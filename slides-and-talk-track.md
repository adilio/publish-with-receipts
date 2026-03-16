# Slides & Talk Track — Provenance Before Publish

**Talk Title:** Provenance Before Publish: Securing PowerShell and Chocolatey Supply Chains from the Pipeline Out
**Event:** Chocolatey Fest 2026
**Duration:** 90 minutes

---

## How to Read This Document

Each slide entry contains:
- **SLIDE:** The text and visual elements on the slide itself
- **TALK TRACK:** What the presenter says while this slide is showing

Slide numbers are approximate; adjust based on pacing during rehearsal.

---

## SECTION 1 — The Problem Space (20–25 min)

---

### Slide 1 — Title Slide

**SLIDE:**
```
Provenance Before Publish
Securing PowerShell and Chocolatey Supply Chains
from the Pipeline Out

[Your Name]
Chocolatey Fest 2026

github.com/YOUR_USERNAME/publish-with-receipts
```

**TALK TRACK:**
Thanks for being here. The title says "provenance before publish" — I'll explain what that phrase means in about five minutes, and by the end of the talk you'll have a GitHub Actions pipeline that implements it. This is a technical session. We're going to look at real YAML, real scan output, and real findings caught against intentionally vulnerable example packages I built for this talk. The repo is on screen — feel free to pull it up now if you want to follow along. Everything you're going to see today is in there.

---

### Slide 2 — Agenda

**SLIDE:**
```
What We're Covering

1. The Problem Space (20 min)
   Six supply chain threats already affecting your packages

2. PowerShell Module Pipeline (20 min)
   PSScriptAnalyzer → Semgrep → SBOM → Vuln Scan → Provenance

3. Chocolatey Package Pipeline (20 min)
   Same model, different risk profile

4. Connecting to the Bigger Picture (10 min)
   GitHub-native → SCA platforms → Cloud security

Q&A throughout
```

**TALK TRACK:**
Here's the structure. Four sections. The first one might make you a little uncomfortable about your current pipelines — that's intentional. The next two are the fix. The last one is about how the outputs plug into tools you're probably already using. I'll take questions throughout, and we'll have time at the end for anything I didn't answer inline.

---

### Slide 3 — Who This Talk Is For

**SLIDE:**
```
This talk is for you if:

✓ You maintain PowerShell modules published to PSGallery
✓ You maintain Chocolatey packages — community or internal repo
✓ You run CI/CD pipelines that install or publish these packages
✓ You've wondered "how would I even know if something was wrong?"

This talk is NOT another SBOM mandate slide deck.
```

**TALK TRACK:**
Quick calibration. Most supply chain security content you've seen is aimed at container ecosystems, npm, or PyPI. A lot of it is driven by government mandates around SBOM. That's a real conversation, but it's not what we're doing today. We're talking specifically about the Windows automation world: PowerShell modules and Chocolatey packages. These have their own supply chain characteristics, and those characteristics don't always get enough attention at security conferences. If you've ever shipped a module to PSGallery and thought "I hope that's fine," this talk is for you.

---

### Slide 4 — The Gap Nobody Talks About

**SLIDE:**
```
Where Security Controls Actually Live

[Diagram]

Source Code
    ↓
Build / CI Pipeline  ← YOU ARE HERE
    ↓
[ THE GAP ]          ← Most individual maintainers have nothing here
    ↓
Registry             ← Signing, moderation, virus scan (registry's job)
    ↓
Consumer Install
```

**TALK TRACK:**
Here's the core framing. Security controls exist at the registry level. PSGallery does virus scanning. Chocolatey community does human moderation. Those are real controls. But they're the registry's job, and they operate on what you've already published. The gap is what happens in your pipeline, before the artifact leaves your hands. That's where you have the most control, and for most individual or small-team maintainers, that gap is empty. "CI passed" and "nothing bad in it" are not the same statement.

---

### Slide 5 — The Thesis

**SLIDE:**
```
Provenance Before Publish

When you publish a package, you should be able to answer:

1. What's in this package?      → SBOM
2. What did we check?           → Scan results (SARIF)
3. Can we prove when and how    → Provenance attestation
   it was built?

These are the receipts.
Not a green checkmark — receipts.
```

**TALK TRACK:**
This is the thesis of the whole talk, and it's simple. Three questions. If you can answer all three at publish time, you have provenance. SBOM answers the first — it's a machine-readable inventory of what's in the package. SARIF answers the second — it's the output format for security scan results, and we'll be using it throughout. Provenance attestation answers the third — it's a signed record of what was built, from which commit, by which pipeline, at what time. I called the repo "publish with receipts" because that's what this is. Not just a green checkmark that CI passed. Actual receipts.

---

### Slide 6 — Threat Overview

**SLIDE:**
```
Six Threats We're Going to Fix

1. Typosquatting         — Wrong package, silently installed
2. Download-and-Execute  — Install script fetches & runs unknown binaries
3. Floating Dependencies — Version resolved at install time, not build time
4. Secret Leakage        — API keys and credentials in published source
5. Unverified Binaries   — Embedded EXEs with no checksum validation
6. Unsafe Install Patterns — Scripts that modify system state without documentation

All real. All affecting packages on PSGallery and Chocolatey today.
```

**TALK TRACK:**
Six threat vectors. I'm going to spend a few minutes on each one, because the pipeline we build only makes sense if you understand what it's defending against. These aren't theoretical. Each one has real incidents behind it, and I'll share those as we go.

---

### Slide 7 — Threat 1: Typosquatting

**SLIDE:**
```
Typosquatting

The attack:
  Register a package named close to a popular one.
  Wait for typos and copy-paste errors.

PSGallery reality:
  No Moniker rules (unlike npm)
  Az.Table registered to impersonate AzTable (10M+ downloads)
  — Aqua Security research, August 2023
  — Callbacks received from production Azure environments within hours
  — Microsoft acknowledged. Issue reproduced after the "fix."

Chocolatey:
  Community repo has human moderation
  Internal repos: typically nothing
```

