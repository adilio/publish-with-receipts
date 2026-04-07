# Talk Track — Provenance Before Publish

**Event:** Chocolatey Fest 2026
**Duration:** 90 minutes
**Format:** Technical breakout — slides, live demo, Q&A

Each section below maps to a slide in `presentation.md`. The talk track is a speaker script: what to say, what to click, what to watch for. Approximate timing is noted per section.

---

## Slide 1 — Title

*Walk to the podium. Let the title sit for a few seconds before speaking.*

"Thanks for coming. This talk is about supply chain security — but I want to be specific about which supply chain, because most of the conversation in this space is happening in a different ecosystem than the one you probably work in.

Most supply chain security content is aimed at containers, npm, PyPI, or enterprise SBOM mandates driven by executive orders. That's all valuable. But if you're in this room, you're probably working in the Windows automation world: PowerShell modules published to PSGallery, Chocolatey packages published to community or internal repos. And that world has its own supply chain, with its own risk profile.

That's what we're here to talk about. The repo is up on screen. Everything you see today is in it. You can follow along, fork it, and run it yourself."

---

## Slide 2 — What We're Covering

*Read through the four sections briefly — this is the roadmap, not the content.*

"Here's the structure. We're going to start with the problem space — six real threat vectors that affect PowerShell and Chocolatey packages. Then we'll build a pipeline for a PowerShell module, step by step. Then we'll do the same for a Chocolatey package, and explain why it needs a different approach. And we'll close with how this connects to larger security platforms if you're operating at enterprise scale.

We've got 90 minutes. There's a live demo in Sections 2 and 3. If the demo gods cooperate, great. If not, I have screenshots and I'll walk you through everything the same way."

---

## Slide 3 — This Talk Is For You If...

"Raise your hand if you maintain a PowerShell module on PSGallery."

*Pause.*

"Keep it up if you maintain Chocolatey packages — community repo, internal repo, or both."

*Pause.*

"Now keep it up if your CI pipeline does something more than run Pester tests or `choco pack` and call it done."

*Most hands will go down.*

"That gap — between 'the tests passed' and 'I know what's actually in this package and what I checked' — that's what we're closing today.

And if you've never seen an SBOM generated from your own package: by the end of this talk, you'll have a pipeline that produces one on every push."

---

## Slide 4 — The Gap

*Point to the diagram.*

"Here's the problem space in one picture. You write code. You run CI. CI passes. The package goes to a registry. Consumers install it.

Most security controls — signing, moderation, virus scanning — happen at the registry level. That matters. But it assumes the artifact arriving at the registry is already trustworthy.

The gap is right here, between your CI pipeline and the registry. For most individual package maintainers, this gap is empty. There's no SBOM, no vulnerability scan, no provenance attestation. There's a green checkmark that says the tests ran.

The question I want you to leave with is: what would it take to fill that gap? Because it's not as complicated or expensive as it sounds."

---

## Slide 5 — The Thesis

"Here's the core idea. Before you publish a package, you should be able to answer three questions.

What's in this package? That's your SBOM — a Software Bill of Materials. A machine-readable inventory of everything in the package and its dependencies at build time.

What did you check? That's your scan results — in SARIF format, which GitHub and most security platforms understand natively. PSScriptAnalyzer, Semgrep, Grype.

Can you prove when and how it was built? That's your provenance attestation — a document that ties the artifact back to a specific commit, a specific pipeline run, and a specific timestamp.

Together, these are your receipts. Not just a green checkmark. Actual evidence. The rest of this talk is about generating those three artifacts automatically, on every push."

---

## Slide 6 — Section 1: The Problem Space

*Section break. Take a breath.*

"Let's talk about the threats. I want to walk through six specific vectors that affect PowerShell and Chocolatey packages. Each one has real incidents behind it — not hypotheticals."

---

## Slide 7 — Six Threats

*Read through the list.*

"Six threats. Typosquatting. Download-and-execute. Floating dependencies. Secret leakage. Unverified binaries. Unsafe install patterns.

Each one has real incidents. Each one is detectable with the right pipeline. Let's go through them."

---

