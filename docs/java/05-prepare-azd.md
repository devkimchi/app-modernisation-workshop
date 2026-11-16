# 5. azd 배포 산출물 준비하기

[전체 목차](../../README.md) | [Java 목차](README.md) | [이전: Azure 서비스 이전](04-migrate-azure-services.md) | [다음: ACA 배포](06-deploy-aca.md) | [문제 해결](08-troubleshooting.md)

## 목표

[실습 3: JDK 25로 업그레이드하기](03-upgrade.md)에서 생성된 Dockerfile, `azure.yaml`, Bicep과 DB 초기화 절차를 실제 앱 코드와 선택한 엔진에 맞춰 검토합니다. 이 단계에서는 Azure 리소스를 만들거나 이미지를 게시하지 않습니다.

## 실습 범위

| 단계 | 다루는 내용 | 이 단계에서 하지 않는 작업 |
| --- | --- | --- |
| [실습 3: JDK 25로 업그레이드하기](03-upgrade.md) | Java 업그레이드, Azure 서비스 이전 코드와 배포 산출물 준비, 로컬 빌드 및 모의 테스트 | Azure 리소스 생성, 실제 Azure 연결, 앱 배포 |
| [실습 4: Azure 서비스로 의존성 이전하기](04-migrate-azure-services.md) | 이전된 Azure 서비스 코드와 테스트, [실습 3: JDK 25로 업그레이드하기](03-upgrade.md)의 검증 결과 검토 | 코드 변경, Azure 리소스 생성과 실제 연결 |
| 실습 5: 이 문서 | Dockerfile, `azure.yaml`, Bicep, DB 초기화 절차와 배포 설정 검토 | 프로비저닝, DB 초기화, 이미지 게시, 배포 |
| [실습 6: azd로 ACA에 배포하기](06-deploy-aca.md) | 승인 후 Azure 리소스 프로비저닝, DB 초기화, 로컬 이미지 빌드, 배포와 실제 기능 확인 | 승인하지 않은 리소스나 데이터 변경 |

## 실습 전 확인 사항

[실습 4: Azure 서비스로 의존성 이전하기](04-migrate-azure-services.md)에서 Azure 서비스 이전 코드와 테스트를 검토한 뒤, 같은 Copilot app 터미널의 **앱 루트**를 계속 사용합니다. [실습 3: JDK 25로 업그레이드하기](03-upgrade.md)에서 기록한 `$before`를 사용해 자동 커밋과 미커밋 변경을 함께 확인합니다.

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
`.github/modernize/rulebook/`의 rulebook과 실제 Azure 코드/환경 변수 계약을 읽고
현재 앱 루트에 이미 있는 Azure Developer CLI 배포 산출물만 검토해 줘.
파일을 만들거나 변경하지 말고, 명령을 실행하거나 결과를 다시 만들지 마.
누락되거나 확인할 수 없는 산출물과 요구사항은 누락 또는 미확인으로 보고해 줘.

- 기존 `azure.yaml`에 서비스 이름 `web`, `worker`가 정의되어 있는지 확인해 줘.
  두 서비스의 `language`가 `docker`, `host`가 `containerapp`인지 확인해 줘.
- 설정에서 로컬 Docker 엔진과 `AZD_CONTAINER_RUNTIME=docker`를 사용하는지,
  `docker.remoteBuild`가 `false`, `docker.platform`이 `linux/amd64`인지 확인해 줘.
- `web`과 `worker`의 기존 Dockerfile이 있는지, 루트 Maven reactor를 빌드 컨텍스트로
  사용하는지 확인해 줘.
- 빌드와 런타임이 JDK 25 기반인지 확인해 줘. 이미지의 실제 tag와 manifest를
  확인한 기존 근거가 없으면 미확인으로 표시해 줘.
- 기존 Dockerfile에서 multi-stage 빌드, 비루트 사용자, `.dockerignore`, 필수 설정과
  health check를 확인해 줘.
- `web`은 HTTP ingress와 실제 listen port가 일치하는지, `worker`는 ingress가 꺼져
  있는지 확인해 줘.
- `worker`가 `minReplicas=1`과 `maxReplicas=1`의 장기 실행 소비자인지 확인해 줘.
  `web`에서 `minReplicas=0`을 사용한다면 cold start 검증이 계획되어 있는지 확인해 줘.
- 기존 Bicep에서 ACR Basic, ACA environment, Log Analytics,
  PostgreSQL Flexible Server, Service Bus queue, private Blob과 각각의 관리 ID 및
  최소 권한을 정의했는지 확인해 줘.
- ACR admin 계정 대신 관리 ID pull을 사용하는지, 로컬 `azd` 게시 주체의 push 권한을
  별도로 설명하는지 확인해 줘. `az acr build`, ACR Tasks와 remote build는 사용하지
  않는 설정인지 확인해 줘.
- `AZURE_CONTAINER_REGISTRY_ENDPOINT`와 `AZURE_RESOURCE_GROUP`을 출력하고,
  서비스 검색에 필요한 `azd-service-name` 태그 또는 `resourceName`을 연결하는지
  확인해 줘.
- `AZURE_WEB_APP_NAME`, `AZURE_WORKER_APP_NAME`, `WEB_URI`를 출력해 후속 조회에
  사용하는지 확인해 줘.
- `.azure/`, 비밀 파일과 빌드 산출물이 Git 및 이미지 빌드 컨텍스트에서 제외되는지
  확인해 줘.
- DB Entra 관리자와 DB 내부 principal, 권한 및 스키마를 설정하는 별도 초기화 절차가
  이미 있는지 확인해 줘. 컨트롤 플레인 RBAC만으로 DB 인증이 완료된 것으로
  처리하지 마.
- 로컬 참가자와 ACA에서 DB까지 실제로 접근할 수 있는 네트워크 경로가 확인되는지
  검토해 줘. 공개 DB라면 확인한 클라이언트 또는 egress IP만 허용하고 모든 IP를
  열지 않는지, ACA의 inbound static IP를 outbound IP로 오인하지 않는지 확인해 줘.
  제한된 연결 경로를 확인할 수 없으면 그 사실과 VNet 또는 private 연결 같은 대안을
  보고하고, 비용 승인이 필요한 사항을 표시해 줘.
- 기존 절차가 새 데모 DB만 초기화하고 기존 DB를 삭제하거나 덮어쓰지 않는지 확인해 줘.
  실제 DB 사용자, 권한 또는 migration은 실행하지 마.
- 구독, 리전, SKU와 비용, 권한, 네트워크 및 이미지 tag 정책을 설명해 줘.
- 기존에 기록된 템플릿 구문 검증과 단위 빌드 결과만 확인해 줘. 결과가 없거나
  근거를 확인할 수 없으면 미검증으로 표시하고 명령은 실행하거나 재실행하지 마.
  미실행 통합 항목도 구분해 줘.
- `azd` hooks와 호출 스크립트도 검토해 줘.
- 이미지 게시, 프로비저닝, migration 실행과 배포는 수행하지 마.

각 판단의 근거로 파일 경로와 줄 번호를 제시해 줘. 코드나 기존 기록에서 확인할 수
없는 항목은 미확인으로 표시해 줘.
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
