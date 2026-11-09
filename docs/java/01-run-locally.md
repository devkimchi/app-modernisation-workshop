# Java 1. 원본 앱을 로컬에서 실행하기

[목차](README.md) | [이전: 공통 준비](../setup.md) | [다음: 평가와 계획](02-assess-and-plan.md) | [정리](07-cleanup.md)

## 목표와 시작 조건

업그레이드 전에 Java 8 원본의 동작을 확인하고 비교 기준을 남깁니다. 사전 점검과 다운로드가 통과했으며 `pom.xml`, `web`, `worker`, `mvnw`, `.mvn`이 있어야 합니다.

실행 위치는 **앱 루트 `java`**, 셸은 **WSL2/macOS Bash**입니다. 사용자 지정 경로를 선택했다면 그 경로로 이동합니다.

## JDK 8과 빌드 확인

```bash
cd java
source "${SDKMAN_DIR:-$HOME/.sdkman}/bin/sdkman-init.sh"
sdk list java
sdk use java <설치한-JDK-8-식별자>
java -version
javac -version
bash ./mvnw -version
bash ./mvnw clean verify
```

`<...>`는 출력에서 확인한 실제 값으로 바꾸고 실행합니다. Java/Maven 실행 JDK가 모두 8이어야 합니다. 최초 Wrapper 실행은 Maven과 의존성을 내려받습니다. 빌드가 실패하면 원본 상태의 문제부터 해결하고 현대화를 시작하지 않습니다.

## 로컬 서비스와 앱 실행

실습에 사용할 가짜 이미지 파일을 준비합니다. 개인 자료나 업무 파일은 업로드하지 않습니다. 아래 두 경로 중 선택한 엔진의 경로만 실행합니다.

### Docker

```bash
docker ps -a --filter name=assets-postgres --filter name=assets-rabbitmq
bash scripts/startapp.sh
docker exec assets-postgres pg_isready -U postgres -d assets_manager
docker exec assets-rabbitmq rabbitmq-diagnostics -q ping
tail -n 40 logs/web.log logs/worker.log
```

같은 이름의 컨테이너가 이미 있으면 먼저 본인 실습 리소스인지 확인합니다. 원본 스크립트는 Docker를 하드코딩하고 `postgres:latest`, `rabbitmq:management`를 사용합니다. 이 태그의 실제 이미지 ID를 기록하세요. 시작 메시지와 고정 10초 대기만으로 서비스 준비를 판단하지 않습니다.

원본 스크립트의 DB/큐 포트는 모든 인터페이스에 바인딩될 수 있습니다. 신뢰할 수 있는 개인 실습 환경에서만 실행하고 로컬 방화벽을 확인합니다. 공유 장비라면 아래 Podman 절차의 명령을 `docker`로 바꿔 루프백에만 바인딩하는 수동 실행 경로를 사용합니다.

### Podman

원본 `startapp.sh`/`stopapp.sh`는 실행하지 않습니다. 전역 `docker=podman` alias를 만들거나 원본 스크립트를 수정할 필요가 없습니다.

```bash
podman ps -a --filter name=assets-postgres --filter name=assets-rabbitmq
podman run -d --name assets-postgres \
  -e POSTGRES_DB=assets_manager -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres \
  -p 127.0.0.1:5432:5432 docker.io/library/postgres:latest
podman run -d --name assets-rabbitmq \
  -p 127.0.0.1:5672:5672 -p 127.0.0.1:15672:15672 docker.io/library/rabbitmq:management
podman exec assets-postgres pg_isready -U postgres -d assets_manager
podman exec assets-rabbitmq rabbitmq-diagnostics -q ping
```

`postgres/postgres`와 RabbitMQ 기본 계정은 원본과 맞추기 위한 **로컬 데모 전용**입니다. 클라우드에서 재사용하지 않습니다. 두 상태 확인 명령이 성공한 뒤, 앱 루트를 기준으로 터미널 두 개에서 각각 실행합니다. 각 터미널에서 SDKMAN 초기화와 JDK 8 선택을 먼저 합니다.

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

## 기준 동작과 Git 기준선

브라우저에서 `http://localhost:8080`을 열고, 초기 목록 표시, 가짜 이미지 업로드, 업로드 결과 조회를 확인합니다. 실제 화면에서 지원하는 동작을 기준으로 사용한 입력과 결과를 기록하세요. RabbitMQ 관리 화면 `http://localhost:15672`와 worker 로그에서 메시지가 처리되는지 확인하고 DB 기록, 파일 저장, 처리 결과가 연결되는지 비교합니다.

DB나 worker가 실패한 상태에서 홈 화면만 열린 것을 성공으로 처리하지 않습니다. 원본의 장애가 있다면 오류와 수정 내용을 따로 남겨 기준선을 명확히 합니다.

실습 생성물과 비밀이 Git에 들어가지 않게 확인한 뒤 기준선 커밋을 만듭니다.

```bash
printf '\n.azure/\nlogs/\npids/\n**/target/\n**/uploads/\n.env\n.env.*\n' >> .gitignore
git status --short
git add .
git diff --cached --stat
git diff --cached
git commit -m "Baseline: verified Java 8 sample"
```

커밋 전 업로드 파일, 로그, 인증 토큰과 연결 문자열이 포함되지 않았는지 검토합니다. 사용자 이름/이메일이 없어서 커밋이 거부되면 본인이 사용할 Git 신원을 **이 저장소 범위**로 설정합니다. 스크립트가 대신 설정하지 않습니다.

이제 Copilot app에 앱 루트를 추가하고 작업 세션을 만듭니다. Windows에서는 Windows 경로로 앱 폴더를 열되 WSL2에서 같은 폴더를 참조하는 경로를 확인합니다. 에이전트 실행 환경과 작업 디렉터리를 확인하고, 원본을 실행하던 세션과 다른 복사본을 수정하지 않도록 합니다.

## 완료 기준과 문제 해결

Java 8 빌드, 웹/worker와 DB/큐의 연결, 업로드의 실제 결과를 확인했고 기준선 커밋이 있어야 합니다. 포트나 컨테이너 이름 충돌은 [문제 해결](../troubleshooting.md)을 참고합니다. 업그레이드 전 실행 프로세스를 정지하는 방법은 [정리](07-cleanup.md)의 로컬 항목을 따릅니다. DB/큐는 다음 실습에 필요하므로 아직 삭제하지 않아도 됩니다.