**TALK TRACK:**
Aqua Security's Nautilus team published this research in August 2023. They registered `Az.Table` with a dot — to impersonate the legitimate `AzTable` module, which has over ten million downloads. They received callbacks from production cloud environments at real companies within hours of publishing. Not days. Hours. npm has Moniker rules that would prevent registering `react-native` if `react-native` already exists. PSGallery has no equivalent. Microsoft acknowledged the problem in late 2022. The Aqua team reproduced it after Microsoft said it was fixed. That's the current state of typosquatting protection on PSGallery. The concerning part isn't that attackers can do this — it's that in automated environments, a typo in a module name in a deployment script gets installed silently with no human reviewing the download.

---

### Slide 8 — Threat 2: Download-and-Execute

**SLIDE:**
```
Download-and-Execute

The pattern:
  $content = Invoke-WebRequest $url
  Invoke-Expression $content

Or in Chocolatey:
  Install-ChocolateyPackage -Url $url   # no checksum

Real incident — Serpent Malware, 2022 (Proofpoint):
  • Targeted French organizations
  • Used macro docs to install Chocolatey legitimately
  • Used Chocolatey to install Python and pip legitimately
  • Deployed backdoor via steganography
  • Chocolatey wasn't compromised — the pipeline around it was

The question isn't "is Chocolatey safe?"
It's "can you prove what your install script actually ran?"
```

**TALK TRACK:**
This pattern is so normalized in Chocolatey packages that people stop questioning it. Of course the install script downloads an executable — that's how Chocolatey works. But which executable, from where, and can you prove it's the same binary the maintainer tested? The Serpent campaign from 2022 is a good illustration. Chocolatey wasn't compromised. Python and pip weren't compromised. The attackers used entirely legitimate tools in a sequence that wasn't validated anywhere in the chain. That's the threat model. Legitimate package managers become attack vectors not because they're broken, but because the pipeline around them doesn't check what's actually happening.

---

### Slide 9 — Threat 3: Floating Dependencies

**SLIDE:**
```
Floating Dependencies

PowerShell manifest (psd1):
  RequiredModules = @('Az.Accounts')          # no version = latest
  RequiredModules = @(@{ModuleVersion='1.0'}) # minimum, not exact

Chocolatey nuspec:
  <dependency id="vcredist140" />             # no version constraint

The risk:
  • Tuesday's deploy pulls a different version than Monday's
  • No code change on your side — just a new version published upstream
  • Dependency confusion: attacker publishes higher version, pipeline pulls it

In Chocolatey context: dependencies run install scripts with elevated privilege.
```

**TALK TRACK:**
Dependency confusion is the more famous version of this attack — Alex Birsan's research from 2021 showed that if your private package registry falls back to the public one, an attacker can publish a higher version number and your build pulls it automatically. But you don't even need a sophisticated attack. Unpinned dependencies just drift. Your pipeline resolves the latest version at install time, and if you haven't pinned it, you're running code you didn't test against. In PowerShell, the consequence might be a broken script. In Chocolatey, the consequence is a dependency install script running as admin against production systems.

---

### Slide 10 — Threat 4: Secret Leakage

**SLIDE:**
```
Secret Leakage

What gets published accidentally:
  • API keys hardcoded in module functions ("just for testing")
  • PSGallery publish scripts included in the package source
  • Connection strings in test files bundled into the published module
  • Internal URLs and share paths in Chocolatey install scripts

PSGallery reality (Aqua, 2023):
  Unlisted packages remain accessible via the API.
  Researchers found GitHub API keys and PSGallery keys in published packages.
  Unlisted ≠ deleted.

"I'll fix it before I publish" is the most dangerous sentence
in package maintenance.
```

**TALK TRACK:**
The Aqua research found something beyond the typosquatting PoC: PSGallery allows unlisted packages to remain accessible via the API. Researchers found packages where maintainers had accidentally included their PSGallery API key in the publishing script that got bundled with the module source. The key that publishes new versions of the module, sitting in the published module, accessible to anyone who knows where to look. Once it's published, even if you unlist it, the data may still be accessible. Chocolatey has a variant of this: internal tools packages that contain hardcoded internal URLs, share paths, or API credentials for accessing internal binary repositories. These end up published to the community repo when someone copies an internal package and forgets to scrub it.

---

### Slide 11 — Threat 5: Unverified External Binaries

**SLIDE:**
```
Unverified External Binaries

The convention: VERIFICATION.txt
  → human-readable file with source URL and checksum
  → not machine-enforced in most pipelines

What can go wrong:
  • Checksum missing entirely
  • Checksum uses MD5 or SHA1 (collision-vulnerable)
  • Checksum present but wrong
  • Binary correct at install time, but directory permissions
    allow replacement afterward

Real CVEs: C:\tools\php81, C:\tools\Cmder
  Insecure directory permissions → binary replacement by lower-privilege attacker
  Even if the install was clean, you're not done.

Chocolatey packages run as admin.
If the binary is wrong, it executes as admin.
```

**TALK TRACK:**
VERIFICATION.txt is the right idea. Chocolatey defined the convention, and community packages are supposed to include it. The problem is it's a human-readable text file that gets reviewed by a human once during moderation, and then nobody looks at it again. If the checksum is wrong — or missing — nothing automated catches it. The CVEs around Chocolatey package directory permissions are a related issue: even if the binary was legitimate at install time, the directory it landed in has write permissions for lower-privileged users. So you got the right binary, you verified it, you installed it as admin — and now any user on the system can replace it. Verification needs to happen at build time, and the package's directory security model needs to be correct. This pipeline handles the first part.

---

