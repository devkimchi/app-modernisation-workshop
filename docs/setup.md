# 공통 준비: 저장소를 만들고 점검한 뒤 샘플 받기

[전체 목차](../README.md) | [문제 해결](troubleshooting.md) | [Java 정리](java/07-cleanup.md) | [.NET 정리](dotnet/07-cleanup.md)

## 목표와 실행 위치

템플릿으로 개인 계정에 저장소를 만들고 클론합니다. 복제한 폴더에서 선택한 트랙의 사전 점검을 실행하고, 부족한 항목을 보완한 뒤 다시 점검합니다. 필수 자동 검사를 통과하면 Copilot app 플러그인을 설치하고 원본 앱을 내려받습니다.

점검 스크립트는 소프트웨어를 설치하거나 관리자 권한을 요청하지 않습니다. 설치 도우미는 별도로 실행하며 도구마다 설치 전에 동의를 받습니다. 두 스크립트 모두 로그인, 공급자 등록, 컨테이너 엔진 시작 또는 JDK 기본 버전 변경을 하지 않습니다.

## 1. 템플릿으로 저장소 만들고 클론하기

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

템플릿으로 만든 저장소는 원본과 이어지지 않은 새 커밋 이력으로 시작하며, 원본 템플릿의 이후 변경을 자동으로 받지 않습니다. 이후 내려받는 앱은 `java` 또는 `dotnet` 폴더에 놓이며, 앱 안에 별도의 `.git` 저장소를 만들지 않습니다. 앱 코드와 기준선 커밋은 이 워크숍 저장소에서 관리합니다.

## 2. 사전 점검과 필요한 조치

### 점검 스크립트 실행

