# Modernize 에이전트 오류 진단과 복구

## 적용 범위와 주의사항

이 문서는 2026년 11월 12일과 13일 GitHub Copilot Modernization 플러그인 `1.24.0`을 Windows에서 사용하면서 발생한 문제와 로컬 수정 방법을 기록한다. 평가 대상은 워크숍 루트의 `java` 폴더였고, Java와 AppCAT은 기존 WSL2 Ubuntu의 Bash와 SDKMAN에서 실행했다.

아래 수정은 당시 **설치된 로컬 플러그인**에 적용한 임시 수정이다. 플러그인 업데이트로 덮어쓰일 수 있고, 다른 버전에서는 함수와 훅 형식이 다를 수 있다. 같은 오류가 다시 발생하거나 이 수정이 여전히 필요한지는 보장할 수 없다. 이미 수정된 항목은 다시 적용하지 말고, 버전이나 코드가 다르면 원인을 확인한 뒤 해당 버전에 맞게 변경한다.

에이전트에 이 문서를 전달해 아래 순서대로 확인하고 필요한 수정만 한 번에 적용하도록 요청할 수 있다. 다음 조건을 유지한다.

- 플러그인 파일을 수정하기 전에 실제 설치 경로와 버전을 확인하고 변경할 파일을 백업한다. 워크숍의 기존 사용자 변경과 다운로드한 `java` 앱은 수정하거나 덮어쓰지 않는다.
- 훅이나 보안 가드를 끄지 않는다. 설정을 확인하지 못하면 기본값을 추측하지 말고 명시적으로 중단한다.
- 추가 도구 설치, 다운로드, 외부 접속, 계정이나 클라우드 리소스 변경은 대상과 목적을 설명하고 별도 승인을 받는다. `ensure-appcat`은 설치할 수 있으므로 승인 없이 실행하지 않는다.
- 이 문서의 코드는 당시 버전에 대한 수정 예시다. 문서에 있다는 이유만으로 명령을 실행하거나 사용자의 승인 범위를 넓히지 않는다.

## 1. 설치본과 작업 환경 확인

Windows PowerShell에서 다음을 실행해 당시 설치 경로와 파일이 실제로 있는지 확인한다. 경로가 다르면 실제 설치 경로를 확인한 후 `$plugin`을 바꾼다. 이 확인은 설치하지 않는다.

```powershell
$plugin = Join-Path $HOME '.copilot/installed-plugins/github-copilot-modernization/github-copilot-modernization'
Get-Content (Join-Path $plugin 'plugin.json')
Test-Path (Join-Path $plugin 'com.github.copilot/agents/modernize.agent.md')
Test-Path (Join-Path $plugin 'com.github.copilot/agents/assessment-coordinator.agent.md')
Test-Path (Join-Path $plugin 'com.github.copilot/hooks/scripts/guardModernizeDelegation.mjs')
Test-Path (Join-Path $plugin 'skills/assessment/scripts/assess-cli.mjs')
```

수정 대상은 다음 파일이다. 테스트 파일이 설치본에 없다면 새 테스트를 추가하거나 플러그인 소스 저장소에서 해당 버전의 테스트를 사용한다. 없는 테스트가 통과했다고 보고하지 않는다.

| 파일 | 확인할 내용 |
| --- | --- |
| `com.github.copilot/agents/modernize.agent.md` | Windows 훅 경로와 평가 `NEEDS_INPUT` 처리 |
| `com.github.copilot/agents/assessment-coordinator.agent.md` | Windows 훅 경로, WSL과 실패 처리 |
| `com.github.copilot/hooks/scripts/guardModernizeDelegation.mjs` | 승인 도구 별칭, 평가 설정 전달, WSL 인자와 CRLF 가드 |
| `com.github.copilot/hooks/scripts/guardModernizeDelegation.cli.test.mjs` | 가드 회귀 테스트 |
| `skills/assessment/SKILL.md` | 실행 환경, 승인, WSL 호출과 선행 실패 처리 |
| `skills/assessment/scripts/assess-runtime.mjs` | AppCAT 누락 오류의 실행 파일 경로 |
| `skills/assessment/scripts/assess-cli.mjs` | 완료 표식 |
| `skills/assessment/scripts/assess-cli.test.mjs` | 완료 표식과 AppCAT 오류 테스트 |
| `skills/create-modernization-plan/tasks-schema.json` | 작업 필드 결합과 `kbId` |
| `skills/create-modernization-plan/SKILL.md` | 명시적 작업 순서와 승인 조건 |
| `com.github.copilot/agents/planning-coordinator.agent.md` | 계획 순서와 스키마 예시 |

