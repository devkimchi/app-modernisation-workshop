# 1. 원본 앱을 로컬에서 실행하기

[전체 목차](../../README.md) | [Java 목차](README.md) | [이전: 준비](00-setup.md) | [다음: 평가와 계획](02-assess-and-plan.md) | [문제 해결](08-troubleshooting.md)

## 목표

Java 8 원본을 빌드하고 이미지 업로드와 비동기 썸네일 생성을 확인합니다. 이 결과가 업그레이드 후 비교 기준입니다.

## 사전 준비

앞 단계에서 사용한 Copilot app 세션의 터미널에서 **앱 루트**(`java` 디렉토리)로 이동합니다.

```bash
cd java
```

앱 루트에 `pom.xml`, `web`, `worker`, `mvnw`, `mvnw.cmd`, `.mvn`이 있는지 확인합니다.

```bash
# zsh/bash
ls -al
```

```powershell
# PowerShell
dir
```

현재 Git 브랜치와 파일 변경 사항을 확인합니다.

```bash
git branch --show-current
git status --short
```

## JDK 8과 빌드 확인

Windows PowerShell 7:

```powershell
. ../scripts/use-java.ps1 -Jdk 8
./mvnw.cmd -version
./mvnw.cmd clean verify
```

macOS와 Linux의 Bash 또는 Zsh:

```bash
source ../scripts/use-java.sh --jdk 8
./mvnw -version
./mvnw clean verify
```

JDK 도우미는 현재 셸의 `JAVA_HOME`과 `PATH`만 바꿉니다. Java/Javac와 Maven이 모두 8을 사용하는지 확인합니다. 빌드 실패 시 현대화를 시작하지 않습니다.

Copilot app 채팅에 빌드를 맡긴다면 다음 조건을 함께 전달합니다. 앱 대화의 실행 프로세스가 터미널의 JDK 선택을 자동으로 상속하지는 않습니다.

Windows용:

```text
이 세션의 실제 java 앱 루트에서 원본을 빌드해 줘. 소스나 런타임은 바꾸지 마.
PowerShell 7에서 . ../scripts/use-java.ps1 -Jdk 8을 먼저 적용하고
./mvnw.cmd를 사용해 줘.
같은 셸에서 버전과 clean verify 결과를 기록해 줘. 설치는 별도 승인을 받아 줘.
```

macOS와 Linux용:

```text
이 세션의 실제 java 앱 루트에서 원본을 빌드해 줘. 소스나 런타임은 바꾸지 마.
Bash 또는 Zsh에서 source ../scripts/use-java.sh --jdk 8을 먼저 적용하고
./mvnw를 사용해 줘.
같은 셸에서 버전과 clean verify 결과를 기록해 줘. 설치는 별도 승인을 받아 줘.
```

## 로컬 서비스와 앱 실행

개인 정보가 없는 실제 PNG 파일을 준비합니다. 확장자만 바꾼 텍스트나 손상된 이미지는 사용하지 않습니다. 원본 시작 스크립트는 Docker 컨테이너를 만들고 web/worker를 `dev` 프로필로 실행합니다. 파일은 로컬 `storage`에 저장하고 RabbitMQ로 썸네일 작업을 보냅니다.

