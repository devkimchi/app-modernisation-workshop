# .NET 2. 평가하고 도구별 실행 계획 세우기

[목차](README.md) | [이전: 원본 실행](01-run-locally.md) | [다음: 업그레이드](03-upgrade.md) | [정리](07-cleanup.md)

## 목표와 시작 조건

원본 동작과 기준선 커밋이 있는 **앱 루트**를 Copilot app에서 엽니다. Agent picker의 **`modernize`**로 평가를 시작합니다. Upgrade 에이전트를 쓰기 전에 Azure 이전 범위와 기존 동작을 함께 파악합니다.

## 평가만 요청

```text
이 폴더는 Contoso University 앱 루트이며 .sln과 .csproj가 있다.
원본 csproj 대상은 v4.8이다. README의 4.8.2 표기대로 타깃을 바꾸지 마.
Modernization 플러그인으로 단일 저장소 평가만 해 줘.
평가 산출물 작성은 허용하지만 앱 코드/패키지 수정, Azure 리소스 생성과 배포는 하지 마.
추가 도구 설치나 외부 서비스 사용이 필요하면 먼저 설명해 줘.

ASP.NET MVC 5/System.Web, EF Core/LocalDB, MSMQ, 파일 저장과 큐 처리,
인증/쿠키/세션, 초기 데이터 생성과 DB 재생성 동작을 근거 파일로 정리해 줘.
.NET 10/ASP.NET Core/Linux로 옮길 때 막히는 Windows 의존성을 찾아 줘.
기존 기능과 테스트 현황, 업그레이드 위험, 평가하지 못한 항목을 구분하고 멈춰 줘.
```

실제 생성된 `.github/modernize` 평가 결과를 읽고 대상 프레임워크, 의존성과 미완료 항목이 맞는지 확인합니다.

## 제약과 역할 분담

```text
평가 결과를 바탕으로 제약을 .github/modernize/rulebook/workshop.md에
기록하고 단계별 실행 계획을 만들어 줘. 지금은 계획까지만 작성해 줘.

- 최종 대상은 .NET 10/ASP.NET Core와 Linux Azure Container Apps다.
- 플랫폼 업그레이드는 app의 Upgrade 에이전트가 담당하고,
  Azure 의존성 이전과 azd/Bicep 배포 산출물은 modernize가 담당한다.
- 기존 Razor/MVC 사용자 기능을 보존한다. 별도 SPA로 다시 쓰지 않는다.
- LocalDB -> Azure SQL, MSMQ -> Service Bus, 로컬 파일 -> private Blob으로 이전한다.
- MSMQ.Messaging 같은 Windows용 패키지 치환만으로 Linux 지원 완료라고 하지 마.
- 관리 ID, 최소 권한과 TLS를 사용하고 비밀은 코드/Git에 넣지 않는다.
- DB 초기화의 데이터 삭제/재생성을 제거하고 명시적인 migration으로 바꾼다.
- Data Protection 키를 revision/인스턴스 간 보존한다.
- 배포는 azd와 Bicep, 선택한 로컬 Docker/Podman 엔진을 사용한다.
  원격 이미지 빌드, ACR Tasks, az acr build를 사용하지 않는다.
- 기준 테스트, .NET 10 업그레이드, Azure 코드, Linux 컨테이너,
  인프라 준비, 배포, 실제 기능 검증과 정리로 작업을 나눈다.
- 업그레이드 단계의 임시 Windows 의존성과 최종 제거 조건을 명시한다.
- 각 단계의 검증 명령, 중단/복구 기준과 비용 발생 전 승인점을 포함한다.
```

최종 목표가 .NET 8/9/11이나 Windows 컨테이너로 바뀌면 승인하지 않습니다. `Upgrade`의 안내 예시가 더 새 버전을 사용해도 이번 워크숍은 **.NET 10**입니다.

## 완료 기준과 문제 해결

평가 결과와 계획을 읽었고 두 에이전트의 책임, 소스 변경 범위, 데이터 보존과 최종 Linux 확인 기준이 명확해야 합니다. 다음 실습은 **업그레이드 부분만** 승인합니다. Agent picker/평가 도구 문제는 [문제 해결](../troubleshooting.md)을 확인하세요.
