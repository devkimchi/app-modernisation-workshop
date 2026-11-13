# Contributing

Thank you for helping improve this workshop. By participating, you agree to follow the [Code of Conduct](CODE_OF_CONDUCT.md).

## Scope and changes

Keep changes focused on the workshop instructions, preparation scripts, and regression tests. Explain learner-facing changes in the relevant documentation and preserve upstream source licenses and notices when working with downloaded samples. Do not commit credentials, local configuration, downloaded applications, or generated test output.

The sample download scripts record the source and pinned commit SHA in `upstream-source.json` and preserve upstream licenses and notices as `UPSTREAM-*` files. They do not modify the original code or target framework, create a separate `.git` inside the sample, or commit or push the download. Preserve this behavior when maintaining the scripts.

## Local checks

Run the relevant regression tests before opening a pull request. These developer checks require no additional test packages and use fixtures and mocked command responses without changing real accounts or OS features. Workshop participants do not need to run them; use the prerequisite checks in the [Java setup](docs/java/00-setup.md) or [.NET setup](docs/dotnet/00-setup.md) instead.

PowerShell:

```powershell
pwsh -NoProfile -File ./tests/scripts.tests.ps1
pwsh -NoProfile -File ./tests/dotnet-original.tests.ps1
pwsh -NoProfile -File ./tests/install-prerequisites.tests.ps1
pwsh -NoProfile -File ./tests/windows-prerequisite-updates.tests.ps1
pwsh -NoProfile -File ./tests/azure-actions.tests.ps1
pwsh -NoProfile -File ./tests/powershell-bootstrap.tests.ps1
pwsh -NoProfile -File ./tests/java-tools.tests.ps1
```

On Windows, `.ps1` entrypoints also accept `powershell.exe -NoProfile -File ./path/to/script.ps1` from Windows PowerShell 5.1 and delegate to PowerShell 7. PowerShell 7 is required before production work in both tracks. Only the installer may offer its installation, with separate consent; CI, redirected input/output and `-NonInteractive` sessions cannot install. Participant instructions use direct script invocation. If the current window is `Restricted`, they may apply `Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned`; never change User/Machine policy or bypass organizational policy.

The bootstrap suite uses real Windows PowerShell 5.1 subprocesses against isolated script copies with mocked prerequisite discovery to verify parsing, early failure and delegation. No real installation, login or OS modification is performed. Repeat the commands above with `powershell.exe -NoProfile -File` to verify the 5.1 entry path on Windows. The Java helper suite covers injected discovery roots, java/javac validation, missing or mismatched JDKs, app-root checks, direct-execution refusal, PowerShell 7 dot-sourcing, 5.1 caller preservation and non-accumulating PATH changes.

Interactive delegation inherits console handles without an output pipeline; noninteractive delegation still passes `-NonInteractive`. Bootstrap fixtures verify launch options, argument preservation and exit codes, but do not replace a real-terminal check of interactive prompts.

The Windows update suite mocks nvm-windows/winget, release discovery and process launching. It covers shared Java/.NET Node installs and same-major updates (22 fallback only for missing/unsupported Node), separate activation consent, provenance/link collisions, failures and noninteractive denial. Both v1 settings/symlinks and v2 configured roots/shim/link modes are covered. V2 auto-install is refused before Node probes; activation uses `--no-install`, and failed tool preparation skips further probes. Activation changes the common Windows selection for subsequent invocations, not running Node processes; existing versions are retained. `-Update` also supports winget/MSI-managed stable PowerShell 7. A Windows PowerShell worker waits for the current pwsh to exit before upgrading, verifies the result and never reenters the installer; scheduling returns exit code 1, not success. Store/ZIP/unrecognized installs remain manual. Tests do not execute the real worker or update the OS. Azure CLI/azd retain consent-based missing-tool installation.

Keep `.ps1` files UTF-8 **with BOM** and LF (see `.editorconfig`): Windows PowerShell 5.1 otherwise decodes Korean text using the system ANSI code page before delegation. Do not add PowerShell 7-only syntax to these entrypoint files; the entire file must parse in 5.1. Dot-source helpers only inside PowerShell 7 when caller-scope functions/variables are needed; 5.1 dot-sourcing fails explicitly without exiting the caller because a child process cannot populate that scope. Common helper files remain definition-only. The deliberate exception is `use-java.ps1`, which changes only the caller's session JDK, never host installation or persistent environment variables.

The .NET original-app tests use isolated fixtures and mocked native invocations; they never start IIS Express or access LocalDB/MSMQ. A real Windows sample restore/build and browser workflow remain separate rehearsal checks.

