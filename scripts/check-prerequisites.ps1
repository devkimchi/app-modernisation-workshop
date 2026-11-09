[CmdletBinding()]
param(
    [string]$Track,
    [string]$ContainerEngine,
    [string]$WslDistribution,
    [switch]$Help
)

$script:WorkshopScripts = $PSScriptRoot

function Resolve-ContainerEngine {
    param([string]$Requested, [string]$Configured = $env:AZD_CONTAINER_RUNTIME)
    foreach ($value in @($Requested, $Configured)) {
        if ($value -and $value -cnotin @('docker', 'podman')) {
            throw [ArgumentException]::new('ContainerEngine/AZD_CONTAINER_RUNTIME 값은 docker 또는 podman이어야 합니다.')
        }
    }
    if ($Requested -and $Configured -and $Requested -cne $Configured) {
        throw [ArgumentException]::new('ContainerEngine과 AZD_CONTAINER_RUNTIME이 다릅니다. 현재 셸의 값을 먼저 일치시키세요.')
    }
    if ($Requested) { return $Requested }
    if ($Configured) { return $Configured }
    return 'docker'
}

function Invoke-ToolProbe {
    param([string]$Name, [string[]]$Arguments = @())
    $command = Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $command) { return [pscustomobject]@{ Code = 127; Text = '' } }
    try {
        $text = (& $command.Source @Arguments 2>&1 | Out-String).Trim()
        return [pscustomobject]@{ Code = $LASTEXITCODE; Text = $text }
    }
    catch {
        return [pscustomobject]@{ Code = 126; Text = $_.Exception.Message }
    }
}

function Add-Check {
    param([string]$Status, [string]$Id, [string]$Message)
    $script:CheckResults.Add([pscustomobject]@{ Status = $Status; Id = $Id; Message = $Message })
    Write-Host "[$Status] $Id : $Message"
}

function Test-MinimumVersion {
    param([string]$Text, [version]$Minimum)
    $match = [regex]::Match($Text, '(?<!\d)(\d+\.\d+\.\d+)(?![\d-])')
    return $match.Success -and ([version]$match.Groups[1].Value -ge $Minimum)
}

function Test-ContainerRuntime {
    param([string]$Engine)
    $version = Invoke-ToolProbe $Engine @('--version')
    if ($version.Code -ne 0) {
        Add-Check FAIL 'container-cli' "$Engine 실행 실패 (종료 코드 $($version.Code)). docs\setup.md를 확인하세요."
        return
    }
    Add-Check PASS 'container-cli' $version.Text
    $format = if ($Engine -eq 'docker') { '{{.OSType}}' } else { '{{.Host.OS}}' }
    $info = Invoke-ToolProbe $Engine @('info', '--format', $format)
    if ($info.Code -ne 0) {
        Add-Check FAIL 'container-engine' "$Engine 연결 실패. 엔진 또는 Podman machine 상태와 권한을 확인하세요. 자동으로 시작하거나 다른 엔진을 사용하지 않습니다."
    }
    elseif ($info.Text.Trim() -ne 'linux') {
        Add-Check FAIL 'container-engine' '선택한 엔진의 Linux 환경을 확인하지 못했습니다.'
    }
    else { Add-Check PASS 'container-engine' "$Engine Linux 환경에 연결했습니다." }
    if ($Engine -eq 'docker') {
        $builder = Invoke-ToolProbe docker @('build', '--help')
        if ($builder.Code -eq 0 -and $builder.Text -match '--platform') { Add-Check PASS 'builder-command' 'Docker --platform 빌드 기능이 있습니다.' }
        else { Add-Check FAIL 'builder-command' 'Docker --platform 빌드 기능을 확인하지 못했습니다.' }
        $buildx = Invoke-ToolProbe docker @('buildx', 'version')
        if ($buildx.Code -eq 0) { Add-Check PASS 'builder' 'Docker Buildx가 있습니다.' }
        else { Add-Check WARN 'builder' 'Buildx를 확인하지 못했습니다. 실제 azd package 단계에서 빌드 지원을 확인해야 합니다.' }
    }
    else {
        $builder = Invoke-ToolProbe podman @('build', '--help')
        if ($builder.Code -eq 0 -and $builder.Text -match '--platform') {
            Add-Check PASS 'builder' 'Podman 내장 빌더가 있습니다. Docker Buildx는 필요하지 않습니다.'
        }
        else { Add-Check FAIL 'builder' 'Podman의 --platform 빌드 기능을 확인하지 못했습니다.' }
    }
    Add-Check MANUAL 'container-workload' '실제 linux/amd64 빌드, 포트 접근과 ACR 게시 성공은 실습에서 확인하세요.'
}