### Slide 12 — Threat 6: Unsafe Install Script Patterns

**SLIDE:**
```
Unsafe Install Script Patterns

chocolateyInstall.ps1 can:
  ✗ Modify the system PATH (without documenting or cleaning up)
  ✗ Write registry keys (without a corresponding uninstall cleanup)
  ✗ Create Windows services
  ✗ Download and immediately execute content
  ✗ Reference internal URLs and credentials

The problem isn't that these actions are inherently wrong.
It's that they're often undocumented, untested, and unreviewable at scale.

Community repo: human review catches some of this
Internal repos: typically zero review

Run as admin. No questions asked.
```

**TALK TRACK:**
This is the broadest category and the one that probably describes the most real-world packages. Not malicious packages — just packages where the install script does things that nobody ever thought to document or test at a security level. PATH modification that never gets cleaned up on uninstall. Registry keys written without a corresponding remove in the uninstall script. Downloads that happen outside Chocolatey's checksum-enforced helper functions. None of this is necessarily intentional. It's just what happens when install scripts get written quickly and the only check is "does it install successfully on my machine."

---

### Slide 13 — Mental Model: Three Artifacts

**SLIDE:**
```
What Provenance Actually Means (Practically)

SBOM               What's in the package
(CycloneDX JSON)   Every dependency, every file, every version
                   Generated by: Syft

Scan Results       What we checked
(SARIF)            Code quality, security patterns, known CVEs
                   Generated by: PSScriptAnalyzer, Semgrep, Grype

Provenance         When, where, and how it was built
Attestation        Tied to a specific commit, pipeline, and timestamp
                   Generated by: GitHub Attestations / SLSA

All three together = receipts you can show to anyone.
```

**TALK TRACK:**
Before we get into the pipeline demos, here's the mental model. Three artifact types. SBOM is the inventory — CycloneDX JSON format, generated by Syft. SARIF is the scan results format — it's what PSScriptAnalyzer, Semgrep, and Grype all emit, and GitHub natively understands it. Provenance attestation is the signed build record — ties the artifact to the exact commit, workflow, and timestamp that produced it. You don't need to understand the specs deeply right now. What matters is that by the end of Sections 2 and 3, your pipeline will produce all three automatically, for every PR and every push.

---

### Slide 14 — Toolchain Overview

**SLIDE:**
```
The Toolchain (All Free, All OSS)

Tool              Purpose                    Output
──────────────────────────────────────────────────────
PSScriptAnalyzer  PowerShell static analysis  SARIF
Semgrep           Custom pattern scanning     SARIF
Syft              SBOM generation             CycloneDX JSON
Grype             Vulnerability scanning      SARIF + JSON
GitHub Scanning   PR annotations, Security    (ingests SARIF)
                  tab integration
GitHub            Provenance attestation      SLSA-style JSON
Attestations
Pester            Unit testing                Test results
```

**TALK TRACK:**
Here's every tool we'll use. All free, all open source, no vendor lock-in. I'll reference this table throughout the demos so you can see where each output goes. The key insight is that SARIF is the connective tissue — all the security tools emit SARIF, and GitHub Code Scanning ingests SARIF and turns it into PR annotations and the Security tab. You don't need any configuration to make that integration work; it's built into GitHub Actions.

---

## SECTION 2 — PowerShell Module Pipeline (20–25 min)

---

### Slide 15 — Section 2 Title

**SLIDE:**
```
Section 2
PowerShell Module Pipeline
Building the Guardrails

Live Demo:
examples/powershell-module/
.github/workflows/powershell-supply-chain.yml
```

**TALK TRACK:**
Let's build the first pipeline. We're going to walk through the example PowerShell module in the repo, then watch the pipeline run against it. I deliberately put anti-patterns into the example module — the same ones I just described in Section 1. By the end of this section, all of them will be caught automatically.

---

### Slide 16 — Tour: The Example Module

**SLIDE:**
```
examples/powershell-module/ExampleModule/

ExampleModule.psd1           ← Manifest with intentional issues:
                               • RequiredModules without version pinning
                               • ScriptsToProcess (executes at module load)
                               • Missing CompanyName, Copyright

Public/Invoke-SafeFunction.ps1   ← Baseline: how things should look
Public/Invoke-UnsafeFunction.ps1 ← Contains:
                                   • Hardcoded API key
                                   • TLS certificate validation bypass
                                   • Download-and-execute pattern
                                   • Base64 encoded command execution

tests/ExampleModule.Tests.ps1    ← Pester tests (they pass)
```

**TALK TRACK:**
This module works. You can import it, call its exported functions, and all the Pester tests pass. Traditional CI gives you a green checkmark. But look at what's in `Invoke-UnsafeFunction.ps1` — a hardcoded API key, a TLS bypass, a download-and-execute pattern. None of that causes a test failure. Pester tests what the function returns, not what it downloads or leaks. And the manifest has a `ScriptsToProcess` entry, which runs a script at module import time. Aqua's typosquatting PoC used exactly this mechanism — the malicious code ran as soon as you imported the module. Tests don't catch that.

---

### Slide 17 — The Workflow Structure

**SLIDE:**
```
.github/workflows/powershell-supply-chain.yml

Triggers: pull_request, push to main

Jobs (in order):

1. pester-tests          Unit tests (baseline)
2. ps-script-analysis    PSScriptAnalyzer → SARIF
3. semgrep-scan          Custom rules → SARIF
4. dependency-pin-check  Floating dependency detection
5. sbom-generate         Syft → CycloneDX JSON
6. vulnerability-scan    Grype → SARIF + JSON
7. provenance-generate   Build attestation
8. pipeline-summary      Aggregate results, upload artifacts
```

**TALK TRACK:**
Here's the full pipeline. Eight jobs. They run in order, though several can run in parallel once the unit tests pass. Each job uses a composite action from the `actions/` directory in the repo — that means you can pull any of these steps into your own pipelines individually without taking the whole thing. Let's go through each one.

