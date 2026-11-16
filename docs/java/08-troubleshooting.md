# 문제 해결

[전체 목차](../../README.md) | [Java 목차](README.md)

## 먼저 오류 위치를 구분하기

오류가 난 명령, 실행 폴더와 셸, 선택한 엔진, 종료 코드와 **비밀을 제거한** 로그를 기록합니다. 원본 앱, 업그레이드, Azure 권한과 네트워크 문제를 구분합니다. 관리자 권한으로 실행하거나 네트워크를 전체 개방해 문제를 우회하지 않습니다.

## 사전 점검과 다운로드

| 증상 | 확인과 조치 |
| --- | --- |
| PowerShell 7 누락 | Windows PowerShell 5.1에서 `./scripts/install-prerequisites.ps1 -Track java`를 실행하면 별도 동의를 받아 설치를 제안합니다. 다른 진입점은 본 작업 전에 멈춥니다. |
| `pwsh`를 찾을 수 없음 | 기본 설치 경로와 갱신된 PATH에서도 찾지 못한 경우입니다. PowerShell 7을 준비하고 새 터미널에서 확인합니다. |
| Windows 스크립트 실행 차단 | `Get-ExecutionPolicy`가 `Restricted`이면 `Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned`를 현재 창에만 적용하고 `./scripts/check-prerequisites.ps1 -Track java`를 다시 실행합니다. 시스템과 사용자 범위는 바꾸지 않습니다. 조직 정책이면 관리자에게 문의합니다. |
| `.sh`의 셸 오류 | `sh`나 `zsh`로 실행하지 말고 `./scripts/check-prerequisites.sh --track java`처럼 직접 실행합니다. 터미널의 셸과 스크립트를 실행하는 Bash는 별개입니다. JDK 선택 도우미 `use-java.sh`는 직접 실행하지 않고 Bash나 Zsh에서 `source`합니다. |
| `permission denied` 또는 줄바꿈 오류 | Git 복제본의 실행 권한과 LF를 확인합니다. 파일 복사로 권한이 사라졌다면 해당 스크립트에 실행 권한을 부여한 뒤 직접 실행합니다. CRLF 파일은 변경 내용을 보존하며 LF로 변환합니다. |
| `MANUAL`인데 종료 코드 0 | 수동 항목은 미검증입니다. Copilot 로그인과 사용 권한, RBAC와 쿼터를 직접 확인합니다. |
| 엔진 인자 충돌 | `AZD_CONTAINER_RUNTIME`과 `-ContainerEngine` 또는 `--container-engine`을 같은 값으로 맞춥니다. |
| 다운로드 대상이 비어 있지 않음 | 숨김 파일과 `.git`도 기존 내용입니다. 기존 파일을 보존하고 새 빈 폴더를 지정합니다. |
| 보호 경로, 심볼릭 링크 또는 junction 오류 | 홈, 파일시스템 루트, 워크숍 루트와 `docs`, `scripts`, `tests`를 피하고 링크를 경유하지 않는 일반 디렉터리를 선택합니다. 자동 삭제로 우회하지 않습니다. |
| Git fetch, 프록시 또는 인증서 오류 | 회사 프록시와 인증서 체인, 고정 SHA 접근을 확인합니다. TLS 검증을 끄거나 최신 `main`으로 바꾸지 않습니다. |
| 다운로드 도중 디스크 오류 | 미완료 파일을 확인하고 새 빈 경로로 재시도합니다. `.workshop-download-*`를 다른 실행이 사용하는지 확인하지 않고 일괄 삭제하지 않습니다. |

점검 종료 코드는 `0`이면 필수 자동 검사 통과, `1`이면 환경 검사 실패, `2`이면 인자 오류입니다. 실제 앱, `linux/amd64` 이미지와 배포 성공은 별도 실습에서 확인합니다. 다운로드 직전 점검이 실패하면 다운로드하지 않습니다. 준비 절차는 [실습 준비](00-setup.md)를 따릅니다.

## 사전 준비 수동 복구

거부하거나 실패한 조치 중 필요한 것만 수행하고 같은 환경에서 다시 점검합니다. 모든 설치와 업데이트는 항목별 동의를 받으며 CI나 비대화형 환경에서는 자동 승인하거나 실행하지 않습니다.

### Windows 도구와 JDK

