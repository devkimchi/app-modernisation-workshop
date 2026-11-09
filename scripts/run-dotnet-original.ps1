[CmdletBinding()]
param(
    [string]$AppPath = (Join-Path (Split-Path $PSScriptRoot -Parent) 'dotnet'),
    [ValidateSet('Debug', 'Release')][string]$Configuration = 'Debug',
    [ValidateRange(1024, 65535)][int]$Port = 58801,
    [switch]$Run,
    [switch]$AllowDatabaseInitialization,
    [switch]$Help
)

. (Join-Path $PSScriptRoot 'dotnet-framework-tools.ps1')

function Invoke-OriginalTool {
    param([string]$File, [string[]]$Arguments)
    & $File @Arguments | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "명령 실패 (종료 코드 $LASTEXITCODE): $File" }
}

function New-OriginalIisConfig {
    param([string]$Template, [string]$ApplicationPath, [int]$ListenPort, [string]$OutputPath)
    [xml]$config = Get-Content -LiteralPath $Template -Raw -ErrorAction Stop
    $sites = $config.SelectSingleNode('/configuration/system.applicationHost/sites')
    $pools = $config.SelectSingleNode('/configuration/system.applicationHost/applicationPools')
    if ($null -eq $sites -or $null -eq $pools) { throw 'IIS Express 템플릿에 sites/applicationPools가 없습니다.' }
    $sites.RemoveAll()
    $installedPool = $pools.SelectSingleNode('add[@managedRuntimeVersion="v4.0" and @managedPipelineMode="Integrated"]')
    $pool = if ($null -ne $installedPool) { $installedPool.CloneNode($true) } else { $config.CreateElement('add') }
    foreach ($oldPool in @($pools.SelectNodes('add'))) { $null = $pools.RemoveChild($oldPool) }
    foreach ($entry in @{ name='WorkshopPool'; managedRuntimeVersion='v4.0'; managedPipelineMode='Integrated' }.GetEnumerator()) {
        $pool.SetAttribute($entry.Key, $entry.Value)
    }
    $profile = $pool.SelectSingleNode('processModel')
    if ($null -eq $profile) {
        $profile = $config.CreateElement('processModel')
        $null = $pool.AppendChild($profile)
    }
    $profile.SetAttribute('loadUserProfile', 'true')
    $profile.SetAttribute('setProfileEnvironment', 'false')
    $null = $pools.AppendChild($pool)
    $site = $config.CreateElement('site')
    $site.SetAttribute('name', 'WorkshopOriginal')
    $site.SetAttribute('id', '1')
    $site.SetAttribute('serverAutoStart', 'true')
    $app = $config.CreateElement('application')
    $app.SetAttribute('path', '/')
    $app.SetAttribute('applicationPool', 'WorkshopPool')
    $directory = $config.CreateElement('virtualDirectory')
    $directory.SetAttribute('path', '/')
    $directory.SetAttribute('physicalPath', $ApplicationPath)
    $null = $app.AppendChild($directory)
    $null = $site.AppendChild($app)
    $bindings = $config.CreateElement('bindings')
    $binding = $config.CreateElement('binding')
    $binding.SetAttribute('protocol', 'http')
    $binding.SetAttribute('bindingInformation', "*:${ListenPort}:localhost")
    $null = $bindings.AppendChild($binding)
    $null = $site.AppendChild($bindings)
    $null = $sites.AppendChild($site)
    # Keep the project's IIS Express Windows authentication settings without changing Web.config.
    $authentication = $config.configuration.'system.webServer'.security.authentication
    if (-not $authentication.anonymousAuthentication -or -not $authentication.windowsAuthentication) {
        throw 'IIS Express 템플릿에 Windows/anonymous authentication 구성이 없습니다.'
    }
    $authentication.anonymousAuthentication.SetAttribute('enabled', 'false')
    $authentication.windowsAuthentication.SetAttribute('enabled', 'true')
    $config.Save($OutputPath)
}

function Invoke-OriginalMain {
    if ($Help) {
        Write-Host 'pwsh -File scripts\run-dotnet-original.ps1 [-AppPath PATH] [-Configuration Debug|Release] [-Run -AllowDatabaseInitialization] [-Port 58801]'
        Write-Host '기본은 복원/빌드만 수행합니다. -Run은 IIS Express를 전경 실행하며 첫 HTTP 요청이 DB 초기화를 유발할 수 있습니다.'
        return 0
    }
    try {
        if (-not $IsWindows -or $PSVersionTable.PSVersion.Major -lt 7) { throw 'Windows PowerShell 7에서 실행하세요.' }
        if ($Run -and -not $AllowDatabaseInitialization) { throw 'Web.config와 Data\DbInitializer.cs를 검토하고 실습 전용 DB임을 확인한 뒤 -AllowDatabaseInitialization을 지정하세요.' }
        $path = (Resolve-Path -LiteralPath $AppPath -ErrorAction Stop).ProviderPath
        foreach ($file in @('ContosoUniversity.sln', 'ContosoUniversity.csproj', 'packages.config', 'Web.config')) {
            if (-not (Test-Path -LiteralPath (Join-Path $path $file) -PathType Leaf)) { throw "원본 필수 파일 없음: $file" }
        }
        [xml]$project = Get-Content -LiteralPath (Join-Path $path 'ContosoUniversity.csproj') -Raw
        if ($project.Project.PropertyGroup.TargetFrameworkVersion -notcontains 'v4.8') { throw '이 도우미는 현대화 전 net48 원본 전용입니다.' }
        $tools = Get-DotnetFrameworkBuildTools
        $properties = @("/p:Configuration=$Configuration", "/p:VisualStudioVersion=$($tools.Version)", "/p:VSToolsPath=$($tools.WebTools)")
        $solution = Join-Path $path 'ContosoUniversity.sln'
        Push-Location $path
        try {
            Invoke-OriginalTool $tools.MSBuild (@($solution, '/t:Restore', '/p:RestorePackagesConfig=true', "/p:RestoreRepositoryPath=$(Join-Path $path 'packages')", '/nologo') + $properties)
            Invoke-OriginalTool $tools.MSBuild (@($solution, '/t:Build', '/nologo') + $properties)
            if (-not $Run) { return 0 }
            $iis = Get-WorkshopIisExpress
            $state = Join-Path $path '.vs\workshop'
            [IO.Directory]::CreateDirectory($state) | Out-Null
            $configPath = Join-Path $state ("applicationhost-" + [guid]::NewGuid().ToString('N') + '.config')
            New-OriginalIisConfig $iis.Template $path $Port $configPath
            Write-Host "IIS Express 전경 실행: http://localhost:$Port/ (종료: Q 또는 Ctrl+C). 첫 요청 전에 DB 대상을 확인하세요."
            Invoke-OriginalTool $iis.Exe @("/config:$configPath", '/site:WorkshopOriginal', '/systray:false')
            return 0
        }
        finally { Pop-Location }
    }
    catch { Write-Host "[FAIL] $($_.Exception.Message)"; return 1 }
}

if ($MyInvocation.InvocationName -ne '.') { exit (Invoke-OriginalMain) }
