# Modernize Agent Troubleshooting Report

## Context

On November 12, 2026, a single-repository assessment of the Asset Manager Java
application was attempted with the GitHub Copilot Modernization plugin. The
installed plugin identified itself as version `1.24.0`. Copilot ran on Windows;
the application and Java tools were in the existing WSL2 Ubuntu distribution.
The application root was the workshop's `java` directory, with `web` and
`worker` modules. The user reported that the original application used Java 8
and Spring Boot 2.7.18 and had already been run locally.

The user permitted assessment artifacts but prohibited source changes, package
updates, resource creation, and deployment. Additional installations and
external service access required prior approval. The user approved using the
existing WSL AppCAT under network isolation, including the possibility of local
telemetry; this did not approve downloads or external access.

The fixes below were applied to the **local installed plugin**, not to the
plugin's source repository. They may be overwritten by a plugin update. Paths
under `com.github.copilot/` and `skills/` are relative to the installed plugin.

## Issues and local resolutions

### 1. Windows hook script path was unavailable

**Symptom:** A `preToolUse` hook failed before the workspace mode check, so the
assessment did not start. A subsequent attempt failed when the
`assessment-coordinator` tried to load its assessment skill.

**Cause:** Windows hook commands referenced `APPMOD_HOOK_SCRIPTS_DIR`, which was
empty in this environment. The router and the assessment coordinator had
separate affected hook definitions.

**Local resolution:** Updated the Windows hook commands in
`com.github.copilot/agents/modernize.agent.md` and
`com.github.copilot/agents/assessment-coordinator.agent.md` to use the actual
installed script paths. The guards remained enabled. Direct hook execution
passed, but an already-running session continued to use its previous hook
definition; restarting Copilot was needed to pick up the change.

**Follow-up for the plugin team:** Resolve hook paths reliably on Windows
without relying on a machine-specific absolute path, and clarify when changed
agent definitions are reloaded.

### 2. Wrong execution environment and masked engine failure

**Symptom:** The assessment looked for AppCAT on Windows even though the user
specified WSL. After the engine failed, the workflow attempted to validate a
nonexistent `report.json`, obscuring the original failure with a missing-report
error.

**Local resolution:** Updated the assessment coordinator and
`skills/assessment/SKILL.md` to honor the requested environment, check existing
tools before requesting installation approval, preserve the first failing
command and error, and avoid validating artifacts that were never produced.
`skills/assessment/scripts/assess-runtime.mjs` was also updated to include the
expected executable path in the missing-AppCAT error.

**Limit:** These changes do not authorize installations or external access.
Those actions still require the user's approval.

### 3. Approval question blocked by the router guard

**Symptom:** An approval request for the environment and possible dependency
access was rejected by the router's guard, preventing the assessment from
continuing.

**Cause:** The runtime presented the question tool as `AskUserQuestion`, but
the guard did not recognize that name as the allowed `ask_user` tool.

**Local resolution:** Added the alias in
`com.github.copilot/hooks/scripts/guardModernizeDelegation.mjs` and added
focused tests in `guardModernizeDelegation.cli.test.mjs`. The existing router
restrictions remained in place.

### 4. Successful verification was initially reported as failed

**Symptom:** An `issue-only` run returned
`ProtocolError: assessment completion evidence missing or invalid`, although
its verifier exited with code 0. The run's `verification.json` recorded
`artifactValidation: "passed"` both at the top level and in
`completionEvidence`.

**Cause:** The verifier printed `**Verification:** passed`, while the router
expected the exact text `Verification: passed`. The difference in Markdown
formatting led to an incorrect failure judgment.

**Local resolution:** Changed `skills/assessment/scripts/assess-cli.mjs` to
emit the exact required marker and added a regression test. The changed output
was checked against the existing verification receipt without rerunning that
assessment.

**Scope:** This established success only for that `issue-only` run, not for
the later requested full-coverage assessment.

### 5. Full-coverage handoff was incorrectly rejected

**Symptom:** With `config: {"analysisCoverage":"full"}`, two `prepare-run`
attempts were denied. The first rejected the `--coverage-source` value; the
second required `issue-only` despite the explicit `full` handoff.