## Slide 8 — Threat 1: Typosquatting

"PSGallery has no moniker rules. npm has explicit protections that prevent you from registering `reactnative` when `react-native` already exists. PSGallery has nothing equivalent.

Aqua Nautilus demonstrated this in 2023. They registered `Az.Table` — with a dot — to impersonate the popular `AzTable` module, which has over 10 million downloads. Within hours, they received callbacks from real production Azure environments at real companies. Not test environments. Production.

Microsoft acknowledged the issue in late 2022. As of the Aqua report in August 2023, the protections were still not fully implemented. They were able to reproduce the attack after Microsoft said it was fixed.

The pipeline defense here is naming validation at build time. Before you publish a package, check whether a similar name already exists in the registry. We'll build this in Section 3 for Chocolatey."

---

## Slide 9 — Threat 2: Download-and-Execute

*Gesture at the code.*

"This pattern is everywhere. In PowerShell modules — you fetch content from a URL and pass it to `Invoke-Expression`. In Chocolatey install scripts — `Install-ChocolateyPackage` with a URL and no checksum.

The pattern is so normalized that people stop questioning it. 'Of course the install script downloads an exe. That's how Chocolatey works.' But which exe? From where? And can you prove it's the same one the maintainer tested on Monday — and not something different that replaced it on Wednesday after the CDN was compromised?

The Serpent malware campaign in 2022 is the case study here. Proofpoint documented a campaign targeting French organizations that used Chocolatey legitimately — it installed Python, installed pip — and then deployed a backdoor via steganography. Chocolatey wasn't compromised. But the pipeline around it had no idea what was actually being executed.

The detection is: pattern matching on download-execute chains, checksum enforcement on external downloads, and SBOM generation for anything that lands in the package."

---

## Slide 10 — Threat 3: Floating Dependencies

*Point at the code block.*

"This is the quiet one. No dramatic incident. Just: different version resolved Monday versus Tuesday, with no change in your code.

PowerShell module manifests can specify `ModuleVersion` in `RequiredModules`, which is a *minimum* version, not an exact one. So when someone installs your module, they might get a different version of `Az.Accounts` than you tested with, depending on what's published at install time.

Chocolatey package dependencies in `.nuspec` files have the same issue if version ranges aren't pinned.

The downstream risk is significant. In enterprise environments, PowerShell modules are often installed as part of automated deployment pipelines. A floating dependency means your Tuesday deployment can behave differently than your Monday deployment, with no code change on your end. And in Chocolatey, because package dependencies can trigger additional install scripts with elevated privilege, you might not even know what ran."

---

## Slide 11 — Threat 4: Secret Leakage

"These examples look cartoonish but they're based on real findings.

Aqua Nautilus, in the same 2023 research, found publishers who accidentally uploaded `.git/config` files containing GitHub API keys, and publishing scripts containing PSGallery API keys — in unlisted packages. Unlisted means they thought they'd removed them. But PSGallery's API still served the content.

The pattern is: someone hardcodes a key 'just for testing,' forgets to remove it before publishing, and now it's out there. And because the PSGallery API is public, even a package that's been unlisted is still accessible if you know the URL.

Semgrep with custom rules catches this at build time. We'll walk through the specific rule patterns in Section 2."

---

## Slide 12 — Threat 5: Unverified Binaries

"Chocolatey has a convention called VERIFICATION.txt. The idea is that any package that embeds or downloads a binary should document its source URL and checksum in that file. It's a good convention.

It's also completely unenforced. VERIFICATION.txt is a human-readable text file. There's no tooling that checks whether the checksums in it are correct, whether the file is present at all, or whether it was updated when the binary changed.

Chocolatey packages run as admin by default. If the binary is compromised — whether at the source, in transit, or because someone swapped it out — it executes with full system access.

The pipeline defense is automated checksum verification and SBOM generation for embedded binaries. If you can't prove what binary is in the package and where it came from, the pipeline surfaces that."

---

## Slide 13 — Threat 6: Unsafe Install Patterns

"Install scripts are powerful. They run as admin. They can write to the registry, create services, modify PATH, download and execute additional content. This is by design — it's how Chocolatey works.

