# 5. azd 배포 산출물 준비하기

[전체 목차](../../README.md) | [Java 목차](README.md) | [이전: Azure 서비스 이전](04-migrate-azure-services.md) | [다음: ACA 배포](06-deploy-aca.md) | [문제 해결](08-troubleshooting.md)

## 목표

[실습 3: JDK 25로 업그레이드하기](03-upgrade.md)에서 생성된 Dockerfile, `azure.yaml`, Bicep과 DB 초기화 절차를 실제 앱 코드와 선택한 엔진에 맞춰 검토합니다. 이 단계에서는 Azure 리소스를 만들거나 이미지를 게시하지 않습니다.

## 실습 범위

| 단계 | 다루는 내용 | 이 단계에서 하지 않는 작업 |
| --- | --- | --- |
| [실습 3: JDK 25로 업그레이드하기](03-upgrade.md) | Java 업그레이드, Azure 서비스 이전 코드와 배포 산출물 준비, 로컬 빌드 및 모의 테스트 | Azure 리소스 생성, 실제 Azure 연결, 앱 배포 |
| [실습 4: Azure 서비스로 의존성 이전하기](04-migrate-azure-services.md) | 이전된 Azure 서비스 코드와 테스트 검토, 필요한 수정과 로컬 검증 | Azure 리소스 생성과 실제 연결 |
| 실습 5: 이 문서 | Dockerfile, `azure.yaml`, Bicep, DB 초기화 절차와 배포 설정 검토 | 프로비저닝, DB 초기화, 이미지 게시, 배포 |
| [실습 6: azd로 ACA에 배포하기](06-deploy-aca.md) | 승인 후 Azure 리소스 프로비저닝, DB 초기화, 로컬 이미지 빌드, 배포와 실제 기능 확인 | 승인하지 않은 리소스나 데이터 변경 |

## 실습 전 확인 사항

[실습 4: Azure 서비스로 의존성 이전하기](04-migrate-azure-services.md)에서 Azure 서비스 이전 코드와 테스트를 검토하고 필요한 수정을 마친 뒤, 같은 Copilot app 터미널의 **앱 루트**를 계속 사용합니다. [실습 3: JDK 25로 업그레이드하기](03-upgrade.md)에서 기록한 `$before`를 사용해 자동 커밋과 미커밋 변경을 함께 확인합니다.

```bash
git status --short
git log --oneline "$before..HEAD"
git diff "$before..HEAD"
git diff
git diff --cached
```

Git 변경 목록에서 `java/` 앱 밖의 파일(예: `docs/`, `scripts/`)이 변경됐는지 확인합니다. diff에 토큰, 자격 증명, 비공개 키, 연결 문자열 등 비밀정보가 포함됐는지도 살핍니다. 채팅에 Java 검증을 맡길 때는 해당 셸에 JDK 25 도우미를 먼저 적용하도록 요청합니다.

## 배포 산출물 요구사항 확인

아래 프롬프트를 통해 요구사항이 생성된 배포 산출물에 반영됐는지 확인합니다.

```text
`.github/modernize/rulebook/`과 실제 Azure 코드 및 환경 변수 계약을 읽고
현재 앱 루트의 기존 Azure Developer CLI 산출물만 검토해 줘. 파일을 만들거나 변경하지 말고 명령도 실행하지 마.

- **azd 설정:** `azure.yaml`의 `web`/`worker`가 `language: docker`, `host: containerapp`인지, 로컬 Docker와 `AZD_CONTAINER_RUNTIME=docker`, `docker.remoteBuild: false`, `docker.platform: linux/amd64` 설정인지 확인해 줘.
- **이미지 빌드:** 두 서비스의 Dockerfile이 루트 Maven reactor를 빌드하는지, JDK 25와 실제 이미지 tag/manifest 근거, multi-stage 빌드, 비루트 사용자, `.dockerignore`, 필수 설정과 health check를 확인해 줘.
- **Container Apps:** `web`의 HTTP ingress와 listen port가 일치하고 `worker`는 ingress가 꺼져 있는지, `worker`가 장기 실행 소비자이며 `minReplicas=1`/`maxReplicas=1`인지 확인해 줘. `web`이 scale-to-zero이면 cold start 검증 계획도 확인해 줘.
- **Azure 리소스와 권한:** Bicep에 ACR Basic, ACA environment, Log Analytics, PostgreSQL Flexible Server, Service Bus queue, private Blob, 관리 ID와 최소 권한이 있는지 확인해 줘. ACR pull은 관리 ID를 쓰고 로컬 `azd` 게시 주체의 push 권한은 별도로 설명하는지 확인해 줘. `az acr build`, ACR Tasks, remote build는 사용하지 않아야 해.
- **출력과 제외 파일:** `AZURE_CONTAINER_REGISTRY_ENDPOINT`, `AZURE_RESOURCE_GROUP`, `AZURE_WEB_APP_NAME`, `AZURE_WORKER_APP_NAME`, `WEB_URI` 출력과 서비스 검색용 `azd-service-name` 태그 또는 `resourceName`을 확인해 줘. `.azure/`, 비밀 파일과 빌드 산출물이 Git 및 이미지 빌드 컨텍스트에서 제외되는지도 확인해 줘.
- **DB 초기화:** DB Entra 관리자, DB 내부 principal/권한/스키마를 설정하는 초기화 절차가 있는지, 새 데모 DB만 대상으로 하고 기존 DB를 삭제하거나 덮어쓰지 않는지 확인해 줘. 컨트롤 플레인 RBAC를 DB 인증으로 간주하거나 실제 DB 작업을 실행하지 마.
- **네트워크와 비용:** 로컬과 ACA의 DB 네트워크 경로, 구독, 리전, SKU, 비용, 권한 및 이미지 tag 정책을 검토해 줘. 공개 DB는 확인된 클라이언트/egress IP만 허용해야 하며 ACA inbound static IP를 outbound IP로 간주하지 마. 경로를 확인할 수 없으면 누락과 대안, 비용 승인 필요성을 보고해 줘.
- **hooks와 검증:** `azd` hooks와 호출 스크립트를 검토해 줘. 템플릿 검증과 단위 빌드는 이미 기록된 결과만 확인하고, 결과가 없으면 미검증으로 표시해 줘. 통합 테스트 미실행 여부도 구분해 줘.
- **제외 범위:** 이미지 게시, 프로비저닝, DB 사용자/권한 변경, migration 및 배포는 하지 마.

각 판단의 근거로 파일 경로와 줄 번호를 제시하고, 누락된 항목은 누락으로, 근거가 없어 확인할 수 없는 항목은 미확인 또는 미검증으로 보고해 줘.
```

