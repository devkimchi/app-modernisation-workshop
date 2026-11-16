# 4. Azure 서비스로 의존성 이전하기

[전체 목차](../../README.md) | [Java 목차](README.md) | [이전: 업그레이드](03-upgrade.md) | [다음: azd 준비](05-prepare-azd.md) | [문제 해결](08-troubleshooting.md)

## 목표

이전 실습에서 준비한 Azure 서비스 이전 코드와 테스트가 기존 동작을 보존하는지 검토합니다.

## 실습 범위

이 실습에서는 [실습 3: JDK 25로 업그레이드하기](03-upgrade.md)에서 준비한 Azure 서비스 이전 코드와 테스트를 검토하고, 외부 Azure 서비스 없이 가능한 검증을 수행합니다.

| 단계 | 다루는 내용 | 이 단계에서 하지 않는 작업 |
| --- | --- | --- |
| [실습 3: JDK 25로 업그레이드하기](03-upgrade.md) | Java 업그레이드, Azure 서비스 이전 코드와 배포 산출물 준비, 로컬 빌드 및 모의 테스트 | Azure 리소스 생성, 실제 Azure 연결, 앱 배포 |
| 실습 4: 이 문서 | 이전된 Azure 서비스 코드와 기존 동작 검토, 외부 Azure 서비스 없는 테스트 | 코드 변경, Azure 리소스 생성과 실제 연결 |
| [실습 5: azd 배포 산출물 준비하기](05-prepare-azd.md) | Dockerfile, `azure.yaml`, Bicep, DB 초기화 절차와 배포 설정 검토 | 프로비저닝, DB 초기화, 이미지 게시, 배포 |
| [실습 6: azd로 ACA에 배포하기](06-deploy-aca.md) | 승인 후 Azure 리소스 프로비저닝, DB 초기화, 로컬 이미지 빌드, 배포와 실제 기능 확인 | 승인하지 않은 리소스나 데이터 변경 |

### Azure 이전 대상과 보존할 동작

| 기존 의존성 | 목표 | 보존할 동작 |
| --- | --- | --- |
| PostgreSQL 컨테이너 | Azure Database for PostgreSQL Flexible Server | DB 연결과 `dev` 외 S3 경로의 메타데이터 기록 및 조회 |
| RabbitMQ | Azure Service Bus queue | 생산자/소비자 계약, 처리 결과와 오류 복구 |
| `dev`의 로컬 파일과 `dev` 외 AWS S3 | private Azure Blob Storage | 업로드 후 조회, 접근 제어와 파일 식별 |

## 실습 전 확인 사항

이전 실습에서 JDK 25 빌드와 로컬 기준 동작 검증을 마친 뒤, 같은 Copilot app 터미널의 **앱 루트**를 계속 사용합니다.

## 코드 이전 요구사항 확인

다음 요구사항이 생성된 코드와 테스트에 반영됐는지 확인합니다.