The problem is under-review. Community repo moderation includes human review of install scripts, which catches a lot. Internal repos typically have no review at all.

The example on screen — a PATH modification — is a real pattern from internal packages. The PATH gets modified. There's no corresponding cleanup in `chocolateyUninstall.ps1`. Six months later, someone uninstalls the package and the PATH entry stays. Nobody knows why things are slightly broken.

The Semgrep rules in this repo flag: registry writes, service creation, PATH modification, and any of these without corresponding documentation or uninstall cleanup. Not every finding is a security issue, but in a context where the script runs as admin, the bar for 'this is fine' should be higher than usual."

---

## Slide 14 — Section 2: PowerShell Module Pipeline

*Section break.*

"Now let's build the pipeline. We'll start with the PowerShell side.

I'm going to walk through the example module in the repo, then show each step of the GitHub Actions workflow. I'll be running this live — if something takes longer than expected I'll move to screenshots and keep going."

*Switch to browser. Navigate to `examples/powershell-module/ExampleModule/` in the repo.*

---

## Slide 15 — The Example Module

*Walk through the files in the browser while talking.*

"The example module is intentionally flawed. Not cartoonishly broken — the kind of thing that ships when you're moving fast.

`ExampleModule.psd1` — the manifest. It has a floating dependency in `RequiredModules` and uses `ScriptsToProcess`, which is the same mechanism Aqua used in their typosquatting proof of concept.

`Invoke-UnsafeFunction.ps1` — an exported function with two issues: a download-and-execute pattern, and a hardcoded API key in a variable. This is real code that would pass a Pester test.

And here's the important thing: `ExampleModule.Tests.ps1` — the tests pass. The module loads. The functions export correctly. Traditional CI says green. The supply chain issues are completely invisible to Pester."

---

## Slide 16 — Step 1: PSScriptAnalyzer

*Switch to the Actions workflow or show SARIF results in a PR.*

"Step one is PSScriptAnalyzer. Static analysis for PowerShell. It flags code quality issues, unsafe patterns, and best practice violations.

In this pipeline it's configured to catch `Invoke-Expression` usage, missing `[CmdletBinding()]`, and `Write-Host`. Output is SARIF, which uploads to GitHub Code Scanning and surfaces directly as annotations in the PR diff.

But — and this is important — PSScriptAnalyzer wasn't designed for supply chain security. It'll catch `Invoke-Expression` as a best practice issue, but it won't catch a hardcoded API key, and it won't catch a download-and-execute pattern that uses approved cmdlets. It's the right tool for code quality. It's not the right tool for the patterns we care about most. That's Semgrep."

---

## Slide 17 — Step 2: Semgrep — Custom Rules

"Off-the-shelf Semgrep has poor PowerShell support. The rules in this repo are custom, written specifically for the patterns that show up in PowerShell modules and Chocolatey packages.

Four categories in `powershell-unsafe-patterns.yml`: download-and-execute patterns, hardcoded secrets, TLS certificate validation bypass, and base64-encoded command execution.

Output is SARIF, same as PSScriptAnalyzer. Findings appear in the PR alongside the PSScriptAnalyzer findings. Consumers of the pipeline don't need to know which tool caught what — they just see the annotation in the diff."

---

## Slide 18 — Semgrep Rule Example

*Show the rule structure.*

"Here's what a rule looks like. This one catches `Invoke-WebRequest` results being passed to `Invoke-Expression` — the classic download-and-execute chain.

The pattern is the important part. Semgrep matches on the structure of the code, not just text. It handles variable assignments between the fetch and the execute.

When this fires on a legitimate use case — and it will, sometimes — you add an inline suppression comment with a justification. The suppression shows up in the SARIF output and in PR annotations, so it's visible. You're not hiding it. You're documenting that you reviewed it and it's intentional."

---

## Slide 19 — Step 3: SBOM with Syft

"Step three: Syft generates a Software Bill of Materials for the module directory.

Format is CycloneDX JSON. That's the standard format supported by GitHub, Grype, and most SCA platforms. The SBOM captures declared dependencies, resolved versions, and file inventory.