---

### Slide 18 — Step 1: PSScriptAnalyzer

**SLIDE:**
```
Step 1: PSScriptAnalyzer

What it catches:
  • Invoke-Expression usage
  • Write-Host instead of Write-Output / Write-Verbose
  • Missing [CmdletBinding()] and parameter validation
  • Invoke-WebRequest without certificate validation

Output: SARIF → uploaded to GitHub Code Scanning

What it does NOT catch:
  • Hardcoded secrets (not a security scanner)
  • Custom anti-patterns specific to your codebase

Rule of thumb: PSScriptAnalyzer = code quality + approved cmdlet misuse
```

**TALK TRACK:**
PSScriptAnalyzer is the standard for PowerShell static analysis. Most teams already have it somewhere. What matters for this pipeline is the output format — SARIF — which means findings show up directly in the PR diff as annotations. You see exactly which line the issue is on, with a description. The thing to understand about PSScriptAnalyzer is what it's not designed for: it'll flag `Invoke-Expression` as a best practice issue, but it won't catch a hardcoded API key or a download-and-execute pattern that uses perfectly legitimate cmdlets. For that, we need Semgrep.

---

### Slide 19 — Step 2: Semgrep with Custom Rules

**SLIDE:**
```
Step 2: Semgrep — Custom Rules

semgrep-rules/powershell-unsafe-patterns.yml

Rules included:
  powershell-download-execute     IWR/IRM piped to IEX
  powershell-hardcoded-secret     API keys, tokens, passwords in variables
  powershell-disable-cert-check   TLS validation bypass
  powershell-encoded-command      -EncodedCommand or base64 decode+execute
  powershell-scripts-to-process   ScriptsToProcess in module manifest

Output: SARIF → GitHub Code Scanning (same tab as PSScriptAnalyzer)

Fork the rules. Add your own. They're YAML.
```

**TALK TRACK:**
Semgrep fills the gap PSScriptAnalyzer doesn't cover. Off-the-shelf Semgrep rules don't cover PowerShell very well — there just isn't a large maintained ruleset for it. So these rules are custom, written specifically for the supply chain patterns we walked through in Section 1. The download-and-execute rule matches patterns where an `Invoke-WebRequest` result flows into `Invoke-Expression` — not just the obvious pipe, but also the assign-then-execute pattern. The hardcoded secret rule looks for specific variable naming patterns near string assignments with entropy characteristics of real keys. I'll show these catching actual findings in the example module in a moment.

---

### Slide 20 — [DEMO] Semgrep Findings in a PR

**SLIDE:**
```
[Screenshot / Live Demo]

PR Annotations from Semgrep:

Invoke-UnsafeFunction.ps1, line 14:
  [HIGH] powershell-hardcoded-secret
  Hardcoded API key detected. Rotate this credential and
  use a secrets manager or environment variable instead.

Invoke-UnsafeFunction.ps1, line 28:
  [HIGH] powershell-download-execute
  Invoke-WebRequest result executed directly. Verify source
  and integrity before executing downloaded content.

ExampleModule.psd1, line 9:
  [MEDIUM] powershell-scripts-to-process
  ScriptsToProcess executes at module import time.
  This is a known attack vector for supply chain compromise.
```

**TALK TRACK:**
[If live demo] Let me open the PR view. You can see the annotations directly in the diff — GitHub Code Scanning maps the SARIF line numbers to the actual code. You don't have to go look at a separate report. The finding is right next to the code that triggered it. [If screenshot] This is what it looks like. Three findings. The API key, the download-and-execute, and the `ScriptsToProcess` flag in the manifest. All caught automatically. The unit tests still pass. This module still works. But now we have visibility.

---

### Slide 21 — Step 3: SBOM Generation

**SLIDE:**
```
Step 3: Syft → SBOM

What it generates:
  • Inventory of every file in the module
  • Declared dependencies from the manifest + their versions
  • Metadata: name, version, author, license (from psd1)

Output format: CycloneDX JSON
Stored as: workflow artifact (downloadable from Actions run)

Why it matters:
  • Build-time snapshot — "what was in it when we built it"
  • Input to the vulnerability scan (next step)
  • When a new CVE drops, you can check all past builds
    to see which packages included the affected component
```

**TALK TRACK:**
The SBOM is the ingredient list. Syft walks the module directory, reads the manifest, and produces a machine-readable inventory in CycloneDX JSON format. That format is understood by basically every downstream security tool — SCA platforms, vulnerability scanners, cloud security products. Right now the main use is feeding it to Grype in the next step. But the artifact is stored in the pipeline run, so when a CVE drops in three months against a dependency you used today, you can query your build history to find out which published versions were affected.

---

### Slide 22 — Step 4: Vulnerability Scanning

**SLIDE:**
```
Step 4: Grype ← SBOM from Syft

What it does:
  • Checks every component in the SBOM against NVD, GitHub Advisory,
    and other vulnerability databases
  • Maps CVEs to severity: Critical / High / Medium / Low

Output:
  • SARIF → GitHub Code Scanning
  • JSON → for downstream enterprise tooling

Configuration:
  Fail on: Critical (configurable)
  Warn on: High and below (configurable)

Limitation: only knows about published CVEs.
That's still a lot of CVEs.
```

**TALK TRACK:**
Grype takes the SBOM from the previous step and cross-references every component against known vulnerability databases. For a pure PowerShell module, you might not have many findings — the module is mostly script files. But you still want this step running, because the moment you add a dependency on a published module that has a known vulnerability, it shows up here automatically. The threshold configuration is important: this pipeline defaults to warning on everything below Critical and failing the build on Critical findings. You should decide what's right for your context. The defaults are intentionally permissive to encourage adoption.

---

