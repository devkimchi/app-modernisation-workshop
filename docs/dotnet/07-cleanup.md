# .NET 7. 리소스와 로컬 실행 정리하기

[목차](README.md) | [이전: ACA 배포](06-deploy-aca.md) | [다음: 전체 목차](../../README.md) | [정리: 현재 문서](07-cleanup.md)

## 목표와 시작 조건

배포 성공 여부와 관계없이 실습에서 만든 자원을 확인하고 정리합니다. 삭제할 환경, 리소스 그룹, DB와 큐가 **본인 실습 전용**인지 먼저 확인합니다. 공유 리소스가 있으면 삭제를 승인하지 마세요.

실행 위치는 **앱 루트**, 셸은 **Windows PowerShell 7**입니다. Azure 삭제는 복구할 수 없는 데이터를 포함할 수 있습니다.

## Azure 정리

```powershell
azd env list
azd env select <이번-실습-환경명>
az account show --query "{name:name,id:id}" --output table
$rg = azd env get-value AZURE_RESOURCE_GROUP
az group show --name $rg --query "{name:name,id:id,tags:tags}" --output json
az resource list --resource-group $rg --query "[].{name:name,type:type}" --output table
azd down
```

`azd down`의 삭제 확인 메시지를 읽고 직접 승인합니다. `--force`/`--purge`를 기본으로 사용하지 않습니다. 삭제가 끝난 후 확인합니다.

```powershell
az group exists --name $rg
```

이번에 새로 만든 전용 그룹이라면 최종적으로 `false`인지 확인합니다. 기존 그룹을 재사용했거나 일부 리소스를 보존했다면 남은 리소스와 비용을 별도로 확인합니다. 프로비저닝이 중단되어 출력 값이 없을 때는 Azure Portal의 실제 환경 태그/이름/활동 로그로 찾고 임의의 그룹을 지우지 않습니다.

별도 역할 할당, 네트워크, Data Protection 키 저장소 및 soft-delete 보존도 확인합니다. 실패한 삭제를 성공으로 표시하지 말고 남은 ID와 오류를 기록합니다. Azure 정리가 끝나기 전 `.azure`를 먼저 지우지 않습니다.

## 로컬 정리

Visual Studio의 디버깅/실행을 중지하고 `dotnet run` 터미널에서 `Ctrl+C`로 앱을 종료합니다. 모든 `dotnet`/IIS Express 프로세스를 이름으로 일괄 종료하지 않습니다. 필요하면 프로세스 경로와 PID를 확인하고 해당 PID만 종료합니다.

LocalDB 인스턴스, MSMQ 서비스, 개발 인증서는 다른 프로젝트가 사용할 수 있습니다. **서비스/기능 전체를 제거하지 않습니다.** 이 실습에서 만든 DB/큐와 데이터인지 원본 설정과 대조하고, 삭제가 필요한 경우 해당 DB/큐만 관리 도구에서 선택해 직접 삭제합니다.

실습에 사용한 Docker/Podman 이미지/컨테이너가 있으면 이름과 생성 시점을 확인해 개별 정리합니다. 전체 엔진 `system prune`, 모든 볼륨 또는 Podman machine 삭제는 하지 않습니다. 앱 폴더와 Git 기준선은 남겨도 됩니다.

## 완료 기준과 문제 해결

Azure 유료 리소스가 삭제되었거나 보존 대상/비용 책임자가 명확하고 실습 프로세스가 정지되어야 합니다. `.azure`, 로그와 로컬 사용자 비밀의 보관 범위를 확인하세요. 삭제 권한/잠금 문제는 [문제 해결](../troubleshooting.md)을 참고합니다.