필요한 업데이트는 워크숍 루트의 `./scripts/install-prerequisites.ps1 -Track java -Update`로 항목별 승인 후 진행합니다. 누락된 도구만 설치하려면 `-Update`를 생략합니다. PowerShell 7 설치만 Windows PowerShell 5.1 진입점에서 제안하며 winget 자체는 설치하지 않습니다.

- **Temurin**: UAC를 거부하면 설치가 완료되지 않습니다. 승인 가능한 환경에서 다시 실행하거나 관리자가 준비한 정식 JDK 8과 25를 사용합니다. 설치 도우미의 `FeatureMain` 구성은 시스템 `PATH`, `JAVA_HOME`과 파일 연결을 변경하지 않습니다. 기존 기본 JDK를 임의로 바꾸지 않습니다.
- **JDK 선택**: PowerShell 7의 **앱 루트**에서 `. ../scripts/use-java.ps1 -Jdk 8` 또는 `. ../scripts/use-java.ps1 -Jdk 25`를 실행합니다. 앞의 점과 공백은 필수입니다. 직접 실행은 호출자의 환경을 바꾸지 못하며 Windows PowerShell 5.1에서 dot-source하는 방식은 지원하지 않습니다. `mvnw.cmd`, Temurin 설치 경로, `java -version`과 `javac -version`을 확인합니다. JRE나 EA 버전으로 대체하지 않습니다.
- **PowerShell 업데이트**: 실행 경로, MSI 등록과 winget 출처가 맞는 정식 7 설치본만 업데이트를 제안합니다. Store나 ZIP 등 확인할 수 없는 설치본은 원래 설치 관리자로 업데이트합니다. 업데이트 예약은 성공이 아니며 종료 코드 1로 멈춥니다. 현재 pwsh를 닫은 후 작업 프로세스의 `PASS` 또는 `FAIL`을 확인하고 새 터미널에서 다시 점검합니다.
- **Azure CLI와 azd**: 누락된 도구는 winget으로 설치하며 기존 설치본 업데이트는 원래 설치 관리자를 사용합니다.

### Node.js 설치와 활성화

워크숍 기준은 **Node.js 22 이상**입니다. 없거나 22 미만이면 22.x를 추가하고 업데이트 시 현재 메이저 버전의 최신 정식 버전을 선택합니다. 기존 버전을 삭제하지 않습니다.

**Windows nvm-windows**

