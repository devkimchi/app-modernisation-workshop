[CmdletBinding()]
param(
    [string]$Track,
    [string]$ContainerEngine,
    [string]$WslDistribution = 'Ubuntu',
    [switch]$Help
)

. (Join-Path $PSScriptRoot 'powershell-bootstrap.ps1')
$bootstrap = Initialize-WorkshopScript -ScriptPath $PSCommandPath -BoundParameters $PSBoundParameters -RemainingArguments $args -DotSourced ($MyInvocation.InvocationName -eq '.')
if ($bootstrap.Handled) { exit $bootstrap.Code }

$script:WorkshopScripts = $PSScriptRoot
. (Join-Path $PSScriptRoot 'dotnet-framework-tools.ps1')

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
    $context = if ($script:CheckContext) { $script:CheckContext } else { 'PowerShell' }
    Write-Host "[$Status] [$context] ${Id}: $Message"
}

function Test-AzureProvider {
    param([string]$Provider)
    $state = Invoke-ToolProbe az @('provider', 'show', '--namespace', $Provider, '--query', 'registrationState', '--output', 'tsv')
    if ($state.Code -eq 0 -and $state.Text -eq 'Registered') { Add-Check PASS $Provider 'Registered' }
    else { Add-Check FAIL $Provider "등록을 확인하지 못했습니다 (종료 코드 $($state.Code)): $($state.Text). 설치 도우미에서 등록하거나 조회 오류를 해결하세요." }
}

