# 공통 문제 해결

[전체 목차](../README.md) | [공통 준비](setup.md) | [Java 목차](java/README.md) | [.NET 목차](dotnet/README.md) | [Java 정리](java/07-cleanup.md) | [.NET 정리](dotnet/07-cleanup.md)

## 먼저 오류 위치를 구분하기

오류가 난 명령, 실행 폴더/셸, 트랙, 선택 엔진, 종료 코드와 **비밀을 제거한** 오류를 기록합니다. 코드 수정 전 원본 문제인지, 업그레이드 후 회귀인지, Azure 권한/네트워크 문제인지 구분합니다. 설치/인증/배포 문제를 한 번에 해결하려고 관리자 권한이나 전체 네트워크 개방을 사용하지 않습니다.

## 사전 점검과 다운로드

| 증상 | 확인과 조치 |
| --- | --- |
| `pwsh`를 찾을 수 없음 | PowerShell 7 설치 후 새 터미널을 엽니다. `powershell.exe` 5.1로 바꾸지 않습니다. |
| Java를 Git Bash에서 실행했다고 실패 | Java는 WSL2/macOS Bash입니다. Windows PowerShell wrapper에 실제 WSL 배포판을 지정할 수도 있습니다. |
| WSL 배포판 이름/버전 실패 | `wsl --list --verbose`에서 이름과 VERSION 2를 확인합니다. 여러 배포판이면 `-WslDistribution`을 지정합니다. 사용자 지정 커널은 자동 판정되지 않을 수 있습니다. |
| Windows에는 도구가 있지만 WSL에서는 실패 | 설치/인증/PATH는 서로 다릅니다. Java 도구는 선택 WSL 안에서 확인하고 Windows app 호스트의 Git/Node도 별도 준비합니다. |
| 플러그인 도구 서버가 Windows JDK만 탐색 | Windows JDK 자동 설치를 승인하지 말고 지정한 WSL2의 Bash 명령을 사용하도록 요청합니다. 도구가 위임을 지원하지 않으면 해당 자동 검사를 미실행으로 남기고, 참가자가 같은 WSL 앱 루트에서 문서의 빌드/실행 명령을 수행해 별도 결과를 기록합니다. |
| `MANUAL`인데 종료 코드 0 | 수동 항목은 미검증입니다. Copilot 권한, 플러그인, RBAC/쿼터를 직접 확인합니다. |
| SDKMAN/JDK 누락 | `SDKMAN_DIR`, `candidates/java`, 실제 java/javac 버전을 확인합니다. PATH의 JRE만으로 통과하지 않습니다. |
| 스크립트 실행 권한/줄바꿈 | `bash scripts/...sh`로 실행합니다. CRLF로 바뀌었다면 배포본의 LF 파일을 복원합니다. 임의로 시스템 실행 정책을 완화하지 않습니다. |
| 엔진 인자 충돌 | `AZD_CONTAINER_RUNTIME`과 `-ContainerEngine`/`--container-engine`을 같은 값으로 맞춥니다. |
| 다운로드 대상이 비어 있지 않음 | 기존 파일을 보존하고 다른 빈 폴더를 지정합니다. 숨김 파일과 `.git`도 기존 내용입니다. |
| 보호 경로/심볼릭 링크/junction 오류 | 워크샵 문서, 홈/루트가 아닌 실제 일반 디렉터리를 선택합니다. 자동 삭제로 우회하지 않습니다. |
| Git fetch/프록시/인증서 오류 | 회사 프록시와 인증서 체인을 정상 설정하고 고정 SHA 접근을 확인합니다. SSL 검증을 끄지 않습니다. |
| 다운로드 도중 디스크 오류 | 실패한 대상의 내용을 확인하고 새 빈 경로로 재시도합니다. `.workshop-download-*`는 고유 임시 경로지만 다른 실행이 사용 중인지 확인 없이 일괄 삭제하지 않습니다. |

다운로드의 필수 파일 오류를 해결하려고 `main` 최신 커밋으로 자동 전환하지 않습니다. 자료에 고정된 SHA 변경은 원본 차이와 실행 절차를 다시 검토해야 합니다.

## Copilot app과 플러그인

| 증상 | 확인과 조치 |
| --- | --- |
| `modernize`가 없음 | Customize에서 마켓플레이스와 실제 설치/활성화, 조직 정책을 확인합니다. 새 세션/앱 재시작이 필요할 수 있습니다. |
| .NET `Upgrade`가 없음 | `microsoft/upgrade-agent-plugins`의 `upgrade-agent` 설치를 확인합니다. Modernization만 설치했다고 Upgrade가 생기지는 않습니다. |
| CLI 전용 안내가 보임 | 이 워크샵은 app의 Customize/Agent picker를 사용합니다. CLI나 VS Code 작업 흐름으로 임의 전환하지 않습니다. |
| 앱을 못 찾음 | app에 연 폴더가 `pom.xml` 또는 실제 `.sln`/`.csproj`가 있는 앱 루트인지 확인합니다. |
| 평가가 오래 걸리거나 중단됨 | 로그의 도구 설치/네트워크/인증 실패를 확인하고 미완료 작업을 구분합니다. 전체 자동 승인을 켜서 해결하지 않습니다. |
| MCP 인증 만료 | 실패한 서버와 이유를 확인합니다. 전역 서버는 Customize > Installed의 Sign in, 저장소 서버는 프로젝트 Repository customizations > MCP servers의 Sign in을 사용합니다. 표시되지 않으면 관리자/강사에게 상태를 알립니다. |

