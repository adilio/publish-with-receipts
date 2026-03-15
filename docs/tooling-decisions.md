# Tooling Decisions

This document explains why each tool in the `publish-with-receipts` pipeline was chosen, what alternatives were considered, and what tradeoffs were made. The goal is to make the choices reproducible and justifiable — so you can explain them to your team, evaluate alternatives, and make informed decisions about what to replace or extend.

---

## PSScriptAnalyzer

**Role:** PowerShell static analysis — code quality and best practice enforcement.

**Why this tool:**

PSScriptAnalyzer is the de facto standard for PowerShell static analysis. It's maintained by the PowerShell team at Microsoft, ships with built-in rules that cover the [PowerShell scripting best practices](https://docs.microsoft.com/en-us/powershell/scripting/developer/cmdlet/strongly-encouraged-development-guidelines), and integrates naturally with the PowerShell ecosystem (VS Code extension, pipeline automation, PSScriptAnalyzer settings files).

It supports SARIF output (via `-ReportSummary` and custom formatters), which means findings flow directly into GitHub Code Scanning without extra tooling.

**What it does well:**
- Catching common code quality issues (missing `[CmdletBinding()]`, `Write-Host` vs `Write-Output`, missing parameter validation)
- `Invoke-Expression` detection (as a best-practice violation)
- Undefined variable usage, missing `PSCredential` usage for credentials
- Rules are PowerShell-aware (understands the language, not just text patterns)

**What it doesn't do well:**
- Supply chain security patterns (download-execute chains, hardcoded secrets)
- Chocolatey-specific patterns
- Custom pattern rules without writing a full PSScriptAnalyzer rule module

**Alternatives considered:**

| Tool | Why not chosen |
|------|---------------|
| `plaster` | Template tool, not a linter |
| Custom regex scripts | Maintenance burden; worse signal/noise ratio |
| Semgrep alone | PSScriptAnalyzer has deeper language understanding for PowerShell quality checks; both are used |

**How we use it:**

PSScriptAnalyzer runs first in the pipeline as a broad quality gate. Findings are uploaded as SARIF. The pipeline is non-blocking by default (`fail-on-findings: 'false'`) — findings surface as PR annotations without blocking merge. Teams can promote specific rules to blocking as they tune their baseline.

---

## Semgrep

**Role:** Pattern-based code scanning — security-specific patterns that PSScriptAnalyzer doesn't cover.

**Why this tool:**

Semgrep is the most accessible tool for writing and maintaining custom code scanning rules. Its rule format is human-readable YAML, its free tier supports custom rules without restriction, and it outputs SARIF natively. The `generic` language mode allows pattern matching on any text-based language, including PowerShell, without requiring a full language parser.

The critical advantage over regex: Semgrep patterns are structurally aware. A pattern like `$... = Invoke-WebRequest; Invoke-Expression $...` is harder to express accurately with regex without generating excessive false positives.

**What it does well:**
- Custom rules with low barrier to entry
- Structural pattern matching (multi-line, variable binding)
- Free for custom rules and open source repos
- SARIF output
- Active community rule registry (`p/default`, `p/security-audit`, etc.)

