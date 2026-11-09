# Contributing

Thank you for helping improve this workshop. By participating, you agree to follow the [Code of Conduct](CODE_OF_CONDUCT.md).

## Scope and changes

Keep changes focused on the workshop instructions, preparation scripts, and regression tests. Explain learner-facing changes in the relevant documentation and preserve upstream source licenses and notices when working with downloaded samples. Do not commit credentials, local configuration, downloaded applications, or generated test output.

## Local checks

The current branch contains repository setup files only. When the workshop materials are present, run the relevant regression test before opening a pull request.

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

## Branches and commits

Use `feat/`, `fix/`, or `docs/` prefixes for branches. Use [Conventional Commits](https://www.conventionalcommits.org/), for example `docs: clarify Java workshop setup`.

## Pull requests

- Describe the learner or maintainer problem and the change.
- Include or update tests for script behavior changes.
- Confirm that the relevant checks pass; mention any checks that could not run.
- Update workshop documentation when instructions or prerequisites change.
- Link the related issue when applicable.

Use the [bug report](.github/ISSUE_TEMPLATE/bug_report.yml) or [feature request](.github/ISSUE_TEMPLATE/feature_request.yml) form for those requests.
