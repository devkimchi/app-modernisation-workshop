[CmdletBinding()]
param([string]$CompiledTemplate)

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
. (Join-Path $root 'scripts\powershell-bootstrap.ps1')
$bootstrap = Initialize-WorkshopScript -ScriptPath $PSCommandPath -BoundParameters $PSBoundParameters `
    -RemainingArguments @() -DotSourced ($MyInvocation.InvocationName -eq '.')
if ($bootstrap.Handled) { exit $bootstrap.Code }

. (Join-Path $root 'infra\scripts\preprovision.ps1')
. (Join-Path $root 'infra\scripts\stage-user-scripts.ps1')
. (Join-Path $root 'infra\scripts\install-vm-tools.ps1')
$script:Passed = 0
function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "FAILED: $Message" }
    $script:Passed++
}
function Assert-Throws([scriptblock]$Action, [string]$Pattern, [string]$Message) {
    $caught = $null
    try { & $Action | Out-Null }
    catch { $caught = $_.Exception.Message }
    Assert-True ($null -ne $caught -and $caught -match $Pattern) "$Message ($caught)"
}

$fixture = Join-Path ([IO.Path]::GetTempPath()) ("appmod-vm-test-" + [guid]::NewGuid().ToString('N'))
$null = [IO.Directory]::CreateDirectory($fixture)
try {
    $sources = Get-VmPayloadSources
    $bundle = New-VmPayload $sources
    $payload = Expand-VmPayload $bundle.content
    Assert-True ($payload.files.Count -eq $sources.Count) 'payload contains every required file'
    Assert-True ($bundle.content.Length -le 90000) 'compressed payload stays below inline limit'
    foreach ($file in $payload.files) {
        Assert-True ((Get-VmBytesHash ([Convert]::FromBase64String($file.content))) -eq
            (Get-VmBytesHash ([IO.File]::ReadAllBytes($sources[$file.name])))) "byte-exact delivery: $($file.name)"
    }
    Assert-Throws { Expand-VmPayload 'not base64' } '.' 'invalid compressed payload fails'
    $large = Join-Path $fixture 'large.ps1'
    [IO.File]::WriteAllBytes($large, (New-Object byte[] 1048576))
    Assert-Throws { New-VmPayload @{ 'large.ps1'=$large } } 'limit' 'oversized payload fails before compression'

    $profile = Join-Path $fixture 'profile with spaces'
    $null = [IO.Directory]::CreateDirectory($profile)
    Write-VmUserFiles $profile $payload
    Write-VmUserFiles $profile $payload
    Assert-True ((Get-ChildItem (Join-Path $profile 'scripts') -File).Count -eq $sources.Count) 'same payload is idempotent'
    & {
        . (Join-Path $profile 'scripts\install-vm-tools.ps1')
        $helpers = Get-VmHelperDirectory
        . (Join-Path $helpers 'install-prerequisites.ps1') -Track dotnet
        Assert-True ($helpers -eq (Join-Path $profile 'scripts') -and
            [bool](Get-Command Install-WorkshopNode -CommandType Function)) 'delivered flat layout loads all shared dependencies'
    }
    $modified = Join-Path $profile 'scripts\install-vm-tools.ps1'
    [IO.File]::WriteAllText($modified, 'user edit')
    Assert-Throws { Write-VmUserFiles $profile $payload } 'Preserving different' 'user edits are never overwritten'
    Assert-True ([IO.File]::ReadAllText($modified) -eq 'user edit') 'conflicting content remains intact'
    $badPayload = [pscustomobject]@{ files=@([pscustomobject]@{name='..\escape.ps1';content='YQ=='}) }
    Assert-Throws { Write-VmUserFiles $profile $badPayload } 'Invalid' 'path traversal is rejected'
    $duplicate = [pscustomobject]@{ files=@(
        [pscustomobject]@{name='a.ps1';content='YQ=='},
        [pscustomobject]@{name='A.ps1';content='Yg=='}
    ) }
    Assert-Throws { Write-VmUserFiles $profile $duplicate } 'duplicate' 'case-insensitive duplicate names fail'
    Assert-True (-not (Test-Path (Join-Path $profile 'scripts\a.ps1'))) 'conflicts are checked before writing'
    if ($IsWindows) {
        $junction = Join-Path $fixture 'junction'
        $null = New-Item -ItemType Junction -Path $junction -Target $profile
        Assert-Throws { Write-VmUserFiles $junction $payload } 'reparse' 'profile junctions are rejected'
        Remove-Item -LiteralPath $junction -Force
    }

    & {
        $script:Created = 0
        $script:HasProfile = $false
        function Get-LocalUser { [pscustomobject]@{ Enabled=$true; SID=[pscustomobject]@{ Value='S-1-5-21-123-456-789-1001' } } }
        function Get-LocalGroupMember { [pscustomobject]@{ SID=[pscustomobject]@{ Value='S-1-5-21-123-456-789-1001' } } }
        function Get-VmProfilePath { if ($script:HasProfile) { return $profile } }
        function New-VmUserProfile {
            param($Sid,$Username)
            Assert-True ($Sid -eq 'S-1-5-21-123-456-789-1001' -and $Username -eq 'appmoduser') 'profile API receives target SID and account'
            $script:Created++
            $script:HasProfile=$true
        }
        Assert-True ((Resolve-VmUserProfile) -eq $profile) 'new profile uses resolved path, not SYSTEM HOME'
        Assert-True ((Resolve-VmUserProfile) -eq $profile -and $script:Created -eq 1) 'existing profile does not call CreateProfile'
        $script:HasProfile = $false
        function New-VmUserProfile { throw 'fixture CreateProfile failure' }
        Assert-Throws { Resolve-VmUserProfile } 'CreateProfile failure' 'profile creation failure propagates'
        function Get-LocalGroupMember { @() }
        Assert-Throws { Resolve-VmUserProfile } 'not a local administrator' 'administrator membership is required'
    }

    & {
        $script:Installs = 0
        function Confirm-VmAction { return $false }
        function Invoke-VmInstaller { $script:Installs++; throw 'must not run' }
        Assert-True (-not (Install-VmPackage Fixture.Package Fixture -TestInstalled { $false })) 'declined package stays incomplete'
        Assert-True ($script:Installs -eq 0) 'decline never launches installer'
        Assert-True (Install-VmPackage Fixture.Package Fixture -TestInstalled { $true }) 'existing tool is kept without consent or install'
        function Confirm-VmAction { return $true }
        function Get-VmWingetVersion { param($Id,$VersionPattern); return '2.0.1' }
        function Update-ProcessPath { }
        function Invoke-VmInstaller {
            param($Command,$Arguments)
            $script:Installs++
            Assert-True ($Command -eq 'winget' -and $Arguments -contains '--version' -and $Arguments -contains '2.0.1') 'major-constrained version is pinned'
            return $true
        }
        $script:VmRestartRequired=$false
        Assert-Throws {
            Install-VmPackage Fixture.Package Fixture -VersionPattern '^2\.\d+\.\d+$' -TestInstalled { $false }
        } 'after installation' 'exit zero alone is not installation success'
        function Invoke-VmInstaller { throw 'fixture native failure' }
        Assert-Throws { Install-VmPackage Fixture.Package Fixture -TestInstalled { $false } } 'native failure' 'installer failures propagate'
        function Invoke-VmInstaller { $script:VmRestartRequired=$true; return $true }
        Assert-True (-not (Install-VmPackage Fixture.Package Fixture -TestInstalled { $false })) 'reboot-pending install is not marked verified'
    }

    & {
        function winget {
            $global:LASTEXITCODE=0
            "Versions`n3.0.0`n2.0.0`n2.0.1`n2.1.0-preview.1"
        }
        Assert-True ((Get-VmWingetVersion AuthorSoftware.NVMWindows '^2\.\d+\.\d+$') -eq '2.0.1') 'release selection excludes other majors and previews'
        Assert-Throws { Get-VmWingetVersion Fixture.Package '^18\.\d+\.\d+$' } 'No stable' 'missing required major fails'
        function winget { $global:LASTEXITCODE=1; 'fixture lookup failure' }
        Assert-Throws { Get-VmWingetVersion Fixture.Package '^2\.\d+\.\d+$' } 'Failed to query' 'version discovery failure never falls back'
    }

    & {
        function Get-Command { [pscustomobject]@{Source='Invoke-FixtureNative'} }
        function Invoke-FixtureNative { $global:LASTEXITCODE=$script:NativeCode }
        foreach ($code in @(1641,3010)) {
            $script:NativeCode=$code; $script:VmRestartRequired=$false
            Assert-True (Invoke-VmInstaller fixture @()) "installer code $code is handled"
            Assert-True $script:VmRestartRequired "installer code $code requires manual restart"
        }
        $script:NativeCode=0; $script:VmRestartRequired=$false
        Assert-True (Invoke-VmInstaller fixture @()) 'native exit zero is handled'
        $script:NativeCode=42
        Assert-Throws { Invoke-VmInstaller fixture @() } '42' 'nonzero native status fails explicitly'
    }

    & {
        function Test-WorkshopBootstrapInteractive { return $false }
        function Read-Host { throw 'must not prompt' }
        Assert-True (-not (Confirm-VmAction 'fixture')) 'noninteractive mode cannot consent'
        Assert-Throws { Assert-VmInstallerContext } 'non-interactive|Windows x64' 'noninteractive identity guard runs before installation'
        function Test-WorkshopBootstrapInteractive { return $true }
        function Get-LocalUser { [pscustomobject]@{SID=[pscustomobject]@{Value='S-1-5-21-123-456-789-1001'}} }
        Assert-Throws { Assert-VmInstallerContext } 'Sign in as appmoduser|Windows x64' 'another Windows account cannot install tools'
    }

    & {
        $script:Registered=$false
        function Get-Command { if ($script:Registered) { [pscustomobject]@{Source='fixture-winget.exe'} } }
        function Get-AppxPackage { [pscustomobject]@{Name='Microsoft.DesktopAppInstaller'} }
        function Confirm-VmAction { return $false }
        function Add-AppxPackage { throw 'must not register before consent' }
        Assert-True (-not (Initialize-VmWinget)) 'App Installer registration requires consent'
        function Confirm-VmAction { return $true }
        function Add-AppxPackage {
            param([switch]$RegisterByFamilyName,$MainPackage,$ErrorAction)
            Assert-True ($RegisterByFamilyName -and $MainPackage -eq 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe') 'registers the official App Installer family'
            $script:Registered=$true
        }
        Assert-True (Initialize-VmWinget) 'WinGet registration is rechecked'
        $script:Registered=$false
        function Get-AppxPackage { return $null }
        function Get-PackageProvider { return $null }
        function Confirm-VmAction { return $false }
        function Install-PackageProvider { throw 'must not install provider without consent' }
        Assert-True (-not (Initialize-VmWinget)) 'WinGet recovery provider requires separate consent'
    }

    & {
        function Get-VmWslExecutable { 'fixture-wsl.exe' }
        $script:FeatureState='Enabled'; $script:StatusCode=0
        function Get-WindowsOptionalFeature { [pscustomobject]@{ State=$script:FeatureState } }
        function Invoke-ToolProbe {
            param($Name,$Arguments)
            Assert-True ($Name -eq 'fixture-wsl.exe' -and ($Arguments -join ' ') -eq '--status') 'WSL2 platform probe is read-only'
            [pscustomobject]@{ Code=$script:StatusCode; Text='' }
        }
        Assert-True (Test-VmWslPlatform) 'enabled platform with working wsl.exe is ready'
        $script:StatusCode=1
        Assert-True (-not (Test-VmWslPlatform)) 'failed wsl.exe status is not ready'
        $script:FeatureState='Disabled'; $script:StatusCode=0
        Assert-True (-not (Test-VmWslPlatform)) 'disabled VirtualMachinePlatform is not ready'
    }

    & {
        $script:Platform=$false; $script:FeatureState='Disabled'; $script:PlatformInstalls=0
        function Test-VmWslPlatform { $script:Platform }
        function Get-WindowsOptionalFeature { [pscustomobject]@{ State=$script:FeatureState } }
        function Get-VmWslExecutable { 'C:\Windows\System32\wsl.exe' }
        function Confirm-VmAction { return $false }
        function Invoke-VmInstaller { throw 'must not install without consent' }
        Assert-True (-not (Install-VmWslPlatform)) 'WSL2 platform decline is preserved'
        function Confirm-VmAction { return $true }
        function Invoke-VmInstaller {
            param($Command,$Arguments)
            Assert-True ($Command -like '*wsl.exe' -and ($Arguments -join ' ') -eq '--install --no-distribution') 'WSL2 platform installs without a distribution'
            $script:PlatformInstalls++; return $true
        }
        $script:VmRestartRequired=$false
        Assert-True (-not (Install-VmWslPlatform)) 'WSL2 platform awaiting activation stays incomplete'
        Assert-True $script:VmRestartRequired 'WSL2 platform installation requires a manual restart'
        $script:FeatureState='EnablePending'; $script:VmRestartRequired=$false
        Assert-True (-not (Install-VmWslPlatform) -and $script:VmRestartRequired -and $script:PlatformInstalls -eq 1) 'pending platform activation is not reinstalled'
        $script:Platform=$true; $script:VmRestartRequired=$false
        Assert-True ((Install-VmWslPlatform) -and $script:PlatformInstalls -eq 1) 'ready WSL2 platform is preserved'
    }

    & {
        $script:WslVersion=0; $script:WslCalls=0
        function Test-VmWslPlatform { return $false }
        function Get-VmUbuntuVersion { throw 'must not query distributions before the platform is ready' }
        Assert-True (-not (Install-VmUbuntu)) 'Ubuntu waits for the WSL2 platform'
        function Test-VmWslPlatform { return $true }
        function Get-VmUbuntuVersion { $script:WslVersion }
        function Confirm-VmAction { return $false }
        function Invoke-VmInstaller { throw 'must not install without consent' }
        Assert-True (-not (Install-VmUbuntu)) 'Ubuntu decline is preserved'
        function Confirm-VmAction { return $true }
        function Invoke-VmInstaller {
            param($Command,$Arguments)
            Assert-True ($Command -eq 'wsl.exe' -and ($Arguments -join ' ') -eq '--install --distribution Ubuntu --no-launch') 'Ubuntu installs without auto-launch or user deletion'
            $script:WslVersion=2; $script:WslCalls++; return $true
        }
        $script:VmRestartRequired=$false
        Assert-True (Install-VmUbuntu) 'Ubuntu installation is checked'
        Assert-True (Install-VmUbuntu) 'existing Ubuntu WSL2 is preserved'
        Assert-True ($script:WslCalls -eq 1) 'Ubuntu is not reinstalled'
        $script:WslVersion=1
        Assert-Throws { Install-VmUbuntu } 'WSL1' 'existing WSL1 is not destructively replaced'
    }

    & {
        function Get-WindowsOptionalFeature { [pscustomobject]@{ State='Disabled' } }
        function Confirm-VmAction { return $true }
        function Enable-WindowsOptionalFeature {
            param([switch]$Online,$FeatureName,[switch]$All,[switch]$NoRestart,$ErrorAction)
            Assert-True ($FeatureName -eq 'MSMQ-Server' -and $NoRestart) 'MSMQ uses NoRestart'
            [pscustomobject]@{ RestartNeeded=$true }
        }
        $script:VmRestartRequired=$false
        Assert-True (-not (Install-VmMsmq)) 'MSMQ pending reboot stays incomplete'
        Assert-True $script:VmRestartRequired 'MSMQ reports reboot requirement'
    }

    & {
        . (Join-Path $root 'scripts\install-prerequisites.ps1') -Track dotnet
        $script:NodeCalls=0; $script:AutoInstall=$true; $script:Approved=$false
        function Get-Command { [pscustomobject]@{ Source='fixture-nvm.exe' } }
        function Invoke-ToolProbe {
            param($Name,$Arguments)
            switch ($Arguments[0]) {
                'version' { [pscustomobject]@{Code=0;Text='2.0.1'} }
                'config' {
                    if ($Arguments[1] -eq 'set') {
                        Assert-True (($Arguments -join ' ') -eq 'config set auto_install=false') 'nvm uses documented assignment syntax'
                        $script:AutoInstall=$false
                    }
                    [pscustomobject]@{Code=0;Text=(@{ auto_install=$script:AutoInstall } | ConvertTo-Json -Compress)}
                }
                default { throw 'unexpected nvm probe' }
            }
        }
        function Confirm-VmAction { $script:Approved }
        function Get-WorkshopNvmConfiguration { if (-not $script:AutoInstall) { [pscustomobject]@{auto_install=$false} } }
        function Install-WorkshopNode { $script:NodeCalls++; return $true }
        Assert-True (-not (Install-VmNvm)) 'automatic Node installation is not enabled by default'
        Assert-True ($script:NodeCalls -eq 0) 'no Node probes before nvm policy consent'
        $script:Approved=$true
        Assert-True (Install-VmNvm) 'consented nvm preparation uses shared Node installer'
        Assert-True ($script:NodeCalls -eq 1 -and -not $script:AutoInstall) 'nvm auto-install disabled before Node work'
        function Invoke-ToolProbe { [pscustomobject]@{Code=0;Text='1.2.2'} }
        Assert-Throws { Install-VmNvm } 'not replaced automatically' 'nvm 1.x is never silently replaced'
    }

    & {
        function Get-VmVsInstance { return $null }
        function Install-VmPackage {
            param($Id,$Name,$TestInstalled,$VersionPattern,$ExtraArguments)
            Assert-True ($Id -eq 'Microsoft.VisualStudio.Community' -and $VersionPattern -eq '^18\.\d+\.\d+$') 'VS 2026 maps to stable 18.x package'
            Assert-True ($ExtraArguments[0] -eq '--override' -and $ExtraArguments[1] -match '--norestart' -and
                $ExtraArguments[1].Contains('visualstudio.vsconfig')) 'VS configuration and no-restart options are forwarded'
            return $true
        }
        Assert-True (Install-VmVisualStudio Community (Join-Path $root 'infra\scripts\visualstudio.vsconfig')) 'VS installer plans explicit workload config'
    }

    & {
        $script:VsReady=$false
        function Get-VmVsInstance {
            param($Product,$Requires=@())
            if (-not $Requires.Count -or $script:VsReady) { [pscustomobject]@{installationPath='C:\fixture with spaces\VS'} }
        }
        function Confirm-VmAction { return $true }
        function Start-Process {
            param($FilePath,$ArgumentList,[switch]$Wait,[switch]$PassThru,$ErrorAction)
            Assert-True ($ArgumentList -match '^modify ' -and $ArgumentList.Contains('"C:\fixture with spaces\VS"') -and
                $ArgumentList -notmatch '--wait' -and $Wait -and $PassThru) 'existing VS modification quotes paths and waits through Start-Process'
            $script:VsReady=$true
            [pscustomobject]@{ExitCode=0}
        }
        Assert-True (Install-VmVisualStudio BuildTools (Join-Path $root 'infra\scripts\buildtools.vsconfig')) 'existing VS workloads are verified after modification'
    }

    & {
        function Test-Path { return $false }
        Assert-Throws { Test-VmFrameworkTools } 'Targeting Pack' 'Framework runtime alone cannot satisfy build prerequisites'
        function Test-Path {
            param($LiteralPath)
            $LiteralPath.EndsWith('v4.8\mscorlib.dll') -or $LiteralPath.EndsWith('170\Tools\Binn\SqlLocalDB.exe')
        }
        function Get-DotnetFrameworkBuildTools { [pscustomobject]@{MSBuild='fixture'} }
        function Get-WorkshopIisExpress { [pscustomobject]@{Exe='fixture'} }
        function Get-Command { return $null }
        function Test-VmCommand {
            param($Name,$Arguments)
            Assert-True ($Name.EndsWith('170\Tools\Binn\SqlLocalDB.exe') -and ($Arguments -join ' ') -eq 'versions') 'LocalDB fallback only queries versions, never creates a database'
            return $true
        }
        Assert-True (Test-VmFrameworkTools) 'LocalDB is detected even before PATH refresh'
    }

    & {
        function Get-VmCopilotVersion { return $null }
        function Confirm-VmAction { return $false }
        function Invoke-RestMethod { throw 'must not download without consent' }
        Assert-True (-not (Install-VmCopilot)) 'Copilot consent precedes release discovery'
        function Get-VmCopilotVersion { return [version]'1.3.0' }
        Assert-True (Install-VmCopilot) 'existing Copilot app is preserved'
    }

    & {
        $script:CopilotVersion=$null; $script:MsiCalls=0; $script:SignatureStatus='Valid'
        function Get-VmCopilotVersion { $script:CopilotVersion }
        function Confirm-VmAction { return $true }
        function Invoke-RestMethod {
            [pscustomobject]@{ tag_name='v1.3.0'; prerelease=$false; draft=$false; assets=@(
                [pscustomobject]@{ name='GitHub-Copilot-windows-x64.msi'
                    browser_download_url='https://github.com/github/app/releases/download/v1.3.0/GitHub-Copilot-windows-x64.msi'
                    digest='sha256:ca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb'
                }
            ) }
        }
        function Invoke-WebRequest {
            param($Uri,$OutFile,[switch]$UseBasicParsing,$ErrorAction)
            $script:DownloadedMsi=$OutFile
            [IO.File]::WriteAllBytes($OutFile,[byte[]]@(97))
        }
        function Get-AuthenticodeSignature {
            [pscustomobject]@{Status=$script:SignatureStatus; SignerCertificate=[pscustomobject]@{Subject='CN="GitHub, Inc.", O="GitHub, Inc.", C=US'}}
        }
        function Start-Process {
            param($FilePath,$ArgumentList,[switch]$Wait,[switch]$PassThru,$ErrorAction)
            Assert-True ($ArgumentList.Contains("/i `"$script:DownloadedMsi`" /passive /norestart") -and $Wait) 'Copilot MSI path is quoted and automatic restart disabled'
            $script:MsiCalls++; $script:CopilotVersion=[version]'1.3.0'
            [pscustomobject]@{ExitCode=0}
        }
        Assert-True (Install-VmCopilot) 'Copilot verifies digest, signature and installed version'
        Assert-True (-not (Test-Path -LiteralPath $script:DownloadedMsi)) 'successful MSI download is cleaned up'
        $script:CopilotVersion=$null; $script:SignatureStatus='NotSigned'
        Assert-Throws { Install-VmCopilot } 'signature' 'unsigned MSI never executes'
        Assert-True ($script:MsiCalls -eq 1 -and -not (Test-Path -LiteralPath $script:DownloadedMsi)) 'failed MSI verification cleans up without execution'
    }

    & {
        function Test-VmRebootPending { return $true }
        function Get-PSDrive { throw 'must not proceed before reboot' }
        Assert-True ((Invoke-VmToolInstallation) -eq 3010) 'reboot-required entry exits before further work'
        function Test-VmRebootPending { return $false }
        function Get-PSDrive { [pscustomobject]@{Free=100GB} }
        function Install-VmWslPlatform { $script:VmRestartRequired=$true; return $false }
        function Install-VmUbuntu { throw 'must not run after reboot boundary' }
        Assert-True ((Invoke-VmToolInstallation) -eq 3010) 'new reboot requirement stops subsequent installation steps'
    }

    $staging = [IO.File]::ReadAllText((Join-Path $root 'infra\scripts\stage-user-scripts.ps1')).Replace('__PAYLOAD_BASE64__', $bundle.content)
    $tokens=$null; $errors=$null
    $null = [Management.Automation.Language.Parser]::ParseInput($staging, [ref]$tokens, [ref]$errors)
    Assert-True ($errors.Count -eq 0) 'generated inline staging script parses'
    Assert-True ([Text.Encoding]::UTF8.GetByteCount($staging) -lt 131072) 'inline script remains below ARM string result limit'
    if ($IsWindows) {
        $installer = Join-Path $root 'infra\scripts\install-vm-tools.ps1'
        & powershell.exe -NoProfile -NonInteractive -File $installer -Help | Out-Host
        Assert-True ($LASTEXITCODE -eq 0) 'Windows PowerShell 5.1 can parse installer and show help'
        & powershell.exe -NoProfile -NonInteractive -File $installer 2>&1 | Out-Host
        Assert-True ($LASTEXITCODE -eq 1) 'real 5.1 noninteractive entry refuses installation'
        $escaped = $installer.Replace("'", "''")
        & powershell.exe -NoProfile -NonInteractive -Command "try { . '$escaped'; exit 99 } catch { Write-Output 'expected dot-source rejection'; exit 0 }" | Out-Host
        Assert-True ($LASTEXITCODE -eq 0) '5.1 dot-sourcing throws without exiting caller'
        $inlineFile = Join-Path $fixture 'inline.ps1'
        [IO.File]::WriteAllText($inlineFile,$staging,[Text.UTF8Encoding]::new($true))
        $parserCommand = '$t=$null; $e=$null; [void][Management.Automation.Language.Parser]::ParseFile(''' +
            $inlineFile.Replace("'", "''") + ''',[ref]$t,[ref]$e); if($e.Count){$e;exit 1}'
        & powershell.exe -NoProfile -NonInteractive -Command $parserCommand | Out-Host
        Assert-True ($LASTEXITCODE -eq 0) 'generated inline script parses in Windows PowerShell 5.1'
    }

    if ($CompiledTemplate) {
        $template = Get-Content -LiteralPath $CompiledTemplate -Raw | ConvertFrom-Json
        Assert-True ($template.parameters.adminPassword.type -eq 'secureString' -and
            -not ($template.parameters.adminPassword.PSObject.Properties.Name -contains 'defaultValue')) 'password is prompted and secure'
        Assert-True ($template.parameters.confirmWindowsClientLicense.allowedValues.Count -eq 1 -and
            $template.parameters.confirmWindowsClientLicense.allowedValues[0] -eq $true) 'license refusal cannot provision'
        $raw = [IO.File]::ReadAllText($CompiledTemplate)
        Assert-True ($raw -notmatch 'AADLoginForWindows|roleAssignments|principalId|runAsPassword') 'no Entra login or copied administrator secrets'
        $workstation = @($template.resources | Where-Object name -eq 'workstation')[0].properties.template
        $vm = @($workstation.resources | Where-Object type -eq 'Microsoft.Compute/virtualMachines')[0]
        Assert-True ($vm.properties.osProfile.adminUsername -eq 'appmoduser') 'local admin username cannot vary'
        Assert-True ($vm.properties.securityProfile.uefiSettings.secureBootEnabled -and
            $vm.properties.securityProfile.uefiSettings.vTpmEnabled) 'Windows 11 secure boot and TPM preserved'
        $schedule = @($workstation.resources | Where-Object type -eq 'Microsoft.DevTestLab/schedules')[0]
        Assert-True (-not ($schedule.PSObject.Properties.Name -contains 'condition') -and
            $schedule.properties.status -eq "[if(parameters('autoShutdownEnabled'), 'Enabled', 'Disabled')]") 'disabling shutdown updates an existing schedule instead of leaving it active'
        $scripts = @($template.resources | Where-Object name -eq 'user-scripts')[0].properties.template
        $delivery = @($scripts.resources | Where-Object type -eq 'Microsoft.Compute/virtualMachines/runCommands')[0]
        Assert-True ($delivery.properties.treatFailureAsDeploymentFailure -and -not $delivery.properties.asyncExecution) 'staging failure fails synchronous deployment'
    }
    Write-Host "[PASS] VM infrastructure and installer checks: $script:Passed"
}
finally {
    Remove-Item -LiteralPath $fixture -Recurse -Force
}
