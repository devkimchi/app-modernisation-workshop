# 공통 준비: 저장소를 만들고 점검한 뒤 샘플 받기

[전체 목차](../README.md) | [문제 해결](troubleshooting.md) | [Java 정리](java/07-cleanup.md) | [.NET 정리](dotnet/07-cleanup.md)

## 목표와 실행 위치

템플릿으로 개인 계정에 워크숍 저장소를 만들어 복제하고, 선택 트랙의 환경을 확인한 다음 원본 앱만 독립 프로젝트로 내려받습니다. **복제한 워크숍 자료 폴더가 현재 작업 폴더**인 상태에서 점검 스크립트를 먼저 실행합니다. 도구가 없어서 실패하면 아래 설치 안내로 보완하고 다시 점검합니다. 다운로드를 먼저 하거나 실패를 무시하지 않습니다.

스크립트는 소프트웨어 설치, 관리자 권한 상승, 로그인, 공급자 등록, 컨테이너 엔진 시작, SDK 기본 버전 변경을 하지 않습니다. 참가자가 필요한 변경을 직접 승인하고 수행합니다.

## 1. 공통 도구와 계정

| 항목 | 기준과 확인 범위 | 설치 안내 |
| --- | --- | --- |
| Git | 샘플 다운로드와 독립 저장소 | [Git](https://git-scm.com/downloads) |
| PowerShell | .NET 및 PowerShell 진입점은 7 이상, Windows PowerShell 5.1 아님 | [PowerShell](https://learn.microsoft.com/powershell/scripting/install/installing-powershell) |
| Bash | Java는 WSL2/macOS, .NET Bash 진입점은 Git Bash | [WSL](https://learn.microsoft.com/windows/wsl/install), [Git for Windows](https://gitforwindows.org/) |
| Node.js | 워크숍 기준 안정 버전 22 이상 | [Node.js](https://nodejs.org/en/download) |
| GitHub Copilot app | 로그인, 라이선스, 조직 정책은 수동 확인 | [Copilot app](https://github.com/copilot/app) |
| Azure CLI | 설치, `containerapp` 확장, 로그인, 구독, 공급자 상태 | [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) |
| Azure Developer CLI | `azd` 1.37.3 이상, 별도 로그인 상태 | [azd 설치](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd) |
| 컨테이너 엔진 | Docker 또는 Podman CLI와 Linux 서버 연결, 빌더 기능 | [Docker Desktop](https://docs.docker.com/desktop/), [Podman](https://podman.io/docs/installation) |

`gh`, 독립 Maven 설치, Copilot CLI, VS Code는 공통 필수가 아닙니다. Java 원본의 Maven Wrapper가 Maven 3.9.9를 내려받으므로 최초 실행에 네트워크가 필요합니다.

**Windows Java 환경은 두 실행 공간을 구분합니다.** Windows Copilot app 호스트에도 Git과 Node.js 22 이상을 준비하고, Java 실습 도구(Git, Node, Azure CLI, `azd`, SDKMAN, 선택 엔진의 CLI)는 선택한 WSL2 배포판 안에 준비합니다. Docker Desktop은 해당 배포판과 WSL 통합을 켜야 합니다. Windows 설치나 로그인만으로 WSL 검사를 통과했다고 판단하지 않습니다.

### 템플릿으로 내 저장소 만들기

이 워크숍 저장소는 공개 템플릿 저장소입니다. 원본을 직접 복제하거나 포크하지 않고, 템플릿으로 본인 **개인 계정**에 새 저장소를 만들어 사용합니다. GitHub 웹에서 다음 순서로 진행합니다.

템플릿에서 바로 저장소를 만들려면 아래 뱃지를 선택합니다.

[![GitHub에서 템플릿으로 저장소 만들기](https://img.shields.io/badge/GitHub-Create%20repository%20from%20template-2ea44f?style=flat&logo=github&logoColor=white)](https://github.com/new?template_name=app-modernisation-workshop&template_owner=devkimchi)

1. [워크숍 템플릿 저장소](https://github.com/devkimchi/app-modernisation-workshop)에서 **Use this template** > **Create a new repository**를 선택합니다.
2. **Owner**에서 본인 개인 계정을 선택하고 저장소 이름을 입력합니다. 조직 계정을 선택하지 않습니다.
3. 공개 범위는 직접 선택합니다. 실습 기록을 공개할 계획이 없다면 **Private**을 선택하세요.
4. **Include all branches**는 선택하지 않습니다. 실습에는 기본 브랜치만 필요합니다.
5. **Create repository from template**을 선택합니다.

만든 저장소를 복제하고 그 폴더로 이동합니다. 이 폴더가 이후 모든 명령의 **워크숍 자료 폴더**입니다. `<본인-계정>`과 `<저장소-이름>`은 실제 값으로 바꿉니다. Windows에서 Java 트랙을 진행한다면 점검 명령을 실행할 환경에서 접근할 수 있는 위치에 복제합니다.

```text
git clone https://github.com/<본인-계정>/<저장소-이름>.git
cd <저장소-이름>
```

GitHub CLI(`gh`)에 이미 로그인했다면 웹 대신 다음 명령으로 저장소를 만들고 현재 폴더 아래에 복제할 수 있습니다. 공개하려면 `--private` 대신 `--public`을 지정합니다. `gh`는 이 워크숍의 필수 도구가 아닙니다.

```text
gh repo create <저장소-이름> --template devkimchi/app-modernisation-workshop --private --clone
cd <저장소-이름>
```

템플릿으로 만든 저장소는 원본과 이어지지 않은 새 커밋 이력으로 시작하며, 원본 템플릿의 이후 변경을 자동으로 받지 않습니다. 이후 내려받는 앱은 이 저장소와 별개의 Git 저장소이므로 앱 코드가 내 워크숍 저장소에 커밋되지 않습니다.

### Azure 로그인과 권한

실습에 사용할 동일한 셸에서 아래 명령을 실행합니다. 구독 ID와 리전은 본인 값으로 바꿉니다. 장치 코드 로그인이나 조직의 인증 절차는 참가자가 직접 완료합니다.

```text
az login
az account list --output table
az account set --subscription "<본인-구독-ID>"
az account show --query "{name:name,id:id,tenantId:tenantId}" --output table
az extension add --name containerapp --upgrade
azd auth login
azd auth login --check-status
```

`az`와 `azd` 인증은 별개입니다. 로그인했다고 배포 권한이나 쿼터가 확보된 것도 아닙니다. Contributor는 리소스 생성에 사용할 수 있지만 일반적으로 **역할 할당 권한은 포함하지 않습니다**. 관리 ID에 데이터 역할을 부여하려면 적절한 범위의 Role Based Access Control Administrator/User Access Administrator 등의 권한을 관리자에게 요청해야 할 수 있습니다. 워크숍 때문에 구독 전체 Owner 권한을 무조건 요청하지 마세요.

공급자 등록은 구독을 변경합니다. 참가자가 해당 구독을 확인하고 권한이 있을 때만 다음 명령을 실행합니다. `--wait`는 시간이 걸릴 수 있습니다.

PowerShell:

```powershell
$track = 'java' # .NET이면 'dotnet'
$providers = @('Microsoft.App', 'Microsoft.OperationalInsights', 'Microsoft.Storage', 'Microsoft.ContainerRegistry', 'Microsoft.ServiceBus')
$providers += if ($track -eq 'java') { 'Microsoft.DBforPostgreSQL' } else { 'Microsoft.Sql' }
foreach ($provider in $providers) { az provider register --namespace $provider --wait }
```

Bash:

```bash
track=java
providers=(Microsoft.App Microsoft.OperationalInsights Microsoft.Storage Microsoft.ContainerRegistry Microsoft.ServiceBus)
if [[ "$track" == java ]]; then providers+=(Microsoft.DBforPostgreSQL); else providers+=(Microsoft.Sql); fi
for provider in "${providers[@]}"; do az provider register --namespace "$provider" --wait; done
```

VNet/Private Endpoint를 계획에 추가하면 `Microsoft.Network` 등 추가 공급자가 필요할 수 있습니다. 배포 계획 검토 때 등록 대상과 비용을 확인합니다. 데이터베이스의 Entra 관리자 지정과 DB 내부 사용자 생성도 별도 권한입니다.

### 컨테이너 엔진 선택

Docker Desktop은 Linux containers 모드와 실제 서버 연결을 확인합니다. Podman은 macOS/Windows에서 machine이 필요할 수 있습니다. 기존 machine을 먼저 확인하고, 필요한 경우에만 직접 생성하거나 시작합니다. WSL 내부 Podman은 해당 배포판의 엔진과 rootless 설정을 확인합니다.

```text
docker info
docker buildx version
```

또는:

```text
podman machine list
podman info
podman build --help
```

Podman의 `machine init`/`machine start`를 점검 스크립트가 대신 실행하지 않습니다. Windows native Podman과 WSL Podman이 같은 서버를 가리킨다고 가정하지 마세요.

선택 우선순위는 **명시 인자 → `AZD_CONTAINER_RUNTIME` → 기본 `docker`**입니다. 인자와 기존 환경 변수의 값이 다르면 오류입니다. 선택한 엔진이 멈춰도 다른 엔진으로 자동 전환하지 않습니다. 이후 `azd`가 같은 엔진을 쓰도록 **각 실습 셸**에서 다음 중 하나를 설정하세요.

```powershell
$env:AZD_CONTAINER_RUNTIME = 'docker' # Podman은 'podman'
```

```bash
export AZD_CONTAINER_RUNTIME=docker # Podman은 podman
```

스크립트 실행은 부모 셸의 환경 변수를 바꾸지 않습니다. Docker Buildx가 없으면 경고를 표시하지만, 실제 `azd package` 성공 전까지 빌드 준비 완료로 보지 않습니다. Podman은 내장 빌더를 사용하며 Docker/Buildx가 없어도 됩니다. Docker 호환 대체 제품은 Linux 실행, `linux/amd64` 빌드, 포트 접근, 인증과 ACR 푸시까지 성공한 경우에만 조건부 지원합니다.

## 2. 트랙별 도구

### Java: SDKMAN, JDK 8/21/25

Windows에서는 WSL2를 사용합니다. `wsl --list --verbose`의 VERSION이 2인지 확인하세요. Windows Git Bash는 Java 실습 환경이 아닙니다. macOS는 Bash에서 실행합니다.

[SDKMAN 설치 안내](https://sdkman.io/install/)에 따라 설치한 뒤, **같은 Bash 환경**에서 다음을 실행합니다.

```bash
source "${SDKMAN_DIR:-$HOME/.sdkman}/bin/sdkman-init.sh"
sdk version
sdk list java
```

배포판과 CPU 아키텍처에 맞는 **정식 JDK 8, 21, 25** 식별자를 골라 각각 `sdk install java <식별자>`로 설치합니다. 표시 이름을 추측하지 마세요. 설치 과정에서 기본 JDK를 바꾸겠느냐는 질문은 직접 결정하고, 실습 1에서는 `sdk use java <설치한-8-식별자>`로 현재 셸만 전환합니다. JRE나 EA 버전은 요구사항을 충족하지 않습니다. 점검은 `SDKMAN_DIR` 또는 `~/.sdkman` 아래의 `java`와 `javac`를 실제 실행해 버전이 맞는지 확인합니다.

### .NET: Windows 도구

[Visual Studio](https://visualstudio.microsoft.com/downloads/) 2026(18.x) IDE와 **ASP.NET 및 웹 개발** 워크로드를 설치합니다. Build Tools만 설치한 환경은 이 워크숍의 원본 IIS Express 실습을 충족하지 않습니다.

Visual Studio Installer의 개별 구성요소에서 .NET Framework 4.8 Targeting Pack, IIS Express와 SQL Server Express LocalDB를 확인하고, [.NET 10 SDK](https://dotnet.microsoft.com/download/dotnet/10.0)도 설치합니다.

원본 README의 "4.8.2" 표기와 달리 고정 커밋의 `ContosoUniversity.csproj`는 **`v4.8`**입니다. 이 자료에서는 원본을 변경하지 않고 **4.8 이상 런타임 + 4.8 Targeting Pack**을 각각 확인합니다. 4.8.1 런타임이 있어도 4.8 참조 어셈블리가 없으면 빌드할 수 없습니다. [공식 버전 확인 안내](https://learn.microsoft.com/dotnet/framework/migration-guide/how-to-determine-which-versions-are-installed)를 기준으로 하며, "4.8.2 설치 파일"을 임의 사이트에서 받지 않습니다.

Windows 기능의 **Microsoft Message Queue(MSMQ) Server**를 활성화하고 필요한 재부팅을 마칩니다. [MSMQ 설치 안내](https://learn.microsoft.com/dotnet/framework/wcf/samples/installing-message-queuing-msmq)를 참고하세요. `Get-Service MSMQ`가 Running인지 확인합니다. 스크립트가 기능이나 서비스 상태를 변경하지 않습니다.

## 3. Copilot app에 플러그인 설치

1. Copilot app에서 GitHub 계정으로 로그인하고 유효한 Copilot 사용 권한을 확인합니다.
2. **Customize**의 마켓플레이스 추가 기능(앱 버전에 따라 Settings > Plugins)을 열고 `microsoft/github-copilot-modernization`을 추가합니다. 출처를 검토하고 허용한 뒤 `github-copilot-modernization` 플러그인의 **Install**을 선택합니다.
3. Agent picker에서 `modernize` 또는 `github-copilot-modernization:modernize`가 보이는지 확인합니다. 내부 coordinator/worker를 직접 선택하지 않습니다.
4. .NET 참가자는 [공식 Upgrade 설치 링크와 app 안내](https://github.com/microsoft/upgrade-agent-plugins#github-copilot-app)를 열어 `microsoft/upgrade-agent-plugins` 마켓플레이스를 추가하고 `upgrade-agent`를 설치합니다. Agent picker의 **Upgrade**를 확인합니다.

설치 뒤 목록이 갱신되지 않으면 앱 새 세션/재시작과 조직 정책을 확인합니다. .NET 안내의 예시가 더 새 버전을 가리켜도 이번 목표는 **.NET 10**입니다. 무인 자동 승인이나 모든 권한 허용을 켜지 않습니다. 앱 UI에서 플러그인이 보이지 않으면 [문제 해결](troubleshooting.md)을 확인하고 멈춥니다. CLI로 임의 전환하지 않습니다.

## 4. 사전 점검을 먼저 실행

복제한 **워크숍 자료 루트**에서 선택한 명령 하나를 실행합니다. 기본 Docker 대신 Podman을 선택했다면 엔진 인자도 바꿉니다.

| 환경 | 명령 |
| --- | --- |
| Java, WSL2/macOS Bash | `bash scripts/check-prerequisites.sh --track java --container-engine docker` |
| Java, Windows PowerShell 7 | `pwsh -File ./scripts/check-prerequisites.ps1 -Track java -WslDistribution Ubuntu -ContainerEngine docker` |
| .NET, Windows PowerShell 7 | `pwsh -File ./scripts/check-prerequisites.ps1 -Track dotnet -ContainerEngine docker` |
| .NET, Windows Git Bash | `bash scripts/check-prerequisites.sh --track dotnet --container-engine docker` |

`Ubuntu`는 실제 WSL2 배포판 이름으로 바꿉니다. 배포판이 여럿이면 PowerShell 진입점은 이름을 명시해야 합니다. macOS에서 PowerShell Java 진입점을 사용하면 로컬 Bash로 위임합니다. .NET Bash 진입점은 Windows `pwsh`로 위임합니다.

| 결과 | 의미 |
| --- | --- |
| `PASS` | 해당 자동 검사 통과 |
| `FAIL` | 필수 검사 실패. 해결하고 재실행 |
| `WARN` | 제한 또는 추가 확인 필요 |
| `MANUAL` | 자동 검증하지 못한 항목. 참가자 직접 확인 필요 |

종료 코드 `0`은 필수 자동 검사 통과, `1`은 환경 검사 실패, `2`는 잘못된 인자 또는 엔진 충돌입니다. Bash는 `echo $?`, PowerShell은 `$LASTEXITCODE`로 확인합니다. `MANUAL`은 성공을 뜻하지 않습니다.

## 5. 점검 통과 후 다운로드

같은 트랙, 같은 엔진, 같은 실행 환경을 사용합니다.

```bash
# Java WSL2/macOS. .NET Git Bash이면 --track dotnet
bash scripts/download-sample.sh --track java --container-engine docker
```

```powershell
# .NET Windows
pwsh -File ./scripts/download-sample.ps1 -Track dotnet -ContainerEngine docker
# Java Windows는 WSL2로 위임
pwsh -File ./scripts/download-sample.ps1 -Track java -WslDistribution Ubuntu -ContainerEngine docker
```

위 PowerShell 예시는 **두 트랙을 모두 실행하라는 의미가 아닙니다**. 선택한 명령 하나만 실행합니다.

기본 위치는 호출한 터미널 폴더가 아니라 스크립트 상위의 워크숍 루트를 기준으로 한 `java` 또는 `dotnet`입니다. 사용자 지정 **상대 경로**는 호출자의 현재 작업 폴더 기준입니다.

Bash 인자에는 POSIX 경로를 사용합니다. Windows Git Bash의 사용자 지정 경로는 `/c/workshops/contoso-app`처럼 쓰고, Windows PowerShell에서는 `C:/workshops/contoso-app`처럼 씁니다. Bash의 `//server/...` 및 Windows 확장/장치 경로는 지원하지 않습니다.

```powershell
pwsh -File ./scripts/download-sample.ps1 -Track dotnet -Destination 'C:/workshops/contoso-app' -ContainerEngine podman
```

```bash
bash scripts/download-sample.sh --track java --destination "$HOME/workshops/asset-app" --container-engine podman
```

대상은 없거나 빈 폴더여야 합니다. 기존 앱, 숨김 파일이 있는 폴더, 홈/루트, 워크숍 루트와 `docs`/`scripts`/`tests`, 심볼릭 링크/junction을 경유하는 경로는 거부합니다. 기존 앱을 갱신하거나 덮어쓰는 옵션은 없습니다. 실패하면 대상 상태를 확인하고 빈 경로로 다시 시도하세요. 네트워크 오류 시 내려받기용 임시 폴더는 정리하지만, 디스크 복사 중 오류가 난 대상은 미완료 파일이 남을 수 있으므로 자동 성공으로 간주하지 않습니다.

샘플 출처/SHA는 `upstream-source.json`, 앱 루트에는 자체 `.git`이 생깁니다. 커밋, 전역 Git 사용자 설정, GitHub 원격 저장소는 만들지 않습니다. 다운로드만으로 앱 동작 확인이 끝난 것은 아닙니다.

원본 코드와 대상 프레임워크는 수정하지 않습니다. 원본 루트의 `LICENSE`/`LICENCE`, `NOTICE`, `COPYING`, `COPYRIGHT` 파일은 확장자나 접미사가 있어도 원래 파일 이름 앞에 `UPSTREAM-`을 붙여 내용 그대로 보존합니다. 원본에 `upstream-source.json` 또는 보존할 고지와 같은 이름의 파일이 이미 있으면 덮어쓰지 않고 다운로드를 중단합니다.

## 완료 기준과 다음 단계

다음 조건을 모두 충족해야 합니다. 개인 계정에 템플릿 기반 저장소를 만들어 복제했고, 필수 자동 검사에 실패가 없으며, 수동 항목을 확인했습니다. 또한 선택한 앱 폴더에 Java의 `pom.xml` 또는 .NET의 `ContosoUniversity.sln`이 있어야 합니다. 기본 위치라면 각각 `java/pom.xml` 또는 `dotnet/ContosoUniversity.sln`입니다. 기본 다운로드 폴더는 워크숍 저장소의 `.gitignore`에 의해 Git 추적 대상에서 제외됩니다. 별도 경로를 선택했다면 앱이 다른 저장소에 실수로 포함되지 않는지도 확인하세요.

[Java 실습 1: 원본 실행](java/01-run-locally.md) 또는 [.NET 실습 1: 원본 실행](dotnet/01-run-locally.md)으로 이동합니다.

## 공식 참고 자료

- [Modernization 플러그인과 사용자 진입 에이전트](https://github.com/microsoft/github-copilot-modernization)
- [Upgrade 플러그인의 Copilot app 설치 안내](https://github.com/microsoft/upgrade-agent-plugins)
- [azd 명령](https://learn.microsoft.com/azure/developer/azure-developer-cli/azd-commands), [azure.yaml 스키마](https://learn.microsoft.com/azure/developer/azure-developer-cli/azd-schema)
- [azd 1.37.3의 Docker/Podman 런타임 선택 구현](https://github.com/Azure/azure-dev/blob/azure-dev-cli_1.37.3/cli/azd/pkg/tools/docker/docker.go)
- [컨테이너 앱 관리 ID](https://learn.microsoft.com/azure/container-apps/managed-identity), [컨테이너 앱 네트워크](https://learn.microsoft.com/azure/container-apps/networking)