기존 `assets-postgres`, `assets-rabbitmq`와 포트 충돌 여부를 먼저 확인합니다. 공유 장비 또는 Podman 사용자는 [루프백 수동 실행](08-troubleshooting.md#루프백-수동-실행)을 사용합니다. 원본 스크립트는 `docker` 명령을 호출하므로 Podman만 설치한 환경에서 그대로 실행하지 않습니다.

Windows:

```powershell
./scripts/startapp.cmd
```

macOS와 Linux:

```bash
./scripts/startapp.sh
```

샘플 `.sh`는 자체 shebang인 `#!/bin/bash`로 실행됩니다. Windows에서는 **Web Module**, **Worker Module**이라는 별도 `cmd` 창이 열리며 해당 창에서 로그를 확인합니다.

## 현재 앱 동작 확인

브라우저에서 `http://localhost:8080`을 열고 다음을 확인합니다.

- 테스트 이미지를 업로드하고 원본과 썸네일이 화면에 표시되는지 확인합니다.
- RabbitMQ 관리 화면 `http://localhost:15672`에서 로컬 데모 계정 `guest`/`guest`로 로그인합니다. **Queues and Streams**의 `image-processing` 큐에서 Ready, Unacked, Consumers를 확인합니다.
- Ready가 0이라는 사실만으로 성공을 판단하지 않습니다. worker의 `Successfully generated thumbnail` 로그와 실제 썸네일을 함께 확인합니다.
- web 로그의 `HikariPool-1 - Start completed`와 이후 오류를 확인합니다. 시작 시 연결 성공이 현재 DB 연결까지 보장하지는 않습니다.
- `dev` 업로드는 DB에 이미지 메타데이터를 기록하지 않습니다. 화면과 `storage`에 파일이 있어도 DB에 행이 없는 것이 정상입니다. `dev` 외 S3 경로의 메타데이터는 다음 평가 단계에서 구분합니다.

macOS와 Linux에서는 앱 루트의 로그를 확인합니다.

```bash
tail -n 100 logs/worker.log
grep -n -F 'HikariPool-1 - Start completed' logs/web.log
grep -inE -C 3 'error|exception|connection refused|connection timed out' logs/web.log
```

Windows의 원본 `.cmd`는 각 창에 로그를 표시합니다. 별도로 로그 파일을 저장한 경우에만 실제 경로로 다음을 실행합니다.

```powershell
Get-Content "<worker-로그-경로>" -Tail 100
Select-String -Path "<web-로그-경로>" -SimpleMatch 'HikariPool-1 - Start completed'
Select-String -Path "<web-로그-경로>" -Pattern 'error|exception|connection refused|connection timed out' -Context 3,3
```

홈 화면이나 업로드 완료 메시지만으로 비동기 처리가 끝났다고 판단하지 않습니다. DB 또는 worker 오류가 있으면 해결 후 다시 확인합니다.

## 로컬 앱 종료

시작 스크립트로 만든 프로세스와 컨테이너인지 확인한 뒤, **앱 루트**에서 해당 종료 스크립트를 실행합니다. 종료 스크립트의 컨테이너 정리 범위를 먼저 읽습니다.

Windows:

```powershell
./scripts/stopapp.cmd
```

macOS와 Linux:

```bash
./scripts/stopapp.sh
```

Windows의 Web Module과 Worker Module 프로세스가 끝났는지 확인하고 남은 창은 직접 닫습니다. PID 파일이 없거나 종료에 실패했다면 [문제 해결](08-troubleshooting.md)을 따르고 모든 Java 프로세스를 이름으로 종료하지 않습니다.

## 원본 앱 상태 커밋

개인 실습 복제본의 기준선을 기록합니다. 앱 폴더 안에 별도 `.git`을 만들지 않습니다. 기존 제외 규칙을 보존하고 생성물과 비밀을 제외합니다. `local.storage.directory`를 바꿨다면 그 경로도 제외합니다.

Windows:

```powershell
Add-Content ./.gitignore "`n.azure/`nlogs/`npids/`n/storage/`n**/target/`n**/uploads/`n.env`n.env.*"
```

macOS와 Linux:

```bash
printf '\n.azure/\nlogs/\npids/\n/storage/\n**/target/\n**/uploads/\n.env\n.env.*\n' >> .gitignore
```

다음 명령은 두 환경에서 같습니다. `git add .`는 앱 루트에서 실행하고 스테이징된 전체 범위를 검토합니다.

```text
git status --short
git add .
git diff --cached --stat
git diff --cached
```

업로드 파일, 로그, 토큰이나 연결 비밀이 있으면 스테이징에서 제외하고 다시 검토합니다. 검토가 끝났을 때만 커밋합니다.

```text
git commit -m "Baseline: verified Java 8 sample"
```

Git 신원이 없다면 참가자가 이 저장소에만 사용할 값을 설정한 뒤 다시 커밋합니다.

```text
git config user.name "Your Name"
git config user.email "you@example.com"
```

## 완료 및 다음 단계

Java 8 빌드, web/worker 실행, PostgreSQL/RabbitMQ 연결, 업로드/썸네일과 기준선 커밋을 확인했다면 [평가와 계획](02-assess-and-plan.md)으로 이동합니다. 확인하지 못한 항목은 성공으로 표시하지 않습니다.