### Slide 23 — Step 5: Provenance Generation

**SLIDE:**
```
Step 5: Provenance Attestation

What it records:
  • Source repository (full URL)
  • Commit SHA
  • GitHub Actions workflow reference
  • Build timestamp
  • Hashes of produced artifacts (module zip, SBOM, SARIF)

Format: SLSA-compatible (via GitHub Attestations)
Stored as: workflow artifact

What it proves:
  "This package was built from commit abc123 in repo X,
   by workflow Y, on date Z, and its SHA256 is ..."

A consumer can verify this without trusting your word.
```

**TALK TRACK:**
This is the receipt. The SBOM answers "what's in it." The SARIF answers "what did we check." The provenance answers "can you prove it." The provenance document is signed by GitHub's OIDC token for the workflow run, which means it's tied to the specific commit and repository — not just claimed to be. A consumer who downloads your module from PSGallery can take the artifact hash, find the attestation in your repo's artifact history, and verify that the module they downloaded matches what your pipeline built from your source code at that specific commit. That's the chain of custody from source to publish.

---

### Slide 24 — Design Decisions

**SLIDE:**
```
Why These Tools?

PSScriptAnalyzer   The standard. Everyone should already have this.
Semgrep            Free for custom rules. SARIF output. Works offline.
                   Alternatives (CodeQL) need more setup, slower.
Syft + Grype       Most adopted OSS SBOM/scan pair. Work together natively.
                   CycloneDX format is the most widely supported.
GitHub Attestations GitHub-native, zero extra infrastructure.

What about code signing?
  Code signing = who published it (registry-level control)
  This pipeline = what's in it and what we checked
  Both are needed. They're not competing.

Non-blocking by default:
  Visibility first. Enforcement second.
  You decide what fails the build.
```

**TALK TRACK:**
Two design decisions I want to call out explicitly. First: this pipeline is non-blocking by default. Findings surface as annotations and warnings. Builds don't fail unless you configure them to. That's intentional. The goal is to get visibility into your packages first, understand what the tools actually catch in your codebase, and then decide what you want to enforce. Don't let the perfect be the enemy of the good — start with warnings, tune the rules, then add enforcement once you trust what you're seeing. Second: code signing is orthogonal to this. Signing tells consumers who published the package. This pipeline tells you what's in it. You need both.

---

## SECTION 3 — Chocolatey Package Pipeline (20–25 min)

---

### Slide 25 — Section 3 Title

**SLIDE:**
```
Section 3
Chocolatey Package Pipeline
A Different Risk Profile

Live Demo:
examples/chocolatey-package/
.github/workflows/chocolatey-supply-chain.yml
```

**TALK TRACK:**
Now the Chocolatey pipeline. Almost everything from Section 2 applies here — Semgrep, Syft, Grype, provenance. But Chocolatey packages have a different risk profile than PowerShell modules, and that means the pipeline needs additional steps that make no sense for a pure PowerShell module. Let me explain why before we look at the code.

---

### Slide 26 — What Makes Chocolatey Different

**SLIDE:**
```
Why Chocolatey Gets Its Own Pipeline

1. Elevated privilege by default
   choco install runs as admin
   Install scripts have full system access

2. External binary downloads are the norm
   Most packages are wrappers around an exe/msi/zip
   The package is not the software — it fetches the software

3. Install scripts modify system state
   PATH, registry, services — all fair game
   Often undocumented, rarely tested for security properties

4. VERIFICATION.txt is convention, not enforcement
   Human-readable. Not machine-checked.

The PowerShell pipeline catches some of this.
It misses the Chocolatey-specific parts entirely.
```

**TALK TRACK:**
PowerShell modules are mostly script files. Chocolatey packages are often thin wrappers around external binaries — they're infrastructure. They run as admin. They download executables. They modify system state. The threat surface is larger and the privilege level is higher. If I wrote a malicious PowerShell module and you imported it, the damage is bounded by your current user context. If I wrote a malicious Chocolatey install script and you ran it, I'm running as admin. That difference shapes the entire pipeline.

---

### Slide 27 — Tour: The Example Package

**SLIDE:**
```
examples/chocolatey-package/

example-package.nuspec         ← Manifest with intentional issues:
                                 • Missing projectUrl, iconUrl, tags
                                 • Dependency without version pinning
                                 • Generic name (collision risk)

tools/chocolateyInstall.ps1    ← Install script with intentional issues:
                                 • Install-ChocolateyPackage without checksum
                                 • Invoke-WebRequest outside Choco helpers
                                 • PATH modification (undocumented)
                                 • Registry writes (undocumented)
                                 • Hardcoded internal URL

tools/chocolateyUninstall.ps1  ← Basic (but present)

tools/VERIFICATION.txt         ← Intentionally incomplete:
                                 • Missing checksum
                                 • Vague source URL ("vendor website")
```

**TALK TRACK:**
Same approach as the PowerShell example — this package works. `choco install` succeeds. The software installs. But the install script does things that your pipeline currently has no visibility into. The checksum is missing from the `Install-ChocolateyPackage` call. There's an additional `Invoke-WebRequest` that downloads a supplementary tool with no verification at all. PATH gets modified and there's nothing in the uninstall script that reverses it. And there's a hardcoded internal URL that would be embarrassing if this got published to the community repo. None of this causes an install failure. It all just silently happens.

---

### Slide 28 — The Chocolatey Workflow Structure

**SLIDE:**
```
.github/workflows/chocolatey-supply-chain.yml

Jobs (in order):

1. naming-validation     Typosquatting / collision check
2. integrity-check       Checksum verification for all binaries
3. install-script-scan   Semgrep with Chocolatey-specific rules
4. dependency-pin-check  Floating dependency detection (nuspec)
5. sbom-generate         Syft → CycloneDX (includes embedded binaries)
6. vulnerability-scan    Grype → SARIF + JSON
7. provenance-generate   Build attestation
8. pipeline-summary      Aggregate, upload artifacts
```

