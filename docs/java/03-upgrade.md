# 3. JDK 25로 업그레이드하기

[전체 목차](../../README.md) | [Java 목차](README.md) | [이전: 평가와 계획](02-assess-and-plan.md) | [다음: Azure 서비스 이전](04-migrate-azure-services.md) | [문제 해결](08-troubleshooting.md)

## 목표와 시작 조건

Copilot app 터미널의 **앱 루트**에서 `ws03-baseline`, `ws03-upgrade`를 차례로 실행합니다. 이전 web/worker 프로세스는 먼저 멈춥니다. DB/RabbitMQ가 필요한 테스트는 검토한 실행 절차로 서비스를 준비하고 원본 시작 스크립트를 무조건 반복 실행하지 않습니다.

Modernize CLI는 작업별 커밋을 만들 수 있습니다. **각 실행 직전** 기준 커밋을 기록하고 작업 트리에 무관한 변경이나 비밀이 없는지 확인합니다. 미커밋 작업은 먼저 별도로 보존합니다.

## Java 8 기준 테스트

실습 2에서 검토한 `ws03-baseline`만 실행합니다.

Windows PowerShell 7:

```powershell
. ../scripts/use-java.ps1 -Jdk 8
git status --short
$before = git rev-parse HEAD
modernize plan execute "승인한 ws03-baseline과 .github/skills/java-aca-workshop/SKILL.md를 따라 Java 8 기준 테스트만 보강하고 실행해 줘. 실패한 검사를 삭제하거나 건너뛰지 마. 업그레이드, Azure 변경과 배포는 하지 마." --source . --language java --plan-name ws03-baseline --delegate local
```

macOS와 Linux:

```bash
source ../scripts/use-java.sh --jdk 8
git status --short
before=$(git rev-parse HEAD)
modernize plan execute "승인한 ws03-baseline과 .github/skills/java-aca-workshop/SKILL.md를 따라 Java 8 기준 테스트만 보강하고 실행해 줘. 실패한 검사를 삭제하거나 건너뛰지 마. 업그레이드, Azure 변경과 배포는 하지 마." --source . --language java --plan-name ws03-baseline --delegate local
```

