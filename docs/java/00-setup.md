# 준비: 저장소 생성부터 샘플 다운로드까지

[전체 목차](../../README.md) | [Java 목차](README.md) | [다음: 원본 실행](01-run-locally.md) | [문제 해결](08-troubleshooting.md)

## 실행 환경

Windows에서는 **PowerShell**, macOS에서는 **Bash** 또는 **Zsh** 를 사용합니다.

### 사전 설치 항목

- [GitHub Copilot app](https://gh.io/app)
- Windows: [PowerShell 7](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-windows), [Docker Desktop](https://docs.docker.com/desktop/)
- macOS: [Homebrew](https://brew.sh), [Docker Desktop](https://docs.docker.com/desktop/)
- Linux: [Docker Engine](https://docs.docker.com/engine/install/)

## 템플릿으로 저장소 만들고 클론하기

1. [워크숍 템플릿](https://github.com/devkimchi/app-modernisation-workshop)에서 **Use this template > Create a new repository**를 선택하거나 [![GitHub에서 템플릿으로 저장소 만들기](https://img.shields.io/badge/GitHub-Create%20repository%20from%20template-2ea44f?style=flat&logo=github&logoColor=white)](https://github.com/new?template\_name=app-modernisation-workshop&template\_owner=devkimchi)을 클릭합니다.
2. Owner는 본인 **개인 계정**으로 지정합니다. 공개할 계획이 없다면 **Private**을 선택하고 **Include all branches**는 선택하지 않습니다.
3. 저장소를 만든 뒤 GitHub CLI(`gh`)를 사용할 수 있는 터미널에서 복제합니다. 아래 값을 실제 계정과 저장소 이름으로 바꾸세요. (예: `octocat/app-modernisation-workshop`)

```bash
gh repo clone <본인-계정>/<저장소-이름>
cd <저장소-이름>
```

복제한 폴더가 **워크숍 루트**입니다. 템플릿 자체를 직접 클론하거나 포크하지 않습니다. 템플릿으로 만든 저장소는 독립된 이력을 가지며 원본의 이후 변경을 자동으로 받지 않습니다.

## 필수 도구 점검과 설치

### Windows 실행 정책

첫 스크립트 실행 전에 현재 창의 정책을 확인합니다.

```powershell
# PowerShell
Get-ExecutionPolicy
```

`Restricted`이면 **현재 창에만** 다음을 적용합니다. 창을 닫으면 원래 정책으로 돌아가므로 새 창에서도 필요하면 다시 적용합니다. 시스템과 사용자 범위의 정책은 바꾸지 않습니다. 조직 정책 때문에 변경할 수 없으면 관리자에게 문의합니다.

```powershell
# PowerShell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned
```

### 설치 여부 점검

**워크숍 루트**에서 운영체제에 맞는 명령 하나를 실행합니다.

```bash
# zsh/bash
./scripts/check-prerequisites.sh --track java
```

```powershell
# PowerShell
./scripts/check-prerequisites.ps1 -Track java
```

#### 설치 여부 점검 결과

| 결과 | 할 일 |
| --- | --- |
| `PASS` | 해당 검사 통과. 앱 실행이나 배포 성공을 뜻하지 않음 |
| `FAIL` | 부족한 도구나 설정을 보완한 뒤 다시 점검 |
| `WARN` | 오류 내용과 검사 제한 확인 |
| `MANUAL` | Copilot 로그인, 라이선스, 조직 정책, 터미널 접근과 Azure 권한을 직접 확인 |
| `INFO` | 참고 정보 |

### 도구 설치와 업데이트

누락된 도구를 설치하고 업데이트 가능한 도구는 **항목별로 `y`로 승인한 경우에만** 갱신합니다. 누락된 도구만 설치하려면 `-Update` 또는 `--update`를 생략합니다. CI와 비대화형 환경에서는 설치를 승인하지 않습니다.

```bash
# zsh/bash
./scripts/install-prerequisites.sh --track java --update
```

```powershell
# PowerShell
./scripts/install-prerequisites.ps1 -Track java -Update
```

#### 도구 설치와 업데이트 항목

| 대상 | 설치와 업데이트 |
| --- | --- |
| [Node.js](https://nodejs.org/) 22 이상 | Windows는 [nvm-windows](https://github.com/nvm-windows/nvm), macOS와 Linux는 [nvm](https://github.com/nvm-sh/nvm). 없거나 22 미만이면 22.x를 설치하고 업데이트 시 현재 메이저의 최신 정식 버전을 추가 |
| 정식 JDK 8, 25 | Windows는 winget의 [Temurin](https://adoptium.net/installation/windows), macOS와 Linux는 [SDKMAN](https://sdkman.io/install/) |
| [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli), [azd](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd) | Windows는 winget으로 누락된 도구 설치, macOS는 Homebrew, Linux는 공식 설치 경로. Windows의 기존 설치본 업데이트는 원래 설치 관리자로 직접 수행 |
| [GitHub CLI](https://cli.github.com/) | Windows는 winget, macOS는 Homebrew, Linux는 공식 apt 저장소 |
| [Modernize CLI](https://github.com/microsoft/modernize-cli) | Windows는 winget, macOS는 Homebrew, Linux는 공식 설치 스크립트 |

Windows에서 JDK를 설치할 때 권한 확인 창이 나타나면 승인합니다. 실습 터미널의 JDK는 별도 도우미로 선택합니다.

macOS와 Linux에서는 `nvm use`로 Node.js 버전을 선택합니다. Linux는 glibc 2.27 이상이 필요합니다. 미달하거나 버전을 확인할 수 없으면 지원되는 배포판을 사용하세요.

### 인증과 권한 확인

워크숍 루트의 터미널에서 실습 대상 계정으로 다음 명령을 차례로 실행합니다.

```text
az login
azd auth login
gh auth login
```

> [!NOTE]
>
> `az login` 실행 중 실습 대상 구독을 선택합니다.

## Copilot app과 Modernize CLI 준비

Copilot app에서 터미널을 열고 워크숍 루트에서 확인합니다.

```text
gh --version
gh auth status
modernize --version
modernize assess --help
modernize plan create --help
modernize plan execute --help
```

`modernize help models`로 사용 가능한 모델을 확인하고, 대화형 메뉴에서 `M`을 눌러 선택합니다. 선호 모델이 없다면 `auto`를 선택할 수 있습니다.

## 샘플 다운로드하기

같은 **워크숍 루트**에서 실행합니다.

```bash
# zsh/bash
./scripts/download-sample.sh --track java
```

```powershell
# PowerShell
./scripts/download-sample.ps1 -Track java
```

대상 `java` 폴더는 없거나 비어 있어야 합니다.

## 완료 및 다음 단계

- [ ] 필수 사전 점검을 마쳤습니다.
- [ ] `az login`, `azd auth login`, `gh auth login`을 실행했습니다.
- [ ] 샘플의 `java/pom.xml`을 확인했습니다.

위 체크리스트를 모두 확인했다면 다음 단계인 [1. 원본 실행](01-run-locally.md)으로 이동합니다.
