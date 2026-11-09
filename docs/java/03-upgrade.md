# Java 3. JDK 21을 거쳐 JDK 25로 업그레이드하기

[목차](README.md) | [이전: 평가와 계획](02-assess-and-plan.md) | [다음: Azure 서비스 이전](04-migrate-azure-services.md) | [정리](07-cleanup.md)

## 목표와 시작 조건

Copilot app의 **`modernize`**, **앱 루트**에서 승인한 계획의 업그레이드 부분만 실행합니다. 이전 Java 앱 프로세스를 먼저 정지하고 DB와 RabbitMQ는 유지합니다. 서로 다른 JDK로 같은 포트를 사용하는 프로세스를 중복 실행하지 마세요.

## 기준 테스트와 JDK 21

```text
승인한 계획 중 로컬 기준 테스트와 JDK 21 중간 업그레이드만 실행해 줘.
먼저 Java 8에서 기존 동작을 표현하는 테스트를 추가하고 실행해 기준을 남겨 줘.
테스트가 없거나 DB/큐가 필요한 항목은 실행 조건을 명시해 줘.
그다음 Java 21과 호환되는 Spring Boot 3.x 안정 버전으로 올려 줘.
javax -> jakarta, 보안 설정, 직렬화와 ORM 변경을 점검하고 기존 기능을 유지해 줘.
SDKMAN의 설치된 JDK 21을 해당 실행 셸에 적용하고 Maven Wrapper로 빌드해 줘.
Windows에서는 앞서 지정한 WSL2 환경을 사용해 줘.
실패한 테스트를 삭제/건너뛰어 성공시키지 말고 원인을 수정하거나 보고해 줘.
아직 Azure 서비스 이전이나 배포 작업은 하지 말고 검증 결과와 diff를 보여 줘.
```

JDK 21의 빌드와 원본 기능이 통과하면 변경 내용을 검토하고 중간 커밋을 남깁니다. 불필요한 UI 변경, 비밀 값과 거대한 생성물이 포함되지 않았는지 확인하세요.

## JDK 25 최종 업그레이드

[Spring Boot 4.1.2의 공식 요구사항](https://github.com/spring-projects/spring-boot/blob/v4.1.2/documentation/spring-boot-docs/src/docs/antora/modules/ROOT/pages/system-requirements.adoc)은 Java 17~27을 지원 범위로 설명합니다. 이는 개별 의존성이나 이 앱의 호환성까지 보장한다는 뜻은 아닙니다. 실제 사용할 라이브러리 조합을 확인합니다.

```text
이제 승인한 계획의 최종 JDK 25 업그레이드만 실행해 줘.
SDKMAN의 JDK 25를 사용하고 Spring Boot 4.1.2를 기준으로
Spring 라이브러리, 테스트 도구, 빌드 플러그인의 호환성을 확인해 줘.
다른 안정 버전이 필요하면 변경 이유와 공식 근거를 제시하고 승인을 기다려 줘.
JDK 21을 최종값으로 남기거나 JDK 25 EA를 선택하지 마.

루트/하위 pom, compiler release, 테스트 JVM과 실행 환경의 Java 버전을 맞춰 줘.
기존 동작을 유지하면서 필요 변경만 하고 Maven Wrapper로 clean verify를 실행해 줘.
web/worker를 로컬 PostgreSQL/RabbitMQ와 실행하고 기준 동작을 다시 확인해 줘.
도구가 확인한 결과와 사람이 확인해야 할 UI 결과를 구분해서 보고해 줘.
```

참가자 Bash에서도 직접 확인합니다.

```bash
source "${SDKMAN_DIR:-$HOME/.sdkman}/bin/sdkman-init.sh"
sdk use java <설치한-JDK-25-식별자>
java -version
javac -version
bash ./mvnw -version
bash ./mvnw clean verify
```

에이전트가 SDKMAN을 다른 프로세스에서 전환해도 현재 터미널의 JDK는 자동으로 바뀌지 않습니다. 생성/수정한 로컬 실행 명령에 따라 web과 worker를 다시 실행하고 실습 1의 입력을 재사용합니다. 원본 Docker 스크립트는 이미 존재하는 컨테이너를 재생성하려 하므로 무조건 반복 실행하지 않습니다.

```bash
git status --short
git diff
git add .
git diff --cached --stat
git commit -m "Upgrade sample to JDK 25"
```

## 완료 기준과 문제 해결

최종 Maven/컴파일/실행 JVM이 모두 25이고, 루트 빌드와 기존 기능이 통과해야 합니다. Boot 버전만 바뀌었거나 테스트를 제외한 패키징만 성공한 것은 완료가 아닙니다. 실패한 단계에서 멈춰 [문제 해결](../troubleshooting.md)을 확인하고, 검토하지 않은 변경을 삭제하는 `reset --hard`로 복구하지 않습니다.
