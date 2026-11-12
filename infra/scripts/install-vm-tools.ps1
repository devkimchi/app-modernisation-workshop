[CmdletBinding()]
param(
    [ValidateSet('dotnet')]
    [string]$Track = 'dotnet',
    [switch]$Help
)

function Get-VmHelperDirectory {
    if (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'powershell-bootstrap.ps1')) { return $PSScriptRoot }
    return [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\scripts'))
}

function Assert-VmInstallerContext {
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT -or -not [Environment]::Is64BitProcess) {
        throw '이 설치 도우미는 Windows x64 PowerShell에서 실행하세요.'
    }
    if (-not (Test-WorkshopBootstrapInteractive)) { throw 'CI 또는 비대화형 환경에서는 설치하지 않습니다.' }
    $current = [Security.Principal.WindowsIdentity]::GetCurrent()
    $account = Get-LocalUser -Name appmoduser -ErrorAction Stop
    if ($current.IsSystem -or $current.User.Value -ne $account.SID.Value) {
        throw 'appmoduser로 로그인한 뒤 같은 계정의 관리자 터미널에서 실행하세요.'
    }
    $principal = New-Object Security.Principal.WindowsPrincipal($current)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'appmoduser의 터미널을 관리자 권한으로 다시 열어 주세요.'
    }
}

function Confirm-VmAction {
    param([string]$Message)
    if (-not (Test-WorkshopBootstrapInteractive)) { return $false }
    Write-Host $Message
    return (Read-Host '실행하시겠습니까? [y/N]') -cmatch '^[yY]$'
}

