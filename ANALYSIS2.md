# ANALYSIS2 — Provenance Before Publish (Second-Pass Refinement)

A synthesis of the original talk, the first-pass critique in `ANALYSIS.md`, and the directives for this pass. The goal is to keep Adil's voice and the existing three-act backbone, widen the threat-landscape education at the front, add honest trench-earned humor, and make the framing around PSGallery and the Chocolatey Community Repository unambiguously collegial.

**Event:** Chocolatey Fest 2026 — PowerShell + DevOps Global Summit (Bellevue, WA, April 2026)
**Duration:** 90 minutes (≈75 min content + 10 min Q&A + 5 min buffer)
**Audience:** Chocolatey and PowerShell practitioners, plus the PSGallery and CCR maintainer teams themselves
**Voice:** Direct, technically confident, self-aware wit. Has written the install scripts we are about to roast. Is in the room, not on the balcony.

---

## Core editorial decisions for this pass

1. **Preserve the spirit.** The three-act shape from the first pass (Ecosystem Gap → Building the Receipts → Unsolved + Monday) stays. The cold-open-on-a-real-looking-Chocolatey-package moment stays. The honest admissions ("nobody is reading the receipt yet", the lockfile gap) stay.
2. **Widen the threat-landscape education.** The first pass compressed six threats into a single five-row table. That is great reference content; it is weak pedagogy. This pass gives each threat category a slide with an analogy, a real incident, and a plain-language "here is why this keeps happening in our ecosystem specifically." Practitioners should leave with names for things they have felt but never heard put plainly.
3. **Earn humor through recognition.** Humor comes from shared-history beats — the package that silently updated to something cursed, the checksum nobody checked, the `VERIFICATION.txt` a future-you has to read in anger at 2 a.m. No punching down, no "lol npm", no jokes at the expense of PSGallery or CCR maintainers. `[laugh beat]` marks where the script intends the line to land.
4. **Collegial framing for the registries.** PSGallery and CCR are treated as allies doing real and underappreciated work. Any gap language is framed as "layer before their work" or "this is what the publisher owes the registry, not what the registry failed to catch." When the talk criticizes the problem space, it criticizes *the problem space* — never the humans maintaining it.
5. **The receipts belong to the publisher.** The responsibility for provenance and integrity ultimately lives with whoever publishes the package. The pipeline makes that responsibility tractable.
6. **Acknowledge the layer above and below.** Two Summit 2025 sessions frame this work. Rob Pleau's "Stop Writing Insecure PowerShell" covered the author-hygiene layer — PSScriptAnalyzer, InjectionHunter, SecretManagement. Michael Green and Sydney Smith's "Supply Chain Security — PSResourceGet Direction" covered the registry-layer plumbing Microsoft is building — Microsoft Artifact Registry, PSResourceGet over OCI, GPO allowlisting via Intune and Azure Policy. This talk sits between them — publisher-side receipts. Reference both sessions where the boundary matters, not as bibliography but as "here's what happens on either side of this layer." Collegial, one sentence or two, then move on.

Slide count target: **31**. Up from 28 in the first pass, because the threat-landscape education is now slide-level instead of table-level. Still down from the 39 of the original.

---

# PART 1 — Revised Slide Deck Content

Each entry: slide title, what the slide shows, and a speaker note written as natural spoken language. Stage directions are in italics. `[laugh beat]` marks moments of intended humor — give the line air to land.

---

### Slide 1 — Title

**Shows:** "Provenance Before Publish — What your PowerShell and Chocolatey receipts should look like, and what's still unsigned." Adil's name and repo URL.

*Walk up. Let the title sit for a beat. Sip of water.*

"Thanks for coming. I know you had five options this slot. I'll try to make this worth the choice."

---

### Slide 2 — Sponsors

**Shows:** Sponsor logos. Paginate skip.

*15 seconds. Don't dawdle.*

"Quick thank-you to the sponsors — the room you're sitting in and the lunch you're about to eat are on them. You know the drill."

---

### Slide 3 — The package that passed every check

**Shows:** Browser view of a realistic-looking Chocolatey package — plausible name (`corp-dev-tools`), plausible `projectUrl`, tags, version. Green checkmarks across `choco pack`, `Test-PackageForVerification`, and a mocked-up CCR Validator row. No bullet points. Just the green.

"Here is where we are starting. This is a Chocolatey package I built last night in my lab. Three kilobytes on disk. It installs a binary from a CDN. It runs as admin. It writes to the registry. It modifies PATH. And every automated gate I threw at it came back green.

`choco pack`: happy. The Chocolatey extension's `Test-PackageForVerification`: happy. If I had submitted it to the Community Repository, the Validator would have approved the metadata and the Verifier would have confirmed the install, upgrade, and uninstall cycle. A human moderator might have caught something. Probably not everything — and I want to be honest about that, because the moderators at CCR are volunteering their time and they are doing work that does not scale with the rate at which the rest of us publish. If I had submitted it to an internal repo — which is where most of us in this room are actually shipping — none of it would have been caught, because internal repos don't come with moderators. They come with whoever you designated, which, let's be real, is frequently nobody. [laugh beat]

Let me show you what it actually does."

---

### Slide 4 — What it actually does

**Shows:** Two panes. Left: `chocolateyInstall.ps1` with three lines highlighted. Right: plain-English callouts for each. The three: (1) `Invoke-WebRequest` download with no checksum, (2) machine-PATH append with no uninstall cleanup, (3) registry write containing a hardcoded internal URL.

"Three things this package does that nothing in your current toolchain catches.

**One.** It downloads a binary from a vendor URL with no checksum. If that URL ever serves something different — because the vendor rotated the CDN, because the CDN was compromised, because a maintainer updated the URL and didn't update the docs, which is the one I have personally done [laugh beat] — that new binary runs on every machine that installs this package, as admin, and nobody is told.

**Two.** It appends a directory to the machine PATH, and there's no cleanup in the uninstall script. Someone uninstalls the package six months from now — the PATH entry stays forever. And if that directory is ever writable by non-admins — which depending on the installer happens more often than you'd like — anyone with a local shell can drop a `git.exe` there. Windows PATH resolution finds the planted binary before the real one. Next person who types `git` on that box runs whatever got dropped. That is a real local privilege escalation pattern. It has been used in the wild. It starts with a forgotten Chocolatey package.

**Three.** It writes a registry value containing what looks like a corporate internal URL. If this package ever leaves the internal repo — gets copied, gets accidentally pushed to CCR, gets handed to a customer alongside a support bundle — that URL is now in every install that runs.

`choco install` prints 'The install was successful.' It always prints that. It also prints that when nothing weird happened. [laugh beat] The output is the same in both cases. That is the problem."

---

### Slide 5 — The six attacks you need names for

**Shows:** A single slide laying out the taxonomy the next six slides will walk through. Six labels, one line each, no incidents yet:

- **Name confusion** — typosquats and lookalikes
- **Dependency confusion** — internal vs. public resolution
- **Download-and-execute** — install-time code fetches
- **Floating dependencies** — no lockfile, no floor
- **Build-pipeline compromise** — the vendor was the problem
- **Secret leakage + artifact drift** — what you shipped isn't what you meant to ship

"Before we go anywhere near tooling, I want to give you names for six things. Because in my experience — and this might just be me — practitioners know something bad can happen here, but they haven't had the categories put to them plainly. And once you have names for the categories, the defenses fall out naturally.

We are going to take one slide each. Each one gets an analogy, a real incident, and a one-line version of why this ecosystem specifically is susceptible. If you have heard all six before and want to zone out for six minutes, I will not be offended. [laugh beat] If you haven't, the rest of the talk assumes these names."

---

### Slide 6 — Name confusion (typosquats and lookalikes)

**Shows:** Two package names side by side: `AzTable` and `Az.Table`. Below, a two-line story: "Aqua Nautilus, 2023. Registered `Az.Table` to impersonate `AzTable`. Callbacks from production Azure environments within hours."

"First one. **Name confusion.** Attacker registers a package whose name differs from a popular package by one character, one dot, one dash. A developer mistypes. Autocomplete confidently recommends the wrong one. Copy-paste from a Stack Overflow answer from 2019 where somebody typed it wrong. The wrong package installs. The wrong package runs.

Aqua Nautilus did this for real in 2023. They registered `Az.Table` — same letters, one extra dot — to impersonate `AzTable`, which at the time had more than ten million downloads. They got callbacks from production Azure environments within hours. This wasn't a prank. This was a proof of concept that worked the first time they tried it.

The reason it worked is that PSGallery, unlike npm, does not have moniker rules — structural name-similarity checks that reject uploads colliding with existing names. This isn't a failing of the PSGallery team. Moniker rules are a big lift, they have false-positive consequences for legitimate forks, and there are reasonable arguments about whether the registry or the publisher should be responsible for name hygiene. It is a shared-challenge problem we are all navigating.

