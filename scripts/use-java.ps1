param([string]$Jdk)

if ($MyInvocation.InvocationName -ne '.') {
    Write-Error '앱 루트에서 dot-source하세요: . ../scripts/use-java.ps1 -Jdk 8|25'
    exit 2
}
if ($PSVersionTable.PSVersion.Major -lt 7) {
    throw '현재 셸의 Java를 전환하려면 PowerShell 7에서 dot-source하세요. Windows PowerShell 5.1에서는 호출자 환경을 바꿀 수 없습니다.'
}

& {
    param($Major, $Scripts)
    if ($Major -cnotin @('8', '25')) { throw '-Jdk 값은 8 또는 25여야 합니다.' }
    if (-not (Test-Path -LiteralPath '.\mvnw.cmd' -PathType Leaf)) { throw '샘플 앱 루트에서 실행하세요. 현재 폴더에 mvnw.cmd가 없습니다.' }
    . (Join-Path $Scripts 'java-tools.ps1')
    $jdk = Find-WorkshopJava -Major ([int]$Major)
    if (-not $jdk) { throw "실행 가능한 Temurin JDK $Major 의 java와 javac를 찾지 못했습니다. 설치 경로와 버전을 확인하세요." }
    $oldBin = if ($env:JAVA_HOME) { Join-Path $env:JAVA_HOME 'bin' } else { '' }
    $newBin = Join-Path $jdk.Home 'bin'
    $remaining = @($env:PATH -split ';' | Where-Object { $_ -and $_.TrimEnd('\', '/') -ine $oldBin -and $_.TrimEnd('\', '/') -ine $newBin })
    $env:JAVA_HOME = $jdk.Home
    $env:PATH = (@($newBin) + $remaining) -join ';'
    Write-Host "[PASS] Temurin JDK $Major 선택: $($jdk.Home)"
    Write-Host $jdk.RuntimeVersion
    Write-Host $jdk.CompilerVersion
} $Jdk $PSScriptRoot
