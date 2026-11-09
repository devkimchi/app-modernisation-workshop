# GitHub Copilot app으로 앱 현대화하기

Java 8 또는 .NET Framework 4.8 앱 하나를 선택해 로컬에서 실행하고, GitHub Copilot app의 **Modernization 플러그인**으로 현대화한 뒤 **Azure Developer CLI(`azd`)로 Azure Container Apps(ACA)에 배포하는** 한국어 핸즈온 워크숍입니다.

## 먼저 할 일

참가자에게 다음이 필요합니다.

- Azure 구독. 없다면 [Azure 무료 구독](https://aka.ms/azure/free)을 직접 신청합니다. 무료 크레딧의 서비스, 리전, 쿼터 제한과 유료 전환 조건을 확인하세요.
- GitHub 계정과 유효한 GitHub Copilot 라이선스. 조직 정책에 따라 플러그인 사용이 제한될 수 있습니다.
- [공통 준비](docs/setup.md)의 선택 트랙 도구와 컨테이너 엔진.

이 저장소는 공개 템플릿 저장소입니다. 원본을 직접 복제하거나 포크하지 말고, **Use this template** > **Create a new repository**로 본인 **개인 계정**에 새 저장소를 만든 뒤 로컬에 복제합니다. 자세한 절차는 [공통 준비](docs/setup.md)에 있습니다. 복제한 폴더가 이후 명령을 실행할 **워크숍 자료 폴더**입니다.

[![GitHub에서 템플릿으로 저장소 만들기](https://img.shields.io/badge/GitHub-Create%20repository%20from%20template-2ea44f?style=flat&logo=github&logoColor=white)](https://github.com/new?template_name=app-modernisation-workshop&template_owner=devkimchi)

**워크숍 자료 폴더에서**, Java는 WSL2/macOS Bash, .NET은 Windows PowerShell 7로 실행합니다. 아래 두 명령은 첫 명령이 성공한 경우에만 이어서 실행합니다.

Java:

```bash
bash scripts/check-prerequisites.sh --track java --container-engine docker &&
bash scripts/download-sample.sh --track java --container-engine docker
```

.NET:

```powershell
pwsh -File ./scripts/check-prerequisites.ps1 -Track dotnet -ContainerEngine docker &&
pwsh -File ./scripts/download-sample.ps1 -Track dotnet -ContainerEngine docker
```

Podman 사용자는 두 명령의 `docker`를 모두 `podman`으로 바꿉니다. Windows에서 Java를 PowerShell로 시작하거나 .NET을 Git Bash로 시작하는 방법은 [공통 준비](docs/setup.md)에 있습니다. 다운로드 스크립트 자체도 사전 점검을 다시 실행하며 실패하면 다운로드하지 않습니다.

선택형 개발 환경은 [Dev Container 안내](.devcontainer/README.md)를 참고하세요. .NET Framework 원본 실습은 여전히 Windows에서 진행합니다.

## 트랙 선택

| 항목 | [Java 트랙](docs/java/README.md) | [.NET 트랙](docs/dotnet/README.md) |
| --- | --- | --- |
| 참가자 환경 | Windows + WSL2 또는 macOS | Windows |
| 원본 | Asset Manager, Java 8, Spring Boot 2.7.18 | Contoso University, ASP.NET MVC 5, 프로젝트 대상 `v4.8` |
| 최종 런타임 | JDK 25. JDK 21은 중간 단계 | .NET 10, ASP.NET Core, Linux |
| 도구 | Modernization의 `modernize` | 업그레이드는 `Upgrade`, Azure 이전은 `modernize` |
| 서비스 이전 | PostgreSQL, RabbitMQ, 파일(`dev`: 로컬, 그 외: AWS S3) → Azure PostgreSQL, Service Bus, Blob | LocalDB, MSMQ, 파일 → Azure SQL, Service Bus, Blob |
| 배포 단위 | web + worker, ACA 2개 | 웹 앱, 필요하면 처리기 분리 여부를 계획에서 결정 |

기본 다운로드 결과는 `java/pom.xml` 또는 `dotnet/ContosoUniversity.sln`입니다. `docs/java`, `docs/dotnet`은 **문서** 폴더이고 최상위 `java`, `dotnet`은 **앱** 폴더입니다. 다운로드 위치는 `-Destination`/`--destination`으로 바꿀 수 있습니다.

선택한 앱 폴더는 원본 저장소와 별개의 Git 저장소입니다. 원본 실행과 기준선 커밋을 마친 뒤 Copilot app에 **앱 폴더 자체**를 추가합니다. 워크숍 최상위를 현대화 대상으로 열지 마세요.

## 자료 구성과 운영

공통 문서는 이 README, [준비](docs/setup.md), [문제 해결](docs/troubleshooting.md)입니다. 각 트랙은 목차 1개와 실습 7개로 구성됩니다. 워크숍 Markdown 문서는 **19개**이며 저장소 운영 문서는 별도입니다.

각 실습은 로컬 실행, 평가와 계획, 업그레이드, Azure 서비스 이전, `azd` 산출물 준비, ACA 배포, 정리 순서입니다. 평가 후 계획 승인 전, Azure 리소스 생성 전에는 반드시 멈춰 내용을 검토합니다. 에이전트의 "완료" 응답 대신 빌드 결과와 실제 기능 동작을 확인하세요.

이 자료에는 완성 앱, 완성 배포 템플릿 또는 자동 배포 스크립트가 들어 있지 않습니다. 참가자가 플러그인과 대화하며 산출물을 만드는 실습입니다. Copilot CLI의 `/plugin` 명령이나 VS Code 전용 명령 팔레트로 워크숍을 진행하지 않습니다.

배포에는 `azd provision`, `azd package`, `azd deploy`를 사용하고 마지막에 `azd down`으로 정리합니다. Docker Desktop이 기본이며 Podman도 안내합니다. **로컬에서 이미지를 빌드한 뒤 Azure Container Registry(ACR)에 푸시**하는 방식이 기본입니다. ACR Tasks, `az acr build` 또는 원본의 배포 스크립트로 대체하지 않습니다.

## 원본과 검증 범위

| 원본 | 다운로드 고정 커밋 | 추출 폴더 |
| --- | --- | --- |
| [Java 샘플](https://github.com/Azure-Samples/java-migration-copilot-samples/tree/317d3bbfd61fb1e402bea61f90e385bec12f2070/asset-manager) | `317d3bbfd61fb1e402bea61f90e385bec12f2070` | `asset-manager` 내용 |
| [.NET 샘플](https://github.com/Azure-Samples/dotnet-migration-copilot-samples/tree/7c1bf47b7e2627fe5a1c764716638815d35e0282/ContosoUniversity) | `7c1bf47b7e2627fe5a1c764716638815d35e0282` | `ContosoUniversity` 내용 |

다운로드는 원본 코드와 대상 프레임워크를 바꾸지 않고 출처를 `upstream-source.json`에 남깁니다. 원본 루트의 라이선스와 고지가 있으면 `UPSTREAM-*` 이름으로 함께 보존합니다.

준비 스크립트 회귀 검사는 외부 패키지 없이 다음과 같이 실행합니다. 실제 계정이나 OS 기능을 바꾸지 않는 fixture/mock 검사이며, macOS/WSL2/Podman 실기기 및 전체 앱 현대화와 Azure 배포를 대신하지 않습니다.

```powershell
pwsh -File ./tests/scripts.tests.ps1
```

```bash
bash tests/scripts.tests.sh
```

누락된 도구/잘못된 커밋을 재현하는 시나리오에서는 `FAIL`/`fatal` 출력이 나올 수 있습니다. 테스트 실행 자체의 성공 여부는 마지막 `PASS` 요약과 종료 코드 `0`으로 판단합니다.

공식 근거와 설치 링크는 [준비 문서](docs/setup.md)에 있습니다. 진행 중단 여부와 관계없이 마지막에는 [Java 정리](docs/java/07-cleanup.md) 또는 [.NET 정리](docs/dotnet/07-cleanup.md)를 확인하세요.

## 기여와 보안

기여 절차는 [CONTRIBUTING.md](CONTRIBUTING.md), 행동 강령은 [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md), 보안 문제 제보는 [SECURITY.md](SECURITY.md)를 참고하세요. 변경 이력은 [CHANGELOG.md](CHANGELOG.md)에 기록합니다.

## 라이선스

이 저장소의 원본 자료에는 [MIT 라이선스](LICENSE)가 적용됩니다. 다운로드하거나 포함한 제3자 샘플은 각 원본 저장소의 라이선스와 고지를 따르며, 이 저장소의 MIT 라이선스가 제3자 자료의 재배포 권한을 부여하지는 않습니다.