클론에 필요한 Git과 아래 명령을 실행할 셸을 먼저 준비합니다. PowerShell 진입점과 .NET Git Bash 진입점에는 PowerShell 7이 필요합니다. Java는 Windows에서 WSL2, macOS에서 Bash를 사용합니다. 도구가 없다면 [공통 도구 설치 안내](#공통-도구와-계정-보완)를 참고하세요.

클론한 **워크숍 자료 루트**에서 선택한 트랙과 환경에 맞는 명령 하나를 실행합니다.

| 환경 | 명령 |
| --- | --- |
| Java, WSL2/macOS Bash | `bash scripts/check-prerequisites.sh --track java --container-engine docker` |
| Java, Windows PowerShell 7 | `pwsh -File ./scripts/check-prerequisites.ps1 -Track java -WslDistribution Ubuntu -ContainerEngine docker` |
| .NET, Windows PowerShell 7 | `pwsh -File ./scripts/check-prerequisites.ps1 -Track dotnet -ContainerEngine docker` |
| .NET, Windows Git Bash | `bash scripts/check-prerequisites.sh --track dotnet --container-engine docker` |

Podman을 사용할 때는 엔진 인자를 `podman`으로 바꿉니다. `Ubuntu`도 실제 WSL2 배포판 이름으로 바꿉니다. 배포판이 여러 개라면 PowerShell 명령에 이름을 반드시 지정해야 합니다. macOS의 PowerShell Java 진입점은 로컬 Bash로, .NET Git Bash 진입점은 Windows `pwsh`로 검사를 넘깁니다.

**Windows Java 트랙의 실행 위치를 구분하세요.** Copilot app은 Windows에서 실행하고 프로젝트 파일을 수정합니다. Java 빌드와 실행, Azure 배포 명령은 WSL Bash에서 수행합니다. 에이전트가 Java 명령을 실행할 때도 WSL 배포판과 프로젝트 경로를 알려 주고 WSL에 위임하도록 요청하세요.

점검 결과의 대괄호는 검사 또는 수동 확인 대상을 나타냅니다. Windows PowerShell의 Java 점검은 Windows의 Git과 Node.js를 검사하고 `azd` 버전을 참고용으로 표시한 뒤, 지정한 WSL 배포판에서 나머지 항목을 검사합니다. WSL Bash에서 직접 실행하면 Windows 호스트는 검사하지 않습니다. Bash에서 Node.js를 찾지 못하거나 WSL에서 Windows 드라이브의 Node.js만 선택되면 nvm을 불러와 기본 버전을 활성화합니다. nvm 경로는 `NVM_DIR`, `$XDG_CONFIG_HOME/nvm`, `~/.nvm` 순서로 결정합니다. 그 밖에 대화형 셸에서만 초기화되는 도구는 비대화형 Bash에서 찾지 못할 수 있습니다.

| 결과 | 의미와 다음 조치 |
| --- | --- |
| `PASS` | 해당 자동 검사 통과 |
| `INFO` | 참고 정보. 필수 검사 통과 여부와 별개 |
| `FAIL` | 필수 검사 실패. 아래 안내를 참고해 해결하고 같은 환경에서 다시 점검 |
| `WARN` | 제한 또는 추가 확인 필요 |
| `MANUAL` | 자동으로 확인하지 않은 항목. 직접 확인하고 Copilot 플러그인은 다음 단계에서 설치 |

`FAIL`을 해결한 뒤 같은 환경에서 점검을 다시 실행하세요. `MANUAL`은 성공을 뜻하지 않으므로 직접 확인해야 합니다. 종료 코드는 `0`이면 필수 자동 검사 통과, `1`이면 환경 검사 실패, `2`이면 잘못된 인자 또는 엔진 충돌입니다. Bash에서는 `echo $?`, PowerShell에서는 `$LASTEXITCODE`로 확인합니다.

### 선택: 누락된 도구 설치

누락된 도구를 설치하려면 **대화형 터미널**에서 아래 명령을 실행합니다. 도우미가 도구마다 설치 대상, 출처와 필요한 권한을 표시합니다. `y`로 승인한 항목만 설치하며, 거부하거나 Enter를 누르면 건너뜁니다. CI 또는 입력이나 출력이 리디렉션된 환경에서는 설치하지 않습니다. 일반 점검과 샘플 다운로드는 설치 도우미를 호출하지 않습니다.

| 설치 대상 | 명령 |
| --- | --- |
| Java, WSL2/macOS | `bash scripts/install-prerequisites.sh --track java --container-engine docker` |
| Java, Windows Copilot app 호스트 | `pwsh -File ./scripts/install-prerequisites.ps1 -Track java -ContainerEngine docker` |
| .NET, Windows | `pwsh -File ./scripts/install-prerequisites.ps1 -Track dotnet -ContainerEngine docker` |

Windows Java 참가자는 필요한 환경마다 명령을 실행하세요. Windows 도우미는 호스트의 Node.js만 설치합니다. WSL 도구는 선택한 배포판을 열고 워크숍 자료 루트에서 Bash 명령을 실행해 설치합니다.

| 환경 | 설치 방식과 주의사항 |
| --- | --- |
| WSL/Linux | nvm을 설치한 뒤 Node.js 22를, SDKMAN을 설치한 뒤 JDK 8, 21, 25를 설치합니다. 각 항목은 별도로 동의받습니다. Azure CLI와 `azd`는 Microsoft 설치 스크립트를 사용합니다. Azure CLI에는 `apt-get`과 `sudo`가 필요하며 시스템 패키지와 APT 저장소가 변경됩니다. `azd`도 설치 위치에 따라 `sudo`가 필요할 수 있습니다. |
| macOS | Node.js와 JDK는 WSL/Linux와 같은 방식으로 설치합니다. Azure CLI와 `azd`에는 기존 Homebrew를 사용합니다. |
| Windows | 기존 `winget`을 사용합니다. 관리자 승인이 필요할 수 있습니다. |

Homebrew와 `winget` 자체는 자동으로 설치하지 않습니다. PATH에서 기존 도구가 발견되면 버전이 오래됐거나 실행에 문제가 있어도 덮어쓰거나 업데이트하지 않습니다. WSL에서 Windows 드라이브의 실행 파일이 선택된 경우에는 WSL에 별도로 설치할지 묻습니다.

SDKMAN에는 Bash 4 이상과 `curl`, `zip`, `unzip`, `tar`, `find`, `sed`가 필요합니다. WSL/Linux에 누락된 명령이 있고 `apt-get`과 `sudo`를 사용할 수 있다면 도우미가 선행 패키지를 설치할지 별도로 묻습니다. 다른 환경에서는 누락된 명령을 직접 설치한 뒤 다시 실행하세요. 이전 설치에 실패해 SDKMAN 경로가 남아 있으면 도우미는 해당 경로를 변경하지 않습니다. 내용을 확인하고 필요한 파일을 보존한 뒤 해당 경로를 직접 옮기거나 정리하고 다시 실행하세요. 기본 경로는 `~/.sdkman`이며 `SDKMAN_DIR`을 설정했다면 그 경로를 사용합니다.

기존 nvm과 SDKMAN은 재사용합니다. JDK는 설치된 정식 버전의 `java`와 `javac`를 확인하고 없는 버전만 설치합니다. 자동 설치에는 현재 환경의 SDKMAN 목록에 있는 Temurin 식별자를 사용합니다. 해당 버전이 없으면 아래 수동 설치 방법으로 다른 배포판을 선택하세요. 기존 기본 JDK는 유지합니다. nvm과 SDKMAN은 셸 설정을 변경할 수 있으며, 현재 터미널에 적용할 초기화 명령은 설치 후 출력됩니다.

컨테이너 엔진은 직접 준비해야 합니다. 도우미는 Windows Java 호스트를 제외하고 설치 후 사전 점검을 다시 실행합니다. 대화형 점검에서는 동의를 받아 Azure 로그인과 누락된 확장 설치도 진행할 수 있습니다. Windows Java 참가자는 WSL 설치까지 마친 뒤 Windows PowerShell 점검 명령을 다시 실행하세요. 새 PATH가 적용되지 않으면 안내된 초기화 명령을 실행하거나 새 터미널에서 점검합니다.

### 공통 도구와 계정 보완

| 항목 | 기준과 확인 범위 | 설치 안내 |
| --- | --- | --- |
| Git | 샘플 다운로드와 워크숍 저장소에서 기준선 관리 | [Git](https://git-scm.com/downloads) |
| PowerShell | .NET 및 PowerShell 진입점은 7 이상, Windows PowerShell 5.1 아님 | [PowerShell](https://learn.microsoft.com/powershell/scripting/install/installing-powershell) |
| Bash | Java는 WSL2/macOS, .NET Bash 진입점은 Git Bash | [WSL](https://learn.microsoft.com/windows/wsl/install), [Git for Windows](https://gitforwindows.org/) |
| Node.js | 워크숍 기준 안정 버전 22 이상 | [Node.js](https://nodejs.org/en/download) |
| GitHub Copilot app | 로그인, 라이선스, 조직 정책은 수동 확인 | [Copilot app](https://github.com/copilot/app) |
| Azure CLI | 설치, `containerapp` 확장, 로그인, 구독, 공급자 상태 | [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) |
| Azure Developer CLI | `azd` 1.37.3 이상, 별도 로그인 상태 | [azd 설치](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd) |
| 컨테이너 엔진 | Docker 또는 Podman CLI와 Linux 서버 연결, 빌더 기능 | [Docker Desktop](https://docs.docker.com/desktop/), [Podman](https://podman.io/docs/installation) |

`gh`, 독립 Maven 설치, Copilot CLI, VS Code는 공통 필수가 아닙니다. Java 원본의 Maven Wrapper가 Maven 3.9.9를 내려받으므로 최초 실행에 네트워크가 필요합니다.

Windows Java 참가자는 Windows 호스트에 Git과 Node.js 22 이상을 준비하고, 선택한 WSL2 배포판에도 Git, Node.js, Azure CLI, `azd`, SDKMAN과 선택한 컨테이너 엔진의 CLI를 준비합니다. Windows에 설치하거나 로그인했다고 해서 WSL에서 사용할 수 있는 것은 아닙니다. nvm 초기화는 점검 스크립트가 처리하지만, 다른 도구도 비대화형 Bash에서 실행할 수 있어야 합니다.

### 자동으로 처리되지 않는 항목

대화형 점검에서는 동의를 받아 Azure CLI와 `azd` 로그인, 구독 선택, 누락된 `containerapp` 확장 설치와 공급자 등록을 진행합니다. 브라우저나 장치 코드 인증은 직접 완료하세요. CI와 비대화형 환경에서는 검사만 합니다. 조치를 거부했거나 실패했다면 [사전 준비 수동 복구](troubleshooting.md#사전-준비-수동-복구)를 참고하세요.

**Azure 대상과 권한**: 표시된 구독과 테넌트가 실습 대상인지 확인하고 리전, 쿼터, 역할 할당 권한 및 데이터베이스 Entra 관리자 설정 권한을 준비합니다. Contributor에는 일반적으로 역할 할당 권한이 포함되지 않습니다. 필요한 범위의 권한을 관리자에게 요청하고, 구독 전체 Owner 권한을 무조건 요청하지 마세요. 배포 계획에 네트워크 리소스를 추가하면 별도 공급자 등록과 비용 검토도 필요할 수 있습니다.

**컨테이너 엔진**: Docker 또는 Podman을 직접 설치하고 시작합니다. Windows Java에서 Docker Desktop을 사용하면 Linux containers 모드와 선택한 WSL 배포판의 통합을 켜세요. Podman은 필요한 경우에만 machine을 직접 생성하거나 시작합니다. Windows와 WSL의 CLI가 같은 엔진에 연결된다고 가정하지 마세요.

`azd`가 선택한 엔진을 사용하도록 **각 실습 셸**에서 설정합니다. 스크립트는 부모 셸의 환경 변수를 변경하지 않습니다.

```powershell
$env:AZD_CONTAINER_RUNTIME = 'docker' # Podman은 'podman'
```

```bash
export AZD_CONTAINER_RUNTIME=docker # Podman은 podman
```

`linux/amd64` 이미지 빌드, 포트 접근과 ACR 게시는 실습 중 확인합니다. CLI와 엔진 연결 검사의 `PASS`만으로 실제 워크로드 성공이 보장되지는 않습니다. Podman은 내장 빌더를 사용하므로 Docker Buildx가 필요하지 않습니다.

**.NET Windows 구성요소**: 아래 항목은 자동 설치하지 않습니다. 누락된 항목만 준비한 뒤 점검을 다시 실행하세요. Visual Studio IDE는 실행할 필요가 없으며, 원본 빌드와 실행은 [실습 1](dotnet/01-run-locally.md)의 CLI 도우미를 사용합니다.

| 구성요소 | 수동 준비 |
| --- | --- |
| Framework 웹 빌드 도구 | [Visual Studio 2022/2026 IDE 또는 Build Tools](https://visualstudio.microsoft.com/downloads/). IDE는 **ASP.NET 및 웹 개발**, Build Tools는 **Web development build tools** 워크로드 |
| .NET Framework | **4.8 이상 런타임과 4.8 Targeting Pack** 모두 필요. 런타임이나 .NET 10 SDK만으로 대체할 수 없음 |
| IIS Express | Visual Studio Installer 개별 구성요소 또는 [IIS Express 10](https://www.microsoft.com/download/details.aspx?id=48264) |
| SQL Server Express LocalDB | Visual Studio Installer 개별 구성요소 또는 [SQL Server Express](https://www.microsoft.com/sql-server/sql-server-downloads)의 LocalDB 설치 옵션. 실습 전용 DB 사용 |
| .NET 10 SDK | [공식 설치 안내](https://dotnet.microsoft.com/download/dotnet/10.0). 현대화 이후 빌드용 |
| MSMQ Server | [Windows 기능 활성화](https://learn.microsoft.com/dotnet/framework/wcf/samples/installing-message-queuing-msmq) 후 필요한 재부팅 완료. MSMQ 서비스가 Running인지 확인 |

필수 `FAIL`을 해결하고 `MANUAL` 항목을 확인한 뒤 다음 단계로 진행합니다. 설치 오류나 지원되지 않는 JDK 배포판은 [문제 해결](troubleshooting.md#사전-준비-수동-복구)을 참고하세요.

## 3. Copilot app에 플러그인 설치

1. Copilot app에서 GitHub 계정으로 로그인하고 유효한 Copilot 사용 권한을 확인합니다.
2. **Customize**의 마켓플레이스 추가 기능(앱 버전에 따라 Settings > Plugins)을 열고 `microsoft/github-copilot-modernization`을 추가합니다. 출처를 검토하고 허용한 뒤 `github-copilot-modernization` 플러그인의 **Install**을 선택합니다.
3. Agent picker에서 `modernize` 또는 `github-copilot-modernization:modernize`가 보이는지 확인합니다. 내부 coordinator/worker를 직접 선택하지 않습니다.
4. .NET 참가자는 [공식 Upgrade 설치 링크와 app 안내](https://github.com/microsoft/upgrade-agent-plugins#github-copilot-app)를 열어 `microsoft/upgrade-agent-plugins` 마켓플레이스를 추가하고 `upgrade-agent`를 설치합니다. Agent picker의 **Upgrade**를 확인합니다.

설치 후 목록이 갱신되지 않으면 앱에서 새 세션을 열거나 앱을 다시 시작하고, 조직 정책도 확인합니다. .NET 안내의 예시가 더 새 버전을 가리켜도 이번 목표는 **.NET 10**입니다. 무인 자동 승인이나 모든 권한 허용을 켜지 마세요. 앱 UI에 플러그인이 보이지 않으면 [문제 해결](troubleshooting.md)을 확인하고 멈춥니다. CLI로 임의 전환하지 않습니다.

## 4. 점검과 플러그인 설치 후 다운로드

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

샘플 출처와 고정 커밋 SHA는 앱 루트의 `upstream-source.json`에 기록됩니다. 스크립트는 고정 커밋 검증에만 임시 Git checkout을 사용하고 다운로드가 끝나면 제거합니다. 다운로드한 앱 안에는 중첩 `.git`을 만들지 않으며, 다운로드 단계에서 기준선 커밋이나 GitHub push도 하지 않습니다. 기본 경로의 앱 파일은 워크숍 저장소가 추적하므로 실습 1에서 변경을 검토한 뒤 그 저장소에 기준선 커밋을 만듭니다. 사용자 지정 경로가 워크숍 저장소 밖에 있으면 해당 파일은 이 저장소에서 추적되지 않습니다. 다운로드만으로 앱 동작 확인이 끝난 것은 아닙니다.

원본 코드와 대상 프레임워크는 수정하지 않습니다. 원본 루트의 `LICENSE`/`LICENCE`, `NOTICE`, `COPYING`, `COPYRIGHT` 파일은 확장자나 접미사가 있어도 원래 파일 이름 앞에 `UPSTREAM-`을 붙여 내용 그대로 보존합니다. 원본에 `upstream-source.json` 또는 보존할 고지와 같은 이름의 파일이 이미 있으면 덮어쓰지 않고 다운로드를 중단합니다.

## 완료 기준과 다음 단계

다음 조건을 모두 충족해야 합니다. 개인 계정에 템플릿 기반 저장소를 만들어 복제했고, 필수 자동 검사에 실패가 없으며, Copilot 플러그인과 이 단계에서 확인 가능한 수동 항목을 확인했습니다. 실제 컨테이너 빌드, 포트 접근과 ACR 게시는 해당 실습에서 확인합니다. 또한 선택한 앱 폴더에 Java의 `pom.xml` 또는 .NET의 `ContosoUniversity.sln`이 있어야 합니다. 기본 위치라면 각각 `java/pom.xml` 또는 `dotnet/ContosoUniversity.sln`입니다. 기본 다운로드 위치의 앱 파일은 워크숍 저장소에서 추적됩니다. 실습 1에서 생성 파일과 비밀이 없는지 확인한 뒤 기준선 커밋을 만드세요. 사용자 지정 경로를 쓴 경우 그 경로가 어느 저장소에 속하는지 먼저 확인합니다.

[Java 실습 1: 원본 실행](java/01-run-locally.md) 또는 [.NET 실습 1: 원본 실행](dotnet/01-run-locally.md)으로 이동합니다.

## 공식 참고 자료

- [Modernization 플러그인과 사용자 진입 에이전트](https://github.com/microsoft/github-copilot-modernization)
- [Upgrade 플러그인의 Copilot app 설치 안내](https://github.com/microsoft/upgrade-agent-plugins)
- [azd 명령](https://learn.microsoft.com/azure/developer/azure-developer-cli/azd-commands), [azure.yaml 스키마](https://learn.microsoft.com/azure/developer/azure-developer-cli/azd-schema)
- [azd 1.37.3의 Docker/Podman 런타임 선택 구현](https://github.com/Azure/azure-dev/blob/azure-dev-cli_1.37.3/cli/azd/pkg/tools/docker/docker.go)
- [컨테이너 앱 관리 ID](https://learn.microsoft.com/azure/container-apps/managed-identity), [컨테이너 앱 네트워크](https://learn.microsoft.com/azure/container-apps/networking)
