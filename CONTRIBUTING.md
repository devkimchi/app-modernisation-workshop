# Contributing

Thank you for helping improve this workshop. By participating, you agree to follow the [Code of Conduct](CODE_OF_CONDUCT.md).

## Scope and changes

Keep changes focused on the workshop instructions, preparation scripts, and regression tests. Explain learner-facing changes in the relevant documentation and preserve upstream source licenses and notices when working with downloaded samples. Do not commit credentials, local configuration, downloaded applications, or generated test output.

## Local checks

Run the relevant regression tests before opening a pull request. These developer checks require no additional test packages and use fixtures and mocked command responses without changing real accounts or OS features. Workshop participants do not need to run them; use the prerequisite checks in the [Java setup](docs/java/0-setup.md) or [.NET setup](docs/dotnet/0-setup.md) instead.

PowerShell:

```powershell
pwsh -File ./tests/scripts.tests.ps1
pwsh -File ./tests/dotnet-original.tests.ps1
pwsh -File ./tests/install-prerequisites.tests.ps1
pwsh -File ./tests/windows-prerequisite-updates.tests.ps1
pwsh -File ./tests/azure-actions.tests.ps1
pwsh -File ./tests/powershell-bootstrap.tests.ps1
```

On Windows, all `.ps1` entrypoints also accept `powershell.exe -NoProfile -File .\path\to\script.ps1` from Windows PowerShell 5.1 and delegate to PowerShell 7. Both PowerShell 7 and the WSL2 platform are required before production script work on Windows, including the .NET track. A Linux distribution is a separate Java prerequisite. The installer alone may offer to install missing prerequisites, with separate consent for PowerShell 7 and WSL2; CI, redirected input/output and `-NonInteractive` sessions cannot install. WSL2 installation changes Windows features and may require administrator approval and a manual restart; it never installs a distro or restarts Windows automatically.

Regression entrypoints mock the WSL2 host preflight so tests do not depend on host OS features or an installed distribution. The bootstrap suite additionally uses real Windows PowerShell 5.1 subprocesses against isolated script copies with mocked prerequisite discovery to verify parsing, early failure and delegation. No real installation, login or OS modification is performed. Repeat the commands above with `powershell.exe` to verify the 5.1 entry path on Windows.

The Windows update suite mocks nvm-windows/winget, release discovery, process launching and WSL. It covers shared Java/.NET Node installs and same-major updates (22 fallback only for missing/unsupported Node), separate activation consent, provenance/link collisions, failures and noninteractive denial. Both v1 settings/symlinks and v2 configured roots/shim/link modes are covered. V2 auto-install is refused before Node probes; activation uses `--no-install`, and failed tool preparation skips further probes. Activation changes the common Windows selection for subsequent invocations, not running Node processes; existing versions are retained. `-Update` also supports version-verified WSL platform updates and winget/MSI-managed stable PowerShell 7. A Windows PowerShell worker waits for the current pwsh to exit before upgrading, verifies the result and never reenters the installer; scheduling returns exit code 1, not success. Store/ZIP/unrecognized installs and inbox WSL without version output remain manual. Tests do not execute the real worker or update the OS. .NET Azure CLI/azd installation behavior is unchanged.

Keep `.ps1` files UTF-8 **with BOM** and LF (see `.editorconfig`): Windows PowerShell 5.1 otherwise decodes Korean text using the system ANSI code page before delegation. Do not add PowerShell 7-only syntax to these entrypoint files; the entire file must parse in 5.1. Dot-source helpers only inside PowerShell 7 when caller-scope functions/variables are needed; 5.1 dot-sourcing fails explicitly without exiting the caller because a child process cannot populate that scope. PowerShell 7 dot-sourcing retains definition-only behavior.

The .NET original-app tests use isolated fixtures and mocked native invocations; they never start IIS Express or access LocalDB/MSMQ. A real Windows sample restore/build and browser workflow remain separate rehearsal checks.

Bash:

```bash
bash tests/scripts.tests.sh
bash tests/install-prerequisites.tests.sh
```

Run the installer suite in WSL2/macOS Bash; its SDKMAN fixtures require real symbolic links rather than Git Bash's link emulation. It covers opt-in Bash `--update`, per-tool consent, provenance checks, version selection and failures with isolated SDKMAN/nvm/Homebrew/APT fixtures. Node uses the latest stable version of the active major (22 fallback only for missing/unsupported Node), with separate installation and activation consent. Installation uses `--no-use`; existing versions and default aliases are retained, and activation only changes the script environment, never the caller's shell. It never installs or updates real tools. Bash `--update` and Windows `-Update` are independent; Windows Node for both tracks uses nvm-windows, not the Bash nvm installation.

Scenarios that simulate missing tools or invalid commits may print `FAIL` or `fatal`. Judge the test run by its final `PASS` summary and exit code `0`.

These tests do not replace checks on real macOS/WSL2 environments or alternative container engines, nor do they verify the full application modernization and Azure deployment workflow. See the [Java](docs/java/8-troubleshooting.md#대체-엔진-설정) and [.NET](docs/dotnet/8-troubleshooting.md#대체-엔진-설정) troubleshooting guides for alternative-engine procedures and rehearsal limitations.

## Branches and commits

Use `feat/`, `fix/`, or `docs/` prefixes for branches. Use [Conventional Commits](https://www.conventionalcommits.org/), for example `docs: clarify Java workshop setup`.

## Pull requests

- Describe the learner or maintainer problem and the change.
- Include or update tests for script behavior changes.
- Confirm that the relevant checks pass; mention any checks that could not run.
- Update workshop documentation when instructions or prerequisites change.
- Link the related issue when applicable.

Use the [bug report](.github/ISSUE_TEMPLATE/bug_report.yml) or [feature request](.github/ISSUE_TEMPLATE/feature_request.yml) form for those requests.