function Test-CommonTools {
    param([string]$Engine, [string]$SelectedTrack)
    $git = Invoke-ToolProbe git @('--version')
    if ($git.Code -eq 0) { Add-Check PASS git $git.Text }
    else { Add-Check FAIL git 'Git을 설치하고 PATH를 확인하세요.' }
    $node = Invoke-ToolProbe node @('--version')
    if ($node.Code -eq 0 -and (Test-MinimumVersion $node.Text '22.0.0')) { Add-Check PASS node $node.Text }
    else { Add-Check FAIL node 'Node.js 22 이상의 안정 버전이 필요합니다.' }
    $az = Invoke-ToolProbe az @('version', '--output', 'json')
    if ($az.Code -eq 0) {
        Add-Check PASS az 'Azure CLI를 실행할 수 있습니다.'
        $extension = Invoke-ToolProbe az @('extension', 'show', '--name', 'containerapp', '--query', 'version', '--output', 'tsv')
        if ($extension.Code -eq 0 -and $extension.Text) { Add-Check PASS 'az-containerapp' "확장 버전: $($extension.Text)" }
        else { Add-Check FAIL 'az-containerapp' 'containerapp 확장을 수동으로 설치하거나 조회 오류를 해결하세요.' }
        $account = Invoke-ToolProbe az @('account', 'show', '--query', 'state', '--output', 'tsv')
        if ($account.Code -eq 0 -and $account.Text -eq 'Enabled') {
            Add-Check PASS 'az-login' '선택된 활성 구독이 있습니다. 실제 대상 구독은 직접 확인하세요.'
            $providers = @('Microsoft.App', 'Microsoft.OperationalInsights', 'Microsoft.Storage', 'Microsoft.ContainerRegistry', 'Microsoft.ServiceBus')
            $providers += if ($SelectedTrack -eq 'java') { 'Microsoft.DBforPostgreSQL' } else { 'Microsoft.Sql' }
            foreach ($provider in $providers) {
                $state = Invoke-ToolProbe az @('provider', 'show', '--namespace', $provider, '--query', 'registrationState', '--output', 'tsv')
                if ($state.Code -eq 0 -and $state.Text -eq 'Registered') { Add-Check PASS $provider 'Registered' }
                else { Add-Check FAIL $provider '등록 상태를 확인하지 못했습니다. 구독 권한과 공급자 등록을 확인하세요.' }
            }
        }
        else { Add-Check FAIL 'az-login' 'az login 및 활성 구독 선택이 필요하거나 구독 조회에 실패했습니다.' }
    }
    else { Add-Check FAIL az 'Azure CLI를 설치하거나 실행 오류를 해결하세요.' }
    $azd = Invoke-ToolProbe azd @('version')
    if ($azd.Code -eq 0 -and (Test-MinimumVersion $azd.Text '1.37.3')) {
        Add-Check PASS azd $azd.Text
        $login = Invoke-ToolProbe azd @('auth', 'login', '--check-status')
        if ($login.Code -eq 0) { Add-Check PASS 'azd-login' 'azd 로그인 상태를 확인했습니다.' }
        else { Add-Check FAIL 'azd-login' 'azd auth login을 직접 실행하거나 인증 오류를 해결하세요. az 로그인과는 별개입니다.' }
    }
    else { Add-Check FAIL azd '워크샵 기준 azd 1.37.3 이상이 필요합니다. 자동 업데이트하지 않습니다.' }
    Test-ContainerRuntime $Engine
    Add-Check MANUAL 'copilot-app' 'Copilot app 로그인, 라이선스, 조직 정책과 Modernization 플러그인 활성화를 확인하세요.'
    Add-Check MANUAL 'azure-access' '배포할 구독, 리전, 쿼터, 역할 할당 권한과 데이터베이스 Entra 관리자 설정 권한을 확인하세요.'
}

