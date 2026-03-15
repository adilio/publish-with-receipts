# Contributing to publish-with-receipts

This repository is the companion material for the talk *"Provenance Before Publish: Securing PowerShell and Chocolatey Supply Chains from the Pipeline Out"*. Contributions that improve the security coverage, accuracy, or usability of the pipeline are welcome.

---

## What you can contribute

| Area | Examples |
|------|---------|
| **New Semgrep rules** | Additional PowerShell or Chocolatey anti-patterns |
| **Composite action improvements** | Bug fixes, new inputs, better error messages |
| **Documentation** | Corrections, additional context, talk slide notes |
| **Example packages** | New anti-patterns to demonstrate, or a "fixed" variant of an existing example |
| **Tooling additions** | Integration with other supply chain tools (e.g., gitleaks, cosign) |

---

## Development setup

### Prerequisites

- **Git** (any recent version)
- **PowerShell 7+** (for running composite actions locally and the local validation script)
- **Python 3.8+** with `pip` (for Semgrep)
- Optional: Syft and Grype (for SBOM and vulnerability scan steps)

### Install local tools

```powershell
# PSScriptAnalyzer
Install-Module PSScriptAnalyzer -Scope CurrentUser -Force

# Pester (for running module tests)
Install-Module Pester -MinimumVersion 5.0 -Scope CurrentUser -Force

# Semgrep
pip install semgrep

# Syft (Linux/macOS)
curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin

# Grype
curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin
```

### Run local validation

Before opening a PR, run the local validation script against your changes:

```powershell
./scripts/Invoke-LocalValidation.ps1 -Target both
```

Pass `-FailOnFindings` to mirror CI strictness:

```powershell
./scripts/Invoke-LocalValidation.ps1 -Target both -FailOnFindings
```

---

## Adding a new Semgrep rule

### Rule structure

All custom rules live in `semgrep-rules/`:

- `powershell-unsafe-patterns.yml` — PowerShell module security rules
- `chocolatey-install-patterns.yml` — Chocolatey install script rules

Each rule follows this structure:

```yaml
- id: descriptive-kebab-case-id
  patterns:               # or 'pattern:' for a single pattern
    - pattern: |
        # The code pattern to match (Semgrep generic syntax)
  message: |
    Clear explanation of what was found and why it matters.
    Include what the developer should do instead.
  severity: ERROR         # ERROR | WARNING | INFO
  languages: [generic]    # generic = text-pattern matching (not AST)
  metadata:
    category: security    # or: maintainability, correctness
    cwe: "CWE-NNN: Short description"   # if applicable
    confidence: HIGH      # HIGH | MEDIUM | LOW
    references:           # optional
      - https://...
```

### Rule ID naming convention

Use the prefix matching the file:
- `powershell-` for rules in `powershell-unsafe-patterns.yml`
- `choco-` or `nuspec-` for rules in `chocolatey-install-patterns.yml`

### Testing your rule

Test that your rule matches the intended pattern and does not over-match:

```bash
# Test against the example packages (expect findings)
semgrep --config semgrep-rules/powershell-unsafe-patterns.yml examples/powershell-module

# Test against a specific file
semgrep --config semgrep-rules/chocolatey-install-patterns.yml examples/chocolatey-package/tools/chocolateyInstall.ps1

# Test that your rule does NOT match safe patterns (expect no findings)
semgrep --config semgrep-rules/powershell-unsafe-patterns.yml --include '*.ps1' path/to/safe/code
```

### Adding the rule to remediation-guide.md

Every new rule should have a corresponding entry in `docs/remediation-guide.md`. The entry must include:

1. The rule ID and severity
2. What the rule caught (plain language)
3. Why it is dangerous
4. A copy-paste "Before / After" fix example

---

## Adding a new composite action

Composite actions live in `actions/<action-name>/action.yml`. Each action should:

### Follow the existing structure

```yaml
name: 'Human Readable Name'
description: |
  What this action does, when to use it, and relevant caveats.

inputs:
  input-name:
    description: 'What this input controls.'
    required: true | false
    default: 'default-value'

outputs:
  output-name:
    description: 'What this output contains.'
    value: ${{ steps.step-id.outputs.output-name }}

runs:
  using: 'composite'
  steps:
    - name: Step name
      id: step-id
      shell: bash | pwsh
      run: |
        # ...
```

### Design principles

1. **Non-blocking by default.** New actions should have a `fail-on-findings` (or equivalent) input defaulting to `'false'`. Teams should be able to surface findings before enforcing them.

2. **SARIF output where applicable.** If the action produces security findings, output a SARIF file and upload it to GitHub Code Scanning via `github/codeql-action/upload-sarif@v3`.

3. **Artifact upload for receipts.** Key output files (SBOM, provenance, scan reports) should be uploaded as workflow artifacts using `actions/upload-artifact@v4`.

4. **Clear output variables.** Expose `finding-count`, `issues-found`, or equivalent outputs so downstream steps can branch on results.

5. **Graceful degradation.** If a tool is unavailable or a network call fails, emit a warning rather than failing hard. The pipeline should degrade gracefully.

### Wire the action into workflows

After creating the action:

1. Add a step in `.github/workflows/powershell-supply-chain.yml` and/or `.github/workflows/chocolatey-supply-chain.yml`
2. Add the new artifact/output to the **Summary** step's table
3. Document the new action in `README.md`

---

## Making changes to example packages

The examples in `examples/` are intentionally flawed to trigger pipeline findings. When modifying them:

- **Preserve the anti-patterns.** The examples are teaching tools. If you add new anti-patterns, add a comment explaining what they demonstrate:

```powershell
# DEMO: download-execute pattern — triggers powershell-download-execute Semgrep rule
$script = Invoke-WebRequest -Uri $remoteScriptUrl
Invoke-Expression $script.Content
```

- **Do not add real credentials.** Even placeholder secrets should look fake (e.g., `sk-PLACEHOLDER-KEY-abc123`).

- **Keep tests passing.** The Pester tests in `examples/powershell-module/tests/` must pass — they demonstrate that unit tests are necessary but insufficient for supply chain safety.

---

## Pull request checklist

Before submitting a PR:

- [ ] `./scripts/Invoke-LocalValidation.ps1 -Target both` runs without unexpected tool errors
- [ ] New Semgrep rules are tested against both matching and non-matching patterns
- [ ] New composite actions have a corresponding step in at least one workflow
- [ ] `docs/remediation-guide.md` is updated for any new rule or action
- [ ] `README.md` is updated if the pipeline surface area changed (new tool, new action, new threat vector)
- [ ] PR description explains the threat vector or gap the change addresses

---

## Code of conduct

This project follows the [Contributor Covenant Code of Conduct](https://www.contributor-covenant.org/version/2/1/code_of_conduct/). Be respectful in issues, PRs, and discussions.
