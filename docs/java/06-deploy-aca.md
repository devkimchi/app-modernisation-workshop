# 6. azd로 ACA에 배포하기

[전체 목차](../../README.md) | [Java 목차](README.md) | [이전: azd 준비](05-prepare-azd.md) | [다음: 정리](07-cleanup.md) | [문제 해결](08-troubleshooting.md)

## 목표

검토와 승인이 끝난 산출물로 참가자가 직접 프로비저닝, 로컬 이미지 빌드, 배포와 기능 검증을 수행합니다.

## 실습 범위

| 단계 | 다루는 내용 | 이 단계에서 하지 않는 작업 |
| --- | --- | --- |
| [실습 3: JDK 25로 업그레이드하기](03-upgrade.md) | Java 업그레이드, Azure 서비스 이전 코드와 배포 산출물 준비, 로컬 빌드 및 모의 테스트 | Azure 리소스 생성, 실제 Azure 연결, 앱 배포 |
| [실습 4: Azure 서비스로 의존성 이전하기](04-migrate-azure-services.md) | 이전된 Azure 서비스 코드와 테스트 검토, 필요한 수정과 로컬 검증 | Azure 리소스 생성과 실제 연결 |
| [실습 5: azd 배포 산출물 준비하기](05-prepare-azd.md) | Dockerfile, `azure.yaml`, Bicep, DB 초기화 절차와 배포 설정 검토 및 수정 | 프로비저닝, DB 초기화, 이미지 게시, 배포 |
| 실습 6: 이 문서 | 승인 후 Azure 리소스 프로비저닝, DB 초기화, 로컬 이미지 빌드, 배포와 실제 기능 확인 | 승인하지 않은 리소스나 데이터 변경 |

## 실습 전 확인 사항

[실습 5: azd 배포 산출물 준비하기](05-prepare-azd.md)에서 산출물을 검토하고 승인한 뒤, 같은 Copilot app 터미널의 **앱 루트**를 사용합니다.

로컬 이미지 빌드를 위해 Docker Engine을 실행하고 `docker info`로 연결을 확인합니다.

