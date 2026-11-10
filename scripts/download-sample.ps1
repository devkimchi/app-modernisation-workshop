[CmdletBinding()]
param(
    [string]$Track,
    [string]$Destination,
    [string]$ContainerEngine,
    [string]$WslDistribution = 'Ubuntu',
    [switch]$Help
)

. (Join-Path $PSScriptRoot 'powershell-bootstrap.ps1')
$bootstrap = Initialize-WorkshopScript -ScriptPath $PSCommandPath -BoundParameters $PSBoundParameters -RemainingArguments $args -DotSourced ($MyInvocation.InvocationName -eq '.')
if ($bootstrap.Handled) { exit $bootstrap.Code }

$script:DownloadScripts = $PSScriptRoot

function Get-SampleDefinition {
    param([string]$SelectedTrack)
    switch -CaseSensitive ($SelectedTrack) {
        'java' { return [pscustomobject]@{ Repository = 'https://github.com/Azure-Samples/java-migration-copilot-samples.git'; Commit = '317d3bbfd61fb1e402bea61f90e385bec12f2070'; Subdirectory = 'asset-manager'; Required = @('pom.xml', 'web', 'worker', 'mvnw', '.mvn\wrapper\maven-wrapper.properties') } }
        'dotnet' { return [pscustomobject]@{ Repository = 'https://github.com/Azure-Samples/dotnet-migration-copilot-samples.git'; Commit = '7c1bf47b7e2627fe5a1c764716638815d35e0282'; Subdirectory = 'ContosoUniversity'; Required = @('ContosoUniversity.sln', 'ContosoUniversity.csproj', 'packages.config') } }
        default { throw [ArgumentException]::new('-Track java 또는 dotnet을 지정하세요.') }
    }
}

