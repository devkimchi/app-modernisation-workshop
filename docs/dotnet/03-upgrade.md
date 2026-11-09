# .NET 3. Upgrade 에이전트로 .NET 10 전환하기

[목차](README.md) | [이전: 평가와 계획](02-assess-and-plan.md) | [다음: Azure 서비스 이전](04-migrate-azure-services.md) | [정리](07-cleanup.md)

## 목표와 시작 조건

Copilot app에서 동일한 **앱 루트**를 대상으로 **Upgrade** 에이전트를 선택합니다. 원본 IIS Express는 먼저 중지합니다. 새 세션으로 전환한다면 이전 평가/계획의 실제 파일 경로를 전달하고 같은 코드 상태에서 작업하는지 확인합니다.

`Upgrade`는 `microsoft/upgrade-agent-plugins`의 `upgrade-agent` 플러그인입니다. Visual Studio의 별도 업그레이드 UI나 Copilot CLI로 전환하는 단계가 아닙니다.

## 업그레이드 계획 검토

```text
이 Contoso University 앱을 .NET Framework v4.8/ASP.NET MVC 5에서
.NET 10/ASP.NET Core로 업그레이드하려고 한다. 목표는 .NET 11이 아니라 .NET 10이다.
앞서 modernize가 만든 <평가-경로>와 <계획-경로>, rulebook을 읽어 줘.
기존 Razor 화면, 라우팅, 유효성 검사, CRUD와 큐/파일 관련 동작을 보존해야 한다.
먼저 기준 테스트와 구체적인 업그레이드 변경 계획을 제시하고 승인을 기다려 줘.
Azure 리소스 생성이나 배포는 하지 마.
```

SDK 스타일 프로젝트, ASP.NET Core 시작/DI/미들웨어, MVC/Razor, 설정, 정적 파일, EF Core와 관련 NuGet 변경 범위를 확인합니다. EF Core 3.1에서 최신 버전으로 옮길 때 쿼리 번역과 DB schema 차이도 검토합니다.

## 승인한 업그레이드 실행

```text
검토한 .NET 10 업그레이드 계획을 실행해 줘.
원본의 기준 테스트를 먼저 실행하고 .NET 10 SDK/ASP.NET Core로 전환해 줘.
global.json이 있다면 설치한 .NET 10 SDK와 맞추고 net10.0을 사용해 줘.
더 새 SDK가 설치되어 있다는 이유로 .NET 11로 올리지 마.

Windows 원본의 MSMQ를 곧바로 Linux에서도 쓸 수 있다고 가정하지 마.
업그레이드 중 임시 Windows 어댑터가 필요하면 범위와 미완료 기능을 명시해 줘.
다음 단계에서 Service Bus로 제거할 부분을 격리하되 테스트를 지워서 성공시키지 마.
복원/빌드/테스트와 Windows 로컬 기능 확인을 수행하고 실패를 구분해 줘.
실제 실행할 프로젝트 경로, launch profile과 URL을 알려 줘.
아직 컨테이너 배포나 Azure 서비스 생성은 하지 마.
```

실제 생성된 솔루션과 프로젝트 경로를 확인한 뒤 **Windows PowerShell 7**에서 실행합니다. 확장자가 `.slnx`로 바뀌었다면 그 경로를 사용합니다.

```powershell
dotnet --version
dotnet restore <실제-솔루션-경로>
dotnet build <실제-솔루션-경로> --no-restore
dotnet test <실제-솔루션-경로> --no-build
dotnet run --project <실제-웹-프로젝트-경로>
```

`dotnet test`가 성공 코드로 끝나도 테스트가 0개라면 회귀 확인이 아닙니다. 발견/실행한 테스트 수와 누락된 기능을 기록합니다. 실행 로그의 실제 주소에서 학생/강좌/강사/학과/통계와 기존 큐/파일 동작을 비교합니다.

## 완료 기준과 문제 해결

.NET 10 빌드와 실행, 기존 사용자 기능의 회귀 결과가 있고, 임시 Windows 의존성이 무엇인지 분명해야 합니다. 이 단계의 Windows 실행 성공은 **Linux 지원 완료가 아닙니다**. 미완료 기능을 보고하고 다음 Azure 이전 계획에서 반드시 처리합니다.

diff를 검토하고 업그레이드 커밋을 남깁니다. 원본 DB를 파괴하는 초기화 동작을 새 Azure DB에 가져가지 않습니다. 지원되지 않는 API나 업그레이드 중단은 [문제 해결](../troubleshooting.md)을 참고합니다.
