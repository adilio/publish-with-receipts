# Talk Track — Provenance Before Publish

**Event:** Chocolatey Fest 2026 (PowerShell + DevOps Global Summit 2026, Bellevue, WA)
**Duration:** 90 minutes (75 min content + 10 min Q&A + 5 min buffer)
**Format:** Technical deep-dive — slides, one live demo beat, Q&A

Each section below maps to a slide in `presentation.md`. This is a speaker track, not a read-aloud script — spoken voice, not paragraphs. Stage directions are in italics.

Revised structure (see `ANALYSIS.md` for the reasoning):

- **Act I — The Ecosystem Gap** (slides 1–8, ~20 min)
- **Act II — Building the Receipts** (slides 9–23, ~40 min)
- **Act III — What's Still Missing and Monday Morning** (slides 24–27, ~15 min)
- **Q&A** (slide 28, ~10 min)

---

## Act I — The Ecosystem Gap

### Slide 1 — Title

*Walk up. Let the title sit for two beats. Sip of water.*

"Thanks for coming. I know you had five options this slot. I'll try to make this worth the choice."

---

### Slide 2 — Sponsors

*15 seconds.*

"Quick thank-you to the sponsors — the room you're sitting in and the lunch you're about to eat are courtesy of them. You know the drill."

---

### Slide 3 — The package that passed every check

*Pull up the browser view. A realistic-looking Chocolatey package, green checks all the way down.*

"Here's where we're starting. This is a Chocolatey package I built last night in my lab. Three kilobytes. It installs a binary from a CDN. It runs as admin. It wrote to the registry. It modified PATH. Every automated gate I threw at it came back green.

`choco pack` succeeded. The Chocolatey extension's `Test-PackageForVerification` sees nothing wrong. If I'd submitted to the community repository, the Validator would have approved it and the Verifier would have confirmed it installs. A human moderator might have caught something. Probably not everything. If I'd submitted to an internal repo — which is where most of you are actually publishing — nothing would have caught any of it, because internal repos don't have moderators. They have whoever you designated, which is frequently nobody.

Let me show you what it actually does."

---

### Slide 4 — What it actually does

*Three callouts on the install script. Walk each one slowly.*

"Three things this package does that nothing in your current toolchain catches.

One: it downloads a binary over HTTP from a vendor URL with no checksum. If that URL ever serves something different — because the vendor rotated the CDN, because the CDN was compromised, because a maintainer updated the URL without updating the docs — that different binary runs on every machine that installs this package, as admin, and nobody is told.

Two: it appends a directory to the machine PATH and there's no corresponding cleanup in the uninstall script. Someone uninstalls the package six months from now — the PATH entry stays forever. If that directory was ever writable by non-admins — and depending on which installer created it, that happens more than you'd like — anyone with local shell access can drop a `git.exe` there. Windows PATH resolution finds the planted binary before the real one. Next person who types `git` on that machine runs whatever was dropped. That's a real local privilege escalation pattern. It's been used in the wild. It starts with a forgotten Chocolatey package.

Three: it writes a registry value containing what looks like a corporate internal URL. If this package ever leaves the internal repo — gets copied, gets accidentally published to CCR, gets handed to a customer — that URL is in every install that runs.

`choco install` prints 'The install was successful.' It always prints that. That is also what it prints when nothing weird happened. The output is the same in both cases. That's the problem."

---

### Slide 5 — The gap this talk is about

*One sentence on screen, large.*

"That's the talk. The gap I'm here to talk about is that PowerShell and Chocolatey both lack the enforcement plumbing that every other major package ecosystem took for granted years ago.

No lockfile. No moniker rules. `VERIFICATION.txt` is a norm, not a contract. Moderation doesn't scale to internal repositories. This is not a critique of the people running the community repo or PSGallery — both teams are doing real work. The issue is the layer *before* their work. By the time a package reaches moderation, the receipts have not been generated, and the registries cannot produce them retroactively. That has to happen in your pipeline."

---

### Slide 6 — What the registries already do

*Two columns: CCR vs. PSGallery, compressed.*

"Before we move on — credit where it's due.

The Chocolatey community repository runs a Validator for metadata and script structure, a Verifier that actually installs, upgrades, and uninstalls in a reference environment, a VirusTotal scanner, and a human moderation pass for non-trusted packages.

PSGallery runs manifest validation, installation testing during validation, antivirus scanning, and PSScriptAnalyzer at error level.

