# .NET 1. 원본 앱을 로컬에서 실행하기

[목차](README.md) | [이전: 공통 준비](../setup.md) | [다음: 평가와 계획](02-assess-and-plan.md) | [정리](07-cleanup.md)

## 목표와 시작 조건

현대화 전 Windows 원본의 동작을 확인합니다. 사전 점검/다운로드를 마쳤고 MSMQ, Visual Studio 2026, .NET Framework 4.8 이상 런타임과 4.8 Targeting Pack, .NET 10 SDK가 있어야 합니다.

터미널은 **Windows PowerShell 7**, 작업 위치는 **앱 루트 `dotnet`**입니다. 빌드와 최초 실행은 Visual Studio 2026에서 수행합니다.

```powershell
Set-Location .\dotnet
Get-Content .\ContosoUniversity.csproj | Select-String TargetFrameworkVersion
Get-Service MSMQ
dotnet --list-sdks
```

`.csproj`의 `v4.8`이 원본 대상입니다. README/packages.config 표기만 보고 타깃을 바꾸지 않습니다. 최초 현대화 전에는 원본 프레임워크를 유지합니다.

## Visual Studio에서 실행

1. Visual Studio 2026에서 이 폴더의 `ContosoUniversity.sln`을 엽니다.
2. 솔루션의 NuGet 패키지를 복원하고 Build Solution을 실행합니다. Targeting Pack 오류와 NuGet 네트워크/인증 오류를 구분합니다.
3. 시작 프로젝트와 IIS Express 프로필을 확인합니다. `Web.config`의 LocalDB 연결 대상은 기본적으로 `(LocalDb)\MSSQLLocalDB`입니다.
4. 디버깅 없이 시작하거나 디버깅을 시작합니다. 기본 HTTPS 주소는 `https://localhost:44300/`이며 실제 실행 프로필의 주소를 사용합니다.

IIS Express 개발 인증서 신뢰 문제는 참가자가 인증서와 출처를 확인해 해결합니다. 브라우저 보안 경고를 무조건 무시하거나 TLS 검사를 끄는 방식으로 통과시키지 않습니다.

LocalDB가 PATH에 없다면 Visual Studio Installer에서 설치 경로를 확인한 뒤 `SqlLocalDB.exe info`를 실행합니다. 없는 인스턴스를 임의로 여러 개 만들기 전에 `Web.config`와 실제 인스턴스 이름을 대조합니다.

**원본 DB 초기화 코드는 모델 변경 시 DB를 재생성할 수 있습니다.** 데모 전용 LocalDB만 사용하고 기존 개인/업무 DB를 연결하지 않습니다.

## 기준 동작 기록

학생 목록/검색/페이지 이동, 학생 추가/수정/삭제, 강좌/강사/학과와 통계 화면을 확인합니다. 가짜 학생 데이터를 사용하고 수행한 입력과 결과를 기록하세요. 소스에 있는 큐 전송/처리 및 파일 업로드 경로도 실제 동작을 확인해 이후 회귀 비교 대상으로 남깁니다.

MSMQ 오류가 나면 서비스 상태, 앱이 사용하는 private queue 이름, 생성/접근 권한과 트랜잭션 설정을 확인합니다. IIS Express를 무조건 관리자 권한으로 실행하는 대신 필요한 권한만 해결합니다. 홈 화면만 열린 상태를 성공으로 처리하지 않습니다.

## 기준선 커밋과 Copilot app

Visual Studio 실행을 중지하고 변경/생성 파일을 확인합니다. 저장소에 이미 있는 `.gitignore`는 보존하면서 실습 생성물의 제외 규칙을 보완합니다.

```powershell
Add-Content .\.gitignore "`n.azure/`n.vs/`n**/bin/`n**/obj/`npackages/`n*.mdf`n*.ldf`n.env`n.env.*"
git status --short
git add .
git diff --cached --stat
git diff --cached
git commit -m "Baseline: verified .NET Framework sample"
```

업로드 파일, 로그, 인증 토큰과 실제 연결 비밀이 포함되지 않았는지 커밋 전에 확인합니다. Git 신원이 없으면 참가자가 이 저장소 범위에 본인 설정을 추가합니다. 원격 GitHub 저장소는 만들 필요가 없습니다.

Copilot app에서 **이 앱 폴더**를 프로젝트로 추가합니다. 워크샵 최상위나 `docs\dotnet`을 열지 않습니다. 앱의 세션이 별도 작업 경로를 사용하면 이후 Visual Studio/터미널도 그 경로를 사용해야 합니다.

## 완료 기준과 문제 해결

원본 빌드, IIS Express와 LocalDB/MSMQ, 주요 화면과 데이터 동작을 확인하고 기준선 커밋을 남겨야 합니다. 실패한 원본 상태로 업그레이드를 시작하면 원인 구분이 어려워집니다. [문제 해결](../troubleshooting.md)에서 Targeting Pack, MSMQ, 인증서 항목을 확인하세요.