The timing matters. This SBOM is generated at build time, from the specific state of the module at this commit. It's a snapshot. If a CVE drops tomorrow against one of these dependencies, you can check which builds are affected without re-running every scan. The SBOM is the answer to 'what was in the package on this date.'"

---

## Slide 20 — Step 4: Vulnerability Scan with Grype

"Grype takes the SBOM from the previous step and checks it against the NVD and GitHub Advisory Database.

Output is SARIF — findings in the PR — plus JSON for downstream ingestion. Severity thresholds are configurable. In this demo, medium severity surfaces as a warning. Critical fails the build.

Grype only knows about published CVEs. It won't find a zero-day. But it catches the known stuff automatically at build time, and that's a baseline most teams don't have.

The SBOM plus Grype combination is especially valuable for retroactive checking. When a new CVE is published against a dependency, you can run Grype against the stored SBOM from six months ago and know immediately whether that release was affected — without rebuilding anything."

---

## Slide 21 — Step 5: Provenance

*Point at the JSON block.*

"The last step is provenance generation. This is the receipt.

It records: the source repo, the commit SHA, the workflow reference, the build timestamp, and hashes of the output artifacts. It follows the SLSA in-toto format.

What this gives you is a chain of custody. The SBOM tells you what was in the package. The SARIF tells you what you checked. The provenance ties both of those back to a specific commit and a specific pipeline run. A consumer who receives this package can verify that it matches what the pipeline built, from what source, at what time.

For a solo maintainer, this might feel like overkill. For a team that's audited, or a team publishing modules that run in production Azure environments, this is the difference between 'we think it's fine' and 'here's the evidence.'"

---

## Slide 22 — PowerShell Pipeline — Full Picture

*Let the diagram speak for a moment.*

"Here's the full pipeline end to end. Push or PR triggers it. Five steps. Four artifacts: two SARIF reports in GitHub Code Scanning, one SBOM, one provenance document.

Each step is a composite action. You can adopt them one at a time. You don't have to run the whole pipeline to get value. Add PSScriptAnalyzer today, add Semgrep next month, add the SBOM when you're ready.

Alright — let's talk about Chocolatey."

---

## Slide 23 — Section 3: Chocolatey Package Pipeline

*Section break.*

"Chocolatey packages are not just PowerShell modules in a different wrapper. They have a different risk profile, and that difference is significant enough to warrant a separate pipeline with separate checks."

---

## Slide 24 — What Makes Chocolatey Different

"Four things set Chocolatey packages apart.

Elevated privilege by default. Install scripts run as admin. Full stop.

External binaries are the norm. A Chocolatey package is often just a thin wrapper around an EXE or MSI that gets downloaded at install time. The package itself might be tiny, but the binary it fetches could be anything.

VERIFICATION.txt is convention, not enforcement. Chocolatey has a mechanism for documenting binary sources and checksums. Nobody checks whether it's correct programmatically. It's a text file.

Internal repos have zero moderation. The Chocolatey community repo has human review. Your internal repo probably doesn't. Which means every risk that community moderation catches, you're carrying yourself.

Everything from the PowerShell pipeline applies here — plus these additional checks."

---

## Slide 25 — The Example Package

*Walk through the files briefly in the browser.*

"The example Chocolatey package has three intentional issues across three files.

The nuspec has missing metadata and an unpinned dependency. The install script calls `Install-ChocolateyPackage` with a URL but no checksum, and it modifies PATH without documenting it. VERIFICATION.txt has no checksums and a vague source URL.

Here's what makes this dangerous as a demo: `choco install` succeeds. The software installs. Everything looks fine. There's nothing in the standard output that tells you any of this happened. That's the problem."

---

## Slide 26 — Step 1: Naming Validation

"Before anything else, we check the package name against the Chocolatey community repo.

The action queries the community repo API and runs a Levenshtein distance check — a string similarity algorithm — against existing package names. If your package name is close to an existing one, it flags it.