**TALK TRACK:**
The Chocolatey pipeline has the same shape as the PowerShell one but the first three steps are Chocolatey-specific. Naming validation, checksum integrity verification, and a Semgrep scan with a different ruleset. The rest — SBOM, Grype, provenance — are the same composite actions from the same `actions/` directory. You can use them in either pipeline.

---

### Slide 29 — Step 1: Package Naming Validation

**SLIDE:**
```
Step 1: Naming Validation

actions/choco-naming-validation/action.yml

What it does:
  • Queries Chocolatey community repo API
  • Computes string similarity (edit distance) against existing package names
  • Flags potential conflicts or squatting attempts

Thresholds:
  > 90% similar to existing package → ERROR (likely conflict)
  > 75% similar                    → WARNING (review recommended)
  Exact match                      → ERROR (already exists)

Output: annotation in PR + exit code for enforcement

Also checks:
  • Reserved prefixes (chocolatey, choco, microsoft)
  • Naming convention compliance (lowercase, no spaces)
```

**TALK TRACK:**
This is the typosquatting defense from Section 1, made concrete. It won't stop a determined attacker from registering a similar name on the community repo — that's a registry-level problem. What it does is catch it in your pipeline before you publish. If you're building an internal package and you accidentally picked a name that's 92% similar to something on the community repo, you want to know that before your internal package goes out, especially if your pipeline might ever talk to both registries.

---

### Slide 30 — Step 2: Checksum and Integrity Verification

**SLIDE:**
```
Step 2: Integrity Check

actions/choco-integrity-check/action.yml

What it checks:

Install-ChocolateyPackage calls:
  ✓ Checksum parameter present
  ✓ ChecksumType is SHA256 (not MD5, not SHA1)
  ✓ URL is HTTPS (not HTTP/FTP without checksum)

Invoke-WebRequest calls (outside Choco helpers):
  ✗ Flagged — Chocolatey's checksum enforcement doesn't apply here

Embedded files in tools/:
  ✓ VERIFICATION.txt exists
  ✓ Every embedded file has an entry with a SHA256 checksum
  ✓ Entry's source URL is a real URL, not "see vendor website"

Optional: download and verify (configurable)
```

**TALK TRACK:**
Chocolatey's built-in `Install-ChocolateyPackage` helper enforces checksums for non-HTTPS downloads as of version 0.10. But two problems: first, a lot of existing packages are still missing checksums. Second, `Invoke-WebRequest` used directly — outside the Chocolatey helper — gets no checksum enforcement at all. This step catches both. It also validates VERIFICATION.txt against the actual embedded files. The optional download-and-verify mode will actually download the referenced URLs during the pipeline run and check the downloaded content against the declared checksum. That's the strongest form of integrity verification but it adds pipeline time, so it's opt-in.

---

### Slide 31 — Step 3: Install Script Analysis (Chocolatey Rules)

**SLIDE:**
```
Step 3: Semgrep — Chocolatey Rules

semgrep-rules/chocolatey-install-patterns.yml

Rules included:
  choco-unverified-download        IWR outside Choco helpers
  choco-install-no-checksum        Install-ChocolateyPackage, no checksum
  choco-hardcoded-internal-url     Internal domains / share paths
  choco-path-modification          PATH changes (flag for review)
  choco-registry-write             Registry modifications (flag for review)
  choco-execute-downloaded         Download → immediate execution

Plus: all powershell-unsafe-patterns.yml rules run too
(hardcoded secrets, download-execute, TLS bypass, etc.)

Output: SARIF → GitHub Code Scanning
```

**TALK TRACK:**
The Chocolatey Semgrep ruleset runs on top of the PowerShell rules from Section 2, not instead of them. You get both. The Chocolatey-specific rules are focused on the patterns that are normal in PowerShell generally but are higher risk in an install script that runs as admin. Path modification isn't inherently wrong. Registry writes aren't inherently wrong. But in a Chocolatey install script, you want them flagged for review every time, because they need a corresponding cleanup in the uninstall script and they need documentation so users understand what the package is doing to their system.

---

### Slide 32 — [DEMO] Chocolatey Pipeline Findings

**SLIDE:**
```
[Screenshot / Live Demo]

PR Annotations for example-package:

chocolateyInstall.ps1, line 8:
  [HIGH] choco-install-no-checksum
  Install-ChocolateyPackage called without checksum parameter.
  Binary integrity cannot be verified.

chocolateyInstall.ps1, line 22:
  [HIGH] choco-unverified-download
  Invoke-WebRequest used outside Chocolatey helper functions.
  No checksum enforcement applies to this download.

chocolateyInstall.ps1, line 31:
  [MEDIUM] choco-path-modification
  PATH modification detected. Verify this is documented in
  package description and reversed in chocolateyUninstall.ps1.

chocolateyInstall.ps1, line 15:
  [HIGH] powershell-hardcoded-secret
  Hardcoded internal URL with credentials pattern detected.

example-package.nuspec:
  Naming validation: 1 WARNING (similarity to existing package)
```

**TALK TRACK:**
[If live demo] Here's the PR. Five findings. The two checksum issues would both go undetected by the PowerShell pipeline from Section 2 — they're Chocolatey-specific patterns. The PATH modification is flagged for review, not as a hard error, because it might be intentional and correct. The hardcoded internal URL comes from the PowerShell rules. And the naming validation caught a similarity warning against an existing community package. This is a package that installs successfully. CI passes. And yet five things need to be looked at before it gets published.

---

### Slide 33 — SBOM for Chocolatey Packages

