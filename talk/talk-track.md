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

"Good. That gap, between 'the tests passed' and 'I know what's actually in this package and what I checked,' is what we're closing today.

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

Here's what this looks like in practice — and this is not a malicious scenario, just normal maintenance drift. A maintainer ships v1.0. The binary comes from the vendor's official CDN and the checksum is documented in VERIFICATION.txt. Six months later, the vendor rotates their CDN and the URL now points to v1.2. The maintainer updates the package version and the download URL but forgets to update the checksum. Nothing in the pipeline catches it. `choco pack` succeeds. The package installs successfully on every machine that updates. The binary running on those machines is different from the one documented in the file, and nobody knows.

The malicious version of that same scenario is the 3CX supply chain attack in 2023. Attackers compromised 3CX's build environment. The signed Windows installer the vendor distributed was already backdoored before anyone packaged it for distribution. Companies pointing their packages at 3CX's official download URL were serving malware. If your pipeline doesn't verify the hash of what it downloaded against something you established at build time, you have no way to detect that the binary changed.

Chocolatey packages run as admin by default. If the binary is compromised — whether at the source, in transit, or because someone updated it without telling you — it executes with full system access.

The pipeline defense is automated checksum verification and SBOM generation for embedded binaries. If you can't prove what binary is in the package and where it came from, the pipeline surfaces that."

---

## Slide 13 — Threat 6: Unsafe Install Patterns

"Install scripts are powerful. They run as admin. They can write to the registry, create services, modify PATH, download and execute additional content. This is by design — it's how Chocolatey works.

The problem is under-review. Community repo moderation includes human review of install scripts, which catches a lot. Internal repos typically have no review at all.

The example on screen is a PATH modification. Let me walk through what actually happens after that. The script adds `C:\tools\myapp` to the machine PATH. There's no corresponding cleanup in `chocolateyUninstall.ps1`. Six months later, someone uninstalls the package. The PATH entry stays, because nothing removed it. Now you have a PATH entry pointing at a directory that either no longer exists or is still present but unmanaged.

