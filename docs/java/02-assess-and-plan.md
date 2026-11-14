# 2. 평가하고 계획 승인하기

[전체 목차](../../README.md) | [Java 목차](README.md) | [이전: 원본 실행](01-run-locally.md) | [다음: 업그레이드](03-upgrade.md) | [문제 해결](08-troubleshooting.md)

## 목표

앱 소스를 변경하지 않고 현재 구조와 업그레이드 위험을 평가한 뒤, 변경 범위와 제약 조건을 반영한 실행 계획을 작성합니다.

## 시작 조건

로컬에서 원본 앱의 동작을 확인하고, 업그레이드 전 앱 상태를 커밋해 둡니다. [실습 1: 원본 앱을 로컬에서 실행하기](01-run-locally.md)에서 사용한 터미널을 계속 사용합니다.

## 앱 평가(Assessment)

modernize CLI를 실행시켜 앱 평가를 시작합니다.

```bash
modernize
```

> [!NOTE]
>
> Modernize CLI가 작업에 사용할 모델을 자동으로 고르게 하려면, 실행 후 화면에서 `M` 키를 눌러 `Auto`를 선택합니다.

또는 아래와 같이 실행시 `auto` 모드를 선택할 수도 있습니다.

```bash
modernize --model auto
```

화면마다 다음 항목을 선택합니다. UI 표기는 설치된 버전에 따라 다를 수 있습니다.

| 화면 | 항목 | 선택값 |
| --- | --- | --- |
| 초기 화면 | Modernization option | Assess |
| Choose source type | Source | Current folder (`java` 앱 루트) |
| 평가 도메인 | Modernization domains | Upgrade, Cloud Readiness, Security |
| Configure assessment | Analysis Coverage | Full analysis |
| Security | Minimum CVE Severity | High |
| Java - Upgrade | Target Runtime | OpenJDK 25 |
| Cloud Readiness | Target Compute Services | Azure Container Apps (ACA) |
| Cloud Readiness | Target Operating System | Linux |
| Cloud Readiness | Containerization | Enabled |

앱 소스와 패키지 변경, Azure 리소스 생성과 배포는 평가 범위에 넣지 않습니다. 추가 설치가 필요하면 대상과 영향을 확인하고 별도로 승인합니다. 종료 후 보고서의 실제 경로, 실패/미분석 항목과 `git status --short`를 확인합니다. 도움말의 기본 출력은 `.github/modernize/assessment`이지만 실제 보고서 파일명을 추측하지 않습니다.

보고서에서 web/worker, 화면과 API, 환경 설정과 비밀 관리, PostgreSQL/RabbitMQ 의존성, 테스트와 업그레이드 위험의 근거 파일을 확인합니다. `dev`의 로컬 파일 저장은 메타데이터를 DB에 기록하지 않으며 `dev` 외 S3 경로의 기록/조회와 구분해야 합니다. 보고서 생성만으로 평가 완료를 선언하지 않습니다.

## 워크숍 제약 기록

앱 루트에 `.github/skills/java-aca-workshop/SKILL.md`를 만들고 다음을 저장합니다. Copilot app 채팅에 이 파일의 작성만 맡겨도 됩니다. 샘플 앱 안의 파일이며 워크숍 자료 루트에 만들지 않습니다.

```markdown
---
name: java-aca-workshop
description: Preserve Asset Manager behavior while upgrading to Java 25 and preparing Azure Container Apps deployment.
---

# 워크숍 제약

- 현재 승인한 계획의 작업 범위만 수행한다. 설치와 외부 서비스 사용은 별도 승인한다.
- Java 8에서 정식 JDK 25로 업그레이드한다. EA 버전은 사용하지 않는다.
- Spring Boot 4.1.2를 기준으로 JDK 25와 라이브러리 호환성, 지원 조건을 확인한다.
  다른 안정 버전이 필요하면 근거와 변경 승인을 받는다. 유료 지원/저장소를 전제하지 않는다.
- web/worker, 기존 화면, 업로드, 파일 조회와 비동기 썸네일 동작을 유지한다.
  불필요한 프런트엔드 재작성은 하지 않는다.
- dev 업로드는 DB에 메타데이터를 기록하지 않는다. dev 외 S3 경로의 DB 기록/조회는
  별도 이전 대상이며 로컬 기준선에서 확인한 기능과 구분한다.
- PostgreSQL은 Azure Database for PostgreSQL Flexible Server로,
  RabbitMQ는 Service Bus로, 로컬 파일과 S3는 private Blob으로 이전한다.
- 관리 ID, 최소 권한, TLS를 사용한다. 비밀은 코드/설정/Git에 저장하지 않는다.
  DB 내부 principal/권한과 ARM 역할을 구분하고 migration 주체를 별도로 정한다.
- 메시지 중복/재시도/dead-letter와 종료 처리를 보존한다. Blob을 공개하거나
  무기한 SAS URL로 우회하지 않는다. S3 데이터 이전과 AWS 접근은 별도 승인한다.
- 최종 환경은 Linux Azure Container Apps이다. AKS나 App Service는 사용하지 않는다.
- azd/Bicep과 로컬 컨테이너 엔진을 사용한다. 원격 빌드, ACR Tasks, az acr build는 금지한다.
- Windows는 PowerShell 7에서 . ../scripts/use-java.ps1 -Jdk 8 또는 -Jdk 25를,
  macOS/Linux는 source ../scripts/use-java.sh --jdk 8 또는 --jdk 25를 먼저 적용한다.
  같은 셸에서 Maven Wrapper를 사용하고 버전/종료 코드/실제 테스트 수를 기록한다.
- 기준 테스트, 업그레이드, Azure 코드, azd 산출물을 별도 계획으로 나눈다.
  변경 파일, 버전 근거, 검증 명령과 중지/복구 기준을 명시한다.
- Azure 리소스 생성, DB 변경/데이터 이전, 이미지 게시, 배포와 삭제는
  계획 실행에 포함하지 않는다. 참가자가 별도 승인 후 직접 실행한다.
- 테스트를 삭제/건너뛰어 성공시키지 않는다. 실제 결과와 미실행 통합 항목을 구분한다.
```

