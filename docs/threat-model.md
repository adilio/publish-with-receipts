# Threat Model

This document details the supply chain threat vectors that the `publish-with-receipts` pipeline is designed to detect and mitigate. Each threat vector is described with its mechanism, real-world context, and the specific pipeline controls that address it.

## Scope

**In scope:** Threats that can be introduced or detected *before a package reaches its registry* — i.e., threats that live in the source code, build pipeline, or packaging process.

**Out of scope:** Registry-level threats (compromised registry infrastructure, account takeover after publish), runtime threats (compromised consumer environments), and supply chain attacks targeting the CI/CD platform itself.

The framing is: "If you build and publish a package today, what could go wrong between your source code and the published artifact — and can your pipeline catch it?"

---

## Threat Vector 1: Typosquatting

**Category:** Dependency confusion / name impersonation

### Mechanism

Typosquatting involves registering a package name designed to be mistaken for a popular, legitimate package. The attacker relies on:

- Common keyboard typos (`exmaple` for `example`)
- Naming convention confusion (`Az.Table` vs `AzTable`, `react-native` vs `reactnative`)
- Case insensitivity in registry lookups
- Automated pipelines that install dependencies without human review

### Real-World Context

In August 2023, Aqua Security's Nautilus team published research demonstrating that PowerShell Gallery (PSGallery) has no protection against typosquatting. Researchers registered `Az.Table` (with a dot) to impersonate the popular `AzTable` module (10M+ downloads). Within hours, they received telemetry callbacks from production Azure environments at real companies.