```text
`.github/modernize/rulebook/`의 rulebook과 실제 업그레이드 결과를 읽고
Azure 서비스 이전 코드와 테스트를 검토해 줘. 파일을 변경하거나 명령을 실행하지 마.
JDK 25와 현재 Spring Boot 버전, web/worker의 기존 기능을 유지하는지 확인해 줘.

- **PostgreSQL:** Flexible Server와 TLS를 사용하고, 관리 ID/Entra 인증과 토큰 갱신이 커넥션 풀에서 올바르게 동작하는지 확인해 줘.
- **Service Bus:** RabbitMQ를 대체하는 생산자와 소비자를 확인해 줘. 메시지 형식과 처리 동작을 유지하고, 성공 시 complete, 실패 시 abandon/dead-letter, 중복 수신 멱등 처리, 종료 시 소비자 정리를 검토해 줘. worker는 장기 실행 소비자로 유지하고 KEDA는 추가하지 마.
- **Blob:** 파일이 private Blob에 저장되고 인증된 서버 경유로 조회되는지 확인해 줘. 컨테이너 로컬 디스크를 영구 저장소로 쓰거나 공개 컨테이너, 무기한 SAS URL을 사용하지 마. `dev` 외 S3 경로의 코드와 설정 및 DB 메타데이터 기록/조회 동작을 보존하고, `dev` 업로드 경로에 없던 DB 기록을 추가하지 마.
- **인증과 SDK:** 로컬 개발 자격 증명과 ACA 관리 ID를 구분하고, 선택한 인증 체인(예: `DefaultAzureCredential`)의 실제 동작을 설명해 줘. 비밀을 코드, 설정, Git에 넣지 말고 현재 Spring Boot/JDK 25와 호환되는 Azure SDK를 근거와 함께 확인해 줘. 호환되지 않는 Spring Cloud Azure starter는 추가하지 마.
- **문서와 테스트:** 변경된 환경 변수, 필요한 리소스와 역할, DB 초기화 절차가 문서화됐는지 확인해 줘. 단위 테스트는 Azure 없이 실행 가능해야 하며 DB/큐/Blob 통합 테스트는 별도로 준비하도록 계획해 줘.
- **제외 범위:** S3 데이터 이전이나 AWS 리소스 접근은 필요성만 검토하고 실행하지 마. 인프라 생성, 실제 DB 변경/데이터 이전, 이미지 게시, 배포는 작업 목록에서 제외해 줘.
```

## 코드 검증

Windows:

```powershell
. ../scripts/use-java.ps1 -Jdk 25
./mvnw.cmd clean verify
```

macOS와 Linux:

```bash
source ../scripts/use-java.sh --jdk 25
./mvnw clean verify
```

명령별 결과를 확인하고 실패하면 멈춥니다. Copilot app 채팅에 추가 Java 검증을 맡길 때도 같은 실행 셸에 `use-java.ps1` 또는 `use-java.sh`로 JDK 25를 먼저 적용하도록 요청합니다.

## 참가자 검토

각 앱의 실제 책임에 따라 역할을 나눕니다. 예를 들어 web에는 Service Bus Data Sender, worker에는 Data Receiver를 부여하며 Blob도 필요한 컨테이너 범위와 작업에 맞춥니다. 모든 앱에 Contributor 또는 구독 전체 데이터 권한을 주지 않습니다.

**PostgreSQL의 ARM 역할과 DB 내부 권한은 다릅니다.** Entra 관리자, 관리 ID에 대응하는 DB principal, 필요한 스키마/테이블 권한과 초기 migration 실행 주체가 계획에 있어야 합니다. 일반 DB 사용자는 스키마 변경 권한까지 무조건 갖지 않도록 구분합니다.

```text
git status --short
git log --oneline "$before..HEAD"
git diff --stat "$before..HEAD"
git diff "$before..HEAD"
git diff
git diff --cached
```

자동 커밋에 앱 외부 파일, 생성물과 비밀이 포함되지 않았는지도 확인합니다.

외부 연결 없이 통과한 단위 검사와 아직 실행하지 않은 Azure 통합 검사를 분리해 기록합니다. 로컬 `dev` 프로파일을 유지할지, Azure 설정이 필요한 별도 프로파일로 분리할지는 코드와 실행 안내에 명확히 반영합니다. Azure 이전 후에도 원본 `dev` 실행 명령이 그대로 유효하다고 가정하지 않습니다.

## 완료 기준과 문제 해결

코드에서 DB, 큐, Blob 경로가 모두 연결되고 S3 경로의 이전 범위와 역할/환경 변수/DB 초기화 계약이 정리되어야 합니다. 단위 검사 통과와 미실행 통합 항목을 기록합니다. Service Bus만 새 SDK로 바꿔 놓고 소비자가 실제로 시작되지 않거나, 업로드 경로가 임시 디스크에 남아 있으면 다음 단계로 넘어가지 않습니다.

JDK/SDK 충돌과 인증 문제는 [문제 해결](08-troubleshooting.md)을 참고합니다. 실제 자격 증명이나 토큰을 채팅에 붙이지 말고 오류 코드와 비밀을 제거한 로그만 사용합니다.
