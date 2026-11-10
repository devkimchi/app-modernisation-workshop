# Java 문제 해결

[전체 목차](../../README.md) | [Java 목차](README.md)

## 먼저 오류 위치를 구분하기

오류가 난 명령, 실행 폴더/셸, 트랙, 선택 엔진, 종료 코드와 **비밀을 제거한** 오류를 기록합니다. 코드 수정 전 원본 문제인지, 업그레이드 후 회귀인지, Azure 권한/네트워크 문제인지 구분합니다. 설치/인증/배포 문제를 한 번에 해결하려고 관리자 권한이나 전체 네트워크 개방을 사용하지 않습니다.

## 사전 점검과 다운로드

| 증상 | 확인과 조치 |
| --- | --- |
| PowerShell 7 또는 WSL2 플랫폼 누락 | Windows의 모든 `.ps1` 진입점은 두 항목을 함께 확인합니다. `powershell.exe -File ./scripts/install-prerequisites.ps1 -Track java`로 시작하면 누락된 항목마다 별도 설치 동의를 받습니다. WSL2는 관리자 권한/기능 변경/재부팅이 필요할 수 있으며 도우미가 배포판을 설치하거나 재부팅하지는 않습니다. 직접 재부팅한 뒤 다시 실행하고 Java용 WSL2 배포판을 별도 준비하세요. |
| `pwsh`를 찾을 수 없음 | Windows PowerShell 5.1에서 `.ps1`을 실행하면 PowerShell 7의 기본 설치 경로와 갱신된 PATH까지 찾습니다. 그래도 없으면 작업 전에 종료합니다. 위 설치 도우미로 준비하거나 PowerShell 7 설치 후 새 터미널을 엽니다. `.ps1`의 UTF-8 BOM과 LF를 유지하세요. |
| Java를 Git Bash에서 실행해 사전 점검 실패 | Java는 WSL2/macOS Bash입니다. Windows PowerShell wrapper에 실제 WSL 배포판을 지정할 수도 있습니다. |
| WSL 배포판 이름/버전 실패 | 기본값은 정확한 이름 `Ubuntu`입니다. 없거나 WSL1이면 다른 배포판으로 전환하지 않습니다. [배포판 지정](#wsl-배포판-지정)을 확인합니다. 사용자 지정 커널은 자동 판정되지 않을 수 있습니다. |
| Windows에는 도구가 있지만 WSL에서는 실패 | 설치/인증/PATH는 서로 다릅니다. Java 도구는 선택 WSL 안에서 확인하고 Windows app 호스트의 Git/Node도 별도 준비합니다. |
| 플러그인 도구 서버가 Windows JDK만 탐색 | Windows JDK 자동 설치를 승인하지 말고 지정한 WSL2의 Bash 명령을 사용하도록 요청합니다. 도구가 위임을 지원하지 않으면 해당 자동 검사를 미실행으로 남기고, 참가자가 같은 WSL 앱 루트에서 문서의 빌드/실행 명령을 수행해 별도 결과를 기록합니다. |
| `MANUAL`인데 종료 코드 0 | 수동 항목은 미검증입니다. Copilot 권한, 플러그인, RBAC/쿼터를 직접 확인합니다. |
| SDKMAN/JDK 누락 | `SDKMAN_DIR`, `candidates/java`, 실제 java/javac 버전을 확인합니다. PATH의 JRE만으로 통과하지 않습니다. |
| 스크립트 실행 권한/줄바꿈 | `bash scripts/...sh`로 실행합니다. CRLF로 바뀌었다면 배포본의 LF 파일을 복원합니다. 임의로 시스템 실행 정책을 완화하지 않습니다. |
| 엔진 인자 충돌 | `AZD_CONTAINER_RUNTIME`과 `-ContainerEngine`/`--container-engine`을 같은 값으로 맞춥니다. |
| 다운로드 대상이 비어 있지 않음 | 기존 파일을 보존하고 다른 빈 폴더를 지정합니다. 숨김 파일과 `.git`도 기존 내용입니다. |
| 보호 경로/심볼릭 링크/junction 오류 | 홈, 파일시스템 루트, 워크숍 루트, `docs`/`scripts`/`tests` 및 심볼릭 링크나 junction을 경유하는 경로는 거부합니다. 보호 경로가 아닌 실제 일반 디렉터리를 선택합니다. 자동 삭제로 우회하지 않습니다. |
| Git fetch/프록시/인증서 오류 | 회사 프록시와 인증서 체인을 정상 설정하고 고정 SHA 접근을 확인합니다. SSL 검증을 끄지 않습니다. |
| 다운로드 도중 디스크 오류 | 복사 도중 실패하면 미완료 파일이 남을 수 있습니다. 기존 파일은 덮어쓰지 않으므로 실패한 대상의 내용을 확인하고 새 빈 경로로 재시도합니다. `.workshop-download-*`는 고유 임시 경로지만 다른 실행이 사용 중인지 확인 없이 일괄 삭제하지 않습니다. |

다운로드의 필수 파일 오류를 해결하려고 `main` 최신 커밋으로 자동 전환하지 않습니다. 자료에 고정된 SHA 변경은 원본 차이와 실행 절차를 다시 검토해야 합니다.

## 사전 준비 수동 복구

점검과 설치 도우미의 조치를 거부했거나 실패한 경우에만 아래에서 필요한 항목을 수행합니다. 선택한 WSL2/macOS Bash에서 실행합니다. 조치 후 같은 환경에서 사전 점검을 다시 실행하세요.

### 기존 도구 업데이트와 설치 출처

기본 설치 도우미는 기존 도구를 업데이트하지 않습니다. `bash scripts/install-prerequisites.sh --track java --update`는 대화형 터미널에서만 도구별 동의를 받아 업데이트합니다. 거부한 항목은 변경하지 않으며, 필요한 도구가 여전히 부족하면 최종 사전 점검은 실패할 수 있습니다.

- **Node.js**: `command -v node`, `node --version`과 `nvm which current`를 비교합니다. nvm 설치가 있어도 선택된 Node.js가 다른 관리자 소유라면 자동으로 변경하지 않습니다. 현재 메이저가 22 이상이면 해당 메이저의 최신 정식 버전, 없거나 오래됐으면 22.x를 추가합니다. 설치에는 `nvm install --no-use <버전>`을 사용하고, 별도 동의 후 `nvm use`로 스크립트 환경에서 활성화합니다. 기존 버전과 기본 alias는 유지합니다. 부모 터미널에는 적용되지 않으므로 출력된 초기화 명령과 `nvm use <새-버전>`을 현재 Bash에서도 실행하세요. 활성화를 거부하고 기존 Node.js가 없거나 22 미만이면 최종 점검은 실패합니다.
- **JDK**: `sdk list java` 조회 실패, 정식 Temurin 미제공, 실제 java/javac 버전 불일치는 자동 설치 성공으로 처리하지 않습니다. 최신 JDK가 이미 있으면 재설치하지 않습니다. 기존 경로를 삭제하지 말고 아래 SDKMAN 복구 절차로 확인하세요. 기존 기본 JDK는 유지됩니다.
- **Azure CLI/azd 패키지 설치본**: `command -v az`, `command -v azd`와 실제 버전을 확인합니다. macOS는 해당 formula의 `brew --prefix <formula>`와 선택된 실행 파일의 실제 경로가 일치해야 합니다. WSL의 APT 설치본은 `dpkg-query -S <실행-파일-경로>`의 소유 패키지 및 `apt-cache policy azure-cli` 또는 `apt-cache policy azd`의 Microsoft HTTPS 저장소 후보를 확인합니다. 출처를 확인하지 못한 Azure CLI나 다른 관리자가 소유한 azd는 공식 스크립트로 덮어쓰지 않습니다. [Azure CLI](https://learn.microsoft.com/cli/azure/update-azure-cli) 또는 [azd](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd)의 공식 안내에서 **원래 설치 방식**의 업데이트 절차를 선택하세요.
- **WSL/Linux azd 공식 스크립트 설치본**: 누락 시 공식 스크립트로 설치하며 `--update`에서도 같은 방식을 사용합니다. 기본 링크 `/usr/local/bin/azd`가 `/opt/microsoft/azd/azd-linux-amd64` 또는 해당 ARM64 바이너리를 가리켜야 합니다. 기존 설치 기록이 없으면 경로와 버전을 확인하고 **공식 스크립트 방식으로 인계하는 동의**와 **설치/업데이트 동의**를 각각 받습니다. 사용자 지정 경로와 패키지 소유 파일은 덮어쓰지 않습니다. 성공 후 설치 방식, 실제 경로, 버전과 SHA-256을 `${XDG_STATE_HOME:-$HOME/.local/state}/app-modernisation-workshop/azd-script-install`에 기록합니다. 이 기록은 출처의 증명이 아니라 이후 파일 변경 감지용입니다. 기록과 다르거나 설치 후 경로/버전 검증에 실패하면 `FAIL`로 중단합니다. 파일이나 기록을 지워 우회하지 말고 변경 원인을 확인하세요. 기존 파일의 백업이나 실패 후 자동 롤백은 제공하지 않습니다.
- **Homebrew**: 누락 시 `--update`에서만 별도로 설치를 제안합니다. 거부하거나 설치 후 `brew --version`이 실패하면 자동 설치를 계속하지 않습니다. [공식 안내](https://brew.sh)에 따라 복구한 뒤 새 터미널에서 다시 점검하세요.

Windows는 `powershell.exe -File ./scripts/install-prerequisites.ps1 -Track java -Update`를 사용합니다.

- **Node.js**: nvm-windows 2.x는 `nvm config get root mode --json`의 설치 루트와 shim/link 경로를, 기존 1.x는 `NVM_HOME`, `NVM_SYMLINK`, `settings.txt`를 확인합니다. 현재 메이저가 22 이상이면 해당 메이저의 최신 정식 버전, 없거나 오래됐으면 22.x를 추가합니다. 설치와 `nvm use` 활성화는 별도 동의를 받으며 기존 버전은 보존합니다. 활성화는 Windows 공용 선택(shim/link)을 변경하므로 이후 터미널의 선택도 바뀌지만 실행 중인 Node.js 프로세스는 바뀌지 않습니다. Bash의 셸별 활성화 및 default alias와는 다릅니다. 독립 설치나 일반 디렉터리가 실행 경로를 차지하면 자동 전환하지 않습니다. 원래 관리자를 확인하고 [nvm-windows 안내](https://github.com/nvm-windows/nvm)에 따라 직접 전환한 뒤 새 터미널에서 점검하세요.

nvm-windows 2.x의 `auto_install=true`는 Node.js 검사만으로도 다른 버전을 설치할 수 있어 자동 처리를 중단합니다. `nvm config get auto_install --json`으로 확인하고 설정 변경은 직접 결정하세요. 프로젝트의 `.nvmrc`, `.node-version`, `package.json`이 버전을 고정했다면 공용 선택과 실제 실행 버전이 다를 수 있습니다. 도우미는 해당 파일이나 자동 감지 설정을 변경하지 않으며 활성화 후 실제 버전이 다르면 실패로 알립니다.
- **PowerShell 7**: 실행 경로·MSI 등록·winget 패키지가 일치하는 정식 7 버전만 업데이트합니다. Store/ZIP 등 출처를 확인할 수 없으면 자동 업데이트만 건너뛰고 필수 도구 확인은 계속합니다. 업데이트는 원래 관리자를 사용하세요. 업데이트 예약은 성공이 아니며 종료 코드 1로 멈춥니다. 현재 pwsh 종료 후 같은 콘솔의 작업 프로세스가 표시하는 `PASS`/`FAIL`을 확인하고 새 터미널에서 `pwsh --version`과 설치 도우미를 다시 실행하세요. 다른 pwsh가 열려 있으면 먼저 종료하세요.
- **WSL**: `wsl.exe --version`을 확인할 수 있는 플랫폼만 별도 동의 후 `wsl.exe --update`합니다. 버전을 제공하지 않는 inbox WSL은 [공식 안내](https://learn.microsoft.com/windows/wsl/install)에 따라 직접 준비하세요. 배포판 업데이트·삭제·자동 재부팅은 하지 않습니다. 재부팅 필요/검증 실패 시 직접 재부팅한 뒤 점검하세요.

두 업데이트 옵션 모두 CI/비대화형 환경에서는 거부됩니다. 회귀 테스트의 fixture 성공은 실제 설치나 OS 업데이트를 검증한 결과가 아닙니다.

### Azure 인증과 공급자 등록

먼저 오류가 미로그인, 권한 부족, 네트워크 중 어느 문제인지 확인합니다. `az`와 `azd` 인증은 별개이며, 브라우저나 장치 코드 인증은 직접 완료해야 합니다. 필요한 명령만 실행하세요.

```text
az login
az account list --output table
az account set --subscription "<본인-구독-ID>"
az account show --query "{name:name,id:id,tenantId:tenantId}" --output table
az extension add --name containerapp --upgrade
azd auth login
azd auth login --check-status
```

WSL에서 Windows 드라이브의 `az`가 호출되면 그 CLI의 인증 설정을 사용합니다. WSL 전용 CLI를 사용하려면 `command -v az`로 Linux 실행 파일을 확인한 뒤 해당 CLI에서 로그인과 구독을 확인하세요.

공급자 등록 실패 시 **대상 구독과 등록 권한을 먼저 확인**하고, 오류에 표시된 미등록 공급자만 아래 명령으로 등록합니다. 구독 설정이 변경되며 `--wait`는 시간이 걸릴 수 있습니다.

```text
az provider register --namespace "<미등록-공급자>" --wait
az provider show --namespace "<미등록-공급자>" --query registrationState --output tsv
```

공통 대상은 `Microsoft.App`, `Microsoft.OperationalInsights`, `Microsoft.Storage`, `Microsoft.ContainerRegistry`, `Microsoft.ServiceBus`입니다. Java에는 `Microsoft.DBforPostgreSQL`도 필요합니다. VNet/Private Endpoint를 추가하면 `Microsoft.Network` 등 추가 공급자를 배포 계획에 맞춰 확인합니다. 공급자 등록이나 로그인 성공이 역할 할당, 데이터베이스 Entra 관리자 지정 또는 DB 내부 사용자 생성 권한까지 보장하지는 않습니다.

### SDKMAN과 JDK 설치

SDKMAN 자체 설치가 실패하면 [공식 설치 안내](https://sdkman.io/install/)와 오류에 표시된 선행 도구를 확인합니다. 기존 설치 경로는 내용을 확인하고 필요한 파일을 보존한 뒤 직접 옮기거나 정리하세요. 도우미는 기존 경로를 덮어쓰지 않습니다.

Temurin을 제공하지 않는 OS/아키텍처에서는 같은 Bash에서 목록을 확인하고 다른 배포판의 **정식 JDK 8, 21, 25**를 선택합니다.

```bash
source "${SDKMAN_DIR:-$HOME/.sdkman}/bin/sdkman-init.sh"
sdk version
sdk list java
sdk install java <목록에서-선택한-식별자>
```

필요한 버전마다 설치를 반복합니다. JRE와 EA 버전은 제외하고, 식별자의 `+빌드번호`도 그대로 사용하세요. 수동 설치 중 기본 JDK 변경 질문은 직접 결정합니다. 앱 루트에서 `source ../scripts/use-java.sh 8`, `source ../scripts/use-java.sh 21` 또는 `source ../scripts/use-java.sh 25`를 실행하면 설치된 SDKMAN JDK를 현재 셸에서 전환합니다.

### WSL 배포판 지정

Windows PowerShell 7의 **워크숍 루트**에서 `wsl --list --verbose`로 설치된 배포판의 정확한 이름과 VERSION 2를 확인합니다. Java용 PowerShell 명령에서 `-WslDistribution`을 생략하면 Windows의 기본 배포판 설정과 무관하게 정확한 이름 `Ubuntu`를 사용합니다. `Ubuntu`가 없거나 WSL1이면 실패하며 다른 배포판으로 자동 전환하지 않습니다.

예를 들어 실제 WSL2 이름이 `Ubuntu-24.04`이면 점검과 다운로드에 동일하게 지정합니다.

```powershell
pwsh -File ./scripts/check-prerequisites.ps1 -Track java -WslDistribution Ubuntu-24.04 -ContainerEngine docker
pwsh -File ./scripts/download-sample.ps1 -Track java -WslDistribution Ubuntu-24.04 -ContainerEngine docker
```

대체 엔진을 사용한다면 아래 엔진 설정에 맞춰 두 명령의 엔진 옵션도 함께 변경합니다.

## Copilot app과 플러그인

| 증상 | 확인과 조치 |
| --- | --- |
| `modernize`가 없음 | Customize에서 마켓플레이스와 실제 설치/활성화, 조직 정책을 확인합니다. 새 세션/앱 재시작이 필요할 수 있습니다. |
| CLI 전용 안내가 보임 | 이 워크숍은 app의 Customize/Agent picker를 사용합니다. CLI나 VS Code 작업 흐름으로 임의 전환하지 않습니다. |
| 앱을 못 찾음 | app에 연 폴더가 `pom.xml`이 있는 앱 루트인지 확인합니다. |
| 평가가 오래 걸리거나 중단됨 | 로그의 도구 설치/네트워크/인증 실패를 확인하고 미완료 작업을 구분합니다. 전체 자동 승인을 켜서 해결하지 않습니다. |
| MCP 인증 만료 | 실패한 서버와 이유를 확인합니다. 전역 서버는 Customize > Installed의 Sign in, 저장소 서버는 프로젝트 Repository customizations > MCP servers의 Sign in을 사용합니다. 표시되지 않으면 관리자/강사에게 상태를 알립니다. |

플러그인 버전별 UI/산출물 위치는 달라질 수 있습니다. 실제 앱 버전, 플러그인 버전과 생성 경로를 기록합니다. 인증 토큰을 채팅에 붙이거나 CLI 전용 `/mcp auth`를 app 해결책으로 사용하지 않습니다.

## Java 로컬 실행

| 증상 | 확인과 조치 |
| --- | --- |
| Java 버전이 되돌아감 | SDKMAN `sdk use`는 현재 셸에 적용됩니다. 매 터미널/에이전트 실행 프로세스의 `java -version`과 Wrapper JDK를 확인합니다. |
| PostgreSQL/RabbitMQ 아직 준비 안 됨 | `pg_isready`, `rabbitmq-diagnostics`, 해당 컨테이너 로그를 확인합니다. 원본의 10초 대기는 readiness 보장이 아닙니다. |
| Java 포트/컨테이너 이름 충돌 | 현재 PID/컨테이너의 소유 프로젝트를 먼저 확인합니다. 다른 앱을 종료하거나 원본 start 스크립트를 반복 실행하지 않습니다. |
| Podman인데 Java 원본이 docker 호출 | 아래 [루프백 수동 실행](#루프백-수동-실행)의 서비스/Maven 실행 경로를 사용합니다. |

### 루프백 수동 실행

**공유 장비의 Docker 사용자**와 **Podman 사용자**를 위한 경로입니다. [Java 실습 1](01-run-locally.md)의 Java 8 빌드를 마친 뒤 **WSL2/macOS Bash의 앱 루트**에서 실행합니다. 원본 `startapp.sh`/`stopapp.sh`는 실행하지 않습니다. 전역 `docker=podman` alias를 만들거나 원본 스크립트를 수정할 필요가 없습니다.

아래는 Podman 명령입니다. Docker 사용자는 이 절차의 `podman` 명령만 `docker`로 바꿔 실행합니다. 두 엔진에서 중복 실행하지 않습니다.

```bash
podman ps -a --filter name=assets-postgres --filter name=assets-rabbitmq
```

같은 이름의 컨테이너가 이미 있으면 소유 프로젝트를 확인하고 이름 충돌을 해결한 뒤 진행합니다. 다른 프로젝트의 컨테이너를 임의로 중지하거나 삭제하지 않습니다.

`postgres/postgres`와 RabbitMQ 기본 계정은 원본과 맞추기 위한 **로컬 데모 전용**입니다. 클라우드에서 재사용하지 않습니다. `postgres:latest`, `rabbitmq:management`의 실제 이미지 ID를 기록합니다. 각 컨테이너 생성이 성공한 뒤 다음 명령을 실행합니다.

```bash
podman run -d --name assets-postgres \
  -e POSTGRES_DB=assets_manager -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres \
  -p 127.0.0.1:5432:5432 docker.io/library/postgres:latest
```

```bash
podman run -d --name assets-rabbitmq \
  -p 127.0.0.1:5672:5672 -p 127.0.0.1:15672:15672 docker.io/library/rabbitmq:management
```

```bash
podman exec assets-postgres pg_isready -U postgres -d assets_manager
podman exec assets-rabbitmq rabbitmq-diagnostics -q ping
```

두 상태 확인 명령이 성공한 뒤, 앱 루트를 기준으로 터미널 두 개에서 각각 실행합니다. 각 터미널에서 SDKMAN 초기화와 JDK 8 선택을 먼저 합니다.

```bash
# 터미널 A, 앱 루트에서
cd web
bash ../mvnw spring-boot:run -Dspring-boot.run.profiles=dev
```

```bash
# 터미널 B, 앱 루트에서
cd worker
bash ../mvnw spring-boot:run -Dspring-boot.run.profiles=dev
```

고정 대기 시간이나 웹 홈 화면만으로 DB/큐와 worker의 준비를 판단하지 않습니다. [실습 1의 기준 동작과 Git 기준선](01-run-locally.md#기준-동작과-git-기준선)으로 돌아가 업로드, 큐 처리와 로그를 확인합니다. 전경 앱은 각 터미널의 `Ctrl+C`로 종료하고, 백그라운드 프로세스라면 앱 경로와 PID를 확인한 뒤 **그 PID만** 종료합니다. 모든 Java 프로세스를 이름으로 종료하지 않습니다. 컨테이너 정리는 아래 엔진 안내와 [정리](07-cleanup.md)를 따릅니다.

## 엔진, azd와 Azure

### 대체 엔진 설정

본문은 Docker 기준입니다. Podman이 필요한 경우 [공식 설치 안내](https://podman.io/docs/installation)에 따라 설치하고 시작합니다. 기존 machine과 연결을 먼저 확인하고 필요한 경우에만 직접 생성하거나 시작합니다. Windows와 WSL의 CLI가 같은 엔진에 연결된다고 가정하지 마세요. 설치 도우미는 컨테이너 엔진을 자동 설치하지 않습니다.

엔진 선택은 명시 인자, `AZD_CONTAINER_RUNTIME`, 기본값 `docker` 순서입니다. 인자와 환경 변수가 다르면 오류가 발생하고, 선택한 엔진이 멈춰도 다른 엔진으로 전환하지 않습니다. Podman machine 목록만으로 현재 연결된 엔진을 판단하지 말고 `podman info`와 연결 설정을 함께 확인하세요. Docker 호환 대체 제품은 Linux 실행, `linux/amd64` 빌드, 포트 접근과 ACR 게시까지 직접 확인한 경우에만 조건부로 사용합니다.

**WSL2/macOS Bash의 워크숍 루트**에서 다음과 같이 설정합니다. `export`는 실습할 Bash마다 필요하며 스크립트가 부모 셸을 변경하지 않습니다.

```bash
export AZD_CONTAINER_RUNTIME=podman
bash scripts/check-prerequisites.sh --track java --container-engine podman
bash scripts/install-prerequisites.sh --track java --container-engine podman
bash scripts/download-sample.sh --track java --container-engine podman
```

설치 도우미는 누락된 도구가 있을 때만 필요한 항목을 직접 승인해 실행합니다. 다운로드는 점검을 통과한 뒤 한 번만 수행합니다. Windows PowerShell wrapper를 사용한다면 해당 셸에서도 `$env:AZD_CONTAINER_RUNTIME = 'podman'`을 설정하고 각 명령에 `-ContainerEngine podman`을 지정합니다. WSL 배포판 지정은 [위 안내](#wsl-배포판-지정)를 따릅니다.

앱 루트에서 인프라를 준비하거나 배포할 때도 프롬프트의 Docker 엔진 요구를 Podman으로 바꾸고 `AZD_CONTAINER_RUNTIME=podman`을 유지합니다. 엔진이 바뀌어도 Dockerfile, `remoteBuild: false`와 로컬 빌드 원칙은 같습니다. Docker의 `docker buildx`와 Podman의 내장 `podman build`는 구분해야 하며, Podman에는 Docker Buildx가 필요하지 않습니다. `azd`는 1.37.3 이상을 사용합니다. Java 원본은 명령을 일괄 치환하는 대신 위 [수동 서비스/Maven 경로](#루프백-수동-실행)를 사용합니다.

정리할 때는 원본을 실행한 동일 엔진에서 `podman inspect assets-postgres assets-rabbitmq`로 소유권을 확인하고, [정리](07-cleanup.md)의 `docker stop`/`docker rm`만 `podman stop`/`podman rm`으로 바꿉니다. 조회나 정지가 실패하면 다음 삭제 단계로 진행하지 않습니다. 다른 프로젝트의 컨테이너, 전체 `system prune`, 모든 볼륨과 Podman machine 삭제는 금지합니다.

### 엔진과 배포 오류

| 증상 | 확인과 조치 |
| --- | --- |
| Docker CLI는 있지만 연결 실패 | Desktop 실행/Linux 모드/context/WSL 통합을 확인합니다. 점검 스크립트는 서버를 시작하지 않습니다. |
| Podman 연결 실패 | 실제 server/machine/connection을 확인합니다. 필요할 때만 직접 machine을 시작하고 WSL과 Windows 엔진을 혼동하지 않습니다. |
| Podman에서 Buildx가 없음 | 정상입니다. 내장 `podman build`를 사용합니다. `azd` 1.37.3 이상과 `AZD_CONTAINER_RUNTIME=podman`을 확인합니다. |
| Apple Silicon/ARM에서 실행 형식 오류 | `linux/amd64` 이미지 manifest와 로컬 에뮬레이션/빌드를 확인합니다. 다른 플랫폼 이미지를 ACA에 밀어 넣지 않습니다. |
| `az` 로그인은 되지만 `azd` 실패 | `azd auth login`을 별도로 수행합니다. tenant, 구독과 선택 환경을 확인합니다. |
| `MissingSubscriptionRegistration` | 오류의 공급자를 확인하고 본인 구독에서 필요한 등록만 승인해 수행합니다. 추가 네트워크 리소스는 별도 공급자가 필요할 수 있습니다. |
| 리전/SKU/쿼터 실패 | 실제 선택 서비스의 가용성과 구독 쿼터를 확인합니다. 다른 리전/SKU로 바꾸면 비용과 네트워크 계획을 다시 승인합니다. |
| ACR Tasks/`az acr build` 제한 | 자료의 기본은 로컬 빌드입니다. `remoteBuild: false`와 선택 엔진을 확인합니다. 무료 구독 제한을 권한 우회로 해결하지 않습니다. |
| `azd package` 실패 | Dockerfile 경로/컨텍스트, Java reactor 경로, Linux base image와 디스크/메모리/엔진을 확인합니다. |
| `azd deploy`의 ACR push 실패 | 로컬 배포 사용자의 push 권한과 레지스트리 모드를 확인합니다. ABAC 모드라면 그 모드에 맞는 저장소 권한이 필요합니다. |
| 앱 image pull 실패 | ACA 관리 ID의 ACR pull 권한/registry 설정을 확인합니다. 로컬 사용자의 push 성공과는 별개입니다. |
| azd가 ACA를 못 찾음 | `azure.yaml` 서비스 이름, `azd-service-name` 태그/resourceName과 Bicep 출력 계약을 대조합니다. |
| revision이 ready가 아님 | 실제 listen port, ingress targetPort, 비루트 파일 권한, 시작/준비 probe와 콘솔/시스템 로그를 확인합니다. |
| DB 인증 실패 | Entra 관리자, DB 내부 principal과 권한을 확인합니다. ARM Contributor와 DB 로그인 권한을 구분합니다. |
| DB 연결 시간 초과 | DNS/TLS/방화벽/egress 경로를 확인합니다. ACA ingress static IP를 outbound로 사용하거나 모든 IP를 허용하지 않습니다. |
| Blob/Service Bus 403 | 앱이 쓰는 관리 ID와 데이터 평면 역할 및 범위를 확인하고 전파 후 제한적으로 재시도합니다. 구독 전체 권한으로 확대하지 않습니다. |
| 큐가 쌓이지만 화면은 정상 | 소비자 시작, queue 이름, 포맷, dead-letter, 재시도와 최소 replica를 확인합니다. 웹 HTTP 200은 비동기 처리 성공이 아닙니다. |
| `azd down` 실패 | 정확한 환경/그룹, resource lock과 삭제 권한을 확인합니다. 다른 그룹이나 전역 자원을 정리하지 말고 남은 리소스 ID와 비용 책임을 기록합니다. |

## 여기서 멈춰야 하는 경우

권한/비용 승인을 받지 못했거나, 원본 동작을 확인하지 못했거나, 필수 빌드/통합 검사가 실패했으면 다음 단계를 성공으로 표시하지 않습니다. 결과를 저장하고 생성한 자원을 정리한 뒤 미완료 범위와 원인을 남깁니다.

외부 Azure 통합 검사, WSL2/macOS/Podman 실기기 실행과 전체 업그레이드는 준비 스크립트의 fixture/mock 검사만으로 검증되지 않습니다. 강사는 행사 전에 사용할 OS/엔진 조합으로 리허설하고 사용한 도구/플러그인 버전을 기록해야 합니다.