This is the typosquatting defense from Section 1, operationalized. It won't stop a determined attacker who's already published a malicious package. But it will catch accidental name collisions before you publish, and it will flag potential conflicts during code review rather than after your package is live."

---

## Slide 27 — Step 2: Checksum & Integrity Check

*Show the code block.*

"Step two verifies that every external binary download has a checksum, that the checksum uses a strong algorithm — SHA256 or better, not MD5 — and that VERIFICATION.txt entries match the actual embedded files.

The check parses `chocolateyInstall.ps1` to extract URLs and checksums from `Install-ChocolateyPackage` and similar helper calls. If a checksum is missing, it's an error. If the algorithm is weak, it's a warning. If the VERIFICATION.txt entry doesn't match the embedded file, it's an error.

Chocolatey already requires checksums for non-secure downloads as of v0.10.0. This pipeline extends that enforcement to all downloads and embedded binaries, and it does it at build time. The difference: if this check fails at install time, the damage is already in progress. At build time, you catch it before anyone runs the script."

---

## Slide 28 — Step 3: Install Script Analysis

"Step three is Semgrep with Chocolatey-specific rules from `chocolatey-install-patterns.yml`.

The rules catch four categories: unverified `Invoke-WebRequest` calls outside Chocolatey's built-in helpers, registry writes and service creation without documentation, hardcoded internal URLs or credentials, and PATH modification without corresponding uninstall cleanup.

These rules are opinionated. Some findings are security issues. Some are maintainability concerns. But in a context where install scripts run as admin, the bar for 'this is fine' should be higher.

When a finding is intentional, you suppress it with a justification comment — same as the PowerShell rules. The suppression is visible in the SARIF output."

---

## Slide 29 — Steps 4–5: SBOM + Provenance

"Steps four and five are the same tools as the PowerShell pipeline — Syft, Grype, provenance generation — but the SBOM content is different.

For a Chocolatey package, Syft scans the full package directory including the `tools/` folder. Embedded binaries are included in the SBOM with file hashes even if Syft can't identify them by name. The SBOM captures the declared dependency chain from the nuspec, any embedded binaries, and their resolved versions.

The provenance document for a Chocolatey package is especially valuable because the package is often a wrapper around an external binary. The provenance ties together: binary URL, binary hash, commit SHA, pipeline run, timestamp. That's the full chain from 'who published this' to 'what binary did it actually download.'"

---

## Slide 30 — Section 4: Connecting to the Bigger Picture

*Section break.*

"Last section. We've built the pipelines. Let's talk about where these outputs go and what realistic adoption looks like."

---

## Slide 31 — Three Integration Tiers

"The pipeline produces three types of artifacts: SBOMs, SARIF findings, and provenance. Those artifacts are useful on their own — we've seen that. But they also feed into larger platforms depending on what your team already uses.

Three tiers.

GitHub-native: SARIF uploads to Code Scanning, findings in PR annotations, artifact attestations. Zero cost, zero additional setup. This is the baseline.

SCA platforms — Snyk, Mend, Black Duck, whichever you're using. Most of these can ingest CycloneDX SBOMs and SARIF. The value add is continuous monitoring. The pipeline runs at build time. SCA platforms alert when new CVEs are published against your previously-built packages. Same SBOM, different cadence.

Cloud security — Wiz, CSPM platforms generally. This is the runtime context layer. A CVE finding from Grype tells you there's a known vulnerability. A cloud security platform tells you whether that package is deployed, whether it's internet-facing, whether it's running with elevated privileges. Same finding, completely different risk profile depending on context."

---

## Slide 32 — Runtime Context Changes Everything

"Here's why the third tier matters.

Without runtime context, a critical CVE in a dependency means: 'we have a critical CVE, go fix it.' You drop everything and patch.

With runtime context, you can answer: is this package actually deployed anywhere? Is the affected component reachable? Is it running with elevated privileges in production, or is it a dev dependency that never touches a prod system?

Same CVE. Completely different response. The pipeline creates the provenance. The platform adds context.

For a solo maintainer, the GitHub-native tier is probably enough. For an enterprise team, the same pipeline outputs feed into a stack that provides continuous monitoring and contextual risk evaluation. Same pipeline, different ceiling."

