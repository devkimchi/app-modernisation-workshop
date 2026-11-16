# 5. azd 배포 산출물 준비하기

[전체 목차](../../README.md) | [Java 목차](README.md) | [이전: Azure 서비스 이전](04-migrate-azure-services.md) | [다음: ACA 배포](06-deploy-aca.md) | [문제 해결](08-troubleshooting.md)

## 목표

실습 3에서 생성된 Dockerfile, `azure.yaml`, Bicep과 DB 초기화 절차를 실제 앱 코드와 선택한 엔진에 맞춰 검토합니다. 이 단계에서는 Azure 리소스를 만들거나 이미지를 게시하지 않습니다.

## 실습 범위

| 단계 | 다루는 내용 | 이 단계에서 하지 않는 작업 |
| --- | --- | --- |
| [실습 3: JDK 25로 업그레이드하기](03-upgrade.md) | Java 업그레이드, Azure 서비스 이전 코드와 배포 산출물 준비, 로컬 빌드 및 모의 테스트 | Azure 리소스 생성, 실제 Azure 연결, 앱 배포 |
| [실습 4: Azure 서비스로 의존성 이전하기](04-migrate-azure-services.md) | 이전된 Azure 서비스 코드와 테스트, 실습 3의 검증 결과 검토 | 코드 변경, Azure 리소스 생성과 실제 연결 |
| 실습 5: 이 문서 | Dockerfile, `azure.yaml`, Bicep, DB 초기화 절차와 배포 설정 검토 | 프로비저닝, DB 초기화, 이미지 게시, 배포 |
| [실습 6: azd로 ACA에 배포하기](06-deploy-aca.md) | 승인 후 Azure 리소스 프로비저닝, DB 초기화, 로컬 이미지 빌드, 배포와 실제 기능 확인 | 승인하지 않은 리소스나 데이터 변경 |

## 실습 전 확인 사항

실습 4에서 Azure 서비스 이전 코드와 테스트를 검토한 뒤, 같은 Copilot app 터미널의 **앱 루트**를 계속 사용합니다. 실습 3에서 기록한 `$before`를 사용해 자동 커밋과 미커밋 변경을 함께 확인합니다.

```text
git status --short
git log --oneline "$before..HEAD"
git diff "$before..HEAD"
git diff
git diff --cached
```

앱 밖의 변경과 비밀이 없는지 확인합니다. 채팅에 Java 검증을 맡길 때도 해당 셸에 JDK 25 도우미를 먼저 적용하도록 요청합니다.

## 배포 산출물 요구사항 확인

별도 계획을 만들지 않고, 다음 요구사항이 생성된 배포 산출물에 반영됐는지 확인합니다.

```text
`.github/modernize/rulebook/`의 rulebook과 실제 Azure 코드/환경 변수 계약을 읽고
현재 앱 루트의 Azure Developer CLI 배포 산출물을 검토해 줘.
파일을 변경하거나 배포, Azure 리소스 생성을 실행하지 마.

- azure.yaml과 infra/의 Bicep을 만들고 서비스 이름은 web, worker로 정해 줘.
- 두 서비스는 language: docker, host: containerapp이다.
- 로컬 Docker 엔진을 사용하고 AZD_CONTAINER_RUNTIME=docker로 맞춘다.
- docker.remoteBuild는 false, docker.platform은 linux/amd64로 명시한다.
- web/worker 각각 Dockerfile을 만들되 루트 Maven reactor를 빌드 컨텍스트로 쓴다.
- 빌드와 런타임 모두 JDK 25 기반이며 공식 이미지의 실제 tag/manifest를 확인한다.
- multi-stage, 비루트 사용자, .dockerignore, 필수 설정과 health check를 구성한다.
- web은 HTTP ingress와 실제 listen port를 맞추고 worker는 ingress를 끈다.
- worker는 우선 minReplicas=1/maxReplicas=1의 장기 실행 소비자로 설정한다.
  web은 minReplicas=0을 사용할 수 있지만 cold start를 검증 항목에 포함한다.
- ACR Basic, ACA environment, Log Analytics, PostgreSQL Flexible Server,
  Service Bus queue, private Blob과 각각의 관리 ID/최소 권한을 Bicep으로 정의한다.
- ACR의 admin 계정 대신 관리 ID pull을 구성하고 로컬 azd 게시 주체의 push 권한을
  별도로 설명한다. az acr build/ACR Tasks나 remote build는 사용하지 않는다.
- AZURE_CONTAINER_REGISTRY_ENDPOINT와 AZURE_RESOURCE_GROUP을 출력하고,
  서비스 검색에 필요한 azd-service-name 태그 또는 resourceName을 연결한다.
- AZURE_WEB_APP_NAME, AZURE_WORKER_APP_NAME, WEB_URI도 출력해 후속 조회에 쓴다.
- .azure/, 비밀 파일, 빌드 산출물을 Git과 이미지 빌드 컨텍스트에서 제외한다.
- DB Entra 관리자와 DB 내부 principal/권한/스키마를 만드는 별도 초기화 절차를
  생성한다. 컨트롤 플레인 RBAC만으로 DB 인증이 끝났다고 처리하지 마.
- 로컬 참가자와 ACA에서 DB까지 실제 접근 가능한 네트워크 경로를 설계한다.
  공개 DB라면 확인한 클라이언트/egress IP만 허용하고 모든 IP를 열지 마.
  ACA의 inbound static IP를 outbound IP로 오인하지 마.
  안정적인 제한 경로가 없으면 VNet/private 연결 등 대안을 제시하고 비용 승인을 기다려 줘.
- 새 데모 DB만 초기화하며 기존 DB를 삭제하거나 덮어쓰는 hook은 만들지 마.
  이 계획은 절차 작성까지만 포함하고 실제 DB 사용자/권한/migration은 실행하지 마.

구독/리전/SKU/비용, 권한, 네트워크와 이미지 태그 정책을 설명해 줘.
템플릿 구문 검증과 단위 빌드 결과, 미실행 통합 항목을 구분해 줘.
azd hooks와 호출 스크립트를 모두 검토 대상으로 포함해 줘.
이미지 게시, 프로비저닝, migration 실행과 배포는 참가자가 별도 승인 후 직접 실행한다.
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

Dockerfile/`azure.yaml`/Bicep, 역할/DB 초기화, 네트워크, 비용, 정리 범위를 검토했고 **참가자가 실제 구독과 생성 범위를 승인**해야 합니다. 아직 `azd package`를 실행하지 않았으므로 이미지 빌드 성공을 주장하지 않습니다. `azd` 연결 문제는 [문제 해결](08-troubleshooting.md)을 참고합니다.