- 없으면 winget의 `AuthorSoftware.NVMWindows` 설치부터 제안합니다. 2.x는 `nvm config get root mode --json`의 루트와 shim 및 링크 경로를, 1.x는 `NVM_HOME`, `NVM_SYMLINK`, `settings.txt`와 활성 `node.exe`를 확인합니다.
- 독립 설치나 일반 디렉터리가 경로를 차지하면 자동으로 덮어쓰지 않습니다. [nvm-windows 안내](https://github.com/nvm-windows/nvm)에서 원래 관리자를 확인하고 직접 전환합니다.
- 설치와 `nvm use` 활성화는 별도 동의를 받습니다. 활성화는 Windows 공용 선택을 바꾸므로 이후 터미널에도 영향을 주지만 실행 중인 Node 프로세스는 바뀌지 않습니다.
- 2.x의 `auto_install=true`는 검사만으로 설치가 시작될 수 있어 중단합니다. `nvm config get auto_install --json`으로 확인하고 설정 변경은 직접 결정합니다. `.nvmrc`, `.node-version`, `package.json`은 수정하지 않습니다. 공용으로 선택한 버전과 프로젝트의 실제 버전이 다르면 실패로 알립니다.

**macOS와 Linux nvm**

- `command -v node`, `node --version`, `nvm which current`를 비교합니다. 선택된 Node가 다른 관리자 소유이면 자동으로 변경하지 않습니다.
- `nvm install --no-use "<버전>"`으로 설치하고 별도 동의 후 스크립트 환경에서 활성화합니다. 기존 버전과 기본 별칭은 유지합니다.
- 부모 터미널은 바뀌지 않습니다. 출력된 초기화 명령과 `nvm use "<새-버전>"`을 현재 Bash/Zsh에도 적용합니다. 활성화를 거부하고 기존 Node가 없거나 22 미만이면 최종 점검은 실패합니다.

`npx` 도구 서버 다운로드가 실패하면 Node와 npm의 실제 경로, 네트워크, 프록시와 npm 레지스트리 설정을 확인합니다. TLS 검증을 끄지 않습니다. 오류 메시지와 비밀을 제거한 로그를 기록합니다. 패키지 다운로드만으로 전체 현대화가 성공했다고 표시하지 않습니다.

### macOS Homebrew와 SDKMAN

Homebrew는 필수입니다. 일반 설치와 `--update` 모두 다른 도구보다 먼저 확인합니다. 설치에는 관리자 승인과 Xcode Command Line Tools가 필요할 수 있습니다. 거부하거나 실패하면 Homebrew가 필요한 도구는 건너뛰고 최종 검사는 실패하지만 Node와 JDK 준비는 별도로 진행할 수 있습니다.

[공식 안내](https://brew.sh)에 따라 복구하고 출력된 `brew shellenv`를 로그인 셸 파일(`~/.zprofile` 또는 `~/.bash_profile`)에 직접 반영합니다. 도우미는 이 파일을 수정하지 않습니다. Modernize는 전체 cask 이름으로 설치합니다.

```bash
brew tap microsoft/modernize https://github.com/microsoft/modernize-cli
brew install --cask microsoft/modernize/modernize
```

tap 전체를 신뢰할 필요는 없습니다. SDKMAN 설치기는 macOS에서 Zsh로 실행하며 설치 후 `sdk`는 Bash 3.2에서도 사용할 수 있도록 구성합니다. Homebrew Bash를 필수로 설치하지 않습니다.

### Linux 도구와 설치 출처

자동 설치는 `apt-get`과 `sudo`가 있는 Ubuntu/Debian 계열에서만 제안합니다. 다른 배포판은 [준비 문서의 공식 링크](00-setup.md#도구-설치-및-업데이트)로 수동 설치한 뒤 점검합니다. Linux에서는 Homebrew를 요구하지 않습니다.

- gh apt 경로는 공식 저장소와 키링을 추가하고 시스템 패키지를 변경하므로 `sudo`와 각 조치를 승인합니다.
- Modernize 공식 `install.sh`는 `sh`로 실행되며 `~/.local/share/modernize`와 `~/.local/bin`을 사용합니다. glibc 2.27 이상이 필요합니다. 설치기가 셸 설정에 PATH를 추가하므로 새 터미널을 열거나 설정을 다시 읽습니다.
- Azure CLI와 azd의 APT 설치본은 `dpkg-query -S "<실행-파일-경로>"`와 `apt-cache policy azure-cli` 또는 `apt-cache policy azd`로 소유 패키지와 Microsoft HTTPS 저장소 후보를 확인합니다. 출처를 확인하지 못한 설치본은 공식 스크립트로 덮어쓰지 않습니다.
- azd 공식 스크립트 설치본은 기본 링크 `/usr/local/bin/azd`가 `/opt/microsoft/azd/azd-linux-amd64` 또는 해당 ARM64 바이너리를 가리켜야 합니다. 기존 기록이 없으면 공식 스크립트 방식으로 관리를 전환하는 동의와 설치 또는 업데이트 동의를 각각 받습니다. 사용자 지정 경로와 패키지 소유 파일은 덮어쓰지 않습니다.
- 성공 후 경로, 버전과 SHA-256을 `${XDG_STATE_HOME:-$HOME/.local/state}/app-modernisation-workshop/azd-script-install`에 기록합니다. 이는 출처 증명이 아니라 이후 변경을 감지하기 위한 기록입니다. 기록과 다르거나 설치 후 검증에 실패하면 멈춥니다. 기록을 삭제해 우회하지 않으며 자동 백업과 복원은 제공하지 않습니다.

macOS 패키지 업데이트도 실제 실행 파일이 해당 `brew --prefix "<formula>"`의 설치본인지 확인합니다. [Azure CLI](https://learn.microsoft.com/cli/azure/update-azure-cli)와 [azd](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd)의 원래 설치 관리자 경로를 유지합니다.

### SDKMAN JDK 선택

macOS와 Linux에서 [SDKMAN 공식 안내](https://sdkman.io/install/)와 필요한 선행 도구를 확인합니다. 기존 설치 폴더를 임의로 덮어쓰거나 기본 JDK를 바꾸지 않습니다. 정식 Temurin을 제공하지 않는 OS/아키텍처라면 목록에서 정식 JDK 8과 25를 선택합니다.

```bash
source "${SDKMAN_DIR:-$HOME/.sdkman}/bin/sdkman-init.sh"
sdk version
sdk list java
sdk install java "<목록에서-선택한-식별자>"
```

식별자의 `+빌드번호`를 유지하고 JRE와 EA 버전은 제외합니다. 필요한 버전마다 설치하고 기본 JDK 변경 질문은 직접 결정합니다. 앱 루트에서 `source ../scripts/use-java.sh --jdk 8` 또는 `source ../scripts/use-java.sh --jdk 25`를 적용합니다. `sdk list`가 실패하거나 java와 javac이 일치하지 않거나 필요한 JDK가 없으면 설치 성공으로 처리하지 않습니다.

### Azure 인증과 공급자 등록

로그인 누락, 권한 부족과 네트워크 문제를 먼저 구분합니다. Azure CLI와 azd 인증은 별개입니다. 필요한 로그인, 구독 변경과 확장 설치는 각각 승인한 뒤 직접 실행합니다.

```bash
az login
az account list --output table
az account set --subscription "<본인-구독-ID>"
az account show --query "{name:name,id:id,tenantId:tenantId}" --output table
az extension add --name containerapp --upgrade
azd auth login
azd auth login --check-status
```

공급자 등록 실패 시 대상 구독과 등록 권한을 확인하고 오류의 미등록 공급자만 등록합니다. 구독 설정이 변경되며 `--wait`는 시간이 걸릴 수 있습니다.

```bash
az provider register --namespace "<미등록-공급자>" --wait
az provider show --namespace "<미등록-공급자>" --query registrationState --output tsv
```

공통 대상은 `Microsoft.App`, `Microsoft.OperationalInsights`, `Microsoft.Storage`, `Microsoft.ContainerRegistry`, `Microsoft.ServiceBus`이며 Java는 `Microsoft.DBforPostgreSQL`도 필요합니다. 네트워크 리소스를 추가하면 `Microsoft.Network` 등도 확인합니다. 로그인이나 공급자 등록에 성공해도 역할 할당, DB Entra 관리자 또는 DB 내부 보안 주체를 생성할 권한까지 보장되지는 않습니다.

## Java 로컬 실행

| 증상 | 확인과 조치 |
| --- | --- |
| Java 버전이 되돌아감 | JDK 선택은 현재 셸에만 적용됩니다. 매 터미널과 채팅의 실행 셸에 `use-java.ps1` 또는 `use-java.sh`를 적용하고 Wrapper의 JDK도 확인합니다. |
| Windows 시작 창이 바로 닫힘 | `startapp.cmd`를 앱 루트에서 실행했는지, JDK와 Docker 연결, Web Module과 Worker Module의 오류를 확인합니다. 성공으로 간주해 다음 단계로 넘어가지 않습니다. |
| Windows 종료 또는 PID 파일 오류 | 이번 앱의 창과 PID 파일을 대조합니다. 해당 창에서 중단하고 남은 창을 닫습니다. 필요하면 `Get-CimInstance Win32_Process`로 앱 경로를 확인한 정확한 PID만 종료합니다. |
| PostgreSQL 또는 RabbitMQ가 준비되지 않음 | 컨테이너 로그, `pg_isready`, `rabbitmq-diagnostics`를 확인합니다. 원본의 10초 대기는 서비스 준비를 보장하지 않습니다. |
| 포트 또는 컨테이너 이름 충돌 | 소유 프로젝트를 먼저 확인합니다. 다른 앱을 종료하거나 원본 시작 스크립트를 반복 실행하지 않습니다. |
| localhost 응답 없음 | web 로그와 8080 수신 상태를 확인합니다. Windows는 `curl.exe -I http://127.0.0.1:8080/`, macOS와 Linux는 `curl -I http://127.0.0.1:8080/`로 조회합니다. 루트에서 `/storage`로 이동하는 302 응답은 정상입니다. |
| Podman인데 원본이 docker를 호출함 | 아래 수동 실행을 사용합니다. 전역 별칭이나 원본 파일의 일괄 치환으로 우회하지 않습니다. |

### 루프백 수동 실행

공유 장비의 Docker 사용자와 Podman 사용자를 위한 방법입니다. Java 8 빌드를 마친 **앱 루트**에서 원본 시작 및 종료 스크립트 대신 수행합니다. 아래 Podman 명령은 Docker 사용 시 `docker`로만 바꿉니다. 두 엔진에서 중복 실행하지 않습니다.

다음 한 줄 명령은 PowerShell 7과 Bash/Zsh에서 모두 실행할 수 있습니다.

```bash
podman ps -a --filter name=assets-postgres --filter name=assets-rabbitmq
```

같은 이름이 있으면 소유 프로젝트를 확인합니다. 기존 컨테이너를 임의로 삭제하지 않습니다. `postgres/postgres`와 RabbitMQ 기본 계정은 원본과 맞추는 **로컬 데모 전용**이며 클라우드에서 재사용하지 않습니다. 이미지의 실제 ID를 기록하고 각 명령의 성공 후 다음으로 진행합니다.

```bash
podman run -d --name assets-postgres -e POSTGRES_DB=assets_manager -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres -p 127.0.0.1:5432:5432 docker.io/library/postgres:latest
```

```bash
podman run -d --name assets-rabbitmq -p 127.0.0.1:5672:5672 -p 127.0.0.1:15672:15672 docker.io/library/rabbitmq:management
```

```bash
podman exec assets-postgres pg_isready -U postgres -d assets_manager
podman exec assets-rabbitmq rabbitmq-diagnostics -q ping
```

둘 다 준비되면 앱 루트에서 터미널 두 개를 열고 각각 실행합니다.

터미널 A:

```bash
# zsh/bash
source ../scripts/use-java.sh --jdk 8
cd web
../mvnw spring-boot:run "-Dspring-boot.run.profiles=dev"
```

```powershell
# PowerShell
. ../scripts/use-java.ps1 -Jdk 8
Set-Location web
../mvnw.cmd spring-boot:run "-Dspring-boot.run.profiles=dev"
```

터미널 B:

```bash
# zsh/bash
source ../scripts/use-java.sh --jdk 8
cd worker
../mvnw spring-boot:run "-Dspring-boot.run.profiles=dev"
```

```powershell
# PowerShell
. ../scripts/use-java.ps1 -Jdk 8
Set-Location worker
../mvnw.cmd spring-boot:run "-Dspring-boot.run.profiles=dev"
```

[실습 1: 원본 앱을 로컬에서 실행하기](01-run-locally.md#현재-앱의-동작-확인)의 업로드, 큐와 로그를 확인합니다. 전경 앱은 각 터미널의 `Ctrl+C`로 종료합니다. 컨테이너는 [실습 7: 리소스와 로컬 실행 정리하기](07-cleanup.md)에서 사용한 엔진과 소유권을 확인한 뒤 개별 정리합니다.

## 평가와 계획

| 증상 | 확인과 조치 |
| --- | --- |
| `modernize`를 찾을 수 없음 | 앱 터미널의 실제 PATH와 `modernize --version`을 확인합니다. Windows는 새 터미널이나 앱 재시작, macOS는 Homebrew 환경, Linux는 `~/.local/bin`을 확인합니다. |
| gh 버전 또는 인증 실패 | `gh --version`이 2.45.0 이상인지 확인하고 필요하면 참가자가 `gh auth login`을 수행합니다. 앱 로그인, gh 인증과 모델 사용 권한은 별개입니다. |
| 앱을 찾지 못함 | 현재 폴더의 `pom.xml`, `git rev-parse --show-toplevel`과 선택한 작업 공간을 확인합니다. 앱이 아닌 자료 폴더를 평가하지 않습니다. |
| 평가나 계획이 중단됨 | CLI 버전, 실패한 도구, 네트워크와 인증 상태, 실제 산출물 경로를 기록합니다. 완료되지 않은 결과는 성공으로 표시하지 않습니다. |
| Full analysis 결과가 없음 | Assess 설정과 실제 완료 범위를 확인합니다. 명령형 `assess` 한 줄이 Full analysis를 자동 선택한다고 가정하지 않습니다. |
| 계획이 보고서나 지침을 참조하지 않음 | 실제 평가 보고서와 지침 경로를 확인하고 [실습 2: 평가하고 계획 승인하기](02-assess-and-plan.md)의 입력과 `plan.md`, `tasks.json`을 대조합니다. |
| 계획 범위가 너무 큼 | 하나의 계획에 필요한 작업만 남기고 단계 순서와 검증 실패 시 중단 조건을 확인합니다. 문서화되지 않은 `--task`, `--phase`, `--until`을 만들거나 `--force`로 승인 경계를 우회하지 않습니다. |
| 재실행 시 같은 계획이 있음 | 실제 산출물과 완료한 작업을 먼저 확인합니다. `--overwrite`로 검토 없이 덮어쓰지 않습니다. |

`modernize help models`로 CLI 모델을 확인합니다. 무인 자동 승인이나 전체 권한 허용으로 실패를 우회하지 않습니다. 화면이나 입력에 문제가 있으면 창 크기, 현재 셸과 비밀을 제거한 오류를 강사에게 전달합니다.

## 업그레이드와 Azure 서비스 이전

| 증상 | 확인과 조치 |
| --- | --- |
| 계획 실행 후 변경 사항이 없음 | Modernize가 자동 커밋했을 수 있습니다. [실습 3: JDK 25로 업그레이드하기](03-upgrade.md)에서 기록한 `$before`를 기준으로 `git log`와 `git diff`를 확인합니다. 미완료 작업은 성공으로 표시하지 않습니다. |
| 다른 Copilot 세션에 영향 | 실행 전후 전역 설정과 CLI 버전을 기록하고 중단합니다. 사용자 전역 디렉터리를 지우거나 내부 파일을 즉석에서 수정하지 않습니다. |
| 업그레이드 빌드 실패 | 앱 루트의 같은 셸에서 JDK 25를 선택하고 Maven Wrapper, 컴파일 설정, 테스트 JVM과 Spring/Jakarta/ORM 호환성을 대조합니다. 실패한 검사를 삭제하지 않습니다. |
| 모의 테스트 실패 또는 누락 | web과 worker의 실행 결과와 테스트 보고서를 확인합니다. 실제 Azure 연결 없이 검증하고 실패하거나 실행되지 않은 테스트를 성공으로 처리하지 않습니다. |
| 이전 코드의 동작이나 권한이 불명확함 | [실습 4: Azure 서비스로 의존성 이전하기](04-migrate-azure-services.md)의 요구사항과 코드, 테스트를 대조합니다. `dev`와 `dev` 외 S3 경로의 차이와 web/worker의 역할을 확인하고 미확인 항목은 남겨 둡니다. |
| 통합 테스트나 실행 스크립트가 없음 | [실습 4의 Azure 통합 테스트 준비](04-migrate-azure-services.md#azure-통합-테스트-준비)에서 `azure-it` 프로필, 테스트와 셸별 스크립트를 생성하고 검토합니다. 이 단계에서는 실제 Azure 연결 테스트를 실행하지 않습니다. |
| Dockerfile, Bicep이나 DB 초기화 절차가 불명확함 | [실습 5: azd 배포 산출물 준비하기](05-prepare-azd.md)에서 앱 코드와 산출물, 훅과 권한을 대조합니다. 리소스 생성이나 DB 변경 없이 누락된 사항과 승인할 범위를 먼저 확인합니다. |

## 엔진, azd와 Azure

### 대체 엔진 설정

실습 문서는 Docker를 기준으로 합니다. Podman은 [공식 설치 안내](https://podman.io/docs/installation)를 따르고 기존 머신과 연결을 먼저 확인합니다. 도우미는 엔진을 자동 설치하지 않습니다. Linux Docker Engine의 권한 문제는 [공식 설치 후 안내](https://docs.docker.com/engine/install/linux-postinstall/)를 따릅니다. docker 그룹은 높은 권한을 부여하므로 영향을 확인하고 `sudo` 없는 연결을 준비합니다. 소켓을 모든 사용자에게 개방하지 않습니다.

엔진 선택은 명시 인자, `AZD_CONTAINER_RUNTIME`, 기본값 `docker` 순서입니다. 인자와 환경 변수가 충돌하면 실패하고 다른 엔진으로 자동 전환하지 않습니다. `podman info`와 실제 연결을 확인합니다. Docker 호환 제품은 Linux 실행, `linux/amd64` 빌드, 포트 접근과 ACR 게시까지 확인한 경우에만 사용합니다.

**워크숍 루트**에서 실행합니다. 환경 변수는 실습할 터미널마다 설정합니다.

```bash
# zsh/bash
export AZD_CONTAINER_RUNTIME=podman
./scripts/check-prerequisites.sh --track java --container-engine podman
./scripts/install-prerequisites.sh --track java --container-engine podman
./scripts/download-sample.sh --track java --container-engine podman
```

```powershell
# PowerShell
$env:AZD_CONTAINER_RUNTIME = 'podman'
./scripts/check-prerequisites.ps1 -Track java -ContainerEngine podman
./scripts/install-prerequisites.ps1 -Track java -ContainerEngine podman
./scripts/download-sample.ps1 -Track java -ContainerEngine podman
```

필요한 설치만 직접 승인하고 다운로드는 점검 후 한 번만 수행합니다. 앱 루트의 계획 입력도 Docker 엔진 요구를 Podman으로 바꾸되 Dockerfile, `remoteBuild: false`와 로컬 빌드는 유지합니다. Podman은 내장 `podman build`를 사용하므로 Docker Buildx가 필요하지 않습니다. azd는 **1.37.3 이상**을 사용합니다.

정리는 같은 엔진의 `podman inspect assets-postgres assets-rabbitmq`로 확인한 뒤 [실습 7: 리소스와 로컬 실행 정리하기](07-cleanup.md)의 `docker stop`과 `docker rm`만 `podman stop`과 `podman rm`으로 바꿉니다. 조회나 정지에 실패하면 삭제하지 않습니다. 다른 프로젝트의 리소스, 전체 `system prune`, 모든 볼륨과 엔진 머신은 삭제하지 않습니다.

### 프로비저닝과 배포 오류

[실습 5: azd 배포 산출물 준비하기](05-prepare-azd.md)와 [실습 6: azd로 ACA에 배포하기](06-deploy-aca.md)의 산출물과 승인 범위를 대조합니다. 실패한 명령의 결과를 확인하기 전에는 다음 단계로 진행하지 않습니다.

| 증상 | 확인과 조치 |
| --- | --- |
| Docker CLI는 있지만 연결 실패 | Docker Desktop 또는 Engine 서비스, Linux 모드와 컨텍스트를 확인합니다. 점검 스크립트는 서버를 시작하지 않습니다. |
| Podman 연결 실패 | 실제 서버, 머신과 연결을 확인하고 필요한 경우에만 시작합니다. 목록만으로 연결 성공을 판단하지 않습니다. |
| Apple Silicon 또는 ARM 실행 형식 오류 | Linux/amd64 매니페스트와 로컬 에뮬레이션 및 빌드를 확인합니다. 다른 플랫폼 이미지를 ACA에 게시하지 않습니다. |
| `az` 로그인만 성공 | azd 인증, 테넌트, 구독과 환경을 별도로 확인합니다. |
| 리전, SKU 또는 쿼터 오류 | 실제 가용성과 쿼터를 확인하고 변경된 비용과 네트워크 계획을 다시 승인합니다. |
| ACR Tasks 제한 | `remoteBuild: false`와 로컬 엔진을 유지합니다. 무료 구독 제한을 권한 우회로 해결하지 않습니다. |
| `azd package` 실패 | Dockerfile과 빌드 컨텍스트, Maven reactor, Linux 이미지, 디스크, 메모리와 엔진을 확인합니다. Windows에서 작성된 `mvnw`의 CRLF도 확인합니다. |
| `azd deploy`가 다시 빌드함 | 가능한 동작입니다. 패키징 후 소스를 바꾸지 않고 실제 게시 및 배포된 이미지의 태그와 다이제스트를 기록합니다. |
| ACR 이미지 게시 또는 가져오기 실패 | 로컬 게시 주체의 푸시 권한과 ACA 관리 ID의 가져오기 권한을 구분합니다. 레지스트리가 ABAC 모드라면 해당 저장소 권한도 확인합니다. |
| azd가 ACA를 찾지 못함 | 서비스 이름, `azd-service-name` 또는 `resourceName`과 Bicep 출력을 대조합니다. |
| 수정 버전이 준비되지 않음 | 수신 설정과 `targetPort`, 비루트 파일 권한, 시작 및 준비 프로브와 콘솔 및 시스템 로그를 확인합니다. |
| DB 인증 실패 | Entra 관리자, DB 보안 주체와 권한을 확인합니다. Azure 리소스의 Contributor와 DB 로그인 권한은 다릅니다. |
| DB 연결 시간 초과 | DNS, TLS, 방화벽과 송신 경로를 확인합니다. ACA 수신 IP를 송신 IP로 사용하거나 모든 IP를 허용하지 않습니다. |
| Blob 또는 Service Bus에서 403 응답 | 실제 관리 ID, 데이터 역할과 범위를 확인하고 권한 전파 후 제한적으로 재시도합니다. 구독 전체로 권한을 확대하지 않습니다. |
| 큐가 쌓이지만 화면은 정상 | 소비자 시작, 큐 이름과 메시지 형식, 배달 못 한 편지 큐, 재시도와 최소 복제본 수를 확인합니다. HTTP 200은 비동기 처리의 성공이 아닙니다. |
| 승인 질문이 나오지 않음 | azd의 자동 비대화형 설정과 `AZD_NON_INTERACTIVE` 지원을 확인합니다. 작업 전에 대상과 비용을 직접 승인하고 훅도 검토합니다. |

### Azure 통합 테스트와 end-to-end 테스트

[실습 6의 Azure 통합 테스트 실행](06-deploy-aca.md#azure-통합-테스트-실행)에서는 로컬 Azure CLI 사용자의 권한을 사용합니다. 이 결과만으로 배포된 앱의 관리 ID 인증까지 확인할 수는 없습니다.

| 증상 | 확인과 조치 |
| --- | --- |
| 스크립트나 `azure-it` 프로필이 없음 | [실습 4의 Azure 통합 테스트 준비](04-migrate-azure-services.md#azure-통합-테스트-준비)에서 테스트와 스크립트가 생성되고 연결됐는지 확인합니다. 없거나 불분명하면 실제 테스트를 실행하지 않습니다. |
| 대상 조회 실패 또는 구독 불일치 | Azure CLI 로그인 사용자와 azd 환경의 구독을 대조합니다. [실습 5의 출력 계약](05-prepare-azd.md#배포-산출물-요구사항-확인)에 필요한 값이 없거나 자리 표시자이면 보완한 뒤 다시 확인합니다. |
| DB 사용자 또는 인증 실패 | Azure CLI 사용자 계정과 PostgreSQL DB 사용자 이름이 일치하는지, `AzureCliCredential`, Entra 인증과 TLS를 확인합니다. 서비스 주체의 DB 역할 이름은 추측하지 않습니다. |
| 테스트 큐가 앱 큐와 같거나 확인되지 않음 | 실제 배포 설정과 앱 큐 출력을 대조하고 메시지를 공유하지 않는 테스트 전용 큐를 확인합니다. 구분할 수 없으면 실행하지 않습니다. 리소스와 권한 변경은 별도 승인을 받습니다. |
| 프로필만 활성화되거나 테스트가 건너뛰어짐 | 이번 실행의 보고서에서 DB, Blob, Service Bus 테스트가 각각 실행되고 성공했는지 확인합니다. 프로필 활성화나 Maven 성공만으로 테스트 성공을 판단하지 않습니다. |
| end-to-end 결과가 불명확함 | [실습 6의 end-to-end 테스트](06-deploy-aca.md#end-to-end-테스트-작성과-실행)에서 업로드, worker 처리와 결과 조회를 확인합니다. HTTP 200이나 비공개 Blob의 연결 오류만으로 성공을 판단하지 않습니다. |

실제 테스트 전에 대상, 권한, 네트워크, 비용과 데이터 변경 범위를 확인하고 명시적으로 승인합니다. 테스트 데이터를 정리할 때도 범위와 영향을 확인하고 별도 승인을 받습니다.

## 리소스와 로컬 실행 정리

[실습 7: 리소스와 로컬 실행 정리하기](07-cleanup.md)에서 본인 실습 환경과 리소스를 확인합니다. 실패한 배포에도 리소스가 남을 수 있습니다.

| 증상 | 확인과 조치 |
| --- | --- |
| 환경이나 리소스 그룹을 확인할 수 없음 | 다른 환경을 대신 선택하거나 임의의 그룹을 삭제하지 않습니다. Azure 포털의 환경명, 태그와 활동 로그를 확인합니다. |
| `azd down` 실패 | 환경과 리소스 그룹, 잠금과 삭제 권한을 확인합니다. 다른 리소스를 지우지 말고 남은 ID와 비용 책임을 기록합니다. |
| 삭제 옵션의 영향이 불명확함 | `--force`는 삭제 확인을 생략합니다. `--purge`는 일시 삭제되는 리소스를 확인 없이 영구 삭제합니다. 사용 전에 대상과 복구 가능성, 영향을 확인하고 별도 승인을 받습니다. |
| 컨테이너나 프로세스가 남음 | 실습에서 사용한 엔진, 앱 경로와 소유권을 확인합니다. 확인한 컨테이너와 PID만 정리하며 다른 프로젝트나 전체 엔진은 삭제하지 않습니다. |

## 여기서 멈춰야 하는 경우

권한이나 비용을 승인받지 못했거나 원본 동작과 필수 검사를 확인하지 못했다면 다음 단계를 성공으로 표시하지 않습니다. 비밀을 제거한 결과를 남기고 생성한 리소스의 정리 범위를 확인합니다. 모의 검증만으로 실제 설치, 운영체제와 엔진 조합, Modernize 전체 실행 또는 Azure 통합이 검증된 것은 아닙니다.
