# 3. JDK 25로 업그레이드하기

[전체 목차](../../README.md) | [Java 목차](README.md) | [이전: 평가와 계획](02-assess-and-plan.md) | [다음: Azure 서비스 이전](04-migrate-azure-services.md) | [문제 해결](08-troubleshooting.md)

## 목표

검토한 계획에 따라 앱을 Java 25로 업그레이드하고 Azure 이전에 필요한 코드와 배포 산출물을 준비합니다.

## 실습 전 확인 사항

평가 보고서, 현대화 지침, `plan.md`, `tasks.json`을 커밋해 둡니다. [실습 2: 평가하고 계획 승인하기](02-assess-and-plan.md)에서 사용한 터미널을 계속 사용합니다.

## 승인한 계획 실행

앱 루트에서 Java 8 기준 테스트부터 시작할 수 있도록 현재 셸의 JDK를 선택하고 Modernize CLI를 실행합니다.

```bash
# zsh/bash
source ../scripts/use-java.sh --jdk 8
git status --short
before=$(git rev-parse HEAD)
modernize
```

```powershell
# PowerShell
. ../scripts/use-java.ps1 -Jdk 8
git status --short
$before = git rev-parse HEAD
modernize
```

> [!NOTE]
>
> Modernize는 작업별 커밋을 만들 수 있습니다. `$before`에는 실행 직전 커밋을 저장해 두고, 결과 검토 단계에서 실행 중 추가된 커밋과 변경 사항을 확인합니다.

화면에 표시되는 항목과 선택값은 다음과 같습니다. UI 표기는 설치된 버전에 따라 다를 수 있습니다.

| 항목 | 선택값 |
| --- | --- |
| How would you like to modernize your app? | Execute |
| Execute modernization plan | 선택 |
| Select a plan | `modernization-plan` (java) |
| Execute the plan | 선택 |

화면의 안내에 따라 계획을 선택하고 `Enter`를 눌러 실행합니다. 이후 에이전트가 질문하면 내용을 읽고 권장 옵션을 선택하거나 별도로 답변을 입력합니다.

> [!CAUTION]
>
> 중간에 실행을 중단하고 더이상 진행하지 않을 수도 있습니다. 이 때는 Copilot app을 이용해 문제를 해결해 가면서 끝까지 진행합니다.

## 업그레이드 결과 검증

현재 터미널에도 JDK 25를 적용하고 Maven Wrapper로 검증합니다. 다른 프로세스의 JDK 선택은 현재 터미널에 자동 적용되지 않습니다.

Windows:

```powershell
. ../scripts/use-java.ps1 -Jdk 25
./mvnw.cmd -version
./mvnw.cmd clean verify
```

macOS와 Linux:

```bash
source ../scripts/use-java.sh --jdk 25
./mvnw -version
./mvnw clean verify
```

각 명령의 결과를 확인하고 실패하면 다음 명령으로 진행하지 않습니다. Windows는 `$LASTEXITCODE`, macOS와 Linux는 명령 직후 `echo $?`를 확인합니다. Azure 연결이 필요한 통합 검사는 별도로 구분합니다.

생성된 로컬 실행 절차에 따라 web/worker를 실행하고 실습 1의 입력을 재사용합니다. Azure 코드도 변경됐으므로 원본 `dev` 실행 명령이 그대로 유효하다고 가정하지 않습니다.

## 실행 결과 검토

실행 직전 저장한 `$before`를 같은 터미널에서 사용합니다. 아래 Git 명령은 PowerShell과 Bash/Zsh에서 모두 실행할 수 있습니다.

```text
git status --short
git log --oneline "$before..HEAD"
git diff --stat "$before..HEAD"
git diff "$before..HEAD"
git diff
git diff --cached
```

`git diff`가 비어 있어도 자동 커밋에 변경이 있을 수 있습니다. 앱 밖의 파일, 비밀과 무관한 변경까지 확인합니다. CLI가 커밋하지 않은 변경만 범위를 검토해 별도로 커밋하며 `git add .`를 무조건 반복하지 않습니다.

## 완료 기준과 문제 해결

최종 Maven/컴파일/실행 JVM이 모두 25이고 루트 빌드와 기존 기능이 통과해야 합니다. Boot 버전만 바뀌거나 테스트를 제외한 패키징만 성공한 것은 완료가 아닙니다. 실패한 단계에서 멈춰 [문제 해결](08-troubleshooting.md)을 확인하고 `reset --hard`로 미검토 변경을 삭제하지 않습니다.
