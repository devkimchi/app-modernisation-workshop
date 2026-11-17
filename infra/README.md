# Windows 11 개발 VM

[전체 목차](../README.md) | [.NET 준비](../docs/dotnet/00-setup.md)

저장소 루트의 `azure.yaml`로 Windows 11 VM을 만들고, 로컬 관리자 `appmoduser`의 `$HOME/scripts`에 설치 도우미를 배치합니다. VM 생성 중에는 도구를 설치하지 않습니다. 로그인한 사용자가 관리자 터미널에서 도우미를 실행하고 항목별로 동의합니다.

## 기본 구성

| 항목 | 값 |
| --- | --- |
| 이미지 | `MicrosoftWindowsDesktop:windows-11:win11-26h2-ent:latest`, x64 Gen2 |
| 리전 | 배포 시 선택, 권장 `koreacentral` |
| VM | `Standard_D8s_v5`, 8 vCPU, 32 GiB |
| OS 디스크 | Premium SSD 256 GiB |
| 부팅 보안 | Trusted Launch, Secure Boot, vTPM |
| Windows 로그인 | `.\appmoduser`, 로컬 관리자, 사용자가 입력한 암호 |
| 접속 | Azure portal의 Bastion Developer |
| 네트워크 | VM 공용 IP 없음, NAT Gateway로 인터넷 아웃바운드 제공 |
| 자동 종료 | 매일 한국 시간 20:00 할당 취소 |

`latest`는 새 VM을 만들 때 해당 SKU의 최신 이미지 버전을 선택합니다. 다른 Windows 11 SKU로 자동 전환하거나 기존 VM을 새 이미지로 다시 만들지는 않습니다.

VM에는 Entra ID 로그인 확장, 로그인 역할 할당과 관리 ID를 만들지 않습니다. Azure 리소스를 배포하고 포털을 사용하는 계정의 Azure 로그인은 별도로 필요합니다.

## 배포

**배포할 PC에서 저장소 루트를 작업 디렉터리로 사용하세요.** Windows에서는 PowerShell 7, macOS와 Linux 데스크톱에서는 Bash 3.2 이상 터미널을 사용합니다. 모든 환경에 azd CLI가 필요하며, Bash 훅은 `gzip`, `base64` 등 기본 명령을 사용하므로 PowerShell을 설치할 필요가 없습니다. 생성되는 VM과 VM 내부 설치 도우미는 모든 배포 환경에서 동일한 Windows 구성입니다.

이 저장소의 `infra`만 떼어 복사하면 공통 `scripts` 파일을 패키징할 수 없습니다.

먼저 다음 조건을 확인하세요.

