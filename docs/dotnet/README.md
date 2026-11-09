# .NET 트랙: Contoso University

[전체 목차](../../README.md) | [이전: 공통 준비](../setup.md) | [다음: 원본 실행](01-run-locally.md) | [정리](07-cleanup.md)

## 목표와 시작 조건

Windows의 ASP.NET MVC 5/.NET Framework **`v4.8`** 앱을 .NET 10/ASP.NET Core로 바꾸고, Windows 전용 의존성을 제거해 **Linux ACA**에 배포합니다. 원본 README의 "4.8.2" 표기를 설치 요구사항으로 사용하지 않습니다.

[공통 준비](../setup.md)의 **사전 점검 → 샘플 다운로드**를 끝내야 합니다. 기본 앱 루트는 워크숍 최상위의 `dotnet`이며 `ContosoUniversity.sln`과 `.csproj`가 바로 아래에 있습니다. **GitHub Copilot app**에서 앱 폴더를 열고 Windows 터미널의 MSBuild와 IIS Express로 원본을 빌드/실행합니다. VS 2022/2026 IDE 또는 독립 Build Tools의 웹 빌드 도구를 사용할 수 있으며, **Visual Studio IDE를 열 필요는 없습니다.**

| 순서 | 실습 | 도구와 완료 기준 |
| --- | --- | --- |
| 1 | [원본 로컬 실행](01-run-locally.md) | Copilot app → PowerShell/MSBuild → IIS Express, LocalDB/MSMQ, 워크숍 저장소 기준선 커밋 |
| 2 | [평가와 계획](02-assess-and-plan.md) | `modernize`, 평가와 실행 범위 승인 |
| 3 | [.NET 10 업그레이드](03-upgrade.md) | `Upgrade`, ASP.NET Core와 회귀 검사 |
| 4 | [Azure 서비스 이전](04-migrate-azure-services.md) | `modernize`, SQL/Service Bus/Blob 및 Windows 의존성 제거 |
| 5 | [azd 배포 준비](05-prepare-azd.md) | `modernize`, Dockerfile/azure.yaml/Bicep 검토 |
| 6 | [ACA 배포](06-deploy-aca.md) | Windows PowerShell 7, azd, 실제 기능 확인 |
| 7 | [정리](07-cleanup.md) | Azure와 로컬 실습 자원 정리 |

기존 화면과 학생/강좌/강사/학과 관리 기능을 보존합니다. 프런트엔드를 새 프레임워크로 다시 작성하는 실습이 아닙니다. 플랫폼 업그레이드는 보조 플러그인의 **Upgrade**, Azure 서비스 이전과 배포 산출물 준비는 Modernization의 **`modernize`**가 맡습니다.

MSMQ 패키지 이름만 바꾸면 Linux에서 동작한다고 판단하지 않습니다. LocalDB, Windows 인증, `System.Web`, IIS 의존성, 로컬 파일 경로와 Data Protection까지 확인합니다. 문제가 생기면 [문제 해결](../troubleshooting.md)을 참고하고, 중단해도 [정리](07-cleanup.md)를 수행합니다.