This is real infrastructure. I'm not recommending you skip it. I'm recommending that by the time your package arrives at one of these registries, you can hand the moderator three things they don't currently receive: an SBOM, a set of scan results, and a provenance document."

---

### Slide 7 — The three questions

"Those three things answer three questions.

What's in this package? That's the SBOM.
What did you check? Scan results, in SARIF.
Can you prove when and how it was built? That's provenance.

We're going to build each of those in the next forty minutes. I also want to be honest with you up front: the answers I can give today are different for each question and different for each ecosystem. The SBOM story works better for Chocolatey packages with embedded binaries than it does for pure PowerShell modules. The provenance story — I can produce a receipt; nobody's reading it at install time yet.

We're going to come back to that honest accounting at the end of the talk."

---

### Slide 8 — Five threats with real incidents

*Table on screen: five threats, five incidents, five reasons the ecosystem is susceptible.*

"Five threats. Each one has a real incident behind it.

**Name impersonation.** Aqua Nautilus registered `Az.Table` — with a dot — in 2023 to impersonate the popular `AzTable` module, 10 million downloads. Got callbacks from production Azure environments within hours. PSGallery has no moniker rules. npm does. cargo does. PSGallery doesn't.

**Download-and-execute.** Serpent malware campaign, 2022. Targeted French organizations. Used Chocolatey legitimately — it installed Python and pip — then deployed a backdoor via steganography. Chocolatey wasn't compromised. The pipeline around it had no idea what was executing.

**Floating dependency.** No single dramatic incident. This one is structural. PowerShell has no lockfile. `RequiredModules` with `ModuleVersion` is a minimum, not a pin. Monday's build and Tuesday's build can resolve different dependency graphs with no change in your code.

**Unverified binary drift.** 3CX supply chain compromise, 2023. Attackers compromised the vendor's build environment. The signed installer the vendor distributed was already backdoored. Every Chocolatey package pointing at the official 3CX URL was distributing malware.

**Secret leakage.** Aqua's PSGallery research, same 2023 paper. Found publishers who had accidentally uploaded `.git/config` with GitHub API keys, and publishing scripts containing PSGallery API keys, in unlisted packages. Still accessible via the PSGallery API after the authors thought they'd removed them.

I'm going to map the rest of the talk to this table. Each row gets addressed by at least one check in the pipeline we're about to build."

---

## Act II — Building the Receipts

### Slide 9 — The flawed module

*Switch to the repo browser. Open `examples/powershell-module/ExampleModule/`.*

"PowerShell side first. This is the flawed module in the repo. Not cartoonishly broken — this is the shape of what ships when you're the solo maintainer and moving fast.

Floating dependency in the `.psd1`. `ScriptsToProcess` — same mechanism Aqua used in their typosquat PoC. An exported function with four labeled flaws. Tests pass. PSGallery would publish it. Everything that's wrong with this module is invisible to the tools in your CI right now."

---

### Slide 10 — The multi-statement pattern

*Four lines of code on screen: hardcoded key, TLS bypass, `Invoke-WebRequest`, `Invoke-Expression`.*

"This is the pattern I want you to remember from the PowerShell side of the talk. Four lines.

PSScriptAnalyzer, which PSGallery already runs, will flag line four — `Invoke-Expression` is a code-quality warning. One finding, one line.

What PSScriptAnalyzer is *not* doing — and is not designed to do — is reading this as a sequence. It's not saying 'the thing being evaluated just arrived from the network.' It's not saying 'the credential feeding the network request is hardcoded two lines up.' It's not connecting 'TLS validation was disabled earlier in the function' to 'a subsequent HTTPS request is about to run in a session with no certificate checks.'

Semgrep's job is to see this as one pattern. Multi-statement. Variable-binding. Cross-line. That's the difference. Not 'Semgrep is better than PSScriptAnalyzer' — they do different jobs. Linter versus security scanner. Run both."

---

### Slide 11 — A Semgrep rule, unabridged

*Full YAML of the `invoke-expression-from-web` rule.*

"This is what a Semgrep rule looks like. YAML. No plugin, no DSL, no IDE dependency. The `$X` metavariable binds an identifier across lines — that's how the pattern matches assignment-then-exec even with other statements between them.

The rules live in `semgrep-rules/` in the repo. Twelve for PowerShell, twelve for Chocolatey. The authoring cost is low enough that if your team has patterns specific to your environment, you can add rules for them in an afternoon. Fork the repo, extend the YAML, send a PR if you want them upstream."

---

### Slide 12 — Live SARIF in the PR