function Test-DotnetTools {
    try {
        $feature = Get-CimInstance Win32_OptionalFeature -Filter "Name='MSMQ-Server'" -ErrorAction Stop
        if ($feature -and $feature.InstallState -eq 1) { Add-Check PASS msmq-feature 'MSMQ Server 기능이 활성화되어 있습니다.' }
        else { Add-Check FAIL msmq-feature 'MSMQ Server 기능을 활성화하고 필요한 재시작을 완료하세요.' }
    }
    catch { Add-Check FAIL msmq-feature "MSMQ 기능 조회 실패: $($_.Exception.Message)" }
    $service = Get-Service MSMQ -ErrorAction SilentlyContinue
    if ($service -and $service.Status -eq 'Running') { Add-Check PASS msmq-service 'MSMQ 서비스가 실행 중입니다.' }
    else { Add-Check FAIL msmq-service 'MSMQ 서비스가 없거나 실행 중이 아닙니다.' }
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    $vs = Invoke-ToolProbe $vswhere @('-products', 'Microsoft.VisualStudio.Product.Community', 'Microsoft.VisualStudio.Product.Professional', 'Microsoft.VisualStudio.Product.Enterprise', '-version', '[18.0,19.0)', '-requires', 'Microsoft.VisualStudio.Workload.NetWeb', '-format', 'json', '-utf8')
    if ($vs.Code -eq 0) {
        try {
            $instances = @($vs.Text | ConvertFrom-Json -ErrorAction Stop)
            if ($instances.Count -gt 0) { Add-Check PASS vs2026 'Visual Studio 2026 IDE와 ASP.NET 및 웹 개발 워크로드가 있습니다.' }
            else { Add-Check FAIL vs2026 'Visual Studio 2026 IDE와 ASP.NET 및 웹 개발 워크로드가 필요합니다.' }
        }
        catch { Add-Check FAIL vs2026 'vswhere 출력 해석에 실패했습니다.' }
    }
    else { Add-Check FAIL vs2026 'Visual Studio Installer의 vswhere를 실행할 수 없습니다.' }
    try {
        $release = Get-ItemPropertyValue -LiteralPath 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -Name Release -ErrorAction Stop
        if ($release -ge 528040) { Add-Check PASS framework-runtime '.NET Framework 4.8 이상 런타임이 있습니다.' }
        else { Add-Check FAIL framework-runtime '.NET Framework 4.8 이상 런타임이 필요합니다.' }
    }
    catch { Add-Check FAIL framework-runtime "런타임 레지스트리 조회 실패: $($_.Exception.Message)" }
    $references = Join-Path ${env:ProgramFiles(x86)} 'Reference Assemblies\Microsoft\Framework\.NETFramework\v4.8'
    if ((Test-Path -LiteralPath (Join-Path $references 'mscorlib.dll')) -and (Test-Path -LiteralPath (Join-Path $references 'RedistList\FrameworkList.xml'))) {
        Add-Check PASS framework-targeting '.NET Framework 4.8 참조 어셈블리가 있습니다.'
    }
    else { Add-Check FAIL framework-targeting '4.8 Targeting Pack이 필요합니다. 런타임 설치만으로는 충분하지 않습니다.' }
    $sdks = Invoke-ToolProbe dotnet @('--list-sdks')
    if ($sdks.Code -eq 0 -and $sdks.Text -match '(?m)^10\.\d+\.\d+\s+\[') { Add-Check PASS dotnet-sdk '.NET 10 안정 SDK가 있습니다.' }
    else { Add-Check FAIL dotnet-sdk '.NET 10 SDK가 필요합니다. 런타임만 설치된 경우는 통과하지 않습니다.' }
    $iis = @("$env:ProgramFiles\IIS Express\iisexpress.exe", "${env:ProgramFiles(x86)}\IIS Express\iisexpress.exe") | Where-Object { Test-Path -LiteralPath $_ }
    if ($iis.Count -gt 0) { Add-Check PASS iis-express 'IIS Express가 있습니다.' }
    else { Add-Check FAIL iis-express 'Visual Studio Installer에서 IIS Express를 설치하세요.' }
    $localdb = Get-Command SqlLocalDB -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Source
    if (-not $localdb) {
        $localdb = Get-ChildItem "$env:ProgramFiles\Microsoft SQL Server\*\Tools\Binn\SqlLocalDB.exe" -ErrorAction SilentlyContinue |
            Sort-Object FullName -Descending | Select-Object -First 1 -ExpandProperty FullName
    }
    if ($localdb) {
        $db = Invoke-ToolProbe $localdb @('versions')
        if ($db.Code -eq 0 -and $db.Text) { Add-Check PASS localdb 'SQL Server LocalDB 설치를 확인했습니다.' }
        else { Add-Check FAIL localdb 'LocalDB 실행 실패. 설치 또는 권한을 확인하세요.' }
    }
    else { Add-Check FAIL localdb 'SQL Server Express LocalDB를 설치하세요.' }
    Add-Check MANUAL 'upgrade-plugin' 'Copilot app에서 upgrade-agent 플러그인과 Upgrade 에이전트를 확인하세요.'
}