**Causes:**

1. The guard included the closing Bash quote in the final `explicit-user`
   argument.
2. The guard could not find the child coordinator's actual configuration in
   the session records and treated the missing handoff as the default.

**Local resolution:** Corrected the WSL argument handling and connected the
child agent's start event to the actual parent delegation event when reading
the configuration. Missing, duplicate, or ambiguous handoffs now fail closed
rather than silently defaulting. Previously rejected hook inputs were replayed
without running the assessment command, and focused regression tests passed.

**Clarification:** `analysisCoverage` supports both `issue-only` and `full`.
`full` adds six fact documents; it does not by itself select a security
assessment or run the application and its tests.

### 6. PowerShell-to-WSL line endings corrupted an AppCAT argument

**Symptom:** A later full-coverage attempt produced six fact documents, but
AppCAT rejected `--mode issue-only\r` with `invalid mode "issue-only\r"`.
AppCAT exited with code 10 and the assessment CLI exited with code 2.
Neither the final report nor its verification was produced for that run.

**Cause:** A PowerShell here-string was piped directly to WSL `bash -s`. The
carriage return from CRLF became part of the last argument on a line. The same
behavior was reproduced with a harmless command. The AppCAT mode
`issue-only` is separate from the assessment's `full` coverage setting; the
trailing carriage return, not the mode choice, caused this failure.

**Local resolution:** Updated the coordinator and assessment skill instructions
to use a safely quoted, single-line `bash -lc` invocation from PowerShell and
preserve the exit status. Added a guard against the observed direct
here-string-to-`bash -s` pattern, with regression tests. The original failing
tool input was replayed through the guard and was denied. This guard addresses
the observed pattern; it is not proof that every possible shell invocation is
protected.

### 7. A single-line WSL retry encountered a separate quoting error

**Symptom:** During the final assessment, an initial single-line WSL command
failed with `bash: -c: line 1: syntax error near unexpected token '('` and exit
code 2.

**Observed cause and workaround:** The logged command was split in a way that
expanded the inherited WSL `PATH` into the Bash script; Windows paths in that
value contained spaces and parentheses. The coordinator retried with
`wsl.exe --exec`, an explicit Linux-only `PATH`, the requested Ubuntu
distribution, and SDKMAN. AppCAT then completed with exit code 0. This was an
invocation workaround; no separate plugin fix for this quoting issue was
made or validated.

### 8. A fresh request was incorrectly stopped by the assistant

After the CRLF fix, a fresh user request did not start an assessment. The
assistant incorrectly applied the completed phase record from an earlier
request to the new request and stopped before delegating. The workspace mode
probe had succeeded. This was an assistant judgment error, not an observed
plugin execution failure; a subsequent explicit request started a new
assessment.

## Final outcome and remaining limits

The subsequent full-coverage run, `20261112073449`, completed artifact
verification. Its `verification.json` records `status: "success"`,
`artifactValidation: "passed"`, `analysisCoverage: "full"`, and
`coverageSource: "explicit-user"`. The receipt lists the AppCAT report and all
six fact documents. The verifier reported 13 issue types, 34 incidents, and
143 estimated effort points.

The successful AppCAT log also said `unable to get dependency output. use
source analysis result only`. Consequently, the passed artifact verification
must not be interpreted as proof that AppCAT dependency analysis was complete.
The cause and impact of the missing dependency output were not investigated.
The receipt confirms artifact validation, not that every application behavior,
dependency, security concern, or runtime test was independently verified.

The final verifier output did not itself include the six fact-document paths or
the detailed findings requested by the user, although the receipt lists the
fact paths. Consider surfacing these paths and partial-engine limitations in
the user-facing completion summary.

Focused guard and assessment CLI/runtime tests passed after the local changes;
one runtime test was skipped on Windows. The original broader guard test suite
could not be run because the installed plugin lacked
`render-agent-platform.js`. The final real assessment provides end-to-end
evidence for the successful path in this environment, not for every platform
or failure path.
