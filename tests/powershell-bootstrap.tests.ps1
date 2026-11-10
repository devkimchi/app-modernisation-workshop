. (Join-Path $PSScriptRoot '..\scripts\powershell-bootstrap.ps1')
# Regression entrypoints mock the host platform; they never enable OS features.
function Test-WorkshopWsl2 { return $true }
$bootstrap = Initialize-WorkshopScript -ScriptPath $PSCommandPath -BoundParameters @{} -RemainingArguments $args -DotSourced ($MyInvocation.InvocationName -eq '.')
if ($bootstrap.Handled) { exit $bootstrap.Code }
# Restore the real probe for the targeted mocks below.
. (Join-Path $PSScriptRoot '..\scripts\powershell-bootstrap.ps1')

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$script:Passed = 0
function Assert-Bootstrap([bool]$Condition, [string]$Name) {
    if (-not $Condition) { throw "FAILED: $Name" }
    $script:Passed++
}
$fixture = Join-Path $root ('.test-output\bootstrap-' + [guid]::NewGuid().ToString('N'))
$encoding = [Text.UTF8Encoding]::new($true)
$savedCI = $env:CI
$savedEngine = $env:AZD_CONTAINER_RUNTIME
try {
    $env:AZD_CONTAINER_RUNTIME = ''
    $null = [IO.Directory]::CreateDirectory($fixture)
    foreach ($file in Get-ChildItem (Join-Path $root 'scripts'),(Join-Path $root 'tests') -Filter '*.ps1') {
        $bytes = [IO.File]::ReadAllBytes($file.FullName)
        Assert-Bootstrap ($bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191) "UTF-8 BOM: $($file.Name)"
        Assert-Bootstrap (-not [IO.File]::ReadAllText($file.FullName).Contains("`r")) "LF: $($file.Name)"
    }

    & {
        function Get-Command { [CmdletBinding()]param($Name, $CommandType, [switch]$All) }
        function Test-Path { [CmdletBinding()]param($LiteralPath, $PathType); return $LiteralPath -eq (Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe') }
        function Test-WorkshopPowerShellExecutable { param($Path); return $true }
        if ($env:ProgramFiles) {
            Assert-Bootstrap ((Find-WorkshopPowerShell) -eq (Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe')) 'find installed executable outside PATH'
        }
    }

    & {
        $script:FeatureState = 1
        $script:WslStatus = 0
        $script:WslCalls = 0
        function Get-WorkshopWslExecutable { return 'mock-wsl' }
        function Get-CimInstance { [CmdletBinding()]param($ClassName, $Filter); return [pscustomobject]@{ InstallState = $script:FeatureState } }
        function mock-wsl {
            Assert-Bootstrap (($args -join ' ') -eq '--status') 'platform detection does not require or start a distro'
            $script:WslCalls++
            $global:LASTEXITCODE = $script:WslStatus
        }
        Assert-Bootstrap (Test-WorkshopWsl2) 'enabled platform and working WSL status accepted'
        $script:FeatureState = 2
        Assert-Bootstrap (-not (Test-WorkshopWsl2)) 'WSL1 executable without VirtualMachinePlatform rejected'
        Assert-Bootstrap ($script:WslCalls -eq 1) 'disabled platform detected without launching WSL'
        $script:FeatureState = 1
        $script:WslStatus = 1
        Assert-Bootstrap (-not (Test-WorkshopWsl2)) 'unusable kernel/status rejected'
        function Get-WorkshopWslExecutable { }
        Assert-Bootstrap (-not (Test-WorkshopWsl2)) 'missing wsl executable rejected'
    }

    & {
        $script:InstallCount = 0
        $script:Interactive = $false
        $script:Approved = $false
        $script:WslCode = 0
        function Test-WorkshopBootstrapInteractive { return $script:Interactive }
        function Confirm-WorkshopWsl2Install { return $script:Approved }
        function Get-WorkshopWslExecutable { return 'mock-wsl' }
        function mock-wsl {
            Assert-Bootstrap (($args -join ' ') -eq '--install --no-distribution') 'WSL installation changes platform only, no distro or reboot'
            $script:InstallCount++
            $global:LASTEXITCODE = $script:WslCode
        }
        Assert-Bootstrap (-not (Install-WorkshopWsl2)) 'noninteractive WSL install denied'
        $script:Interactive = $true
        Assert-Bootstrap (-not (Install-WorkshopWsl2)) 'declined WSL install denied'
        Assert-Bootstrap ($script:InstallCount -eq 0) 'declined/noninteractive WSL install has no side effects'
        $script:Approved = $true
        Assert-Bootstrap (Install-WorkshopWsl2) 'separately approved WSL install requested'
        $script:WslCode = 3010
        Assert-Bootstrap (Install-WorkshopWsl2) 'WSL reboot-required status handled'
        $script:WslCode = 1
        Assert-Bootstrap (-not (Install-WorkshopWsl2)) 'WSL installer failure propagated'
    }

    & {
        $script:PowerShellPresent = $false
        $script:WslPresent = $false
        $script:BootstrapInstalls = [Collections.Generic.List[string]]::new()
        function Get-WorkshopHostPrerequisites {
            return [pscustomobject]@{ Windows = $true; PowerShell = $(if ($script:PowerShellPresent) { 'mock-pwsh' }); Wsl2 = $script:WslPresent }
        }
        function Install-WorkshopPowerShell { $script:BootstrapInstalls.Add('PowerShell'); $script:PowerShellPresent = $true }
        function Install-WorkshopWsl2 { $script:BootstrapInstalls.Add('WSL2'); $script:WslPresent = $true; return $true }
        foreach ($state in @(@($false,$false), @($true,$false), @($false,$true))) {
            $script:PowerShellPresent = $state[0]
            $script:WslPresent = $state[1]
            $result = Initialize-WorkshopScript -ScriptPath 'not-run.ps1' -BoundParameters @{ Track = 'dotnet' }
            Assert-Bootstrap ($result.Handled -and $result.Code -eq 1) 'either missing prerequisite blocks .NET before main'
        }
        Assert-Bootstrap ($script:BootstrapInstalls.Count -eq 0) 'normal preflight never installs anything'
        $script:PowerShellPresent = $false
        $script:WslPresent = $false
        $result = Initialize-WorkshopScript -ScriptPath 'not-run.ps1' -BoundParameters @{ Track = 'java' } -AllowInstall
        Assert-Bootstrap (($script:BootstrapInstalls -join ',') -eq 'PowerShell,WSL2') 'installer checks both missing prerequisites independently'
        Assert-Bootstrap ($result.Handled -and $result.Code -eq 1) 'WSL installation stops before main until manual restart/recheck'
        $result = Initialize-WorkshopScript -ScriptPath 'not-run.ps1' -BoundParameters @{ Track = 'dotnet' }
        Assert-Bootstrap (-not $result.Handled) 'ready PS7 host continues without delegation or recursion'
        $script:PowerShellPresent = $false
        $script:WslPresent = $false
        $script:BootstrapInstalls.Clear()
        $null = Initialize-WorkshopScript -ScriptPath 'not-run.ps1' -BoundParameters @{ Track = 'java'; Help = $true } -AllowInstall
        $null = Initialize-WorkshopScript -ScriptPath 'not-run.ps1' -BoundParameters @{ Track = 'invalid' } -AllowInstall
        $null = Initialize-WorkshopScript -ScriptPath 'not-run.ps1' -BoundParameters @{ Track = 'dotnet'; ContainerEngine = 'invalid' } -AllowInstall
        Assert-Bootstrap ($script:BootstrapInstalls.Count -eq 0) 'help and invalid arguments never install prerequisites'
        $env:AZD_CONTAINER_RUNTIME = 'podman'
        $result = Initialize-WorkshopScript -ScriptPath 'not-run.ps1' -BoundParameters @{ Track = 'dotnet'; ContainerEngine = 'docker' } -AllowInstall
        Assert-Bootstrap ($result.Handled -and $result.Code -eq 1 -and $script:BootstrapInstalls.Count -eq 0) 'conflicting valid container engines never install prerequisites'
        $result = Initialize-WorkshopScript -ScriptPath 'not-run.ps1' -BoundParameters @{ Track = 'java' } -DotSourced $true -AllowInstall
        Assert-Bootstrap (-not $result.Handled -and $script:BootstrapInstalls.Count -eq 0) 'PS7 dot-sourcing never installs or runs host checks'
        $env:AZD_CONTAINER_RUNTIME = ''
    }

    & {
        $script:InstallCount = 0
        $script:Interactive = $false
        $script:Approved = $false
        $script:WingetAvailable = $true
        $script:WingetCode = 0
        $script:Located = $false
        function Get-Command {
            [CmdletBinding()]param($Name, $CommandType)
            if ($script:WingetAvailable) { return [pscustomobject]@{ Source = 'mock-winget' } }
        }
        function Test-WorkshopBootstrapInteractive { return $script:Interactive }
        function Confirm-WorkshopPowerShellInstall { return $script:Approved }
        function Find-WorkshopPowerShell { if ($script:Located) { return 'mock-pwsh.exe' } }
        function winget {
            Assert-Bootstrap (($args -join ' ') -eq 'install --id Microsoft.PowerShell --exact --source winget') 'exact approved package, no automatic agreement acceptance'
            $script:InstallCount++
            $script:Located = $true
            $global:LASTEXITCODE = $script:WingetCode
            'mock installation progress'
        }
        Assert-Bootstrap (-not (Install-WorkshopPowerShell)) 'noninteractive install denied'
        Assert-Bootstrap ($script:InstallCount -eq 0) 'noninteractive install has no side effects'
        $script:Interactive = $true
        Assert-Bootstrap (-not (Install-WorkshopPowerShell)) 'declined install denied'
        Assert-Bootstrap ($script:InstallCount -eq 0) 'declined install has no side effects'
        $script:Approved = $true
        $script:WingetAvailable = $false
        Assert-Bootstrap (-not (Install-WorkshopPowerShell)) 'missing winget does not install'
        $script:WingetAvailable = $true
        Assert-Bootstrap ((Install-WorkshopPowerShell) -eq 'mock-pwsh.exe') 'approved install rediscovers executable'
        Assert-Bootstrap ($script:InstallCount -eq 1) 'approved install exactly once'
        $script:WingetCode = 42
        Assert-Bootstrap (-not (Install-WorkshopPowerShell)) 'winget failure does not continue'
        function Find-WorkshopPowerShell { }
        $script:WingetCode = 0
        Assert-Bootstrap (-not (Install-WorkshopPowerShell)) 'successful installer without runnable executable does not continue'
        $result = Initialize-WorkshopScript -ScriptPath 'not-run.ps1' -BoundParameters @{} -DotSourced $true
        Assert-Bootstrap (-not $result.Handled) 'PS7 dot-source keeps caller scope without running main'
    }

    $worker = Join-Path $fixture 'worker 한글 & spaces.ps1'
    $report = Join-Path $fixture 'arguments.json'
    [IO.File]::WriteAllText($worker, @'
param([string]$Name, [string[]]$Values, [switch]$Enabled, [switch]$Disabled, [string]$Report)
@{ Name=$Name; Values=$Values; Enabled=[bool]$Enabled; Disabled=[bool]$Disabled; Remaining=@($args); Major=$PSVersionTable.PSVersion.Major } |
    ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $Report -Encoding UTF8
exit 23
'@, $encoding)
    $parameters = @{
        Name = '한글 space & "quotes" ''apostrophe'' \ trailing\'
        Values = @('first value', '한글 "second"')
        Enabled = [Management.Automation.SwitchParameter]::new($true)
        Disabled = [Management.Automation.SwitchParameter]::new($false)
        Report = $report
    }
    $code = Invoke-WorkshopPowerShell -ScriptPath $worker -BoundParameters $parameters -RemainingArguments @('last value', '한글 "tail"')
    Assert-Bootstrap ($code -eq 23) 'worker exit code preserved'
    $result = Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
    Assert-Bootstrap ($result.Major -ge 7) 'worker runs under PowerShell 7'
    Assert-Bootstrap ($result.Name -ceq $parameters.Name) 'spaces quotes Unicode backslashes preserved'
    Assert-Bootstrap (($result.Values -join '|') -ceq ($parameters.Values -join '|')) 'array values preserved'
    Assert-Bootstrap ($result.Enabled -and -not $result.Disabled) 'true and explicitly false switches preserved'
    Assert-Bootstrap (($result.Remaining -join '|') -ceq 'last value|한글 "tail"') 'remaining arguments preserved'
    $successfulWorker = Join-Path $fixture 'successful-worker.ps1'
    [IO.File]::WriteAllText($successfulWorker, 'if ($args.Count -ne 0) { throw "Unexpected arguments" }; $global:LASTEXITCODE=42; Write-Host "PASS: successful worker"', $encoding)
    Assert-Bootstrap ((Invoke-WorkshopPowerShell -ScriptPath $successfulWorker -BoundParameters @{}) -eq 0) 'successful script does not inherit stale native exit code'

    if ($IsWindows) {
        $legacy = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        Assert-Bootstrap (-not (Test-WorkshopPowerShellExecutable $legacy)) 'PowerShell 5.1 executable is rejected as worker'
        $legacyParameters = @{}
        foreach ($key in $parameters.Keys) { $legacyParameters[$key] = $parameters[$key] }
        $legacyParameters.Enabled = $true
        $legacyParameters.Disabled = $false
        $serialized = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes([Management.Automation.PSSerializer]::Serialize($legacyParameters)))
        $legacyCommand = ". '" + (Join-Path $root 'scripts\powershell-bootstrap.ps1').Replace("'", "''") + "'; " +
            '$parameters=[Management.Automation.PSSerializer]::Deserialize([Text.Encoding]::Unicode.GetString([Convert]::FromBase64String(' +
            "'$serialized'))); " +
            'exit (Invoke-WorkshopPowerShell -ScriptPath ' + "'" + $worker.Replace("'", "''") + "'" +
            ' -BoundParameters $parameters -RemainingArguments @(''last value'',''한글 "tail"''))'
        $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($legacyCommand))
        $null = & $legacy -NoProfile -NonInteractive -EncodedCommand $encoded 2>&1
        Assert-Bootstrap ($LASTEXITCODE -eq 23) 'real PS5.1 forwards worker exit code'
        $result = Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
        Assert-Bootstrap ($result.Name -ceq $parameters.Name -and $result.Enabled -and -not $result.Disabled) 'real PS5.1 preserves Unicode quotes and false switches'
        Assert-Bootstrap (($result.Values -join '|') -ceq ($parameters.Values -join '|') -and ($result.Remaining -join '|') -ceq 'last value|한글 "tail"') 'real PS5.1 preserves array and remaining arguments'
        $files = @(Get-ChildItem (Join-Path $root 'scripts'),(Join-Path $root 'tests') -Filter '*.ps1')
        $paths = ($files.FullName | ForEach-Object { "'" + $_.Replace("'", "''") + "'" }) -join ','
        $parseCommand = '$ErrorActionPreference="Stop"; foreach ($path in @(' + $paths + ')) { $tokens=$null; $errors=$null; $null=[Management.Automation.Language.Parser]::ParseFile($path,[ref]$tokens,[ref]$errors); if ($errors.Count) { throw "$path : $errors" } }; "PS51_PARSE_PASS"'
        $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($parseCommand))
        $output = & $legacy -NoProfile -NonInteractive -EncodedCommand $encoded 2>&1 | Out-String
        Assert-Bootstrap ($LASTEXITCODE -eq 0 -and $output.Contains('PS51_PARSE_PASS')) 'every script parses with real Windows PowerShell 5.1'

        # Isolated copies force discovery failure without altering this machine's
        # PATH, installations or production script files.
        foreach ($directory in @('scripts', 'tests')) {
            $null = [IO.Directory]::CreateDirectory((Join-Path $fixture $directory))
            Copy-Item (Join-Path $root "$directory\*.ps1") (Join-Path $fixture $directory)
        }
        $helper = Join-Path $fixture 'scripts\powershell-bootstrap.ps1'
        $content = [IO.File]::ReadAllText($helper).Replace('function Get-WorkshopHostPrerequisites {', 'function Get-OriginalWorkshopHostPrerequisites {')
        $content = $content.Replace("if (`$MyInvocation.InvocationName -ne '.') {", "function Get-WorkshopHostPrerequisites { return [pscustomobject]@{ Windows=`$true; PowerShell=`$null; Wsl2=`$false } }`nif (`$MyInvocation.InvocationName -ne '.') {")
        [IO.File]::WriteAllText($helper, $content, $encoding)
        $env:CI = '1'
        foreach ($shell in @($legacy, (Join-Path $PSHOME 'pwsh.exe'))) {
            foreach ($file in $files) {
                $directory = Split-Path (Split-Path $file.FullName -Parent) -Leaf
                $copy = Join-Path $fixture "$directory\$($file.Name)"
                $arguments = if ($file.Name -eq 'install-prerequisites.ps1') { @('-Track', 'dotnet') } else { @() }
                $output = & $shell -NoLogo -NoProfile -NonInteractive -File $copy @arguments 2>&1 | Out-String
                Assert-Bootstrap ($LASTEXITCODE -eq 1 -and $output.Contains('Microsoft.PowerShell') -and $output.Contains('[FAIL] WSL2') -and $output.Contains('No workshop actions')) "missing prerequisites stop before side effects: $shell $($file.Name); code=$LASTEXITCODE; output=$output"
            }
        }
        $content = [IO.File]::ReadAllText((Join-Path $root 'scripts\powershell-bootstrap.ps1')).Replace('function Test-WorkshopWsl2 {', 'function Test-OriginalWorkshopWsl2 {')
        $content = $content.Replace("if (`$MyInvocation.InvocationName -ne '.') {", "function Test-WorkshopWsl2 { return `$true }`nif (`$MyInvocation.InvocationName -ne '.') {")
        [IO.File]::WriteAllText($helper, $content, $encoding)
        foreach ($name in @('check-prerequisites', 'download-sample', 'run-dotnet-original', 'install-prerequisites')) {
            $output = & $legacy -NoLogo -NoProfile -NonInteractive -File (Join-Path $fixture "scripts\$name.ps1") -Help 2>&1 | Out-String
            Assert-Bootstrap ($LASTEXITCODE -eq 0 -and $output.Contains("scripts\$name.ps1")) "PS5.1 delegates -Help without recursion: $name"
        }
        $dotCommand = 'try { . ''' + (Join-Path $fixture 'scripts\check-prerequisites.ps1').Replace("'", "''") + ''' -Help; exit 99 } catch { if ($_.Exception.Message -notlike ''*Dot-sourcing requires*'') { exit 98 } }; ''CALLER_ALIVE''; exit 0'
        $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($dotCommand))
        $output = & $legacy -NoProfile -NonInteractive -EncodedCommand $encoded 2>&1 | Out-String
        Assert-Bootstrap ($LASTEXITCODE -eq 0 -and $output.Contains('CALLER_ALIVE')) 'real PS5.1 dot-sourcing gives actionable error without exiting caller'
    }
    Write-Host "PASS: $script:Passed PowerShell bootstrap assertions"
}
finally {
    $env:CI = $savedCI
    $env:AZD_CONTAINER_RUNTIME = $savedEngine
    Remove-Item -LiteralPath $fixture -Recurse -Force
}