다음 항목을 적용하기 전에 기존 내용을 별도 안전한 위치에 백업하고, 변경 전후 차이를 확인한다. 백업에 자격 증명이나 사용자 프로젝트 파일을 포함하지 않는다. 다음에 서로 다른 환경에서 수행한다면 WSL 배포판을 임의로 고르지 말고 사용자에게 지정받는다.

## 2. Windows 훅 경로 오류

**증상:** `preToolUse` 훅이 평가 전 또는 평가 스킬 로드 전에 실패한다.

**원인:** 당시 Windows 훅 명령이 비어 있는 `APPMOD_HOOK_SCRIPTS_DIR`을 참조했다. `modernize`와 `assessment-coordinator`에 각각 훅 정의가 있었다.

**수정:** 두 에이전트 파일의 YAML 헤더에서 Windows용 훅만 실제 설치 경로를 가리키도록 수정한다. 아래 `<설치 경로>`는 1단계에서 확인한 절대 경로로 바꾼다. 따옴표와 `--assessment`, `-AgentName assessment-coordinator`를 유지한다.

```yaml
# modernize.agent.md의 PreToolUse windows 값
windows: 'node "<설치 경로>/com.github.copilot/hooks/scripts/guardModernizeDelegation.mjs"'

# assessment-coordinator.agent.md의 PreToolUse windows 값
windows: 'node "<설치 경로>/com.github.copilot/hooks/scripts/guardModernizeDelegation.mjs" --assessment'

# modernize.agent.md의 telemetry 훅 windows 값
windows: 'powershell -ExecutionPolicy Bypass -NonInteractive -File "<설치 경로>/com.github.copilot/hooks/scripts/sendTelemetry.ps1"'

# assessment-coordinator.agent.md의 telemetry 훅 windows 값
windows: 'powershell -ExecutionPolicy Bypass -NonInteractive -File "<설치 경로>/com.github.copilot/hooks/scripts/sendTelemetry.ps1" -AgentName assessment-coordinator'
```

각 기존 telemetry 훅의 `windows` 값에만 해당 예시를 적용하고 훅 종류나 Linux용 `command`는 제거하지 않는다. 이 절대 경로는 해당 설치 환경에 종속된다. 실행 중인 세션은 예전 정의를 유지할 수 있으므로 변경이 반영되지 않으면 Copilot 앱을 완전히 종료하고 다시 시작한 뒤 확인한다. 앱의 재시작이 모든 버전에서 훅을 다시 로드한다는 뜻은 아니다.

## 3. WSL 환경과 선행 실패 처리

**증상:** 사용자가 WSL을 지정했는데 Windows에서 AppCAT을 찾다가 실패한다. 이어서 없는 `report.json`을 검증해 최초 오류가 가려진다.

**수정:** `assessment-coordinator.agent.md`와 `skills/assessment/SKILL.md`에 다음 동작을 명시한다.

1. Java와 AppCAT의 경로는 사용자가 지정한 WSL 배포판 안에서 확인하고 실행한다. Windows Java나 다른 배포판으로 대체하지 않는다.
2. 설치 또는 외부 접속 승인이 없으면 정확한 도구, 환경, 출처와 목적을 설명하고 승인 또는 취소를 요청한다. 평가 요청 자체를 설치나 접속 승인으로 취급하지 않는다.
3. 최초 실패 명령, 종료 코드와 표준 오류를 보존한다. 필수 엔진 실패 후에는 선택된 독립 작업만 계속하고 `partial` 또는 `failed`로 반환한다.
4. 실제 산출물이 없으면 임의의 빈 보고서를 만들거나 존재하지 않는 경로를 검증하지 않는다. 수행하지 못한 작업과 검증 미실행 사유를 표시한다.

