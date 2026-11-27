# Pitaiya debt scanner

Ruby CLI and GitHub Action that run technical debt checks against the Git checkout available in CI.

## Run locally

Use Ruby 3.4 and Git. From the scanner repository, run:

```sh
ruby pitaiya-scan.rb --directory /path/to/checkout --output report.json
ruby scanner_test.rb
```

The directory must be the root of a Git working tree. The scanner reads tracked files from that working tree. Without `--output`, JSON goes to stdout. Findings are informational by default. Use `--fail-on-findings` to exit with status 1 when there are findings. Invocation and scan errors exit with status 2.

## Use in GitHub Actions

Run the scanner after checking out the repository to scan. Replace `SCANNER_COMMIT_SHA` with the full commit SHA of the scanner version you want to use.

```yaml
- uses: actions/checkout@d23441a48e516b6c34aea4fa41551a30e30af803 # v6
  with:
    persist-credentials: false
- uses: Pitaiya/ms-debt-scanner@SCANNER_COMMIT_SHA
  id: debt
- uses: actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02 # v4
  with:
    name: pitaiya-debt-report
    path: ${{ steps.debt.outputs.report-path }}
```

The action reports findings without blocking the build. Its `directory` input defaults to the current workspace and can point to a checkout in a subdirectory. The versioned JSON report lists the executed checks and their findings.

## Available checks

| Check | What it reports |
| --- | --- |
| `overdue-debt` | Full-line `TODO(debt: YYYY-MM-DD)` or `FIXME(debt: YYYY-MM-DD)` comments with a valid due date earlier than today in UTC. |

For example, `// TODO(debt: 2026-01-30): Remove the legacy adapter` becomes a finding once that date has passed. The check recognizes `//`, `#` and `--` line comment prefixes in the source extensions listed in [the check](overdue_debt.rb). The report includes the relative path, line and due date.
