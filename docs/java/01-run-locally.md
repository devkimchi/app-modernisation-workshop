# Java 1. 원본 앱을 로컬에서 실행하기

[전체 목차](../../README.md) | [Java 목차](README.md) | [이전: 준비](00-setup.md) | [다음: 평가와 계획](02-assess-and-plan.md) | [문제 해결](08-troubleshooting.md)

## 목표와 시작 조건

업그레이드 전에 Java 8 원본의 동작을 확인하고 비교 기준을 남깁니다. 사전 점검과 다운로드가 통과했으며 `pom.xml`, `web`, `worker`, `mvnw`, `.mvn`이 있어야 합니다.

워크숍 자료 루트에 있고 기본 다운로드 위치를 사용했다면 다음 명령으로 앱 루트(`java`)로 이동합니다.

```bash
# zsh/bash
cd java
```

이후 명령은 **앱 루트(`java`)** 에서 실행합니다.

## JDK 8과 빌드 확인

```bash
# zsh/bash
source ../scripts/use-java.sh --jdk 8
```

이 스크립트는 현재 셸에서 Java 8을 선택하고 `java -version`, `javac -version` 결과를 표시합니다. 사용자 지정 경로에 샘플을 다운로드했다면 스크립트 경로를 워크숍 저장소 위치에 맞게 바꾸세요. 이어서 앱 루트에서 Maven Wrapper와 전체 검증을 별도로 실행합니다. Java/Maven 실행 JDK가 모두 8이어야 합니다. 최초 Wrapper 실행은 Maven과 의존성을 내려받습니다. 검증이 실패하면 원본 상태의 문제부터 해결하고 현대화를 시작하지 않습니다.

```bash
bash ./mvnw -version
bash ./mvnw clean verify
```

## 로컬 서비스와 앱 실행

실습에 사용할 개인 정보가 없는 실제 PNG 이미지 파일을 준비합니다. 확장자만 바꾼 텍스트나 손상된 파일은 썸네일 처리에 실패할 수 있습니다. 개인 자료나 업무 파일은 업로드하지 않습니다. 아래는 Docker 실행 경로입니다. 대체 엔진은 [문제 해결](08-troubleshooting.md#대체-엔진-설정)을 참고합니다.

### Docker

```bash
docker ps -a --filter name=assets-postgres --filter name=assets-rabbitmq
```

같은 이름의 컨테이너가 이미 있으면 소유 프로젝트를 확인하고 이름 충돌을 해결한 뒤 진행합니다. 다른 프로젝트의 컨테이너를 임의로 중지하거나 삭제하지 않습니다.

원본 스크립트는 Docker를 하드코딩하고 `postgres:latest`, `rabbitmq:management`를 사용합니다. 이 태그의 실제 이미지 ID를 기록하세요. 시작 메시지와 고정 10초 대기만으로 서비스 준비를 판단하지 않습니다.

원본 스크립트의 DB/큐 포트는 모든 인터페이스에 바인딩될 수 있습니다. 신뢰할 수 있는 개인 실습 환경에서만 실행하고 로컬 방화벽을 확인합니다. 공유 장비라면 아래 스크립트를 실행하지 말고 [문제 해결의 루프백 수동 실행](08-troubleshooting.md#루프백-수동-실행)에서 Docker 경로를 사용합니다.

```bash
bash scripts/startapp.sh
```

```bash
docker exec assets-postgres pg_isready -U postgres -d assets_manager
docker exec assets-rabbitmq rabbitmq-diagnostics -q ping
tail -n 40 logs/web.log logs/worker.log
```

## 기준 동작과 Git 기준선

브라우저에서 `http://localhost:8080`을 열고, 초기 목록 표시, 테스트 이미지 업로드와 결과 조회를 확인합니다. 실제 화면에서 지원하는 동작을 기준으로 사용한 입력과 결과를 기록하세요. RabbitMQ 관리 화면 `http://localhost:15672`와 worker 로그에서 메시지 처리와 썸네일 생성을 확인하고, PostgreSQL 연결은 앱 로그에서 별도로 확인합니다.

원본 `dev` 프로필의 업로드 경로는 파일을 저장하고 메시지를 전송하지만 DB에 이미지 메타데이터 행을 만들지 않습니다. 따라서 업로드 후 DB 행 생성은 이 로컬 기준선의 완료 조건이 아닙니다. `dev` 외 프로필의 AWS S3와 DB 메타데이터 구현은 [평가와 계획](02-assess-and-plan.md)에서 별도로 다룹니다.

DB나 worker가 실패한 상태에서 홈 화면만 열린 것을 성공으로 처리하지 않습니다. 원본의 장애가 있다면 오류와 수정 내용을 따로 남겨 기준선을 명확히 합니다.

기본 `dev` 저장 폴더는 앱 루트의 `storage`입니다. `local.storage.directory`를 바꿨다면 실제 저장 경로도 확인하고 저장소 안의 생성 파일을 제외합니다. 앱 폴더에는 별도의 `.git` 저장소가 없으며, Git은 워크숍 루트 저장소를 사용합니다. 실습 생성물과 비밀이 Git에 들어가지 않도록 앱 폴더의 제외 규칙을 보완합니다.

```bash
printf '\n.azure/\nlogs/\npids/\n/storage/\n**/target/\n**/uploads/\n.env\n.env.*\n' >> .gitignore
git status --short
```

변경할 파일을 확인하고 스테이징합니다.

```bash
git add .
```

스테이징된 내용을 검토합니다.

```bash
git diff --cached --stat
git diff --cached
```

업로드 파일, 로그, 인증 토큰과 연결 문자열이 포함되어 있으면 커밋하지 않습니다. 해당 파일을 스테이징에서 제외하고 제외 규칙을 보완한 뒤 다시 확인합니다. 검토가 끝난 후 기준선 커밋을 만듭니다.

```bash
git commit -m "Baseline: verified Java 8 sample"
```

사용자 이름/이메일이 없어서 커밋이 거부되면 본인이 사용할 Git 신원을 **워크숍 저장소 범위**로 설정합니다. 스크립트가 대신 설정하지 않습니다.

이제 Copilot app에 앱 루트를 추가하고 작업 세션을 만듭니다. Windows에서는 Windows 경로로 앱 폴더를 열되 WSL2에서 같은 폴더를 참조하는 경로를 확인합니다. 에이전트 실행 환경과 작업 디렉터리를 확인하고, 원본을 실행하던 세션과 다른 복사본을 수정하지 않도록 합니다.

## 완료 기준과 문제 해결

Java 8 빌드, 웹/worker와 DB/큐의 연결, 업로드의 실제 결과를 확인했고 기준선 커밋이 있어야 합니다. 포트나 컨테이너 이름 충돌은 [문제 해결](08-troubleshooting.md)을 참고합니다. 업그레이드 전 실행 프로세스를 정지하는 방법은 [정리](07-cleanup.md)의 로컬 항목을 따릅니다. DB/큐는 다음 실습에 필요하므로 아직 삭제하지 않아도 됩니다.
