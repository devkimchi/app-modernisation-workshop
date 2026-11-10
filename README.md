# GitHub Copilot app으로 앱 현대화하기

GitHub Copilot app으로 현대화한 뒤 Azure Container Apps로 배포하는 핸즈온 워크숍입니다.

## 워크숍 구조

```text
.
├── README.md       # 워크숍 안내와 진행 순서
├── docs
│   ├── java        # Java 트랙 목차, 준비, 실습, 문제 해결
│   └── dotnet      # .NET 트랙 목차, 준비, 실습, 문제 해결
├── scripts         # 사전 점검, 설치, 샘플 다운로드 도우미
├── java            # 다운로드되는 Java 앱
└── dotnet          # 다운로드되는 .NET 앱
```

## 먼저 할 일

참가자에게 다음이 필요합니다.

- Azure 구독. 없다면 [Azure 무료 구독](https://aka.ms/azure/free)을 직접 신청합니다. 무료 크레딧의 서비스, 리전, 쿼터 제한과 유료 전환 조건을 확인하세요.
- GitHub 계정과 유효한 GitHub Copilot 라이선스. 조직 정책에 따라 플러그인 사용이 제한될 수 있습니다.
- 선택한 트랙의 실행 환경. Java는 Windows + WSL2 또는 macOS, .NET은 Windows에서 진행합니다.

**[Java 준비](docs/java/0-setup.md) 또는 [.NET 준비](docs/dotnet/0-setup.md) 중 자신의 트랙 문서 하나를 선택해 시작하세요.** 준비부터 문제 해결까지 트랙별로 안내하므로 다른 트랙의 문서를 함께 읽을 필요는 없습니다.

각 준비 문서는 다음 순서로 진행합니다.

1. **Use this template > Create a new repository**로 본인 개인 계정에 저장소를 만들고 로컬에 복제합니다. 원본 템플릿을 직접 클론하거나 포크하지 않습니다.
2. 사전 점검 스크립트를 실행하고, 설치 도우미와 동의 기반 조치로 부족한 항목을 보완합니다. 자동으로 처리되지 않는 항목만 수동으로 준비한 뒤 다시 점검합니다.
3. Copilot app에 플러그인을 설치합니다.
4. 샘플 앱을 다운로드하고 원본 로컬 실행 실습으로 넘어갑니다.

[![GitHub에서 템플릿으로 저장소 만들기](https://img.shields.io/badge/GitHub-Create%20repository%20from%20template-2ea44f?style=flat&logo=github&logoColor=white)](https://github.com/new?template_name=app-modernisation-workshop&template_owner=devkimchi)

실행 명령과 수동 준비 항목은 각 트랙의 준비 문서에 있습니다. .NET 원본은 Visual Studio IDE를 열지 않고 MSBuild와 IIS Express로 빌드하고 실행합니다. 선택형 개발 환경은 [Dev Container 안내](.devcontainer/README.md)를 참고하되, .NET Framework 원본 실습은 Windows에서 진행합니다.

## 트랙 선택

| 항목 | [Java 트랙](docs/java/README.md) | [.NET 트랙](docs/dotnet/README.md) |
| --- | --- | --- |
| 참가자 환경 | Windows + WSL2 또는 macOS | Windows |
| 원본 | Asset Manager, Java 8, Spring Boot 2.7.18 | Contoso University, .NET Framework 4.8, ASP.NET MVC 5 |
| 최종 런타임 | Java 25, Spring Boot 4.1.2 | .NET 10, ASP.NET Core MVC |
| 도구 | Modernization의 `modernize` | 업그레이드는 `Upgrade`, Azure 이전은 `modernize` |
| 서비스 이전 | PostgreSQL, RabbitMQ, 파일(`dev`: 로컬, 그 외: AWS S3) → Azure PostgreSQL, Service Bus, Blob | LocalDB, MSMQ, 파일 → Azure SQL, Service Bus, Blob |
| 배포 단위 | web + worker, ACA 2개 | 웹 앱, 필요하면 처리기 분리 여부를 계획에서 결정 |

## 워크숍 진행 순서

| 순서 | Java 트랙 | .NET 트랙 |
| --- | --- | --- |
| 0 | [준비](docs/java/0-setup.md) | [준비](docs/dotnet/0-setup.md) |
| 1 | [원본 로컬 실행](docs/java/01-run-locally.md) | [원본 로컬 실행](docs/dotnet/01-run-locally.md) |
| 2 | [평가와 계획](docs/java/02-assess-and-plan.md) | [평가와 계획](docs/dotnet/02-assess-and-plan.md) |
| 3 | [JDK 25 업그레이드](docs/java/03-upgrade.md) | [.NET 10 업그레이드](docs/dotnet/03-upgrade.md) |
| 4 | [Azure 서비스 이전](docs/java/04-migrate-azure-services.md) | [Azure 서비스 이전](docs/dotnet/04-migrate-azure-services.md) |
| 5 | [azd 배포 준비](docs/java/05-prepare-azd.md) | [azd 배포 준비](docs/dotnet/05-prepare-azd.md) |
| 6 | [ACA 배포](docs/java/06-deploy-aca.md) | [ACA 배포](docs/dotnet/06-deploy-aca.md) |
| 7 | [정리](docs/java/07-cleanup.md) | [정리](docs/dotnet/07-cleanup.md) |

문제가 생기면 진행 단계와 관계없이 [Java 문제 해결](docs/java/8-troubleshooting.md) 또는 [.NET 문제 해결](docs/dotnet/8-troubleshooting.md)을 참고하세요.

## 원본과 검증 범위

| 원본 | 다운로드 고정 커밋 | 추출 폴더 |
| --- | --- | --- |
| [Java 샘플](https://github.com/Azure-Samples/java-migration-copilot-samples/tree/317d3bbfd61fb1e402bea61f90e385bec12f2070/asset-manager) | `317d3bbfd61fb1e402bea61f90e385bec12f2070` | `asset-manager` 내용 |
| [.NET 샘플](https://github.com/Azure-Samples/dotnet-migration-copilot-samples/tree/7c1bf47b7e2627fe5a1c764716638815d35e0282/ContosoUniversity) | `7c1bf47b7e2627fe5a1c764716638815d35e0282` | `ContosoUniversity` 내용 |

다운로드는 원본 코드와 대상 프레임워크를 바꾸지 않고 출처를 `upstream-source.json`에 남깁니다. 원본 루트의 라이선스와 고지가 있으면 `UPSTREAM-*` 이름으로 함께 보존합니다.

준비 스크립트 회귀 검사는 외부 패키지 없이 다음과 같이 실행합니다. 실제 계정이나 OS 기능을 바꾸지 않는 fixture/mock 검사이며, macOS/WSL2/Podman 실기기 및 전체 앱 현대화와 Azure 배포를 대신하지 않습니다.

```powershell
pwsh -File ./tests/scripts.tests.ps1
pwsh -File ./tests/dotnet-original.tests.ps1
```

```bash
bash tests/scripts.tests.sh
```

누락된 도구/잘못된 커밋을 재현하는 시나리오에서는 `FAIL`/`fatal` 출력이 나올 수 있습니다. 테스트 실행 자체의 성공 여부는 마지막 `PASS` 요약과 종료 코드 `0`으로 판단합니다.

설치 링크는 [Java 준비](docs/java/0-setup.md) 또는 [.NET 준비](docs/dotnet/0-setup.md)에 있습니다. 진행 중단 여부와 관계없이 마지막에는 [Java 정리](docs/java/07-cleanup.md) 또는 [.NET 정리](docs/dotnet/07-cleanup.md)를 확인하세요.

## 기여와 보안

기여 절차는 [CONTRIBUTING.md](CONTRIBUTING.md), 행동 강령은 [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md), 보안 문제 제보는 [SECURITY.md](SECURITY.md)를 참고하세요. 변경 이력은 [CHANGELOG.md](CHANGELOG.md)에 기록합니다.

## 라이선스

이 저장소의 원본 자료에는 [MIT 라이선스](LICENSE)가 적용됩니다. 다운로드하거나 포함한 제3자 샘플은 각 원본 저장소의 라이선스와 고지를 따르며, 이 저장소의 MIT 라이선스가 제3자 자료의 재배포 권한을 부여하지는 않습니다.