function Show-AzureIdentity {
    $identity = Invoke-ToolProbe az @('account', 'show', '--query', '[[id,name]]', '--output', 'tsv')
    if ($identity.Code -ne 0 -or -not $identity.Text) {
        Add-Check WARN 'azure-subscription' '현재 구독 정보를 조회하지 못했습니다. 대상 구독과 테넌트를 직접 확인하세요.'
        return
    }
    $subscription = $identity.Text -split "`t", 2
    if ($subscription.Count -ne 2 -or -not $subscription[0] -or -not $subscription[1]) {
        Add-Check WARN 'azure-subscription' '현재 구독 ID와 이름을 해석하지 못했습니다. 대상 구독을 직접 확인하세요.'
        return
    }
    Add-Check MANUAL 'azure-subscription' "구독 이름: $($subscription[1]) / 구독 ID: $($subscription[0])"
    $tenant = Invoke-ToolProbe az @('account', 'show', '--query', 'tenantId', '--output', 'tsv')
    $tenantId = [guid]::Empty
    if ($tenant.Code -ne 0 -or -not [guid]::TryParse($tenant.Text, [ref]$tenantId)) {
        Add-Check WARN 'azure-tenant' '현재 테넌트 ID를 조회하지 못해 테넌트 이름을 확인할 수 없습니다.'
        return
    }
    $cloud = Invoke-ToolProbe az @('cloud', 'show', '--query', 'endpoints.resourceManager', '--output', 'tsv')
    if ($cloud.Code -ne 0 -or $cloud.Text -notmatch '^https://') {
        Add-Check WARN 'azure-tenant' "테넌트 ID: $tenantId. Azure 클라우드 엔드포인트를 조회하지 못해 테넌트 이름을 확인할 수 없습니다."
        return
    }
    $url = $cloud.Text.TrimEnd('/') + '/tenants?api-version=2022-12-01'
    $name = Invoke-ToolProbe az @('rest', '--method', 'get', '--url', $url, '--query', "value[?tenantId=='$tenantId'].displayName | [0]", '--output', 'tsv', '--only-show-errors')
    if ($name.Code -eq 0 -and $name.Text -and $name.Text -notin @('None', 'null')) {
        Add-Check MANUAL 'azure-tenant' "테넌트 이름: $($name.Text) / 테넌트 ID: $tenantId"
    }
    else { Add-Check WARN 'azure-tenant' "테넌트 ID: $tenantId. 테넌트 이름을 조회하지 못했습니다. 권한, 네트워크 및 Azure Portal을 확인하세요." }
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
    Add-Check PASS 'container-cli' "$Engine CLI 실행: $($version.Text)"
    $format = if ($Engine -eq 'docker') { '{{.OSType}}' } else { '{{.Host.OS}}' }
    $info = Invoke-ToolProbe $Engine @('info', '--format', $format)
    if ($info.Code -ne 0) {
        Add-Check FAIL 'container-engine' "$Engine 연결 실패. 엔진 또는 Podman machine 상태와 권한을 확인하세요. 자동으로 시작하거나 다른 엔진을 사용하지 않습니다."
    }
    elseif ($info.Text.Trim() -ne 'linux') {
        Add-Check FAIL 'container-engine' '선택한 엔진의 Linux 환경을 확인하지 못했습니다.'
    }
    else { Add-Check PASS 'container-engine' "$Engine CLI가 Linux 컨테이너 엔진에 연결했습니다. 엔진의 설치 위치는 이 검사로 확인하지 않습니다." }
    if ($Engine -eq 'docker') {
        $builder = Invoke-ToolProbe docker @('build', '--help')
        if ($builder.Code -eq 0 -and $builder.Text -match '--platform') { Add-Check PASS 'builder-command' 'Docker CLI 도움말에서 --platform 옵션을 확인했습니다. 실제 빌드는 아직 확인하지 않았습니다.' }
        else { Add-Check FAIL 'builder-command' 'Docker --platform 빌드 기능을 확인하지 못했습니다.' }
        $buildx = Invoke-ToolProbe docker @('buildx', 'version')
        if ($buildx.Code -eq 0) { Add-Check PASS 'builder' 'Docker CLI에서 Buildx 버전 조회에 성공했습니다. 실제 빌드는 아직 확인하지 않았습니다.' }
        else { Add-Check WARN 'builder' 'Buildx를 확인하지 못했습니다. 실제 azd package 단계에서 빌드 지원을 확인해야 합니다.' }
    }
    else {
        if ($IsWindows -or $IsMacOS) {
            $machines = Invoke-ToolProbe podman @('machine', 'list')
            if ($machines.Code -eq 0) { Add-Check PASS 'podman-machine' "Podman machine 목록 (선택된 연결은 별도로 확인): $($machines.Text)" }
            else { Add-Check WARN 'podman-machine' 'Podman machine 목록을 조회하지 못했습니다. machine과 연결 설정을 직접 확인하세요.' }
        }
        $builder = Invoke-ToolProbe podman @('build', '--help')
        if ($builder.Code -eq 0 -and $builder.Text -match '--platform') {
            Add-Check PASS 'builder' 'Podman CLI 도움말에서 --platform 옵션을 확인했습니다. 실제 빌드는 아직 확인하지 않았습니다. Docker Buildx는 필요하지 않습니다.'
        }
        else { Add-Check FAIL 'builder' 'Podman의 --platform 빌드 기능을 확인하지 못했습니다.' }
    }
    Add-Check MANUAL 'container-workload' '이 실습 셸에서 실제 linux/amd64 이미지 빌드, 컨테이너 포트 접근과 ACR 게시를 실습 중 확인하세요. 위 PASS는 실제 워크로드 성공을 보장하지 않습니다.'
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
        else { Add-Check FAIL 'az-containerapp' '설치 도우미에서 containerapp 확장을 설치하거나 조회 오류를 해결하세요.' }
        $account = Invoke-ToolProbe az @('account', 'show', '--query', 'state', '--output', 'tsv')
        if ($account.Code -eq 0 -and $account.Text -eq 'Enabled') {
            Add-Check PASS 'az-login' '선택된 활성 구독이 있습니다.'
            Show-AzureIdentity
            $providers = @('Microsoft.App', 'Microsoft.OperationalInsights', 'Microsoft.Storage', 'Microsoft.ContainerRegistry', 'Microsoft.ServiceBus')
            $providers += if ($SelectedTrack -eq 'java') { 'Microsoft.DBforPostgreSQL' } else { 'Microsoft.Sql' }
            foreach ($provider in $providers) {
                Test-AzureProvider $provider
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
    Add-Check MANUAL 'copilot-app' 'Windows에서 실행하는 Copilot app의 로그인, 라이선스, 조직 정책과 Modernization 플러그인을 확인하세요.'
    Add-Check MANUAL 'azure-access' '위에서 조회한 Azure CLI의 구독이 실습 대상인지 확인하고, 해당 구독의 리전, 쿼터, 역할 할당 및 데이터베이스 Entra 관리자 설정 권한을 확인하세요.'
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
    try {
        $tools = Get-DotnetFrameworkBuildTools
        $msbuild = Invoke-ToolProbe $tools.MSBuild @('-version', '-nologo')
        if ($msbuild.Code -ne 0) { throw 'MSBuild.exe를 실행할 수 없습니다.' }
        Add-Check PASS framework-build "IDE 실행 없이 빌드 가능: $($tools.MSBuild) / 웹 타깃: $($tools.WebTools)"
    }
    catch { Add-Check FAIL framework-build $_.Exception.Message }
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
    try {
        $iis = Get-WorkshopIisExpress
        Add-Check PASS iis-express "IIS Express 실행 파일과 구성 템플릿: $($iis.Exe)"
    }
    catch { Add-Check FAIL iis-express $_.Exception.Message }
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
        $Distribution = 'Ubuntu'
    }
    if ($Distribution -cnotin $names) { throw "WSL 배포판이 없습니다: $Distribution. 기본값은 Ubuntu입니다. wsl --list --verbose로 이름을 확인하고 -WslDistribution <이름>을 지정하세요." }
    $details = Invoke-ToolProbe wsl @('--list', '--verbose')
    $pattern = '(?m)^\s*\*?\s*' + [regex]::Escape($Distribution) + '\s+.+?\s+2\s*$'
    if ($details.Code -ne 0 -or ($details.Text -replace "`0", '') -notmatch $pattern) { throw "배포판 $Distribution 이 WSL2인지 확인하지 못했습니다. wsl --list --verbose로 VERSION 2인지 확인하세요." }
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
    $script:CheckResults = [Collections.Generic.List[object]]::new()
    if ($Track -eq 'java') {
        try {
            if ($IsWindows) {
                $script:CheckContext = 'Windows 호스트'
                Write-Host 'Windows 호스트 검사: Copilot app 호스트의 Git과 Node.js를 확인하고 azd 버전은 참고용으로 표시합니다.'
                $git = Invoke-ToolProbe git @('--version')
                if ($git.Code -eq 0) { Add-Check PASS 'windows-host-git' $git.Text }
                else { Add-Check FAIL 'windows-host-git' 'Windows Copilot app 호스트에 Git이 필요합니다.' }
                $node = Invoke-ToolProbe node @('--version')
                if ($node.Code -eq 0 -and (Test-MinimumVersion $node.Text '22.0.0')) { Add-Check PASS 'windows-host-node' $node.Text }
                else { Add-Check FAIL 'windows-host-node' 'Windows Copilot app 호스트에 Node.js 22 이상의 안정 버전이 필요합니다.' }
                $hostAzd = Invoke-ToolProbe azd @('version')
                if ($hostAzd.Code -eq 0) { Add-Check INFO 'windows-host-azd' "$($hostAzd.Text). 참고용이며 Java 실습의 WSL azd 검사와 별개입니다." }
                else { Add-Check INFO 'windows-host-azd' 'Windows 호스트의 azd는 확인되지 않았습니다. Java 실습에서는 WSL의 azd가 필요합니다.' }
            }
            Write-Host 'Java 실습 검사: 아래 Bash 결과는 지정한 WSL 배포판 또는 macOS의 호출 환경입니다.'
            $bashArguments = @('--track', 'java', '--container-engine', $engine)
            if ($IsWindows) { $bashArguments += '--windows-host-checked' }
            $bashResult = Invoke-JavaBashScript (Join-Path $script:WorkshopScripts 'check-prerequisites.sh') $bashArguments $WslDistribution
            $hostFailures = @($script:CheckResults | Where-Object Status -eq 'FAIL').Count
            if ($hostFailures -gt 0) { Write-Host "Windows 호스트 필수 실패: $hostFailures"; return 1 }
            return $bashResult
        }
        catch { Write-Host "[FAIL] Java Bash 실행 실패: $($_.Exception.Message)"; return 1 }
    }
    if (-not $IsWindows) { Write-Host '[FAIL] .NET 원본 실습은 Windows에서만 지원합니다.'; return 1 }
    $script:CheckContext = 'Windows 호스트'
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
