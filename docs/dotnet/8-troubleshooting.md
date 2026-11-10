# .NET 문제 해결

[전체 목차](../../README.md) | [.NET 목차](README.md)

## 먼저 오류 위치를 구분하기

오류가 난 명령, 실행 폴더/셸, 트랙, 선택 엔진, 종료 코드와 **비밀을 제거한** 오류를 기록합니다. 코드 수정 전 원본 문제인지, 업그레이드 후 회귀인지, Azure 권한/네트워크 문제인지 구분합니다. 설치/인증/배포 문제를 한 번에 해결하려고 관리자 권한이나 전체 네트워크 개방을 사용하지 않습니다.

## 사전 점검과 다운로드

| 증상 | 확인과 조치 |
| --- | --- |
| PowerShell 7 또는 WSL2 플랫폼 누락 | 두 항목이 모두 필요합니다. `powershell.exe -File ./scripts/install-prerequisites.ps1 -Track dotnet`으로 시작하면 누락된 항목마다 별도 동의를 받습니다. WSL2는 관리자 권한/Windows 기능 변경/재부팅이 필요할 수 있습니다. 안내에 따라 직접 재부팅하고 다시 실행하세요. .NET 원본은 계속 Windows에서 실행하며 배포판은 필수가 아닙니다. |
| `pwsh`를 찾을 수 없음 | Windows PowerShell 5.1에서 `.ps1`을 실행하면 기본 설치 경로와 갱신된 PATH에서도 PowerShell 7을 찾습니다. 발견하지 못하면 설치 안내와 함께 종료합니다. 위 설치 도우미로 준비하거나 PowerShell 7 설치 후 새 터미널을 엽니다. |
| `MANUAL`인데 종료 코드 0 | 수동 항목은 미검증입니다. Copilot 권한, 플러그인, RBAC/쿼터를 직접 확인합니다. |
| 스크립트 실행 권한/인코딩/줄바꿈 | `pwsh -File` 또는 Windows PowerShell 5.1의 `powershell.exe -File`로 시작합니다. 실제 작업은 PowerShell 7입니다. `.ps1`은 5.1 파서를 위해 UTF-8 BOM과 LF를 유지합니다. Git Bash 진입점은 `bash scripts/...sh`로 실행합니다. 임의로 시스템 실행 정책을 완화하지 않습니다. |
| 엔진 인자 충돌 | `AZD_CONTAINER_RUNTIME`과 `-ContainerEngine`/`--container-engine`을 같은 값으로 맞춥니다. |
| 다운로드 대상이 비어 있지 않음 | 기존 파일을 보존하고 다른 빈 폴더를 지정합니다. 숨김 파일과 `.git`도 기존 내용입니다. |
| 보호 경로/심볼릭 링크/junction 오류 | 워크숍 문서, 홈/루트가 아닌 실제 일반 디렉터리를 선택합니다. 자동 삭제로 우회하지 않습니다. |
| Git fetch/프록시/인증서 오류 | 회사 프록시와 인증서 체인을 정상 설정하고 고정 SHA 접근을 확인합니다. SSL 검증을 끄지 않습니다. |
| 다운로드 도중 디스크 오류 | 실패한 대상의 내용을 확인하고 새 빈 경로로 재시도합니다. `.workshop-download-*`는 고유 임시 경로지만 다른 실행이 사용 중인지 확인 없이 일괄 삭제하지 않습니다. |

다운로드의 필수 파일 오류를 해결하려고 `main` 최신 커밋으로 자동 전환하지 않습니다. 자료에 고정된 SHA 변경은 원본 차이와 실행 절차를 다시 검토해야 합니다.

## 사전 준비 수동 복구

점검과 설치 도우미의 조치를 거부했거나 실패한 경우에만 아래에서 필요한 항목을 수행합니다. Windows PowerShell 7에서 실행합니다. 조치 후 같은 환경에서 사전 점검을 다시 실행하세요.

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

공급자 등록 실패 시 **대상 구독과 등록 권한을 먼저 확인**하고, 오류에 표시된 미등록 공급자만 아래 명령으로 등록합니다. 구독 설정이 변경되며 `--wait`는 시간이 걸릴 수 있습니다.

```text
az provider register --namespace "<미등록-공급자>" --wait
az provider show --namespace "<미등록-공급자>" --query registrationState --output tsv
```

공통 대상은 `Microsoft.App`, `Microsoft.OperationalInsights`, `Microsoft.Storage`, `Microsoft.ContainerRegistry`, `Microsoft.ServiceBus`입니다. .NET에는 `Microsoft.Sql`도 필요합니다. VNet/Private Endpoint를 추가하면 `Microsoft.Network` 등 추가 공급자를 배포 계획에 맞춰 확인합니다. 공급자 등록이나 로그인 성공이 역할 할당, 데이터베이스 Entra 관리자 지정 또는 DB 내부 사용자 생성 권한까지 보장하지는 않습니다.

