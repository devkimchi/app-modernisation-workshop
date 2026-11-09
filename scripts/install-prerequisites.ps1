[CmdletBinding()]
param(
    [string]$Track,
    [string]$ContainerEngine,
    [switch]$Help
)

. (Join-Path $PSScriptRoot 'check-prerequisites.ps1') -Track $Track -ContainerEngine $ContainerEngine -Help:$Help

function Confirm-ToolInstall {
    param([string]$Description)
    Write-Host $Description
    $answer = Read-Host '설치하시겠습니까? [y/N]'
    return $answer -ceq 'y' -or $answer -ceq 'Y'
}

function Update-ProcessPath {
    $existing = @($env:PATH -split ';' | Where-Object { $_ })
    foreach ($scope in @('Machine', 'User')) {
        $paths = [Environment]::GetEnvironmentVariable('Path', $scope) -split ';'
        foreach ($path in $paths) {
            $expanded = [Environment]::ExpandEnvironmentVariables($path.Trim())
            if ($expanded -and $expanded -notin $existing) { $existing += $expanded }
        }
    }
    $env:PATH = $existing -join ';'
}

function Install-WindowsTools {
    param([string]$SelectedTrack)
    $tools = if ($SelectedTrack -eq 'java') {
        @(@{ Command='node'; Package='OpenJS.NodeJS.LTS'; Name='Node.js LTS' })
    }
    else {
        @(
            @{ Command='node'; Package='OpenJS.NodeJS.LTS'; Name='Node.js LTS' },
            @{ Command='az'; Package='Microsoft.AzureCLI'; Name='Azure CLI' },
            @{ Command='azd'; Package='Microsoft.Azd'; Name='Azure Developer CLI' }
        )
    }
    $failed = $false
    foreach ($tool in $tools) {
        $existing = Get-Command $tool.Command -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($existing) {
            Write-Host "[INFO] $($tool.Name): PATH에서 발견했습니다 ($($existing.Source)). 설치하거나 업데이트하지 않습니다."
            continue
        }
        if (-not (Get-Command winget -CommandType Application -ErrorAction SilentlyContinue)) {
            Write-Host "[WARN] $($tool.Name) 자동 설치에는 Windows 패키지 관리자 winget이 필요합니다."
            continue
        }
        if (Confirm-ToolInstall "$($tool.Name): Windows 호스트에 winget 패키지 $($tool.Package)을 설치합니다. 네트워크와 관리자 승인이 필요할 수 있습니다. winget에서 표시하는 약관은 직접 확인하세요.") {
            & winget install --id $tool.Package --exact --source winget | Out-Host
            if ($LASTEXITCODE -ne 0) {
                Write-Host "[FAIL] $($tool.Name) 설치 실패 (종료 코드 $LASTEXITCODE)."
                $failed = $true
            }
            else { Update-ProcessPath }
        }
    }
    return (-not $failed)
}

function Invoke-InstallPrerequisiteMain {
    if ($Help) {
        Write-Host 'pwsh -File scripts\install-prerequisites.ps1 -Track java|dotnet [-ContainerEngine docker|podman]'
        return 0
    }
    if ($Track -cnotin @('java', 'dotnet')) { Write-Host '[FAIL] -Track java 또는 -Track dotnet을 지정하세요.'; return 2 }
    if (-not $IsWindows) { Write-Host '[FAIL] 이 설치 도우미는 Windows에서만 지원합니다.'; return 1 }
    try { $engine = Resolve-ContainerEngine $ContainerEngine }
    catch [ArgumentException] { Write-Host "[FAIL] $($_.Exception.Message)"; return 2 }
    if ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected -or $env:CI) {
        Write-Host '[FAIL] 설치는 대화형 터미널에서만 가능합니다. 비대화형 환경에서는 설치하지 않습니다.'
        return 1
    }
    Write-Host '설치 대상: Windows 호스트. 이미 PATH에 있는 도구는 변경하지 않습니다.'
    $installed = Install-WindowsTools $Track
    if ($Track -eq 'java') {
        $node = Invoke-ToolProbe node @('--version')
        if ($node.Code -eq 0 -and (Test-MinimumVersion $node.Text '22.0.0')) {
            Write-Host "[PASS] [Windows 호스트] node: $($node.Text)"
        }
        else {
            Write-Host '[FAIL] [Windows 호스트] node: Node.js 22 이상의 안정 버전을 실행하지 못했습니다. PATH 또는 설치 상태를 확인하세요.'
            $installed = $false
        }
        Write-Host 'Windows 설치가 끝났습니다. Java 도구는 선택한 WSL 배포판을 열고 bash scripts/install-prerequisites.sh --track java를 별도로 실행하세요.'
        Write-Host 'WSL 및 호스트 사전 점검은 이후 check-prerequisites.ps1에서 실행하세요.'
        if (-not $installed) { return 1 }
        return 0
    }
    Write-Host '설치 후 사전 점검을 다시 실행합니다. 로그인, 확장과 수동 항목은 직접 확인하세요.'
    $result = Invoke-PrerequisiteMain
    if (-not $installed -or $result -ne 0) { return 1 }
    return 0
}

if ($MyInvocation.InvocationName -ne '.') { exit (Invoke-InstallPrerequisiteMain) }