**What it doesn't do well:**
- Deep semantic analysis (it's pattern-based, not type-aware)
- PowerShell has limited native language support; the `generic` mode is less precise than language-specific modes
- Performance on very large codebases (not a concern for this use case)

**Alternatives considered:**

| Tool | Why not chosen |
|------|---------------|
| GitHub CodeQL | PowerShell is not a supported CodeQL language |
| `gitleaks` | Specialised in secret detection; less flexible for custom patterns |
| Regex-based custom action | Higher false positive rate; harder to maintain |
| Bandit | Python-specific |

**How we use it:**

Two rule sets are maintained in `semgrep-rules/`:
- `powershell-unsafe-patterns.yml` — Generic PowerShell security patterns
- `chocolatey-install-patterns.yml` — Chocolatey-specific patterns

The Semgrep action is called with both rule files for the Chocolatey pipeline, and with just the PowerShell rules for the module pipeline. Teams can add additional rules or reference Semgrep Registry rule sets.

---

## Syft

**Role:** SBOM generation — Software Bill of Materials in CycloneDX format.

**Why this tool:**

Syft (by Anchore) is the most widely adopted open-source SBOM generation tool. It supports dozens of package ecosystems, outputs multiple SBOM formats (SPDX, CycloneDX, Syft's own format), and pairs naturally with Grype for vulnerability scanning. The `anchore/sbom-action` GitHub Action wraps it for zero-configuration use.

CycloneDX JSON was chosen over SPDX because:
- It has broader tooling support for downstream consumption (SCA platforms, Grype, Dependency-Track)
- The schema is more concise for the data we need
- It's the default for most Anchore tooling

**What it does well:**
- Cataloguing files and their hashes (even for unknown binary formats)
- Supporting multiple output formats
- Integration with Grype (same toolchain, same data model)
- GitHub Action available

**What it doesn't do well:**
- Deep PowerShell module dependency resolution (it reads manifests but doesn't resolve transitive dependencies through the PSGallery API)
- Identifying specific versions of executables embedded in Chocolatey packages unless they have embedded version metadata

**Alternatives considered:**

| Tool | Why not chosen |
|------|---------------|
| `cdxgen` | Good alternative; slightly less mature ecosystem integration |
| `spdx-tools` | SPDX-focused; less Grype integration |
| GitHub's native SBOM export | Only covers the repo's detected dependencies, not the package artifact |

---

## Grype

**Role:** Vulnerability scanning — checking SBOM components against known CVE databases.

**Why this tool:**

Grype (by Anchore) is Syft's natural partner for vulnerability scanning. It consumes Syft's SBOM output directly, checks against the National Vulnerability Database (NVD), GitHub Advisory Database, and other sources, and outputs SARIF for GitHub Code Scanning integration.

The Syft → Grype pipeline is the most widely deployed open-source SBOM/scan combination, which means the toolchain is well-documented, well-tested, and has an active community.

**What it does well:**
- Consuming CycloneDX/SPDX SBOMs directly
- Multiple vulnerability database sources (not just NVD)
- SARIF output for GitHub integration
- JSON output for downstream processing
- Caching of the vulnerability database between runs

**What it doesn't do well:**
- Vulnerability databases lag behind public disclosure (this is universal, not Grype-specific)
- PowerShell modules often have few catalogued CVEs because they're script-based rather than binary packages
- Reachability analysis (whether a vulnerable component is actually invoked in a given code path)

**Alternatives considered:**

| Tool | Why not chosen |
|------|---------------|
| Trivy | Excellent alternative; slightly different SBOM format support |
| Snyk | Commercial; free tier rate-limited; better for continuous monitoring than pipeline gating |
| OWASP Dependency-Check | Java-oriented; less PowerShell/NuGet coverage |

---

## SARIF (Output Format)

**Role:** Common output format for all security findings — enables GitHub Code Scanning integration.

**Why this format:**

SARIF (Static Analysis Results Interchange Format) is the [OASIS standard](https://docs.oasis-open.org/sarif/sarif/v2.1.0/) for static analysis tool output. GitHub Code Scanning natively consumes SARIF, which means findings from any SARIF-producing tool appear in the Security tab and as PR annotations without extra tooling or custom parsing.

This is the zero-cost integration: upload SARIF in a workflow → findings appear in PR → reviewers see them without leaving GitHub.

SARIF also provides a common schema that SCA platforms, SIEM tools, and security orchestration platforms can ingest. The same SARIF files uploaded to GitHub can be forwarded to enterprise tooling without transformation.

**Alternatives:**

All tools used in this pipeline support SARIF. JSON output is also generated by Grype for more detailed analysis, but SARIF is the primary integration format.

---

## Provenance Format (SLSA / in-toto)

**Role:** Provenance attestation — tying pipeline outputs to a specific source commit and build environment.

**Why this format:**

The `provenance-generate` action produces a document in [SLSA Provenance v0.2](https://slsa.dev/provenance/v0.2) format, which is a profile of the [in-toto attestation framework](https://in-toto.io/). This is the industry standard for software provenance, supported by:

- `slsa-verifier` — the reference verification CLI
- GitHub's native Artifact Attestations feature (which accepts SLSA provenance)
- Sigstore / cosign for signing and verification

The pipeline's `provenance-generate` action is a *lightweight* implementation that produces a correctly-structured provenance document without requiring the full `slsa-framework/slsa-github-generator` setup. The tradeoff is that the document is not signed (it's an unsigned artifact), which means it cannot be cryptographically verified by a consumer.

**For signed, verifiable provenance** (SLSA level 2+), replace the `provenance-generate` action with `slsa-framework/slsa-github-generator`. The signed provenance can then be verified with `slsa-verifier verify-artifact`. The composite action in this repo is a stepping stone for teams that want provenance visibility before committing to the full SLSA framework integration.

---

## GitHub Actions (CI Platform)

**Role:** CI/CD platform — running the pipeline.

**Why GitHub Actions:**

The audience for this pipeline is primarily GitHub-hosted repositories. GitHub Actions is free for public repositories, natively integrates with GitHub Code Scanning (SARIF upload), and supports reusable composite actions that can be called from any repository.

**Azure DevOps:**

The concepts in this pipeline are fully portable to Azure DevOps Pipelines. The tools (PSScriptAnalyzer, Semgrep, Syft, Grype) all run on any CI platform. The primary migration work is:

1. Replacing composite `action.yml` files with ADO template YAML
2. Replacing `github/codeql-action/upload-sarif` with the ADO SARIF upload task or a manual REST API call to the [ADO Advanced Security API](https://learn.microsoft.com/en-us/azure/devops/repos/security/configure-github-advanced-security-features)
3. Replacing GitHub Attestations with a manual artifact signing approach (e.g., cosign)

A port for Azure DevOps is a potential future addition to this repository.