### .NET 빌드 구성요소

기본 MSBuild만으로는 원본 웹 프로젝트를 빌드할 수 없습니다. Visual Studio Installer에서 IDE의 `Microsoft.VisualStudio.Workload.NetWeb` 또는 Build Tools의 `Microsoft.VisualStudio.Workload.WebBuildTools`를 준비하세요. 설치본에 다음 파일이 있어야 합니다.

- `MSBuild/Current/Bin/MSBuild.exe`
- `MSBuild/Microsoft/VisualStudio/v17.0` 또는 `v18.0` 아래의 `WebApplications/Microsoft.WebApplication.targets`

IIS Express에는 실행 파일뿐 아니라 `AppServer/applicationhost.config` 템플릿도 필요합니다. 원본은 전체 Framework MSBuild와 IIS Express로 빌드하고 실행하며, `dotnet build`/`dotnet run`으로 대체하지 않습니다.

원본 README의 "4.8.2" 표기와 달리 고정 커밋의 프로젝트 대상은 `v4.8`입니다. **4.8 이상 런타임과 4.8 참조 어셈블리**를 각각 준비합니다. 4.8.1 런타임만으로는 4.8 Targeting Pack을 대체할 수 없습니다. [공식 버전 확인 안내](https://learn.microsoft.com/dotnet/framework/migration-guide/how-to-determine-which-versions-are-installed)를 따르고, "4.8.2 설치 파일"을 임의 사이트에서 받지 마세요.

## Copilot app과 플러그인

| 증상 | 확인과 조치 |
| --- | --- |
| `modernize`가 없음 | Customize에서 마켓플레이스와 실제 설치/활성화, 조직 정책을 확인합니다. 새 세션/앱 재시작이 필요할 수 있습니다. |
| .NET `Upgrade`가 없음 | `microsoft/upgrade-agent-plugins`의 `upgrade-agent` 설치를 확인합니다. Modernization만 설치했다고 Upgrade가 생기지는 않습니다. |
| CLI 전용 안내가 보임 | 이 워크숍은 app의 Customize/Agent picker를 사용합니다. CLI나 VS Code 작업 흐름으로 임의 전환하지 않습니다. |
| 앱을 못 찾음 | app에 연 폴더가 실제 `.sln`/`.csproj`가 있는 앱 루트인지 확인합니다. |
| 평가가 오래 걸리거나 중단됨 | 로그의 도구 설치/네트워크/인증 실패를 확인하고 미완료 작업을 구분합니다. 전체 자동 승인을 켜서 해결하지 않습니다. |
| MCP 인증 만료 | 실패한 서버와 이유를 확인합니다. 전역 서버는 Customize > Installed의 Sign in, 저장소 서버는 프로젝트 Repository customizations > MCP servers의 Sign in을 사용합니다. 표시되지 않으면 관리자/강사에게 상태를 알립니다. |

플러그인 버전별 UI/산출물 위치는 달라질 수 있습니다. 실제 앱 버전, 플러그인 버전과 생성 경로를 기록합니다. 인증 토큰을 채팅에 붙이거나 CLI 전용 `/mcp auth`를 app 해결책으로 사용하지 않습니다.

## .NET 로컬 실행

| 증상 | 확인과 조치 |
| --- | --- |
| Framework 참조 어셈블리 누락 | 런타임과 별개로 **4.8 Targeting Pack**을 설치합니다. 4.8.2 다운로드를 찾거나 csproj를 임의 retarget하지 않습니다. |
| `framework-build` 검사 실패 | VS 2022/2026 IDE 또는 Build Tools를 사용할 수 있습니다. `vswhere`와 선택 설치본의 MSBuild 실행 파일, `WebApplications/Microsoft.WebApplication.targets`를 확인합니다. Build Tools에는 Web development build tools가 필요하며 기본 MSBuild만으로는 부족합니다. IDE 실행은 필요하지 않습니다. |
| MSB4019 / 웹 타깃 import 실패 | `dotnet build`가 아니라 도우미의 전체 Framework MSBuild를 사용합니다. 도우미는 해당 설치본의 `VSToolsPath`/`VisualStudioVersion`을 전달합니다. 웹 타깃 없이 프로젝트 import를 삭제해 우회하지 않습니다. |
| 패키지/HintPath 누락 | 원본은 `packages.config`이며 앱 루트의 `packages`를 참조합니다. 도우미의 `/t:Restore /p:RestorePackagesConfig=true /p:RestoreRepositoryPath=...` 성공을 먼저 확인하고 프록시/패키지 소스 오류를 해결합니다. |
| IIS Express CLI가 종료되거나 주소 접근 실패 | 장기 실행 터미널, 실행 PID와 로그를 확인합니다. 기본 CLI는 `http://localhost:58801/`이며 IDE의 HTTPS 44300과 다릅니다. 포트 충돌은 `-Port`로 해결하고 관리자 실행/URL ACL/방화벽 전역 변경으로 우회하지 않습니다. HTTP 응답 확인은 DB 초기화를 유발할 수 있습니다. |
| IIS 401 / 500.19 / 500.21 | 생성 구성의 Windows 인증(활성), 익명 인증(비활성), CLR4 Integrated 풀과 IIS Express ASP.NET 모듈을 확인합니다. Windows 통합 인증을 지원하는 로컬 브라우저를 사용하고 로그의 모듈/설정 오류를 구분합니다. 전역 인증을 풀거나 무조건 관리자 실행하지 않습니다. |
| MSMQ 오류 | Windows 기능, Running 서비스, 정확한 private queue 이름/권한/트랜잭션 설정을 확인합니다. Linux로 MSMQ를 가져가지 않습니다. |
| .NET 10 SDK 검사 실패 | `dotnet --list-sdks`를 봅니다. 런타임만 설치했거나 preview만 있는 경우는 통과하지 않습니다. `global.json`도 확인합니다. |
| LocalDB/IIS Express 없음 | Visual Studio Installer 개별 구성요소를 확인합니다. 일반 SQL Server를 다른 DB에 연결해 대신 쓰지 않습니다. |
| HTTPS 인증서 경고 | 개발 인증서와 발급/신뢰 상태를 참가자가 확인해 해결합니다. 보안 경고 우회나 TLS 검증 비활성화를 기본으로 하지 않습니다. |

## 엔진, azd와 Azure

### 대체 엔진 설정

본문은 Docker 기준입니다. Podman이 필요한 경우 [공식 설치 안내](https://podman.io/docs/installation)에 따라 설치하고 Linux 서버에 연결합니다. 기존 machine과 연결을 먼저 확인하고 필요한 경우에만 직접 생성하거나 시작합니다. 설치 도우미는 컨테이너 엔진을 자동 설치하지 않습니다. .NET Framework 원본의 MSBuild, IIS Express, LocalDB와 MSMQ 실행은 계속 Windows에서 진행합니다.

엔진 선택은 명시 인자, `AZD_CONTAINER_RUNTIME`, 기본값 `docker` 순서입니다. 인자와 환경 변수가 다르면 오류가 발생하고, 선택한 엔진이 멈춰도 다른 엔진으로 전환하지 않습니다. Podman machine 목록만으로 현재 연결된 엔진을 판단하지 말고 `podman info`와 연결 설정을 함께 확인하세요. Docker 호환 대체 제품은 Linux 실행, `linux/amd64` 빌드, 포트 접근과 ACR 게시까지 직접 확인한 경우에만 조건부로 사용합니다.

**Windows PowerShell 7의 워크숍 루트**에서 다음과 같이 설정합니다. 환경 변수는 실습할 PowerShell마다 필요하며 스크립트가 부모 셸을 변경하지 않습니다.

```powershell
$env:AZD_CONTAINER_RUNTIME = 'podman'
pwsh -File ./scripts/check-prerequisites.ps1 -Track dotnet -ContainerEngine podman
pwsh -File ./scripts/install-prerequisites.ps1 -Track dotnet -ContainerEngine podman
pwsh -File ./scripts/download-sample.ps1 -Track dotnet -ContainerEngine podman
```

설치 도우미는 누락된 도구가 있을 때만 필요한 항목을 직접 승인해 실행합니다. 다운로드는 점검을 통과한 뒤 한 번만 수행합니다. Windows Git Bash 진입점을 사용한다면 그 셸에서도 `export AZD_CONTAINER_RUNTIME=podman`을 설정하고 각 Bash 명령의 `--container-engine docker`를 `--container-engine podman`으로 바꿉니다.

앱 루트에서 인프라를 준비하거나 배포할 때도 프롬프트의 Docker 엔진 요구를 Podman으로 바꾸고 `$env:AZD_CONTAINER_RUNTIME = 'podman'`을 유지합니다. 문서의 컨테이너 명령은 `docker` 대신 `podman`으로 실행하되 Dockerfile, `remoteBuild: false`와 로컬 빌드 원칙은 유지합니다. Docker의 `docker buildx`와 Podman의 내장 `podman build`는 구분해야 하며, Podman에는 Docker Buildx가 필요하지 않습니다. `azd`는 1.37.3 이상을 사용합니다.

정리는 실습에 사용한 동일 엔진에서 컨테이너/이미지의 이름, 생성 시점과 소유 프로젝트를 확인한 뒤 개별 수행합니다. 다른 프로젝트의 자원, 전체 `system prune`, 모든 볼륨과 Podman machine 삭제는 금지합니다. Windows 앱 프로세스는 [정리](07-cleanup.md)처럼 확인한 정확한 PID만 종료합니다.

### 엔진과 배포 오류

| 증상 | 확인과 조치 |
| --- | --- |
| Docker CLI는 있지만 연결 실패 | Desktop 실행/Linux 모드/context을 확인합니다. 점검 스크립트는 서버를 시작하지 않습니다. |
| Podman 연결 실패 | 실제 server/machine/connection을 확인합니다. 필요할 때만 직접 machine을 시작하고 WSL과 Windows 엔진을 혼동하지 않습니다. |
| Podman에서 Buildx가 없음 | 정상입니다. 내장 `podman build`를 사용합니다. `azd` 1.37.3 이상과 `AZD_CONTAINER_RUNTIME=podman`을 확인합니다. |
| `az` 로그인은 되지만 `azd` 실패 | `azd auth login`을 별도로 수행합니다. tenant, 구독과 선택 환경을 확인합니다. |
| `MissingSubscriptionRegistration` | 오류의 공급자를 확인하고 본인 구독에서 필요한 등록만 승인해 수행합니다. 추가 네트워크 리소스는 별도 공급자가 필요할 수 있습니다. |
| 리전/SKU/쿼터 실패 | 실제 선택 서비스의 가용성과 구독 쿼터를 확인합니다. 다른 리전/SKU로 바꾸면 비용과 네트워크 계획을 다시 승인합니다. |
| ACR Tasks/`az acr build` 제한 | 자료의 기본은 로컬 빌드입니다. `remoteBuild: false`와 선택 엔진을 확인합니다. 무료 구독 제한을 권한 우회로 해결하지 않습니다. |
| `azd package` 실패 | Dockerfile 경로/컨텍스트, .NET 프로젝트 경로, Linux base image와 디스크/메모리/엔진을 확인합니다. |
| `azd deploy`의 ACR push 실패 | 로컬 배포 사용자의 push 권한과 레지스트리 모드를 확인합니다. ABAC 모드라면 그 모드에 맞는 저장소 권한이 필요합니다. |
| 앱 image pull 실패 | ACA 관리 ID의 ACR pull 권한/registry 설정을 확인합니다. 로컬 사용자의 push 성공과는 별개입니다. |
| azd가 ACA를 못 찾음 | `azure.yaml` 서비스 이름, `azd-service-name` 태그/resourceName과 Bicep 출력 계약을 대조합니다. |
| revision이 ready가 아님 | 실제 listen port, ingress targetPort, 비루트 파일 권한, 시작/준비 probe와 콘솔/시스템 로그를 확인합니다. |
| DB 인증 실패 | Entra 관리자, DB 내부 principal과 권한을 확인합니다. ARM Contributor와 DB 로그인 권한을 구분합니다. |
| DB 연결 시간 초과 | DNS/TLS/방화벽/egress 경로를 확인합니다. ACA ingress static IP를 outbound로 사용하거나 모든 IP를 허용하지 않습니다. |
| Blob/Service Bus 403 | 앱이 쓰는 관리 ID와 데이터 평면 역할 및 범위를 확인하고 전파 후 제한적으로 재시도합니다. 구독 전체 권한으로 확대하지 않습니다. |
| 큐가 쌓이지만 화면은 정상 | 소비자 시작, queue 이름, 포맷, dead-letter, 재시도와 최소 replica를 확인합니다. 웹 HTTP 200은 비동기 처리 성공이 아닙니다. |
| .NET 재배포 후 쿠키/CSRF 오류 | Data Protection 공유 키, 앱 이름과 Blob 권한을 확인합니다. 임시 디스크 키 저장을 없앱니다. |
| `azd down` 실패 | 정확한 환경/그룹, resource lock과 삭제 권한을 확인합니다. 다른 그룹이나 전역 자원을 정리하지 말고 남은 리소스 ID와 비용 책임을 기록합니다. |

## 여기서 멈춰야 하는 경우

권한/비용 승인을 받지 못했거나, 원본 동작을 확인하지 못했거나, 필수 빌드/통합 검사가 실패했으면 다음 단계를 성공으로 표시하지 않습니다. 결과를 저장하고 생성한 자원을 정리한 뒤 미완료 범위와 원인을 남깁니다.

외부 Azure 통합 검사, Windows/Podman 실기기 실행과 전체 업그레이드는 준비 스크립트의 fixture/mock 검사만으로 검증되지 않습니다. 강사는 행사 전에 사용할 OS/엔진 조합으로 리허설하고 사용한 도구/플러그인 버전을 기록해야 합니다.
