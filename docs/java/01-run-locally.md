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

아래 스크립트를 실행시켜 Java 8을 선택합니다.

```bash
# zsh/bash
source ../scripts/use-java.sh --jdk 8
```

이어서 앱 루트에서 Maven Wrapper와 전체 검증을 별도로 실행합니다.

```bash
# zsh/bash
bash ./mvnw -version && bash ./mvnw clean verify
```

> [!IMPORTANT]
>
> 검증이 실패하면 원본 상태의 문제부터 해결하고 현대화를 시작하지 않습니다.

## 로컬 서비스와 앱 실행

실습에 사용할 개인 정보가 없는 실제 PNG 이미지 파일을 준비합니다. 확장자만 바꾼 텍스트나 손상된 파일은 썸네일 처리에 실패할 수 있습니다. 개인 자료나 업무 파일은 업로드하지 않습니다. 아래는 Docker 실행 경로입니다. 대체 엔진은 [문제 해결](08-troubleshooting.md#대체-엔진-설정)을 참고합니다.

`startapp.sh`는 web과 worker를 `dev` 프로필로 실행합니다. Spring Boot 프로필은 앱에서 사용할 구현과 설정을 선택하며, 이 프로필에서는 파일을 로컬 `storage`에 저장하고 RabbitMQ로 썸네일 작업을 전달합니다.

아래 스크립트는 Docker 컨테이너를 시작한 뒤 web과 worker를 백그라운드로 실행합니다.

```bash
# zsh/bash
bash scripts/startapp.sh
```

## 현재 앱 동작 확인

브라우저에서 `http://localhost:8080`을 열고 초기 목록이 표시되는지 확인합니다. 테스트 이미지를 업로드한 뒤 화면에 업로드 결과와 썸네일이 나타나는지 확인합니다. RabbitMQ 관리 화면 `http://localhost:15672`와 worker 로그에서 메시지 처리와 썸네일 생성을 확인하고, PostgreSQL 연결은 앱 로그에서 별도로 확인합니다.

업로드한 원본 파일과 worker가 만든 썸네일은 로컬 `storage` 폴더에 저장됩니다. 웹 앱은 파일을 저장한 뒤 RabbitMQ에 썸네일 생성 메시지를 보냅니다. worker가 메시지를 처리하지 않으면 원본 업로드는 성공해도 썸네일은 나타나지 않을 수 있으므로, 업로드 완료 메시지만으로 처리가 끝났다고 판단하지 않습니다.

이 실행 경로는 이미지 메타데이터를 PostgreSQL에 저장하지 않습니다. 따라서 `storage`에 파일이 있고 화면에서 확인할 수 있어도 DB 행이 없는 것이 정상입니다. PostgreSQL 연결 로그는 앱이 설정된 DB에 연결했는지 확인하는 용도입니다. `dev` 프로필 외의 AWS S3 저장과 DB 메타데이터 처리는 [평가와 계획](02-assess-and-plan.md)에서 별도로 다룹니다.

DB나 worker가 실패한 상태에서 홈 화면만 열린 것을 성공으로 처리하지 않습니다. 원본 앱에서 오류가 발생하면 오류와 수정 내용을 기록해 두어, 이후 변경한 앱과 동작을 비교할 수 있도록 합니다.

기본 로컬 저장 폴더는 앱 루트의 `storage`입니다. `local.storage.directory`를 바꿨다면 실제 저장 경로도 확인하고 저장소 안의 생성 파일을 제외합니다. 앱 폴더에는 별도의 `.git` 저장소가 없으며, Git은 워크숍 루트 저장소를 사용합니다. 실습 생성물과 비밀이 Git에 들어가지 않도록 앱 폴더의 제외 규칙을 보완합니다.

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

업로드 파일, 로그, 인증 토큰과 연결 문자열이 포함되어 있으면 커밋하지 않습니다. 해당 파일을 스테이징에서 제외하고 제외 규칙을 보완한 뒤 다시 확인합니다. 검토를 마치면 Java 8 샘플의 현재 상태를 커밋합니다.

```bash
git commit -m "Baseline: verified Java 8 sample"
```

Git 사용자 이름이나 이메일이 설정되지 않아 커밋이 거부되면, 이 저장소에서 사용할 이름과 이메일을 설정합니다. 아래 명령은 이 저장소에만 적용되며, 스크립트가 대신 설정하지 않습니다.

```bash
# zsh/bash
git config user.name "Your Name"
git config user.email "you@example.com"
```

이제 Copilot app에 앱 루트를 추가하고 작업 세션을 만듭니다. Windows에서는 Windows 경로로 앱 폴더를 열되 WSL2에서 같은 폴더를 참조하는 경로를 확인합니다. 에이전트 실행 환경과 작업 디렉터리를 확인하고, 원본을 실행하던 세션과 다른 복사본을 수정하지 않도록 합니다.

## 완료 기준과 문제 해결

Java 8 빌드, 웹/worker와 DB/큐의 연결, 업로드의 실제 결과를 확인했고 기준선 커밋이 있어야 합니다. 포트나 컨테이너 이름 충돌은 [문제 해결](08-troubleshooting.md)을 참고합니다. 업그레이드 전 실행 프로세스를 정지하는 방법은 [정리](07-cleanup.md)의 로컬 항목을 따릅니다. DB/큐는 다음 실습에 필요하므로 아직 삭제하지 않아도 됩니다.