*[LIVE DEMO BEAT] Switch to a live browser tab. Show a PR with inline SARIF annotations.*

"Here's what the output looks like from the reviewer's side. Annotations inline in the diff. Aggregated in the Security tab. Filterable by tool or severity.

The dollar cost of this is zero. The setup is one `github/codeql-action/upload-sarif` step at the end of each scanning job. If you took one thing from this talk and put it in your pipeline next week, this is the thing — visibility in the PR, no dashboard to train your team on."

*[Optional live push: if scheduling allows, edit a file here to introduce a new finding, push, and let the pipeline catch it while you're still talking. Fallback: stay on the pre-populated PR.]*

---

### Slide 13 — The SBOM, and the gap inside it

*CycloneDX JSON on screen. `components` array visible.*

"SBOM next. CycloneDX JSON, generated by Syft against the module directory. Components array. PURLs. Resolved versions. File hashes. Useful as an audit trail.

Now the honest part. This SBOM records what I shipped. It does *not* record what resolves on the consumer's machine when they `Install-Module` this thing.

PowerShell has no lockfile. `Install-Module` resolves `RequiredModules` at install time against whatever is currently the highest-satisfying version in PSGallery. I ship Monday, you install Tuesday, you might have a different dependency graph than my build produced. My SBOM tells you what I built. It doesn't tell you what ran on your machine.

That's the lockfile gap. It's the single biggest unsolved problem in PowerShell supply chain security today. No tool on this pipeline fully closes it. The closest current workaround is to pin `RequiredVersion` — the exact version — instead of `ModuleVersion`, and enforce that pinning with `dependency-pin-check`. That's a maintainer-side commitment, not a consumer-side guarantee.

We'll come back to what a real fix would look like in Act III."

---

### Slide 14 — Vulnerability scan, retroactively

"Grype reads the SBOM, runs it against NVD and the GitHub Advisory Database, findings go back into Code Scanning.

Build-time value is obvious. The less-obvious value is retroactive. The SBOM is retained as an artifact for a year by default. When a CVE drops six months from now against a dependency you shipped, you re-run Grype against the stored SBOM from that release and you know in seconds which builds were affected. That's incident response, not prevention. Both matter — and in my experience the incident-response case is what gets this pipeline funded in an enterprise, not the build-time gating."

---

### Slide 15 — Provenance, and the missing consumer

*Provenance JSON on screen. Source repo, commit SHA, workflow ref, artifact hash.*

"Provenance. Here's the receipt.

Now. Who's reading this receipt? `Install-Module` doesn't check it. `choco install` doesn't check it. The registries don't require it at upload. No install-time verifier ships in the ecosystem today.

I produce the provenance. The consumer never asks to see it.

That's a real problem with the current state of this, and I'm not going to pretend it isn't. What I can say is the provenance is useful *to the maintainer* right now. If a customer ever asks 'can you prove the module you shipped on this date came from this commit and was built by this pipeline,' I can answer. If an incident happens and I need to establish definitively which build produced which artifact, I can.

That's maintainer-side audit value — real but narrower than an end-to-end story. The full loop closes when the registries require signed provenance at upload and the install tooling verifies at install. Both are ecosystem-scale asks. They're not my pipeline's problem. What I can do in the meantime is produce the receipts now so that the day a verifier ships, my back catalog is ready to be read."

---

### Slide 16 — PowerShell pipeline — actual run

*Screenshot of the real Actions run graph with step timings.*

"Full pipeline end to end. Three and a half minutes on a cold runner, under two minutes once Grype's database is cached. Non-blocking by default. Every step is a composite action you can pull independently — you can adopt any one of these without the others."

---

### Slide 17 — Chocolatey changes the threat model

"Switching to Chocolatey. Everything we just built applies. On top of that, Chocolatey tightens the threat model in three ways.

Install scripts run as admin. The package is typically a thin wrapper around a binary the install script fetches — so the package's security is mostly the security of an external download. And moderation doesn't reach internal repositories, which is where a lot of Chocolatey is actually deployed.

That combination is why the Chocolatey pipeline adds three checks the PowerShell pipeline doesn't need."

---

### Slide 18 — The flawed package

*Brief walk through `examples/chocolatey-package/`.*

"This is the package from the cold open. Nuspec with missing metadata and unpinned dependencies. Install script with the three flaws we already looked at. `VERIFICATION.txt` with no checksums."

---

### Slide 19 — Naming validation

"Naming validation queries the CCR API and runs a Levenshtein similarity check against existing package names. Cheap to run. Narrow in what it catches — won't stop a determined attacker who's already published, but it catches accidental name collisions before you publish and surfaces potential typosquat conflicts in code review.

Not going to spend long on this. It's the cheapest check in the pipeline. Moving on."

---

### Slide 20 — Checksums + VERIFICATION.txt drift

"Three checks. Every external download has a checksum. The algorithm is SHA256 or better. And `VERIFICATION.txt` entries match the actual embedded files on disk.

That third check is the one I want you to notice. Imagine this — and this isn't a malicious scenario, just maintenance drift. Maintainer ships v1.0. Download comes from the vendor's official CDN, checksum documented, `VERIFICATION.txt` matches. Six months later the vendor rotates the CDN, URL changes, maintainer updates the install script, regenerates the package, forgets to update `VERIFICATION.txt`. `choco pack` succeeds. Package installs. `VERIFICATION.txt` now describes the previous binary. Anyone who checks it manually is reading stale data. The pipeline catches this at build time by recomputing hashes against the actual files.

The malicious version of that same scenario is 3CX, 2023. Attackers compromised the vendor's build environment, the signed installer was already backdoored, every Chocolatey package pointing at the official 3CX CDN was serving malware. If your pipeline doesn't verify what it downloaded against a hash you established at build time, you can't detect that the binary changed."

---

### Slide 21 — Install-script analysis

"Four rule categories. Raw `Invoke-WebRequest` outside Chocolatey's helpers — bypasses Chocolatey's built-in checksum enforcement. Registry writes and service creation without a documentation comment — in a script that runs as admin, the reviewer needs to know why. Hardcoded internal URLs — leaks your internal topology if the package ever leaves the internal repo. PATH modification without matching uninstall cleanup — this one deserves its own slide."

---

### Slide 22 — The PATH story

*Diagram: PATH append → missing uninstall cleanup → writable directory → planted `git.exe` → LPE.*

"Install script appends `C:\tools\myapp` to the machine PATH. Uninstall script doesn't remove it. Six months later, someone uninstalls the package. PATH entry stays.

If that directory's ACLs ever let non-admins write to it — and depending on the installer that created it, that happens more than you'd like — anyone with a local shell can drop a `git.exe`, a `python.exe`, a `node.exe` there. Windows PATH resolution finds them before the real ones. The next person who types `git` on that machine runs whatever was dropped.

That's a documented LPE precondition, and a misconfigured PATH entry from a forgotten Chocolatey package is a common way it gets set up. The Semgrep rule doesn't know whether the directory is writable. It knows the uninstall cleanup is missing. In a context where the script runs as admin, that's enough to make it reviewable."

---

### Slide 23 — Chocolatey pipeline — actual run

*Actions run graph for the Chocolatey workflow.*

"Chocolatey pipeline. Same five output artifacts as the PowerShell pipeline — two SARIF reports, an SBOM, Grype results, provenance. Ecosystem-specific checks. Same shape."

---

## Act III — What's Still Missing, and Monday

### Slide 24 — Three unsolved problems

"Now the honest accounting. Three things this pipeline does not solve.

**One, the lockfile gap.** We covered it. The Chocolatey version is slightly better — `.nuspec` dependencies can be pinned to exact versions, and the pipeline's `dependency-pin-check` enforces it. The PowerShell version is worse, and no composite action I write is going to fix it. The real fix is a PowerShell lockfile, which is a platform-level change.

**Two, consumers aren't reading receipts.** `Install-Module` and `choco install` don't verify provenance. Production of receipts runs ahead of verification. That gap closes when the registries require signed provenance at upload and clients verify at install. Both are ecosystem-level decisions. The worthwhile thing I can do in the meantime is produce the receipts now so that the day a verifier ships, my back catalog is ready.

**Three, internal repositories.** CCR has moderators. Your internal Chocolatey repo typically doesn't. In that context this pipeline is not a complement to moderation — it *is* the moderation. That changes how seriously you take enforcement. On a community package I'd say 'start non-blocking, tune, enforce when ready.' On an internal package shipped to thousands of endpoints with no human review — start blocking on critical checks immediately. Don't be polite with your own infrastructure."

---

### Slide 25 — Monday-morning adoption path

"Three steps for next week.

One, one afternoon: add PSScriptAnalyzer with SARIF upload and Semgrep with one rule file, non-blocking. You'll see what fires. You will get false positives. Expect them.

Two, one afternoon, later the same week or next: add SBOM and provenance generation. Both are single-composite-action adoptions. Neither blocks anything — they produce artifacts.

Three, ongoing: tune rules, add suppressions with justifications, decide which findings block a merge.

What *not* to do on day one: don't turn on enforcement before you've seen the baseline. That's how security gates get disabled quietly three months later when the team gets tired of them. Visibility first. Enforcement after you've earned it."

---

### Slide 26 — The repo

"Repo's on screen. `examples/` has the flawed module and the flawed package. `actions/` has eight composite actions you can adopt individually. `semgrep-rules/` has the YAML rules. `docs/` has the threat model, tooling decisions, enterprise integration, and a remediation guide for every finding type the pipeline surfaces.

You don't need to have been in this room to use the repo. The decisions are written down."

---

### Slide 27 — Last line

"Receipts are useful even when nobody reads them — until the day someone does.

That's the talk. I'll take questions."

---

### Slide 28 — Q&A

*Pause. Look up. Don't fill silence.*

"Few I get often, while you're thinking:

- **'How does this compare to Chocolatey's moderation?'** Complementary. Moderation is registry-side. This pipeline runs before your package reaches the registry. You want both.
- **'Does this work with Azure DevOps?'** Concepts are identical, tools are portable. The composite actions are GitHub-specific. Porting the workflows is straightforward — the tools (PSScriptAnalyzer, Semgrep, Syft, Grype) all run anywhere. SARIF upload is the main thing that changes.
- **'What about internal Chocolatey repos?'** This is actually where the pipeline adds the most value. Internal repos typically have zero moderation. You're the only line of defense.
- **'You work at Wiz — is this a vendor pitch?'** No, and let me say it plainly. Nothing in this pipeline depends on Wiz or any proprietary platform. Everything is free and open source. The reason runtime context matters at all — whether you use Wiz, a competing CSPM, or nothing — is that a CVE at build time doesn't tell you whether the vulnerable component is actually deployed, reachable, or running with privilege. That's a real gap, and somebody in the industry is going to close it. I have opinions about who. That's not the point of this talk.
- **'How do you handle legitimate `Invoke-WebRequest` usage that gets flagged?'** Inline suppression with justification. Flag everything, suppress with a comment explaining why it's intentional, the suppression ships in SARIF and is visible in the PR.
- **'Does this slow CI?'** Two to five minutes for a typical module or package. Most of that is Grype downloading its vulnerability database on first run. Caches after that.

What else have you got?"

---

## Demo notes

### Before the talk

- Repo open in a browser tab with a PR that has pipeline results already populated (fallback path).
- Second tab: a working checkout ready to edit and push (live path, optional).
- Pre-loaded tabs: repo overview, PR with SARIF annotations, Actions workflow run, SBOM artifact, provenance artifact.
- SARIF JSON, SBOM JSON, and provenance JSON open locally in an editor as deep fallback if the browser dies.
- Pre-warm Grype's cache on the demo machine.
- Test both workflows end to end at least twice in the week prior.
- Verify Grype has a non-empty finding set — add a dependency with a known CVE to the example module if needed, otherwise slide 14 lands on an empty table.

### Live demo beat (slide 12)

If scheduling and Wi-Fi allow, the live moment is: edit `Invoke-UnsafeFunction.ps1` on stage to introduce a slightly-changed flaw, commit and push, narrate for 60–90 seconds while the pipeline runs, show the annotation landing in the PR. High reward, moderate risk.

Fallback: stay on the pre-populated PR, show the existing annotations, move on. Don't apologize or narrate the switch — "here's one I prepared earlier" is fine.

### Timing guide (90 minutes)

| Section | Slides | Target |
|---------|--------|--------|
| Act I — Ecosystem gap | 1–8 | 18–20 min |
| Act II — Building (PowerShell) | 9–16 | 20–22 min |
| Act II — Building (Chocolatey) | 17–23 | 15–18 min |
| Act III — Unsolved + Monday | 24–27 | 10–12 min |
| Q&A | 28 | 10 min |

### If you fall behind

Drop slides 14 and 19 first — both are single-beat slides whose content can be folded into the next slide. Grype (14) can be mentioned briefly on slide 13 as "SBOM feeds a CVE scanner, here are the findings in Code Scanning, moving on." Naming validation (19) can be mentioned in a single sentence at the top of slide 20.

### If you finish early

Go deeper on any of the three unsolved problems in Act III — each could be its own 20-minute talk and the audience at Chocolatey Fest will have specific questions about internal-repo enforcement in particular. Take them.