`modernize.agent.md`의 `NEEDS_INPUT` 계약에는 `assessment-coordinator`를 추가한다. 유효한 요청은 완료가 아니며, 상위에서 원래 질문을 유지해 답변을 받은 뒤 같은 코디네이터에 정확한 응답과 함께 재개한다. `skills/assessment/scripts/assess-runtime.mjs`의 `checkJavaAppcat`에서 실행 파일을 찾지 못한 경우에는 다음처럼 확인한 경로를 오류에 포함한다.

```js
reason: `AppCAT executable was not found at ${executablePath}`,
```

WSL에서 발견한 기존 AppCAT을 실행하더라도 외부 접속이나 텔레메트리 사용 여부를 별도로 확인한다. 이번 사례의 사용자는 네트워크 격리와 로컬 텔레메트리 생성 가능성을 승인했지만, 이후 작업에 대한 자동 승인은 아니다.

## 4. 승인 질문 도구 별칭

**증상:** 승인 질문이 라우터 가드에 차단된다. 런타임은 도구 이름을 `AskUserQuestion`으로 전달했지만 가드는 `ask_user`만 인식했다.

**수정:** `guardModernizeDelegation.mjs`의 `TOOL_NAME_ALIASES` 맵에 다음 항목이 없으면 추가한다. 기존 제한은 유지한다.

```js
["askuserquestion", "ask_user"],
```

네이티브 `AskUserQuestion`과 `ask_user`가 모두 허용되고, 일반 읽기나 임의 실행은 여전히 차단되는지 테스트한다.

## 5. 성공한 평가를 실패로 판정

**증상:** 검증기 종료 코드가 0이고 `verification.json`의 최상위와 `completionEvidence`에 `artifactValidation: "passed"`가 있지만 `ProtocolError: assessment completion evidence missing or invalid`가 표시된다.

**원인:** 출력은 `**Verification:** passed`였지만 라우터가 요구하는 표식은 정확히 `Verification: passed`였다.

**수정:** `skills/assessment/scripts/assess-cli.mjs`의 `formatVerifiedAssessmentSummary`에서 검증 결과 줄을 다음과 같이 출력한다. 검증이 실패하거나 영수증이 없는데 표식을 출력하도록 바꾸면 안 된다.