Microsoft's in-progress answer at the registry layer — and if you want the deep version, Michael Green and Sydney Smith walked us through it at Summit last year — is the Microsoft Artifact Registry and PSResourceGet going over OCI. Structural fix: only Microsoft can publish under the MAR namespace, so you literally can't squat on `MAR/PSResource/Az.Accounts`. Different layer from this talk. It is also not shipped for most of what you install — today only the Azure PowerShell team is fully onboarded, and MAR doesn't help for community packages or third-party vendor modules. Which means if you care whether your package is confusable with someone else's, the check still has to live in your pipeline. We'll do it in forty minutes."

---

### Slide 7 — Dependency confusion

**Shows:** A box labeled "Internal feed: `AcmeSecrets` v1.2.3" next to a box labeled "Public PSGallery: `AcmeSecrets` v9.9.9". An arrow pointing from `Install-Module` resolution to the public one. A caption: "Higher version wins. Your resolver doesn't know which feed was supposed to be authoritative."

"Second one. **Dependency confusion.** Close cousin of name confusion. Your organization has an internal package — let's call it `AcmeSecrets`. It lives on an internal feed. An attacker notices you reference it in a public job log, or in a GitHub Actions workflow file, or in a screenshot on a conference talk. [laugh beat] The attacker publishes a package with the same name to the public registry, with a higher version number. Next time your CI installs dependencies, the resolver picks the higher version. Which happens to be the public one. Which happens to be the attacker's.

This one isn't hypothetical. Alex Birsan demonstrated it in 2021 against Apple, Microsoft, Tesla, PayPal, Shopify, Netflix, Yelp, and a couple dozen others. Ten-thousand-dollar bug bounties all around. The PowerShell ecosystem has the same shape of risk the moment you have any private modules with names that could be squatted publicly. The defense is to make sure your resolver is explicitly scoped — the internal feed is authoritative for internal names, and those names aren't resolvable externally even by accident.

Again, this is not something the registry can fix for you. This is a publisher-side discipline question. The pipeline's job is to remind you when you've forgotten."

---

### Slide 8 — Download-and-execute

**Shows:** A four-line PowerShell snippet: hardcoded URL, `Invoke-WebRequest` into `$X`, `Invoke-Expression $X`. Below, a one-line summary: "Serpent campaign, 2022 — used Chocolatey legitimately, then deployed a backdoor via steganography."

"Third one. **Download-and-execute.** The install script fetches something at install time and runs it. The thing being fetched is not what was reviewed. The thing being reviewed is the *code that fetches*, not the code that runs.

This is the pattern. `Invoke-WebRequest`, content into a variable, `Invoke-Expression` on the variable. Or the Chocolatey equivalent: `Install-ChocolateyPackage` with a URL but no checksum. Four lines. Each line on its own is legal PowerShell. Each line on its own is something you have probably written. The chain of four is remote code execution with no integrity guarantee.

Real incident: the Serpent malware campaign, 2022, targeting French organizations. Attackers used Chocolatey *completely legitimately* — they installed Python through the official Chocolatey channel, using the real Chocolatey infrastructure — and then their own downstream tooling, running in the already-elevated context that Chocolatey installs kick off, reached out and pulled a backdoor hidden in an image. Steganography. Chocolatey itself wasn't compromised. The pipeline around it had no idea what was executing, because the install-time download was opaque.

The thing I want you to sit with here is that 'download-and-execute' is not a weird exotic pattern. It is normalized in our ecosystem. Every vendor that ships a Chocolatey package that wraps a `.exe` installer does some version of this. The question isn't whether you download and execute. It's whether you pin what you downloaded against a hash you trusted at build time."

---

### Slide 9 — Floating dependencies (the lockfile gap)

**Shows:** A `.psd1` snippet with `RequiredModules = @( @{ ModuleName = 'Az.Accounts'; ModuleVersion = '2.0.0' } )`. An arrow: "resolved at *install* time, not publish time." A caption: "npm has package-lock.json. cargo has Cargo.lock. PowerShell has a list of floors."

"Fourth one. **Floating dependencies.** No single dramatic incident behind this one — it's the structural one, and that is what makes it scary.

Look at this `.psd1`. `RequiredModules` with `ModuleVersion = '2.0.0'`. That is not a pin. That is a floor. It means 'at least 2.0.0.' What the consumer actually installs is 'whatever is currently the highest version in PSGallery that satisfies the floor.' Monday's build and Tuesday's install can resolve to different dependency graphs with zero change to your code.

If you came from npm or cargo or Go, you already know what a lockfile is — a byte-identical pin of every transitive dependency in your graph, checked into source, applied at install. `package-lock.json`. `Cargo.lock`. `go.sum`. PowerShell does not have this. Not a missing feature that is about to ship — it is a genuinely unsolved ecosystem problem. Which means every PowerShell SBOM you have ever seen is describing *the author's build*, not *the consumer's install*. That is a gap we are going to name again later in this talk because it changes what our receipts actually mean.

No attacker needed here. Normal day, different resolution, potentially different behavior. The attacker version of this is when one of the transitive dependencies quietly changes ownership and the new owner decides to test what happens when a popular module starts calling home. Which has happened in every other ecosystem. [laugh beat] Just not to us yet. That we know of."

---

### Slide 10 — Build-pipeline compromise

**Shows:** Diagram of a signed vendor installer with an arrow labeled "backdoored before signing" pointing at it. Caption: "3CX, 2023. The installer was authentic. The authenticity wasn't the problem."

"Fifth one. **Build-pipeline compromise.** The scariest category, because the defenses you are used to trusting don't help you.

The attacker doesn't compromise the package. They don't even compromise the vendor's code. They compromise the vendor's *build environment*. The installer that comes out is the real installer, from the real vendor, signed with the real code-signing cert, and it is already backdoored before anybody put a signature on it. Every downstream check that asks 'is this from the vendor?' returns yes. Because it is.

The canonical incident is 3CX, 2023. The attackers compromised the build pipeline of a VoIP desktop app with around twelve million users. The signed installer the vendor distributed was already malicious. Every Chocolatey package that pointed at the official 3CX download URL — including perfectly well-maintained, well-intentioned ones — was distributing malware. The maintainers didn't do anything wrong. The checksums they documented matched the file the vendor was serving. The file the vendor was serving was what the vendor meant to serve. The problem was one layer further upstream.

The only defense here is in-depth: you pin hashes at build time, you detect drift when they change, you have a mechanism to re-verify historical artifacts when new evidence emerges, and you have provenance that lets you answer 'which of my builds consumed the bad version of that upstream?' None of those individually would have stopped 3CX. All of them together make the cleanup tractable instead of impossible."

---

### Slide 11 — Secret leakage and artifact drift

**Shows:** Two-column. Left: a published module with a hardcoded `sk-live-...` API key. Right: a `VERIFICATION.txt` showing checksums for binaries that no longer match the embedded files. Caption: "What you shipped isn't always what you meant to ship."

"Sixth one, and then we move on. **Secret leakage and artifact drift.** Two related failure modes of 'the package on the registry isn't what the author believes they published.'

Secret leakage — Aqua Nautilus again, same 2023 research. They found PSGallery publishers who had accidentally shipped `.git/config` with GitHub tokens in it. They found publishing scripts containing PSGallery API keys in *unlisted* packages — packages the authors thought they had hidden — still accessible via the PSGallery API after the authors thought they had removed them. Because unlisting changes search visibility, not API reachability. The PSGallery team has since improved this, and I want to be clear: they responded. But the existence of those keys in the first place was a publisher-side failure, not a registry-side failure. We shipped secrets. The registry just made them reachable longer than we wanted.

Artifact drift — this is the `VERIFICATION.txt` story that most of you in this room have already hit at least once. Maintainer ships v1.0. Vendor URL is documented. Checksum is in `VERIFICATION.txt`. Vendor rotates their CDN six months later. Maintainer updates the URL in `chocolateyInstall.ps1`, regenerates the package, forgets `VERIFICATION.txt`. [laugh beat] `choco pack` succeeds. The package installs. `VERIFICATION.txt` is now describing the previous binary. Anyone who verifies manually is reading a file that is lying to them — not maliciously, just out-of-date. 

The malicious version is 3CX, which we just covered. The non-malicious version is every one of us, on a Thursday afternoon, under time pressure, hitting `choco pack` and hoping for the best. The defense is the same in both cases: the pipeline recomputes what the file claims, against what is actually on disk."

---

### Slide 12 — What the registries already do

**Shows:** Two columns with equal weight. **Chocolatey Community Repository:** Validator (nuspec, scripts, structure), Verifier (install/upgrade/uninstall in a reference VM), VirusTotal scan, human moderation. **PowerShell Gallery:** manifest validation, installation testing during validation, antivirus scanning, error-level PSScriptAnalyzer. Caption: "This is real infrastructure. The rest of this talk is the layer before it, not instead of it."

"Before we pivot to tooling, I want to spend a slide on what the registries are already doing, because I think the shared narrative in our industry has been unfair to them.

