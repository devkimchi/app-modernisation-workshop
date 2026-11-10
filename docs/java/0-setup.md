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

```bash
gh repo clone <본인-계정>/<저장소-이름>
cd <저장소-이름>
```

복제한 폴더가 **워크숍 루트**입니다. 이후 명령은 이 폴더에서 실행합니다. Windows에서는 WSL에서도 접근할 수 있는 위치를 사용하세요.

> [!NOTE]
>
> 템플릿 저장소를 직접 클론하거나 포크하지 않습니다. 템플릿으로 만든 저장소는 독립된 이력을 가지며 원본의 이후 변경을 자동으로 받지 않습니다.

## 2. 필수 도구 설치여부 확인하기

### 도구 설치 여부 점검

실습에 사용할 필수 도구들이 설치되어 있는지 확인합니다. 아래 명령어를 실행시키세요.

```bash
# zsh/bash
bash scripts/check-prerequisites.sh --track java
```

```powershell
# PowerShell
powershell.exe -File ./scripts/check-prerequisites.ps1 -Track java
```

확인 결과는 아래를 참고하세요.

| 결과 | 할 일 |
| --- | --- |
| `PASS` | 해당 검사 통과. 실제 앱 실행이나 배포 성공을 뜻하지 않음 |
| `FAIL` | 부족한 도구나 설정을 보완한 뒤 다시 점검 |
| `WARN` | 오류 내용과 검사 제한 확인 |
| `MANUAL` | 직접 확인. Copilot 플러그인은 3단계에서 설치 |
| `INFO` | 참고 정보 |

### 도구 설치와 업데이트

누락된 도구를 설치하고, 업데이트 가능한 기존 도구는 **항목별로 `y`로 승인한 경우에만** 갱신합니다. 누락된 도구만 설치하려면 `--update`를 생략하세요.

```bash
# zsh/bash
bash scripts/install-prerequisites.sh --track java --update
```

설치하려는 도구는 아래와 같습니다.

| 대상 | 설치와 업데이트 |
| --- | --- |
| Node.js 22 이상 | nvm으로 설치합니다. 업데이트 시 현재 메이저의 최신 정식 버전을 추가하며, 없거나 22 미만이면 22.x를 선택합니다. |
| JDK 8, 21, 25 | SDKMAN으로 정식 Temurin을 설치하고, 업데이트 시 각 메이저의 최신 버전을 추가합니다. |
| Azure CLI, azd | WSL은 공식 설치 스크립트, macOS는 Homebrew로 설치합니다. 업데이트는 확인된 APT/Homebrew 패키지와 WSL azd 공식 스크립트 설치본을 지원합니다. azd의 기존 설치 기록이 없으면 관리 방식 인계를 별도 승인합니다. |

설치한 Node.js를 현재 터미널에서도 사용하려면 스크립트가 출력한 초기화 명령과 `nvm use` 명령을 실행하세요.

### Windows 호스트 도구 설치

Windows 환경에서 필요한 도구를 설치하려는 경우에는 아래 명령어를 실행시킵니다. 업데이트 가능한 기존 도구는 **항목별로 `y`로 승인한 경우에만** 갱신합니다. 누락된 도구만 설치하려면 `-Update`를 생략하세요.

```powershell
# PowerShell
powershell.exe -File ./scripts/install-prerequisites.ps1 -Track java -Update
```

### 직접 준비할 항목

- **Azure 권한**: 표시된 구독과 테넌트가 실습 대상인지 확인합니다. 리전, 쿼터, 역할 할당과 DB Entra 관리자 설정 권한은 별도 준비합니다. Contributor만으로 역할 할당 권한이 확보되지는 않습니다. 필요한 범위의 권한을 요청하고 구독 전체 Owner를 무조건 요청하지 마세요.
- **컨테이너 엔진**: [Docker Desktop](https://docs.docker.com/desktop/)을 설치하고 시작합니다. Windows Docker Desktop은 Linux containers 모드와 선택한 WSL 배포판의 통합을 켭니다. Windows와 WSL의 CLI가 같은 엔진에 연결된다고 가정하지 마세요.
- **Copilot 사용 권한**: 앱 로그인, 라이선스와 조직의 플러그인 정책을 확인합니다.

## 3. Copilot app에 플러그인 설치하기

1. Copilot app에서 GitHub 계정으로 로그인합니다.
2. **Customize**의 마켓플레이스 추가 기능(앱 버전에 따라 Settings > Plugins)에서 `microsoft/github-copilot-modernization`을 추가합니다.
3. 출처를 검토하고 허용한 뒤 `github-copilot-modernization` 플러그인을 설치합니다.
4. Agent picker에 `modernize` 또는 `github-copilot-modernization:modernize`가 보이는지 확인합니다. 내부 coordinator/worker를 직접 선택하지 않습니다.

목록이 갱신되지 않으면 새 세션이나 앱 재시작을 시도합니다. 무인 자동 승인이나 모든 권한 허용을 켜지 마세요. 문제가 계속되면 [문제 해결](8-troubleshooting.md)을 확인하고 멈춥니다. Copilot CLI나 VS Code로 임의 전환하지 않습니다.

## 4. 샘플 다운로드하기

```bash
# zsh/bash
bash scripts/download-sample.sh --track java
```

```powershell
# PowerShell
powershell.exe -File ./scripts/download-sample.ps1 -Track java
```

샘플은 워크숍 루트의 `java` 폴더에 다운로드됩니다. 다운로드할 `java` 폴더는 없거나 비어 있어야 합니다.

`java/pom.xml`이 있는지 확인한 뒤 [실습 1: 원본 실행](01-run-locally.md)으로 이동합니다. 기본 경로의 앱 파일은 워크숍 저장소에서 관리하며, 실습 1에서 생성 파일과 비밀이 없는지 검토한 뒤 기준선 커밋을 만듭니다. 저장소 밖에 다운로드했다면 해당 앱은 이 저장소에서 추적되지 않습니다.