function Test-VmRebootPending {
    return (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') -or
        (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired')
}

function Invoke-VmInstaller {
    param([string]$Command, [string[]]$Arguments)
    $executable = Get-Command $Command -CommandType Application -ErrorAction Stop | Select-Object -First 1
    & $executable.Source @Arguments | Out-Host
    $code = $LASTEXITCODE
    if ($code -in @(1641, 3010)) {
        $script:VmRestartRequired = $true
        Write-Host '[MANUAL] 설치 관리자가 재부팅 필요 상태를 반환했습니다. 직접 재부팅한 뒤 다시 실행하세요.'
        return $true
    }
    if ($code -ne 0) { throw "$Command 설치 실패 (종료 코드 $code)." }
    return $true
}

function Get-VmWingetVersion {
    param([string]$Id, [string]$VersionPattern)
    $text = (& winget show --id $Id --exact --source winget --versions --disable-interactivity 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 0) {
        throw "$Id 버전 조회 실패. winget에서 원본 약관과 네트워크 상태를 직접 확인하세요: $text"
    }
    $versions = @($text -split '\r?\n' | ForEach-Object { $_.Trim() } |
        Where-Object { $_ -match $VersionPattern } | ForEach-Object { [version]$_ } | Sort-Object -Descending)
    if (-not $versions.Count) { throw "$Id 에서 요구한 정식 버전을 찾지 못했습니다: $VersionPattern" }
    return $versions[0].ToString()
}

function Install-VmPackage {
    param(
        [string]$Id,
        [string]$Name,
        [scriptblock]$TestInstalled,
        [string]$VersionPattern,
        [string[]]$ExtraArguments = @()
    )
    if (& $TestInstalled) { Write-Host "[PASS] $Name 설치 확인. 기존 설치본을 유지합니다."; return $true }
    if (-not (Confirm-VmAction "$Name ($Id)을 설치합니다. 표시되는 라이선스와 설치 내용을 확인하세요.")) {
        Write-Host "[MANUAL] $Name 설치를 건너뛰었습니다."
        return $false
    }
    $arguments = @('install', '--id', $Id, '--exact', '--source', 'winget')
    if ($VersionPattern) { $arguments += @('--version', (Get-VmWingetVersion $Id $VersionPattern)) }
    $arguments += $ExtraArguments
    $null = Invoke-VmInstaller winget $arguments
    if ($script:VmRestartRequired) { return $false }
    if (Get-Command Update-ProcessPath -CommandType Function -ErrorAction SilentlyContinue) { Update-ProcessPath }
    if (-not (& $TestInstalled)) { throw "$Name 설치 후 상태를 확인하지 못했습니다. 새 터미널에서 다시 실행하세요." }
    Write-Host "[PASS] $Name 설치를 확인했습니다."
    return $true
}

function Initialize-VmWinget {
    if (Get-Command winget -CommandType Application -ErrorAction SilentlyContinue) { return $true }
    if (Get-AppxPackage -Name Microsoft.DesktopAppInstaller -ErrorAction Stop) {
        if (-not (Confirm-VmAction '현재 사용자에게 Windows 패키지 관리자 App Installer를 등록합니다.')) { return $false }
        Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe -ErrorAction Stop
    }
    else {
        if (-not (Get-PackageProvider -ListAvailable -Name NuGet -ErrorAction SilentlyContinue)) {
            if (-not (Confirm-VmAction 'WinGet 준비에 필요한 NuGet 패키지 공급자를 설치합니다.')) { return $false }
            $null = Install-PackageProvider -Name NuGet -Scope CurrentUser -Force -ErrorAction Stop
        }
        if (-not (Get-Module -ListAvailable Microsoft.WinGet.Client)) {
            if (-not (Confirm-VmAction 'PSGallery에서 Microsoft.WinGet.Client 모듈을 현재 사용자에게 설치합니다.')) { return $false }
            Install-Module -Name Microsoft.WinGet.Client -Scope CurrentUser -Repository PSGallery -Force -ErrorAction Stop
        }
        if (-not (Confirm-VmAction 'Microsoft.WinGet.Client로 모든 사용자의 안정 WinGet 패키지 관리자를 설치하거나 복구합니다.')) { return $false }
        Import-Module Microsoft.WinGet.Client -ErrorAction Stop
        Repair-WinGetPackageManager -AllUsers -ErrorAction Stop | Out-Host
    }
    if (-not (Get-Command winget -CommandType Application -ErrorAction SilentlyContinue)) {
        throw 'winget을 찾지 못했습니다. 새 관리자 터미널에서 다시 실행하세요.'
    }
    return $true
}

function Test-VmPowerShell7 {
    $path = Find-WorkshopPowerShell
    if (-not $path) { return $false }
    $major = & $path -NoProfile -NonInteractive -Command '$PSVersionTable.PSVersion.Major'
    if ($LASTEXITCODE -ne 0 -or "$major".Trim() -ne '7') { throw '안정 PowerShell 7.x 경로를 확인하세요.' }
    return $true
}

function Get-VmUbuntuVersion {
    $list = Invoke-ToolProbe wsl.exe @('--list', '--verbose')
    if ($list.Code -ne 0) { throw "WSL 배포판 조회 실패: $($list.Text)" }
    if (($list.Text -replace "`0", '') -match '(?m)^\s*\*?\s*Ubuntu\s+\S+\s+([12])\s*$') {
        return [int]$Matches[1]
    }
    return 0
}

function Install-VmUbuntu {
    $version = Get-VmUbuntuVersion
    if ($version -eq 1) { throw '기존 Ubuntu는 WSL1입니다. 데이터를 보존하고 직접 WSL2 전환을 준비하세요.' }
    if ($version -eq 2) { Write-Host '[PASS] appmoduser의 Ubuntu WSL2 등록을 확인했습니다.'; return $true }
    if (-not (Confirm-VmAction 'appmoduser에 Ubuntu WSL2를 설치합니다. 최초 Linux 사용자 설정은 이후 직접 진행합니다.')) {
        return $false
    }
    $null = Invoke-VmInstaller wsl.exe @('--install', '--distribution', 'Ubuntu', '--no-launch')
    if ($script:VmRestartRequired) { return $false }
    if ((Get-VmUbuntuVersion) -ne 2) { throw 'Ubuntu WSL2 등록을 확인하지 못했습니다. 재부팅과 WSL 상태를 확인하세요.' }
    Write-Host '[MANUAL] wsl -d Ubuntu를 실행해 최초 Linux 사용자 설정을 완료하세요.'
    return $true
}

function Install-VmMsmq {
    $feature = Get-WindowsOptionalFeature -Online -FeatureName MSMQ-Server -ErrorAction Stop
    if ("$($feature.State)" -in @('EnablePending', 'DisablePending')) {
        $script:VmRestartRequired = $true
        return $false
    }
    if ("$($feature.State)" -ne 'Enabled') {
        if (-not (Confirm-VmAction 'MSMQ Server와 필요한 Windows 기능을 활성화합니다. 자동 재부팅하지 않습니다.')) { return $false }
        $result = Enable-WindowsOptionalFeature -Online -FeatureName MSMQ-Server -All -NoRestart -ErrorAction Stop
        if ($result.RestartNeeded) { $script:VmRestartRequired = $true; return $false }
        if ((Get-WindowsOptionalFeature -Online -FeatureName MSMQ-Server -ErrorAction Stop).State -ne 'Enabled') {
            throw 'MSMQ 기능 활성화를 확인하지 못했습니다.'
        }
    }
    $service = Get-Service MSMQ -ErrorAction Stop
    if ($service.Status -ne 'Running') {
        if (-not (Confirm-VmAction 'MSMQ 서비스를 자동 시작으로 설정하고 시작합니다. 큐나 데이터는 만들지 않습니다.')) { return $false }
        Set-Service MSMQ -StartupType Automatic -ErrorAction Stop
        Start-Service MSMQ -ErrorAction Stop
        $service = Get-Service MSMQ -ErrorAction Stop
        $service.WaitForStatus('Running', [TimeSpan]::FromSeconds(30))
    }
    Write-Host '[PASS] MSMQ Server와 서비스 실행을 확인했습니다.'
    return $true
}

function Test-VmFrameworkRuntime {
    $path = 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full'
    if (-not (Test-Path $path)) { return $false }
    return (Get-ItemProperty $path -Name Release -ErrorAction Stop).Release -ge 528040
}

function Install-VmNvm {
    $nvm = Get-Command nvm -CommandType Application -ErrorAction SilentlyContinue
    if ($nvm) {
        $version = Get-WorkshopReleaseVersion (Invoke-ToolProbe nvm @('version'))
        if (-not $version -or $version.Major -ne 2) { throw '기존 nvm을 자동 교체하지 않습니다. nvm-windows 2.x를 직접 준비하세요.' }
    }
    else {
        $nodeLink = Join-Path $env:ProgramFiles 'nodejs'
        if ((Get-Command node -CommandType Application -ErrorAction SilentlyContinue) -or
            $env:NVM_HOME -or $env:NVM_SYMLINK -or (Test-Path -LiteralPath $nodeLink)) {
            throw '기존 Node.js 또는 NVM 경로를 보존합니다. nvm-windows 2.x 전환을 직접 준비하세요.'
        }
        $installed = Install-VmPackage -Id AuthorSoftware.NVMWindows -Name 'nvm-windows 2.x' -VersionPattern '^2\.\d+\.\d+$' -TestInstalled {
            $v = Get-WorkshopReleaseVersion (Invoke-ToolProbe nvm @('version'))
            $v -and $v.Major -eq 2
        }
        if (-not $installed) { return $false }
    }
    $probe = Invoke-ToolProbe nvm @('config', 'get', 'auto_install', '--json')
    if ($probe.Code -ne 0) { throw 'nvm 자동 설치 설정을 조회하지 못했습니다.' }
    $config = $probe.Text | ConvertFrom-Json -ErrorAction Stop
    if ($config.auto_install -isnot [bool]) { throw 'nvm auto_install 설정이 올바르지 않습니다.' }
    if ($config.auto_install) {
        if (-not (Confirm-VmAction '동의 없는 Node.js 자동 설치를 막기 위해 nvm의 auto_install을 false로 바꿉니다.')) { return $false }
        $change = Invoke-ToolProbe nvm @('config', 'set', 'auto_install=false')
        if ($change.Code -ne 0) { throw "nvm 자동 설치 해제 실패: $($change.Text)" }
    }
    if (-not (Get-WorkshopNvmConfiguration)) {
        throw 'nvm config의 auto_install을 false로 설정하고 root/mode/enabled를 확인한 뒤 다시 실행하세요.'
    }
    return Install-WorkshopNode
}

function Get-VmVsInstance {
    param([string]$Product, [string[]]$Requires = @())
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (-not (Test-Path -LiteralPath $vswhere)) { return }
    $arguments = @('-products', "Microsoft.VisualStudio.Product.$Product", '-version', '[18.0,19.0)', '-latest', '-format', 'json', '-utf8')
    if ($Requires.Count) { $arguments += '-requires'; $arguments += $Requires }
    $probe = Invoke-ToolProbe $vswhere $arguments
    if ($probe.Code -ne 0) { throw "Visual Studio 상태 조회 실패: $($probe.Text)" }
    $instances = @($probe.Text | ConvertFrom-Json -ErrorAction Stop)
    if ($instances.Count) { return $instances[0] }
}

function Install-VmVisualStudio {
    param([ValidateSet('Community', 'BuildTools')][string]$Product, [string]$ConfigFile)
    $config = Get-Content -LiteralPath $ConfigFile -Raw | ConvertFrom-Json -ErrorAction Stop
    $components = @($config.components)
    if (Get-VmVsInstance $Product $components) { Write-Host "[PASS] Visual Studio 2026 $Product 구성 확인."; return $true }
    $instance = Get-VmVsInstance $Product
    if ($instance) {
        if (-not (Confirm-VmAction "기존 Visual Studio 2026 $Product 에 $ConfigFile 의 누락 구성요소를 추가합니다. Visual Studio를 닫아 주세요.")) { return $false }
        $setup = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\setup.exe'
        # setup.exe does not support the bootstrapper's --wait switch.
        $arguments = "modify --installPath `"$($instance.installationPath)`" --config `"$ConfigFile`" --passive --norestart"
        $process = Start-Process -FilePath $setup -ArgumentList $arguments -Wait -PassThru -ErrorAction Stop
        if ($process.ExitCode -in @(1641, 3010)) { $script:VmRestartRequired = $true; return $false }
        if ($process.ExitCode -ne 0) { throw "Visual Studio 구성 실패 (종료 코드 $($process.ExitCode))." }
        if (-not (Get-VmVsInstance $Product $components)) { throw '요청한 Visual Studio 구성요소를 확인하지 못했습니다.' }
        return $true
    }
    $override = "--passive --wait --norestart --config `"$ConfigFile`""
    return Install-VmPackage -Id "Microsoft.VisualStudio.$Product" -Name "Visual Studio 2026 $Product" `
        -VersionPattern '^18\.\d+\.\d+$' -ExtraArguments @('--override', $override) `
        -TestInstalled { [bool](Get-VmVsInstance $Product $components) }
}

function Get-VmCopilotVersion {
    foreach ($root in @('HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall',
            'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall',
            'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall')) {
        if (-not (Test-Path $root)) { continue }
        foreach ($key in Get-ChildItem $root -ErrorAction Stop) {
            $app = Get-ItemProperty $key.PSPath -ErrorAction Stop
            if ($app.DisplayName -match '^GitHub Copilot( App)?$') {
                $version = $null
                if (-not [version]::TryParse($app.DisplayVersion, [ref]$version)) { throw 'Copilot app 설치 버전을 읽지 못했습니다.' }
                return $version
            }
        }
    }
}

function Install-VmCopilot {
    $existing = Get-VmCopilotVersion
    if ($existing) { Write-Host "[PASS] GitHub Copilot app $existing 유지. 로그인과 플러그인 설정은 직접 진행하세요."; return $true }
    if (-not (Confirm-VmAction '공식 github/app 정식 릴리스의 GitHub Copilot app을 설치합니다. Copilot CLI가 아닙니다.')) { return $false }
    $release = Invoke-RestMethod 'https://api.github.com/repos/github/app/releases/latest' -ErrorAction Stop
    if ($release.prerelease -or $release.draft -or $release.tag_name -notmatch '^v?(\d+\.\d+\.\d+)$') {
        throw '정식 Copilot app 릴리스를 확인하지 못했습니다.'
    }
    $expectedVersion = [version]$Matches[1]
    $assets = @($release.assets | Where-Object name -eq 'GitHub-Copilot-windows-x64.msi')
    if ($assets.Count -ne 1 -or $assets[0].browser_download_url -notlike 'https://github.com/github/app/releases/download/*') {
        throw '공식 Windows x64 MSI를 확인하지 못했습니다.'
    }
    $path = Join-Path $env:TEMP ("appmod-copilot-$([guid]::NewGuid().ToString('N')).msi")
    try {
        Invoke-WebRequest -Uri $assets[0].browser_download_url -OutFile $path -UseBasicParsing -ErrorAction Stop
        if ($assets[0].digest -match '^sha256:([a-fA-F0-9]{64})$') {
            if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ine $Matches[1]) { throw 'Copilot MSI 해시가 일치하지 않습니다.' }
        }
        $signature = Get-AuthenticodeSignature -LiteralPath $path
        if ($signature.Status -ne 'Valid' -or
            $signature.SignerCertificate.Subject -notmatch '(CN|O)="?GitHub(,? Inc\.?)?"?(,|$)') {
            throw 'Copilot MSI의 유효한 GitHub 서명을 확인하지 못했습니다.'
        }
        $process = Start-Process -FilePath (Join-Path $env:SystemRoot 'System32\msiexec.exe') `
            -ArgumentList "/i `"$path`" /passive /norestart" -Wait -PassThru -ErrorAction Stop
        if ($process.ExitCode -in @(1641, 3010)) { $script:VmRestartRequired = $true; return $false }
        if ($process.ExitCode -ne 0) { throw "Copilot app MSI 설치 실패 (종료 코드 $($process.ExitCode))." }
        $installed = Get-VmCopilotVersion
        if (-not $installed -or $installed -lt $expectedVersion) { throw 'Copilot app 설치 후 버전 확인에 실패했습니다.' }
        Write-Host "[PASS] GitHub Copilot app $installed. 로그인과 플러그인 설치는 직접 진행하세요."
        return $true
    }
    finally {
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force -ErrorAction Stop }
    }
}

function Test-VmCommand {
    param([string]$Name, [string[]]$Arguments = @('--version'))
    $probe = Invoke-ToolProbe $Name $Arguments
    return $probe.Code -eq 0 -and -not [string]::IsNullOrWhiteSpace($probe.Text)
}

function Test-VmDesktopApp {
    param([string[]]$Paths)
    return @($Paths | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf }).Count -gt 0
}

function Test-VmFrameworkTools {
    $framework = Join-Path ${env:ProgramFiles(x86)} 'Reference Assemblies\Microsoft\Framework\.NETFramework\v4.8\mscorlib.dll'
    if (-not (Test-Path -LiteralPath $framework)) { throw '.NET Framework 4.8 Targeting Pack이 없습니다.' }
    if (-not (Get-DotnetFrameworkBuildTools)) { throw 'MSBuild 또는 Framework 웹 빌드 도구가 없습니다.' }
    if (-not (Get-WorkshopIisExpress)) { throw 'IIS Express를 찾지 못했습니다.' }
    $localDb = Get-Command SqlLocalDB.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    $candidates = @()
    if ($localDb) { $candidates += $localDb.Source }
    foreach ($version in @('170', '160', '150')) {
        $candidates += Join-Path $env:ProgramFiles "Microsoft SQL Server\$version\Tools\Binn\SqlLocalDB.exe"
    }
    $found = $false
    foreach ($path in $candidates) {
        if ((Test-Path -LiteralPath $path) -and (Test-VmCommand $path @('versions'))) { $found = $true; break }
    }
    if (-not $found) { throw 'SQL Server LocalDB 버전을 확인하지 못했습니다.' }
    Write-Host '[PASS] Framework 4.8 Targeting Pack, 웹 빌드 도구, IIS Express, LocalDB를 확인했습니다.'
    return $true
}

function Invoke-VmToolInstallation {
    $script:VmRestartRequired = $false
    if (Test-VmRebootPending) {
        Write-Host '[MANUAL] Windows 재부팅이 대기 중입니다. 직접 재부팅한 뒤 다시 실행하세요.'
        return 3010
    }
    $drive = Get-PSDrive -Name $env:SystemDrive.TrimEnd(':') -ErrorAction Stop
    if ($drive.Free -lt 50GB) { throw '설치 전 시스템 드라이브의 여유 공간을 50 GiB 이상 확보하세요.' }
    $steps = @(
        @{ Name='Ubuntu WSL2'; Run={ Install-VmUbuntu } },
        @{ Name='MSMQ'; Run={ Install-VmMsmq } },
        @{ Name='.NET Framework'; Run={
            Install-VmPackage Microsoft.DotNet.Framework.Runtime '.NET Framework 4.8.x 런타임' `
                -VersionPattern '^4\.8\.1$' -TestInstalled { Test-VmFrameworkRuntime }
        } },
        @{ Name='Git'; Run={ Install-VmPackage Git.Git Git -TestInstalled { Test-VmCommand git } } },
        @{ Name='GitHub CLI'; Run={ Install-VmPackage GitHub.cli 'GitHub CLI' -TestInstalled { Test-VmCommand gh } } },
        @{ Name='nvm and Node.js'; Run={ Install-VmNvm } },
        @{ Name='Azure CLI'; Run={ Install-VmPackage Microsoft.AzureCLI 'Azure CLI' -TestInstalled { Test-VmCommand az } } },
        @{ Name='azd'; Run={ Install-VmPackage Microsoft.Azd azd -TestInstalled { Test-VmCommand azd @('version') } } },
        @{ Name='.NET 10 SDK'; Run={
            if (-not (Install-WorkshopDotnetSdk)) { return $false }
            $probe = Invoke-ToolProbe dotnet @('--list-sdks')
            $probe.Code -eq 0 -and $probe.Text -match '(?m)^10\.\d+\.\d+\s+\['
        } },
        @{ Name='Visual Studio Community'; Run={ Install-VmVisualStudio Community (Join-Path $PSScriptRoot 'visualstudio.vsconfig') } },
        @{ Name='Visual Studio Build Tools'; Run={ Install-VmVisualStudio BuildTools (Join-Path $PSScriptRoot 'buildtools.vsconfig') } },
        @{ Name='Framework build and run tools'; Run={ Test-VmFrameworkTools } },
        @{ Name='VS Code'; Run={
            Install-VmPackage Microsoft.VisualStudioCode 'VS Code' -TestInstalled {
                Test-VmDesktopApp @((Join-Path $env:LOCALAPPDATA 'Programs\Microsoft VS Code\Code.exe'),
                    (Join-Path $env:ProgramFiles 'Microsoft VS Code\Code.exe'))
            }
        } },
        @{ Name='GitHub Copilot app'; Run={ Install-VmCopilot } },
        @{ Name='Docker Desktop'; Run={
            Install-VmPackage Docker.DockerDesktop 'Docker Desktop (WSL2 백엔드)' -TestInstalled {
                Test-VmDesktopApp @((Join-Path $env:ProgramFiles 'Docker\Docker\Docker Desktop.exe'))
            } -ExtraArguments @('--override', 'install --backend=wsl-2')
        } }
    )
    $failed = $false
    foreach ($step in $steps) {
        try {
            if (-not (& $step.Run)) { $failed = $true; Write-Host "[MANUAL] $($step.Name) 준비가 완료되지 않았습니다." }
        }
        catch {
            $failed = $true
            Write-Host "[FAIL] $($step.Name): $($_.Exception.Message)"
        }
        if ($script:VmRestartRequired -or (Test-VmRebootPending)) {
            Write-Host '[MANUAL] 재부팅이 필요합니다. 자동 재부팅하지 않습니다. 재부팅 후 같은 명령을 다시 실행하세요.'
            return 3010
        }
    }
    Write-Host '[MANUAL] Ubuntu 최초 사용자 설정, Docker Desktop 시작과 Linux 컨테이너 확인, Copilot 로그인과 플러그인 설정을 직접 진행하세요.'
    Write-Host '[INFO] Azure/GitHub 로그인, 구독 변경, 공급자 등록, 실습 DB 생성은 실행하지 않았습니다.'
    if ($failed) { return 1 }
    Write-Host '[PASS] 도구 설치 상태를 확인했습니다. 실제 앱 빌드와 VM 런타임 검증은 별도로 진행하세요.'
    return 0
}