On a shared machine or a build server, that second case is worse than it sounds. If that directory is writable by non-admin users — and a lot of tools directories under `C:\` are, depending on how the app was installed — anyone with local access can drop a binary there named after a common tool. `git.exe`. `python.exe`. `node.exe`. Windows PATH resolution finds that binary before the real one. The next person who runs `git` on that machine runs whatever was planted instead. That's not theoretical. It's a well-documented local privilege escalation path, and a misconfigured PATH entry from a forgotten Chocolatey package is a common way the precondition gets set up.

The Semgrep rules in this repo flag: registry writes, service creation, PATH modification, and any of these without corresponding documentation or uninstall cleanup. Not every finding is a security issue, but in a context where the script runs as admin, the bar for 'this is fine' should be higher than usual.

That's the threat model. Six vectors, all real, all detectable with the right tooling. The question is whether your pipeline catches them before the package ships. Let's build one that does."

---

## Slide 14 — Section 2: PowerShell Module Pipeline

*Section break.*

"Now let's build the pipeline. We'll start with the PowerShell side.

I'm going to walk through the example module in the repo, then show each step of the GitHub Actions workflow. I'll be running this live — if something takes longer than expected I'll move to screenshots and keep going."

*Switch to browser. Navigate to `examples/powershell-module/ExampleModule/` in the repo.*

---

## Slide 15 — The Example Module

*Walk through the files in the browser while talking.*

"The example module is intentionally flawed. Not cartoonishly broken. The kind of thing that ships when you're moving fast, or when you're the only person maintaining it, which tends to be the same situation.

`ExampleModule.psd1` — the manifest. It has a floating dependency in `RequiredModules` and uses `ScriptsToProcess`, which is the same mechanism Aqua used in their typosquatting proof of concept.

`Invoke-UnsafeFunction.ps1` — an exported function with two issues: a download-and-execute pattern, and a hardcoded API key in a variable. This is real code that would pass a Pester test.

And here's the important thing: `ExampleModule.Tests.ps1` — the tests pass. The module loads. The functions export correctly. Traditional CI says green. The supply chain issues are completely invisible to Pester.

When I first pushed this module to a test repo, GitHub showed a green checkmark. What I'm going to show you now is what the supply chain pipeline sees that Pester doesn't."

---

## Slide 16 — Step 1: PSScriptAnalyzer

*Switch to the PR. Navigate to the Files Changed tab.*

"Before I explain the configuration, let me show you what the output looks like from the reviewer's side.

[Point to an inline annotation in the diff.]

Right there in the code review. Not in a separate security dashboard, not an email to whoever you designated as your security person. An annotation on the specific line, with the rule name, the severity, and a description. Your reviewer sees this without leaving the PR.

[Switch to the Security tab, then Code Scanning.]

And here's where the findings aggregate. Everything from PSScriptAnalyzer, everything from Semgrep — in the same view, filterable by tool, severity, or state. This is the GitHub-native tier from Section 4's adoption path: zero cost, zero additional infrastructure. You upload a SARIF file at the end of the workflow step, and GitHub handles the rest.

Now, what PSScriptAnalyzer is actually doing here: static analysis for code quality and best practice violations. It flags `Invoke-Expression`, missing `[CmdletBinding()]`, and `Write-Host`. That's the right scope for what it is.

What it doesn't do is understand supply chain patterns. It sees `Invoke-Expression` and says 'this is a code quality warning.' It doesn't know that the expression being evaluated was just fetched from a remote URL. It doesn't know that variable in the previous line is holding content from an arbitrary CDN. That distinction matters, and that's what Semgrep is for."

---

## Slide 17 — Step 2: Semgrep — Custom Rules

*Stay in the Code Scanning view. Filter to Semgrep findings.*

"[Filter to the Semgrep tool in the Code Scanning dropdown.]

These are the Semgrep findings. Same interface — annotations in the PR diff, aggregated here — but different patterns.

[Point to the download-and-execute finding.]

That one is the Invoke-WebRequest feeding into Invoke-Expression. PSScriptAnalyzer flagged the Invoke-Expression on its own, as a code quality issue. Semgrep understands the data flow: the content came from a URL, was assigned to a variable, and is being passed to an expression evaluator. That's a different finding. That's 'you are executing untrusted remote content at runtime.'

[Point to the hardcoded API key finding if visible.]

And that one is the API key from `Invoke-UnsafeFunction.ps1`. Pattern match on the string shape. PSScriptAnalyzer doesn't have a rule for this. Semgrep does, because we wrote one.

The rules live in `semgrep-rules/powershell-unsafe-patterns.yml` in the repo. Four categories: download-and-execute, hardcoded secrets, TLS certificate validation bypass, and base64-encoded command execution. The off-the-shelf Semgrep registry has poor PowerShell support, so these are custom. Fork them, extend them for your patterns, send a PR if you've got something worth adding."

---

## Slide 18 — Semgrep Rule Example

*Navigate to the `semgrep-rules/` directory in the repo browser. Open `powershell-unsafe-patterns.yml`.*

"[Open the rule file in the browser and scroll to the invoke-expression-from-web rule.]

Here's the rule. YAML structure, readable without a Semgrep background.

The `patterns` block is a list of clauses that all have to match. The metavariable `$X` matches any identifier, so this catches it whether you wrote `$content`, `$result`, `$response`, or anything else. Semgrep handles intermediate variable assignments — you don't have to have a direct pipe from the web request to the expression. If there's an assignment and then a reference, it still matches.

The `message` field is what shows up in the SARIF output and the Code Scanning annotation. The `severity` controls whether it's a warning or a build-blocking error, depending on how you've configured the workflow threshold.

When this fires on a legitimate use case — and it will, because there are real scenarios where fetching and evaluating remote content is intentional — you add a suppression comment above the line with a justification. The suppression shows up in the SARIF output. It's documented. You're not hiding the pattern, you're recording that you reviewed it and made a conscious call."

---

## Slide 19 — Step 3: SBOM with Syft

*Switch to the workflow run. Navigate to the Artifacts section at the bottom of the run summary.*

"[Click on the SBOM artifact to download it. Open it in a code editor or the browser.]

This is the SBOM. CycloneDX JSON format. The metadata block at the top has the generation timestamp, the tool version, and the module it was generated from.

[Scroll to the `components` array.]

Each entry here is a component: package name, version, type, and a PURL — a Package URL, which is a standardized identifier for the package in its registry. For PowerShell dependencies, PURLs reference PSGallery. For anything from NuGet, they reference nuget.org.

The version numbers are resolved versions. Not 'minimum 2.0.0' like the manifest says. The actual version that was installed and available at this commit, at this point in time. That's the snapshot, and that's what makes this useful.

When a CVE drops tomorrow against a dependency, you don't have to rerun any scans. You search your stored SBOMs for the affected PURL and version. You know in seconds which releases are exposed, going back to the first time the pipeline ran.

The timing of SBOM generation also matters. This runs at build time, before the package is published. It's not a scan of what's in the registry. It's a record of what was in the package when it left your pipeline."

---

## Slide 20 — Step 4: Vulnerability Scan with Grype

*Navigate back to the PR or to the Code Scanning view filtered to Grype.*

"[Point to a Grype finding in Code Scanning.]

Grype took the SBOM from the previous step and ran it against the NVD and GitHub Advisory Database. This finding has the CVE ID, the affected package, the installed version, the fixed version if one exists, and a link to the advisory.

The severity thresholds are configurable. In this pipeline, medium surfaces as a warning and critical fails the build. If you're adding this to an existing codebase for the first time, start with everything as warnings for a few weeks. You'll see what your packages look like, and there may be some surprises, without blocking any merges. Tune the thresholds when you have a sense of the baseline.

The SBOM and Grype combination is especially valuable retroactively. A new CVE gets published today against a dependency you were using three months ago. You pull the stored SBOM from that release out of artifact storage, run Grype against it, and you know whether that release was affected — without rebuilding anything, without touching the current code. That's the case the pipeline is really designed for: not just catching things at build time, but answering questions about builds that already happened."

---

## Slide 21 — Step 5: Provenance

*Navigate to the provenance JSON artifact from the workflow run. Open it.*

"[Pull up the provenance artifact in the editor or browser.]

The provenance document. This is the receipt that ties everything together.

Source repo, commit SHA, workflow reference, build timestamp, artifact hash. Each one of those fields is a link in a chain. The source repo and commit SHA tell you exactly what code was compiled. The workflow reference tells you which pipeline ran and links back to the specific Actions run. The artifact hash is a SHA256 of the output artifact — the module package that went to the registry.

Here's how a consumer uses this. They receive the module. They hash the artifact they have, compare it to `artifact_hash`. If it matches, they know they have exactly what the pipeline produced. The commit SHA links to the repo, where the code is visible. The workflow reference links to the Actions run, where every step that ran is logged. You can trace the artifact all the way back to the specific line of code that produced it.

For a solo maintainer, this might feel like more formality than the situation calls for. For a team that publishes modules running in production Azure environments, or a team that gets asked 'can you prove the thing you shipped matches what's in your repo,' this is the answer. It's the difference between 'we think it's fine' and 'here's the chain of evidence.'"

---

## Slide 22 — PowerShell Pipeline — Full Picture

*Let the diagram speak for a moment.*

"Here's the full pipeline end to end. Push or PR triggers it. Five steps. Four artifacts: two SARIF reports in GitHub Code Scanning, one SBOM, one provenance document.

Each step is a composite action. You can adopt them one at a time. You don't have to run the whole pipeline to get value. Add PSScriptAnalyzer today, add Semgrep next month, add the SBOM when you're ready.

That's the PowerShell pipeline. Now let's talk about why Chocolatey needs its own version, and why you can't just point the same workflow at a `.nuspec` and call it done."

---

## Slide 23 — Section 3: Chocolatey Package Pipeline

*Section break.*

"The PowerShell pipeline we just built is designed around a specific threat model: modules that run in the context of whoever invokes them. Your module runs with the permissions of the user who imports it. The risk is in the code you wrote and the dependencies you declared.

Chocolatey is a categorically different situation. Install scripts run as admin. Not as the user who typed the command — elevated, because installing software systemwide requires it. And the thing the install script is deploying is typically a binary from an external URL, not code you wrote. The package is the delivery mechanism. The actual software comes from somewhere else.

That combination — admin execution of externally sourced binaries — means the blast radius if something goes wrong is fundamentally higher than in the PowerShell case. The same pipeline principles apply. The specific checks have to be different. Let's build it."

---

## Slide 24 — What Makes Chocolatey Different

"Four things set Chocolatey packages apart from PowerShell modules, and they compound each other.

Elevated privilege, by default. Install scripts run as admin. This isn't a configuration option you can work around — it's how the tool works. When you're reviewing a Chocolatey install script, you're reviewing code that will execute as SYSTEM on every machine that installs or updates this package. There is no 'runs with user privileges' fallback unless the package author explicitly coded for it, which most don't, because it's not the expected pattern.

The package usually isn't the software. A Chocolatey package is typically a thin PowerShell wrapper around a binary that gets fetched at install time. The package itself might be three kilobytes of metadata and a short script. The binary it downloads might be a 50-megabyte EXE from a vendor CDN. That binary is what runs on the machine. Which means the security of the package is entirely dependent on the security of that external download — and the package author's control over that download is limited to the URL and the checksum they documented at package creation time.

VERIFICATION.txt is documentation, not a contract. There's a well-established convention for recording binary sources and checksums. Nothing validates it programmatically. The checksum might be accurate, might have drifted when a maintainer updated the binary without updating the file, or might be missing entirely for older packages. The convention exists. The enforcement doesn't, unless you build it.

Internal repos have no safety net. The Chocolatey community repo has human moderators who review install scripts before packages are approved. Your internal repo has whoever you assigned to do it, which is often nobody formal, or a process that has been 'we should really get to that' for longer than anyone's comfortable admitting.

Everything from the PowerShell pipeline applies here. On top of that, Chocolatey packages need their own checks."

---

## Slide 25 — The Example Package

*Walk through the files briefly in the browser.*

"The example Chocolatey package has three intentional issues across three files.

The nuspec has missing metadata and an unpinned dependency. The install script calls `Install-ChocolateyPackage` with a URL but no checksum, and it modifies PATH without documenting it. VERIFICATION.txt has no checksums and a vague source URL.

Here's what makes this dangerous as a demo: `choco install` succeeds. The software installs. Chocolatey prints 'The install was successful.' It always prints that. There's nothing in that output that tells you any of this happened, which is also what Chocolatey prints when everything actually is fine. That's the problem."

---

## Slide 26 — Step 1: Naming Validation

"Before anything else, we check the package name against the Chocolatey community repo.

The action queries the community repo API and runs a Levenshtein distance check — a string similarity algorithm — against existing package names. If your package name is close to an existing one, it flags it.

This is the typosquatting defense from Section 1, operationalized. It won't stop a determined attacker who's already published a malicious package. But it will catch accidental name collisions before you publish, and it will flag potential conflicts during code review rather than after your package is live."

---

## Slide 27 — Step 2: Checksum & Integrity Check

*Show the code block.*

"Step two verifies that every external binary download has a checksum, that the checksum uses a strong algorithm — SHA256 or better, not MD5 — and that VERIFICATION.txt entries match the actual embedded files.

The check parses `chocolateyInstall.ps1` to extract URLs and checksums from `Install-ChocolateyPackage` and similar helper calls. Three possible findings: missing checksum is an error, weak algorithm is a warning, VERIFICATION.txt not matching the embedded file is an error.

The algorithm check matters more than it might seem. MD5 and SHA1 are deprecated for integrity checking because there are known collision attacks against both. An attacker who can influence the binary being served can potentially craft a replacement that produces the same MD5 hash. SHA256 doesn't have this problem in practice. If your package still uses MD5 for checksums, it's worth fixing independent of anything else we're talking about today.

The VERIFICATION.txt match check closes a specific gap: a maintainer updates the binary URL for a new release, regenerates the package, but forgets to update VERIFICATION.txt. The package passes `choco pack` without errors. It installs successfully. But the checksum in VERIFICATION.txt now describes the previous binary, not the current one. Anyone checking it manually has inaccurate data.

Chocolatey already requires checksums for non-secure downloads as of v0.10.0. This pipeline extends that enforcement to all downloads and embedded binaries and runs it at build time. The difference matters: if this check fails at install time, the software is already being downloaded onto the machine. At build time, you catch it before anyone runs the script."

---

## Slide 28 — Step 3: Install Script Analysis

"Step three is Semgrep with Chocolatey-specific rules from `chocolatey-install-patterns.yml`. Let me go through the four categories specifically, because the risk profile here is different from the PowerShell rules.

Raw `Invoke-WebRequest` calls outside Chocolatey's built-in helpers. When you use `Install-ChocolateyPackage`, Chocolatey's helper validates the checksum, handles retries, and logs the download to its audit trail. When you use `Invoke-WebRequest` directly — even if you've added your own checksum logic — you bypass all of that. The rule flags direct web calls so it's a conscious, documented choice when you make it.

Registry writes and service creation without documentation. An install script that creates a Windows service installs something that runs indefinitely with system privileges, long after the install script finishes. The rule flags `New-Service`, `Set-Service`, and `sc.exe` calls and checks for a corresponding documentation comment. Not every service creation is a problem — a lot of legitimate packages install services. But if there's no comment explaining what the service is, what it does, and how it gets cleaned up, the reviewer can't evaluate it. And in a context where the script runs as admin, 'I couldn't see anything obviously wrong' is not a sufficient review.

Hardcoded internal URLs and credentials. Internal Chocolatey packages sometimes hardcode URLs pointing to corporate infrastructure, like `https://artifacts.corp.internal/...`. If that package ever leaves the internal repo — gets copied somewhere, gets published by mistake — it exposes your internal topology to anyone who looks at the script. Credentials are worse: they end up in Chocolatey's verbose log output, which can be world-readable depending on how logging is configured on the machine.