플러그인 버전별 UI/산출물 위치는 달라질 수 있습니다. 실제 앱 버전, 플러그인 버전과 생성 경로를 기록합니다. 인증 토큰을 채팅에 붙이거나 CLI 전용 `/mcp auth`를 app 해결책으로 사용하지 않습니다.

## Java와 .NET 로컬 실행

| 증상 | 확인과 조치 |
| --- | --- |
| Java 버전이 되돌아감 | SDKMAN `sdk use`는 현재 셸에 적용됩니다. 매 터미널/에이전트 실행 프로세스의 `java -version`과 Wrapper JDK를 확인합니다. |
| PostgreSQL/RabbitMQ 아직 준비 안 됨 | `pg_isready`, `rabbitmq-diagnostics`, 해당 컨테이너 로그를 확인합니다. 원본의 10초 대기는 readiness 보장이 아닙니다. |
| Java 포트/컨테이너 이름 충돌 | 현재 PID/컨테이너의 소유 프로젝트를 먼저 확인합니다. 다른 앱을 종료하거나 원본 start 스크립트를 반복 실행하지 않습니다. |
| Podman인데 Java 원본이 docker 호출 | [Java 실습 1](java/01-run-locally.md)의 Podman 수동 서비스/Maven 실행 경로를 사용합니다. |
| Framework 참조 어셈블리 누락 | 런타임과 별개로 **4.8 Targeting Pack**을 설치합니다. 4.8.2 다운로드를 찾거나 csproj를 임의 retarget하지 않습니다. |
| VS 2026 검사 실패 | 18.x IDE와 ASP.NET 및 웹 개발 워크로드를 확인합니다. Build Tools 단독 설치는 불충분합니다. |
| MSMQ 오류 | Windows 기능, Running 서비스, 정확한 private queue 이름/권한/트랜잭션 설정을 확인합니다. Linux로 MSMQ를 가져가지 않습니다. |
| .NET 10 SDK 검사 실패 | `dotnet --list-sdks`를 봅니다. 런타임만 설치했거나 preview만 있는 경우는 통과하지 않습니다. `global.json`도 확인합니다. |
| LocalDB/IIS Express 없음 | Visual Studio Installer 개별 구성요소를 확인합니다. 일반 SQL Server를 다른 DB에 연결해 대신 쓰지 않습니다. |
| HTTPS 인증서 경고 | 개발 인증서와 발급/신뢰 상태를 참가자가 확인해 해결합니다. 보안 경고 우회나 TLS 검증 비활성화를 기본으로 하지 않습니다. |

## 엔진, azd와 Azure

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
| `azd package` 실패 | Dockerfile 경로/컨텍스트, Java reactor 또는 .NET 프로젝트 경로, Linux base image와 디스크/메모리/엔진을 확인합니다. |
| `azd deploy`의 ACR push 실패 | 로컬 배포 사용자의 push 권한과 레지스트리 모드를 확인합니다. ABAC 모드라면 그 모드에 맞는 저장소 권한이 필요합니다. |
| 앱 image pull 실패 | ACA 관리 ID의 ACR pull 권한/registry 설정을 확인합니다. 로컬 사용자의 push 성공과는 별개입니다. |
| azd가 ACA를 못 찾음 | `azure.yaml` 서비스 이름, `azd-service-name` 태그/resourceName과 Bicep 출력 계약을 대조합니다. |
| revision이 ready가 아님 | 실제 listen port, ingress targetPort, 비루트 파일 권한, 시작/준비 probe와 콘솔/시스템 로그를 확인합니다. |
| DB 인증 실패 | Entra 관리자, DB 내부 principal과 권한을 확인합니다. ARM Contributor와 DB 로그인 권한을 구분합니다. |
| DB 연결 시간 초과 | DNS/TLS/방화벽/egress 경로를 확인합니다. ACA ingress static IP를 outbound로 사용하거나 모든 IP를 허용하지 않습니다. |
| Blob/Service Bus 403 | 앱이 쓰는 관리 ID와 데이터 plane 역할/범위를 확인하고 전파 후 제한적으로 재시도합니다. 구독 전체 권한으로 확대하지 않습니다. |
| 큐가 쌓이지만 화면은 정상 | 소비자 시작, queue 이름, 포맷, dead-letter, 재시도와 최소 replica를 확인합니다. 웹 HTTP 200은 비동기 처리 성공이 아닙니다. |
| .NET 재배포 후 쿠키/CSRF 오류 | Data Protection 공유 키, 앱 이름과 Blob 권한을 확인합니다. 임시 디스크 키 저장을 없앱니다. |
| `azd down` 실패 | 정확한 환경/그룹, resource lock과 삭제 권한을 확인합니다. 다른 그룹이나 전역 자원을 정리하지 말고 남은 리소스 ID와 비용 책임을 기록합니다. |

## 여기서 멈춰야 하는 경우

권한/비용 승인을 받지 못했거나, 원본 동작을 확인하지 못했거나, 필수 빌드/통합 검사가 실패했으면 다음 단계를 성공으로 표시하지 않습니다. 결과를 저장하고 생성한 자원을 정리한 뒤 미완료 범위와 원인을 남깁니다.

외부 Azure 통합 검사, WSL2/macOS/Podman 실기기 실행과 전체 업그레이드는 준비 스크립트의 fixture/mock 검사만으로 검증되지 않습니다. 강사는 행사 전에 사용할 OS/엔진 조합으로 리허설하고 사용한 도구/플러그인 버전을 기록해야 합니다.
