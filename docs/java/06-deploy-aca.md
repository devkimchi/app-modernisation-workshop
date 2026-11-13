# 6. azd로 ACA에 배포하기

[전체 목차](../../README.md) | [Java 목차](README.md) | [이전: azd 준비](05-prepare-azd.md) | [다음: 정리](07-cleanup.md) | [문제 해결](08-troubleshooting.md)

## 목표와 시작 조건

검토와 승인이 끝난 산출물로 참가자가 직접 프로비저닝, **로컬 이미지 빌드**, 배포와 기능 검증을 수행합니다. 실행 위치는 Copilot app 터미널의 **앱 루트**입니다. Windows는 PowerShell 7, macOS와 Linux는 Bash 또는 Zsh를 사용합니다. 선택 엔진, JDK 25, 구독, 권한과 네트워크 경로를 확인합니다. Modernize 계획 실행에 실제 Azure 변경을 맡기지 않습니다.

## 환경 설정

Windows:

```powershell
$env:AZD_CONTAINER_RUNTIME = 'docker'
$env:AZD_NON_INTERACTIVE = 'false'
```

macOS와 Linux:

```bash
export AZD_CONTAINER_RUNTIME=docker
export AZD_NON_INTERACTIVE=false
```

다음 명령은 두 환경에서 같습니다. `<...>`를 실제 값으로 바꾸고 로그인 상태부터 확인합니다. 필요한 로그인은 참가자가 직접 수행합니다.

```text
azd version
azd auth login --check-status
az account show --query "{name:name,id:id}" --output table
azd env new "<개인별-고유-환경명>"
azd env set AZURE_SUBSCRIPTION_ID "<본인-구독-ID>"
azd env set AZURE_LOCATION "<지원되는-리전>"
```

기존 환경을 이어서 사용한다면 새로 만들지 않고 `azd env list`와 `azd env select "<환경명>"`을 사용합니다. `az account show`의 구독과 `azd env get-value AZURE_SUBSCRIPTION_ID`를 대조합니다. az와 azd의 로그인은 별개입니다. 다른 참가자의 환경이나 구독을 선택하지 않습니다. `.azure`에는 상태/설정이 저장되므로 커밋하거나 채팅에 전체 내용을 붙이지 않습니다.

azd는 실행 환경에 따라 자동 비대화형 모드가 될 수 있습니다. 설치본이 지원하는 `AZD_NON_INTERACTIVE=false`로 자동 감지를 해제하더라도 비용/데이터 승인이나 hook 검토를 대신하지는 않습니다. 승인 질문이 반드시 나온다고 가정하지 말고 각 명령 전에 범위를 직접 확인합니다.

## 프로비저닝, 패키징, 배포

각 명령이 성공하고 결과를 검토한 뒤 다음 명령을 실행합니다. 블록 전체를 무인 실행하지 않습니다. 모든 hooks를 읽고 설치본 `azd provision --help`에 `--preview`가 있으면 다음으로 변경을 미리 봅니다. 미리보기도 Azure 접근과 hook 실행을 포함할 수 있으며 비용 견적이나 데이터 안전 보장을 대신하지 않습니다.

```text
azd provision --preview
```

구독, 리전, SKU, 권한, 네트워크와 비용을 승인한 뒤 실제로 생성합니다.

```text
azd provision
```

생성된 리소스와 실패 지점을 확인합니다. 승인한 DB 초기화 절차로 Entra principal, DB 권한, 스키마와 migration을 준비합니다. ARM/Bicep 성공만으로 이 작업이 끝났다고 판단하지 않습니다. 로컬 개발자 ID로 수행할 DB 관리 작업과 ACA 앱 관리 ID의 권한을 구분하세요.

```text
azd package
```

명령 직후 Windows는 `$LASTEXITCODE`, macOS와 Linux는 `echo $?`로 종료 코드 `0`을 확인합니다. 로그에서 **선택한 로컬 엔진**, `linux/amd64`, Java 25 이미지와 web/worker 각각의 빌드를 확인합니다. 실패했거나 빌드 결과를 확인하지 못했다면 배포하지 않습니다.

```text
azd deploy
```

`azd deploy`는 다시 빌드할 수 있습니다. package 후 소스를 바꾸지 않고 실제 배포 이미지 tag/digest를 기록합니다. 이미지 게시와 앱 업데이트가 성공했는지 확인한 뒤 결과를 조회합니다.

```text
azd show
```

Docker가 멈췄다고 자동으로 다른 엔진이나 원격 빌드로 전환하지 않습니다. 대체 엔진이 필요하면 [문제 해결](08-troubleshooting.md#대체-엔진-설정)을 참고합니다.

`azd up`은 provision/package/deploy를 묶는 명령이지만 이번 실습은 실패 위치와 승인 범위를 알 수 있도록 단계별 실행이 기본입니다.

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
