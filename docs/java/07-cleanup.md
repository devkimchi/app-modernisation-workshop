# Java 7. 리소스와 로컬 실행 정리하기

[목차](README.md) | [이전: ACA 배포](06-deploy-aca.md) | [다음: 전체 목차](../../README.md) | [정리: 현재 문서](07-cleanup.md)

## 목표와 시작 조건

성공/실패 여부와 관계없이 실습에서 만든 유료 리소스를 확인하고 삭제합니다. **삭제할 환경과 리소스가 본인 실습용인지 먼저 확인**하세요. Azure 삭제는 복구할 수 없는 데이터를 포함할 수 있습니다. 필요한 가짜 테스트 결과만 기록하고 실제 데이터는 절대 섞지 않습니다.

실행 위치는 **앱 루트**, 셸은 **WSL2/macOS Bash**입니다. 생성하지 않은 리소스는 건드리지 않습니다.

## Azure 정리

각 코드 블록을 실행한 뒤 성공 여부와 출력을 확인하고 다음 블록으로 진행합니다. 실제 환경명으로 `<이번-실습-환경명>`을 바꿉니다.

```bash
azd env list
```

이번 실습 환경이 없거나 명령이 실패하면 다른 환경을 선택하지 않습니다. 리소스를 만들지 않았다면 Azure 정리를 건너뛰고 로컬 정리로 이동합니다. 프로비저닝 중 실패해 리소스가 남았을 가능성이 있다면 Azure Portal에서 정확한 환경명/태그/활동 로그로 찾습니다.

```bash
azd env select <이번-실습-환경명>
```

선택이 실패하거나 대상이 불분명하면 중단합니다. 이전에 선택된 환경을 대신 사용하지 않습니다. 선택한 환경의 구독 ID와 Azure CLI 구독 ID를 각각 확인합니다.

```bash
azd env get-value AZURE_SUBSCRIPTION_ID
```

```bash
az account show --query "{name:name,id:id}" --output table
```

두 구독이 승인한 본인 실습 구독과 다르거나 값을 확인하지 못하면 중단합니다. 다음 명령으로 리소스 그룹을 확인합니다.

```bash
rg=$(azd env get-value AZURE_RESOURCE_GROUP) && [ -n "$rg" ] && printf '리소스 그룹: %s\n' "$rg"
```

명령이 실패하거나 값이 비어 있으면 중단합니다.

```bash
az group show --name "$rg" --query "{name:name,id:id,tags:tags}" --output json
```

```bash
az resource list --resource-group "$rg" --query "[].{name:name,type:type}" --output table
```

위 명령이 모두 성공했고 구독, 그룹과 리소스가 삭제를 승인한 본인 실습 대상인지 확인한 경우에만 다음 명령을 실행합니다. 공유 리소스, 다른 환경 또는 기존 서비스가 포함되어 있으면 실행하지 않습니다. 삭제 확인 메시지도 읽고 직접 승인합니다. `--force`/`--purge`를 기본으로 사용하지 않습니다.

```bash
azd down
```

삭제가 끝난 후 확인합니다.

```bash
az group exists --name "$rg"
```

새로 만든 전용 리소스 그룹이라면 최종적으로 `false`인지 확인합니다. 기존 그룹을 재사용했거나 `azd`가 일부 리소스를 보존했다면 남은 항목을 별도로 확인합니다. 프로비저닝 중 실패해 환경 출력이 없다면 Azure Portal에서 확인하고 임의의 그룹을 삭제하지 않습니다.

별도 생성한 역할 할당, 네트워크, 저장소의 보존/soft-delete 정책과 비용도 확인합니다. 정리 실패를 숨기지 말고 소유자에게 남은 리소스 ID와 오류를 전달합니다. Azure가 사라지기 전에 `.azure`를 삭제하면 추적하기 어려워집니다.

## 로컬 정리

Podman 경로처럼 터미널 전경에서 실행한 web/worker는 해당 터미널에서 `Ctrl+C`로 종료합니다. 원본 Docker 스크립트의 백그라운드 프로세스는 로그/PID 파일 및 `ps`로 앱 경로와 PID를 대조한 뒤 **그 PID만** 종료합니다. 모든 Java 프로세스를 이름으로 종료하지 않습니다. `stopapp.sh`도 실행 전에 내용을 읽고 영향 범위를 확인합니다.

선택한 엔진이 원본을 실행한 엔진과 같은지 확인하고 컨테이너를 조회합니다.

```bash
engine="${AZD_CONTAINER_RUNTIME:-docker}"
"$engine" inspect assets-postgres assets-rabbitmq
```

조회가 실패하거나 **이 실습에서 생성한 컨테이너인지 확인하지 못했다면** 중단합니다. 확인한 컨테이너만 정지합니다. 다음 단계에서 DB/큐의 실습 데이터가 삭제됩니다.

```bash
"$engine" stop assets-postgres assets-rabbitmq
```

정지가 성공했는지 확인한 뒤 해당 컨테이너를 삭제합니다.

```bash
"$engine" rm assets-postgres assets-rabbitmq
```

전체 엔진의 `system prune`, 모든 볼륨 삭제, Podman machine 삭제는 하지 않습니다. 내려받은 앱 폴더와 Git 기준선은 남겨도 되며, 스크립트가 이를 자동 삭제하지 않습니다.

## 완료 기준과 문제 해결

Azure 유료 리소스가 삭제되었거나 보존 대상/비용 책임자가 명확하고, 실습 프로세스/컨테이너가 정지되어야 합니다. 로컬 설정과 로그에 민감한 값이 남지 않았는지 확인하세요. 삭제 권한이나 잠금 때문에 실패하면 [문제 해결](../troubleshooting.md)을 참고합니다.
