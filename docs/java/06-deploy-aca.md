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
| 실습 6: azd로 ACA에 배포하기 (이 문서) | 승인 후 Azure 리소스 프로비저닝, DB 초기화, 로컬 이미지 빌드, 배포와 실제 기능 확인 | 승인하지 않은 리소스나 데이터 변경 |

## 실습 전 확인 사항

[실습 5: azd 배포 산출물 준비하기](05-prepare-azd.md)에서 산출물을 검토하고 승인한 뒤, 같은 Copilot app 터미널의 **앱 루트**를 사용합니다.

로컬 이미지 빌드를 위해 Docker Engine을 실행하고 `docker info`로 연결을 확인합니다.

> [!NOTE]
> 다른 컨테이너 빌드 엔진을 사용하려면 [8. 문제 해결: 대체 엔진 설정](08-troubleshooting.md#대체-엔진-설정)을 참고합니다.

DB 초기화에 사용할 PostgreSQL 클라이언트도 확인합니다. 명령을 찾을 수 없다면 [준비: PostgreSQL 클라이언트 설치](00-setup.md#postgresql-클라이언트-설치)에 따라 설치하거나 실행 경로를 설정한 뒤 진행합니다.

```bash
psql --version
```

## 환경 설정

현재 셸에서 Docker Engine을 사용하도록 설정합니다. 설치된 azd가 지원하면 자동 비대화형 모드 감지도 해제합니다.

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

앱 배포 환경을 만듭니다. `<...>`를 실제 값으로 바꿉니다(예: `contoso-asset-manager`).

```bash
azd env new "<개인별-고유-환경명>"
```

## 프로비저닝, 패키징, 배포

각 명령이 성공하고 결과를 검토한 뒤 다음 명령을 실행합니다. 블록 전체를 무인 실행하지 않습니다.

> [!NOTE]
> `azd up`은 프로비저닝, 패키징, 배포를 묶어 실행합니다. 이번 실습에서는 실패한 단계와 승인 범위를 알 수 있도록 각 명령을 따로 실행합니다.

### 리소스 프로비저닝

[실습 5: azd 배포 산출물 준비하기](05-prepare-azd.md)에서 검토한 훅과 구독, 리전, SKU, 권한, 네트워크와 비용을 확인하고 승인합니다. 환경에 구독과 리전이 이미 설정되어 있다면 다음 명령으로 확인하고, 구독은 앞서 확인한 `az account show`의 결과와 대조합니다. 이미 설정된 값은 다시 묻지 않을 수 있습니다.

```bash
azd env get-value AZURE_SUBSCRIPTION_ID
azd env get-value AZURE_LOCATION
```

값이 설정되지 않았다면 대화형 프로비저닝에서 선택을 요청할 수 있습니다. 선택 질문이 반드시 나온다고 가정하지 말고 승인한 대상이 불분명하면 진행하지 않습니다.

```bash
azd provision
```

### 리소스 확인

리소스 프로비저닝에 성공했다면 앱 루트에서 리소스 그룹 이름을 읽어 리소스 목록을 확인합니다.

```bash
# zsh/bash
rg=$(azd env get-value AZURE_RESOURCE_GROUP)
az resource list --resource-group "$rg" --query "[].{name:name,type:type}" --output table
```

```powershell
# PowerShell
$rg = azd env get-value AZURE_RESOURCE_GROUP
az resource list --resource-group $rg --query "[].{name:name,type:type}" --output table
```

목록을 [실습 5: azd 배포 산출물 준비하기](05-prepare-azd.md)에서 승인한 리소스와 대조합니다. 이름이 비어 있거나 필요한 리소스가 없으면 원인을 파악해 해결합니다. 프로비저닝이 실패한 경우에도 원인을 파악해 해결합니다.

### DB 방화벽에 클라이언트 IP 등록

공개 네트워크로 PostgreSQL에 연결하려면 DB 초기화 전에 **접속할 PC의 공인 IPv4 주소**를 서버 방화벽에 등록합니다. `192.168.x.x` 같은 사설 IP나 DB 서버의 IP가 아닌, 서버에서 접속 출발지로 인식하는 주소여야 합니다. 사설 네트워크를 사용한다면 공개 접근을 켜지 말고 승인한 사설 연결 경로를 확인합니다.

Azure Portal에서 대상 PostgreSQL 서버의 **네트워킹**을 열고 **현재 클라이언트 IP 추가**에 표시된 주소를 확인합니다. VPN이나 회사 프록시를 사용하면 브라우저와 DB 접속의 공인 IP가 다를 수 있습니다. 확실하지 않으면 네트워크 관리자에게 확인하세요. 외부 IP 조회 서비스를 따로 사용할 필요는 없습니다.

> [!NOTE]
> 터미널에서 [ipify](https://www.ipify.org)의 API로 공인 IPv4 주소를 확인할 수도 있습니다. **Microsoft나 Azure가 운영하지 않는 외부 서비스**이며, 조회 시 공인 IP와 요청 정보가 해당 서비스에 전달됩니다. 조직의 외부 서비스 사용 정책을 확인한 뒤 필요한 경우에만 사용하세요.
>
> ```bash
> # zsh/bash
> clientIp=$(curl -4 --fail --silent --show-error --max-time 10 https://api.ipify.org)
> ```
>
> ```powershell
> # PowerShell
> $clientIp = (Invoke-RestMethod -Uri "https://api.ipify.org" -TimeoutSec 10).Trim()
> ```
>
> 조회 결과가 실제 DB 접속의 송신 IP와 같은지 확인한 뒤 아래 `<확인한-공인-IPv4>`에 입력합니다. VPN이나 프록시 환경에서는 다를 수 있으므로 결과를 확인 없이 자동 등록하지 마세요.

서버와 IP 주소를 확인하고 변경을 승인한 뒤 Portal에서 저장하거나 앱 루트에서 아래 명령을 실행합니다. 방화벽 규칙을 조회하고 변경할 권한이 필요합니다. `<확인한-공인-IPv4>`를 확인한 주소로 바꾸고, 조회에 실패하거나 값이 비어 있으면 중단하세요. **Azure 서비스 전체 허용**을 켜거나 모든 IP를 허용하지 마세요.

```bash
# zsh/bash
subscription=$(azd env get-value AZURE_SUBSCRIPTION_ID)
rg=$(azd env get-value AZURE_RESOURCE_GROUP)
server=$(azd env get-value POSTGRESQL_SERVER)
clientIp="<확인한-공인-IPv4>"
ruleName="allow-local-$(date +%Y%m%d%H%M%S)"
az postgres flexible-server firewall-rule create --subscription "$subscription" --resource-group "$rg" --server-name "$server" --name "$ruleName" --start-ip-address "$clientIp" --end-ip-address "$clientIp"
az postgres flexible-server firewall-rule list --subscription "$subscription" --resource-group "$rg" --server-name "$server" --output table
```

```powershell
# PowerShell
$subscription = azd env get-value AZURE_SUBSCRIPTION_ID
$rg = azd env get-value AZURE_RESOURCE_GROUP
$server = azd env get-value POSTGRESQL_SERVER
$clientIp = "<확인한-공인-IPv4>"
$ruleName = "allow-local-$(Get-Date -Format yyyyMMddHHmmss)"
az postgres flexible-server firewall-rule create --subscription $subscription --resource-group $rg --server-name $server --name $ruleName --start-ip-address $clientIp --end-ip-address $clientIp
az postgres flexible-server firewall-rule list --subscription $subscription --resource-group $rg --server-name $server --output table
```

규칙의 시작과 끝 IP가 같고 승인한 주소만 허용했는지 확인합니다. 적용까지 몇 분 걸릴 수 있습니다. 계속 연결 시간이 초과되면 PC가 연결된 네트워크에서 외부로 나가는 TCP 5432 포트를 차단하는지도 확인합니다. 방화벽을 허용해도 DB 인증과 권한 설정은 별도로 필요합니다.

공인 IP가 바뀌면 새 주소를 확인해 등록하고, 기존 규칙은 별도 승인 후 삭제합니다. 위 규칙은 해당 PC에만 적용됩니다. 마이그레이션 관리 ID를 사용하는 별도 호스트와 ACA의 DB 연결 경로도 각각 확인하고 승인한 주소만 허용해야 합니다. ACA 수신 IP를 송신 IP로 등록하지 마세요.

### DB 연결용 루트 인증서 준비

`psql`의 `sslmode=verify-full`은 서버 인증서와 호스트 이름을 검증합니다. DB에 연결할 셸에서 [Azure PostgreSQL이 사용하는 루트 CA](https://learn.microsoft.com/en-us/azure/postgresql/security/security-tls#root-cas-used-by-azure-database-for-postgresql)를 내려받아 PEM 파일로 준비하고, `PGSSLROOTCERT`에 파일 경로를 지정합니다. 아래 예시는 임시 파일을 사용하며 시스템 인증서 저장소나 기존 `root.crt`를 변경하지 않습니다.

macOS와 Linux/WSL에서는 `curl`과 `openssl`이 필요합니다. 아래 명령은 다운로드한 DER 인증서 두 개를 PEM 형식으로 변환해 하나로 합칩니다.

```bash
pgCaDir=$(mktemp -d) &&
curl --fail --silent --show-error --location --max-time 30 --output "$pgCaDir/digicert.der" "https://cacerts.digicert.com/DigiCertGlobalRootG2.crt" &&
curl --fail --silent --show-error --location --max-time 30 --output "$pgCaDir/microsoft.der" "https://www.microsoft.com/pkiops/certs/Microsoft%20RSA%20Root%20Certificate%20Authority%202017.crt" &&
openssl x509 -inform DER -in "$pgCaDir/digicert.der" -out "$pgCaDir/digicert.pem" &&
openssl x509 -inform DER -in "$pgCaDir/microsoft.der" -out "$pgCaDir/microsoft.pem" &&
cat "$pgCaDir/digicert.pem" "$pgCaDir/microsoft.pem" > "$pgCaDir/azure-postgresql-roots.pem" &&
export PGSSLROOTCERT="$pgCaDir/azure-postgresql-roots.pem"
```

Windows에서는 PowerShell 7에서 실행합니다. 별도 OpenSSL 설치는 필요하지 않습니다.

```powershell
$caUrls = @(
    "https://cacerts.digicert.com/DigiCertGlobalRootG2.crt"
    "https://www.microsoft.com/pkiops/certs/Microsoft%20RSA%20Root%20Certificate%20Authority%202017.crt"
)

$pemCertificates = foreach ($url in $caUrls) {
    $response = Invoke-WebRequest -Uri $url -TimeoutSec 30 -ErrorAction Stop
    $certificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new(
        [byte[]]$response.Content
    )
    try {
        $base64 = [Convert]::ToBase64String(
            $certificate.RawData,
            [Base64FormattingOptions]::InsertLineBreaks
        )
        "-----BEGIN CERTIFICATE-----`n$base64`n-----END CERTIFICATE-----"
    }
    finally {
        $certificate.Dispose()
    }
}

$caFile = New-TemporaryFile -ErrorAction Stop
Set-Content -LiteralPath $caFile.FullName -Value $pemCertificates -Encoding ascii -ErrorAction Stop
$env:PGSSLROOTCERT = $caFile.FullName
```

오류가 나면 다음 단계로 진행하지 마세요. 설정한 경로는 현재 셸과 여기서 실행한 `psql`에 적용됩니다. DB 초기화와 확인도 같은 셸에서 진행하고, 마이그레이션 관리 ID를 사용하는 별도 호스트에서도 인증서를 준비합니다. 새 셸을 열거나 임시 파일이 삭제되면 다시 준비하세요.

`root certificate file ... does not exist`는 루트 인증서 파일이 없다는 뜻입니다. `certificate verify failed`가 나타나면 지정한 PEM 파일과 서버 FQDN을 확인합니다. `sslrootcert=system`도 Windows의 `psql` 배포판에 따라 검증에 실패할 수 있으므로, 이 예시에서는 해당 옵션을 넣지 않고 `PGSSLROOTCERT`를 사용합니다. `sslmode=verify-full`은 유지하고 인증서 검증을 끄지 마세요.

### DB 초기화

앱 루트에서 [실습 5: azd 배포 산출물 준비하기](05-prepare-azd.md)에서 검토한 DB 초기화 안내(예: `infra/db/README.md`)와 스크립트를 확인합니다. 승인한 새 데모 DB만 대상으로 합니다. 안내, 대상 또는 권한이 불분명하면 중단하고, 기존 DB나 호환되지 않는 스키마가 있다면 DB 소유자와 확인합니다.

서버의 Entra 인증과 관리자, DB 이름, web/worker와 마이그레이션 관리 ID를 확인합니다. 실행 호스트에서 DB에 접근할 수 있는지, TLS 인증서를 신뢰할 수 있는지도 확인합니다. 각 연결에 사용할 PostgreSQL용 Entra 토큰은 [Entra 인증 안내](https://learn.microsoft.com/en-us/azure/postgresql/security/security-entra-configure)와 [관리 ID 연결 안내](https://learn.microsoft.com/en-us/azure/postgresql/security/security-connect-with-managed-identity)를 참고해 발급합니다. 토큰을 명령 인자, 셸 기록, 저장소나 로그에 남기지 말고 재연결 시 만료되었다면 다시 발급합니다.

다음은 `infra/db/bootstrap-identities.sql`과 `infra/db/initialize-image-metadata.sql`을 검토한 경우의 예시입니다. 산출물이 다르면 승인한 초기화 절차를 따릅니다. Azure RBAC와 DB 내부 권한은 별개입니다. 조회 명령은 순서대로 실행하고, 오류나 빈 값이 나오면 다음 명령을 실행하지 마세요.

1. **Entra 관리자:** `postgres` DB에 보안 주체와 연결 권한을 설정합니다. 승인된 로컬 개발자 계정이 서버의 Entra 관리자일 때만 이 계정을 사용할 수 있습니다. 앱 루트에서 azd 환경과 Azure CLI의 구독이 같은지 확인한 뒤 실행합니다. 조회한 관리자 이름과 서버 FQDN이 승인한 대상인지 확인하고, SQL 프롬프트에는 web, worker, 마이그레이션 관리 ID와 앱 DB 이름을 입력합니다.

   ```bash
   # zsh/bash
   subscription=$(azd env get-value AZURE_SUBSCRIPTION_ID)
   rg=$(azd env get-value AZURE_RESOURCE_GROUP)
   server=$(azd env get-value POSTGRESQL_SERVER)
   pgHost=$(az postgres flexible-server show --subscription "$subscription" --resource-group "$rg" --name "$server" --query fullyQualifiedDomainName --output tsv)
   pgAdmin=$(azd env get-value POSTGRESQL_ADMIN_NAME)
   PGPASSWORD=$(az account get-access-token --resource-type oss-rdbms --query accessToken --output tsv) &&
   export PGPASSWORD &&
   psql "host=$pgHost dbname=postgres sslmode=verify-full" --username "$pgAdmin" --file "infra/db/bootstrap-identities.sql"
   unset PGPASSWORD
   ```

   ```powershell
   # PowerShell
   $subscription = azd env get-value AZURE_SUBSCRIPTION_ID
   $rg = azd env get-value AZURE_RESOURCE_GROUP
   $server = azd env get-value POSTGRESQL_SERVER
   $pgHost = az postgres flexible-server show --subscription $subscription --resource-group $rg --name $server --query fullyQualifiedDomainName --output tsv
   $pgAdmin = azd env get-value POSTGRESQL_ADMIN_NAME
   $env:PGPASSWORD = az account get-access-token --resource-type oss-rdbms --query accessToken --output tsv
   if ($LASTEXITCODE -ne 0) { throw "PostgreSQL token acquisition failed." }
   psql "host=$pgHost dbname=postgres sslmode=verify-full" --username $pgAdmin --file "infra/db/bootstrap-identities.sql"
   Remove-Item Env:\PGPASSWORD
   ```

2. **마이그레이션 관리 ID:** 관리자 연결을 종료하고 이 ID가 연결된 승인된 호스트에서 별도로 인증합니다. 해당 호스트에 같은 azd 환경의 비밀이 아닌 출력값과 앱 파일이 준비되어 있어야 합니다. DB에 접근할 수 있는 호스트의 앱 루트에서 아래 값을 먼저 조회합니다. Azure 조회 권한이 없다면 권한을 임의로 추가하지 말고 승인된 조회 주체가 확인한 값을 안전하게 전달합니다. `az login --identity`는 Azure CLI 로그인 주체를 마이그레이션 ID로 바꾸므로 해당 호스트에서만 실행합니다. SQL 프롬프트에는 web과 worker 관리 ID 이름을 입력합니다.

   ```bash
   # zsh/bash
   subscription=$(azd env get-value AZURE_SUBSCRIPTION_ID)
   rg=$(azd env get-value AZURE_RESOURCE_GROUP)
   server=$(azd env get-value POSTGRESQL_SERVER)
   pgDatabase=$(azd env get-value POSTGRESQL_DATABASE)
   pgUser=$(azd env get-value MIGRATION_IDENTITY_NAME)
   pgHost=$(az postgres flexible-server show --subscription "$subscription" --resource-group "$rg" --name "$server" --query fullyQualifiedDomainName --output tsv)
   migrationClientId=$(az identity show --subscription "$subscription" --resource-group "$rg" --name "$pgUser" --query clientId --output tsv)
   az login --identity --client-id "$migrationClientId" --allow-no-subscriptions --output none &&
   PGPASSWORD=$(az account get-access-token --resource-type oss-rdbms --query accessToken --output tsv) &&
   export PGPASSWORD &&
   psql "host=$pgHost dbname=$pgDatabase sslmode=verify-full" --username "$pgUser" --file "infra/db/initialize-image-metadata.sql"
   unset PGPASSWORD
   ```

   ```powershell
   # PowerShell
   $subscription = azd env get-value AZURE_SUBSCRIPTION_ID
   $rg = azd env get-value AZURE_RESOURCE_GROUP
   $server = azd env get-value POSTGRESQL_SERVER
   $pgDatabase = azd env get-value POSTGRESQL_DATABASE
   $pgUser = azd env get-value MIGRATION_IDENTITY_NAME
   $pgHost = az postgres flexible-server show --subscription $subscription --resource-group $rg --name $server --query fullyQualifiedDomainName --output tsv
   $migrationClientId = az identity show --subscription $subscription --resource-group $rg --name $pgUser --query clientId --output tsv
   az login --identity --client-id $migrationClientId --allow-no-subscriptions --output none
   if ($LASTEXITCODE -ne 0) { throw "Managed identity login failed." }
   $env:PGPASSWORD = az account get-access-token --resource-type oss-rdbms --query accessToken --output tsv
   if ($LASTEXITCODE -ne 0) { throw "PostgreSQL token acquisition failed." }
   psql "host=$pgHost dbname=$pgDatabase sslmode=verify-full" --username $pgUser --file "infra/db/initialize-image-metadata.sql"
   Remove-Item Env:\PGPASSWORD
   ```

마이그레이션 관리 ID는 테이블을 만들고 소유하며 앱에는 연결하지 않습니다. web과 worker에는 스키마 생성이나 테이블 변경 권한을 부여하지 않습니다. 이 예시는 기존 데이터 이전이나 스키마 업그레이드를 수행하지 않습니다.

실패하면 일부 변경이 적용됐을 수 있으므로 DB 상태를 확인하고 원인을 해결해 해당 작업을 완료한 뒤 다음 단계로 진행합니다.

초기화 후에는 2단계와 같은 호스트와 셸에서 조회한 변수와 마이그레이션 ID 인증을 사용해 앱 DB에 연결합니다. 토큰은 다시 발급하고, 조회 실패나 빈 값이 있으면 진행하지 마세요.

```bash
# zsh/bash
PGPASSWORD=$(az account get-access-token --resource-type oss-rdbms --query accessToken --output tsv) &&
export PGPASSWORD &&
psql "host=$pgHost dbname=$pgDatabase sslmode=verify-full" --username "$pgUser"
```

```powershell
# PowerShell
$env:PGPASSWORD = az account get-access-token --resource-type oss-rdbms --query accessToken --output tsv
if ($LASTEXITCODE -ne 0) { throw "PostgreSQL token acquisition failed." }
psql "host=$pgHost dbname=$pgDatabase sslmode=verify-full" --username $pgUser
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

결과를 앞서 검토한 초기화 절차의 대상과 권한에 대조해 기록합니다. 확인할 수 없거나 승인한 범위와 다르면 해결하기 전까지 배포하지 않습니다. 앱 관리 ID 인증과 앱 연결은 배포 후 별도로 확인합니다.

확인을 마치면 `\q`로 `psql`을 종료합니다. 연결에 실패했거나 확인을 마쳤다면 토큰을 삭제합니다.

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

```bash
azd package
```

로그에서 Docker Engine, `linux/amd64`, Java 25 이미지와 web/worker 각각의 빌드 결과를 확인합니다. 빌드에 실패했거나 결과를 확인하지 못했다면 원인을 해결하고 결과를 확인한 뒤 배포합니다.

### 배포

앱 루트에서 web과 worker 이미지를 게시하고 Azure Container Apps에 배포합니다.

```bash
azd deploy
```

`azd deploy`는 이미지를 다시 빌드할 수 있습니다. 패키징 후 소스를 바꾸지 않고 실제 배포된 이미지의 태그와 다이제스트를 기록합니다. 이미지 게시와 앱 업데이트가 성공했는지 확인한 뒤 결과를 조회합니다.

```bash
azd show
```

## 리소스 상태와 기능 확인

Azure 포털에서 앞서 확인한 리소스 그룹을 열고 web과 worker Container App을 각각 확인합니다.

1. **개요**와 **수정 버전 관리(Revision management)** 에서 배포 상태와 이번에 배포한 수정 버전의 준비 상태, web의 URL을 확인합니다.
2. **설정 → 수신(Ingress)** 에서 web과 worker의 수신 설정이 [실습 5: azd 배포 산출물 준비하기](05-prepare-azd.md)에서 검토한 구성과 일치하는지 확인합니다.
3. worker의 **모니터링 → 로그 스트림(Log stream) → 콘솔(Console)** 에서 처리 로그와 오류를 확인합니다. 수정 버전, 복제본 또는 컨테이너가 여러 개라면 해당 대상을 선택합니다.

터미널에서 확인하려면 다음 명령을 사용할 수도 있습니다. [실습 5: azd 배포 산출물 준비하기](05-prepare-azd.md)에서 정의한 출력 이름을 사용합니다. 값이 비어 있으면 추측하지 말고 `azd` 출력 계약과 Bicep 연결부터 수정합니다. 로그 명령은 worker의 최근 50줄을 조회합니다.

```bash
# zsh/bash
rg=$(azd env get-value AZURE_RESOURCE_GROUP)
web=$(azd env get-value AZURE_WEB_APP_NAME)
worker=$(azd env get-value AZURE_WORKER_APP_NAME)
az containerapp show --resource-group "$rg" --name "$web" \
  --query "{state:properties.provisioningState,ready:properties.latestReadyRevisionName,fqdn:properties.configuration.ingress.fqdn}" --output json
az containerapp show --resource-group "$rg" --name "$worker" \
  --query "{state:properties.provisioningState,ready:properties.latestReadyRevisionName,ingress:properties.configuration.ingress}" --output json
az containerapp logs show --resource-group "$rg" --name "$worker" --type console --tail 50
```

```powershell
# PowerShell
$rg = azd env get-value AZURE_RESOURCE_GROUP
$web = azd env get-value AZURE_WEB_APP_NAME
$worker = azd env get-value AZURE_WORKER_APP_NAME
az containerapp show --resource-group $rg --name $web --query "{state:properties.provisioningState,ready:properties.latestReadyRevisionName,fqdn:properties.configuration.ingress.fqdn}" --output json
az containerapp show --resource-group $rg --name $worker --query "{state:properties.provisioningState,ready:properties.latestReadyRevisionName,ingress:properties.configuration.ingress}" --output json
az containerapp logs show --resource-group $rg --name $worker --type console --tail 50
```

### Azure 통합 테스트 실행

[실습 4: Azure 서비스로 의존성 이전하기](04-migrate-azure-services.md#azure-통합-테스트-준비)에서 준비한 테스트는 실제 Azure의 DB, Service Bus와 Blob에 연결해 데이터를 읽고 씁니다. 로컬 실행 주체의 권한을 사용하므로 이 결과만으로 web이나 worker의 관리 ID 인증을 증명할 수 없습니다.

1. [실습 4: Azure 서비스로 의존성 이전하기](04-migrate-azure-services.md#azure-통합-테스트-준비)에서 생성한 테스트, `azure-it` 프로필, 실행 스크립트와 안내를 검토합니다. 테스트나 스크립트가 없거나 연결이 불분명하면 해당 실습을 보완하고 진행하지 않습니다.
2. 테스트 대상과 주체를 [실습 5: azd 배포 산출물 준비하기](05-prepare-azd.md)에서 검토한 출력과 DB 초기화 안내에 대조합니다. Azure CLI 사용자에게 DB, Blob과 테스트 전용 큐의 최소 데이터 권한이 있는지 확인합니다. 네트워크 경로가 확보됐는지, PostgreSQL TLS 인증서를 신뢰할 수 있는지도 확인합니다. 앱 큐 출력이 실제 배포 설정과 일치하는지 확인하고 앱 큐와 다른 전용 큐만 사용합니다.

   Azure CLI 사용자 이름이 해당 PostgreSQL DB 사용자 이름과 다르거나 대상, 권한, 비용 또는 데이터 변경 범위가 불분명하면 실행하지 않습니다. 리소스나 권한이 없으면 필요한 범위와 비용을 검토하고 별도 승인을 받습니다. 로그인 상태가 없거나 주체가 다르면 `az login`으로 승인된 사용자 계정에 로그인한 뒤 확인합니다. 서비스 주체의 DB 역할 이름은 추측하지 않습니다.
3. 앱 루트에서 현재 셸에 맞는 스크립트를 직접 실행합니다. 스크립트가 JDK 25를 선택하고 Azure CLI와 azd에서 대상을 조회합니다. 표시된 구독, 리소스, 사용자와 데이터 읽기 및 쓰기 범위를 앞서 검토한 비용과 함께 확인한 뒤 실행에 명시적으로 동의합니다. CI나 비대화형 환경에서는 실행할 수 없습니다.

   ```bash
   # zsh/bash
   ./scripts/run-azure-it.sh
   ```

   ```powershell
   # PowerShell
   ./scripts/run-azure-it.ps1
   ```

4. 종료 코드와 이번 실행의 테스트 보고서를 확인해 DB, Service Bus와 Blob 테스트의 실행 및 성공 여부를 각각 기록합니다. 프로필이 없거나 테스트가 실행되지 않았거나 건너뛴 경우는 성공이 아닙니다. 실패 또는 미검증 항목과 생성된 테스트 데이터의 식별자를 기록합니다. 데이터 정리는 범위와 영향을 확인하고 별도로 승인합니다.

### End-to-end 테스트 작성과 실행

배포된 앱에서 사용자의 업로드부터 결과 조회까지 확인하는 end-to-end 테스트를 준비합니다. 앱 루트에서 Copilot app 채팅에 다음을 요청합니다.

```text
현재 앱의 화면, 업로드 및 조회 흐름, 테스트 도구와 배포 설정을 읽고 배포된 web을 대상으로 하는 end-to-end 테스트를 작성해 줘.
기존 테스트 도구를 우선 사용하고 테스트 코드와 실행 안내만 준비해 줘. 앱 운영 코드, 배포 설정과 이미지는 변경하지 말고 실제 앱 접속이나 테스트 실행도 하지 마.

- 개인정보가 없는 테스트 이미지를 업로드하고 해당 입력을 식별해 처리 완료와 결과 조회까지 검증해 줘.
- 실제 앱과 검토된 배포 구성에 근거해 DB 메타데이터, 비공개 Blob, Service Bus와 worker 처리 결과를 확인하는 방법과 성공 조건을 제시해 줘. `dev` 기준선에 없던 DB 기록은 `dev` 외 S3 경로에서 이전한 동작으로 구분해 줘.
- 비동기 처리는 제한 시간과 실패 조건이 있는 확인 방법을 사용해 줘. HTTP 200이나 건너뛴 검사만으로 전체 성공을 표시하지 마.
- 비공개 Blob의 익명 접근이 거부되는지 확인하되, 권한 있는 조회와 구분해 줘. 오류나 연결 실패를 접근 제어 성공으로 처리하지 마.
- 테스트별 고유 식별자를 사용하고 기존 데이터나 메시지를 수정하거나 삭제하지 마. 자동 정리는 하지 말고 테스트 데이터와 별도 정리 방법을 안내해 줘.
- 실행 대상 URL, 실행 주체, 필요한 권한, 네트워크, 읽기와 쓰기 범위, 비용과 필수 설정을 명시해 줘. 대상이 없거나 확인할 수 없으면 실패하거나 미검증으로 표시해 줘.
- 앱 루트에서 Windows PowerShell과 WSL/Linux의 Bash 및 macOS의 zsh/bash 각각으로 실행할 정확한 준비 및 실행 명령, 결과 확인과 실패 시 조치를 제시해 줘. 값이 없는 대상은 임의로 채우지 마.
- 비밀정보와 서명된 URL을 코드, 명령 인자, 로그나 Git에 넣지 마. 의존성이나 브라우저 설치가 필요하면 설치하지 말고 필요한 항목을 보고해 줘.
- 실제 Azure 연결, 데이터 변경, 배포, 테스트 실행과 도구 설치는 하지 마. 변경 파일과 검증하지 못한 항목을 보고해 줘.
```

코드와 안내의 앱 흐름, 대상과 권한, 데이터 범위와 성공 조건을 확인합니다. 도구 설치는 별도로 결정합니다. 승인된 환경에서 구독, web URL, 실행 주체, 비용과 데이터 변경 범위를 확인하고 승인한 뒤 셸에 맞는 준비와 실행 명령을 직접 실행합니다. 미확인 항목은 미검증으로 기록하고 테스트 데이터는 별도 승인 후 정리합니다.

### 결과 검토

로그 해석이 필요하면 Copilot app 채팅에 비밀을 제거한 결과와 다음 요청을 전달합니다.

```text
전달한 azd 출력, 리소스 상태와 통합 및 end-to-end 테스트 결과를 검토해 줘. 구독이나 환경을 바꾸지 마.
web/worker 이미지의 태그와 다이제스트, JDK 25, 준비 상태와 수신 설정의 근거를 확인해 줘.
DB TLS/관리 ID와 실제 권한, Service Bus 처리, Blob 비공개 검증의 누락을 찾아 줘.
실제 실행 결과와 미실행 항목을 구분하고 추가 검사 명령은 제시만 해 줘.
운영 데이터 삭제, 방화벽 전체 개방, RBAC 범위 확대는 하지 마.
오류가 있으면 비밀을 제거한 로그와 원인을 제시하고 필요한 변경 승인을 기다려 줘.
```

Java 명령을 추가로 맡길 때는 앱 루트의 같은 셸에서 JDK 25를 먼저 선택하도록 요청합니다. Windows에서는 `. ../scripts/use-java.ps1 -Jdk 25`, macOS와 Linux에서는 `source ../scripts/use-java.sh --jdk 25`를 사용합니다. 코드 수정은 제한된 복구 계획을 검토한 뒤 실행합니다.

수동 확인이 필요하면 `azd show`의 **web URL**을 브라우저에서 열고 [실습 1: 원본 앱을 로컬에서 실행하기](01-run-locally.md)와 같은 개인 정보 없는 입력을 사용합니다. DB 메타데이터 기록과 조회, Blob 저장과 조회, Service Bus 수신과 worker 처리가 연결되는지 확인합니다. DB 메타데이터는 원본 `dev`에 없던 동작이므로 `dev` 외 S3 구현에서 이전한 기능으로 구분해 기록합니다. 비공개 Blob URL의 익명 요청으로 파일이 공개되지 않는지도 확인합니다.

단위 테스트 통과나 HTTP 200만으로는 완료가 아닙니다. 로컬 파일에 의존하지 않고 새 수정 버전에서도 같은 업로드를 조회할 수 있는지 확인합니다. 강제 종료 대신 정상 재배포나 새 수정 버전으로 검증하고 추가 비용을 확인합니다.

## 완료 및 다음 단계

- [ ] 승인한 리소스와 web/worker의 정상 수정 버전을 확인하고 이미지 식별자와 배포 결과를 기록했습니다.
- [ ] Azure 통합 테스트와 end-to-end 테스트 결과로 실제 사용자 기능을 확인하고 미검증 항목을 구분해 기록했습니다.
- [ ] 로컬 파일에 의존하지 않고 새 수정 버전에서도 업로드를 조회할 수 있는지 확인했습니다.

위 항목을 모두 마쳤다면 [7. 리소스와 로컬 실행 정리하기](07-cleanup.md)로 이동합니다.
