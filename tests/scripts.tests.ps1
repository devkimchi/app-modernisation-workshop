$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $root 'scripts\check-prerequisites.ps1')
. (Join-Path $root 'scripts\download-sample.ps1')
$script:Passed = 0

function Assert-True([bool]$Condition, [string]$Name) {
    if (-not $Condition) { throw "FAILED: $Name" }
    $script:Passed++
}
function Assert-Throws([scriptblock]$Action, [string]$Name) {
    $threw = $false
    try { & $Action | Out-Null } catch { $threw = $true }
    Assert-True $threw $Name
}
function New-Results { $script:CheckResults = [Collections.Generic.List[object]]::new() }
function Has-Failure([string]$Id) { return @($script:CheckResults | Where-Object { $_.Id -eq $Id -and $_.Status -eq 'FAIL' }).Count -gt 0 }

$temporary = Join-Path $root ('.test-output\ps-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($temporary) | Out-Null
$savedEngine = $env:AZD_CONTAINER_RUNTIME
$savedProgramFiles = $env:ProgramFiles
$savedProgramFilesX86 = ${env:ProgramFiles(x86)}
try {
    foreach ($file in Get-ChildItem (Join-Path $root 'scripts') -Filter '*.ps1') {
        $tokens = $null; $errors = $null
        $null = [Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)
        Assert-True ($errors.Count -eq 0) "syntax $($file.Name)"
    }
    $env:AZD_CONTAINER_RUNTIME = ''
    Assert-True ((Resolve-ContainerEngine '') -eq 'docker') 'default engine'
    Assert-True ((Resolve-ContainerEngine 'podman') -eq 'podman') 'explicit podman'
    $env:AZD_CONTAINER_RUNTIME = 'podman'
    Assert-True ((Resolve-ContainerEngine '') -eq 'podman') 'configured engine'
    Assert-Throws { Resolve-ContainerEngine docker } 'engine conflict'
    Assert-Throws { Resolve-ContainerEngine nerdctl } 'unsupported engine'
    Assert-True (Test-MinimumVersion 'azd version 1.37.3 (commit abc)' '1.37.3') 'azd minimum'
    Assert-True (-not (Test-MinimumVersion '1.37.2' '1.37.3')) 'old azd'
    Assert-True (-not (Test-MinimumVersion '22.0.0-rc.1' '22.0.0')) 'preview rejected'

    $script:Calls = [Collections.Generic.List[string]]::new()
    $script:Stopped = $false
    function Invoke-ToolProbe {
        param([string]$Name, [string[]]$Arguments)
        $script:Calls.Add("$Name $($Arguments -join ' ')")
        $text = ''; $code = 0
        if ($Arguments[0] -eq '--version') { $text = "$Name version 5.4.0" }
        elseif ($Arguments[0] -eq 'info') {
            if ($script:Stopped) { $code = 1 } else { $text = 'linux' }
        }
        elseif ($Arguments[0] -eq 'build') { $text = '--platform' }
        elseif ($Arguments[0] -eq 'buildx') { $code = 127 }
        return [pscustomobject]@{ Code = $code; Text = $text }
    }
    New-Results
    Test-ContainerRuntime podman
    Assert-True (-not (Has-Failure 'container-cli')) 'podman CLI'
    Assert-True (-not (Has-Failure 'builder')) 'podman native builder'
    Assert-True (@($script:Calls | Where-Object { $_ -like 'docker *' }).Count -eq 0) 'podman never probes docker'
    $script:Stopped = $true
    $script:Calls.Clear()
    New-Results
    Test-ContainerRuntime docker
    Assert-True (Has-Failure 'container-engine') 'stopped engine fails'
    Assert-True (@($script:Calls | Where-Object { $_ -like 'podman *' }).Count -eq 0) 'no fallback'
    Remove-Item Function:\Invoke-ToolProbe
    . (Join-Path $root 'scripts\check-prerequisites.ps1')

    $script:SignedIn = $true
    $script:MissingNode = $false
    $script:Registered = $true
    function Invoke-ToolProbe {
        param([string]$Name, [string[]]$Arguments)
        $code = 0; $text = ''
        switch ($Name) {
            git { $text = 'git version 2.50.0' }
            node { $text = 'v22.1.0'; if ($script:MissingNode) { $code=127; $text='' } }
            az {
                switch ($Arguments[0]) {
                    version { $text='{}' }
                    extension { $text='1.3.0' }
                    account { if ($script:SignedIn) { $text='Enabled' } else { $code=1 } }
                    provider { $text=if ($script:Registered) { 'Registered' } else { 'NotRegistered' } }
                }
            }
            azd {
                if ($Arguments[0] -eq 'version') { $text='azd version 1.37.3' }
                elseif (-not $script:SignedIn) { $code=1 }
            }
            docker {
                switch ($Arguments[0]) {
                    --version { $text='Docker version 29.0.0' }
                    info { $text='linux' }
                    build { $text='--platform' }
                    buildx { $text='v0.20.0' }
                }
            }
            default { $code=127 }
        }
        return [pscustomobject]@{ Code=$code; Text=$text }
    }
    New-Results
    Test-CommonTools docker dotnet
    Assert-True (@($script:CheckResults | Where-Object Status -EQ FAIL).Count -eq 0) 'complete common tool fixture'
    $script:SignedIn=$false; $script:MissingNode=$true
    New-Results
    Test-CommonTools docker dotnet
    Assert-True (Has-Failure node) 'missing Node fails'
    Assert-True (Has-Failure az-login) 'Azure CLI auth failure'
    Assert-True (Has-Failure azd-login) 'azd auth failure'
    $script:SignedIn=$true; $script:Registered=$false
    New-Results
    Test-CommonTools docker java
    Assert-True (Has-Failure 'Microsoft.DBforPostgreSQL') 'Java provider registration required'
    Remove-Item Function:\Invoke-ToolProbe
    . (Join-Path $root 'scripts\check-prerequisites.ps1')

    if ($IsWindows) {
        $env:ProgramFiles = Join-Path $temporary 'program-files'
        ${env:ProgramFiles(x86)} = Join-Path $temporary 'program-files-x86'
        $references = Join-Path ${env:ProgramFiles(x86)} 'Reference Assemblies\Microsoft\Framework\.NETFramework\v4.8'
        [IO.Directory]::CreateDirectory((Join-Path $references 'RedistList')) | Out-Null
        [IO.Directory]::CreateDirectory((Join-Path $env:ProgramFiles 'IIS Express')) | Out-Null
        Set-Content (Join-Path $references 'mscorlib.dll') 'fixture'
        Set-Content (Join-Path $references 'RedistList\FrameworkList.xml') 'fixture'
        Set-Content (Join-Path $env:ProgramFiles 'IIS Express\iisexpress.exe') 'fixture'
        $script:FakeRelease = 528040
        $script:FakeSdk = '10.0.100 [fixture]'
        $script:FakeFeature = 1
        $script:FakeVs = '[{"installationVersion":"18.0.1"}]'
        function Get-CimInstance { [CmdletBinding()]param($ClassName, $Filter); return [pscustomobject]@{ InstallState=$script:FakeFeature } }
        function Get-Service { [CmdletBinding()]param($Name); return [pscustomobject]@{ Status='Running' } }
        function Get-ItemPropertyValue { [CmdletBinding()]param($LiteralPath, $Name); return $script:FakeRelease }
        function Get-Command { [CmdletBinding()]param($Name, $CommandType); return [pscustomobject]@{ Source='fixture-sqllocaldb' } }
        function Invoke-ToolProbe {
            param([string]$Name, [string[]]$Arguments)
            $text = if ($Name -like '*vswhere.exe') { $script:FakeVs } elseif ($Name -eq 'dotnet') { $script:FakeSdk } else { '16.0' }
            return [pscustomobject]@{ Code=0; Text=$text }
        }
        New-Results
        Test-DotnetTools
        Assert-True (-not (Has-Failure framework-runtime)) 'runtime 4.8 accepted'
        Assert-True (-not (Has-Failure framework-targeting)) 'targeting pack accepted'
        Assert-True (-not (Has-Failure vs2026)) 'VS IDE workload fixture'
        Assert-True (-not (Has-Failure dotnet-sdk)) '.NET 10 SDK accepted'
        Remove-Item (Join-Path $references 'mscorlib.dll')
        New-Results
        Test-DotnetTools
        Assert-True (-not (Has-Failure framework-runtime)) 'runtime independent of targeting pack'
        Assert-True (Has-Failure framework-targeting) 'runtime alone insufficient'
        $script:FakeRelease = 461808
        $script:FakeSdk = '10.0.100-preview.1 [fixture]'
        $script:FakeFeature = 2
        $script:FakeVs = '[]'
        New-Results
        Test-DotnetTools
        Assert-True (Has-Failure framework-runtime) 'old framework rejected'
        Assert-True (Has-Failure dotnet-sdk) 'preview SDK rejected'
        Assert-True (Has-Failure msmq-feature) 'disabled MSMQ rejected'
        Assert-True (Has-Failure vs2026) 'no qualifying IDE rejected'
        foreach ($name in @('Get-CimInstance','Get-Service','Get-ItemPropertyValue','Get-Command','Invoke-ToolProbe')) { Remove-Item "Function:\$name" }
        . (Join-Path $root 'scripts\check-prerequisites.ps1')
        $env:ProgramFiles = $savedProgramFiles
        ${env:ProgramFiles(x86)} = $savedProgramFilesX86
    }

    $destination = Join-Path $temporary 'destination with spaces'
    Assert-True ((Assert-SafeDestination $destination $root) -eq $destination) 'space destination'
    Push-Location $temporary
    try { Assert-True ((Assert-SafeDestination 'relative-child' $root) -eq (Join-Path $temporary 'relative-child')) 'relative path follows PowerShell location' }
    finally { Pop-Location }
    Assert-Throws { Assert-SafeDestination $root $root } 'workshop root rejected'
    Assert-Throws { Assert-SafeDestination (Join-Path $root 'docs\child') $root } 'documentation rejected'
    if ($IsWindows) { Assert-Throws { Assert-SafeDestination (Join-Path $root 'docs.\child') $root } 'Windows path alias rejected' }
    if ($IsWindows) { Assert-Throws { Assert-SafeDestination ('\\?\' + (Join-Path $root 'docs\child')) $root } 'extended device path rejected' }
    Assert-Throws { Assert-SafeDestination $HOME $root } 'home rejected'
    [IO.Directory]::CreateDirectory($destination) | Out-Null
    Set-Content (Join-Path $destination '.hidden') 'preserve'
    Assert-Throws { Assert-SafeDestination $destination $root } 'hidden file prevents overwrite'
    Assert-True ((Get-Content (Join-Path $destination '.hidden') -Raw).Trim() -eq 'preserve') 'existing content preserved'
    if ($IsWindows) {
        $junction = Join-Path $temporary 'junction'
        New-Item -ItemType Junction -Path $junction -Target $destination | Out-Null
        Assert-Throws { Assert-SafeDestination (Join-Path $junction 'child') $root } 'junction rejected'
        Remove-Item -LiteralPath $junction
    }

    $fixture = Join-Path $temporary 'upstream'
    $app = Join-Path $fixture 'ContosoUniversity'
    [IO.Directory]::CreateDirectory($app) | Out-Null
    foreach ($name in @('ContosoUniversity.sln', 'ContosoUniversity.csproj', 'packages.config', '.gitignore')) {
        Set-Content -LiteralPath (Join-Path $app $name) -Value "fixture $name"
    }
    Set-Content -LiteralPath (Join-Path $fixture 'LICENSE') 'Fixture license, not a real sample license'
    Set-Content -LiteralPath (Join-Path $fixture 'NOTICE.md') 'Fixture notice'
    Set-Content -LiteralPath (Join-Path $fixture 'license-MIT.txt') 'Fixture alternate license'
    Set-Content -LiteralPath (Join-Path $fixture 'COPYRIGHT') 'Fixture copyright'
    Set-Content -LiteralPath (Join-Path $app 'ContosoUniversity.csproj') '<Project><PropertyGroup><TargetFrameworkVersion>v4.8</TargetFrameworkVersion></PropertyGroup></Project>'
    & git init --quiet $fixture
    & git -C $fixture config core.autocrlf false
    & git -C $fixture add .
    & git -C $fixture -c user.name=Fixture -c user.email=fixture@example.invalid commit --quiet -m "Fixture`n`nCo-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>"
    if ($LASTEXITCODE -ne 0) { throw 'Fixture commit failed' }
    $commit = (& git -C $fixture rev-parse HEAD).Trim()
    $definition = [pscustomobject]@{ Repository=$fixture; Commit=$commit; Subdirectory='ContosoUniversity'; Required=@('ContosoUniversity.sln','ContosoUniversity.csproj','packages.config') }
    $download = Join-Path $temporary 'download with spaces'
    Invoke-SampleDownload $download $definition $root
    Assert-True (Test-Path (Join-Path $download 'ContosoUniversity.sln')) 'flattened solution'
    Assert-True (Test-Path (Join-Path $download '.gitignore')) 'hidden files preserved'
    $workshopIgnore = Get-Content (Join-Path $root '.gitignore') -Raw
    Assert-True ($workshopIgnore -notmatch '(?m)^/(java|dotnet)/$') 'workshop tracks downloaded app directories'
    Assert-True (Test-Path (Join-Path $download 'UPSTREAM-LICENSE')) 'license preserved'
    $metadata = Get-Content (Join-Path $download 'upstream-source.json') -Raw | ConvertFrom-Json
    Assert-True ($metadata.commit -eq $commit) 'pinned provenance'
    Assert-True ($metadata.repository -eq $fixture -and $metadata.subdirectory -eq 'ContosoUniversity') 'repository and subdirectory provenance'
    Assert-True $metadata.licenseFileFound 'license metadata'
    foreach ($name in @('LICENSE', 'NOTICE.md', 'license-MIT.txt', 'COPYRIGHT')) {
        Assert-True ((Get-FileHash (Join-Path $fixture $name)).Hash -eq (Get-FileHash (Join-Path $download "UPSTREAM-$name")).Hash) "notice bytes preserved: $name"
    }
    foreach ($file in Get-ChildItem -LiteralPath $app -Force -File) {
        Assert-True ((Get-FileHash $file.FullName).Hash -eq (Get-FileHash (Join-Path $download $file.Name)).Hash) "source bytes unchanged: $($file.Name)"
    }
    Assert-True (-not (Test-Path (Join-Path $download '.git'))) 'download has no nested Git repository'
    $gitRoot = (& git -C $download rev-parse --show-toplevel).Trim()
    Assert-True ([IO.Path]::GetFullPath($gitRoot) -eq $root) 'download uses workshop Git root'
    Assert-Throws { Invoke-SampleDownload $download $definition $root } 'repeat refuses overwrite'
    $emptyTarget = Join-Path $temporary 'empty'
    [IO.Directory]::CreateDirectory($emptyTarget) | Out-Null
    Invoke-SampleDownload $emptyTarget $definition $root
    Assert-True (Test-Path (Join-Path $emptyTarget 'ContosoUniversity.sln')) 'existing empty destination'
    foreach ($collisionName in @('upstream-source.json', 'UPSTREAM-NOTICE.md')) {
        Set-Content -LiteralPath (Join-Path $app $collisionName) 'preserve upstream content'
        & git -C $fixture add .
        & git -C $fixture -c user.name=Fixture -c user.email=fixture@example.invalid commit --quiet -m "Fixture collision`n`nCo-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>"
        $definition.Commit = (& git -C $fixture rev-parse HEAD).Trim()
        $collisionTarget = Join-Path $temporary $collisionName
        Assert-Throws { Invoke-SampleDownload $collisionTarget $definition $root } "reject source collision: $collisionName"
        Assert-True (-not (Test-Path $collisionTarget)) "collision not published: $collisionName"
        Remove-Item -LiteralPath (Join-Path $app $collisionName)
    }
    $definition.Commit = '0000000000000000000000000000000000000000'
    $failed = Join-Path $temporary 'failed'
    Assert-Throws { Invoke-SampleDownload $failed $definition $root } 'bad commit fails'
    Assert-True (-not (Test-Path $failed)) 'failed download is not published'
    Assert-True (@(Get-ChildItem $temporary -Force | Where-Object Name -Like '.workshop-download-*').Count -eq 0) 'temporary paths cleaned'

    foreach ($trackName in @('java','dotnet')) {
        $sample = Get-SampleDefinition $trackName
        $bash = Get-Content (Join-Path $root 'scripts\download-sample.sh') -Raw
        Assert-True ($bash.Contains($sample.Commit)) "same commit in both shells: $trackName"
        Assert-True ($bash.Contains($sample.Repository)) "same source in both shells: $trackName"
    }
    $devContainer = Get-Content -LiteralPath (Join-Path $root '.devcontainer\devcontainer.json') -Raw | ConvertFrom-Json
    Assert-True (@($devContainer.features.PSObject.Properties.Name | Where-Object { $_ -notmatch ':latest$' }).Count -eq 0) 'Dev Container features use latest tags'
    $javaFeature = $devContainer.features.'ghcr.io/devcontainers/features/java:latest'
    Assert-True ($javaFeature.version -eq '8' -and @($javaFeature.additionalVersions -split ',') -contains '21' -and @($javaFeature.additionalVersions -split ',') -contains '25') 'Dev Container includes JDK 8, 21 and 25'
    Assert-True ($devContainer.features.'ghcr.io/devcontainers/features/dotnet:latest'.version -eq '10.0') 'Dev Container includes .NET 10 SDK'
    Assert-True ($devContainer.features.'ghcr.io/devcontainers/features/node:latest'.version -eq '22') 'Dev Container includes Node 22'
    Assert-True ($null -ne $devContainer.features.'ghcr.io/devcontainers/features/azure-cli:latest' -and $null -ne $devContainer.features.'ghcr.io/azure/azure-dev/azd:latest') 'Dev Container includes Azure CLI and azd'
    Assert-True ($null -ne $devContainer.features.'ghcr.io/devcontainers/features/docker-in-docker:latest') 'Dev Container includes isolated Docker engine'
    Assert-True ($devContainer.containerEnv.WORKSHOP_DEVCONTAINER -eq '1' -and $devContainer.containerEnv.AZD_CONTAINER_RUNTIME -eq 'docker') 'Dev Container selects the documented Java and Docker environment'
    Assert-True (@($devContainer.forwardPorts) -contains 8080 -and @($devContainer.forwardPorts) -contains 15672) 'Dev Container forwards app and management ports'
    $Track='dotnet'; $Destination=Join-Path $temporary 'blocked-by-preflight'; $ContainerEngine='docker'; $Help=$false
    $env:AZD_CONTAINER_RUNTIME='docker'
    function pwsh { $global:LASTEXITCODE=1 }
    Assert-True ((Invoke-DownloadMain) -eq 1) 'download propagates prerequisite failure'
    Assert-True (-not (Test-Path $Destination)) 'prerequisite failure prevents download'
    Remove-Item Function:\pwsh
    $documents = @((Get-Item (Join-Path $root 'README.md'))) + @(Get-ChildItem (Join-Path $root 'docs') -Recurse -Filter '*.md')
    Assert-True ($documents.Count -eq 19) '19 workshop documents'
    foreach ($document in $documents) {
        $text = Get-Content $document.FullName -Raw
        Assert-True ($text -match '[가-힣]') "Korean text: $($document.Name)"
        Assert-True ($text -notmatch '[\u3040-\u30ff]') "no accidental Japanese: $($document.Name)"
        foreach ($match in [regex]::Matches($text, '\[[^\]]+\]\(([^)]+)\)')) {
            $link = $match.Groups[1].Value
            if ($link -match '^[a-z]+:|^#') { continue }
            $target = [IO.Path]::GetFullPath((Join-Path $document.DirectoryName ($link.Split('#')[0] -replace '/', [IO.Path]::DirectorySeparatorChar)))
            Assert-True (Test-Path -LiteralPath $target -PathType Leaf) "local link: $link in $($document.Name)"
        }
        if ($document.Name -match '^\d\d-') {
            foreach ($navigation in @('[목차]', '[이전:', '[다음:', '[정리')) {
                Assert-True ($text.Contains($navigation)) "navigation $navigation in $($document.Name)"
            }
        }
    }
    Write-Host "PASS: $script:Passed PowerShell assertions"
}
finally {
    $env:AZD_CONTAINER_RUNTIME = $savedEngine
    $env:ProgramFiles = $savedProgramFiles
    ${env:ProgramFiles(x86)} = $savedProgramFilesX86
    Remove-Item -LiteralPath $temporary -Recurse -Force
}
