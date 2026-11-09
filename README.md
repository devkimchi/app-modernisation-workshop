# GitHub Copilot app으로 앱 현대화하기

Java 8 또는 .NET Framework 4.8 애플리케이션을 GitHub Copilot app의 Modernization 플러그인으로 현대화하고 Azure Container Apps에 배포하는 한국어 핸즈온 워크샵입니다.

## 워크샵 트랙

| 트랙 | 원본 애플리케이션 | 목표 |
| --- | --- | --- |
| Java | Java 8, Spring Boot 2.7.18 기반 Asset Manager | JDK 25, Azure PostgreSQL, Service Bus, Blob Storage, Azure Container Apps |
| .NET | ASP.NET MVC 5, .NET Framework 4.8 기반 Contoso University | .NET 10, Azure SQL, Service Bus, Blob Storage, Azure Container Apps |

워크샵은 로컬 실행과 기준선 확인, 평가 및 계획 검토, 점진적 현대화, Azure 서비스 이전, 배포 준비, 실제 배포, 리소스 정리 순서로 진행합니다. Azure 리소스를 만들기 전에는 계획과 비용을 검토하고, 배포 성공은 도구의 완료 메시지가 아니라 빌드와 실제 동작으로 확인합니다.

## 현재 브랜치 범위

이 브랜치는 저장소 기본 파일만 포함합니다. 워크샵 본문인 문서, 스크립트, 테스트는 [init 브랜치](https://github.com/devkimchi/app-modernisation-workshop/tree/init)에 있으며 이번 초기화 변경에는 가져오지 않았습니다. 따라서 이 브랜치만으로는 실습을 진행할 수 없습니다.

워크샵 자료가 포함되면 참가자는 공통 준비 절차를 마친 뒤 Java 또는 .NET 트랙을 선택합니다. 샘플 앱은 워크샵 저장소와 별개의 저장소로 유지하고, 원본 라이선스와 고지를 보존해야 합니다.

## 요구 사항

- Azure 구독 및 GitHub Copilot 라이선스
- 선택한 트랙의 개발 도구와 Docker 또는 Podman
- 워크샵 저장소의 준비 절차와 트랙별 안내

## 테스트

테스트 파일은 현재 브랜치에 없으므로 CI는 해당 파일이 추가될 때까지 각 테스트 단계를 알림과 함께 건너뜁니다. 자료가 추가된 뒤에는 다음 회귀 테스트를 실행합니다.

```powershell
pwsh -File .\tests\scripts.tests.ps1
```

```bash
bash tests/scripts.tests.sh
```

## 라이선스

이 저장소의 원본 자료에는 MIT 라이선스가 적용됩니다. 다운로드하거나 포함한 제3자 샘플은 각 원본 저장소의 라이선스와 고지를 따르며, 이 저장소의 MIT 라이선스가 제3자 자료의 재배포 권한을 부여하지는 않습니다.