- Azure 구독에서 리소스 그룹, VM, 네트워크와 자동 종료 일정을 생성할 권한
- 선택한 리전의 VM 크기, vCPU 할당량과 Bastion Developer 지원
- [Azure에서 Windows 클라이언트를 사용할 라이선스 자격](https://learn.microsoft.com/azure/virtual-machines/windows/windows-desktop-multitenant-hosting-deployment)
- Windows, Visual Studio Community, Docker Desktop과 GitHub Copilot의 사용 조건

Copilot app 터미널에서 azd가 AI 에이전트 환경을 감지해 질문을 생략하면, 직접 입력할 수 있는 같은 터미널에서 **아래 배포 명령을 실행하기 전에** 비대화형 모드 자동 감지를 해제하세요.

PowerShell:

```powershell
$env:AZD_NON_INTERACTIVE = 'false'
```

macOS/Linux Bash:

```bash
export AZD_NON_INTERACTIVE=false
```

현재 셸 세션과 자식 프로세스에만 적용됩니다. 일반 터미널에서는 보통 필요하지 않으며, CI나 무인 실행에서는 설정하지 마세요. 이 설정은 질문을 허용할 뿐 필수 환경 값의 누락이나 Bicep 기본값에 따른 질문 생략을 해결하지는 않습니다.

아래 명령은 Windows PowerShell 7과 macOS/Linux Bash에서 동일합니다. 구독과 리전이 설정되어 있지 않으면 azd가 선택을 요청합니다. 리전은 `koreacentral`을 권장합니다.

```powershell
azd auth login
azd env new appmod-dev
azd provision
```

첫 배포에서 `adminPassword`를 가려진 입력으로 받고, `confirmWindowsClientLicense`를 묻습니다. 라이선스 자격을 확인한 경우에만 `true`로 진행하세요. 암호는 12~123자이며 대문자, 소문자, 숫자, 특수 문자 중 3가지 이상을 포함해야 합니다. Azure의 추가 암호 정책도 적용됩니다. 암호를 명령 인수, 매개변수 파일이나 채팅에 적지 마세요.

azd는 입력을 로컬에 캐시합니다. 조사한 azd 1.37.3에서는 비밀 값을 기본 `$HOME/.azd/vaults`에 base64로 저장합니다. 이는 암호화가 아닙니다. 구성 디렉터리는 `AZD_CONFIG_DIR`에 따라 달라질 수 있습니다. `.azure`와 azd vault를 공유하거나 커밋하지 마세요. 암호를 다시 입력하려면 해당 환경에서 다음 명령을 실행한 뒤 다시 프로비저닝하세요. 이 명령은 azd의 참조를 제거하며, 기존 VM 암호나 vault 파일 전체를 지우는 명령은 아닙니다.

```powershell
azd env config unset infra.parameters.adminPassword
azd provision
```

기본값을 바꾸려면 **프로비저닝 전에** 필요한 값만 설정하세요. 미설정 값에는 Bicep 기본값이 적용됩니다.

```powershell
azd env set VM_SIZE Standard_D8s_v5
azd env set VM_OS_DISK_SIZE_GB 512
azd env set VM_AUTO_SHUTDOWN_ENABLED true
azd env set VM_AUTO_SHUTDOWN_TIME 2100
```

디스크는 256~1024 GiB를 허용하며 기존 디스크를 축소하지 마세요. VM 크기 변경은 재시작을 유발할 수 있습니다. 설치 중 자동 종료를 피하려면 `VM_AUTO_SHUTDOWN_ENABLED`를 `false`로 설정하세요. 다른 리전이나 VM 크기는 Windows 11, 중첩 가상화와 Bastion 지원을 다시 확인해야 합니다.

## 로그인과 도구 설치

1. Azure portal에서 생성된 VM의 **연결 > Bastion**을 선택합니다. 로컬 계정 `.\appmoduser`와 입력한 암호로 로그인합니다.
2. `appmoduser`의 Windows PowerShell을 **관리자 권한으로 실행**합니다. 처음에는 PowerShell 7이 없어도 됩니다.
3. 다음 명령을 실행하고 필요한 항목에 동의합니다.

```powershell
powershell.exe -NoProfile -File "$HOME/scripts/install-vm-tools.ps1"
```

Windows PowerShell 5.1에서는 WinGet과 안정 PowerShell 7.x를 준비한 뒤 공통 부트스트랩으로 PowerShell 7에 위임합니다. PowerShell 7이 준비된 후에는 아래 명령도 사용할 수 있습니다.

```powershell
pwsh -NoProfile -File "$HOME/scripts/install-vm-tools.ps1"
```

재부팅 안내가 나오면 작업을 저장하고 VM을 직접 재부팅한 뒤 같은 명령을 다시 실행하세요. 자동 재부팅, 자동 로그인과 예약 작업에 의한 재개는 없습니다. 기존 설치본과 데이터를 유지하며, 아직 준비되지 않은 항목을 다시 확인합니다.

CI, `-NonInteractive`, 입출력 리디렉션, SYSTEM이나 다른 사용자로 실행하면 설치하지 않습니다. 설치에 동의하지 않으면 해당 항목은 미완료로 남습니다. 모든 설치 후 상태 검사가 끝나야 종료 코드 `0`을 반환합니다. 미완료나 실패는 `1`, 재부팅 대기는 `3010`입니다.

### 설치 대상

| 도구 | 설치와 확인 방식 |
| --- | --- |
| WSL2 플랫폼 | 배포판 없이 `wsl.exe --install --no-distribution`으로 설치. 설치 후 직접 재부팅 |
| Ubuntu | WSL2 플랫폼 준비 후 설치. `appmoduser`에 등록 |
| PowerShell | 안정 7.x, 기존 버전은 자동 업데이트하지 않음 |
| MSMQ | Server 기능과 서비스 시작. 큐와 데이터는 생성하지 않음 |
| .NET Framework | 4.8 이상 런타임 확인, 없으면 4.8.1 설치 |
| Framework 빌드 도구 | 4.8 Targeting Pack과 SDK, MSBuild 웹 빌드 구성요소 |
| nvm-windows, Node.js | 정식 nvm 2.x, 새 Node는 22.x. 기존 지원 메이저 유지, 설치와 활성화에 별도 동의 |
| Git, GitHub CLI | `Git.Git`, `GitHub.cli`. GitHub CLI는 2.45.0 이상 확인 |
| Azure CLI, azd | `Microsoft.AzureCLI`, `Microsoft.Azd` |
| Modernize CLI | `GitHub.Copilot.modernization.agent`. `modernize --version`으로 확인 |
| .NET SDK | 안정 10.x, 기존 다른 메이저 유지 |
| Visual Studio 2026 Community | 안정 18.x, [visualstudio.vsconfig](scripts/visualstudio.vsconfig)의 웹 및 데스크톱 개발 구성 |
| Build Tools 2026 | 안정 18.x, [buildtools.vsconfig](scripts/buildtools.vsconfig)의 웹 빌드 구성 |
| IIS Express, SQL Server LocalDB | Visual Studio 구성요소로 설치. DB를 만들거나 초기화하지 않음 |
| VS Code | `Microsoft.VisualStudioCode` |
| GitHub Copilot app | 공식 `github/app` 최신 정식 x64 MSI. 제공된 SHA-256과 GitHub 서명을 확인한 뒤 실행 |
| Docker Desktop | WSL2 백엔드로 설치. 최초 실행과 약관 확인은 수동 진행 |

전체 IDE와 Build Tools는 별도 설치 항목입니다. 설치 전 시스템 드라이브에 최소 50 GiB의 여유 공간을 요구하며, 이후 Docker 이미지와 WSL 데이터에 필요한 공간은 별도로 확보하세요.

nvm 1.x나 출처가 불명확한 기존 Node 설치는 자동 교체하지 않습니다. nvm의 `auto_install`이 켜져 있으면 별도 동의 후 끕니다. 기존 Ubuntu가 WSL1이면 삭제하거나 자동 변환하지 않고 중단합니다.

### 설치 후 수동 작업

VM의 사용자 터미널에서 Ubuntu를 처음 실행하고 Linux 사용자 계정을 설정하세요.

```powershell
wsl -d Ubuntu
```

Docker Desktop을 시작해 약관과 WSL2 설정을 확인하고 Linux 컨테이너를 사용하세요. GitHub Copilot app을 실행해 로그인하세요. 이후 [.NET 준비 문서](../docs/dotnet/00-setup.md)의 3단계에서 gh 인증과 Modernize CLI를 확인하고 실습 준비를 진행합니다.

이 도우미는 Azure/GitHub 로그인, 구독 변경, 공급자 등록과 실습 DB 생성을 실행하지 않습니다. WSL2 중첩 가상화, Docker 실행과 실제 앱 빌드는 VM에서 별도로 확인해야 합니다. 오류 해결을 위해 Trusted Launch를 자동으로 끄지 않습니다.

## 파일 배치와 재배포

`preprovision` 훅은 로컬 공통 도우미 6개, VM 설치 스크립트와 `.vsconfig` 2개를 압축해 `infra/.generated/payload.json`에 만듭니다. Bicep은 이 내용을 내장합니다. 별도 스토리지, SAS나 공개 저장소 게시가 필요하지 않습니다.

azd는 Windows에서 `preprovision.ps1`, macOS/Linux에서 `preprovision.sh`를 실행합니다. Bash 구현도 파일의 원본 바이트, JSON 형식과 크기 제한을 유지합니다. `postprovision.ps1`과 `postprovision.sh`는 각 환경의 셸로 Bastion 접속과 VM 내부 설치 명령을 안내합니다.

VM 생성 후 Managed Run Command가 `appmoduser`의 SID로 프로필을 찾고, 없으면 Windows `CreateProfile` API로 준비합니다. SYSTEM의 `$HOME`이나 추측한 사용자 경로를 쓰지 않습니다. 실제 프로필의 `scripts` 아래에 UTF-8 BOM과 LF를 보존해 파일을 배치합니다. 이 배치 스크립트만 PowerShell 7 검사 없이 Windows PowerShell 5.1에서 실행됩니다.

프로필 생성 단계에서 배포가 실패했다면 오류를 해결한 뒤 같은 azd 환경에서 `azd provision`을 다시 실행하세요. 이 단계의 실패만으로 VM이나 리소스 그룹을 삭제할 필요는 없습니다.

동일한 파일은 그대로 두고 다른 내용의 기존 파일, 경로 이탈과 reparse point는 거부합니다. 배치 실패는 배포 실패로 처리합니다. 사용자 수정 파일과 충돌하면 VM에서 충돌 파일을 별도 위치에 백업하고 원래 경로에서 옮긴 뒤 `azd provision`을 다시 실행하세요. 변경된 설치 도우미를 전달할 때도 동일하게 처리합니다.

## 유지보수 검증

저장소 루트에서 실행하세요. 첫 명령은 로컬 파일 패키징만 수행합니다. Bicep 명령에는 Azure CLI의 Bicep 도구가 필요합니다.

```powershell
pwsh -NoProfile -File ./infra/scripts/preprovision.ps1
az bicep build --file ./infra/main.bicep --outfile ./infra/.generated/main.json
pwsh -NoProfile -File ./infra/tests/vm-setup.tests.ps1 -CompiledTemplate ./infra/.generated/main.json
powershell.exe -NoProfile -File ./infra/tests/vm-setup.tests.ps1 -CompiledTemplate ./infra/.generated/main.json
```

Bicep을 수동 컴파일할 때도 먼저 payload를 생성해야 합니다. `.generated`와 `.azure`는 Git에서 제외됩니다. 관련 공통 도우미의 회귀 테스트는 [CONTRIBUTING](../CONTRIBUTING.md#local-checks)에 있습니다.

macOS/Linux에서는 다음 명령으로 패키징과 Bash 회귀 테스트를 실행합니다. 테스트에만 Python 3가 추가로 필요하며, macOS에서는 기본 Bash 3.2로 실행하세요.

```bash
bash ./infra/scripts/preprovision.sh
az bicep build --file ./infra/main.bicep --outfile ./infra/.generated/main.json
bash ./infra/tests/vm-payload.tests.sh
```

Bash 테스트는 파일의 바이트 일치, 공백 경로, 크기 제한, 누락 파일과 압축 실패 시 오류 전파 및 접속 안내를 확인합니다. CI의 macOS/Linux 작업에서도 실행합니다.

테스트는 임시 파일과 mock으로 프로필 조회, 파일 충돌, 설치 동의, 버전 선택, 실패와 재부팅 경계를 검증합니다. 의도적인 거절과 오류가 `FAIL`로 출력될 수 있으므로 마지막 `PASS` 요약과 테스트 프로세스 종료 코드로 판단하세요. 실제 프로필 생성, 도구 설치나 Azure 배포를 수행하지 않습니다.

**실제 VM 생성, 최초 로그인, WinGet 초기화, WSL2 중첩 가상화, Docker와 전체 도구 설치는 아직 검증하지 않았습니다.** 로컬 테스트 통과는 VM 리허설 성공을 뜻하지 않습니다.

## 리소스 정리

자동 종료로 VM의 컴퓨팅 비용이 멈춰도 디스크, NAT Gateway와 공용 IP 요금은 남을 수 있습니다. 더 이상 쓰지 않을 때 VM과 WSL의 필요한 데이터를 먼저 백업하세요.

배포한 PC의 저장소 루트에서 대상 azd 환경을 확인한 뒤 직접 삭제합니다. 선택한 환경의 리소스 그룹과 VM 데이터가 삭제됩니다.

```powershell
azd env select appmod-dev
azd down
```