Microsoft acknowledged the underlying issue in late 2022. As of the Aqua report, mitigations were incomplete and researchers were able to reproduce the attack after Microsoft's stated fixes. PSGallery's situation contrasts with npm, which has explicit [Moniker rules](https://docs.npmjs.com/policies/disputes#module-squatting) preventing registration of names like `reactnative` when `react-native` already exists.

Chocolatey's community repository has human moderation, which catches some typosquatting attempts. Internal/private Chocolatey repositories typically have no naming validation.

### Pipeline Controls

| Action | What it checks |
|--------|---------------|
| `choco-naming-validation` | Compares the package name in `.nuspec` against community repo packages using Levenshtein distance. Flags names within 2 characters of existing packages. |

### Residual Risk

Naming validation cannot prevent a determined attacker from publishing to a public registry — it only catches the issue *before you publish*. The primary value is catching accidental name collisions in your own pipeline and triggering a review before a problematic package is published.

---

## Threat Vector 2: Download-and-Execute

**Category:** Remote code execution via unverified network content

### Mechanism

Install scripts or module functions that fetch content from external URLs and execute it directly, without verifying the content against a known hash. Attack paths include:

- Compromised CDN serving a modified binary
- DNS hijacking / BGP hijack redirecting the download URL
- MITM attack (especially if TLS validation is disabled)
- Server-side compromise at the hosting provider
- URL repurposing (attacker acquires a domain that was previously used for a legitimate download)

### Real-World Context

The Serpent malware campaign (2022, documented by Proofpoint) targeted French organisations using macro-enabled documents that installed Chocolatey legitimately, then used it to install Python and pip, then deployed a backdoor via steganography. Chocolatey itself wasn't compromised — the campaign showed how legitimate package managers become attack vectors when the surrounding pipeline doesn't validate what's being executed.

In the PowerShell ecosystem, patterns like `Invoke-WebRequest | Invoke-Expression` (download-and-execute) appear in legitimate tools and malware alike. PSGallery has no programmatic check for this pattern in published modules.

Chocolatey acknowledges checksum requirements: as of v0.10.0, checksums are required for non-secure (HTTP) downloads. However, many community packages still have missing or incorrect checksums, and the check happens at install time — not in the maintainer's pipeline.

### Pipeline Controls

| Action/Rule | What it checks |
|-------------|---------------|
| `semgrep-rules/powershell-unsafe-patterns.yml` → `powershell-download-execute` | Matches `Invoke-WebRequest`/`Invoke-RestMethod` results piped to or passed to `Invoke-Expression` |
| `semgrep-rules/powershell-unsafe-patterns.yml` → `powershell-disable-certificate-validation` | Matches `ServicePointManager::ServerCertificateValidationCallback` overrides |
| `semgrep-rules/chocolatey-install-patterns.yml` → `choco-unverified-download` | Matches `Invoke-WebRequest` calls outside of Chocolatey's built-in helpers |
| `semgrep-rules/chocolatey-install-patterns.yml` → `choco-install-package-no-checksum` | Matches `Install-ChocolateyPackage` calls without a `checksum` argument |
| `choco-integrity-check` | Validates checksum presence and algorithm strength in install scripts |

---

## Threat Vector 3: Floating Dependencies

**Category:** Dependency confusion / version drift

### Mechanism

Specifying a minimum version (`ModuleVersion = '1.0'` in a `.psd1`, or `version="1.0"` in a `.nuspec`) rather than an exact or bounded version means the resolved dependency can change between builds without any code change in the package being built. An attacker can:

- Publish a higher version number to a public registry to be resolved preferentially
- Compromise a legitimate package version that is being silently upgraded to
- Introduce breaking changes or malicious code in a minor version that gets auto-resolved

This is related to the *dependency confusion* attack class described by Alex Birsan (2021).

### Real-World Context

In enterprise environments, PowerShell modules are commonly installed as part of deployment pipelines (Azure Automation, DSC, Ansible/WinRM). A floating dependency means a Tuesday deployment can pull a different version of a module than Monday's deployment, with no change in the organisation's own code — and no visibility into what changed.

For Chocolatey packages, dependencies that install additional Chocolatey packages can transitively pull install scripts with elevated privileges. A floating transitive dependency is therefore not just a correctness issue but a security one.

### Pipeline Controls

| Action/Rule | What it checks |
|-------------|---------------|
| `sbom-generate` | The SBOM captures resolved dependency versions at build time, creating a baseline for detecting future drift |
| `semgrep-rules/powershell-unsafe-patterns.yml` → `powershell-scripts-to-process` | Flags the `ScriptsToProcess` mechanism in module manifests (related: version-independent code execution at import time) |

**Note:** The SBOM is a detective control, not a preventive one. It doesn't prevent floating dependencies from being used, but it makes the resolved versions auditable. Pinning enforcement would require a separate linting step against the `.psd1` or `.nuspec` directly.

---

## Threat Vector 4: Secret Leakage

**Category:** Credential exposure

### Mechanism

API keys, tokens, connection strings, and other credentials hardcoded in module source code or package scripts. Sources of accidental inclusion:

- Development shortcuts ("I'll remove this key before I push")
- Test credentials that differ from production but are still sensitive
- Internal infrastructure details (share paths, internal API URLs) in packages published to public registries
- `.env` files, config files, or log files accidentally included in the published package

### Real-World Context

Aqua Security's PSGallery research also found that the gallery API allows unlisted packages to remain accessible. Researchers discovered publishers who had accidentally uploaded `.git/config` files containing GitHub API keys, and publishing automation scripts containing PSGallery API keys. Once published (even if unlisted), the data may be harvested by automated scanners before the mistake is discovered.

### Pipeline Controls

| Action/Rule | What it checks |
|-------------|---------------|
| `semgrep-rules/powershell-unsafe-patterns.yml` → `powershell-hardcoded-secret` | Matches common variable assignments for API keys, tokens, passwords, secrets, connection strings |
| `semgrep-rules/chocolatey-install-patterns.yml` → `choco-hardcoded-internal-url` | Matches hardcoded internal URLs and UNC paths in install scripts |

### Residual Risk

Semgrep rules for secret detection have both false positives (variable names that look like secrets but contain placeholder values) and false negatives (secrets stored in unusual variable names or obfuscated). For high-assurance secret detection, supplement these rules with a dedicated tool like `gitleaks` or `truffleHog` and configure GitHub's built-in [secret scanning](https://docs.github.com/en/code-security/secret-scanning/about-secret-scanning).

---

## Threat Vector 5: Unverified External Binaries

**Category:** Binary integrity

### Mechanism

Packages that include or download third-party executables without verifying their integrity against a known-good hash. This is the broadest version of the download-and-execute vector, including binaries that are:

- Embedded in the package `tools/` directory
- Downloaded at install time without a checksum
- Downloaded with an MD5 or SHA1 checksum (computationally feasible to forge)

Chocolatey's `VERIFICATION.txt` convention documents the source and checksums of embedded binaries, but it's a human-readable text file that is not programmatically enforced by default.

### Real-World Context

Several Chocolatey CVEs relate to insecure permissions on installed directories (e.g., `C:\tools\php81`, `C:\tools\Cmder`), meaning even if the binary was correct at install time, it can be replaced by a lower-privilege attacker afterward. While that's a post-install concern, the install-time integrity check is a prerequisite: there's no point verifying file permissions if the binary was never verified to begin with.

### Pipeline Controls

| Action/Rule | What it checks |
|-------------|---------------|
| `choco-integrity-check` | Validates checksum presence and algorithm strength; checks embedded binaries against VERIFICATION.txt |
| `semgrep-rules/chocolatey-install-patterns.yml` → `choco-execute-downloaded-content` | Matches patterns where downloaded files are immediately executed |
| `semgrep-rules/chocolatey-install-patterns.yml` → `choco-weak-checksum-algorithm` | Flags MD5 and SHA1 checksum types |
| `sbom-generate` | Records file hashes for embedded binaries even if Syft can't identify them by component name |

---

## Threat Vector 6: Unsafe Install Script Patterns

**Category:** Privilege abuse / system modification

### Mechanism

Chocolatey install scripts run with elevated privilege (admin) by default. This makes them a high-value target for abuse. Unsafe patterns include:

- Undocumented PATH modifications that persist after uninstall
- Registry writes without corresponding cleanup in the uninstall script
- Service creation without documentation
- System-wide configuration changes that affect all users
- Use of `[System.Net.ServicePointManager]::ServerCertificateValidationCallback` overrides that persist for the session

These patterns are not necessarily malicious — many Chocolatey packages legitimately need to modify PATH or the registry. The risk is in the lack of documentation, the lack of corresponding cleanup, and the lack of visibility into what the install script actually does.

### Pipeline Controls

| Action/Rule | What it checks |
|-------------|---------------|
| `semgrep-rules/chocolatey-install-patterns.yml` → `choco-path-modification-undocumented` | Flags `Install-ChocolateyPath` calls |
| `semgrep-rules/chocolatey-install-patterns.yml` → `choco-registry-write-undocumented` | Flags registry writes under HKLM |
| `ps-script-analysis` | PSScriptAnalyzer catches code quality patterns like missing `[CmdletBinding()]`, `Write-Host` usage, and other maintainability issues |

---

## Threat Model Assumptions

1. **The CI pipeline is trusted.** This threat model assumes GitHub Actions is not compromised. A compromised CI platform (e.g., supply chain attack on an action this pipeline uses) is out of scope.
2. **The developer's workstation is trusted.** This model does not address insider threat or compromise of the developer machine used to write and commit code.
3. **Registry infrastructure is trusted.** Registry-level attacks (PSGallery or Chocolatey community repo being compromised) are out of scope.
4. **The attacker cannot modify committed source.** The provenance attestation ties pipeline outputs to a specific commit SHA. This assumes the attacker cannot force-push to the branch that triggers the pipeline.

## What This Pipeline Does Not Cover

- **Code signing verification** — Signing (Authenticode, NuGet signatures) is a registry-level and consumer-level control. This pipeline handles what's *in* the package; signing handles *who published it*.
- **Runtime behaviour analysis** — The pipeline is static analysis only. Dynamic analysis of install script behaviour (e.g., sandboxed execution) is not implemented.
- **Transitive dependency analysis** — Grype checks CVEs against declared dependencies in the SBOM, but deep transitive dependency graphs for PowerShell modules are not fully resolved by Syft.
- **Social engineering and account compromise** — If the publisher's PSGallery or Chocolatey account is compromised, this pipeline doesn't help. Enable MFA on your registry accounts.