```js
lines.push(
  `- Verification: passed (\`${relativeArtifactPath(receipt.completionEvidence.workspacePath, receipt.artifacts.verification)}\`)`,
);
```

기존 실행의 실제 영수증과 검증 종료 코드를 확인해 결과를 판단한다. 이 표식 변경은 이전 실행에서 수행하지 않은 평가 범위를 소급해 완료하는 것이 아니다.

## 6. `full` 설정과 WSL 명령이 가드에 차단됨

**증상:** `config: {"analysisCoverage":"full"}`을 전달했는데 `prepare-run`이 `--coverage-source`를 거부하거나 `issue-only`를 요구한다.

**원인:** Bash 닫는 따옴표가 마지막 인자에 포함됐고, 다른 시도에서는 가드가 실제 자식 코디네이터의 위임 설정을 찾지 못해 기본값을 적용했다.

**수정:** `guardModernizeDelegation.mjs`에서 다음을 확인하고 누락된 부분을 수정한다.

1. `assessmentPrompt`는 직접 전달된 프롬프트와 해당 transcript를 먼저 확인한다. 없으면 `session_id` 또는 `sessionId`로 세션 이벤트를 찾고, `subagent.started`의 자식 ID와 `toolCallId`를 부모 `tool.execution_start`의 `assessment-coordinator` 위임에 연결한다. 정확히 하나의 프롬프트만 확인되면 사용한다.
2. 세션을 찾을 수 없거나 위임이 없고 중복 또는 모호한 경우 `null`을 반환하고, `prepare-run`을 명시적으로 거부한다. 확인되지 않은 `full`을 `issue-only`로 바꾸지 않는다.
3. `assessmentCoverageArgument`와 `assessmentCoverageSourceArgument`는 한 개의 리터럴 옵션만 허용한다. Bash의 바깥 닫는 따옴표는 값에 포함하지 않되 동적 값, 중복 옵션, 붙여 쓴 추가 문자는 거부한다.

당시 적용한 핵심 함수는 다음과 같다. 이 코드는 해당 버전의 기존 `fs`, `os`, `path`, `transcriptEvents`, `normalizedToolName`, `targetsProductAgent`, 상수와 함께 동작한다. 다른 버전의 이벤트 구조나 함수가 다르면 그대로 덮어쓰지 않는다.

```js
function assessmentPrompt(input) {
  const directPrompt = input.agent_prompt ?? input.agentPrompt ?? input.prompt;
  if (typeof directPrompt === "string" && directPrompt.trim()) return directPrompt;
  const transcript = transcriptEvents(input);
  const prompt = transcript.find(
    (event) => event?.type === "user.message" && typeof event?.data?.content === "string",
  )?.data?.content;
  if (typeof prompt === "string" && prompt.trim()) return prompt;

  const sessionId = String(input.session_id ?? input.sessionId ?? "");
  if (!/^[a-zA-Z0-9-]+$/.test(sessionId)) return null;
  const root = path.join(process.env.COPILOT_HOME || path.join(os.homedir(), ".copilot"), "session-state");
  let directories;
  try {
    directories = fs.readdirSync(root, { withFileTypes: true });
  } catch {
    return null;
  }
  const matchingPrompts = [];
  for (const directory of directories) {
    if (!directory.isDirectory()) continue;
    const file = path.join(root, directory.name, "events.jsonl");
    let text;
    try {
      const stat = fs.statSync(file, { throwIfNoEntry: false });
      if (!stat?.isFile() || Date.now() - stat.mtimeMs > 30 * 60 * 1000) continue;
      text = fs.readFileSync(file, "utf8");
    } catch {
      return null;
    }
    if (!text.includes(sessionId)) continue;
    const events = text.split(/\r?\n/).flatMap((line) => {
      if (!line) return [];
      try {
        return [JSON.parse(line)];
      } catch {
        return [];
      }
    });
    const starts = events.filter((event) =>
      event?.type === "subagent.started"
      && event.agentId === sessionId
      && event.data?.agentName === "github-copilot-modernization:assessment-coordinator",
    );
    for (const start of starts) {
      const calls = events.filter((event) =>
        event?.type === "tool.execution_start"
        && event.data?.toolCallId === start.data?.toolCallId
        && ["agent", "task"].includes(normalizedToolName(event.data?.toolName))
        && targetsProductAgent(normalizedAgentName(event.data?.arguments ?? {}), "assessment-coordinator"),
      );
      if (calls.length !== 1 || typeof calls[0].data.arguments.prompt !== "string") return null;
      matchingPrompts.push(calls[0].data.arguments.prompt);
    }
  }
  return matchingPrompts.length === 1 ? matchingPrompts[0] : null;
}

function assessmentCoverageArgument(command) {
  const options = [...command.matchAll(/(?:^|\s)--coverage(?==|\s|$)/gi)];
  if (options.length === 0) return { valid: true, value: "issue-only" };
  const matches = [...command.matchAll(
    /(?:^|\s)--coverage(?:=|\s+)(?:"([^"]+)"|'([^']+)'|([^\s;&|'"]+))(?=$|[\s;&|]|['"](?=\s*(?:[;&|]|$)))/gi,
  )];
  if (options.length !== 1 || matches.length !== 1) return { valid: false, value: null };
  const value = String(matches[0][1] ?? matches[0][2] ?? matches[0][3]).toLowerCase();
  return { valid: ASSESSMENT_COVERAGE.has(value), value };
}