The PowerShell installer suite mocks .NET SDK discovery and winget installation. It covers consent, missing winget, installation and verification failures, runtime-only and preview-only installations, and coexistence with older SDKs. By default the .NET track installs a stable 10.x SDK only when missing. With `-Update`, it compares installed SDKs with winget's latest stable 10.x, requires separate consent, pins and verifies the requested version, and never downgrades or selects another major or preview. Other major SDKs and `global.json` are unchanged; the installer may replace older patches in the same feature band. No real SDK is installed by these tests.

Native Java checks and installation use the same common Windows Node path and verify Temurin JDK 8/25 separately. Regression cases cover Temurin `--custom "ADDLOCAL=FeatureMain"` arguments, installed-JDK reuse, missing tools and consent refusal. Modernize/gh checks cover absence, execution failure, gh's minimum version and authentication failure; successful gh authentication is not proof of Copilot model access. Direct invocation must preserve the caller's working directory and restore temporary environment changes, while intentional installer PATH refresh remains session-local. Non-Windows `.ps1` use must fail with `.sh` guidance rather than delegating.

Bash:

```bash
bash tests/scripts.tests.sh
bash tests/install-prerequisites.tests.sh
bash tests/azure-actions.tests.sh
bash tests/use-java.tests.sh
bash tests/shell-portability.tests.sh
```

Run the suites on macOS and Linux. On macOS, use `/bin/bash tests/<suite>.tests.sh` for each suite to verify the built-in Bash 3.2, not a Homebrew Bash selected by PATH. The `use-java.sh` cases also require Zsh (install it separately on Ubuntu if absent). CI runs Bash 5/GNU on Ubuntu and `/bin/bash` 3.2/BSD on macOS, setting PATH so `env bash` also resolves to the intended Bash.

The installer suite covers opt-in Bash `--update`, per-tool consent, provenance checks, version selection and failures with isolated SDKMAN/nvm/Homebrew/APT fixtures and real symbolic links. Node uses the latest stable version of the active major (22 fallback only for missing/unsupported Node), with separate installation and activation consent. Installation uses `--no-use`; existing versions and default aliases are retained, and activation only changes the script environment, never the caller's shell. It never installs or updates real tools. Bash `--update` and Windows `-Update` are independent; Windows Node for both tracks uses nvm-windows, not the Bash nvm installation.

Keep all `.sh` files compatible with Bash 3.2 and Bash 5, with `#!/usr/bin/env bash` and LF. Do not add `mapfile`/`readarray`, associative arrays, namerefs, case-conversion expansions, newer shell operators or `set -u` empty-array assumptions. Use options shared by BSD/GNU; avoid `sed -i`, `readlink -f`, `realpath`, `date -d`, `grep -P`, `sort -V` and similar platform-specific conveniences. Keep OS-only tools inside their guarded branches. `use-java.sh` must source correctly in Bash and Zsh without leaking helper functions or changing caller options.

The portability suite checks syntax, shebangs, prohibited constructs/platform-specific command locations and Git modes. Directly executed scripts/tests use `100755`; source-only `use-java.sh` uses `100644`. Verify modes with `git ls-files -s scripts tests`, including on Windows where `core.fileMode=false` can hide working-tree mode changes. Entrypoint fixtures cover direct execution, non-Bash guards, supported OS detection and .NET rejection. Installer fixtures cover each official installer's interpreter, Homebrew-first consent/failure and fully qualified Modernize cask installation, Linux apt/manual paths and Modernize PATH handling. JDK source tests cover Bash/Zsh parsing, missing/mismatched JDKs, app-root checks and preserved caller options.

Scenarios that simulate missing tools or invalid commits may print `FAIL` or `fatal`. Judge the test run by its final `PASS` summary and exit code `0`.

Linux azd script-install fixtures cover fresh installs, explicit adoption of existing default-layout installs, separate update consent, package-ownership refusal, local path/version/SHA-256 records, changed files, and installer/runtime failures. Official-script installs and updates use the same installer; APT-owned installs retain the verified Microsoft APT route. Fixtures never run the real installer or change system paths.

The `azure-actions` suites verify that login, subscription selection, extension installation and provider registration require installer consent, and that prerequisite checks only query state even in interactive sessions. Run `bash tests/azure-actions.tests.sh` alongside the Bash suites; the PowerShell command is listed above. Download prechecks use the same query-only checks.

