# Java 준비: 저장소 생성부터 샘플 다운로드까지

[전체 목차](../../README.md) | [Java 목차](README.md) | [다음: 원본 실행](01-run-locally.md) | [문제 해결](8-troubleshooting.md)

## 실행 환경

Windows에서는 **WSL2 Bash**, macOS에서는 **Bash** 또는 **Zsh** 를 사용합니다.

> [!WARNING]
> **Windows 사용자**
>
> Windows의 Copilot app은 프로젝트 파일을 수정하고, Java 빌드와 실행 및 Azure 배포 명령은 WSL에서 수행합니다. 에이전트에게 사용할 WSL 배포판과 프로젝트 경로를 알려 주고 해당 환경에서 명령을 실행하도록 요청하세요. Windows에 설치하거나 로그인한 도구를 WSL에서도 사용할 수 있다고 가정하지 마세요.

### 사전 설치 항목

- [GitHub Copilot app](https://gh.io/app)
- **Windows 사용자**: [WSL](https://learn.microsoft.com/windows/wsl/install)
- **Windows 사용자**: [PowerShell 7](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-windows)

## 1. 템플릿으로 저장소 만들고 클론하기

1. [워크숍 템플릿](https://github.com/devkimchi/app-modernisation-workshop)에서 **Use this template > Create a new repository**를 선택하거나 또는 [![GitHub에서 템플릿으로 저장소 만들기](https://img.shields.io/badge/GitHub-Create%20repository%20from%20template-2ea44f?style=flat&logo=github&logoColor=white)](https://github.com/new?template\_name=app-modernisation-workshop&template\_owner=devkimchi)을 클릭하세요.
2. Owner는 본인 **개인 계정**으로 지정합니다. 공개할 계획이 없다면 **Private**을 선택하고, **Include all branches**는 선택하지 않습니다.
3. 저장소를 만든 뒤 GitHub CLI(`gh`)를 사용할 수 있는 터미널에서 복제합니다. 아래 값을 실제 계정과 저장소 이름으로 바꾸세요. (예: `octocat/app-modernisation-workshop`)

```text
gh repo clone <본인-계정>/<저장소-이름>
cd <저장소-이름>
```

복제한 폴더가 **워크숍 루트**입니다. 이후 명령은 이 폴더에서 실행합니다. Windows에서는 WSL에서도 접근할 수 있는 위치를 사용하세요.

> [!NOTE]
>
> 템플릿 저장소를 직접 클론하거나 포크하지 않습니다. 템플릿으로 만든 저장소는 독립된 이력을 가지며 원본의 이후 변경을 자동으로 받지 않습니다.

## 2. 필수 도구 설치여부 확인하기

WSL2 또는 macOS Bash에서 실행합니다.

```bash
bash scripts/check-prerequisites.sh --track java --container-engine docker
```

Windows 호스트의 Git과 Node.js까지 함께 검사하려면 **Windows PowerShell 7**에서 다음 명령을 대신 실행합니다. 기본 배포판은 정확한 이름이 `Ubuntu`인 WSL2 배포판입니다. 해당 배포판이 없거나 WSL1이면 실패하며 다른 배포판으로 자동 전환하지 않습니다. 다른 이름을 사용한다면 [배포판 지정 방법](8-troubleshooting.md#wsl-배포판-지정)을 참고하세요.

```powershell
pwsh -File ./scripts/check-prerequisites.ps1 -Track java -ContainerEngine docker
```

이 문서는 Docker를 기준으로 설명합니다. 현재 셸에 `AZD_CONTAINER_RUNTIME`이 이미 설정되어 있다면 `docker`인지 확인합니다. 엔진 설정 충돌이나 대체 엔진은 [문제 해결의 엔진 설정](8-troubleshooting.md#대체-엔진-설정)을 참고하세요.

| 결과 | 할 일 |
| --- | --- |
| `PASS` | 해당 검사 통과. 실제 앱 실행이나 배포 성공을 뜻하지 않음 |
| `FAIL` | 부족한 도구나 설정을 보완한 뒤 다시 점검 |
| `WARN` | 오류 내용과 검사 제한 확인 |
| `MANUAL` | 직접 확인. Copilot 플러그인은 3단계에서 설치 |
| `INFO` | 참고 정보 |

대화형 점검에서는 별도 동의를 받아 Azure CLI와 `azd` 로그인, 구독 선택, 누락된 `containerapp` 확장 설치 및 공급자 등록을 진행합니다. 브라우저나 장치 코드 인증은 직접 완료하세요. CI와 비대화형 환경에서는 검사만 합니다.

### 누락된 도구 설치

**WSL2/macOS의 대화형 Bash**에서 설치 도우미를 실행합니다. 도구마다 설치 대상, 출처와 권한을 표시하며 `y`로 승인한 항목만 설치합니다.

```bash
bash scripts/install-prerequisites.sh --track java --container-engine docker
```

| 대상 | 설치 방식 |
| --- | --- |
| Node.js 22 | nvm 설치 또는 재사용 후 설치 |
| Azure CLI, azd | WSL은 공식 설치 스크립트, macOS는 기존 Homebrew 사용 |
| JDK 8, 21, 25 | SDKMAN 설치 또는 재사용 후 누락된 정식 Temurin JDK만 설치 |

기존 PATH의 도구는 오래됐더라도 자동 업데이트하지 않습니다. WSL에서 Windows 실행 파일만 발견하면 WSL에 별도로 설치할 수 있습니다. 기존 기본 JDK는 유지합니다. nvm과 SDKMAN은 셸 설정을 변경할 수 있으며, 현재 터미널에 적용할 초기화 명령은 설치 후 출력됩니다.

WSL의 Azure CLI 설치에는 `apt-get`과 `sudo`가 필요하며 APT 저장소와 시스템 패키지가 변경됩니다. azd도 설치 위치에 따라 sudo가 필요할 수 있습니다. SDKMAN의 선행 도구가 없으면 APT 환경에서 패키지 설치 여부를 별도로 묻습니다. Homebrew 자체는 설치하지 않습니다.

Windows 호스트의 선행 도구나 Node.js가 없다면 **대화형 PowerShell 7 또는 Windows PowerShell 5.1**에서 별도로 실행합니다. PowerShell 7이 아직 없어도 다음 명령으로 시작할 수 있습니다.

```powershell
powershell.exe -File ./scripts/install-prerequisites.ps1 -Track java -ContainerEngine docker
```

누락된 **PowerShell 7**은 기존 winget의 `Microsoft.PowerShell` 패키지로, **WSL2 플랫폼**은 `wsl.exe --install --no-distribution`으로 설치할지 **각각** 묻고 `y`로 승인한 항목만 설치합니다. WSL2 설치는 Windows 기능 변경, 관리자 권한과 재부팅이 필요할 수 있습니다. 도우미는 재부팅하지 않고 종료하므로 필요하면 직접 재부팅한 뒤 같은 명령을 다시 실행하세요. CI와 입력·출력이 리디렉션된 비대화형 환경에서는 설치하지 않습니다. Linux 배포판과 WSL 안의 도구는 설치하지 않으므로 Java용 WSL2 배포판은 따로 준비합니다. 두 항목이 준비되면 PowerShell 7에서 누락된 Windows Node.js의 설치 동의를 받습니다.

설치 후 같은 점검 명령을 다시 실행하세요. Bash 점검은 필요한 경우 `NVM_DIR`, `$XDG_CONFIG_HOME/nvm`, `~/.nvm` 중 설정에 맞는 경로에서 nvm을 불러와 기본 Node.js를 활성화합니다. 다른 도구도 비대화형 Bash에서 실행할 수 있어야 합니다.

### 직접 준비할 항목

- **Azure 권한**: 표시된 구독과 테넌트가 실습 대상인지 확인합니다. 리전, 쿼터, 역할 할당과 DB Entra 관리자 설정 권한은 별도 준비합니다. Contributor만으로 역할 할당 권한이 확보되지는 않습니다. 필요한 범위의 권한을 요청하고 구독 전체 Owner를 무조건 요청하지 마세요.
- **컨테이너 엔진**: [Docker Desktop](https://docs.docker.com/desktop/)을 설치하고 시작합니다. Windows Docker Desktop은 Linux containers 모드와 선택한 WSL 배포판의 통합을 켭니다. Windows와 WSL의 CLI가 같은 엔진에 연결된다고 가정하지 마세요.
- **Copilot 사용 권한**: 앱 로그인, 라이선스와 조직의 플러그인 정책을 확인합니다.

azd가 같은 엔진을 사용하도록 **실습할 Bash마다** 설정합니다. 스크립트는 부모 셸을 변경하지 않습니다.

```bash
export AZD_CONTAINER_RUNTIME=docker
```

컨테이너의 실제 `linux/amd64` 빌드, 포트 접근과 ACR 게시는 해당 실습에서 확인합니다. Maven 3.9.9는 샘플의 Maven Wrapper가 내려받으며 Spring Boot는 프로젝트 의존성이므로 별도 설치하지 않습니다.

필수 `FAIL`을 해결하고, 이 단계에서 확인 가능한 수동 항목을 확인하세요. 설치 실패나 Temurin 미제공 환경은 [수동 복구](8-troubleshooting.md#사전-준비-수동-복구)를 참고합니다. 종료 코드는 `0`이면 필수 자동 검사 통과, `1`이면 환경 검사 실패, `2`이면 인자 오류입니다.

## 3. Copilot app에 플러그인 설치하기

1. Copilot app에서 GitHub 계정으로 로그인합니다.
2. **Customize**의 마켓플레이스 추가 기능(앱 버전에 따라 Settings > Plugins)에서 `microsoft/github-copilot-modernization`을 추가합니다.
3. 출처를 검토하고 허용한 뒤 `github-copilot-modernization` 플러그인을 설치합니다.
4. Agent picker에 `modernize` 또는 `github-copilot-modernization:modernize`가 보이는지 확인합니다. 내부 coordinator/worker를 직접 선택하지 않습니다.

목록이 갱신되지 않으면 새 세션이나 앱 재시작을 시도합니다. 무인 자동 승인이나 모든 권한 허용을 켜지 마세요. 문제가 계속되면 [문제 해결](8-troubleshooting.md)을 확인하고 멈춥니다. Copilot CLI나 VS Code로 임의 전환하지 않습니다.

## 4. 샘플 다운로드하기

점검과 플러그인 설치를 마친 뒤 **WSL2/macOS Bash의 워크숍 루트**에서 실행합니다.

```bash
bash scripts/download-sample.sh --track java --container-engine docker
```

Windows PowerShell에서 WSL에 위임하려면 위 명령 대신 다음을 사용합니다.

```powershell
pwsh -File ./scripts/download-sample.ps1 -Track java -ContainerEngine docker
```

다운로드 직전에 사전 점검을 다시 실행하며 실패하면 다운로드하지 않습니다. 기본 대상은 워크숍 루트의 `java`입니다. 다른 경로가 필요하면 Bash에서 `--destination "$HOME/workshops/asset-app"`을 지정합니다. 상대 경로는 호출자의 현재 폴더 기준입니다.

대상은 없거나 빈 폴더여야 합니다. 기존 파일을 덮어쓰지 않으며 홈, 파일시스템 루트, 워크숍 루트, `docs`/`scripts`/`tests`, 심볼릭 링크를 경유하는 경로는 거부합니다. 실패 시 대상 상태를 확인하고 빈 경로로 다시 시도하세요. 복사 도중 실패하면 미완료 파일이 남을 수 있습니다.

출처와 고정 SHA는 `upstream-source.json`에 기록하고, 원본 라이선스와 고지는 `UPSTREAM-*` 이름으로 보존합니다. 원본 코드와 대상 프레임워크를 바꾸지 않으며 앱 안에 별도 `.git`을 만들지 않습니다. 다운로드만으로 커밋하거나 push하지 않습니다.

`java/pom.xml`이 있는지 확인한 뒤 [실습 1: 원본 실행](01-run-locally.md)으로 이동합니다. 기본 경로의 앱 파일은 워크숍 저장소에서 관리하며, 실습 1에서 생성 파일과 비밀이 없는지 검토한 뒤 기준선 커밋을 만듭니다. 저장소 밖에 다운로드했다면 해당 앱은 이 저장소에서 추적되지 않습니다.