끝나면 아래 [실행 결과 검토](#실행-결과-검토)로 커밋과 미커밋 변경을 함께 확인합니다. 원본 런타임에서 테스트가 통과하고 DB/큐 등 외부 조건과 미실행 검사가 구분되어야 다음 계획을 만듭니다.

## JDK 25 업그레이드 계획

[Spring Boot 4.1.2 공식 요구사항](https://github.com/spring-projects/spring-boot/blob/v4.1.2/documentation/spring-boot-docs/src/docs/antora/modules/ROOT/pages/system-requirements.adoc)은 Java 17~27을 지원 범위로 설명합니다. 이것이 개별 라이브러리나 샘플의 호환성까지 보장하지는 않습니다.

다음 요구사항을 **앱 루트**의 `ws03-upgrade-input.txt`에 UTF-8로 저장합니다. 실습 2에서 기록한 실제 평가 보고서 경로도 첫 줄에 추가합니다.

```text
.github/skills/java-aca-workshop/SKILL.md, 평가 보고서와 실제 기준 테스트 결과를 읽고
JDK 25 업그레이드만 계획해 줘. 지금은 파일 변경 없이 계획만 작성해 줘.
정식 JDK 25와 Spring Boot 4.1.2를 기준으로 Spring 라이브러리, 테스트 도구,
Maven 빌드 플러그인의 호환성과 지원 조건을 확인해 줘.
다른 안정 버전이 필요하면 근거와 변경 승인을 받아 줘. EA와 유료 저장소는 쓰지 마.
중간 업그레이드가 필요하면 버전별 검증 기준과 중단/복구 조건을 명시해 줘.
javax -> jakarta, 보안 설정, 직렬화와 ORM 변경을 점검하고 기존 기능을 유지해 줘.
루트/하위 pom, compiler release, 테스트 JVM과 실행 환경의 Java 버전을 맞춰 줘.
Windows는 PowerShell 7의 . ../scripts/use-java.ps1 -Jdk 25,
macOS/Linux는 source ../scripts/use-java.sh --jdk 25를 같은 실행 셸에 적용해 줘.
Maven Wrapper clean verify와 로컬 PostgreSQL/RabbitMQ 회귀 검사를 포함하고
도구 결과와 사람이 확인할 UI 결과를 구분해 줘.
Azure 서비스 이전, 리소스 생성, DB 변경/데이터 이전과 배포는 포함하지 마.
```

Windows:

```powershell
$goal = Get-Content ./ws03-upgrade-input.txt -Raw -Encoding utf8
modernize plan create $goal --source . --language java --plan-name ws03-upgrade
```

macOS와 Linux:

```bash
goal=$(cat ws03-upgrade-input.txt)
modernize plan create "$goal" --source . --language java --plan-name ws03-upgrade
```

생성된 `plan.md`와 `tasks.json`을 함께 읽고 업그레이드 범위, 테스트, 버전과 파일 목록을 승인합니다. 아직 준비되지 않은 JDK의 자동 설치를 묵시적으로 승인하지 않습니다.

## 승인한 업그레이드 실행

Windows:

```powershell
. ../scripts/use-java.ps1 -Jdk 25
git status --short
$before = git rev-parse HEAD
modernize plan execute "승인한 ws03-upgrade와 워크숍 스킬의 업그레이드 범위만 실행해 줘. 기준 테스트를 생략하지 말고 Azure 변경과 배포는 하지 마." --source . --language java --plan-name ws03-upgrade --delegate local
./mvnw.cmd -version
./mvnw.cmd clean verify
```

macOS와 Linux:

```bash
source ../scripts/use-java.sh --jdk 25
git status --short
before=$(git rev-parse HEAD)
modernize plan execute "승인한 ws03-upgrade와 워크숍 스킬의 업그레이드 범위만 실행해 줘. 기준 테스트를 생략하지 말고 Azure 변경과 배포는 하지 마." --source . --language java --plan-name ws03-upgrade --delegate local
./mvnw -version
./mvnw clean verify
```

각 명령의 결과를 확인하고 실패하면 다음 명령으로 진행하지 않습니다. Windows는 `$LASTEXITCODE`, macOS와 Linux는 명령 직후 `echo $?`를 확인합니다. 다른 프로세스의 JDK 선택은 현재 터미널에 자동 적용되지 않습니다.

생성/수정한 로컬 실행 절차에 따라 web/worker를 실행하고 실습 1의 입력을 재사용합니다. Copilot app 채팅에 Java 명령을 맡길 때도 해당 실행 셸에 위 JDK 도우미를 먼저 적용하도록 요청합니다.

## 실행 결과 검토

각 계획 실행 직전 저장한 `$before`를 같은 터미널에서 사용합니다. 아래 Git 명령은 PowerShell과 Bash/Zsh에서 모두 실행할 수 있습니다.

```text
git status --short
git log --oneline "$before..HEAD"
git diff --stat "$before..HEAD"
git diff "$before..HEAD"
git diff
git diff --cached
```

`git diff`가 비어 있어도 자동 커밋에 변경이 있을 수 있습니다. 앱 밖의 파일, 비밀과 무관한 변경까지 확인합니다. CLI가 커밋하지 않은 변경만 범위를 검토해 별도로 커밋하며 `git add .`를 무조건 반복하지 않습니다.

## 완료 기준과 문제 해결

최종 Maven/컴파일/실행 JVM이 모두 25이고 루트 빌드와 기존 기능이 통과해야 합니다. Boot 버전만 바뀌거나 테스트를 제외한 패키징만 성공한 것은 완료가 아닙니다. 실패한 단계에서 멈춰 [문제 해결](08-troubleshooting.md)을 확인하고 `reset --hard`로 미검토 변경을 삭제하지 않습니다.