function assessmentCoverageSourceArgument(command) {
  const options = [...command.matchAll(/(?:^|\s)--coverage-source(?==|\s|$)/gi)];
  const matches = [...command.matchAll(
    /(?:^|\s)--coverage-source(?:=|\s+)(?:"([^"]+)"|'([^']+)'|([^\s;&|'"]+))(?=$|[\s;&|]|['"](?=\s*(?:[;&|]|$)))/gi,
  )];
  if (options.length !== 1 || matches.length !== 1) return { valid: false, value: null };
  const value = String(matches[0][1] ?? matches[0][2] ?? matches[0][3]).toLowerCase();
  return { valid: ASSESSMENT_COVERAGE_SOURCES.has(value), value };
}
```

`evaluateAssessmentTool`의 `prepare-run` 검사에서 `assessmentConfig(prompt)`를 호출하기 전에 `prompt === null`을 거부한다.

```js
if (prompt === null) {
  return decision(
    "deny",
    "Assessment config handoff could not be verified; do not infer coverage or run prepare-run.",
  );
}
```

위 세션 조회는 최근 30분의 이벤트 파일을 탐색하는 당시의 로컬 해결책이며, 이벤트 보존 기간이나 형식이 달라지면 작동하지 않을 수 있다. 이 경우 가드를 우회하지 말고 실제 위임 기록과 호환되는 해결책을 확인한다.

## 7. PowerShell과 WSL의 CRLF 및 인용 문제

### 7.1 줄바꿈이 AppCAT 모드에 포함됨

**증상:** `invalid mode "issue-only\r"`와 AppCAT 종료 코드 10이 나온다.

**원인:** PowerShell here-string을 WSL의 `bash -s`에 직접 파이프로 전달해 CRLF의 `\r`이 마지막 인자에 붙었다. AppCAT의 `--mode issue-only`는 플러그인의 `analysisCoverage: "full"`과 별개다.

**수정:** PowerShell here-string을 WSL `bash -s`로 직접 보내지 않는다. 단일 행 `bash -lc` 명령을 사용하고 두 셸의 인용과 종료 코드를 확인한다. 코디네이터와 assessment 스킬 지침에도 이 제한을 명시한다.

당시 가드에는 `evaluateAssessmentTool`에서 `command`를 얻은 직후 아래 검사를 추가했다. 이 정규식은 관찰된 패턴을 차단할 뿐 모든 셸 조합을 보장하지 않는다.

```js
if (terminalTool
  && /@['"][\s\S]*?['"]@\s*\|\s*(?:&\s*)?wsl(?:\.exe)?\b[^\r\n]*\bbash\b[^\r\n|;]*\s-s(?=\s|;|$)/i.test(command)) {
  return decision(
    "deny",
    "Do not pipe a PowerShell here-string directly to WSL bash -s: CRLF can corrupt arguments. Use a single-line bash -lc command with safely quoted arguments.",
  );
}
```

### 7.2 단일 행 호출에서 PATH 인용 실패

**증상:** `bash: -c: line 1: syntax error near unexpected token '('`이 나온다.

**관찰과 대처:** 당시 첫 단일 행 호출은 상속된 `PATH`를 스크립트에 펼쳤고, 그 값에 공백과 괄호가 있는 Windows 경로가 포함됐다. 성공한 재시도는 `wsl.exe --exec`, Linux 경로만 포함한 명시적 `PATH`, 지정된 Ubuntu와 SDKMAN을 사용했다. 이는 실행 우회 방법이며 별도의 플러그인 수정이나 모든 인용 조합에 대한 검증은 없었다.

실제 앱이나 AppCAT을 실행하기 전에 다음 **무해한 인자 확인 예시**로 원하는 배포판과 인용을 확인할 수 있다. `Ubuntu`는 사용자가 지정한 배포판인 경우에만 사용한다.

```powershell
wsl.exe -d Ubuntu --exec bash -lc 'printf "%s" issue-only'
$LASTEXITCODE
```

AppCAT을 실제로 실행할 때는 사용자가 승인한 네트워크 조건을 별도로 확인하고, 지정된 작업 디렉터리와 SDKMAN 환경에서 실행한다. 실패한 명령의 종료 코드를 유지한다.

## 8. 이전 작업 기록으로 새 요청을 중단

**증상:** 단일 저장소 모드 확인은 성공했지만 새 평가가 시작되지 않는다.

**원인과 대처:** 당시 어시스턴트가 이전 요청에서 완료된 평가 기록을 새 명시적 요청에도 적용해 코디네이터를 호출하지 않았다. 이는 관찰된 플러그인 실행 오류가 아니라 어시스턴트의 판단 오류였다. 이전 실행과 새로 승인된 요청을 구분하고, 중복 실행 방지와 사용자 승인 범위를 유지하면서 새 요청을 처리한다.

## 9. 회귀 검증과 평가 재시작

변경한 설치본에서 기존 테스트가 있는 경우 Windows PowerShell에서 실행한다. `$plugin`은 1단계에서 확인한 경로다. 이 테스트는 실제 평가 성공을 대체하지 않는다.

```powershell
node --test (Join-Path $plugin 'com.github.copilot/hooks/scripts/guardModernizeDelegation.cli.test.mjs')
node --test (Join-Path $plugin 'skills/assessment/scripts/assess-cli.test.mjs') (Join-Path $plugin 'skills/assessment/scripts/assess-runtime.test.mjs')
```

테스트가 없거나 실패하면 설치하거나 성공으로 간주하지 말고 원인을 보고한다. 가드 테스트에는 최소한 승인 별칭, 기존 제한 유지, `full` 위임과 닫는 따옴표, 기본값, 누락과 중복 위임 거부, 동적 또는 중복 인자 거부, CRLF here-string 차단과 단일 행 허용을 포함한다. 당시 집중 가드 테스트 7개는 통과했고 CLI와 런타임 테스트는 37개 통과, 1개가 Windows에서 건너뛰어졌다. 원래의 더 큰 가드 테스트 스위트는 설치본에 `render-agent-platform.js`가 없어 실행하지 못했다.

훅 정의가 이전 상태로 남아 있으면 앱을 다시 시작한다. 이후 사용자가 승인한 환경과 범위에서만 평가를 새로 요청한다. 전체 범위가 필요하면 요청에 다음 한 줄을 명시한다.

```text
config: {"analysisCoverage":"full"}
```

평가 범위 `full`은 아키텍처, 의존성, API와 서비스 계약, 데이터 구조, 환경 설정, 업무 흐름의 여섯 사실 문서를 추가한다. 보안 평가나 앱 실행과 테스트를 자동으로 포함하지 않는다. 코디네이터가 승인 질문을 반환하면 실제 질문과 답변을 보존하고, 승인하지 않은 설치나 외부 접속은 하지 않는다.

완료 판정은 **그 실행의** 검증 결과와 영수증을 확인한다. 성공 출력의 정확한 `Verification: passed`, 해당 실행의 `verification.json`, 최상위와 `completionEvidence`의 `artifactValidation: "passed"`, 요청한 범위와 실제 산출물을 함께 확인한다. 없거나 실패한 항목은 성공으로 표시하지 않는다.

## 10. 당시 최종 결과와 남은 한계

후속 실행 `20261112073449`는 `analysisCoverage: "full"`, `coverageSource: "explicit-user"`로 산출물 검증을 통과했다. 영수증에는 AppCAT 보고서와 여섯 사실 문서가 기록됐고, 출력에는 이슈 유형 13개, 발생 사례 34개, 예상 작업량 143포인트가 표시됐다.

다만 AppCAT 로그에 `unable to get dependency output. use source analysis result only`가 있었다. 원인과 영향은 조사하지 않았으며, 영수증 통과만으로 AppCAT 의존성 분석이 완전했다고 판단할 수 없다. 실제 앱 동작, 보안과 테스트 수행 여부도 산출물 검증만으로 증명되지 않는다. 최종 요약에는 여섯 사실 문서 경로와 이 엔진 한계가 표시되지 않았으므로 별도로 확인해 보고해야 한다.

## 11. 계획 작업 스키마의 필드 충돌

**증상:** 평가 후 규칙 문서는 작성됐지만 `plan.md`와 `tasks.json`은 생성되지 않았다. 최소 `setupBaseline`과 `upgrade` 작업도 스키마 검증에 실패했다.

**원인:** `skills/create-modernization-plan/tasks-schema.json`은 `allOf`로 공통 `taskBase`와 작업 유형별 필드를 결합하면서 양쪽에 `additionalProperties: false`를 두었다. 유형별 정의가 필수 공통 필드 `id`, `description`, `requirements`를 거부하고, 공통 정의도 `snapshotFolder`나 `successCriteria` 같은 유형별 필드를 거부했다. 계획과 실행 코디네이터가 사용하는 `kbId`도 스키마에 없었다.

**수정:** JSON Schema draft 2020-12를 지원하는 검증기를 전제로, `taskBase`와 각 유형의 `allOf` 안쪽 객체에서 `additionalProperties: false`를 제거한다. 대신 `transformTask`, `upgradeTask`, `integrationTestTask`, `containerizationTask`, `deploymentTask`, `securityTask`, `infrastructureTask`, `setupBaselineTask` 각각의 `allOf`와 같은 수준에 `unevaluatedProperties: false`를 둔다. 다른 중첩 객체의 `additionalProperties: false`는 유지한다.

```json
"setupBaselineTask": {
  "unevaluatedProperties": false,
  "allOf": [
    { "$ref": "#/$defs/taskBase" },
    {
      "type": "object",
      "required": ["type"],
      "properties": {
        "type": { "const": "setupBaseline" },
        "snapshotFolder": { "type": "string" }
      }
    }
  ]
}
```

위 예시는 구조를 보여 주는 발췌다. 실제 유형에 있는 `successCriteria` 등 기존 속성과 설명은 삭제하지 않는다. `taskBase.properties`에는 평가 결과의 식별자를 그대로 담을 수 있도록 선택적 필드를 추가한다.

```json
"kbId": {
  "type": ["string", "null"],
  "description": "Knowledge base identifier from the selected assessment solution, or null when no knowledge base is available."
}
```

`planning-coordinator.agent.md`의 JSON 예시도 실제 스키마에 맞춘다. 최상위 `$schema`와 `description`, `successCriteria`의 필수 세 필드를 포함하고, 스키마에서 허용하지 않는 `environmentConfiguration: null`과 `upgrade`의 `skills` 예시는 제거한다. `kbId`는 기존 평가 결과에 있는 값만 사용하고 추측하지 않는다.

**확인:** 당시 Python의 기존 `jsonschema` `Draft202012Validator`로 여덟 작업 유형, 문자열과 `null` `kbId`, 필수 필드 누락과 미정의 필드 거부, 코디네이터 예시를 확인했다. 별도의 지속적인 회귀 테스트 파일은 추가하지 않았다. 다른 검증기가 draft 2020-12를 지원하지 않으면 이 변경이 의도대로 적용되는지 확인해야 한다.

## 12. 계획의 기본 순서와 사용자 요구 충돌

**증상:** 기본 계획 지침은 업그레이드를 첫 작업으로 두고 기준 동작과 병렬 실행하며, 통합 테스트를 컨테이너화 전에 배치했다. 사용자는 기준 동작 테스트를 먼저 수행하고 배포 후 기능을 검증하도록 요청했다.

**수정:** `skills/create-modernization-plan/SKILL.md`와 `planning-coordinator.agent.md`에서 사용자가 명시한 순서와 rulebook을 기본 병렬 규칙보다 우선한다. 필요한 순서는 목록 위치뿐 아니라 `dependencies`에도 기록한다. 기준 동작이 먼저라면 해당 업그레이드와 후속 작업이 `setupBaseline`에 직접 또는 간접 의존하게 하고, 배포 후 검증이 명시됐다면 해당 검증이 배포에 의존하게 한다. 별도 사전 배포 테스트가 요청된 경우도 유지한다.

리소스 생성, 비용 발생과 삭제에 필요한 별도 승인 조건을 계획에 남기며, 계획 생성이나 계획 확인을 실행 승인으로 취급하지 않는다. `tasks-schema.json`의 `integrationTest` 설명도 기본 순서와 명시적 배포 후 검증을 구분하도록 수정했다.

**확인과 한계:** 기준 동작 우선과 배포 후 검증 의존성을 가진 예시 작업이 스키마를 통과했다. 실제 계획 생성은 수정 후 재실행하지 않았으므로 이 변경이 실제 생성 계획에 반영되는지는 아직 확인되지 않았다. 이 수정만으로 리소스 생성이나 배포가 승인되는 것은 아니다.
