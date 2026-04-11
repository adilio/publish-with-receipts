---
marp: true
theme: summit-2026
paginate: true
header: Chocolatey Fest 2026
footer: github.com/adilio/publish-with-receipts
---

<!--
  Presentation reviewed using the death-by-ppt skill by HeyItsGilbert
  https://github.com/HeyItsGilbert/marketplace/blob/main/plugins/presentation-review/skills/death-by-ppt/SKILL.md
-->

<!-- _class: title -->

# Provenance Before Publish

## Securing PowerShell & Chocolatey Supply Chains

<p class="name wide">Adil Leghari</p>
<p class="handle wide">github.com/adilio/publish-with-receipts</p>

---

<!-- _class: sponsors -->
<!-- _paginate: skip -->

# Thanks!

<!--
Gotta thank the sponsors!
-->

---

## What We're Covering

<ol class="primary-list">
<li><strong>The Problem Space</strong> — Six threats already in your packages</li>
<li><strong>PowerShell Pipeline</strong> — PSScriptAnalyzer → Semgrep → SBOM → Provenance</li>
<li><strong>Chocolatey Pipeline</strong> — Same model, different risk profile</li>
<li><strong>Bigger Picture</strong> — GitHub-native to enterprise platforms</li>
</ol>

<p class="muted">We’ll keep the slides practical: threat model first, then the two pipelines, then how this scales.</p>

---

## This Talk Is For You If...

<ul class="checklist secondary-list">
<li>You maintain PowerShell modules on PSGallery</li>
<li>You maintain Chocolatey packages (community or internal)</li>
<li>Your CI says "passed" but you're not sure what that means</li>
<li>You've never seen an SBOM from your own package</li>
</ul>

<p class="muted">If any of that sounds familiar, the pipeline examples later in the deck should map pretty closely to your world.</p>

---

## The Gap

```
Source Code
    ↓
Build / CI Pipeline   ← YOU ARE HERE
    ↓
[ THE GAP ]           ← Most maintainers have nothing here
    ↓
Registry              ← Moderation, virus scan
    ↓
Consumer Install
```

---

## What the Registries Already Do

<div class="columns">
<div>

### Chocolatey CCR

<ul class="primary-list">
<li>Validator: nuspec, checksums, script layout</li>
<li>Verifier: install, upgrade, uninstall</li>
<li>VirusTotal plus human review for community packages</li>
</ul>

</div>
<div>

### PowerShell Gallery

<ul class="secondary-list">
<li>Manifest validation for version, GUID, author, description</li>
<li>Installation testing in validation</li>
<li>Antivirus scanning plus error-level PSScriptAnalyzer</li>
</ul>

</div>
</div>

<p class="muted">Both registries already do real work. This pipeline complements them — it doesn't replace them.</p>

---

## What They Don't Do

<div class="columns">
<div>

### Technical gaps

<ul class="quaternary-list">
<li>Audits upstream vendor source code or proves binaries clean beyond AV</li>
<li>Tests across a broad OS, locale, or environment matrix</li>
<li>Generates an SBOM or provenance attestation</li>
<li>Monitors for URL or binary drift after approval</li>
<li>Detects hardcoded secrets in published scripts</li>
</ul>

</div>
<div>

### Process gaps

<ul class="secondary-list">
<li>CCR's VERIFICATION.txt is convention — nothing enforces it programmatically</li>
<li>CCR moderation covers community packages; internal repos have none</li>
<li>PSGallery's PSScriptAnalyzer fires on error-level rules only — not supply chain patterns</li>
</ul>

</div>
</div>

<p class="muted">Neither registry produces receipts. That's the gap this pipeline fills.</p>

---

## The Thesis

**<span class="gradient-text">Three questions</span> you should answer before publishing:**

<ul class="primary-list">
<li>What's in this package? → <span class="primary-bg">SBOM</span></li>
<li>What did we check? → <span class="secondary-bg">Scan results (SARIF)</span></li>
<li>Can we prove when and how it was built? → <span class="quaternary-bg">Provenance</span></li>
</ul>

<div class="callout gradient">

### These are your receipts — not just a green checkmark.

</div>

---

<!-- _class: big-statement -->

# Section 1

## The Problem Space

---

## Six Threats

<ol class="quaternary-list">
<li><strong>Typosquatting</strong> — Wrong package, silently installed</li>
<li><strong>Download-and-Execute</strong> — Install scripts fetch unknown binaries</li>
<li><strong>Floating Dependencies</strong> — Version resolved at install time</li>
<li><strong>Secret Leakage</strong> — API keys in published source</li>
<li><strong>Unverified Binaries</strong> — No checksum, no proof</li>
</ol>

Each one is detectable with the right pipeline.

---

## Threat 1: Typosquatting