if ($MyInvocation.InvocationName -eq '.') {
    if ($PSVersionTable.PSVersion.Major -lt 7) { throw 'Dot-sourcing requires PowerShell 7. Run this script normally from Windows PowerShell 5.1.' }
}
elseif ($Help) {
    Write-Host 'appmoduser의 관리자 터미널: powershell.exe -NoProfile -File "$HOME\scripts\install-vm-tools.ps1"'
    Write-Host '항목별 동의가 필요합니다. 재부팅 후 같은 명령을 다시 실행하세요. 자동 로그인이나 Azure 배포는 하지 않습니다.'
}
else {
    $ErrorActionPreference = 'Stop'
    try {
        $helpers = Get-VmHelperDirectory
        . (Join-Path $helpers 'powershell-bootstrap.ps1')
        Assert-VmInstallerContext
        $script:VmRestartRequired = $false
        if (Test-VmRebootPending) { Write-Host '[MANUAL] 직접 재부팅한 뒤 다시 실행하세요.'; exit 3010 }
        if (-not (Initialize-VmWinget)) { Write-Host '[MANUAL] winget 준비를 완료하지 않았습니다.'; exit 1 }
        if (-not (Install-VmPackage Microsoft.PowerShell 'PowerShell 7.x' -VersionPattern '^7\.\d+\.\d+$' -TestInstalled { Test-VmPowerShell7 })) {
            if ($script:VmRestartRequired) { exit 3010 }
            exit 1
        }
        $bootstrap = Initialize-WorkshopScript -ScriptPath $PSCommandPath -BoundParameters @{ Track='dotnet' } `
            -RemainingArguments @() -AllowInstall
        if ($bootstrap.Handled) { exit $bootstrap.Code }
        if ($PSVersionTable.PSVersion.Major -ne 7) { throw 'PowerShell 7.x에서 실행하세요.' }
        . (Join-Path $helpers 'install-prerequisites.ps1') -Track dotnet
        exit (Invoke-VmToolInstallation)
    }
    catch {
        Write-Error "[FAIL] $($_.Exception.Message)" -ErrorAction Continue
        exit 1
    }
}
