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
```

The .NET original-app tests use isolated fixtures and mocked native invocations; they never start IIS Express or access LocalDB/MSMQ. A real Windows sample restore/build and browser workflow remain separate rehearsal checks.

Bash:

```bash
bash tests/scripts.tests.sh
```

Scenarios that simulate missing tools or invalid commits may print `FAIL` or `fatal`. Judge the test run by its final `PASS` summary and exit code `0`.

These tests do not replace checks on real macOS/WSL2 environments or with Podman, nor do they verify the full application modernization and Azure deployment workflow.

## Branches and commits

Use `feat/`, `fix/`, or `docs/` prefixes for branches. Use [Conventional Commits](https://www.conventionalcommits.org/), for example `docs: clarify Java workshop setup`.

## Pull requests

- Describe the learner or maintainer problem and the change.
- Include or update tests for script behavior changes.
- Confirm that the relevant checks pass; mention any checks that could not run.
- Update workshop documentation when instructions or prerequisites change.
- Link the related issue when applicable.

Use the [bug report](.github/ISSUE_TEMPLATE/bug_report.yml) or [feature request](.github/ISSUE_TEMPLATE/feature_request.yml) form for those requests.
