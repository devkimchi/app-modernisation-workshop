# Windows 11 개발 VM

[전체 목차](../README.md) | [.NET 준비](../docs/dotnet/00-setup.md)

`azure.yaml`로 Windows 11 VM을 만들고, 로컬 관리자 `appmoduser`의 `$HOME/scripts`에 설치 도우미를 복사합니다. 도구는 VM에 로그인한 뒤 설치합니다.

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
| 네트워크 | VM 공용 IP 없음, NAT Gateway를 통해 인터넷 접속 |
| 자동 종료 | 매일 한국 시간 20:00 할당 취소 |

`latest`는 새 VM에 사용할 해당 SKU의 최신 이미지입니다. 기존 VM의 이미지는 갱신하지 않으며, 다른 SKU로 전환하지도 않습니다.

VM은 Entra ID 로그인과 Managed Identity를 사용하지 않습니다. 배포와 Azure portal 접속에는 Azure 로그인이 필요합니다.

## 사전 준비

배포할 PC에 azd CLI를 미리 설치하고 다음 조건을 확인하세요.

- Azure 구독에서 리소스 그룹, VM, 네트워크와 자동 종료 일정을 생성할 권한
- 선택한 리전의 VM 크기 지원, vCPU 할당량과 Bastion Developer 지원
- [Azure에서 Windows 클라이언트를 사용할 라이선스 자격](https://learn.microsoft.com/azure/virtual-machines/windows/windows-desktop-multitenant-hosting-deployment)
- Windows, Visual Studio Build Tools, Docker Desktop과 GitHub Copilot의 사용 조건

## 배포

**배포할 PC의 저장소 루트에서 실행하세요.** 공통 `scripts` 파일도 필요하므로 `infra`만 복사해서 배포할 수는 없습니다.

Copilot app 터미널에서 azd가 AI 에이전트 환경으로 인식해 질문을 생략하면, **배포 명령을 실행하기 전에** 같은 터미널에서 다음 값을 설정하세요. 직접 입력할 수 있는 터미널이어야 합니다.

PowerShell:

```powershell
$env:AZD_NON_INTERACTIVE = 'false'
```

macOS/Linux Bash:

```bash
export AZD_NON_INTERACTIVE=false
```

현재 터미널과 자식 프로세스에만 적용됩니다. 일반 터미널에서는 보통 필요하지 않으며, CI나 무인 실행에서는 설정하지 마세요. 이 설정만으로 누락된 필수 값이나 Bicep 기본값이 바뀌지는 않습니다.

다음 명령은 두 환경에서 같습니다. 구독과 리전이 설정되지 않았다면 azd가 선택을 요청합니다.

```powershell
azd auth login
azd env new appmod-dev
azd provision
```

첫 배포에서는 `adminPassword`를 입력하고 `confirmWindowsClientLicense`에 답합니다. 암호는 화면에 표시되지 않습니다. Windows 클라이언트 라이선스 자격이 있는 경우에만 `true`를 선택하세요. 암호는 12~123자로, 대문자, 소문자, 숫자, 특수 문자 중 3가지 이상을 포함해야 하며 Azure 암호 정책도 충족해야 합니다. 명령 인수, 매개변수 파일이나 채팅에 암호를 적지 마세요.

azd는 입력한 값을 로컬에 캐시합니다. 확인한 azd 1.37.3은 비밀 값을 기본 `$HOME/.azd/vaults`에 **암호화 없이 base64로 저장**합니다. 경로는 `AZD_CONFIG_DIR` 설정에 따라 달라질 수 있습니다. `.azure`와 azd vault를 공유하거나 커밋하지 마세요.

암호를 다시 입력하려면 해당 azd 환경에서 다음 명령을 실행하세요. 캐시 참조만 해제하며, 기존 VM 암호를 바꾸거나 vault 파일을 삭제하지는 않습니다.

```powershell
azd env config unset infra.parameters.adminPassword
azd provision
```

기본값을 바꾸려면 **프로비저닝 전에** 필요한 항목만 설정하세요.

```powershell
azd env set VM_SIZE Standard_D8s_v5
azd env set VM_OS_DISK_SIZE_GB 512
azd env set VM_AUTO_SHUTDOWN_ENABLED true
azd env set VM_AUTO_SHUTDOWN_TIME 2100
```

디스크는 256~1024 GiB로 설정할 수 있으며, 기존 디스크는 축소하지 마세요. VM 크기를 바꾸려면 재시작이 필요할 수 있습니다. 다른 리전이나 VM 크기를 사용하려면 Windows 11, 중첩 가상화와 Bastion 지원을 확인하세요. 설치 중 자동 종료를 막으려면 `VM_AUTO_SHUTDOWN_ENABLED`를 `false`로 설정하세요.

## 로그인과 도구 설치

1. Azure portal에서 VM의 **연결 > Bastion**을 선택하고 `.\appmoduser`와 배포 시 입력한 암호로 로그인합니다.
2. PowerShell을 **관리자 권한으로 실행**합니다. Windows PowerShell 5.1과 PowerShell 7 모두 사용할 수 있습니다.
3. 다음 명령을 실행하고 필요한 항목에 동의합니다.

```powershell
& "$HOME/scripts/install-vm-tools.ps1"
```

경로 앞의 `&`와 따옴표를 유지하세요. Windows PowerShell 5.1에서는 WinGet과 PowerShell 7.x를 준비한 뒤 PowerShell 7로 실행을 이어갑니다.

기본적으로 항목마다 동의를 받습니다. 이 VM 도우미에 한해 `-Yes`를 지정하면 도구 설치, 약관 수락(WinGet 패키지 및 원본 약관 포함), 설정 변경(nvm 설정 및 Node.js 활성화 포함)에 일괄 동의합니다.

```powershell
& "$HOME/scripts/install-vm-tools.ps1" -Yes
```

재부팅 안내가 나오면 작업을 저장하고 VM을 직접 재부팅한 뒤 같은 명령을 다시 실행하세요. 기존 설치와 데이터는 유지합니다. `-Yes`를 사용해도 재부팅, 로그인과 설치 재개는 직접 해야 합니다.

관리자 `appmoduser`의 대화형 터미널에서 실행해야 합니다. `-Yes`도 CI, `-NonInteractive`, 입출력 리디렉션, SYSTEM이나 다른 사용자 실행 제한을 해제하지 않습니다. 종료 코드는 완료 `0`, 미동의를 포함한 미완료 또는 실패 `1`, 재부팅 대기 `3010`입니다.

### 설치 대상

다음 순서로 설치하며, 재부팅이 필요하면 중단합니다.

| 그룹 | 도구 | 설치와 확인 방식 |
| --- | --- | --- |
| 1. 설치 도구 | WinGet | App Installer 등록 또는 설치 |
| 1. 설치 도구 | PowerShell | 7.x 정식 버전. 기존 버전은 자동 업데이트하지 않음 |
| 2. Windows 기능 | WSL2 플랫폼 | 배포판 없이 `wsl.exe --install --no-distribution`으로 설치. 설치 후 직접 재부팅 |
| 2. Windows 기능 | Ubuntu | WSL2 설치 후 `appmoduser`에 등록 |
| 2. Windows 기능 | MSMQ | Server 기능 활성화 및 서비스 시작. 큐와 데이터는 생성하지 않음 |
| 3. 런타임 및 SDK | Visual C++ x64 런타임 | `Microsoft.VCRedist.2015+.x64` 설치 및 DLL 확인 |
| 3. 런타임 및 SDK | .NET Framework | 4.8 이상 런타임 확인, 없으면 4.8.1 설치 |
| 3. 런타임 및 SDK | .NET 10 SDK | `Microsoft.DotNet.SDK.10`, 10.x 정식 버전. 다른 메이저 버전은 유지 |
| 3. 런타임 및 SDK | .NET 11 SDK | `Microsoft.DotNet.SDK.11`, 11.x 정식 버전. .NET 10과 함께 설치 |
| 3. 런타임 및 SDK | nvm-windows, Node.js | nvm 2.x 정식 버전과 Node.js 22.x. 기존 지원 메이저 버전은 유지 |
| 4. .NET Framework 도구 | Build Tools 2026 | 18.x 정식 버전. [buildtools.vsconfig](scripts/buildtools.vsconfig)의 웹 및 .NET 데스크톱 빌드 도구, 4.8 Targeting Pack과 SDK |
| 4. .NET Framework 도구 | IIS Express | Microsoft 공식 x64 MSI. SHA-256과 Microsoft 서명 확인 |
| 4. .NET Framework 도구 | SQL Server LocalDB | Microsoft 공식 SQL Server 2025 Express LocalDB x64 MSI. SHA-256과 Microsoft 서명 확인. DB와 인스턴스는 생성하지 않음 |
| 4. .NET Framework 도구 | 빌드 및 실행 도구 확인 | 4.8 Targeting Pack, MSBuild 웹 빌드 도구, IIS Express와 SQL Server LocalDB 확인. DB 생성과 초기화는 하지 않음 |
| 5. DB 및 컨테이너 | PostgreSQL 18 클라이언트 | `PostgreSQL.PostgreSQL.18`의 `commandlinetools`만 설치하고 실행 확인. 동의 후 사용자 PATH에 추가. 서버, pgAdmin, Stack Builder는 설치하지 않고 DB도 생성하지 않음 |
| 5. DB 및 컨테이너 | Docker Desktop | WSL2 백엔드로 설치. 최초 실행과 약관 확인은 수동 진행 |
| 6. GitHub 도구 | Git | `Git.Git` |
| 6. GitHub 도구 | GitHub CLI | `GitHub.cli`, 2.45.0 이상 |
| 6. GitHub 도구 | GitHub Copilot CLI | `GitHub.Copilot`. `copilot --version`으로 확인 |
| 7. Azure 도구 | Azure CLI | `Microsoft.AzureCLI` |
| 7. Azure 도구 | azd | `Microsoft.Azd` |
| 8. 편집기 및 현대화 도구 | VS Code | `Microsoft.VisualStudioCode` |
| 8. 편집기 및 현대화 도구 | GitHub Copilot app | 공식 `github/app` 최신 정식 x64 MSI. SHA-256과 GitHub 서명 확인 |
| 8. 편집기 및 현대화 도구 | Modernize CLI | `GitHub.Copilot.modernization.agent`. `modernize --version`으로 확인 |

시스템 드라이브에 최소 50 GiB의 여유 공간이 필요합니다. Docker 이미지와 WSL 데이터에 필요한 공간은 별도로 확보하세요. Visual Studio Community IDE는 설치하거나 제거하지 않습니다. IIS Express와 LocalDB는 Build Tools에 포함되지 않아 따로 설치합니다.

nvm 1.x나 출처가 불명확한 Node.js는 자동 교체하지 않습니다. nvm의 `auto_install` 해제와 Node.js 활성화에는 동의가 필요합니다. 단, 첫 설치 시 기본 버전 활성화는 설치 동의에 포함됩니다. 기존 Ubuntu가 WSL1이면 삭제하거나 변환하지 않고 중단합니다.

도우미는 설치 후 또는 재실행 시 정상 작동하는 PostgreSQL 18 클라이언트의 경로를 사용자 PATH에 중복 없이 추가합니다. 기존 항목과 순서를 유지하며 시스템 PATH는 바꾸지 않습니다. Windows Terminal을 완전히 종료하고 다시 열어 `psql --version`으로 확인하세요. 다른 `psql`이 먼저 실행되면 경고를 표시합니다. PostgreSQL 18을 직접 확인하려면 `& "$env:ProgramFiles/PostgreSQL/18/bin/psql.exe" --version`을 실행하세요.

`psql.exe`가 출력 없이 종료되면 Visual C++ 런타임이 누락되었을 수 있습니다. 도우미를 다시 실행하면 런타임을 먼저 확인하고, 정상 작동하는 PostgreSQL은 재설치하지 않습니다.

### 설치 후 수동 작업

VM 터미널에서 Ubuntu를 실행하고 Linux 사용자 계정을 만드세요.

```powershell
wsl -d Ubuntu
```

Docker Desktop을 시작해 약관과 WSL2 설정을 확인하고 Linux 컨테이너를 사용하세요. GitHub Copilot app에 로그인하고, `copilot`을 실행해 CLI 인증을 진행하세요. 이후 [.NET 준비 문서](../docs/dotnet/00-setup.md)의 3단계부터 gh 인증과 Modernize CLI를 확인합니다.

도우미는 Azure/GitHub 로그인, 구독 변경, Resource Provider 등록과 실습 DB 생성을 하지 않습니다. WSL2 중첩 가상화, Docker 실행과 앱 빌드는 VM에서 직접 확인하세요. Trusted Launch는 자동으로 끄지 않습니다.

## 파일 배치와 재배포

`preprovision` 훅은 공통 도우미 6개, VM 설치 스크립트와 `buildtools.vsconfig`를 압축해 `infra/.generated/payload.json`을 만듭니다. Bicep에 포함하므로 별도 스토리지나 SAS, 공개 저장소가 필요하지 않습니다.

Windows에서는 `.ps1`, macOS/Linux에서는 `.sh` 훅을 실행합니다. `postprovision` 훅은 Bastion 접속과 도구 설치 명령을 안내합니다.

VM 생성 후 Managed Run Command가 `appmoduser`의 프로필을 찾아 `scripts` 폴더에 파일을 복사합니다. 프로필이 없으면 먼저 생성합니다.

프로필 생성에 실패하면 오류를 해결한 뒤 같은 azd 환경에서 `azd provision`을 다시 실행하세요. VM이나 리소스 그룹을 삭제할 필요는 없습니다.

내용이 같은 파일은 유지하며, 다른 파일을 덮어쓰거나 지정 폴더 밖의 경로와 reparse point를 사용하려 하면 배포가 실패합니다. 파일이 충돌하거나 새 도우미로 교체하려면 VM에서 해당 파일을 백업해 다른 위치로 옮긴 뒤 `azd provision`을 다시 실행하세요.

## 유지보수 검증

저장소 루트에서 실행하세요. Azure CLI의 Bicep 도구가 필요합니다. 먼저 로컬 파일을 패키징한 뒤 컴파일하고, PowerShell 7과 5.1 진입 경로를 각각 검증합니다.

```powershell
pwsh -NoProfile -File ./infra/scripts/preprovision.ps1
az bicep build --file ./infra/main.bicep --outfile ./infra/.generated/main.json
pwsh -NoProfile -File ./infra/tests/vm-setup.tests.ps1 -CompiledTemplate ./infra/.generated/main.json
powershell.exe -NoProfile -File ./infra/tests/vm-setup.tests.ps1 -CompiledTemplate ./infra/.generated/main.json
```

생성 파일이 있는 `.generated`와 `.azure`는 Git에서 제외됩니다. 공통 도우미의 테스트는 [CONTRIBUTING](../CONTRIBUTING.md#local-checks)을 참고하세요.

macOS/Linux 테스트에는 Python 3가 필요합니다. macOS에서는 기본 Bash 3.2를 사용하세요.

```bash
bash ./infra/scripts/preprovision.sh
az bicep build --file ./infra/main.bicep --outfile ./infra/.generated/main.json
bash ./infra/tests/vm-payload.tests.sh
```

테스트는 임시 파일과 mock을 사용하며 실제 도구 설치나 Azure 배포는 하지 않습니다. 의도적인 오류로 `FAIL`이 출력될 수 있으니 마지막 `PASS` 요약과 종료 코드로 결과를 확인하세요. **로컬 테스트만으로 실제 VM 배포와 도구 작동을 검증할 수는 없습니다.**

## 리소스 정리

VM이 자동 종료돼도 디스크, NAT Gateway와 공용 IP 요금은 남을 수 있습니다. 삭제 전에 VM과 WSL의 필요한 데이터를 백업하세요.

배포한 PC의 저장소 루트에서 대상 azd 환경을 확인한 뒤 실행하세요. **선택한 환경의 리소스 그룹과 VM 데이터가 삭제됩니다.**

```powershell
azd env select appmod-dev
azd down
```
