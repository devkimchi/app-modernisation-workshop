# .NET 준비: 저장소 생성부터 샘플 다운로드까지

[전체 목차](../../README.md) | [.NET 목차](README.md) | [다음: 원본 실행](01-run-locally.md) | [문제 해결](08-troubleshooting.md)

## 실행 환경

원본 .NET Framework 앱은 **Windows**에서 진행합니다. Copilot app에서 코드 작업을 하고 **Windows PowerShell 7, MSBuild와 IIS Express**로 빌드하고 실행합니다. Visual Studio IDE를 열 필요는 없습니다.

### 사전 설치 항목

- [GitHub Copilot app](https://gh.io/app)
- [Git](https://git-scm.com/downloads)과 [GitHub CLI](https://cli.github.com/)
- [PowerShell 7](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-windows)
- [WSL2 플랫폼](https://learn.microsoft.com/windows/wsl/install)

WSL2 플랫폼은 공통 스크립트의 Windows 호스트 필수 항목입니다. .NET 앱은 Windows에서 실행하며 Linux 배포판은 필요하지 않습니다.

## 1. 템플릿으로 저장소 만들고 클론하기

1. [워크숍 템플릿](https://github.com/devkimchi/app-modernisation-workshop)에서 **Use this template > Create a new repository**를 선택하거나 [![GitHub에서 템플릿으로 저장소 만들기](https://img.shields.io/badge/GitHub-Create%20repository%20from%20template-2ea44f?style=flat&logo=github&logoColor=white)](https://github.com/new?template_name=app-modernisation-workshop&template_owner=devkimchi)을 클릭합니다.
2. Owner는 본인 **개인 계정**으로 지정합니다. 공개할 계획이 없다면 **Private**을 선택하고, **Include all branches**는 선택하지 않습니다.
3. 저장소를 만든 뒤 GitHub CLI(`gh`)를 사용할 수 있는 Windows PowerShell에서 복제합니다. 아래 값을 실제 계정과 저장소 이름으로 바꾸세요. (예: `octocat/app-modernisation-workshop`)

```powershell
gh repo clone <본인-계정>/<저장소-이름>
cd <저장소-이름>
```

복제한 폴더가 **워크숍 루트**입니다. 이후 명령은 이 폴더에서 실행합니다.

> [!NOTE]
>
> 템플릿 저장소를 직접 클론하거나 포크하지 않습니다. 템플릿으로 만든 저장소는 독립된 이력을 가지며 원본의 이후 변경을 자동으로 받지 않습니다.

## 2. 필수 도구 설치 여부 확인하기

### 도구 설치 여부 점검

**Windows PowerShell**에서 실행합니다. Windows PowerShell 5.1에서 시작해도 실제 작업은 PowerShell 7에서 수행합니다.

```powershell
powershell.exe -File ./scripts/check-prerequisites.ps1 -Track dotnet -ContainerEngine docker
```

이 문서는 Docker를 기준으로 설명합니다. 현재 셸에 `AZD_CONTAINER_RUNTIME`이 이미 설정되어 있다면 `docker`인지 확인합니다. 엔진 설정 충돌이나 대체 엔진은 [문제 해결의 엔진 설정](08-troubleshooting.md#대체-엔진-설정)을 참고하세요.

| 결과 | 할 일 |
| --- | --- |
| `PASS` | 해당 검사 통과. 실제 앱 실행이나 배포 성공을 뜻하지 않음 |
| `FAIL` | 부족한 도구나 설정을 보완한 뒤 다시 점검 |
| `WARN` | 오류 내용과 검사 제한 확인 |
| `MANUAL` | 직접 확인. Copilot 플러그인은 3단계에서 설치 |
| `INFO` | 참고 정보 |

### 도구 설치와 업데이트

누락된 도구를 설치하고, 업데이트 가능한 기존 도구는 **항목별로 `y`로 승인한 경우에만** 갱신합니다. 누락된 도구만 설치하려면 `-Update`를 생략하세요.

**대화형 Windows PowerShell**에서 실행합니다. PowerShell 7이 아직 없어도 다음 명령으로 시작할 수 있습니다. CI나 입력·출력이 리디렉션된 환경에서는 설치하지 않습니다.

```powershell
powershell.exe -File ./scripts/install-prerequisites.ps1 -Track dotnet -ContainerEngine docker -Update
```

점검은 상태만 조회합니다. 설치 도우미는 도구 설치 후 Azure CLI와 `azd` 로그인, 구독 선택, 누락된 `containerapp` 확장 설치와 공급자 등록을 항목별 동의를 받아 진행합니다. 브라우저나 장치 코드 인증은 직접 완료하세요.

| 대상 | 설치와 업데이트 |
| --- | --- |
| PowerShell 7 | 기존 winget으로 설치하며, 관리 출처가 확인되는 설치본만 업데이트합니다. |
| WSL2 플랫폼 | Linux 배포판 없이 설치합니다. 버전을 확인할 수 있는 플랫폼만 업데이트합니다. |
| Node.js 22 이상 | nvm-windows로 설치합니다. 업데이트 시 현재 메이저의 최신 정식 버전을 추가하며, 없거나 22 미만이면 22.x를 선택합니다. 기존 버전은 보존하고 설치와 활성화는 별도로 승인받습니다. |
| Azure CLI, azd(1.37.3 이상) | 기존 winget으로 누락된 도구만 설치합니다. 업데이트는 원래 설치 관리자로 직접 진행합니다. |

관리자 승인이나 WSL2 설치 후 재부팅이 필요할 수 있습니다. 도우미는 자동 재부팅하지 않으므로 안내에 따라 직접 재부팅한 뒤 다시 실행하세요. 설치나 업데이트가 끝나지 않으면 [문제 해결](08-troubleshooting.md#사전-준비-수동-복구)을 확인합니다.

### Windows 빌드 및 실행 도구 준비

아래 구성요소는 도우미가 **자동 설치하지 않습니다**. 점검에서 누락된 항목만 준비하세요.

| 구성요소 | 수동 준비 |
| --- | --- |
| Framework 웹 빌드 도구 | [Visual Studio 2022/2026 IDE 또는 Build Tools](https://visualstudio.microsoft.com/downloads/). IDE는 **ASP.NET 및 웹 개발**, Build Tools는 **Web development build tools** 워크로드 |
| .NET Framework | **4.8 이상 런타임과 4.8 Targeting Pack** 모두 필요. 런타임이나 .NET 10 SDK만으로 대체할 수 없음 |
| IIS Express | Visual Studio Installer 개별 구성요소 또는 [IIS Express 10](https://www.microsoft.com/download/details.aspx?id=48264) |
| SQL Server Express LocalDB | Visual Studio Installer 개별 구성요소 또는 [SQL Server Express](https://www.microsoft.com/sql-server/sql-server-downloads)의 LocalDB 설치 옵션. 실습 전용 DB 사용 |
| .NET 10 SDK | [공식 설치 안내](https://dotnet.microsoft.com/download/dotnet/10.0). 현대화 이후 빌드용 |
| MSMQ Server | [Windows 기능 활성화](https://learn.microsoft.com/dotnet/framework/wcf/samples/installing-message-queuing-msmq) 후 필요한 재부팅 완료. MSMQ 서비스가 Running인지 확인 |

원본은 `System.Web` 기반의 비 SDK 형식 프로젝트이므로 `dotnet build`/`dotnet run`이 아닌 전체 Framework MSBuild와 IIS Express를 사용합니다. 실제 절차는 [실습 1](01-run-locally.md)에서 진행합니다.

### 직접 준비할 항목

- **Azure 권한**: 표시된 구독과 테넌트가 실습 대상인지 확인합니다. 리전, 쿼터, 역할 할당과 DB Entra 관리자 설정 권한은 별도 준비합니다. Contributor만으로 역할 할당 권한이 확보되지는 않습니다. 필요한 범위의 권한을 요청하고 구독 전체 Owner를 무조건 요청하지 마세요.
- **컨테이너 엔진**: [Docker Desktop](https://docs.docker.com/desktop/)을 설치하고 시작합니다. Linux containers 모드를 사용합니다.
- **Copilot 사용 권한**: [앱](https://github.com/copilot/app) 로그인, 라이선스와 조직의 플러그인 정책을 확인합니다.

azd가 같은 엔진을 사용하도록 **실습할 PowerShell마다** 설정합니다. 스크립트는 부모 셸을 변경하지 않습니다.

```powershell
$env:AZD_CONTAINER_RUNTIME = 'docker'
```

준비 후 점검 명령을 다시 실행해 필수 `FAIL`을 해결하고, 이 단계에서 확인 가능한 수동 항목을 확인하세요.

## 3. Copilot app에 플러그인 설치하기

1. Copilot app에서 GitHub 계정으로 로그인합니다.
2. **Customize**의 마켓플레이스 추가 기능(앱 버전에 따라 Settings > Plugins)에서 `microsoft/github-copilot-modernization`을 추가합니다.
3. 출처를 검토하고 허용한 뒤 `github-copilot-modernization` 플러그인을 설치합니다. Agent picker에서 `modernize` 또는 `github-copilot-modernization:modernize`를 확인합니다.
4. [공식 Upgrade 설치 안내](https://github.com/microsoft/upgrade-agent-plugins#github-copilot-app)에 따라 `microsoft/upgrade-agent-plugins` 마켓플레이스를 추가하고 `upgrade-agent`를 설치합니다. Agent picker에서 **Upgrade**를 확인합니다.

업그레이드는 **Upgrade**, Azure 이전은 **modernize**를 사용합니다. 내부 coordinator/worker는 직접 선택하지 않습니다. 외부 안내가 더 새 버전을 가리켜도 이번 목표는 **.NET 10**입니다.

목록이 갱신되지 않으면 새 세션이나 앱 재시작을 시도합니다. 무인 자동 승인이나 모든 권한 허용을 켜지 마세요. 문제가 계속되면 [문제 해결](08-troubleshooting.md)을 확인하고 멈춥니다. Copilot CLI나 VS Code로 임의 전환하지 않습니다.

## 4. 샘플 다운로드하기

점검과 플러그인 설치를 마친 뒤 **Windows PowerShell의 워크숍 루트**에서 실행합니다.

```powershell
powershell.exe -File ./scripts/download-sample.ps1 -Track dotnet -ContainerEngine docker
```

샘플은 워크숍 루트의 `dotnet` 폴더에 다운로드됩니다. 다운로드할 `dotnet` 폴더는 없거나 비어 있어야 합니다.

`dotnet/ContosoUniversity.sln`이 있는지 확인한 뒤 [실습 1: 원본 실행](01-run-locally.md)으로 이동합니다. 기본 경로의 앱 파일은 워크숍 저장소에서 관리하며, 실습 1에서 생성 파일과 비밀이 없는지 검토한 뒤 기준선 커밋을 만듭니다. 저장소 밖에 다운로드했다면 해당 앱은 이 저장소에서 추적되지 않습니다.