The Chocolatey Community Repository runs a Validator that checks metadata and script structure. It runs a Verifier that actually performs an install, an upgrade, and an uninstall in a reference environment — which is not free to operate. It runs VirusTotal. It has a human moderation pass for non-trusted packages. Most of that is volunteer time.

PowerShell Gallery runs manifest validation, installation testing during validation, antivirus scanning, and PSScriptAnalyzer at error level on every upload. That is a non-trivial amount of automated scrutiny on every single module that lands.

This is real infrastructure. I am not recommending you skip it, and I am not recommending the pipeline we are about to build replaces it. What I *am* recommending is that by the time your package arrives at one of these registries, you can hand the moderator three things they don't currently receive: an SBOM, a set of scan results, and a provenance document. Because the registries can't generate those retroactively — the source of truth is in the publisher's pipeline, and the publisher is you. [laugh beat: point at room] The receipts are ours to produce. That's the premise of the rest of the talk."

---

### Slide 13 — The three questions

**Shows:** Large, centered:
- What's in this package? → **SBOM**
- What did you check? → **scan results (SARIF)**
- Can you prove when and how it was built? → **provenance**

"Three questions a maintainer should be able to answer before publishing.

What's in this package? That's the SBOM. What did you check? That's scan results in SARIF. Can you prove when and how it was built? That's provenance.

I want to be honest with you up front: the answers I can give you today are different for each question, and different for each ecosystem. The SBOM story works better for Chocolatey packages with embedded binaries than it does for pure PowerShell modules. The provenance story — I can produce a receipt; nobody's reading it at install time yet. I am going to come back to that honest accounting at the end. This is the part of the talk where we earn the right to make those admissions."

---

## Act II — Building the Receipts

---

### Slide 14 — The flawed module

**Shows:** Browser on `examples/powershell-module/ExampleModule/`. Three callouts: `.psd1` floating dep + `ScriptsToProcess`; `Invoke-UnsafeFunction.ps1` with four labeled flaws; `ExampleModule.Tests.ps1` that passes.

*Switch to the repo browser.*

"PowerShell side first. This is the flawed module in the repo. I want to make sure you read it for what it is: not cartoonishly broken. This is the shape of the thing that ships when you are the solo maintainer, it's Friday, your toddler has an ear infection, and the release has to go out today. [laugh beat]

Floating dependency in the `.psd1`. `ScriptsToProcess` — same mechanism Aqua used in their typosquat proof of concept. An exported function with four labeled flaws. Pester passes. PSGallery would publish this. Everything that is wrong with this module is invisible to the tools you currently have in CI. That's the thing to hold in your head."

---

### Slide 15 — The multi-statement pattern

**Shows:** Four lines from `Invoke-UnsafeFunction.ps1`:
```powershell
$ApiKey = "sk-live-abc123..."
[ServicePointManager]::ServerCertificateValidationCallback = {$true}
$X = Invoke-WebRequest -Uri $url -Headers @{Authorization=$ApiKey}
Invoke-Expression $X
```
Two annotations below: **PSScriptAnalyzer:** warns on line 4 (`Invoke-Expression`). **Semgrep:** flags lines 1–4 as one download-execute chain with hardcoded credential + TLS bypass.

"This is the pattern I want you to remember from the PowerShell side. Four lines.

PSScriptAnalyzer — which PSGallery already runs at publish time, and which is an excellent piece of software written by people who understand PowerShell more deeply than I do — will flag line four. `Invoke-Expression` is a code-quality warning. One finding, one line.

What PSScriptAnalyzer is *not* doing — and is not designed to do, because it is a linter — is reading these four lines as a *sequence*. It is not saying 'the thing being evaluated just arrived from the network.' It is not saying 'the credential feeding the network request is hardcoded two lines up.' It is not connecting 'TLS validation was turned off earlier in the function' to 'a subsequent HTTPS request is about to run with no certificate checks.'

Semgrep's job is to see this as one pattern. Multi-statement. Variable-binding. Cross-line. That is the difference. Not 'Semgrep is better than PSScriptAnalyzer.' They do different jobs. Linter versus security scanner. Run both.

If you want the author-hygiene version of this whole conversation in depth — PSScriptAnalyzer extensions, InjectionHunter, custom AST rules for PII, SecretManagement and SecretStore for credentials at rest — Rob Pleau's Summit 2025 session, 'Stop Writing Insecure PowerShell,' is the layer below this one. Watch it if you haven't. This talk assumes that layer of hygiene is already the baseline; what we're doing here is what shows up when you go to publish."

---

### Slide 16 — A Semgrep rule, unabridged

**Shows:** Full YAML of the `invoke-expression-from-web` rule. No other content.

```yaml
rules:
  - id: invoke-expression-from-web
    patterns:
      - pattern: |
          $X = Invoke-WebRequest ...
          Invoke-Expression $X
    message: Remote content fetched without integrity check
    severity: ERROR
    languages: [generic]
```

"This is what a Semgrep rule looks like. YAML. No plugin. No DSL. No IDE dependency. The `$X` is a metavariable — it binds an identifier across lines, which is how the pattern matches assignment-then-exec even when there are other statements between them.

The rules live in `semgrep-rules/` in the repo. Twelve for PowerShell, twelve for Chocolatey. The authoring cost is low enough that if your team has patterns specific to your environment — and you do, I promise you do — you can add rules for them in an afternoon. Fork the repo, extend the YAML, send a PR if you want them upstream. I will merge it. That is a promise. [laugh beat]"

---

### Slide 17 — Live SARIF in the PR

**Shows:** Browser on a real PR with inline SARIF annotations in the diff and aggregated in the Security tab.

*[LIVE DEMO BEAT] Switch to a live browser tab. Pre-populated fallback ready in a second tab.*

"This is what the output looks like from the reviewer's side. Annotations inline in the diff. Aggregated in the Security tab. Filterable by tool and by severity.

The dollar cost of this is zero. The setup is one `github/codeql-action/upload-sarif` step at the end of each scanning job. If you took one thing from this talk and put it in your pipeline next week, this is the thing — visibility in the PR, no new dashboard to train your team on. Because we both know how training your team on a new dashboard goes. [laugh beat]