**PSGallery has no Moniker rules** (unlike npm)

- Registered `Az.Table` to impersonate `AzTable` (10M+ downloads)
- Callbacks from **production Azure environments within hours**
- Microsoft claimed fixes twice — neither held up to verification
- No evidence structural naming protections were ever implemented

**Microsoft's structural fix:** Microsoft Artifact Registry (MAR) for official modules — vendor-controlled namespace. PSGallery stays for community packages. No naming protection there.

**Pipeline defense:** Naming similarity validation at build time

---

## Threat 2: Download-and-Execute

```powershell
# PowerShell module
$content = Invoke-WebRequest $url
Invoke-Expression $content

# Chocolatey install script
Install-ChocolateyPackage -Url $url  # no checksum
```

**Serpent malware (2022):** Used Chocolatey legitimately to install Python, then deployed a backdoor. The pipeline around it was the problem.

---

## Threat 3: Floating Dependencies

```powershell
# .psd1 manifest — minimum version, not pinned
RequiredModules = @(
    @{ ModuleName = 'Az.Accounts'; ModuleVersion = '2.0.0' }
)
```

- Different version resolved Monday vs. Tuesday — no code change
- Chocolatey deps can trigger additional elevated install scripts

---

## Threat 4: Secret Leakage

```powershell
# Found in published PSGallery modules
$ApiKey = "sk-live-abc123..."
$ConnectionString = "Server=internal.corp;Password=hunter2"
```

Aqua Nautilus found PSGallery API keys in *unlisted* packages — still accessible via the API after authors tried to remove them.

---

## Threat 5: Unverified Binaries

```text
# VERIFICATION.txt — intentionally incomplete
FILE: setup.exe
# (no checksum)
# (no source URL)
```

- Chocolatey packages run as admin
- VERIFICATION.txt is convention, not enforcement

---

## Threat 6: Unsafe Install Patterns

```powershell
# Undocumented PATH modification
$env:PATH += ";C:\tools\myapp"
[Environment]::SetEnvironmentVariable("PATH", $env:PATH, "Machine")
# No cleanup in chocolateyUninstall.ps1
```

Install scripts run as admin. Registry, services, PATH — all under-reviewed in internal repos.

---

<!-- _class: big-statement -->

# Section 2

## PowerShell Module Pipeline

---

## The Example Module

`examples/powershell-module/ExampleModule/`

| File | Intentional Issues |
|------|--------------------|
| `ExampleModule.psd1` | Floating dependency, `ScriptsToProcess` |
| `Invoke-UnsafeFunction.ps1` | Download-and-execute, hardcoded API key |
| `ExampleModule.Tests.ps1` | Tests pass — supply chain issues invisible |

---

## Step 1: PSScriptAnalyzer

- Static analysis for PowerShell code quality
- Flags: `Invoke-Expression`, missing `[CmdletBinding()]`, `Write-Host`
- Output: **SARIF** → GitHub Code Scanning → PR annotations

<div class="callout secondary">

### PSGallery already runs PSScriptAnalyzer at publish time
Running it here catches issues before you push. Semgrep fills the gaps it can't see: hardcoded secrets, download-execute chains, and unsafe patterns that need context to detect.

</div>

---

## Step 2: Semgrep — Custom Rules

`semgrep-rules/powershell-unsafe-patterns.yml`

- Download-and-execute patterns
- Hardcoded API keys and tokens
- TLS certificate validation bypass
- Base64-encoded command execution

Output: **SARIF** → PR annotations

---

## Semgrep Rule Example

```yaml
rules:
  - id: invoke-expression-from-web
    patterns:
      - pattern: |
          $X = Invoke-WebRequest ...
          Invoke-Expression $X
    message: Remote content fetched without integrity check
    severity: ERROR
```

Add inline suppression with justification when legitimate.

---

## Step 3: SBOM with Syft

- Scans module directory
- Output: **CycloneDX JSON**
- Captures: declared dependencies, resolved versions, file inventory

<div class="callout primary">

### Why it matters
When a CVE drops tomorrow, you know which builds are affected — without re-running scans.

</div>

---

## Step 4: Vulnerability Scan with Grype

- Consumes the Syft SBOM
- Checks NVD and GitHub Advisory Database
- Output: **SARIF + JSON** — configurable severity thresholds

Grype catches published CVEs at build time. SBOM + Grype = retroactive checking when new CVEs are published.

---

## Step 5: Provenance

```json
{
  "source_repo": "adilio/publish-with-receipts",
  "commit_sha": "abc123...",
  "workflow": "powershell-supply-chain.yml",
  "build_timestamp": "2026-04-01T14:30:00Z",
  "artifact_hash": "sha256:def456..."
}
```

The receipt. Ties SBOM + scan results to a specific commit and pipeline run.

---

