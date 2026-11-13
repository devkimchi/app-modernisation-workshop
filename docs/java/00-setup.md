# 준비: 저장소 생성부터 샘플 다운로드까지

[전체 목차](../../README.md) | [Java 목차](README.md) | [다음: 원본 실행](01-run-locally.md) | [문제 해결](08-troubleshooting.md)

## 실행 환경

Windows에서는 **PowerShell**, macOS에서는 **Bash** 또는 **Zsh**를 사용합니다.

### 사전 설치 항목

- [GitHub Copilot app](https://gh.io/app)
- Windows: [PowerShell 7](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-windows), [Docker Desktop](https://docs.docker.com/desktop/)
- macOS: [Homebrew](https://brew.sh), [Docker Desktop](https://docs.docker.com/desktop/)
- Linux: [Docker Engine](https://docs.docker.com/engine/install/)

## 템플릿으로 저장소 만들고 복제하기

1. [워크숍 템플릿](https://github.com/devkimchi/app-modernisation-workshop)에서 **Use this template > Create a new repository**를 선택하거나 [![GitHub에서 템플릿으로 저장소 만들기](https://img.shields.io/badge/GitHub-Create%20repository%20from%20template-2ea44f?style=flat&logo=github&logoColor=white)](https://github.com/new?template\_name=app-modernisation-workshop&template\_owner=devkimchi)을 클릭합니다.
2. Owner에서 **개인 계정**을 선택합니다. 저장소를 공개하지 않으려면 **Private**을 선택하고 **Include all branches**는 선택하지 않습니다.
3. 저장소를 만든 뒤 GitHub CLI(`gh`)를 사용할 수 있는 터미널에서 복제합니다. 아래 값을 실제 계정과 저장소 이름으로 바꾸세요. (예: `octocat/app-modernisation-workshop`)

```bash
gh repo clone <본인-계정>/<저장소-이름>
cd <저장소-이름>
```

복제한 폴더가 **워크숍 루트**입니다. 템플릿 저장소를 직접 복제하거나 포크하지 마세요. 템플릿으로 만든 저장소는 원본과 별도의 이력을 가지며, 원본의 변경 사항이 자동으로 반영되지 않습니다.

## 필수 도구 점검과 설치

### Windows 실행 정책

첫 스크립트를 실행하기 전에 PowerShell 실행 정책을 확인합니다.

```powershell
# PowerShell
Get-ExecutionPolicy
```

`Restricted`이면 다음 명령을 실행해 **현재 PowerShell 창에서만** 실행 정책을 변경합니다.

```powershell
# PowerShell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned
```

> [!CAUTION]
>
> `CurrentUser` 범위로 설정하면 모든 PowerShell 창에 적용됩니다. 보안에 영향을 줄 수 있으므로 권장하지 않습니다.

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
| `PASS` | 점검 통과. 앱 실행이나 배포까지 확인한 것은 아님 |
| `FAIL` | 누락된 도구를 설치하거나 설정을 보완한 뒤 다시 점검 |
| `WARN` | 경고 내용과 점검 범위를 확인 |
| `MANUAL` | Copilot 로그인과 라이선스, 조직 정책, 터미널 접근 권한, Azure 권한을 직접 확인 |
| `INFO` | 참고 정보 |

### 도구 설치 및 업데이트

누락된 도구를 설치합니다. 업데이트를 선택하면 **각 항목에서 `y`를 입력해 승인한 도구만** 업데이트합니다. 누락된 도구만 설치하려면 `-Update` 또는 `--update`를 생략합니다.

```bash
# zsh/bash
./scripts/install-prerequisites.sh --track java --update
```

```powershell
# PowerShell
./scripts/install-prerequisites.ps1 -Track java -Update
```

#### 도구별 설치 및 업데이트 방법

| 대상 | 설치 및 업데이트 방법 |
| --- | --- |
| [Node.js](https://nodejs.org/) 22 이상 | Windows에서는 [nvm-windows](https://github.com/nvm-windows/nvm), macOS와 Linux에서는 [nvm](https://github.com/nvm-sh/nvm)을 사용합니다. Node.js가 없거나 버전이 22 미만이면 22.x를 설치합니다. 업데이트를 선택하면 현재 메이저 버전의 최신 정식 버전을 추가합니다. |
| 정식 JDK 8 및 25 | Windows에서는 winget으로 [Temurin](https://adoptium.net/installation/windows)을 설치하고, macOS와 Linux에서는 [SDKMAN](https://sdkman.io/install/)을 사용합니다. |
| [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli), [azd](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd) | Windows에서는 winget으로 누락된 도구를 설치합니다. macOS에서는 Homebrew를, Linux에서는 공식 설치 방법을 사용합니다. Windows에 이미 설치된 도구는 원래 사용한 설치 관리자로 직접 업데이트합니다. |
| [GitHub CLI](https://cli.github.com/) | Windows에서는 winget을, macOS에서는 Homebrew를 사용합니다. Linux에서는 공식 apt 저장소를 사용합니다. |
| [Modernize CLI](https://github.com/microsoft/modernize-cli) | Windows에서는 winget을, macOS에서는 Homebrew를 사용합니다. Linux에서는 공식 설치 스크립트를 사용합니다. |

> [!NOTE]
>
> - Windows에서 JDK를 설치할 때 권한 확인 창이 나타나면 승인합니다. 실습에 사용할 JDK는 제공된 도우미에서 선택합니다.
> - macOS와 Linux에서는 `nvm use`로 Node.js 버전을 선택합니다.
> - Linux에서는 glibc 2.27 이상이 필요합니다. 버전이 2.27 미만이거나 확인할 수 없다면 지원되는 배포판을 사용하세요.

### 인증과 권한 확인

워크숍 루트의 터미널에서 다음 명령을 차례로 실행하고, 각 서비스에서 실습에 사용할 계정으로 로그인합니다.

```text
az login
azd auth login
gh auth login
```

> [!NOTE]
>
> `az login`을 실행할 때 실습에 사용할 구독을 선택합니다.

## Copilot app과 Modernize CLI 준비

Copilot app에서 터미널을 열고 워크숍 루트로 이동합니다. 다음 명령으로 도구가 설치되어 있는지, GitHub에 로그인되어 있는지 확인하고 Modernize CLI의 주요 명령을 살펴봅니다.

```text
gh --version
gh auth status
modernize --version
modernize assess --help
modernize plan create --help
modernize plan execute --help
```

> [!NOTE]
>
> `modernize help models`로 사용할 수 있는 모델을 확인합니다. 선호하는 모델이 없다면 `auto`를 선택해도 됩니다.

## 샘플 다운로드하기

같은 **워크숍 루트**에서 실행합니다. 다운로드 대상인 `java` 폴더는 없거나 비어 있어야 합니다.

```bash
# zsh/bash
./scripts/download-sample.sh --track java
```

```powershell
# PowerShell
./scripts/download-sample.ps1 -Track java
```

## 완료 및 다음 단계

- [ ] 필수 사전 점검을 마쳤습니다.
- [ ] `az login`, `azd auth login`, `gh auth login`을 실행해 로그인을 마쳤습니다.
- [ ] 샘플의 `java/pom.xml` 파일이 있는지 확인했습니다.

위 항목을 모두 마쳤다면 다음 단계인 [1. 원본 실행](01-run-locally.md)로 이동합니다.