---

## Slide 33 — Realistic Adoption Path

"Don't try to adopt everything at once. Here's how I'd actually do this.

Start with one pipeline. PowerShell or Chocolatey, whichever is your bigger surface area or the one where you're most worried.

Start non-blocking. Run everything as warnings. Let your team see what the tools catch before you start failing builds. You'll get false positives. You'll tune the rules. That's expected.

Add one composite action at a time. PSScriptAnalyzer and Semgrep today. SBOM generation next month. Provenance when you're ready.

Tune the rules. The Semgrep rules in this repo are a starting point. Every codebase has patterns that look suspicious to a generic scanner but are intentional in context. Suppress with justification, document why.

Add enforcement when you're ready. The goal is visibility first, enforcement second. You decide what blocks a merge."

---

## Slide 34 — The Repo

"Here's the repo. Everything you saw today is in it.

`examples/` — the flawed module and package. Fork it, run the pipeline, see what fires.

`actions/` — eight composite actions. Pull any of them into your own repo individually. They're designed to be adopted one at a time.

`semgrep-rules/` — the custom rules. They're YAML. Fork them, extend them, send a PR if you've got a pattern that should be in here.

`docs/` — threat model, tooling decisions, enterprise integration, remediation guide. The 'why' behind every decision is written down. You don't need to have been at this talk to use the repo."

---

## Slide 35 — Toolchain — All Free, All Open Source

"The full toolchain: PSScriptAnalyzer, Semgrep, Syft, Grype, SLSA. All free. All open source. No vendor licenses. No proprietary platforms required.

Everything runs on GitHub Actions public runners. If you've got a GitHub repo, you can run this pipeline today."

---

## Slide 36 — Provenance Before Publish

"Back to the thesis.

Before you publish a package, you should be able to answer three questions. What's in it — that's the SBOM. What did you check — that's the scan results. Can you prove how it was built — that's the provenance.

Not a green checkmark. Receipts."

---

## Slide 37 — Questions?

*Pause. Look up from the slides.*

"I'll take questions. While you're thinking, a few I get often:

'How does this compare to Chocolatey's moderation?' Complementary. Moderation is a registry-level control. This pipeline runs before your package reaches the registry. You want both.

'Does this work with Azure DevOps instead of GitHub Actions?' The concepts are the same, the composite actions are GitHub-specific. The tools — PSScriptAnalyzer, Semgrep, Syft, Grype — all run anywhere. Porting the workflows is straightforward.

'What about internal Chocolatey repos?' This is actually where the pipeline adds the most value. Internal repos typically have zero moderation. You're the only line of defense.

'How do you handle legitimate `Invoke-WebRequest` usage that gets flagged?' Semgrep supports inline suppression with justification. Flag everything, suppress with a comment that explains why it's intentional. The suppression is visible in the PR.

'Does this slow down CI?' For typical PowerShell modules and Chocolatey packages, the full pipeline adds about two to five minutes. Most of that is Grype downloading its vulnerability database on first run. It caches after that.

What else have you got?"

---

## Demo Notes

### Before the talk

- Have the repo open in a browser tab with a PR that has pipeline results already populated
- Pre-load tabs: repo overview, PR with SARIF annotations, Actions workflow run, SBOM artifact, provenance artifact
- Test both workflows end to end at least twice in the week prior
- Verify Grype has findings — include a dependency with a known CVE in the example module if needed
- Have SARIF JSON, SBOM JSON, and provenance JSON open locally in a code editor as fallback

### If the live demo breaks

Screenshots are in `demo-screenshots/` (local only, not in the repo). Walk through them the same way — the audience doesn't care whether the browser is live. What matters is showing the artifacts and what they contain.

### Timing guide

| Section | Slides | Target time |
|---------|--------|-------------|
| Intro + Problem Space | 1–13 | 20–25 min |
| PowerShell Pipeline | 14–22 | 20–25 min |
| Chocolatey Pipeline | 23–29 | 20–25 min |
| Bigger Picture + Close | 30–37 | 10–15 min |
| Q&A | — | ~10 min |
