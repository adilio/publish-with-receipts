# publish-with-receipts

Supply chain guardrails for PowerShell modules and Chocolatey packages. Catch the problems before you publish, not after.

This repo gives you reusable GitHub Actions that generate SBOMs, scan for vulnerabilities, detect risky script patterns, and produce provenance artifacts — all inside your existing CI pipeline. Everything here is free, open source, and ready to fork.

## Why This Exists

Most supply chain security tooling focuses on what happens at the registry: signing, verification, distribution. That matters. But it assumes the artifact being published is already trustworthy.

This project focuses on what happens *before* that point. The idea is simple: if you’re going to publish a package, you should be able to show receipts. What was in it. What you checked. What the tools found. Not just “it passed the build.”

## What’s in the Repo

```
publish-with-receipts/
├── examples/
│   ├── powershell-module/          # Example PS module (intentionally flawed for demo)
│   └── chocolatey-package/         # Example Choco package (intentionally flawed for demo)
│
├── .github/workflows/
│   ├── powershell-supply-chain.yml # Full pipeline for PowerShell modules
│   └── chocolatey-supply-chain.yml # Full pipeline for Chocolatey packages
│
├── actions/                        # Reusable composite actions
│   ├── ps-script-analysis/         # PSScriptAnalyzer + custom rules
│   ├── sbom-generate/              # SBOM generation via Syft
│   ├── vulnerability-scan/         # Vulnerability scanning via Grype
│   ├── semgrep-scan/               # Pattern matching for unsafe code
│   ├── dependency-pin-check/       # Floating dependency detection (.psd1 / .nuspec)
│   ├── choco-naming-validation/    # Package naming checks
│   ├── choco-integrity-check/      # Checksum and binary verification
│   └── provenance-generate/        # SLSA-style provenance artifacts
│
├── semgrep-rules/                  # Custom rules for PowerShell and Chocolatey patterns
│   ├── powershell-unsafe-patterns.yml    # 12 rules covering download-execute, secrets, obfuscation, pinning
│   └── chocolatey-install-patterns.yml   # 12 rules covering checksums, path/registry/service changes, pinning
│
├── scripts/
│   └── Invoke-LocalValidation.ps1  # Run all checks locally before pushing
│
├── docs/
│   ├── threat-model.md             # The threat vectors this project addresses
│   ├── tooling-decisions.md        # Why these tools and what the tradeoffs are
│   ├── enterprise-integration.md   # Connecting outputs to SCA and cloud security platforms
│   └── remediation-guide.md        # How to fix every finding type the pipeline surfaces
│
└── CONTRIBUTING.md                 # How to add rules, actions, and examples
```

## The Toolchain

|Tool                                                              |What It Does                  |Used For                                           |
|------------------------------------------------------------------|------------------------------|---------------------------------------------------|
|[PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer)|Static analysis for PowerShell|Script quality, unsafe patterns                    |
|[Semgrep](https://github.com/semgrep/semgrep)                     |Pattern-based code scanning   |Secrets, download-and-execute, custom rules        |
|[Syft](https://github.com/anchore/syft)                           |SBOM generation               |Software bill of materials for modules and packages|
|[Grype](https://github.com/anchore/grype)                         |Vulnerability scanning        |CVE matching against generated SBOMs               |
|[SARIF](https://sarifweb.azurewebsites.net/)                      |Reporting format              |Unified output that surfaces in GitHub PR reviews  |
|Built-in (PowerShell)                                             |Dependency pin check          |Floating dependency detection in .psd1 and .nuspec |

No vendor licenses. No proprietary platforms. Everything runs in GitHub Actions on public runners.

## Quick Start

### Fork and run against the examples

1. Fork this repo
1. Open a PR that modifies anything in `examples/powershell-module/` or `examples/chocolatey-package/`
1. Watch the pipeline run and review the SARIF findings in the PR

### Use the composite actions in your own repo

Pick the actions you need and reference them in your workflows:

```yaml
- uses: your-fork/publish-with-receipts/actions/sbom-generate@main
  with:
    path: ./your-module
```

Each composite action is self-contained. You can adopt one at a time. You don’t have to use the whole pipeline to get value.

## What the Examples Demonstrate

The example PowerShell module and Chocolatey package are **intentionally flawed**. They contain realistic anti-patterns that the pipeline is designed to catch:

**PowerShell module:**

- Download-and-execute patterns in exported functions
- Floating dependency versions
- Hardcoded credentials in source
- Missing or incomplete module manifest metadata

**Chocolatey package:**

- Missing or incorrect checksums for external binary downloads
- Unsafe patterns in `chocolateyInstall.ps1`
- No SBOM for embedded third-party binaries
- Package naming that could conflict with existing packages

These aren’t cartoonishly broken. They’re the kind of things that ship when people are moving fast and CI doesn’t check for them.

## Threat Vectors Covered

For the full write-up, see <docs/threat-model.md>. The short version:

- **Typosquatting** — packages with names designed to catch common misspellings
- **Download-and-execute** — install scripts that pull and run binaries from external URLs without verification
- **Floating dependencies** — unpinned versions that can be swapped out from under you
- **Secret leakage** — API keys, tokens, and credentials committed to module source or package scripts
- **Unverified binaries** — external executables included or downloaded without checksum validation
- **Unsafe install script patterns** — Chocolatey install scripts that modify system state in undocumented ways

## Enterprise Integration

The pipeline outputs (SBOMs, SARIF, provenance artifacts) are designed to be useful on their own but also to feed into larger security tooling. Teams running SCA platforms or cloud security tools can ingest these artifacts for ongoing monitoring, policy enforcement, and contextual risk evaluation.

See <docs/enterprise-integration.md> for details on how the pipeline-level outputs connect to runtime context.

## Background

This repo is the companion material for the talk **“Provenance Before Publish: Securing PowerShell and Chocolatey Supply Chains from the Pipeline Out”** presented at Chocolatey Fest 2026.

The talk covers the threat model, walks through the tooling decisions, and demonstrates the full pipeline end to end. But you don’t need to have seen the talk to use the repo. The docs folder covers the same ground.

## Running checks locally

Before pushing, run the local validation script to get the same feedback that CI will produce:

```powershell
# Run all checks against both example packages
./scripts/Invoke-LocalValidation.ps1 -Target both

# Quick check (PowerShell only, skip SBOM/Grype)
./scripts/Invoke-LocalValidation.ps1 -Target powershell -SkipSBOM

# Fail on any finding (mirrors enforce mode)
./scripts/Invoke-LocalValidation.ps1 -Target both -FailOnFindings
```

Required tools: `Install-Module PSScriptAnalyzer`, `pip install semgrep`, and optionally [Syft](https://github.com/anchore/syft) and [Grype](https://github.com/anchore/grype).

## Remediating findings

See [docs/remediation-guide.md](docs/remediation-guide.md) for copy-paste fixes for every finding type the pipeline can surface — PSScriptAnalyzer rules, Semgrep rules, dependency pinning issues, and Grype CVEs.

## Contributing

Issues and PRs welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for how to add Semgrep rules, composite actions, and example anti-patterns. If you’ve got a threat vector that isn’t covered, a tool that fits the pipeline better, or a rule that catches something the current set misses, open an issue and let’s talk about it.

## License

MIT. Use it, fork it, adapt it, ship it.
