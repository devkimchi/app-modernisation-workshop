# Java 1. 원본 앱을 로컬에서 실행하기

[전체 목차](../../README.md) | [Java 목차](README.md) | [이전: 준비](00-setup.md) | [다음: 평가와 계획](02-assess-and-plan.md) | [문제 해결](08-troubleshooting.md)

## 목표와 사전 준비

업그레이드에 앞서 Java 8 원본 앱의 동작을 확인한 뒤, 이후 변경한 앱과 비교합니다. 사전 점검과 다운로드를 완료하고 앱 루트에 `pom.xml`, `web`, `worker`, `mvnw`, `.mvn`이 있는지 확인합니다.

워크숍 자료 루트에서 기본 다운로드 위치를 사용했다면 다음 명령으로 앱 루트(`java`)로 이동합니다.

```bash
# zsh/bash
cd java
```

이후 명령은 **앱 루트(`java`)** 에서 실행합니다.

## JDK 8과 빌드 확인

아래 스크립트를 실행해 Java 8을 선택합니다.

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
> 검증에 실패하면 원인을 해결할 때까지 현대화를 시작하지 않습니다.

## 로컬 서비스와 앱 실행

실습에는 개인 정보가 포함되지 않은 실제 PNG 파일을 사용합니다. 확장자만 바꾼 텍스트 파일이나 손상된 이미지는 썸네일을 만들지 못할 수 있습니다. 개인 자료나 업무 파일은 업로드하지 마세요.

`startapp.sh`는 웹 앱과 worker를 `dev` 프로필로 실행합니다. 이 프로필은 파일을 로컬 `storage` 폴더에 저장하고 썸네일 생성 작업을 RabbitMQ로 전달합니다.

아래 스크립트는 Docker 컨테이너를 시작한 뒤 웹 앱과 worker를 백그라운드로 실행합니다.

```bash
# zsh/bash
bash scripts/startapp.sh
```

## 현재 앱 동작 확인

다음 항목을 확인합니다.

- 브라우저에서 `http://localhost:8080`을 열어 초기 목록이 표시되는지 확인합니다.
- 테스트 이미지를 업로드하고 업로드 결과와 썸네일이 화면에 나타나는지 확인합니다.
- RabbitMQ 관리 화면(`http://localhost:15672`)에서 큐 상태를 확인합니다.
- worker 로그에서 메시지 처리와 썸네일 생성을 확인합니다.
- 앱 로그에서 PostgreSQL 연결을 확인합니다.

> [!CAUTION]
>
> `http://localhost:8080`으로 접속이 안될 수 있습니다. 이 경우에는 아래 명령어를 통해 IP주소를 직접 알아낸 후 접속해 보세요.
>
> ```bash
> hostname -I
> ```
>
> `http://<IP주소>:8080`
>
> 자세한 해결 방법은 [문제 해결 문서의 "Windows에서 localhost:8080에 연결할 수 없음" 절](08-troubleshooting.md#windows에서-localhost8080에-연결할-수-없음)을 참고하세요.

웹 앱은 업로드한 원본 파일을 로컬 `storage` 폴더에 저장한 뒤 RabbitMQ에 썸네일 생성 메시지를 보냅니다. worker가 메시지를 처리하지 않으면 원본 파일은 저장되어도 썸네일이 생성되지 않을 수 있습니다. 업로드 완료 메시지만으로 처리가 끝났다고 판단하지 마세요.

`dev` 프로필로 실행하면 이미지 메타데이터를 PostgreSQL에 저장하지 않습니다. 파일이 `storage` 폴더와 화면에 보여도 DB에 행이 없는 것이 정상입니다. PostgreSQL 연결 여부는 앱 로그에서 확인합니다. AWS S3 저장과 DB 메타데이터 처리는 [평가와 계획](02-assess-and-plan.md)에서 다룹니다.

DB나 worker에 오류가 있으면 홈 화면이 열리는지만으로 실행 성공 여부를 판단하지 마세요. 오류 원인을 해결한 뒤 다시 확인합니다.

기본 저장 경로는 앱 루트의 `storage` 폴더입니다. `local.storage.directory`를 변경했다면 실제 저장 경로를 확인하고, 저장소에 생성된 파일이 포함되지 않도록 제외 규칙을 보완합니다.

```bash
# zsh/bash
printf '\n.azure/\nlogs/\npids/\n/storage/\n**/target/\n**/uploads/\n.env\n.env.*\n' >> .gitignore
git status --short
```

커밋할 파일을 확인한 뒤 스테이징합니다.

```bash
# zsh/bash
git add .
```

스테이징한 파일을 검토합니다.

```bash
# zsh/bash
git diff --cached --stat
git diff --cached
```

업로드 파일, 로그, 인증 토큰 또는 연결 문자열은 커밋하지 마세요. 이런 파일이 스테이징되어 있으면 제외하고, 제외 규칙을 보완한 다음 다시 확인합니다. 검토를 마치면 Java 8 원본 앱의 현재 상태를 커밋합니다.

```bash
# zsh/bash
git commit -m "Baseline: verified Java 8 sample"
```

Git 사용자 이름이나 이메일이 설정되지 않아 커밋할 수 없다면, 아래 명령으로 이 저장소에 사용할 이름과 이메일을 설정합니다. 이 설정은 이 저장소에만 적용되며, 스크립트가 대신 설정하지 않습니다.

```bash
# zsh/bash
git config user.name "Your Name"
git config user.email "you@example.com"
```

## 실행 확인 및 문제 해결

다음 단계로 넘어가기 전에 Java 8 빌드가 성공하는지, 웹 앱과 worker가 실행되는지, DB와 큐에 연결되는지, 업로드한 이미지의 썸네일이 생성되는지 확인합니다. 원본 앱의 현재 상태도 앞서 안내한 대로 커밋했는지 확인합니다.

포트나 컨테이너 이름이 충돌하면 [문제 해결](08-troubleshooting.md)을 참고합니다. 업그레이드 전에 실행 중인 프로세스를 정지하려면 [정리](07-cleanup.md)의 로컬 항목을 따릅니다. DB와 큐는 다음 실습에서도 사용하므로 지금 삭제하지 않아도 됩니다.