## azure.yaml 검토 포인트

아래는 **설정 형태 예시**이지 완성 파일이 아닙니다. 실제 Dockerfile 경로와 서비스 이름이 생성물과 일치해야 합니다.

```yaml
services:
  web:
    project: .
    language: docker
    host: containerapp
    docker:
      path: ./web/Dockerfile
      context: .
      remoteBuild: false
      platform: linux/amd64
  worker:
    project: .
    language: docker
    host: containerapp
    docker:
      path: ./worker/Dockerfile
      context: .
      remoteBuild: false
      platform: linux/amd64
```

`language: java`의 자동 JAR 탐색과 혼용하지 않습니다. 두 이미지의 런타임이 Java 25이고, 각각 해당 모듈의 JAR을 실행하는지 확인합니다. 이미지 태그는 `latest` 재사용 대신 이번 빌드를 식별할 수 있는 고유 값으로 만들고 배포 후 digest를 기록합니다.

`azd`가 서비스와 리소스를 찾을 수 있어야 합니다. Bicep과 `azure.yaml`의 서비스 이름, 태그, 리소스 이름을 대조합니다. `azd provision`의 임시 bootstrap 이미지가 필요하면 신뢰하는 이미지와 교체 흐름을 명시하고, 실제 서비스가 배포되었다고 오인하지 않도록 합니다.

루트/서비스 수준의 **모든 azd hooks와 호출 스크립트**를 읽습니다. 명령 수준 hook은 앱 루트, 서비스 수준 hook은 `project` 경로에서 실행됩니다. 셸과 상대 경로를 확인하고 DB 초기화나 자동 배포를 `postprovision`에 숨기지 않습니다. 오류를 숨기는 `continueOnError: true`를 기본값으로 두지 않습니다. 이미 생성된 산출물을 `azd init --from-code`로 다시 생성하지 않습니다.

## 비용과 배포 승인

PostgreSQL, Service Bus, ACR, 로그 및 네트워크 리소스는 ACA가 scale-to-zero여도 비용이 발생할 수 있습니다. 리전별 SKU/쿼터와 [Azure 가격 계산기](https://azure.microsoft.com/pricing/calculator/)를 확인합니다. 무료 구독의 ACR Tasks 제한을 피하는 것이 서비스 전체를 무료로 만든다는 뜻은 아닙니다.

데이터베이스 방화벽의 "Azure 서비스 허용"은 본인 구독만 허용하는 기능이 아닙니다. 이를 묵시적으로 켜거나 `0.0.0.0`~`255.255.255.255`로 열어 연결 문제를 숨기지 않습니다. 네트워크 경로를 확정하지 못했으면 배포를 승인하지 않습니다.

## 완료 기준과 문제 해결

Dockerfile/`azure.yaml`/Bicep, 역할/DB 초기화, 네트워크, 비용, 정리 범위를 검토하고 **참가자가 실제 구독과 생성 범위를 승인**해야 합니다. 이미 기록된 `azd package` 결과만 확인하고, 결과가 없거나 근거를 확인할 수 없으면 이미지 빌드를 미검증으로 표시합니다. `azd` 연결 문제는 [문제 해결](08-troubleshooting.md)을 참고합니다.