**SLIDE:**
```
Step 4: Syft SBOM — Chocolatey Specifics

Same composite action as PowerShell pipeline.
Different output because Chocolatey packages contain binaries.

SBOM includes:
  • Package metadata from nuspec
  • Declared dependencies (and versions if pinned)
  • Embedded files in tools/ — file hashes even if unidentifiable
  • If Syft recognizes the embedded binary (e.g., .NET exe),
    it records the component name and version too

This matters for vulnerability scanning:
  • Grype can match embedded binaries to CVEs if Syft identifies them
  • Even unidentifiable binaries have their hash recorded —
    useful for forensics if something goes wrong later
```

**TALK TRACK:**
The SBOM step uses the same composite action as the PowerShell pipeline, but the output is richer for Chocolatey packages because they contain binaries. If you embed a .NET executable and Syft can identify it — which it often can for common tools — the SBOM includes the component name and version, and Grype can match it against CVEs. Even if Syft can't identify the binary, it records the file hash. That hash is your evidence that the binary at publish time was the same as the one you tested. If that binary gets flagged later, you have a chain back to the exact build artifact.

---

### Slide 34 — What the PS Pipeline Wouldn't Catch

**SLIDE:**
```
Why Chocolatey Needs Its Own Pipeline

PowerShell pipeline would catch:
  ✓ Hardcoded secrets in install scripts
  ✓ Download-and-execute patterns
  ✓ PSScriptAnalyzer code quality issues

PowerShell pipeline would miss:
  ✗ Missing checksum in Install-ChocolateyPackage
     (Choco-specific helper, not generic PowerShell)
  ✗ VERIFICATION.txt incomplete or missing
  ✗ PATH modification without uninstall cleanup
  ✗ Naming collision against Chocolatey community repo
  ✗ Embedded binary files (no script files to scan)
  ✗ Registry writes specific to install context

Same model. Different ruleset. Different binary handling.
```

**TALK TRACK:**
This is the summary of why these are two separate pipelines. It's not because the tools are different — most of the tools are the same. It's because the risk surface is different. If you just copy the PowerShell pipeline and run it against a Chocolatey package, you'll catch maybe half the issues. You'll miss everything that's specific to how Chocolatey works: the helper functions, the checksum enforcement, the VERIFICATION.txt convention, the binary embedding, the naming conventions. The composite actions are designed so you can mix and match — use the Chocolatey naming validation and integrity check actions in a pipeline that also includes the PowerShell Semgrep rules.

---

## SECTION 4 — Connecting to the Bigger Picture (10–15 min)

---

### Slide 35 — Section 4 Title

**SLIDE:**
```
Section 4
Connecting to the Bigger Picture

Pipeline outputs → Platforms
From solo maintainer to enterprise team
```

**TALK TRACK:**
Last section. The pipeline produces artifacts. Those artifacts are useful on their own, but they become more powerful when they're connected to platforms that add continuous monitoring and runtime context. Let's look at what that looks like at three levels.

---

### Slide 36 — Three Integration Tiers

**SLIDE:**
```
Pipeline Outputs → Three Tiers

Tier 1: GitHub-Native (free, zero setup beyond the pipeline)
  SARIF → Code Scanning → PR annotations + Security tab
  Provenance → GitHub Artifact Attestations
  Dependabot → some overlap with SBOM data

Tier 2: SCA Platforms (your existing enterprise tooling)
  CycloneDX SBOM → Snyk, Mend, Black Duck, Dependency-Track
  SARIF → import into existing SAST/DAST platforms
  Value: continuous monitoring when new CVEs drop

Tier 3: Cloud Security / Runtime Context
  SBOM + deployed workload data → actual exposure analysis
  "Is this vulnerable component actually deployed and reachable?"
  Grype finding → Wiz / CSPM → "Critical, but this system
  isn't internet-facing and has no sensitive data access"
```

**TALK TRACK:**
Tier 1 is what we've been demonstrating. It's free, it's built into GitHub, and it works the moment you add the pipeline. Tier 2 is where enterprise teams are. Most of you in this room have a software composition analysis tool. Whether that's Snyk, Mend, Black Duck, or Dependency-Track, those tools can ingest CycloneDX SBOMs and SARIF results. The pipeline's outputs are designed to feed into whatever you're already using. You don't replace your existing tooling; you give it better inputs than it was getting before. Tier 3 is the ceiling. A vulnerability finding from Grype tells you there's a CVE. Runtime context tells you whether it matters in your environment.

---

### Slide 37 — Runtime Context: Why It Matters

**SLIDE:**
```
The Difference Between a Finding and a Risk

Grype says:       CVE-2024-XXXX, Critical, affects component Y
That's a finding.

Platform says:    Component Y is deployed in these 3 workloads.
                  One is internet-facing. Two are internal.
                  The internet-facing one has read access to customer data.
That's a risk.

For PowerShell + Chocolatey maintainers:
  Build-time SBOM = what was in the package when you shipped it
  Runtime correlation = which of your deployed systems
                        have this package installed, with what context

The pipeline creates the provenance.
Runtime platforms tell you which findings actually matter.
```

**TALK TRACK:**
The reason this matters at the enterprise level is alert fatigue. If Grype finds 40 medium CVEs and your security team gets a ticket for each one, nothing gets fixed. But if 35 of those CVEs are in components that only run in dev sandboxes with no network access and no sensitive data, and 5 are in production internet-facing systems — your team should be working on the 5. Cloud security platforms like Wiz provide that runtime context. They ingest the SBOM, correlate it against deployed workloads, and surface the findings that actually have exposure. The pipeline creates the input. The platform does the triage.

---

### Slide 38 — Realistic Adoption Advice

**SLIDE:**
```
How to Actually Roll This Out

Start with one.
  PowerShell or Chocolatey — whichever is your bigger surface area.
  Don't try to do both pipelines in week one.

Start non-blocking.
  Warnings only. Let your team see what tools catch before you enforce.
  Expect false positives — tune the rules.

Adopt composite actions individually.
  PSScriptAnalyzer today.
  Add Semgrep next sprint.
  Add SBOM + Grype next month.
  Add provenance when you're ready.

The docs are in the repo.
  Threat model, tooling decisions, remediation guide.
  If you need to justify this to your manager, the rationale is written.
```

