# 선택형 Dev Container

이 환경은 기존 워크숍의 필수 조건이 아닙니다. Java 실습 도구와 Linux 호환 .NET 10 프로젝트의 빌드 환경을 제공합니다. Windows 전용 .NET Framework 원본, Visual Studio, IIS Express, LocalDB와 MSMQ 실습은 대체하지 않습니다.

## 시작하기

Linux 컨테이너를 실행하는 Docker, [VS Code와 Dev Containers 확장](https://code.visualstudio.com/docs/devcontainers/containers), 패키지 다운로드를 위한 네트워크가 필요합니다. 호스트와 Dev Container는 같은 CPU 아키텍처를 사용합니다. ARM 환경에서 `linux/amd64` 이미지를 빌드할 때는 Buildx와 에뮬레이션을 별도로 확인합니다.

**보안 주의:** Docker-in-Docker가 별도 데몬을 실행하기 위해 Dev Container를 privileged 모드로 시작합니다. 호스트 Docker 소켓을 마운트하지 않지만 높은 권한이므로 신뢰할 수 있는 개인 환경에서만 사용하고, 공유 장비에서는 관리자 승인을 받습니다.

1. VS Code에서 워크숍 자료 폴더를 열고 **Dev Containers: Reopen in Container**를 선택합니다.
2. 이미지 빌드와 Azure CLI `containerapp` 확장 설치가 완료되면 컨테이너의 Bash 터미널에서 다음을 확인합니다.

```bash
source "${SDKMAN_DIR:-$HOME/.sdkman}/bin/sdkman-init.sh"
sdk current java
sdk list java
dotnet --list-sdks
docker info
docker buildx version
az extension show --name containerapp --query version --output tsv
```

JDK 8이 기본이며 JDK 21과 25도 SDKMAN으로 설치됩니다. 각 터미널에서 실습에 필요한 버전을 `sdk use`로 선택합니다. 확장 설치가 실패하면 네트워크를 확인하고 `az extension add --name containerapp --upgrade`를 다시 실행합니다.

Java 사전 점검과 다운로드는 컨테이너의 워크숍 자료 폴더에서 기존 Bash 명령으로 실행합니다. Azure 로그인, 공급자 등록, Copilot 플러그인 설치와 리소스 생성은 자동으로 수행하지 않습니다. 사용자 지정 앱 경로를 쓰려면 컨테이너에서 그 경로에 접근할 수 있어야 합니다.

Windows의 Git worktree처럼 `.git`이 컨테이너 밖의 절대 경로를 가리키면 워크숍 자료 폴더에서 Git 명령이 실패할 수 있습니다. 해당 폴더에서도 Git을 사용해야 한다면 일반 복제본을 열어 사용합니다. 다운로드한 앱은 별도의 Git 저장소입니다.

## 실행 환경 확인

컨테이너 내부 Docker 엔진은 호스트 엔진과 별개이며 `AZD_CONTAINER_RUNTIME=docker`가 설정됩니다. 앱 실행과 정리는 동일한 엔진에서 수행합니다. 내부 엔진의 데이터 볼륨은 Dev Container를 중지하거나 다시 만들어도 남을 수 있으므로 삭제 전 소유자와 내용을 확인합니다. 포트 화면에서 앱 `8080`과 RabbitMQ 관리 화면 `15672`의 전달 주소를 확인하고 공개하지 않습니다.

Copilot app 세션은 Dev Container에 자동으로 연결되지 않습니다. 에이전트를 컨테이너에서 실행하려면 [사용자 지정 환경 안내](https://docs.github.com/copilot/how-tos/copilot-on-github/customize-copilot/customize-cloud-agent/create-a-custom-environment)에 따라 필요한 도구와 계정 권한을 확인하고 환경 호스트를 직접 등록한 뒤 app에서 선택합니다. 등록과 인증은 자동으로 수행하지 않습니다. Windows 호스트에서 에이전트를 실행한다면 Windows에도 Git과 Node.js 22 이상을 별도로 준비합니다. 에이전트의 앱 경로, 플러그인과 실행 환경을 확인하고 실습 프롬프트에도 실제 환경을 지정하세요.

Linux에서 .NET 10을 빌드하려면 앱이 해당 플랫폼과 호환되어야 합니다. Windows 전용 의존성이 남아 있으면 빌드나 실행이 실패할 수 있습니다.