function Get-JavaBashTarget {
    param([string]$Distribution)
    if (-not $IsWindows) { return [pscustomobject]@{ Command = 'bash'; Prefix = @(); Distribution = '' } }
    $list = Invoke-ToolProbe wsl @('--list', '--quiet')
    if ($list.Code -ne 0) { throw 'WSL 배포판을 조회하지 못했습니다. WSL2 설치 상태를 확인하세요.' }
    $names = @(($list.Text -replace "`0", '') -split '\r?\n' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    if (-not $Distribution) {
        if ($names.Count -ne 1) { throw 'WSL 배포판을 명시하세요: -WslDistribution Ubuntu. 여러 배포판 중 하나를 임의로 선택하지 않습니다.' }
        $Distribution = $names[0]
    }
    if ($Distribution -cnotin $names) { throw "지정한 WSL 배포판이 없습니다: $Distribution" }
    $details = Invoke-ToolProbe wsl @('--list', '--verbose')
    $pattern = '(?m)^\s*\*?\s*' + [regex]::Escape($Distribution) + '\s+.+?\s+2\s*$'
    if ($details.Code -ne 0 -or ($details.Text -replace "`0", '') -notmatch $pattern) { throw '지정한 배포판이 WSL2인지 확인하지 못했습니다.' }
    return [pscustomobject]@{ Command = 'wsl'; Prefix = @('--distribution', $Distribution, '--exec'); Distribution = $Distribution }
}

function Convert-ToJavaPath {
    param([string]$Path, $Target)
    $full = [IO.Path]::GetFullPath($Path)
    if (-not $IsWindows) { return $full }
    $result = Invoke-ToolProbe wsl @('--distribution', $Target.Distribution, '--exec', 'wslpath', '-a', $full)
    if ($result.Code -ne 0 -or -not $result.Text) { throw 'Windows 경로를 WSL 경로로 변환하지 못했습니다.' }
    return $result.Text.Trim()
}

function Invoke-JavaBashScript {
    param([string]$Script, [string[]]$Arguments, [string]$Distribution)
    $target = Get-JavaBashTarget $Distribution
    $path = Convert-ToJavaPath $Script $target
    $commandArguments = if ($IsWindows) { @($target.Prefix) + @('bash', $path) + $Arguments } else { @($path) + $Arguments }
    & $target.Command @commandArguments | Out-Host
    return $LASTEXITCODE
}

function Invoke-PrerequisiteMain {
    if ($Help) {
        Write-Host 'pwsh -File scripts\check-prerequisites.ps1 -Track java|dotnet [-ContainerEngine docker|podman] [-WslDistribution Ubuntu]'
        return 0
    }
    if ($Track -cnotin @('java', 'dotnet')) { Write-Host '[FAIL] -Track java 또는 -Track dotnet을 지정하세요.'; return 2 }
    try { $engine = Resolve-ContainerEngine $ContainerEngine }
    catch [ArgumentException] { Write-Host "[FAIL] $($_.Exception.Message)"; return 2 }
    if ($Track -eq 'java') {
        try {
            return (Invoke-JavaBashScript (Join-Path $script:WorkshopScripts 'check-prerequisites.sh') @('--track', 'java', '--container-engine', $engine) $WslDistribution)
        }
        catch { Write-Host "[FAIL] Java Bash 실행 실패: $($_.Exception.Message)"; return 1 }
    }
    if (-not $IsWindows) { Write-Host '[FAIL] .NET 원본 실습은 Windows에서만 지원합니다.'; return 1 }
    $script:CheckResults = [Collections.Generic.List[object]]::new()
    if ($PSVersionTable.PSVersion.Major -ge 7) { Add-Check PASS pwsh "PowerShell $($PSVersionTable.PSVersion)" }
    else { Add-Check FAIL pwsh 'PowerShell 7이 필요합니다.' }
    Write-Host "트랙: $Track / 엔진: $engine / 실행 환경: Windows"
    $previous = $env:AZURE_EXTENSION_USE_DYNAMIC_INSTALL
    try {
        $env:AZURE_EXTENSION_USE_DYNAMIC_INSTALL = 'no'
        Test-CommonTools $engine $Track
        Test-DotnetTools
    }
    finally { $env:AZURE_EXTENSION_USE_DYNAMIC_INSTALL = $previous }
    $failures = @($script:CheckResults | Where-Object Status -eq 'FAIL').Count
    Write-Host "필수 실패: $failures. MANUAL 항목은 자동 확인되지 않았습니다. azd 실행 전 현재 셸에서 AZD_CONTAINER_RUNTIME=$engine 을 지정하세요."
    if ($failures -gt 0) { return 1 }
    return 0
}

if ($MyInvocation.InvocationName -ne '.') { exit (Invoke-PrerequisiteMain) }