**TALK TRACK:**
I want to be direct about adoption. Don't try to implement all eight pipeline steps across all your packages in one sprint. That's how projects die. Start with one package, one pipeline, non-blocking. The composite actions are specifically designed to be adopted piecemeal. PSScriptAnalyzer by itself is better than nothing. SBOM generation by itself gives you build-time inventory. Each step adds value independently — you don't need the full pipeline to get started. And expect the Semgrep rules to fire on things that are actually fine in your codebase. That's normal. Inline suppression comments with a justification are the right response. The suppression is visible in the SARIF output, so it's not hiding the issue — it's documenting that someone reviewed it.

---

### Slide 39 — The Repo

**SLIDE:**
```
publish-with-receipts

github.com/YOUR_USERNAME/publish-with-receipts

What's in it:

examples/         Intentionally flawed PS module + Chocolatey package
                  Fork it, open a PR, watch the pipeline run

actions/          8 reusable composite actions
                  Pull them into your repos one at a time

semgrep-rules/    Custom rules for PS + Chocolatey patterns
                  Extend them for your own codebase

docs/             Threat model, tooling decisions,
                  enterprise integration guide, remediation guide

scripts/          Invoke-LocalValidation.ps1
                  Run the pipeline locally before you push

Issues and PRs welcome.
```

**TALK TRACK:**
Here's the repo. Everything you saw today is in it. The fastest way to see the pipeline in action is to fork the repo, open a PR that modifies the example packages, and watch the workflows run. The intentionally flawed examples will generate real findings. From there, you can pull the composite actions into your own repos individually. The `docs/` directory has the full rationale for every tool choice and every rule — if someone on your team asks "why Semgrep over CodeQL," that question is answered in `docs/tooling-decisions.md`. Issues and PRs are welcome. If you have a threat vector that isn't covered or a tool that fits better for your use case, I want to hear about it.

---

### Slide 40 — Q&A Prep

**SLIDE:**
```
Anticipated Questions

"How does this compare to Chocolatey moderation?"
  Complementary. Moderation = registry-level. This = pipeline-level.
  Internal repos have no moderation — this fills that gap entirely.

"What about Azure DevOps?"
  Concepts are the same. Composite actions are GitHub-specific.
  PSScriptAnalyzer, Semgrep, Syft, Grype all run anywhere.

"How do you handle legitimate IWR usage that gets flagged?"
  Semgrep inline suppression + justification comment.
  Suppression is visible in SARIF — it documents the review.

"Does this slow down CI?"
  2-5 minutes for typical packages.
  Most of that is Grype's vuln DB download (cached after first run).

"What about signing?"
  Orthogonal. Signing = who published it. This = what's in it.
  Add Authenticode/NuGet signing as an additional step.

"Can I use this for internal-only packages?"
  Yes — this is actually where it adds the most value.
  Internal repos have zero external moderation.
```

**TALK TRACK:**
[Reference this slide as questions come in. Don't read it verbatim — use it as a prompt for the answers you've already prepared.]

The internal repo question is one I want to flag explicitly before we get into Q&A, because it often comes up and the answer is important: internal Chocolatey repos are where this pipeline adds the most value, not the least. The Chocolatey community repo has human moderation. PSGallery has virus scanning. Your internal repo has exactly whatever controls you built. If the answer is "none," then every package you publish internally has a zero-review install script that runs as admin on your systems. That's a larger attack surface than PSGallery.

---

### Slide 41 — Closing

**SLIDE:**
```
Summary

The gap between "CI passed" and "safe to publish" is real.
You can close it with free, open source tooling,
in a pipeline that generates receipts you can actually show.

Three artifacts:
  SBOM       — What's in it
  SARIF      — What you checked
  Provenance — When, where, and how it was built

Eight reusable composite actions.
24+ custom Semgrep rules.
All in the repo.

Thank you.
github.com/YOUR_USERNAME/publish-with-receipts
```

**TALK TRACK:**
Supply chain security for PowerShell and Chocolatey doesn't require buying a new tool or hiring a security team. It requires a pipeline that generates evidence. SBOM, SARIF, provenance — three artifact types, eight composite actions, all open source, all designed to be adopted incrementally. The gap between "CI passed" and "safe to publish" is closeable. The repo is there, the docs are there, and the examples are there to show you exactly what the pipeline catches. Thank you for your time. I'll be around after the session if you want to dig into anything specific.

---

## Appendix: Slide Count and Time Budget

| Section | Slides | Estimated Time |
|---------|--------|----------------|
| Section 1: Problem Space | 14 (slides 1–14) | 20–25 min |
| Section 2: PS Pipeline | 10 (slides 15–24) | 20–25 min |
| Section 3: Choco Pipeline | 10 (slides 25–34) | 20–25 min |
| Section 4: Bigger Picture | 7 (slides 35–41) | 10–15 min |
| **Total** | **41 slides** | **~85 min + Q&A** |

## Appendix: Demo Checkpoints

These are the moments where you switch from slides to the live demo environment:

1. **Slide 20** — Open GitHub PR showing Semgrep SARIF annotations in the PowerShell module PR
2. **Slide 21** — Show the SBOM artifact downloaded from the Actions run
3. **Slide 22** — Show the Grype results tab in Code Scanning
4. **Slide 23** — Show the provenance attestation JSON artifact
5. **Slide 32** — Open GitHub PR showing Chocolatey pipeline findings
6. **Slide 39** — Show the repo on screen (repo tour, README, actions/ directory)

Have screenshots ready for each checkpoint as fallback.