> [!NOTE]
> 다른 컨테이너 빌드 엔진을 사용하려면 [8. 문제 해결: 대체 엔진 설정](08-troubleshooting.md#대체-엔진-설정)을 참고합니다.

## 환경 설정

Docker Engine을 사용하고, 설치본이 지원하면 azd의 자동 비대화형 모드 감지를 해제하도록 현재 셸에서 다음을 설정합니다.

```bash
# zsh/bash
export AZD_CONTAINER_RUNTIME=docker
export AZD_NON_INTERACTIVE=false
```

```powershell
# PowerShell
$env:AZD_CONTAINER_RUNTIME = 'docker'
$env:AZD_NON_INTERACTIVE = 'false'
```

> [!NOTE]
> Podman을 사용하려면 위 `AZD_CONTAINER_RUNTIME` 값을 `podman`으로 바꾸고 앞서 안내한 대체 엔진의 실행 조건을 확인합니다.

Azure CLI와 azd의 로그인은 별개입니다. 필요한 경우 참가자가 직접 로그인하고, 로그인 상태와 선택한 구독을 확인합니다.

```bash
az login
azd auth login
az account show --query "{name:name,id:id}" --output table
azd auth login --check-status
```

앱 배포 환경을 만듭니다. `<...>`를 실제 값으로 바꿉니다. (예: `contoso-asset-manager`)

```bash
azd env new "<개인별-고유-환경명>"
```

## 프로비저닝, 패키징, 배포

> [!NOTE]
> `azd up`은 provision/package/deploy를 묶는 명령이지만 이번 실습은 실패 위치와 승인 범위를 알 수 있도록 단계별 실행이 기본입니다.

각 명령이 성공하고 결과를 검토한 뒤 다음 명령을 실행합니다. 블록 전체를 무인 실행하지 않습니다.

### 리소스 프로비저닝

[실습 5](05-prepare-azd.md)에서 검토한 hooks와 구독, 리전, SKU, 권한, 네트워크 및 비용을 확인하고 승인합니다. 환경에 구독과 리전이 이미 설정되어 있다면 다음 명령으로 확인하고, 구독은 앞에서 확인한 `az account show`의 결과와 대조합니다. 이미 설정된 값은 다시 묻지 않을 수 있습니다.

```bash
azd env get-value AZURE_SUBSCRIPTION_ID
azd env get-value AZURE_LOCATION
```

값이 설정되지 않았다면 대화형 프로비저닝에서 선택을 요청할 수 있습니다. 선택 질문이 반드시 나온다고 가정하지 말고, 승인한 대상이 불분명하면 진행하지 않습니다.

```bash
azd provision
```

### 리소스 확인

리소스 프로비저닝에 성공했다면 앱 루트에서 리소스 그룹 이름을 확인하고, 두 번째 명령의 `<리소스-그룹-이름>`을 확인한 값으로 바꿔 실행합니다.

```bash
azd env get-value AZURE_RESOURCE_GROUP
az resource list --resource-group "<리소스-그룹-이름>" --query "[].{name:name,type:type}" --output table
```

목록을 [실습 5: azd 배포 산출물 준비하기](05-prepare-azd.md)에서 승인한 리소스와 대조합니다. 이름이 비어 있거나 필요한 리소스가 없으면 원인을 파악하고 문제를 해결합니다. 또한 리소스 프로비저닝이 실패했다면 원인을 파악하고 문제를 해결합니다.

### DB 초기화

앱 루트에서 실습 5에서 검토한 DB 초기화 안내(예: `infra/db/README.md`)와 스크립트를 확인합니다. 승인한 새 데모 DB만 대상으로 하며, 안내나 대상과 권한이 불분명하면 중단합니다. 기존 DB나 호환되지 않는 스키마가 있다면 DB 소유자와 확인합니다.

서버의 Entra 인증과 관리자, DB 이름, web/worker 및 마이그레이션 관리 ID, 실행 호스트의 DB 접근과 TLS 인증서 신뢰를 확인합니다. 각 연결에 사용할 PostgreSQL용 Entra 토큰은 [Entra 인증 안내](https://learn.microsoft.com/en-us/azure/postgresql/security/security-entra-configure)와 [관리 ID 연결 안내](https://learn.microsoft.com/en-us/azure/postgresql/security/security-connect-with-managed-identity)를 참고해 발급합니다. 토큰을 명령 인자, 셸 기록, 저장소나 로그에 남기지 말고, 재연결 시 만료되었다면 다시 발급합니다.

다음은 `infra/db/bootstrap-identities.sql`과 `infra/db/initialize-image-metadata.sql`을 검토한 경우의 예시입니다. 산출물이 다르면 승인한 초기화 절차를 따릅니다. Azure RBAC와 DB 내부 권한은 별개입니다.

1. **Entra 관리자:** `postgres` DB에 principal과 연결 권한을 설정합니다. 승인된 로컬 개발자 계정이 서버의 Entra 관리자일 때만 이 계정을 사용할 수 있습니다. 앱 루트에서 `<서버-FQDN>`과 `<Entra-관리자-이름>`을 바꿔 실행하고, 프롬프트에 web, worker, 마이그레이션 관리 ID와 앱 DB 이름을 입력합니다.

   ```bash
   psql "host=<서버-FQDN> dbname=postgres sslmode=verify-full" --username "<Entra-관리자-이름>" --file "infra/db/bootstrap-identities.sql"
   ```

2. **마이그레이션 관리 ID:** 관리자 인증을 종료하고 이 ID가 연결된 승인된 호스트에서 별도로 인증합니다. DB에 접근할 수 있는 해당 호스트의 앱 루트에서 `<서버-FQDN>`, `<앱-DB-이름>`과 `<마이그레이션-관리-ID-이름>`을 바꿔 실행하고, 프롬프트에 web과 worker 관리 ID 이름을 입력합니다.

   ```bash
   psql "host=<서버-FQDN> dbname=<앱-DB-이름> sslmode=verify-full" --username "<마이그레이션-관리-ID-이름>" --file "infra/db/initialize-image-metadata.sql"
   ```

이 ID가 테이블을 만들고 소유하며 앱에는 연결하지 않습니다. web과 worker에는 스키마 생성이나 테이블 변경 권한을 부여하지 않습니다. 이 예시는 기존 데이터 이전이나 스키마 업그레이드를 수행하지 않습니다.

실패하면 일부 변경이 적용됐을 수 있으므로 DB 상태를 확인하고 원인을 해결해 해당 작업을 완료한 뒤 다음 단계로 진행합니다.

초기화 후 DB에 접근할 수 있는 호스트에서 위 인증 안내에 따라 승인된 주체의 Entra 토큰을 `PGPASSWORD`로 전달합니다. `<서버-FQDN>`, `<앱-DB-이름>`과 `<DB-사용자-이름>`을 해당 주체의 값으로 바꿔 앱 DB에 연결합니다.

```bash
psql "host=<서버-FQDN> dbname=<앱-DB-이름> sslmode=verify-full" --username "<DB-사용자-이름>"
```

연결된 `psql`에서 DB, 로그인 주체(`session_user`), 현재 역할(`current_user`), 역할과 권한을 확인합니다.

```sql
SELECT current_database(), session_user, current_user;
\du
\dt
\dp
```

위 예시를 사용했다면 같은 `psql` 세션에서 web과 worker의 DB 역할 이름을 입력해 유효 권한과 테이블 소유자를 확인합니다. 유효 권한에는 역할 상속과 `PUBLIC`이 포함됩니다.

```sql
\prompt 'Web DB role: ' web_role
\prompt 'Worker DB role: ' worker_role
SELECT role_name,
       has_table_privilege(role_name, 'public.image_metadata', 'SELECT') AS can_select,
       has_table_privilege(role_name, 'public.image_metadata', 'INSERT') AS can_insert,
       has_table_privilege(role_name, 'public.image_metadata', 'UPDATE') AS can_update,
       has_table_privilege(role_name, 'public.image_metadata', 'DELETE') AS can_delete,
       has_schema_privilege(role_name, 'public', 'CREATE') AS can_create
FROM (VALUES (:'web_role'), (:'worker_role')) AS apps(role_name);

SELECT pg_get_userbyid(relowner) AS table_owner
FROM pg_class
WHERE oid = to_regclass('public.image_metadata');
```

web은 네 테이블 권한이 모두 `true`, worker는 조회와 수정만 `true`여야 합니다. 두 역할의 `can_create`는 `false`, 테이블 소유자는 마이그레이션 관리 ID여야 합니다. `\du`와 `\dp`에서도 예상하지 않은 역할 상속이나 권한이 없는지 확인합니다.

결과를 검토한 초기화 절차의 대상과 권한에 대조하고 기록합니다. 확인할 수 없거나 승인한 범위와 다르면 해결하기 전까지 배포하지 않습니다. 앱 관리 ID 인증과 앱 연결은 배포 후 별도로 확인합니다.

확인을 마치면 `\q`로 `psql`을 종료합니다. 연결 실패 또는 확인 후 토큰을 삭제합니다.

```bash
# zsh/bash
unset PGPASSWORD
```

```powershell
# PowerShell
Remove-Item Env:\PGPASSWORD
```

### 이미지 패키징

앱 루트에서 web과 worker의 배포용 컨테이너 이미지를 Docker Engine으로 빌드합니다.

```text
azd package
```

로그에서 Docker Engine, `linux/amd64`, Java 25 이미지와 web/worker 각각의 빌드를 확인합니다. 실패했거나 빌드 결과를 확인하지 못했다면 원인을 해결하고 빌드 결과를 확인한 뒤 배포합니다.

### 배포

앱 루트에서 web과 worker 이미지를 게시하고 Azure Container Apps에 배포합니다.

```text
azd deploy
```

`azd deploy`는 다시 빌드할 수 있습니다. package 후 소스를 바꾸지 않고 실제 배포 이미지 tag/digest를 기록합니다. 이미지 게시와 앱 업데이트가 성공했는지 확인한 뒤 결과를 조회합니다.

```text
azd show
```

## 리소스 상태와 기능 확인

실습 5에서 정의한 출력 이름을 사용합니다. 값이 비어 있으면 추측하지 말고 `azd` 출력 계약과 Bicep 연결부터 고칩니다.

Windows:

```powershell
$rg = azd env get-value AZURE_RESOURCE_GROUP
$web = azd env get-value AZURE_WEB_APP_NAME
$worker = azd env get-value AZURE_WORKER_APP_NAME
az containerapp show --resource-group $rg --name $web --query "{state:properties.provisioningState,ready:properties.latestReadyRevisionName,fqdn:properties.configuration.ingress.fqdn}" --output json
az containerapp show --resource-group $rg --name $worker --query "{state:properties.provisioningState,ready:properties.latestReadyRevisionName,ingress:properties.configuration.ingress}" --output json
az containerapp logs show --resource-group $rg --name $worker --type console --tail 50
```

macOS와 Linux:

```bash
rg=$(azd env get-value AZURE_RESOURCE_GROUP)
web=$(azd env get-value AZURE_WEB_APP_NAME)
worker=$(azd env get-value AZURE_WORKER_APP_NAME)
az containerapp show --resource-group "$rg" --name "$web" \
  --query "{state:properties.provisioningState,ready:properties.latestReadyRevisionName,fqdn:properties.configuration.ingress.fqdn}" --output json
az containerapp show --resource-group "$rg" --name "$worker" \
  --query "{state:properties.provisioningState,ready:properties.latestReadyRevisionName,ingress:properties.configuration.ingress}" --output json
az containerapp logs show --resource-group "$rg" --name "$worker" --type console --tail 50
```

참가자가 실습 5에서 검토한 통합 검사를 직접 실행합니다. 로그 해석이 필요하면 Copilot app 채팅에 비밀을 제거한 결과와 다음 요청을 전달합니다.

```text
전달한 azd 출력과 통합 검사 결과를 검토해 줘. 구독이나 환경을 바꾸지 마.
web/worker 이미지 tag/digest, JDK 25, readiness와 ingress 설정의 근거를 확인해 줘.
DB TLS/관리 ID와 실제 권한, Service Bus 처리, Blob 비공개 검증의 누락을 찾아 줘.
실제 실행 결과와 미실행 항목을 구분하고 추가 검사 명령은 제시만 해 줘.
운영 데이터 삭제, 방화벽 전체 개방, RBAC 범위 확대는 하지 마.
오류가 있으면 비밀을 제거한 로그와 원인을 제시하고 필요한 변경 승인을 기다려 줘.
```

Java 명령을 추가로 맡길 때는 실제 앱 루트의 같은 셸에서 Windows는 `. ../scripts/use-java.ps1 -Jdk 25`, macOS와 Linux는 `source ../scripts/use-java.sh --jdk 25`를 먼저 적용하도록 요청합니다. 코드 수정이 필요하면 별도의 제한된 복구 계획을 검토한 뒤 실행합니다.

참가자는 `azd show`의 **web URL**을 브라우저에서 열고 실습 1과 같은 개인 정보 없는 이미지와 입력으로 확인합니다. DB 메타데이터 기록과 조회, Blob 저장과 조회, Service Bus 수신과 worker 처리 결과가 모두 연결되어야 합니다. DB 메타데이터는 원본 `dev` 기준선에 없던 동작이며, `dev` 외 S3 구현에서 이전한 기능으로 구분해 기록합니다. private Blob URL을 익명 요청했을 때 파일이 그대로 공개되지 않는지도 확인합니다.

단위 테스트만 통과하거나 HTTP 200만 나온 것은 완료가 아닙니다. 로컬 파일에 의존하지 않는지, 신규 revision에서 같은 업로드를 다시 조회할 수 있는지도 확인합니다. 강제 프로세스 종료가 아닌 정상적인 재배포/새 revision을 이용해 검증하며 추가 비용을 확인합니다.

## 완료 기준과 문제 해결

web/worker의 정상 revision과 실제 사용자 기능이 확인되면 이번 배포의 이미지 식별자와 결과를 기록합니다. 권한 전파, DB 연결, 이미지 pull, worker 오류는 [문제 해결](08-troubleshooting.md)을 따릅니다. 실패한 배포도 리소스가 남을 수 있으므로 곧바로 [정리](07-cleanup.md) 범위를 확인합니다.
