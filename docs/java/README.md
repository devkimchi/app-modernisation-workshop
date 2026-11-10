# Java 트랙: Asset Manager

[전체 목차](../../README.md) | [다음: 준비](0-setup.md) | [문제 해결](8-troubleshooting.md)

## 목표와 시작 조건

Java 8/Spring Boot 2.7.18 앱을 **JDK 21을 거쳐 JDK 25**로 업그레이드하고 Azure 서비스를 연결한 뒤, web과 worker를 ACA에 배포합니다. 두 모듈과 기존 사용자 기능을 유지합니다.

[준비](0-setup.md)의 **사전 점검 → 샘플 다운로드**를 끝내야 합니다. 기본 앱 루트는 워크숍 최상위의 `java`입니다. macOS 또는 Windows WSL2의 Bash를 사용하고, Copilot app에는 이 앱 폴더를 프로젝트로 추가합니다.

| 순서 | 실습 | 완료 시 확인할 것 |
| --- | --- | --- |
| 0 | [준비](0-setup.md) | 저장소 생성과 클론, 사전 점검과 보완, 플러그인 설치 및 샘플 다운로드 |
| 1 | [원본 로컬 실행](01-run-locally.md) | Java 8의 웹, DB 연결, 큐, worker 동작과 워크숍 저장소 기준선 커밋 |
| 2 | [평가와 계획](02-assess-and-plan.md) | 평가 결과, 제약조건, 단계별 승인 계획 |
| 3 | [JDK 25 업그레이드](03-upgrade.md) | 중간 JDK 21과 최종 JDK 25에서 회귀 검사 |
| 4 | [Azure 서비스 이전](04-migrate-azure-services.md) | PostgreSQL, Service Bus, private Blob 코드와 단위 검사 |
| 5 | [azd 배포 준비](05-prepare-azd.md) | Dockerfile, azure.yaml, Bicep 및 비용/권한 검토 |
| 6 | [ACA 배포](06-deploy-aca.md) | 프로비저닝, 로컬 이미지 빌드, 배포, 실제 기능 확인 |
| 7 | [정리](07-cleanup.md) | Azure 리소스와 로컬 실습 프로세스 정리 |
| 8 | [문제 해결](8-troubleshooting.md) | 진행 중 발생한 오류의 원인과 조치 확인 |

## 진행 원칙

Windows에서는 SDKMAN과 Java 도구가 WSL2 안에 있습니다. Copilot app이 Windows 셸에서 작업한다면 프롬프트에 실제 WSL 배포판과 앱 경로를 전달하고 **Java 명령을 WSL2에 명시적으로 위임**하도록 합니다. macOS에서는 같은 앱 루트에서 Bash를 사용합니다. 앱의 세션 작업 경로가 바뀌면 WSL 경로도 다시 확인하세요.

각 실습의 완료 조건에 따라 실제 앱 동작을 확인하세요. 문제가 생기면 [문제 해결](8-troubleshooting.md)을 참고하세요.