*[Optional live beat: edit a file here to introduce a new finding, push, narrate for 60–90 seconds while the pipeline runs, show the annotation landing. Fallback: stay on the pre-populated PR, don't apologize for the switch.]*"

---

### Slide 18 — The SBOM, and the gap inside it

**Shows:** Snippet of `powershell-module-sbom.cdx.json` with a visible `components` array and PURLs. Below, a callout: "Your SBOM records what you shipped. It doesn't record what resolves on the consumer's machine."

"SBOM next. CycloneDX JSON, generated by Syft against the module directory. Components array. PURLs. Resolved versions. File hashes. Useful as an audit trail.

Now the honest part — this is the lockfile gap from Act I, finally landing. This SBOM records what *I shipped*. It does *not* record what resolves on the consumer's machine when they `Install-Module` this thing. PowerShell has no lockfile. `Install-Module` resolves `RequiredModules` at install time against whatever is currently the highest-satisfying version in PSGallery. I ship Monday. You install Tuesday. Your dependency graph might be different from the one my build produced. My SBOM tells you what I built. It doesn't tell you what ran on your machine.

This is the single biggest unsolved problem in PowerShell supply chain security today, and I want to be clear that nobody on stage or in the registry team has a clever fix for it hiding in their back pocket. Not me, not PSGallery, not Microsoft. The current workaround is to pin `RequiredVersion` — the exact version — instead of `ModuleVersion`, and to enforce that pinning with `dependency-pin-check` in the repo. That is a maintainer-side commitment, not a consumer-side guarantee. We come back to this in Act III."

---

### Slide 19 — Vulnerability scan, and the retroactive payoff

**Shows:** Grype SARIF output in Code Scanning. Caption: "Stored SBOM + future Grype run = 'which of my past releases are affected?' in seconds."

"Grype reads the SBOM from the previous step. Runs it against NVD and the GitHub Advisory Database. Findings go back into Code Scanning.

The build-time value is obvious — you learn about known CVEs in your declared dependencies before you ship. The *less* obvious value is retroactive. The SBOM is retained as an artifact for a year by default. When a CVE drops six months from now against a dependency you shipped, you re-run Grype against the stored SBOM from that release and you know in seconds which builds were affected. That is incident response, not prevention. Both matter — and in my experience, in an enterprise context, the incident-response case is what actually gets this pipeline funded, not the build-time gating. Because leadership has sat through the other kind of incident, the one where you're trying to figure out *after the fact* whether a given build is exposed, and nobody has an answer, and everybody stays late. [laugh beat, knowing]"

---

### Slide 20 — Provenance, and the consumer who isn't there

**Shows:** Provenance JSON — source repo, commit SHA, workflow ref, artifact hash, timestamp. Below, a blunt single-line callout: "This is the receipt. Nobody is reading it at install time. Yet."

"Provenance. Here is the receipt.

Now. Who is reading this receipt? `Install-Module` doesn't check it. `choco install` doesn't check it. The registries don't require it at upload. No install-time verifier ships in the ecosystem today. I produce the provenance. The consumer never asks to see it.

That is a real problem with the current state of this, and I am not going to pretend it isn't. What I can say is the provenance is useful *to the maintainer* right now. If a customer ever asks 'can you prove the module you shipped on this date came from this commit and was built by this pipeline,' I can answer. If an incident happens and I need to establish definitively which build produced which artifact, I can. That's maintainer-side audit value — real, but narrower than an end-to-end story.

The full loop closes when the registries require signed provenance at upload and the install tooling verifies at install. Both are ecosystem-scale asks. They are not my pipeline's problem to solve, and frankly, they are not any single pipeline's problem to solve. What I can do in the meantime is produce the receipts *now*, so the day a verifier ships, my back catalog is ready to be read. That is the bet."

---

### Slide 21 — PowerShell pipeline — actual run

**Shows:** Screenshot of the real GitHub Actions run graph with step timings.

"Full pipeline, end to end. Three and a half minutes on a cold runner. Under two minutes once Grype's database is cached. Non-blocking by default. Every step is a composite action you can pull independently — you can adopt any one of these without taking all of them. You don't have to buy the whole pipeline."

---

### Slide 22 — Chocolatey changes the threat model

**Shows:** Three-row comparison table:
- Execution context: user → **admin**
- Package content: your code → **a thin wrapper around an external binary**
- Review: PSGallery AV + PSScriptAnalyzer → **CCR moderation for community, zero for internal**

"Switching to Chocolatey. Everything we just built applies. On top of that, Chocolatey tightens the threat model in three ways.

Install scripts run as admin. The package is typically a three-kilobyte wrapper around a fifty-megabyte binary that gets fetched at install time, which means the package's security is mostly the security of an external download. And moderation doesn't reach internal repositories, which is where a lot of Chocolatey is actually deployed — and where, again, the volunteers at CCR can't help you, even if they wanted to.

That combination is why the Chocolatey pipeline adds three checks the PowerShell pipeline doesn't need."

---

### Slide 23 — The flawed Chocolatey package

**Shows:** Browser on `examples/chocolatey-package/`. Three callouts: nuspec missing metadata + unpinned dep; `chocolateyInstall.ps1` with the three cold-open flaws; `VERIFICATION.txt` with no checksums.

"This is the package from the cold open. nuspec with missing metadata and unpinned dependencies. Install script with the three flaws we already looked at. `VERIFICATION.txt` with no checksums.

The thing I want you to notice: this is not a contrived example. This is the shape of something I have personally helped review in two different enterprises. [laugh beat, rueful] Both times the author was extremely senior. Both times the package had been in production for months. Neither time was the author trying to do anything wrong. They were trying to ship the thing."

---

### Slide 24 — Naming validation

**Shows:** Levenshtein check output against the CCR API. One-line caption: "Cheap, narrow, non-heroic. Catches name collisions before you publish."

"Naming validation queries the CCR API and runs a Levenshtein similarity check against existing package names. Cheap to run. Narrow in what it catches — won't stop a determined attacker who has already published, but it catches accidental name collisions before *you* publish, and it surfaces potential typosquat conflicts for reviewers.

Not going to spend long on this. It's the cheapest check in the pipeline. Moving on."

---

### Slide 25 — Checksums + VERIFICATION.txt drift

**Shows:** `Install-ChocolateyPackage` call with required checksum fields. Below, a four-step drift narrative: maintainer ships → vendor rotates CDN → maintainer updates URL → `VERIFICATION.txt` left stale.

"Three checks. Every external download has a checksum. The algorithm is SHA256 or better. And `VERIFICATION.txt` entries match the actual embedded files on disk.

That third check is the one I want you to notice. I already told the drift story in Act I, so I'll make it short. Maintainer ships v1.0, checksums match. Six months later, vendor rotates the CDN, URL changes, maintainer updates the install script, forgets `VERIFICATION.txt`. `choco pack` succeeds. Package installs. `VERIFICATION.txt` is describing a binary that no longer exists. Nothing malicious. Just maintenance drift. Every one of us has done a version of this. [laugh beat]

The malicious version is 3CX — which we also already covered. The defense against both is the same: the pipeline recomputes file hashes at build time and flags when they don't match what's claimed in `VERIFICATION.txt`. This is the most specifically-Chocolatey check in the pipeline. It is also, in my experience, the one that catches the most real issues in internal-repo packages."

---

### Slide 26 — Install-script analysis

**Shows:** Four rule names from `chocolatey-install-patterns.yml`, each with a one-line description:
- `choco-unverified-download` — raw `Invoke-WebRequest` outside Chocolatey helpers
- `choco-registry-write-undocumented` — HKLM writes without doc comment or uninstall cleanup
- `choco-path-modification-undocumented` — PATH change without uninstall cleanup
- `choco-hardcoded-internal-url` — internal URLs / UNC paths embedded in the script

"Four rule categories. Raw `Invoke-WebRequest` outside Chocolatey's helpers — bypasses Chocolatey's built-in checksum enforcement, which exists and is good, and if you are writing around it you should probably stop. [laugh beat] Registry writes and service creation without a documentation comment — in a script that runs as admin, the reviewer needs to know why. Hardcoded internal URLs — leaks your internal topology if the package ever leaves the internal repo. PATH modification without matching uninstall cleanup — this one gets its own slide."

---

### Slide 27 — The PATH story

**Shows:** Diagram. Step 1: `chocolateyInstall.ps1` appends `C:\tools\myapp` to machine PATH. Step 2: uninstall script doesn't remove it. Step 3: directory is non-admin-writable. Step 4: attacker drops `git.exe`. Step 5: next user running `git` runs the planted binary. Label: "Local privilege escalation via a forgotten Chocolatey package."

"Install script appends `C:\tools\myapp` to the machine PATH. Uninstall script doesn't remove it. Six months later, someone uninstalls the package — the PATH entry stays.

If that directory's ACLs ever let non-admins write to it — and depending on the installer that created it, that happens more than you'd like — anyone with a local shell can drop a `git.exe`, a `python.exe`, a `node.exe` there. Windows PATH resolution finds them before the real ones. The next person who types `git` on that machine runs whatever got dropped.

That's a documented LPE precondition, and a misconfigured PATH entry from a forgotten Chocolatey package is a common way it gets set up. The Semgrep rule doesn't know whether the directory is writable. It knows the uninstall cleanup is missing. In a context where the script runs as admin, that's enough to make it reviewable — and it's the finding I most often see get fixed quietly with no fuss, because the author immediately recognizes the shape of the problem once it's pointed out."

---

### Slide 28 — Chocolatey pipeline — actual run

**Shows:** Screenshot of the real `chocolatey-supply-chain.yml` run graph.

"Chocolatey pipeline. Same five output artifacts as the PowerShell pipeline — two SARIF reports, an SBOM, Grype results, provenance. Ecosystem-specific checks. Same shape."

---

## Act III — What's Still Missing, and Monday

---

### Slide 29 — Three unsolved problems

**Shows:** Three short blocks. (1) The lockfile gap. (2) Receipt consumers don't exist. (3) Internal repos have no moderation.

"Now the honest accounting. Three things this pipeline does not solve.

**One, the lockfile gap.** Covered it. The Chocolatey version is slightly better — `.nuspec` dependencies can be pinned to exact versions, and `dependency-pin-check` enforces it. The PowerShell version is worse, and no composite action I write is going to fix it. The real fix is a PowerShell lockfile, which is a platform-level change. If that is something you work on or can advocate for, this is me advocating for it.

**Two, consumers aren't reading receipts.** `Install-Module` and `choco install` don't verify provenance. Production of receipts runs ahead of verification. That gap closes when the registries require signed provenance at upload and the clients verify at install. Both are ecosystem-level decisions — and CCR and PSGallery are in the room, and they know it, and the answer to 'why haven't you shipped this yet' is always 'backward compatibility, resource constraints, and a careful rollout plan' — which, when I was sysadmin-side of this conversation, I had opinions about. Now that I've been on the other side of ship-vs-don't-break-everyone decisions, I have more patience with the answer. [laugh beat]

The PSResourceGet team has been showing direction — Michael Green and Sydney Smith at Summit last year walked through MAR, PSResourceGet over OCI, GPO allowlisting through Intune and Azure Policy. That is the closed-loop version of what we are producing receipts for: the client knows which registries to trust, and the registry publishes signed artifacts with identity-level guarantees. It is not shipped everywhere — discovery across vendor registries, dependency resolution across MAR and PSGallery, and caching from the NuGet-v2 gallery into an OCI registry are all still open questions they are actively soliciting feedback on. The worthwhile thing I can do in the meantime is produce the receipts now so the day a verifier ships, my back catalog is ready to be read.

**Three, internal repositories.** CCR has moderators. Your internal Chocolatey repo typically does not. In that context, this pipeline is not a *complement* to moderation — it *is* the moderation. That changes how seriously you take enforcement. On a community package I'd say 'start non-blocking, tune, enforce when ready.' On an internal package shipped to thousands of endpoints with no human review — start blocking on critical checks immediately. Don't be polite with your own infrastructure."

---

### Slide 30 — Monday-morning adoption path

**Shows:** Three numbered steps, each with an effort estimate.
1. **One afternoon.** PSScriptAnalyzer with SARIF upload + Semgrep with one rule file, non-blocking.
2. **One afternoon.** SBOM + provenance generation. Both single-composite-action adoptions.
3. **Ongoing.** Tune rules, add suppressions with justifications, decide what blocks.

"Three steps for next week.

One, one afternoon: add PSScriptAnalyzer with SARIF upload and Semgrep with one rule file, non-blocking. You'll see what fires. You will get false positives. Expect them. Do not open seventy-four Jira tickets on day one. [laugh beat]

Two, one afternoon, later the same week or the next: add SBOM and provenance generation. Both are single-composite-action adoptions. Neither blocks anything — they produce artifacts.

Three, ongoing: tune rules, add suppressions with justifications, decide which findings block a merge.

What *not* to do on day one: don't turn on enforcement before you've seen the baseline. That is how security gates get disabled quietly three months later, when the team gets tired of them. Visibility first. Enforcement after you've earned it."

---

### Slide 31 — The repo + a last line

**Shows:** Top half — `github.com/adilio/publish-with-receipts` with four pointers: `examples/`, `actions/`, `semgrep-rules/`, `docs/`. Bottom half, centered and large: "Receipts are useful even when nobody reads them — until the day someone does."

"Repo is on screen. `examples/` has the flawed module and the flawed package. `actions/` has eight composite actions you can adopt individually. `semgrep-rules/` has the YAML rules. `docs/` has the threat model, tooling decisions, enterprise integration, and a remediation guide for every finding type the pipeline surfaces. You don't need to have been in this room to use the repo. The decisions are written down, so when your VP of Engineering asks 'wait, why are we doing this?' six months from now, you have something to point at that isn't a hand-wave. [laugh beat]

That's the talk. Receipts are useful even when nobody reads them — until the day someone does. I'll take questions."

---

### Slide 32 — Q&A

**Shows:** Prompt, name, handle, repo URL.

*Pause. Look up. Don't fill the silence.*

"While you're thinking, a few I get often:

- **How does this compare to Chocolatey's moderation?** Complementary. Moderation is registry-side. This pipeline runs before your package reaches the registry. You want both. And the moderators would like you to send them packages that are easier to moderate. Everyone wins.
- **Does this work with Azure DevOps?** Concepts are identical, tools are portable. The composite actions are GitHub-specific. The tools — PSScriptAnalyzer, Semgrep, Syft, Grype — run anywhere. SARIF upload is the main thing that changes.
- **What about internal Chocolatey repos?** This is actually where the pipeline adds the most value. Internal repos typically have zero moderation. You're the only line of defense.
- **You work at Wiz — is this a vendor pitch?** No, and let me say it plainly. Nothing in this pipeline depends on Wiz or any proprietary platform. Everything is free and open source. The reason runtime context matters — whether you use Wiz, a competing CSPM, or nothing — is that a CVE at build time doesn't tell you whether the vulnerable component is deployed, reachable, or running with privilege. That's a real gap, and somebody will close it. I have opinions about who. That's not the point of this talk. [laugh beat]
- **How do you handle legitimate `Invoke-WebRequest` usage that gets flagged?** Inline suppression with justification. Flag everything, suppress with a comment explaining why it's intentional, the suppression ships in SARIF, and reviewers see it in the PR.
- **Does this slow CI?** Two to five minutes for a typical module or package. Most of that is Grype downloading its vulnerability database on first run. Caches after.

What else have you got?"

---

# PART 2 — Polished Talk Track

What follows is the continuous spoken track. Stage directions in italics. `[laugh beat]` marks where the line is intended to land — give it air. This is a speaker track, not a read-aloud script. Spoken voice, not paragraphs.

---

## Act I — The Ecosystem Gap

*[Slide 1 — Title. Walk up. Let the title sit. Drink of water.]*

Thanks for coming. I know you had five options this slot. I'll try to make this worth the choice.

*[Slide 2 — Sponsors. 15 seconds.]*

Quick thank-you to the sponsors — the room you're sitting in and the lunch you're about to eat are on them. You know the drill.

*[Slide 3 — The package that passed every check. Pull up the browser view.]*

Here is where we are starting. This is a Chocolatey package I built last night in my lab. Three kilobytes. It installs a binary from a CDN. It runs as admin. It wrote to the registry. It modified PATH. And every automated gate I threw at it came back green.

`choco pack`: happy. The Chocolatey extension's `Test-PackageForVerification`: happy. If I'd submitted it to the Community Repository, the Validator would have approved the metadata and the Verifier would have confirmed install, upgrade, and uninstall. A human moderator might have caught something. Probably not everything — and I want to be honest about that, because the CCR moderators are volunteering their time and they're doing work that does not scale with the rate the rest of us publish at. If I'd submitted to an internal repo — which is where most of us are actually shipping — nothing would have caught any of it, because internal repos don't come with moderators. They come with whoever you designated, which, let's be real, is frequently nobody. [laugh beat]

Let me show you what it actually does.

*[Slide 4 — What it actually does. Three callouts on the install script. Walk each one slowly.]*

Three things this package does that nothing in your current toolchain catches.

One. It downloads a binary from a vendor URL with no checksum. If that URL ever serves something different — because the vendor rotated the CDN, because the CDN was compromised, because a maintainer updated the URL without updating the docs, which is the one I have personally done [laugh beat] — that new binary runs on every machine that installs this package, as admin, and nobody is told.

Two. It appends a directory to the machine PATH. No cleanup in the uninstall script. Someone uninstalls the package six months from now, the PATH entry stays forever. And if that directory was ever writable by non-admins — depending on the installer, that happens more often than you'd like — anyone with a local shell can drop a `git.exe` there. Windows PATH resolution finds the planted binary before the real one. Next person who types `git` on that box runs whatever got dropped. That is a real local privilege escalation pattern. It has been used in the wild. It starts with a forgotten Chocolatey package.

Three. This package writes a registry value containing what looks like a corporate internal URL. If it ever leaves the internal repo — gets copied, gets pushed to CCR by accident, gets handed to a customer with a support bundle — that URL is now in every install that runs.

`choco install` prints 'The install was successful.' It always prints that. It also prints that when nothing weird happened. [laugh beat] The output is the same in both cases. That is the problem.

*[Slide 5 — The six attacks you need names for.]*

Before we go anywhere near tooling, I want to give you names for six things.

Because in my experience — and this might just be me — practitioners know something bad can happen here, but nobody has put the categories to them plainly. And once you have names, the defenses fall out naturally.

Six slides. One each. Each one gets an analogy, a real incident, and a one-line version of why this ecosystem specifically is susceptible. If you have heard all six, zone out for six minutes and I won't be offended. [laugh beat] If you haven't, the rest of the talk assumes these names.

*[Slide 6 — Name confusion.]*

First one. Name confusion. Attacker registers a package whose name differs from a popular package by one character, one dot, one dash. A developer mistypes. Autocomplete confidently recommends the wrong one. Somebody copies from a Stack Overflow answer from 2019 where the typo was already baked in. The wrong package installs. The wrong package runs.

Aqua Nautilus did this for real in 2023. Registered `Az.Table` — same letters, extra dot — to impersonate `AzTable`, ten million downloads at the time. Callbacks from production Azure environments within hours. This wasn't a prank; it was a proof of concept that worked the first time they tried it.

The reason it worked is that PSGallery, unlike npm, does not have moniker rules at the registry layer. That isn't a failing of the PSGallery team. Moniker rules are a big lift, they have false-positive consequences for legitimate forks, and there are reasonable arguments about whether the registry or the publisher should own name hygiene. It's a shared-challenge problem we're all navigating.

Microsoft's in-progress answer at the registry layer — and if you want the deep version, Michael Green and Sydney Smith walked us through it at Summit last year — is the Microsoft Artifact Registry and PSResourceGet going over OCI. Structural fix: only Microsoft can publish under the MAR namespace, so you literally can't squat on `MAR/PSResource/Az.Accounts`. Different layer from this talk. It is also not shipped for most of what you install — today only the Azure PowerShell team is fully onboarded, and MAR doesn't help for community packages or third-party vendor modules. Which means if you care whether your package is confusable with someone else's, the check still has to live in your pipeline. We'll do it in forty minutes.

*[Slide 7 — Dependency confusion.]*

Second one. Dependency confusion. Close cousin of name confusion. Your org has an internal package — call it `AcmeSecrets`. It lives on an internal feed. An attacker notices you reference it in a public job log, in a workflow file, in a screenshot on a conference talk. [laugh beat] The attacker publishes a package with the same name to the public registry, with a higher version number. Next time your CI installs dependencies, the resolver picks the higher version. The higher version happens to be the attacker's.

Alex Birsan demonstrated this in 2021 against Apple, Microsoft, Tesla, PayPal, Shopify, Netflix, and a long list of others. Ten-thousand-dollar bug bounties all around. The PowerShell ecosystem has the same shape of risk the moment you have private modules with names that could be squatted publicly. The defense is to scope your resolver explicitly — internal feed is authoritative for internal names, and those names aren't resolvable externally even by accident. This is a publisher-side discipline question. The pipeline's job is to remind you when you've forgotten.

*[Slide 8 — Download-and-execute.]*

Third one. Download-and-execute. The install script fetches something at install time and runs it. The thing being fetched is not what was reviewed. The thing being reviewed is the *code that fetches*, not the code that runs.

This is the pattern. Hardcoded URL. `Invoke-WebRequest` into a variable. `Invoke-Expression` on the variable. Or the Chocolatey equivalent — `Install-ChocolateyPackage` with a URL but no checksum. Four lines. Each line on its own is legal PowerShell. Each line on its own is something you have probably written. The chain of four is remote code execution with no integrity guarantee.

Real incident: Serpent, 2022, targeting French organizations. Attackers used Chocolatey completely legitimately — installed Python through the real Chocolatey infrastructure — and then their own downstream tooling, running in the already-elevated context Chocolatey installs kick off, reached out and pulled a backdoor hidden in an image. Steganography. Chocolatey wasn't compromised. The pipeline around it had no idea what was executing.

The point I want you to sit with is that download-and-execute isn't exotic. It's normalized. Every vendor that ships a Chocolatey package wrapping a `.exe` installer is doing some version of this. The question isn't whether you download and execute. It's whether you pin what you downloaded against a hash you trusted at build time.

*[Slide 9 — Floating dependencies.]*

Fourth one. Floating dependencies. No single dramatic incident behind this one — it's the structural one, and that's what makes it scary.

Look at this `.psd1`. `RequiredModules` with `ModuleVersion = '2.0.0'`. That is not a pin. That is a floor. It means 'at least 2.0.0.' The consumer installs 'whatever is currently the highest version in PSGallery that satisfies the floor.' Monday's build and Tuesday's install can resolve to different dependency graphs with zero change to your code.

If you came from npm or cargo or Go, you already know what a lockfile is — byte-identical pin of every transitive dependency, checked into source, applied at install. `package-lock.json`. `Cargo.lock`. `go.sum`. PowerShell does not have this. Not a missing feature about to ship — a genuinely unsolved ecosystem problem. Which means every PowerShell SBOM you have ever seen is describing *the author's build*, not *the consumer's install*. That's a gap we're going to name again later, because it changes what our receipts actually mean.

No attacker required here. Normal day, different resolution, potentially different behavior. The attacker version is when a transitive dependency quietly changes ownership and the new owner decides to test what happens when a popular module starts calling home. Which has happened in every other ecosystem. [laugh beat] Just not to us yet. That we know of.

*[Slide 10 — Build-pipeline compromise.]*

Fifth one. Build-pipeline compromise. The scariest category, because the defenses you're used to trusting don't help you.

The attacker doesn't compromise the package. They don't compromise the vendor's code. They compromise the vendor's build environment. The installer that comes out is the real installer, from the real vendor, signed with the real code-signing cert — and it is already backdoored before anybody signs it. Every downstream check that asks 'is this from the vendor?' returns yes. Because it is.

Canonical incident: 3CX, 2023. Attackers compromised the build pipeline of a VoIP desktop app with around twelve million users. The signed installer the vendor distributed was already malicious. Every Chocolatey package that pointed at the official 3CX download URL — including perfectly well-maintained, well-intentioned ones — was distributing malware. The maintainers did nothing wrong. The checksums they had documented matched the file the vendor was serving. The file the vendor was serving was what the vendor meant to serve. The problem was one layer upstream.

The only defense here is in depth: pin hashes at build time, detect drift when they change, keep historical artifacts re-verifiable, and have provenance that lets you answer 'which of my builds consumed the bad upstream version.' None of those individually would have stopped 3CX. All of them together make the cleanup tractable instead of impossible.

*[Slide 11 — Secret leakage and artifact drift.]*

Sixth one, and then we move on. Secret leakage and artifact drift.

Secret leakage — Aqua Nautilus, same 2023 research. They found PSGallery publishers who had accidentally shipped `.git/config` with GitHub tokens. They found publishing scripts containing PSGallery API keys in *unlisted* packages — packages the authors thought they had hidden — still accessible via the PSGallery API after the authors thought they had removed them. Because unlisting changes search visibility, not API reachability. PSGallery has improved this since; they responded. But the existence of the keys in the first place was a publisher-side failure, not a registry-side failure. We shipped the secrets. The registry just made them reachable longer than we wanted.

Artifact drift — this is the `VERIFICATION.txt` story most of you in this room have hit at least once. Maintainer ships v1.0. Vendor URL documented. Checksum in `VERIFICATION.txt`. Vendor rotates the CDN six months later. Maintainer updates the URL in `chocolateyInstall.ps1`, regenerates the package, forgets `VERIFICATION.txt`. [laugh beat] `choco pack` succeeds. Package installs. `VERIFICATION.txt` now describes the previous binary. Anyone who verifies manually is reading a file that is lying to them — not maliciously, just out-of-date.

Malicious version: 3CX, which we just covered. Non-malicious version: every one of us, on a Thursday afternoon, under time pressure, hitting `choco pack` and hoping. The defense is the same in both cases: the pipeline recomputes what the file claims against what is actually on disk.

*[Slide 12 — What the registries already do.]*

Before we pivot to tooling, I want to spend a slide on what the registries are already doing, because I think the shared narrative in our industry has been unfair to them.

Chocolatey Community Repository runs a Validator for metadata and script structure. Runs a Verifier that actually performs install, upgrade, and uninstall in a reference environment — which is not free to operate. Runs VirusTotal. Has a human moderation pass for non-trusted packages. Most of that is volunteer time.

PowerShell Gallery runs manifest validation, installation testing during validation, antivirus scanning, and PSScriptAnalyzer at error level on every upload. That's a non-trivial amount of automated scrutiny on every module that lands.

This is real infrastructure. I am not recommending you skip it. I am not recommending the pipeline we're about to build replaces it. What I *am* recommending is that by the time your package arrives at one of these registries, you can hand the moderator three things they don't currently receive: an SBOM, scan results, a provenance document. Because the registries can't generate those retroactively — the source of truth is in the publisher's pipeline, and the publisher is *us*. [laugh beat: point at room] The receipts are ours to produce. That's the premise of the rest of the talk.

*[Slide 13 — The three questions.]*

Three questions a maintainer should be able to answer before publishing.

What's in this package? SBOM. What did you check? Scan results in SARIF. Can you prove when and how it was built? Provenance.

I want to be honest up front: the answers I can give today are different for each question, and different for each ecosystem. The SBOM story works better for Chocolatey packages with embedded binaries than for pure PowerShell modules. The provenance story — I can produce a receipt; nobody's reading it at install time yet. I'm going to come back to that honest accounting at the end. This is the part of the talk where we earn the right to make those admissions.

---

## Act II — Building the Receipts

*[Slide 14 — Flawed module. Switch to the repo browser.]*

PowerShell side first. This is the flawed module in the repo. I want you to read it for what it is: not cartoonishly broken. This is the shape of the thing that ships when you're the solo maintainer, it's Friday, your toddler has an ear infection, and the release has to go out today. [laugh beat]

Floating dependency in the psd1. `ScriptsToProcess` — same mechanism Aqua used in their typosquat PoC. Exported function with four labeled flaws. Pester passes. PSGallery would publish it. Everything that's wrong with this module is invisible to the tools in your CI right now. That's what to hold in your head.

*[Slide 15 — Multi-statement pattern.]*

This is the pattern I want you to remember from the PowerShell side. Four lines.

PSScriptAnalyzer — which PSGallery already runs at publish time, and which is an excellent piece of software written by people who understand PowerShell more deeply than I do — will flag line four. `Invoke-Expression` is a code-quality warning. One finding, one line.

What PSScriptAnalyzer is *not* doing — and isn't designed to do, because it's a linter — is reading these four lines as a sequence. It's not saying 'the thing being evaluated just arrived from the network.' It's not saying 'the credential feeding the network request is hardcoded two lines up.' It's not connecting 'TLS validation was disabled earlier in the function' to 'a subsequent HTTPS request is about to run with no certificate checks.'

Semgrep's job is to see this as one pattern. Multi-statement. Variable-binding. Cross-line. That's the difference. Not 'Semgrep is better than PSScriptAnalyzer.' They do different jobs. Linter versus security scanner. Run both.

If you want the author-hygiene version of this whole conversation in depth — PSScriptAnalyzer extensions, InjectionHunter, custom AST rules for PII, SecretManagement and SecretStore for credentials at rest — Rob Pleau's Summit 2025 session, "Stop Writing Insecure PowerShell," is the layer below this one. Watch it if you haven't. This talk assumes that layer of hygiene is already the baseline; what we're doing here is what shows up when you go to publish.

*[Slide 16 — Semgrep rule YAML.]*

This is what a Semgrep rule looks like. YAML, no plugin, no DSL. The `$X` is a metavariable — binds an identifier across lines, which is how the pattern matches assignment-then-exec even with other statements between them.

The rules live in `semgrep-rules/` in the repo. Twelve for PowerShell, twelve for Chocolatey. The authoring cost is low enough that if your team has patterns specific to your environment — and you do, I promise you do — you can add rules for them in an afternoon. Fork the repo, extend the YAML, send a PR if you want them upstream. I will merge it. That's a promise. [laugh beat]

*[Slide 17 — SARIF in the PR. Live browser. Fallback ready in second tab.]*

This is the output from the reviewer's side. Annotations inline in the diff. Aggregated in the Security tab. Filterable by tool and severity.

Dollar cost: zero. Setup: one `upload-sarif` step at the end of each scanning job. If you took one thing from this talk and put it in your pipeline next week, this is the thing — visibility in the PR, no new dashboard to train your team on. Because we all know how training your team on a new dashboard goes. [laugh beat]

*[Optional live beat: edit `Invoke-UnsafeFunction.ps1` on stage to introduce a slightly-changed flaw, commit, push, narrate for 60–90 seconds while the pipeline runs, show the annotation landing. Fallback: stay on the pre-populated PR, don't apologize for the switch — "here's one I prepared earlier" is fine.]*

*[Slide 18 — SBOM and the lockfile gap.]*

SBOM next. CycloneDX JSON, generated by Syft against the module directory. Components array, PURLs, resolved versions, file hashes. Useful as an audit trail.

Now the honest part — this is the lockfile gap from Act I finally landing. This SBOM records what I shipped. It does not record what resolves on the consumer's machine when they `Install-Module`. PowerShell has no lockfile. `Install-Module` resolves `RequiredModules` at install time against whatever is currently the highest-satisfying version in PSGallery. I ship Monday. You install Tuesday. Your dependency graph might differ from mine. My SBOM tells you what I built. It doesn't tell you what ran on your machine.

That is the single biggest unsolved problem in PowerShell supply chain security today, and I want to be clear: nobody on stage or in the registry team has a clever fix in their back pocket. Not me. Not PSGallery. Not Microsoft. The current workaround is to pin `RequiredVersion` — exact version — instead of `ModuleVersion`, and enforce with `dependency-pin-check`. That's a maintainer-side commitment, not a consumer-side guarantee. We come back to this in Act III.

*[Slide 19 — Grype.]*

Grype reads the SBOM. Runs it against NVD and the GitHub Advisory Database. Findings go back into Code Scanning.

Build-time value: obvious. Less-obvious value: retroactive. The SBOM is retained as an artifact for a year by default. When a CVE drops six months from now against a dependency you shipped, you re-run Grype against the stored SBOM from that release and you know in seconds which builds were affected. That is incident response, not prevention. Both matter — and in my experience, in an enterprise, the incident-response case is what actually gets this pipeline funded. Because leadership has sat through the other kind of incident, the one where you're trying to figure out *after the fact* whether a given build is exposed, and nobody has an answer, and everybody stays late. [laugh beat, knowing]

*[Slide 20 — Provenance, and the missing consumer.]*

Provenance. Source repo, commit SHA, workflow reference, artifact hash, timestamp. Here's the receipt.

Now. Who's reading this receipt? `Install-Module` doesn't check it. `choco install` doesn't check it. The registries don't require it at upload. No out-of-the-box verifier fires on package install today. I produce the provenance. The consumer never asks to see it.

That is a real problem with the current state of this, and I'm not going to pretend it isn't. What I can say is the provenance is useful *to the maintainer* right now. If a customer ever asks 'can you prove the module you shipped on this date came from this commit and was built by this pipeline,' I can answer. If an incident happens and I need to establish definitively which build produced which artifact, I have it. That's maintainer-side audit value — real, but narrower than an end-to-end story.

The full loop closes when the registries require signed provenance at upload and the install tooling verifies at install. Both are ecosystem-scale asks. Not my pipeline's problem to solve, and frankly, not any single pipeline's problem to solve. What I can do in the meantime is produce the receipts now, so the day a verifier ships, my back catalog is ready to be read. That's the bet.

*[Slide 21 — Actual run graph.]*

Full pipeline, end to end. Three and a half minutes cold, under two minutes once Grype's database is cached. Non-blocking by default. Every step is a composite action you can pull independently. You don't have to buy the whole pipeline.

*[Slide 22 — Chocolatey is different.]*

Switching to Chocolatey. Everything we just built applies. On top of that, Chocolatey tightens the threat model in three ways.

Install scripts run as admin. The package is typically a three-kilobyte wrapper around a fifty-megabyte external binary, which means the package's security is mostly the security of an external download. And moderation doesn't reach internal repositories, which is where a lot of Chocolatey is actually deployed — and where, again, the CCR volunteers can't help you, even if they wanted to.

That combination is why the Chocolatey pipeline adds three checks the PowerShell pipeline doesn't need.

*[Slide 23 — Flawed package.]*

This is the package from the cold open. nuspec with missing metadata and unpinned dependencies. Install script with the three flaws we looked at. `VERIFICATION.txt` with no checksums.

This is not a contrived example. This is the shape of something I have personally helped review in two different enterprises. [laugh beat, rueful] Both times the author was extremely senior. Both times the package had been in production for months. Neither time was the author trying to do anything wrong. They were trying to ship the thing.

*[Slide 24 — Naming validation.]*

Naming validation queries the CCR API, runs a Levenshtein similarity check against existing package names. Cheap to run. Narrow in what it catches — won't stop a determined attacker who's already published, but it catches accidental name collisions before you publish and surfaces potential typosquat conflicts during code review. Not going to spend long on this. Cheapest check in the pipeline. Moving on.

*[Slide 25 — Checksums + VERIFICATION.txt drift.]*

Three checks. Every external download has a checksum. Algorithm is SHA256 or better. And `VERIFICATION.txt` entries match the actual embedded files on disk.

Third check is the one I want you to notice. I told the drift story in Act I — maintainer ships, vendor rotates CDN, URL updated, `VERIFICATION.txt` forgotten. `choco pack` succeeds. Package installs. `VERIFICATION.txt` describes a binary that no longer exists. Nothing malicious. Just drift. Every one of us has done a version of this. [laugh beat]

Malicious version: 3CX, which we also already covered. Defense in both cases is the same: the pipeline recomputes file hashes at build time and flags when they don't match what's claimed in `VERIFICATION.txt`. This is the most specifically-Chocolatey check in the pipeline. It is also, in my experience, the one that catches the most real issues in internal-repo packages.

*[Slide 26 — Install-script analysis.]*

Four rule categories. Raw `Invoke-WebRequest` outside Chocolatey's helpers — bypasses Chocolatey's built-in checksum enforcement, which exists and is good, and if you're writing around it you should probably stop. [laugh beat] Registry writes and service creation without a documentation comment — in a script that runs as admin, the reviewer needs to know why. Hardcoded internal URLs — leaks your internal topology if the package ever leaves the internal repo. PATH modification without matching uninstall cleanup — that one gets its own slide.

*[Slide 27 — PATH story.]*

Install script appends `C:\tools\myapp` to the machine PATH. Uninstall script doesn't remove it. Six months later, someone uninstalls the package. PATH entry stays.

If that directory's ACLs ever let non-admins write to it — depending on the installer that created it, that happens more than you'd like — anyone with a local shell can drop a `git.exe`, a `python.exe`, a `node.exe` there. Windows PATH resolution finds them before the real ones. Next person who types `git` on that machine runs whatever got dropped.

Documented LPE precondition. Misconfigured PATH entry from a forgotten Chocolatey package is how it commonly gets set up. The Semgrep rule doesn't know whether the directory is writable. It knows the cleanup is missing. In a context where the script runs as admin, that's enough to make it reviewable — and it's the finding I most often see get fixed quietly with no fuss, because the author immediately recognizes the shape of the problem.

*[Slide 28 — Chocolatey run graph.]*

Chocolatey pipeline. Same five output artifacts as the PowerShell pipeline. Ecosystem-specific checks. Same shape.

---

## Act III — What's Still Missing, and Monday

*[Slide 29 — Three unsolved problems.]*

Now the honest accounting. Three things this pipeline does not solve.

One, the lockfile gap. Covered it. Chocolatey version is slightly better — `.nuspec` dependencies can be pinned to exact versions, `dependency-pin-check` enforces it. PowerShell version is worse, and no composite action I write is going to fix it. Real fix is a PowerShell lockfile, which is a platform-level change. If that's something you work on or can advocate for, this is me advocating for it.

Two, consumers aren't reading receipts. `Install-Module` and `choco install` don't verify provenance. Production of receipts runs ahead of verification. Gap closes when the registries require signed provenance at upload and clients verify at install. Both are ecosystem-level decisions — and CCR and PSGallery are in the room, they know it, and the answer to 'why haven't you shipped this yet' is always 'backward compatibility, resource constraints, and a careful rollout plan.' Which, when I was sysadmin-side of this conversation, I had opinions about. Now that I've been on the other side of ship-versus-don't-break-everyone decisions, I have more patience with the answer. [laugh beat]

The PSResourceGet team has been showing direction here — Michael Green and Sydney Smith at Summit last year walked through MAR, PSResourceGet over OCI, GPO allowlisting through Intune and Azure Policy. That's the closed-loop version of what we're producing receipts for: the client knows which registries to trust, the registry publishes signed artifacts with identity-level guarantees. It's not shipped everywhere — discovery across vendor registries, dependency resolution across MAR and PSGallery, and caching from the NuGet-v2 gallery into an OCI registry are all still open questions they're actively soliciting feedback on. The worthwhile thing I can do in the meantime is produce the receipts now, so the day a verifier ships, my back catalog is ready to be read.

Three, internal repositories. CCR has moderators. Your internal Chocolatey repo typically doesn't. In that context this pipeline isn't a complement to moderation — it is the moderation. That changes how seriously you should take enforcement. On a community package I'd say 'start non-blocking, tune, enforce when ready.' On an internal package shipped to thousands of endpoints with no human review — start blocking on critical checks immediately. Don't be polite with your own infrastructure.

*[Slide 30 — Monday morning.]*

Three steps for next week.

One, one afternoon: PSScriptAnalyzer with SARIF upload and Semgrep with one rule file, non-blocking. You'll see what fires. You will get false positives. Expect them. Do not open seventy-four Jira tickets on day one. [laugh beat]

Two, one afternoon, later the same week or next: SBOM and provenance generation. Both single-composite-action adoptions. Neither blocks anything — they produce artifacts.

Three, ongoing: tune rules, add suppressions with justifications, decide what blocks a merge.

What *not* to do on day one: don't turn on enforcement before you've seen the baseline. That is how security gates get disabled quietly three months later when the team gets tired of them. Visibility first. Enforcement after you've earned it.

*[Slide 31 — Repo + last line.]*

Repo is on screen. `examples/` has the flawed module and the flawed package. `actions/` has eight composite actions you can adopt individually. `semgrep-rules/` has the YAML rules. `docs/` has threat model, tooling decisions, enterprise integration, and a remediation guide for every finding type the pipeline surfaces. You don't need to have been in this room to use the repo. The decisions are written down — so when your VP of Engineering asks 'wait, why are we doing this?' six months from now, you have something to point at that isn't a hand-wave. [laugh beat]

That's the talk. Receipts are useful even when nobody reads them — until the day someone does.

I'll take questions.

*[Slide 32 — Q&A. Pause. Look up. Don't fill the silence.]*

While you're thinking, a few I get often:

How does this compare to Chocolatey's moderation? Complementary. Moderation is registry-side. This pipeline runs before your package reaches the registry. You want both. And the moderators would like you to send them packages that are easier to moderate. Everyone wins.

Does this work with Azure DevOps? Concepts are identical, tools are portable. The composite actions are GitHub-specific. The tools — PSScriptAnalyzer, Semgrep, Syft, Grype — run anywhere. SARIF upload is the main thing that changes.

What about internal Chocolatey repos? This is actually where the pipeline adds the most value. Internal repos typically have zero moderation. You're the only line of defense.

You work at Wiz — is this a vendor pitch? No, and let me say it plainly. Nothing in this pipeline depends on Wiz or any proprietary platform. Everything is free and open source. The reason runtime context matters — whether you use Wiz, a competing CSPM, or nothing — is that a CVE at build time doesn't tell you whether the vulnerable component is deployed, reachable, or running with privilege. That's a real gap, and somebody will close it. I have opinions about who. That's not the point of this talk. [laugh beat]

How do you handle legitimate `Invoke-WebRequest` usage that gets flagged? Inline suppression with justification. Flag everything, suppress with a comment explaining why it's intentional, the suppression ships in SARIF, reviewers see it in the PR.

Does this slow CI? Two to five minutes for a typical module or package. Most of that is Grype downloading its vulnerability database on first run. Caches after.

What else have you got?

---

## Demo and delivery notes

**Before the talk**

- Repo open in a browser tab with a PR whose pipeline results are already populated (fallback path).
- Second tab: a working checkout ready to edit and push (live path, optional).
- Pre-loaded tabs: repo overview, PR with SARIF annotations, Actions workflow run, SBOM artifact, provenance artifact.
- SARIF JSON, SBOM JSON, and provenance JSON open locally in an editor as deep fallback.
- Pre-warm Grype's cache on the demo machine.
- Test both workflows end-to-end at least twice in the week prior.
- Verify Grype has a non-empty finding set — add a dependency with a known CVE to the example module if needed, otherwise slide 19 lands on an empty table.

**Live demo beat (slide 17)**

If scheduling and Wi-Fi allow, live moment: edit `Invoke-UnsafeFunction.ps1` on stage to introduce a slightly-changed flaw, commit and push, narrate for 60–90 seconds while the pipeline runs, show the annotation landing in the PR. High reward, moderate risk.

Fallback: stay on the pre-populated PR, show the existing annotations, move on. Don't apologize or narrate the switch — "here's one I prepared earlier" is fine.

**Timing guide (90 minutes)**

| Section | Slides | Target |
|---------|--------|--------|
| Act I — Ecosystem gap + six threats | 1–13 | 22–25 min |
| Act II — Building (PowerShell) | 14–21 | 18–20 min |
| Act II — Building (Chocolatey) | 22–28 | 15–17 min |
| Act III — Unsolved + Monday | 29–31 | 10–12 min |
| Q&A | 32 | 10 min |

**If you fall behind**

Drop slides 7 (dependency confusion) and 19 (Grype) first. Dependency confusion can be folded into slide 6 as a two-sentence coda. Grype can be mentioned on slide 18 as "SBOM feeds a CVE scanner, here are the findings, moving on."

**If you finish early**

Go deeper on any of the three unsolved problems in Act III — each could be its own 20-minute talk and a Chocolatey Fest audience will have specific questions about internal-repo enforcement in particular. Take them.

---

## Summary of changes from ANALYSIS.md (first pass) to ANALYSIS2.md (this pass)

- **Threat landscape front-loaded and expanded.** First pass compressed six threats into one five-row table. This pass gives each category a dedicated slide with analogy + incident + plain-language "why our ecosystem is susceptible." Slide 5 is a new taxonomy overview; slides 6–11 are the six threats individually. The five-row table is absorbed into the six-slide walk.
- **PSGallery and CCR framed as allies.** Every mention is explicit that the registry teams are doing non-trivial work, that the gap is the layer *before* their work, and that responsibility for provenance lives with the publisher. Specific softening on slide 12 ("the registries can't generate these retroactively"), slide 18 ("not PSGallery, not Microsoft"), and slide 29 ("backward compatibility, resource constraints, a careful rollout plan").
- **Humor added where it's earned.** Roughly a dozen `[laugh beat]` moments, each rooted in recognition: the Friday-afternoon release, the seventy-four Jira tickets, the new-dashboard-training joke, the "we shipped the secrets" admission, the CDN-rotation mistake Adil owns personally. No punching down. No vendor jokes.
- **Three-act structure preserved.** Act names unchanged. Narrative arc unchanged. Cold-open-on-a-realistic-Chocolatey-package preserved from first pass. Lockfile-gap admission and provenance-consumer admission preserved.
- **Slide count 31, up from 28 in first pass.** The extra three slides all land in the threat-landscape section. Everything else compressed or left as-is.
- **Original's spirit kept where the first pass over-corrected.** The two-column "what the registries already do" slide returns with equal visual weight. The naming-validation slide returns as a short beat rather than being cut entirely. The "Receipts. Not just a green checkmark." framing is retained in the closing.
- **Prior-art references added at the layer boundaries.** Three places where the talk now points outward: slide 6 credits Michael Green and Sydney Smith's Summit 2025 "PSResourceGet Direction" session for the MAR / OCI / GPO story at the registry layer; slide 15 credits Rob Pleau's Summit 2025 "Stop Writing Insecure PowerShell" for the author-hygiene layer below this one; slide 29 returns to the PSResourceGet direction as the closed-loop answer to the "nobody's reading receipts at install time" problem. One or two sentences each — collegial, signposting, not bibliography.
