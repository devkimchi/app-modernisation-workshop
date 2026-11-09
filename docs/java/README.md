# Java 트랙: Asset Manager

[전체 목차](../../README.md) | [이전: 공통 준비](../setup.md) | [다음: 원본 실행](01-run-locally.md) | [정리](07-cleanup.md)

## 목표와 시작 조건

Java 8/Spring Boot 2.7.18 앱을 **JDK 21을 거쳐 JDK 25**로 업그레이드하고 Azure 서비스를 연결한 뒤, web과 worker를 ACA에 배포합니다. 두 모듈과 기존 사용자 기능을 유지합니다.

[공통 준비](../setup.md)의 **사전 점검 → 샘플 다운로드**를 끝내야 합니다. 기본 앱 루트는 워크숍 최상위의 `java`입니다. macOS 또는 Windows WSL2의 Bash를 사용하고, Copilot app에는 이 앱 폴더를 프로젝트로 추가합니다.

| 순서 | 실습 | 완료 시 확인할 것 |
| --- | --- | --- |
| 1 | [원본 로컬 실행](01-run-locally.md) | Java 8의 웹, DB 연결, 큐, worker 동작과 워크숍 저장소 기준선 커밋 |
| 2 | [평가와 계획](02-assess-and-plan.md) | 평가 결과, 제약조건, 단계별 승인 계획 |
| 3 | [JDK 25 업그레이드](03-upgrade.md) | 중간 JDK 21과 최종 JDK 25에서 회귀 검사 |
| 4 | [Azure 서비스 이전](04-migrate-azure-services.md) | PostgreSQL, Service Bus, private Blob 코드와 단위 검사 |
| 5 | [azd 배포 준비](05-prepare-azd.md) | Dockerfile, azure.yaml, Bicep 및 비용/권한 검토 |
| 6 | [ACA 배포](06-deploy-aca.md) | 프로비저닝, 로컬 이미지 빌드, 배포, 실제 기능 확인 |
| 7 | [정리](07-cleanup.md) | Azure 리소스와 로컬 실습 프로세스 정리 |

사용자가 선택하는 에이전트는 Modernization 플러그인의 **`modernize`**입니다. 플러그인이 내부 작업자를 선택하게 하고, 참가자가 내부 에이전트를 임의로 직접 실행하지 않습니다.

## 진행 원칙

Windows에서는 SDKMAN과 Java 도구가 WSL2 안에 있습니다. Copilot app이 Windows 셸에서 작업한다면 프롬프트에 실제 WSL 배포판과 앱 경로를 전달하고 **Java 명령을 WSL2에 명시적으로 위임**하도록 합니다. macOS에서는 같은 앱 루트에서 Bash를 사용합니다. 앱의 세션 작업 경로가 바뀌면 WSL 경로도 다시 확인하세요.

스크립트나 에이전트의 성공 메시지는 기능 확인을 대신하지 않습니다. 원본 `dev` 프로필에서는 업로드, 파일 저장, 메시지 처리와 결과 표시를 연결해 확인하고 DB 연결은 별도로 확인합니다. Azure 이전 후에는 `dev` 외 원본 구현의 DB 메타데이터 기능도 확인합니다. 문제가 생기면 [문제 해결](../troubleshooting.md)을 보고, 진행을 중단해도 [정리](07-cleanup.md)는 수행합니다.