## PowerShell Pipeline — Full Picture

```
Push / PR
    ↓
PSScriptAnalyzer  →  SARIF  →  PR Annotations
    ↓
Semgrep           →  SARIF  →  PR Annotations
    ↓
Syft              →  CycloneDX SBOM  →  Artifact
    ↓
Grype             →  SARIF + JSON  →  PR Annotations
    ↓
Provenance        →  JSON  →  Artifact (365-day retention)
```

---

<!-- _class: big-statement -->

# Section 3

## Chocolatey Package Pipeline

---

## What Makes Chocolatey Different

- **Elevated privilege by default** — install scripts run as admin
- **External binaries are the norm** — package wraps a downloaded EXE/MSI
- **VERIFICATION.txt** — convention, not enforcement
- **Internal repos** — typically zero moderation

Everything from Section 2 applies, plus Chocolatey-specific checks.

---

## The Example Package

`examples/chocolatey-package/`

| File | Intentional Issues |
|------|--------------------|
| `example-package.nuspec` | Missing metadata, unpinned dependency |
| `chocolateyInstall.ps1` | Missing checksum, undocumented PATH change |
| `VERIFICATION.txt` | No checksums, vague source URL |

The package installs. `choco install` succeeds. That's the problem.

---

## Step 1: Naming Validation

- Queries Chocolatey community repo API
- Levenshtein distance check for similar names
- Flags naming conflicts and typosquatting risks
- Checks metadata completeness (projectUrl, iconUrl, tags)

---

## Step 2: Checksum & Integrity Check

```powershell
Install-ChocolateyPackage `
  -Url "https://example.com/setup.exe" `
  -Checksum "abc123..."  # present? SHA256? matches?
  -ChecksumType "sha256"
```

- Checksums present and using strong algorithm (SHA256+)
- VERIFICATION.txt entries match embedded files

---

## Step 3: Install Script Analysis

`semgrep-rules/chocolatey-install-patterns.yml`

- Unverified `Invoke-WebRequest` outside Chocolatey helpers
- Registry writes and service creation without documentation
- Hardcoded internal URLs and credentials
- PATH modification without uninstall cleanup

---

## Steps 4–5: SBOM + Provenance

Same tools (Syft → Grype → Provenance), different content:

- SBOM includes **embedded binaries** from `tools/` directory
- File hashes recorded even for unknown executables
- Provenance ties together: binary URL + hash + commit + pipeline

---

<!-- _class: big-statement -->

# Section 4

## Connecting to the Bigger Picture

---

## Three Integration Tiers

| Tier | Tools | Value |
|------|-------|-------|
| GitHub-native | Code Scanning, Artifact Attestations | SARIF in PRs, free |
| SCA platforms | Snyk, Mend, Black Duck | Continuous CVE monitoring |
| Cloud security | Wiz, CSPM | Runtime context + exposure |

Same pipeline outputs. Different ceiling.

---

## Runtime Context Changes Everything

**Without it:** "Critical CVE in dependency X"

**With Wiz/CSPM:**
- Deployed? Internet-facing? Elevated privileges?
- Same CVE — actionable risk or just noise?

The pipeline creates the provenance. The platform adds context.

---

## Realistic Adoption Path

<div class="checklist">

1. Start with one pipeline — PowerShell or Chocolatey
2. Start non-blocking — findings as warnings first
3. Add one composite action at a time
4. Tune the rules — Semgrep supports inline suppression
5. Add enforcement when ready

</div>

---

## The Repo

`github.com/adilio/publish-with-receipts`

- `examples/` — Flawed module + package. Fork and run the pipeline.
- `actions/` — Eight composite actions. Adopt one at a time.
- `semgrep-rules/` — Custom rules. Extend for your patterns.
- `docs/` — Threat model, tooling decisions, enterprise integration.

---

## Toolchain — All Free, All Open Source

| Tool | Purpose | Output |
|------|---------|--------|
| PSScriptAnalyzer | PowerShell static analysis | SARIF |
| Semgrep | Pattern-based scanning | SARIF |
| Syft | SBOM generation | CycloneDX JSON |
| Grype | Vulnerability scanning | SARIF + JSON |
| SLSA / GitHub Attestations | Provenance | In-toto JSON |

---

## Provenance Before Publish

| Question | Artifact | Tool |
|----------|----------|------|
| What's in this package? | SBOM | Syft |
| What did we check? | Scan results | PSScriptAnalyzer + Semgrep + Grype |
| Can we prove how it was built? | Provenance | SLSA / GitHub Attestations |

<div class="callout gradient">

### Not a green checkmark. Receipts.

</div>

---

<!-- _class: title -->

# Questions?

<p class="name wide">Adil Leghari</p>
<p class="handle wide">github.com/adilio/publish-with-receipts</p>