function Assert-SafeDestination {
    param([string]$Path, [string]$WorkshopRoot)
    if ($IsWindows -and ($Path.StartsWith('\\?\') -or $Path.StartsWith('\\.\'))) {
        throw 'Windows 확장/장치 경로는 지원하지 않습니다. 일반 드라이브 경로를 사용하세요.'
    }
    $full = [IO.Path]::GetFullPath($Path, (Get-Location).ProviderPath).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    $root = [IO.Path]::GetPathRoot($full).TrimEnd('\', '/')
    if (-not $full -or $full -eq $root -or $full -eq $HOME.TrimEnd('\', '/') -or $full -eq $WorkshopRoot.TrimEnd('\', '/')) {
        throw '홈, 드라이브 루트 또는 워크샵 최상위를 다운로드 대상으로 사용할 수 없습니다.'
    }
    foreach ($name in @('docs', 'scripts', 'tests')) {
        $protected = [IO.Path]::GetFullPath((Join-Path $WorkshopRoot $name)).TrimEnd('\', '/')
        if ($full -eq $protected -or $full.StartsWith($protected + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
            throw '워크샵 자료 폴더 안에는 앱을 다운로드할 수 없습니다.'
        }
    }
    $ancestor = $full
    while ($ancestor) {
        $item = Get-Item -LiteralPath $ancestor -Force -ErrorAction SilentlyContinue
        if ($item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw '심볼릭 링크 또는 junction을 경유하는 대상은 지원하지 않습니다.' }
        $ancestor = [IO.Path]::GetDirectoryName($ancestor)
    }
    if (Test-Path -LiteralPath $full) {
        if (-not (Test-Path -LiteralPath $full -PathType Container)) { throw '대상이 폴더가 아닙니다.' }
        if (@(Get-ChildItem -LiteralPath $full -Force -ErrorAction Stop).Count -gt 0) { throw '대상 폴더가 비어 있지 않습니다. 기존 파일은 덮어쓰지 않습니다.' }
    }
    return $full
}

function Invoke-DownloadGit {
    param([string[]]$Arguments)
    & git @Arguments | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "Git 명령 실패 (종료 코드 $LASTEXITCODE). 네트워크, Git 설정과 대상 권한을 확인하세요." }
}

function Invoke-SampleDownload {
    param([string]$Target, $Definition, [string]$WorkshopRoot)
    $targetPath = Assert-SafeDestination $Target $WorkshopRoot
    $parent = [IO.Path]::GetDirectoryName($targetPath)
    [IO.Directory]::CreateDirectory($parent) | Out-Null
    $staging = Join-Path $parent ('.workshop-download-' + [guid]::NewGuid().ToString('N'))
    [IO.Directory]::CreateDirectory($staging) | Out-Null
    try {
        $checkout = Join-Path $staging 'checkout'
        Invoke-DownloadGit @('init', '--quiet', $checkout)
        Invoke-DownloadGit @('-C', $checkout, 'remote', 'add', 'origin', $Definition.Repository)
        Invoke-DownloadGit @('-C', $checkout, 'fetch', '--quiet', '--depth', '1', 'origin', $Definition.Commit)
        Invoke-DownloadGit @('-C', $checkout, '-c', 'advice.detachedHead=false', '-c', 'core.autocrlf=false', 'checkout', '--quiet', '--detach', 'FETCH_HEAD')
        $head = (& git -C $checkout rev-parse HEAD).Trim()
        if ($LASTEXITCODE -ne 0 -or $head -cne $Definition.Commit) { throw '원본 커밋 검증에 실패했습니다.' }
        $source = Join-Path $checkout $Definition.Subdirectory
        foreach ($required in $Definition.Required) {
            if (-not (Test-Path -LiteralPath (Join-Path $source $required))) { throw "원본 필수 경로가 없습니다: $required" }
        }
        $payload = Join-Path $staging 'payload'
        [IO.Directory]::CreateDirectory($payload) | Out-Null
        Get-ChildItem -LiteralPath $source -Force | Copy-Item -Destination $payload -Recurse -Force -ErrorAction Stop
        $metadataPath = Join-Path $payload 'upstream-source.json'
        if (Test-Path -LiteralPath $metadataPath) { throw '원본에 upstream-source.json이 있어 출처 파일을 덮어쓰지 않고 중단합니다.' }
        $licensePresent = $false
        $noticePattern = '^(LICENSE|LICENCE|NOTICE|COPYING|COPYRIGHT)([._-].*)?$'
        foreach ($notice in Get-ChildItem -LiteralPath $checkout -Force -File | Where-Object Name -Match $noticePattern) {
            $noticePath = Join-Path $payload ("UPSTREAM-" + $notice.Name)
            if (Test-Path -LiteralPath $noticePath) { throw "원본 파일과 고지 보존 경로가 충돌합니다: $($notice.Name)" }
            Copy-Item -LiteralPath $notice.FullName -Destination $noticePath -ErrorAction Stop
            if ($notice.Name -match '^(LICENSE|LICENCE|COPYING)([._-].*)?$') { $licensePresent = $true }
        }
        if (Get-ChildItem -LiteralPath $source -Force -File | Where-Object Name -Match '^(LICENSE|LICENCE|COPYING)([._-].*)?$') { $licensePresent = $true }
        $metadata = [ordered]@{ repository = $Definition.Repository; commit = $Definition.Commit; subdirectory = $Definition.Subdirectory; licenseFileFound = $licensePresent }
        $metadata | ConvertTo-Json | Set-Content -LiteralPath $metadataPath -Encoding utf8 -ErrorAction Stop
        $null = Assert-SafeDestination $targetPath $WorkshopRoot
        if (Test-Path -LiteralPath $targetPath) { [IO.Directory]::Delete($targetPath, $false) }
        [IO.Directory]::Move($payload, $targetPath)
        Write-Host "[PASS] 샘플 다운로드: $targetPath"
        Write-Host "[PASS] 원본 커밋: $head / 앱 폴더에 Git 저장소를 만들지 않음"
        if (-not $licensePresent) { Write-Host '[WARN] 원본에서 라이선스 파일을 찾지 못했습니다. 재배포 권한을 가정하지 마세요.' }
    }
    finally {
        if (Test-Path -LiteralPath $staging) { Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction Stop }
    }
}

function Invoke-DownloadMain {
    if ($Help) {
        Write-Host 'pwsh -File scripts\download-sample.ps1 -Track java|dotnet [-Destination PATH] [-ContainerEngine docker|podman] [-WslDistribution Ubuntu]'
        return 0
    }
    if ($Track -cnotin @('java', 'dotnet')) { Write-Host '[FAIL] -Track java 또는 -Track dotnet을 지정하세요.'; return 2 }
    $definition = Get-SampleDefinition $Track
    $workshop = Split-Path $script:DownloadScripts -Parent
    $savedHelp = $Help
    . (Join-Path $script:DownloadScripts 'check-prerequisites.ps1') -Track $Track -ContainerEngine $ContainerEngine -WslDistribution $WslDistribution
    $Help = $savedHelp
    try {
        $destinationPath = if ($Destination) { [IO.Path]::GetFullPath($Destination, (Get-Location).ProviderPath) } else { Join-Path $workshop $Track }
        $engine = Resolve-ContainerEngine $ContainerEngine
        $null = Assert-SafeDestination $destinationPath $workshop
    }
    catch { Write-Host "[FAIL] $($_.Exception.Message)"; return 2 }
    if ($Track -eq 'java') {
        try {
            $target = Get-JavaBashTarget $WslDistribution
            $javaDestination = Convert-ToJavaPath $destinationPath $target
            return (Invoke-JavaBashScript (Join-Path $script:DownloadScripts 'download-sample.sh') @('--track', 'java', '--destination', $javaDestination, '--container-engine', $engine) $WslDistribution)
        }
        catch { Write-Host "[FAIL] Java 다운로드 위임 실패: $($_.Exception.Message)"; return 1 }
    }
    & pwsh -NoLogo -NoProfile -File (Join-Path $script:DownloadScripts 'check-prerequisites.ps1') -Track dotnet -ContainerEngine $engine | Out-Host
    if ($LASTEXITCODE -ne 0) { Write-Host '[FAIL] 사전 점검이 통과하지 않아 다운로드하지 않았습니다.'; return 1 }
    try {
        Invoke-SampleDownload $destinationPath $definition $workshop
        return 0
    }
    catch { Write-Host "[FAIL] 다운로드 실패: $($_.Exception.Message)"; return 1 }
}

if ($MyInvocation.InvocationName -ne '.') { exit (Invoke-DownloadMain) }