스킬 자동 검색의 기준 경로를 가정하지 않고 매 계획 입력에 이 파일을 명시합니다. 스킬은 안내 문서이지 OS 권한이나 비용 발생을 막는 보안 장치가 아닙니다.

## 네 계획과 첫 계획 생성

| 계획 | 생성 시점과 범위 |
| --- | --- |
| `ws03-baseline` | 지금 생성. Java 8 기준 테스트만 보강하고 실행 |
| `ws03-upgrade` | 기준 테스트 확인 후 생성. JDK 25 업그레이드와 로컬 회귀 |
| `ws04-azure-code` | 업그레이드 검토 후 생성. Azure 연동 코드와 단위 테스트 |
| `ws05-azd-assets` | 코드 계약 확정 후 생성. Dockerfile, azure.yaml, Bicep과 DB 준비 절차 작성 |

평가 보고서의 실제 파일 경로로 `<실제-평가-보고서>`를 바꾸고 **첫 계획만** 생성합니다. `--assess-file-path`는 설치본 도움말에 있는지 먼저 확인합니다. 없다면 보고서 경로를 목표 문장에 넣고 계획에 반영됐는지 검토합니다.

Windows:

```powershell
$assessment = "<실제-평가-보고서>"
$goal = '.github/skills/java-aca-workshop/SKILL.md와 평가 보고서를 읽고 Java 8 기준 테스트 보강과 실행만 계획해 줘. 기존 web/worker 동작과 dev/S3 차이를 보존하고 DB/큐가 필요한 검사는 실행 조건을 명시해 줘. 런타임 업그레이드, Azure 이전, 리소스 생성과 배포는 제외해 줘. 지금은 계획만 작성해 줘.'
modernize plan create $goal --source . --language java --plan-name ws03-baseline --assess-file-path $assessment
```

macOS와 Linux:

```bash
assessment="<실제-평가-보고서>"
goal='.github/skills/java-aca-workshop/SKILL.md와 평가 보고서를 읽고 Java 8 기준 테스트 보강과 실행만 계획해 줘. 기존 web/worker 동작과 dev/S3 차이를 보존하고 DB/큐가 필요한 검사는 실행 조건을 명시해 줘. 런타임 업그레이드, Azure 이전, 리소스 생성과 배포는 제외해 줘. 지금은 계획만 작성해 줘.'
modernize plan create "$goal" --source . --language java --plan-name ws03-baseline --assess-file-path "$assessment"
```

## 검토와 완료 기준

실제 생성된 `plan.md`, `tasks.json`과 사용 스킬의 경로를 기록하고 둘을 함께 읽습니다. 출력 경로는 버전과 실행 결과를 따르며 서로 다른 디렉터리에 임의로 복제하지 않습니다.

- 작업 목록이 기준 테스트에만 한정되는가?
- 외부 도구 설치나 비용 발생 작업, Azure/DB 변경이 섞이지 않았는가?
- 테스트 조건, 파일 범위와 중단/복구 기준이 명확한가?
- 앱 외부 파일, 생성물과 비밀이 커밋되지 않도록 범위를 검토했는가?

`--source .`는 Git 커밋 범위의 보안 경계가 아닙니다. 범위를 바꾸면 `plan.md`와 `tasks.json`을 함께 수정하고 다시 검토합니다. 전체 현대화를 한 번에 승인하지 않습니다. 평가와 `ws03-baseline` 검토를 마쳤다면 [업그레이드](03-upgrade.md)에서 이 계획만 실행합니다.