PATH modification without uninstall cleanup. We covered the attack vector in the threats section. The specific rule checks: if `SetEnvironmentVariable` with 'PATH' appears in `chocolateyInstall.ps1`, does a corresponding cleanup exist in `chocolateyUninstall.ps1`? If not, it's a finding. The rule doesn't know whether the directory is writable or whether an attacker would care about it. But it knows the cleanup is missing, and that's enough to surface for review.

These rules are opinionated, and some findings will be intentional. Suppress with a justification comment — same as the PowerShell rules. The suppression is visible in SARIF."

---

## Slide 29 — Steps 4–5: SBOM + Provenance

"Steps four and five are the same tools as the PowerShell pipeline — Syft, Grype, provenance generation — but the SBOM content is different.

For a Chocolatey package, Syft scans the full package directory including the `tools/` folder. Embedded binaries are included in the SBOM with file hashes even if Syft can't identify them by name. The SBOM captures the declared dependency chain from the nuspec, any embedded binaries, and their resolved versions.

The provenance document for a Chocolatey package is especially valuable because the package is often a wrapper around an external binary. The provenance ties together: binary URL, binary hash, commit SHA, pipeline run, timestamp. That's the full chain from 'who published this' to 'what binary did it actually download.'

With both pipelines built, the output formats are the same across both: SARIF, CycloneDX JSON, provenance JSON. That consistency is intentional. These formats are the standard inputs for every security platform that matters. Let's talk about where they go."

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

Add enforcement when you're ready. Resist the urge to make everything blocking on day one — that's how pipelines get disabled and then quietly removed. The goal is visibility first, enforcement second. You decide what blocks a merge."

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
