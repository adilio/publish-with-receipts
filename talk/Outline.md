# OUTLINE.md — Provenance Before Publish

**Talk Title:** Provenance Before Publish: Securing PowerShell and Chocolatey Supply Chains from the Pipeline Out  
**Event:** Chocolatey Fest 2026  
**Duration:** 90 minutes  
**Format:** Technical breakout session (talk with live demos and pre-built screenshots as fallback)  
**Companion Repo:** [publish-with-receipts](https://github.com/adilio/publish-with-receipts)

-----

## High-Level Structure

|Section|Title                                                            |Time     |Format                      |
|-------|-----------------------------------------------------------------|---------|----------------------------|
|1      |The Problem Space: Supply Chain Threats You’re Already Exposed To|20-25 min|Slides + real-world examples|
|2      |PowerShell Module Pipeline: Building the Guardrails              |20-25 min|Live demo + slides          |
|3      |Chocolatey Package Pipeline: A Different Risk Profile            |20-25 min|Live demo + slides          |
|4      |Connecting to the Bigger Picture + Wrap-up                       |10-15 min|Slides + Q&A                |

-----

## Section 1: The Problem Space (20-25 minutes)

### Purpose

Educate the audience on the specific supply chain threat vectors that affect PowerShell modules and Chocolatey packages. Build the mental model that makes the rest of the talk land. This section should leave people slightly uncomfortable about their current pipelines before we show them how to fix it.

### 1.1 — Opening: What “Supply Chain Security” Means Here (3-4 min)

**Key message:** Most supply chain security content is aimed at container ecosystems, npm, PyPI, or enterprise SBOM mandates. This talk is specifically about the Windows automation world: PowerShell modules published to PSGallery and Chocolatey packages published to community or internal repos.

**Talking points:**

- Supply chain security has become a buzzword. For a lot of Windows-focused engineers, the conversation feels like it’s happening in a different ecosystem (containers, Kubernetes, OCI registries).
- But PowerShell modules and Chocolatey packages have their own supply chain, and it’s got some unique characteristics that make it worth examining separately.
- Frame the registry vs. pipeline distinction early: most security controls (signing, moderation, virus scanning) happen at the registry. This talk is about what happens before your artifact reaches the registry. That’s the gap.
- Introduce the phrase “provenance before publish” as the thesis: if you’re going to publish something, you should be able to show what was in it, what you checked, and what the tools found. Receipts, not just a green checkmark.

**Slide ideas:**

- Simple diagram: Source Code → Build/CI Pipeline → [THIS IS THE GAP] → Registry → Consumer
- The gap between “CI passed” and “registry accepted it” is where most risk lives for individual package maintainers.

### 1.2 — Threat Vector Deep Dive (15-18 min)

Walk through each threat vector with a mix of real-world incidents and generic examples. The goal is to make each one feel tangible, not theoretical.

#### 1.2.1 — Typosquatting (3-4 min)

**What it is:** Registering packages with names designed to catch common misspellings or naming convention confusion.

**Real-world example:**

- The Aqua Security / Aqua Nautilus research (2023) on PowerShell Gallery. They demonstrated that PSGallery has no protection against typosquatting, unlike npm which has Moniker rules. They registered `Az.Table` (with a dot) to impersonate the popular `AzTable` module (10M+ downloads). Within hours they received callbacks from production cloud environments at real companies.
- Microsoft acknowledged the issue in late 2022. As of the Aqua report in August 2023, the protections were still not fully implemented. Researchers were able to reproduce the attacks after Microsoft said they were fixed.
- Contrast with npm’s approach: npm has explicit Moniker rules that prevent registering names like `reactnative` when `react-native` already exists. PSGallery has no equivalent.

**Why it matters for this audience:**

- Azure-related modules follow the `Az.<name>` convention but it’s not enforced. An attacker can register `Az.Tabl` or `Az.Table` and impersonate legitimate Microsoft modules.
- Chocolatey packages have a similar risk surface. Community repo moderation catches some of this, but internal repos typically have no naming validation at all.
- In automated environments (scripts, CI pipelines), a typo in a module name gets installed silently. There’s no human looking at the download screen.

**What the pipeline can do:** Naming validation checks that compare package names against known registries for similarity. We’ll build this in Section 3.

#### 1.2.2 — Download-and-Execute Patterns (3-4 min)

**What it is:** Install scripts that fetch binaries from external URLs and execute them, often without any integrity verification.

**Examples:**

- Common pattern in Chocolatey `chocolateyInstall.ps1` scripts: `Install-ChocolateyPackage` with a URL pointing to an external binary. If checksums aren’t enforced, the binary could be swapped out by a compromised CDN, a MITM attack, or a changed URL.
- PowerShell modules that use `Invoke-WebRequest` or `Invoke-RestMethod` in their initialization or exported functions to pull and execute remote code.
- The Serpent malware campaign (2022, documented by Proofpoint): targeted French organizations using macro-enabled Word documents that installed Chocolatey legitimately, then used it to install Python and pip, then deployed a backdoor via steganography. Chocolatey itself wasn’t compromised, but the campaign demonstrated how legitimate package managers become part of an attack chain when the surrounding pipeline doesn’t validate what’s happening.

**Why it matters for this audience:**

- Chocolatey’s docs explicitly note that checksums are required for non-secure (HTTP/FTP) downloads as of v0.10.0, but many packages still have missing or incorrect checksums.
- Chocolatey community moderation involves human review of package scripts, but this is a best-effort process. Internal repos typically have no review at all.
- The pattern is so normalized that people stop questioning it. “Of course the install script downloads an exe. That’s how Chocolatey works.” But *which* exe, from *where*, and can you prove it’s the same one the maintainer tested?

**What the pipeline can do:** Pattern detection in install scripts (Semgrep rules), checksum enforcement, and SBOM generation for downloaded binaries. We’ll build this in Sections 2 and 3.

#### 1.2.3 — Floating Dependencies (2-3 min)

**What it is:** Depending on a module or package version without pinning it, so the resolved version can change between builds without any code change on your side.

**Examples:**

- PowerShell module manifests (`*.psd1`) that specify `RequiredModules` without version constraints, or with loose constraints like `ModuleVersion = '1.0'` (minimum, not exact).
- Chocolatey packages that depend on other packages without version pinning in the `.nuspec` file.
- The general class of dependency confusion / substitution attacks: if your pipeline resolves dependencies at build time from a public registry, and you haven’t pinned versions, an attacker can publish a higher version number and your pipeline will pull it automatically.

**Why it matters for this audience:**

- In enterprise environments, PowerShell modules are often installed as part of deployment pipelines (Azure, AWS). A floating dependency means your Tuesday deployment might pull a different version of a module than your Monday deployment, with no change in your own code.
- This is particularly dangerous in Chocolatey because package dependencies can trigger additional install scripts with elevated privileges.

**What the pipeline can do:** SBOM generation captures the exact resolved versions at build time. Dependency pinning checks can flag unpinned versions in manifests and nuspecs.

#### 1.2.4 — Secret Leakage (2-3 min)

**What it is:** API keys, tokens, credentials, and other secrets committed to module source code or package scripts.

**Examples:**

- The Aqua Nautilus research also found that PSGallery allows unlisted packages to remain accessible via the API. Researchers discovered publishers who accidentally uploaded `.git/config` files containing GitHub API keys, and publishing scripts containing PSGallery API keys.
- Common patterns: hardcoded API keys in PowerShell module functions, connection strings in test files that get included in the published module, `.env` files or config files with real credentials included in Chocolatey package tools directories.

**Why it matters for this audience:**

- PowerShell modules often interact with cloud APIs (Azure, AWS). The temptation to hardcode a key “just for testing” is constant.
- Chocolatey package scripts sometimes contain internal URLs, share paths, or credentials for accessing internal binary repositories. These end up published to the community repo by accident.
- Once published, even if you unlist the package, the data may still be accessible (as Aqua demonstrated with PSGallery).

**What the pipeline can do:** Semgrep rules for secret patterns, plus dedicated secret scanning. We’ll use Semgrep with custom rules in Section 2.

#### 1.2.5 — Unverified External Binaries (2-3 min)

**What it is:** Packages that include or download third-party executables without verifying their integrity against a known-good hash.

**Examples:**

- Chocolatey packages that embed `.exe` or `.msi` files in the `tools/` directory without a corresponding `VERIFICATION.txt` that includes checksums and source URLs.
- Packages that download binaries from external sources where the checksum in the install script doesn’t match the actual file, or where checksums are simply missing.
- Several Chocolatey CVEs relate to insecure permissions on installed directories (e.g., `C:\tools\php81`, `C:\tools\Cmder`), which means even if the binary was correct at install time, it can be replaced by a lower-privilege attacker afterward.

**Why it matters for this audience:**

- Chocolatey packages run with elevated privilege by default. If the binary is compromised, it executes as admin.
- The VERIFICATION.txt convention exists in Chocolatey but isn’t programmatically enforced in most pipelines. It’s a human-readable file that humans often don’t read.

**What the pipeline can do:** Automated checksum verification, SBOM generation for all embedded binaries, and validation that VERIFICATION.txt exists and contains the required fields. We’ll build this in Section 3.

### 1.3 — The Mental Model: What Provenance Actually Means (2-3 min)

**Key message:** Transition from “here’s what can go wrong” to “here’s how we think about fixing it.” Introduce provenance as a practical concept, not a spec.

**Talking points:**

- SLSA (Supply-chain Levels for Software Artifacts) is the formal framework here. It defines provenance as verifiable information about software artifacts describing where, when, and how something was produced.
- But you don’t need to adopt the full SLSA spec to get value. The core idea is simple: when you publish a package, you should be able to answer three questions:
1. What’s in this package? (SBOM)
1. What did we check? (Scan results, SARIF)
1. Can we prove it was built from this source, by this pipeline, at this time? (Provenance attestation)
- The rest of this talk is about building a pipeline that generates those three artifacts automatically, for both PowerShell modules and Chocolatey packages.
- Frame the toolchain briefly: PSScriptAnalyzer, Semgrep, Syft, Grype, SARIF, and provenance generation. All free, all open source, all running in GitHub Actions.

**Slide ideas:**

- Three questions diagram: SBOM answers “what’s in it,” SARIF answers “what did we check,” Provenance answers “can we prove it.”
- Brief toolchain overview slide showing each tool and its role (this will be referenced throughout Sections 2 and 3).

-----

## Section 2: PowerShell Module Pipeline (20-25 minutes)

### Purpose

Walk through the GitHub Actions pipeline for the example PowerShell module. This is the first live demo section. Show the pipeline running, explain each step, and demonstrate what the outputs look like in a real PR.

### 2.1 — Tour the Example Module (3-4 min)

**What to show:** Walk through the `examples/powershell-module/` directory in the `publish-with-receipts` repo.

**Key files to highlight:**

- `ExampleModule.psd1` — The module manifest. Point out intentional issues:
  - Missing or incomplete metadata fields (Author, Description, ProjectUri)
  - `RequiredModules` with unpinned versions
  - `ScriptsToProcess` usage (this is the same mechanism Aqua used in their typosquatting PoC)
- `ExampleModule.psm1` — The root module file
- `Public/Invoke-SafeFunction.ps1` — A clean, well-written exported function (the baseline)
- `Public/Invoke-UnsafeFunction.ps1` — An exported function with intentional anti-patterns:
  - `Invoke-WebRequest` downloading and executing a remote script
  - A hardcoded API key in a variable
  - No input validation on URL parameters
- `tests/ExampleModule.Tests.ps1` — Basic Pester tests (show that traditional testing alone doesn’t catch supply chain issues)

**Talking point:** These anti-patterns aren’t cartoonish. They’re the kind of thing that ships when you’re moving fast and your CI only runs Pester tests. The module works. The tests pass. But there’s no supply chain visibility.

### 2.2 — The GitHub Actions Workflow (12-15 min)

**What to show:** Walk through `.github/workflows/powershell-supply-chain.yml` step by step. For each step, explain what it does, show the output, and explain why it matters.

**Demo format:** Live walkthrough of a PR that modifies the example module. Show the pipeline running in GitHub Actions, then switch to the PR view to show SARIF annotations. Have screenshots as fallback if the live demo has issues.

#### Step 1: PSScriptAnalyzer (3-4 min)

**What it does:** Static analysis for PowerShell scripts. Checks for script quality, unsafe patterns, and best practice violations.

**Configuration details:**

- Custom rule configuration that flags specific patterns:
  - `Invoke-Expression` usage
  - `Invoke-WebRequest` / `Invoke-RestMethod` without certificate validation
  - Missing `[CmdletBinding()]` and parameter validation
  - Use of `Write-Host` instead of `Write-Output` / `Write-Verbose`
- Output format: SARIF, uploaded to GitHub’s code scanning

**What to show in the demo:**

- PSScriptAnalyzer findings surfaced directly in the PR diff as annotations
- How the severity levels map to PR blocking vs. warning
- The difference between a PSScriptAnalyzer finding (code quality) and what Semgrep catches (security patterns)

**Talking point:** PSScriptAnalyzer is great for code quality but it wasn’t designed for supply chain security. It’ll catch `Invoke-Expression` as a best practice issue, but it won’t catch a hardcoded API key or a download-and-execute pattern that uses approved cmdlets. That’s where Semgrep comes in.

#### Step 2: Semgrep with Custom Rules (3-4 min)

**What it does:** Pattern-based code scanning using custom rules written specifically for PowerShell supply chain patterns.

**Custom rules to demonstrate** (from `semgrep-rules/powershell-unsafe-patterns.yml`):

- **Download-and-execute detection:** Matches patterns where `Invoke-WebRequest` or `Invoke-RestMethod` results are piped to `Invoke-Expression` or saved and executed
- **Hardcoded secrets:** Matches common patterns for API keys, tokens, connection strings, passwords assigned to variables
- **Unsafe TLS/certificate handling:** Matches `[System.Net.ServicePointManager]::ServerCertificateValidationCallback` overrides
- **Base64 encoded command execution:** Matches `-EncodedCommand` patterns and manual base64 decode-and-execute

**What to show in the demo:**

- Semgrep catching the hardcoded API key in `Invoke-UnsafeFunction.ps1`
- Semgrep catching the download-and-execute pattern
- SARIF output with clear descriptions of what was found and why it matters
- How custom rules are structured (briefly show the YAML rule format)

**Talking point:** Off-the-shelf Semgrep rules don’t cover PowerShell well. The custom rules in this repo are designed for the specific patterns that show up in PowerShell modules and Chocolatey packages. They’re in the repo. Fork them, extend them, add your own.

#### Step 3: SBOM Generation with Syft (2-3 min)

**What it does:** Generates a Software Bill of Materials listing everything in the module, including declared dependencies and their versions.

**Configuration details:**

- Syft configured to scan the module directory
- Output format: CycloneDX JSON (widely supported by downstream tools)
- SBOM captures: module files, declared dependencies from the manifest, and resolved versions

**What to show in the demo:**

- The generated SBOM artifact
- How declared dependencies and their versions appear in the SBOM
- The difference between what the manifest says and what’s actually resolved (if there are floating versions)

**Talking point:** An SBOM at build time is your baseline. It’s the answer to “what was in this package when we built it.” If something changes later (a dependency is compromised, a CVE is published), you can trace it back to which builds are affected.

#### Step 4: Vulnerability Scanning with Grype (2-3 min)

**What it does:** Takes the SBOM from Syft and checks it against known vulnerability databases.

**Configuration details:**

- Grype consumes the CycloneDX SBOM from the previous step
- Output format: SARIF (uploaded to GitHub code scanning) and JSON (for downstream processing)
- Severity thresholds: configurable per-project (demo shows warning on medium, fail on critical)

**What to show in the demo:**

- Grype results in the PR view
- How a known vulnerability in a dependency surfaces as a PR annotation
- The JSON output that enterprise tools can ingest

**Talking point:** Grype isn’t going to catch everything. It only knows about published CVEs. But it catches the known stuff automatically, and that’s a baseline you should have. The SBOM + Grype combination means you can also retroactively check old builds when new CVEs are published.

#### Step 5: Provenance Generation (2-3 min)

**What it does:** Generates a provenance attestation that records what was built, from what source, by which pipeline, at what time.

**Configuration details:**

- Uses GitHub’s attestation capabilities or the SLSA GitHub generator (depending on complexity level for the audience)
- Provenance document includes: source repo, commit SHA, workflow reference, build timestamp, artifact hashes
- Stored as a build artifact alongside the SBOM and SARIF results

**What to show in the demo:**

- The provenance document structure
- How it ties back to the specific commit and PR
- How a consumer could verify that the published module matches what the pipeline built

**Talking point:** This is the receipt. The SBOM tells you what’s in it. The SARIF tells you what you checked. The provenance tells you *when*, *where*, and *how* it was built, and ties it all to a specific commit. Together, they answer the three questions from Section 1.

### 2.3 — Design Decisions and Tradeoffs (2-3 min)

**Talking points:**

- Why these tools and not others? PSScriptAnalyzer is the standard for PowerShell. Semgrep because it’s free for custom rules and supports SARIF. Syft and Grype because they’re the most widely adopted OSS SBOM/scanning pair and they work well together.
- What about ScriptSigner / code signing? Code signing is a registry-level control. It tells you who signed it, not what’s in it. Both are needed. This pipeline handles the “what’s in it” side.
- SARIF as the common output format: it integrates natively with GitHub’s code scanning, so findings show up in PRs without any extra tooling. It’s also consumed by most SCA and security platforms.
- This pipeline is designed to be non-blocking by default. Findings surface as annotations and warnings. You choose what blocks a merge and what’s informational. The goal is visibility first, enforcement second.

-----

## Section 3: Chocolatey Package Pipeline (20-25 minutes)

### Purpose

Apply the same provenance model to Chocolatey packages, but frame it as a distinct risk profile. Chocolatey packages are not just “PowerShell modules in a different wrapper.” They execute with elevated privilege, download external binaries, and run install scripts that shape how software lands on systems.

### 3.1 — What Makes Chocolatey Different (3-4 min)

**Key message:** Everything from Section 2 applies, but Chocolatey packages have additional characteristics that make supply chain security harder and more important.

**Talking points:**

- **Elevated privilege by default.** Chocolatey installs to `C:\ProgramData\chocolatey` and requires admin rights. Install scripts run as admin. If an install script is compromised, it has full system access.
- **External binary downloads are the norm.** Unlike PowerShell modules (which are mostly script files), Chocolatey packages routinely download `.exe`, `.msi`, and `.zip` files from external URLs. The package is often just a wrapper around an external binary.
- **Install scripts are powerful and under-reviewed.** `chocolateyInstall.ps1` can do essentially anything: modify the registry, create services, change PATH, download and execute arbitrary code. Community repo moderation reviews these scripts, but internal repos typically don’t.
- **The VERIFICATION.txt convention.** Chocolatey has a convention for documenting the source and checksums of embedded binaries, but it’s a human-readable text file, not a machine-enforceable control.

### 3.2 — Tour the Example Chocolatey Package (3-4 min)

**What to show:** Walk through the `examples/chocolatey-package/` directory.

**Key files to highlight:**

- `example-package.nuspec` — The package manifest. Point out intentional issues:
  - Missing or generic metadata (iconUrl, projectUrl, tags)
  - Dependency without version pinning
  - Package name that could potentially conflict with existing packages
- `tools/chocolateyInstall.ps1` — The install script. Point out intentional issues:
  - `Install-ChocolateyPackage` call with an external URL
  - Missing or incorrect checksum
  - Additional `Invoke-WebRequest` call to download a supplementary tool without any verification
  - Modification of system PATH without documentation
- `tools/chocolateyUninstall.ps1` — The uninstall script (basic, but present)
- `tools/VERIFICATION.txt` — Intentionally incomplete (missing checksum, vague source URL)

**Talking point:** This package works. `choco install` succeeds. The software installs. But the pipeline has no idea what binary was downloaded, whether it matches what the maintainer tested, or what the install script actually did beyond the happy path. That’s the gap we’re closing.

### 3.3 — The GitHub Actions Workflow (12-15 min)

**What to show:** Walk through `.github/workflows/chocolatey-supply-chain.yml`. Highlight the steps that are the same as the PowerShell pipeline and the steps that are Chocolatey-specific.

#### Step 1: Package Naming Validation (2-3 min)

**What it does:** Checks the package name in the `.nuspec` against known Chocolatey community repo packages for similarity/conflicts.

**Implementation details:**

- Queries the Chocolatey community repository API for packages with similar names
- Uses string similarity matching (Levenshtein distance or similar) to flag potential conflicts
- Checks against common naming patterns and reserved prefixes

**What to show in the demo:**

- A package name that triggers a similarity warning
- How the output surfaces in the PR

**Talking point:** This is the typosquatting defense from Section 1, made concrete. It won’t stop a determined attacker publishing to the community repo, but it will catch accidental name collisions in your own pipeline and flag intentional squatting attempts before you publish.

#### Step 2: Checksum and Integrity Verification (2-3 min)

**What it does:** Validates that every external binary referenced in the install script has a corresponding checksum, and that embedded binaries in the `tools/` directory have checksums in VERIFICATION.txt.

**Implementation details:**

- Parses `chocolateyInstall.ps1` to extract URLs and checksums from `Install-ChocolateyPackage` and similar helper calls
- Validates that checksums are present and use strong algorithms (SHA256 or better, not MD5)
- Checks embedded files against VERIFICATION.txt entries
- Downloads the referenced URL and verifies the checksum matches (optional, configurable)

**What to show in the demo:**

- A missing checksum flagged as an error
- A weak checksum algorithm flagged as a warning
- A VERIFICATION.txt entry that doesn’t match the actual embedded file

**Talking point:** Chocolatey already requires checksums for non-secure downloads, but this pipeline extends that to all downloads and embedded binaries, and it does it at build time, not install time. The difference matters: if the checksum fails at install time, the damage is already in progress.

#### Step 3: Install Script Analysis (2-3 min)

**What it does:** Scans `chocolateyInstall.ps1` and `chocolateyUninstall.ps1` using Semgrep with Chocolatey-specific rules.

**Custom rules to demonstrate** (from `semgrep-rules/chocolatey-install-patterns.yml`):

- **Unverified external downloads:** `Invoke-WebRequest` calls outside of Chocolatey’s built-in helpers (which handle checksums)
- **System-modifying actions without documentation:** Registry writes, service creation, PATH modification
- **Hardcoded internal URLs or credentials:** Share paths, API keys, internal domain references that shouldn’t be in a public package
- **Execution of downloaded content:** Patterns where downloaded files are immediately executed without verification
- **Use of `-IgnoredArguments` without `$env:ChocolateyPackageParameters`:** Indicates the script isn’t handling package parameters properly

**What to show in the demo:**

- Semgrep catching the unverified download in the example install script
- A rule that catches PATH modification without corresponding uninstall cleanup
- SARIF output specific to Chocolatey patterns

**Talking point:** These rules are opinionated. Not every finding is a security issue. Some are maintainability or hygiene concerns. But in a Chocolatey context, where install scripts run as admin, the bar for “this is fine” should be higher than it usually is.

#### Step 4: SBOM Generation for the Full Package (2-3 min)

**What it does:** Generates an SBOM that covers not just the package metadata, but also embedded binaries and declared external dependencies.

**Implementation details:**

- Syft scans the full package directory including `tools/` contents
- Additional metadata extracted from the `.nuspec` (dependencies, version, author)
- For embedded binaries: file hashes are recorded even if Syft can’t identify them by name
- Output: CycloneDX JSON, same format as the PowerShell pipeline for consistency

**What to show in the demo:**

- An SBOM that includes both the Chocolatey package metadata and the embedded binary
- How the SBOM captures the declared dependency chain
- The difference between a Chocolatey SBOM (which includes binaries) and a PowerShell module SBOM (which is mostly scripts and manifests)

#### Step 5: Vulnerability Scan + Provenance (2-3 min)

**What it does:** Same as Section 2 — Grype against the SBOM, then provenance generation.

**What to show in the demo:**

- Grype results for the Chocolatey package (including any findings against the embedded binary if it’s a known package)
- Provenance attestation for the Chocolatey build

**Talking point:** The provenance for a Chocolatey package is especially valuable because the package is often a thin wrapper around an external binary. The provenance ties together: which binary was downloaded, from where, what its hash was, what the SBOM contained, what the scan found, and which commit and pipeline produced it. That’s the full chain.

### 3.4 — What the PowerShell Pipeline Wouldn’t Catch (2-3 min)

**Key message:** This is why Chocolatey packages need their own pipeline, not just a copy of the PowerShell one.

**Talking points:**

- The generic Semgrep rules from Section 2 would catch some patterns (hardcoded secrets, basic download-and-execute), but they’d miss Chocolatey-specific issues like missing checksums in `Install-ChocolateyPackage` calls, incomplete VERIFICATION.txt, and install scripts that modify system state.
- The naming validation is registry-specific. PSGallery and the Chocolatey community repo have different naming conventions and different APIs.
- The SBOM for a Chocolatey package needs to account for embedded binaries in a way that a PowerShell module SBOM doesn’t.
- Show a side-by-side of the same issue caught (or missed) by each pipeline to make the point concrete.

-----

## Section 4: Connecting to the Bigger Picture + Wrap-up (10-15 minutes)

### Purpose

Show how the pipeline outputs connect to enterprise security tooling, make the “take it home” pitch, and handle Q&A.

### 4.1 — From Pipeline to Platform (5-7 min)

**Key message:** The pipeline produces artifacts (SBOMs, SARIF, provenance). Those artifacts are useful on their own, but they become more powerful when connected to platforms that add runtime context.

**Talking points:**

#### GitHub-Native Integration

- SARIF uploads to GitHub Code Scanning. Findings appear in the Security tab and in PR annotations. This is the zero-cost, zero-setup integration.
- Dependabot can consume some of the same dependency information, but it operates at the repo level, not the package level. The SBOM from this pipeline is more specific.
- GitHub Artifact Attestations (relatively new) provide a native way to attach provenance to releases.

#### SCA Platforms (Generic)

- Traditional SCA tools (Snyk, Mend/WhiteSource, Black Duck, etc.) can ingest CycloneDX SBOMs and SARIF results.
- The value add: continuous monitoring. The pipeline runs at build time, but SCA platforms can alert when new CVEs are published that affect your previously-built packages.
- Most enterprise teams already have an SCA tool. The pipeline’s outputs are designed to feed into whatever they’re using. You don’t have to replace your existing tooling; you just give it better inputs.

#### Cloud Security and Runtime Context (Wiz as example)

- Here’s where it gets interesting for organizations operating at scale. The SBOM generated at build time can be correlated against deployed workloads.
- A vulnerability finding from Grype might be critical or irrelevant depending on context: is the affected package deployed? Is it internet-facing? Is it running with elevated privileges? Is it in a production environment or a dev sandbox?
- Platforms like Wiz provide this runtime context. They can ingest SBOMs and correlate software findings with actual exposure, identity risk, and network reachability.
- This is the difference between a vulnerability list and risk context. The pipeline creates the provenance. The cloud security platform tells you which findings actually matter in your environment.
- You can also integrate CSPM (Cloud Security Posture Management) platforms generically for the same purpose.

**Talking point:** The pipeline is the starting point, not the end state. For a solo maintainer, the GitHub-native integration (SARIF in PRs, artifact attestations) might be enough. For an enterprise team, the same outputs feed into a stack that provides continuous monitoring and contextual risk evaluation. Same pipeline, different ceiling.

**Slide ideas:**

- Diagram showing pipeline outputs flowing into three tiers: GitHub-native (free), SCA platforms (existing enterprise tooling), Cloud security / Wiz (runtime context layer)
- NOT a product pitch slide. Frame it as “here’s the architecture” with Wiz as one example in the category.

### 4.2 — Realistic Adoption Advice (2-3 min)

**Talking points:**

- Don’t try to adopt everything at once. Start with one pipeline (PowerShell or Chocolatey, whichever is your bigger surface area).
- Start non-blocking. Surface findings as warnings. Let your team see what the tools catch before you start failing builds.
- The composite actions in the repo are designed to be adopted individually. You can add just PSScriptAnalyzer and Semgrep today, then add SBOM generation next month, then add provenance when you’re ready.
- Expect false positives. Tune the rules. The Semgrep rules in the repo are a starting point, not gospel. Every team’s codebase has patterns that are fine in context but look suspicious to a generic scanner.
- The docs folder in the repo covers the “why” behind every tool choice and rule. If you need to justify this to your team or your manager, the rationale is written down.

### 4.3 — The Repo and What to Do Next (2-3 min)

**What to show:** The `publish-with-receipts` repo on screen.

**Talking points:**

- Here’s the repo. Everything you saw today is in it.
- The `examples/` directory has the intentionally flawed PowerShell module and Chocolatey package. Fork it, run the pipeline, see the findings.
- The `actions/` directory has the composite actions. Pull them into your own repos individually.
- The `semgrep-rules/` directory has the custom rules. Extend them for your own patterns.
- The `docs/` directory has the threat model, tooling decisions, and enterprise integration guide. You don’t need to have been at this talk to use the repo.
- Issues and PRs welcome. If you’ve got a threat vector that isn’t covered or a tool that fits better, let’s talk about it.

### 4.4 — Q&A (remaining time, ~5 min)

**Anticipated questions to prepare for:**

- “How does this compare to Chocolatey’s built-in moderation process?” (Answer: complementary, not competing. Moderation is a registry-level control. This is a pipeline-level control that runs before your package reaches the registry.)
- “Can this work with Azure DevOps instead of GitHub Actions?” (Answer: the concepts are the same, the implementation would need porting. The composite actions are GitHub-specific, but the tools (PSScriptAnalyzer, Semgrep, Syft, Grype) all run anywhere.)
- “What about private/internal Chocolatey repositories?” (Answer: this is actually where this pipeline adds the most value, because internal repos typically have zero moderation.)
- “How do you handle legitimate Invoke-WebRequest usage that gets flagged?” (Answer: Semgrep supports inline suppression comments. The approach is flag everything, suppress with justification. The suppression is visible in the PR and in the SARIF results.)
- “Does this slow down CI significantly?” (Answer: depends on package size, but for typical PowerShell modules and Chocolatey packages, the full pipeline adds 2-5 minutes. Most of that is Grype downloading its vulnerability database on first run; it caches after that.)
- “What about signing?” (Answer: signing is orthogonal. This pipeline tells you what’s in the package and what you checked. Signing tells consumers who published it. Both are needed. You can add Authenticode or NuGet signing as an additional pipeline step.)

-----

## Demo Environment Setup Notes

### Prerequisites for Live Demo

- GitHub repo with both workflows configured and running
- A pre-prepared PR branch that modifies the example module and package with new anti-patterns
- The PR should already have one run completed so you can show results immediately, then trigger a new run live if time permits
- Browser tabs pre-loaded: repo overview, PR with annotations, Actions workflow run, SBOM artifact, provenance artifact

### Fallback Plan

- Screenshots of every pipeline step output, every PR annotation, every artifact
- Store screenshots in a `demo-screenshots/` directory (not in the public repo, just on your laptop)
- If GitHub Actions is slow or down, walk through the screenshots and note “this is what it looks like when it runs”
- Have the SARIF JSON, SBOM JSON, and provenance JSON available locally to show in a code editor if the browser-based view isn’t cooperating

### Things to Test Before the Talk

- Run both workflows end to end at least twice in the week before the talk
- Verify SARIF uploads appear in the PR Security tab
- Verify Semgrep rules catch all intended patterns in the example files
- Verify Grype has findings (you may need to include a dependency with a known CVE for demo purposes)
- Test the naming validation action against the Chocolatey community repo API (it should not require authentication for read-only queries)
- Check GitHub Actions runner availability (sometimes there are queue delays on public runners)

-----

## Toolchain Reference

|Tool            |Version to Pin    |Purpose                   |Output Format    |Notes                                                            |
|----------------|------------------|--------------------------|-----------------|-----------------------------------------------------------------|
|PSScriptAnalyzer|Latest stable     |PowerShell static analysis|SARIF            |Install via `Install-Module` in the workflow                     |
|Semgrep         |Latest stable     |Pattern-based scanning    |SARIF            |Use `returntocorp/semgrep-action` or CLI directly                |
|Syft            |Latest stable     |SBOM generation           |CycloneDX JSON   |Use `anchore/sbom-action` or CLI                                 |
|Grype           |Latest stable     |Vulnerability scanning    |SARIF + JSON     |Use `anchore/scan-action` or CLI, consumes Syft SBOM             |
|SLSA Provenance |Per slsa-framework|Provenance attestation    |In-toto/SLSA JSON|Use `slsa-framework/slsa-github-generator` or GitHub Attestations|

-----

## File Deliverables Needed for the Repo

Based on this outline, the following files need to be created:

### Examples

- [ ] `examples/powershell-module/ExampleModule/ExampleModule.psd1`
- [ ] `examples/powershell-module/ExampleModule/ExampleModule.psm1`
- [ ] `examples/powershell-module/ExampleModule/Public/Invoke-SafeFunction.ps1`
- [ ] `examples/powershell-module/ExampleModule/Public/Invoke-UnsafeFunction.ps1`
- [ ] `examples/powershell-module/tests/ExampleModule.Tests.ps1`
- [ ] `examples/chocolatey-package/example-package.nuspec`
- [ ] `examples/chocolatey-package/tools/chocolateyInstall.ps1`
- [ ] `examples/chocolatey-package/tools/chocolateyUninstall.ps1`
- [ ] `examples/chocolatey-package/tools/VERIFICATION.txt`

### GitHub Actions Workflows

- [ ] `.github/workflows/powershell-supply-chain.yml`
- [ ] `.github/workflows/chocolatey-supply-chain.yml`

### Reusable Composite Actions

- [ ] `actions/ps-script-analysis/action.yml`
- [ ] `actions/semgrep-scan/action.yml`
- [ ] `actions/sbom-generate/action.yml`
- [ ] `actions/vulnerability-scan/action.yml`
- [ ] `actions/choco-naming-validation/action.yml`
- [ ] `actions/choco-integrity-check/action.yml`
- [ ] `actions/provenance-generate/action.yml`

### Semgrep Rules

- [ ] `semgrep-rules/powershell-unsafe-patterns.yml`
- [ ] `semgrep-rules/chocolatey-install-patterns.yml`

### Documentation

- [ ] `docs/threat-model.md`
- [ ] `docs/tooling-decisions.md`
- [ ] `docs/enterprise-integration.md`

### Root

- [x] `README.md`
- [x] `OUTLINE.md`
- [ ] `LICENSE`