These tests do not replace real Windows/macOS/Linux checks or verify the full modernization and Azure deployment workflow. See the [Java](docs/java/08-troubleshooting.md#대체-엔진-설정) and [.NET](docs/dotnet/08-troubleshooting.md#대체-엔진-설정) troubleshooting guides for alternative-engine procedures.

## Instructor rehearsal checklist

Record tool versions, model, OS/shell, actual commands, exit codes and passed/failed/not-run outcomes. Keep private logs, credentials and downloaded applications out of this repository. Obtain individual consent before installations, model-consuming operations, authentication changes and cloud/data changes.

**Evidence for this migration (2026-11-13):** Modernize CLI `1.0.95` was available after its local update. Read-only `modernize --version`, `modernize assess --help`, `modernize plan create --help` and `modernize plan execute --help` confirmed the interface, including `--assess-file-path`, `--plan-name`, `--source` and the default assessment output `.github/modernize/assessment`. This is not a successful assessment or migration.

An individually approved Windows installation of `EclipseAdoptium.Temurin.8.JDK` with `--exact --source winget --custom "ADDLOCAL=FeatureMain"` completed at `8.0.512.9`. `java` and `javac` reported `1.8.0_512`; User/Machine PATH and `JAVA_HOME` were unchanged. The Java discovery helper found the installed JDK. File associations were not independently checked. JDK 25 installation, live `assess`/`plan create`/`plan execute`, Windows sample runtime and Azure deployment were not performed as part of this evidence. Do not mark the remaining checks below complete based on help output or fixture tests.

- [ ] **Windows setup:** confirm Copilot app terminal shell, direct 5.1 entry and PowerShell 7 delegation, exit codes and caller survival. On a `Restricted` window, verify Process-only `RemoteSigned` and unchanged policy in a new window. Verify session PATH refresh after direct installation.
- [ ] **Windows Java:** rehearse both Temurin versions with UAC and `FeatureMain`; verify registry discovery, JDK versions, persistent PATH/`JAVA_HOME` and file associations. Dot-source `use-java.ps1` in PowerShell 7, run JDK 8 `mvnw.cmd clean verify`, and verify JDK 25 selection. Check downloaded `.cmd` line endings, Web Module/Worker Module windows, PID files, start/stop and container cleanup.
- [ ] **Windows .NET:** restore/build the pinned v4.8 sample with the existing MSBuild helper, run IIS Express with explicit DB-initialization consent, and verify LocalDB/MSMQ and all baseline browser actions.
- [ ] **Copilot app terminal:** test TUI rendering, arrow keys/Enter, Korean and space-containing paths, interruption/reentry and the exact checkout used by Git, CLI and helper scripts.
- [ ] **Modernize flow, both tracks:** run Full analysis, inspect actual report/plan/task paths and skill discovery from app vs Git root. Execute `ws03-baseline`, `ws03-upgrade`, `ws04-azure-code` and `ws05-azd-assets` separately after reviewing each plan. Verify tests and auto-commit scope, including files outside the app. Record JDK discovery behavior and unexecuted integration work.
- [ ] **Modernize host effects:** compare global Copilot configuration and other sessions before/after execution. Do not delete global directories as a workaround.
- [ ] **Node/tool servers:** confirm nvm/nvm-windows Node in the app terminal, npm/`npx` first-download behavior and proxy requirements; confirm .NET deployment/upgrade server paths. For a missing-Node probe, change only that test session's PATH, not persistent settings.
- [ ] **macOS:** start with no Homebrew or Homebrew Bash; verify the consent-based Homebrew-first path, login-shell guidance, SDKMAN's Zsh installer and Bash 3.2 runtime. Verify Homebrew 6 tap handling with the fully qualified Modernize cask. From default Zsh, source `use-java.sh`, directly execute scripts and the sample `startapp.sh`, then proceed through plan execution. Record Bash/Zsh versions.
- [ ] **Linux desktop (Ubuntu LTS):** verify Copilot app and terminal, apt gh repository/keyring, Azure CLI/azd/SDKMAN prerequisite paths, Modernize `install.sh`, glibc and PATH. Run the engine without `sudo`, execute the sample and proceed through plan execution. Where available, verify manual guidance on a non-apt distribution.
- [ ] **Containers:** test Docker/Podman Linux containers and local `linux/amd64` builds, including Apple Silicon where used. Check Windows-generated `mvnw` line endings in Docker builds and record actual image tags/digests.
- [ ] **Approved Azure environment:** review all hooks, azd interactive behavior and preview; run `azd provision`, separately approved DB principal/permissions/migrations, `azd package`, `azd deploy`, user features and `azd down`. Confirm Java metadata/worker flows or .NET Data Protection across revisions. Record remaining resources and costs after failure as well as success.

For documentation-only changes, check relative links, top navigation/step order and `git diff --check`; an application build is not required. Report mock results separately from real installation, runtime, macOS BSD and Azure evidence.

## Branches and commits

Use `feat/`, `fix/`, or `docs/` prefixes for branches. Use [Conventional Commits](https://www.conventionalcommits.org/), for example `docs: clarify Java workshop setup`.

## Pull requests

- Describe the learner or maintainer problem and the change.
- Include or update tests for script behavior changes.
- Confirm that the relevant checks pass; mention any checks that could not run.
- Update workshop documentation when instructions or prerequisites change.
- Link the related issue when applicable.

Use the [bug report](.github/ISSUE_TEMPLATE/bug_report.yml) or [feature request](.github/ISSUE_TEMPLATE/feature_request.yml) form for those requests.
