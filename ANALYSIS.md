# ANALYSIS — Provenance Before Publish

A no-mercy review of the talk as it currently exists, followed by a revised structure, slide deck, and talk track.

The talk is a 90-minute Chocolatey Fest session at PowerShell + DevOps Global Summit 2026 (Apr 13–16, Bellevue, WA). Audience: Chocolatey and PowerShell practitioners who take packaging seriously, skew senior, and will not be charmed by vendor-ware or by being told things they already know.

---

## PHASE 1 — Brutal Honest Critique

### 1. Concept validity

**The thesis is okay. It isn't sharp.**

"Three receipts: SBOM, scan results, provenance" is a competent frame. It's also the frame every supply chain talk in 2024 and 2025 used. It isn't wrong, but as a reason to sit in a room for 90 minutes, it has a "we've heard this" problem.

What the talk is actually saying — and failing to say loudly enough — is narrower and better: *the PowerShell and Chocolatey ecosystems lack the mundane plumbing (lockfiles, enforced VERIFICATION, moniker rules, signed provenance verification at install time) that npm, cargo, Maven, and the container world already take for granted.* The audience knows this in their bones. Nobody has put it to them plainly. That is the talk that would land.

Instead, the current framing is "here's a pipeline I built." A pipeline is a shape you can ship, not a thesis. The audience will walk out remembering the shape, not the argument.

**Specific thesis weaknesses:**

- Slide 7 (`## The Thesis`) lists the three questions as equally weighted. They aren't. For Chocolatey packages the SBOM + provenance story is strong. For pure PowerShell modules, as the talk track honestly admits on line 105, "that advisory database coverage doesn't exist yet." If a third of the thesis doesn't work for half the talk, the thesis is wrong-shaped.
- "Not a green checkmark. Receipts." is a nice line. But nobody is going to *verify* those receipts — `slsa-verifier` is never invoked by a real Chocolatey consumer on a real install. The talk mentions this obliquely on slide 23 (the consumer "hashes the artifact they have, compare it to `artifact_hash`"), but that isn't a thing that happens. If the receipts are unclaimed, why are we writing them?

The talk needs to either (a) acknowledge the receipts-are-one-sided problem directly and make *that* the interesting part, or (b) narrow the thesis to "receipts for the maintainer's own auditability and incident response," which is a defensible smaller claim.

### 2. Audience fit

This is Chocolatey Fest. 7 of 39 slides are Chocolatey-specific (25–31). The other 32 are generic supply chain + PowerShell module content. That ratio is wrong for the room.

The Chocolatey-specific material that *is* there is also shallow in places:

- Slide 28 (Naming Validation) explains Levenshtein distance. This audience knows what Levenshtein distance is. They want to know: *how noisy is this check in practice? What percentage of CCR packages would it flag today?* The talk never says.
- Slide 29 (Checksum & Integrity Check) correctly notes MD5/SHA1 are deprecated. This audience knows. What they want: *how many community repo packages still use MD5? Is that trending down? What's the CCR Validator's current posture on weak checksums?* Again, the talk doesn't say.
- Slide 30 (Install Script Analysis) lists four rule categories. It doesn't show the rules, doesn't show what typical internal-repo packages trip, and doesn't show the false-positive rate. The audience has written Chocolatey install scripts. They've hit these rules already, mentally. They want data, not categories.

The deeper problem: the talk treats the audience as people who need to be taught *that* supply chain matters. This audience — Chocolatey Fest attendees at Summit, in 2026, after three years of headline-grade package-ecosystem attacks — has been convinced for a while. Teach them something about their *specific* ecosystem they haven't seen framed this way before.

### 3. Talk structure and flow

The four-section shape (Problem Space → PowerShell Pipeline → Chocolatey Pipeline → Bigger Picture) is reasonable. Its execution has several problems:

**The threat model is a list, not a narrative.** Slides 10–15 are "Threat 1, Threat 2, Threat 3, Threat 4, Threat 5, Threat 6." Each gets one slide. They are formatted identically. By Threat 4 the audience has lost the plot because there's no dramatic arc connecting them. The Serpent anecdote on Threat 2 is the strongest story and it's buried behind the first three.

**The tool parade.** Slides 18–23 are PSScriptAnalyzer, Semgrep, Syft, Grype, Provenance, one per slide, in sequence. This is the textbook structure of a vendor demo. A deep-dive audience will mentally compile this to "five open-source tools stitched together with Actions" and check out.

**The `Why Not Just PSScriptAnalyzer?` slide (19) is defensive.** It pre-empts a skeptic question. That's a tell — the speaker is worried the audience will reject the framing. The correct response to that worry is to just *show* a pattern PSScriptAnalyzer misses and Semgrep catches. The audience will conclude the thing you wanted them to conclude. Don't argue it on a slide.

**The "Connecting to the Bigger Picture" section is where attention dies.** Slide 34 (Runtime Context Changes Everything) is the Wiz moment — "Without it: 'Critical CVE in dependency X' / With Wiz/CSPM: ..." Adil works at Wiz. A room of senior engineers will clock the vendor pitch immediately. This isn't fatal, but it is the moment where the cynics disengage and the charitable audience members grow quietly cooler.

**Opening is weak.** Slide 1 is a title, Slide 2 is a thank-you-sponsors, Slide 3 is "What We're Covering." The talk doesn't start until slide 6 or 7. A deep-dive audience at a conference this far in will give you maybe three minutes of benefit-of-the-doubt attention before they judge whether this is going to be worth the 87 minutes that follow. The current opening spends those minutes on orientation and gratitude, not on hooking the room.

**Closing is a whimper.** Slide 38 ("Provenance Before Publish" — a repeat of slide 7) and Slide 39 (Questions?). The call to action is passive. The "Realistic Adoption Path" on slide 35 is the right content but it's five slides before the end and framed as a bulleted checklist.

**Pacing feels off.** 15 slides (~40% of the deck) before Section 2 — that's a long intro. The Chocolatey section is 7 slides in what should be the meat of a Chocolatey Fest session.

### 4. Slide content and speaker notes — specific callouts

- **Slide 2 (`## Thanks!` sponsors slide):** Sits between the title and the agenda. This is structurally fine at conferences that require it, but it breaks the narrative momentum. Keep it, but place a real hook slide after it, not an agenda.
- **Slide 3 (`## This Talk Is For You If...`):** The "raise your hand" bit in the track is a good read-the-room move, but the slide content itself is a filter — four bullet points describing who should stay. This is a way of announcing the talk hasn't started yet. Cut it or compress it into the opening line.
- **Slide 4 (`## The Gap`):** ASCII-art diagram inside a code block. The `← YOU ARE HERE` arrow is cute once. The diagram doesn't earn the slide — same content could live in one sentence. And "you are here" framing assumes the audience is the build engineer, which most package maintainers aren't formally.
- **Slide 7 (`## The Thesis`):** "Three questions you should answer before publishing" — fine. But this is the thesis slide and it is hidden on slide 7 behind six slides of context. Move it earlier or re-use it as the bookends.
- **Slide 9 (`## Six Threats`):** Just a list with a "each one is detectable" closer. Pure setup. Could be absorbed into slide 10's opener.
- **Slide 12 (Floating Dependencies):** The talk track on this is the sharpest single passage in the whole deck ("no dramatic incident. Just: different version resolved Monday vs. Tuesday"). But the *slide* underweights it — two code lines and three bullets. This is the threat with the least audience-intuitive danger and the slide should earn it.
- **Slide 15 (Threat 6 — Unsafe Install Patterns):** The PATH-based LPE chain in the talk track (writable `C:\tools` dir, `git.exe` planted, local priv-esc) is a *great* story. It is not on the slide. The slide just shows a PATH-append code block.
- **Slide 17 (`## The Example Module`):** A table with three rows. The point of a demo-module slide is to let the audience see the code. This is a table describing the code. Show the code, or cut the slide and do it in the browser.
- **Slide 18 (`## Step 1: PSScriptAnalyzer`):** The speaker-note block here is the best written piece of prose on any slide — genuinely tight and useful. The slide itself is three bullets and a callout. Imbalance: the notes work, the slide doesn't.
- **Slide 19 (`## Why Not Just PSScriptAnalyzer?`):** Defensive. Cut.
- **Slide 20 (Semgrep Rule Example):** A good slide — shows an actual rule. Keep and enlarge its role.
- **Slide 21 (`## Step 3: SBOM with Syft`):** The "lockfile gap" callout inside this slide is the single most honest and interesting statement in the deck. It admits the PowerShell SBOM story is structurally incomplete. Extract it. Give it its own slide. Make it a *thing* the talk deals with, not a quiet footnote inside a tool-step slide.
- **Slide 24 (PowerShell Pipeline — Full Picture):** Another ASCII diagram. Fine, but not memorable. A screenshot of the actual GitHub Actions run graph with timings would earn the slide.
- **Slide 30 (Install Script Analysis):** Just a bulleted list of rule categories. The talk-track prose behind it is much better than what's on the slide.
- **Slides 33–34 (Three Integration Tiers, Runtime Context):** Vendor-pitch zone. Either rewrite to remove Wiz by name or re-cast the section around the general problem ("here's why build-time findings need runtime context — no matter whose platform you're using").
- **Slide 35 (Realistic Adoption Path):** Good content, wrong location. This should land right before the closing statement so the audience leaves with concrete first steps, not after a vendor-adjacent slide.
- **Slide 38 (`## Provenance Before Publish`):** Repeats slide 7 in different formatting. Pick one. Lose the other.

**Speaker notes in general:** The `talk-track.md` file is substantively better than the deck. The prose is direct, specific, cites real incidents, and does the work the slides don't. This is a good problem to have — it means the raw material for a better deck already exists. Several slides just need to be re-built to show what the track is saying.

### 5. Demo and code quality

The example module and package are solid. Each anti-pattern is labeled in-file with the rule that catches it, which is exactly right for a talk companion. `Invoke-UnsafeFunction.ps1` packs four labeled flaws (hardcoded key, TLS bypass, download-execute, base64 encoded command) into one function. That's fine for a teaching example; it is a little dense and could be split into two files for readability.

The `chocolateyInstall.ps1` example is realistic. The PATH modification + registry writes + unverified `Invoke-WebRequest` combination is exactly the shape of a junior-written internal package. Good.

The demo approach itself — "switch to browser, show PR with pre-populated SARIF annotations" — is competent but unmemorable. The demo should *do* something live that the audience feels. Candidates:

1. **Live pipeline run on a modification made during the talk.** Edit a file in the deck-adjacent repo on stage, push, and let the pipeline catch the new issue in real-time. Risk: CI latency.
2. **Side-by-side "passes / fails" moment.** Show a package that passes `choco pack` + `Test-ModuleManifest` on the left. Same package through the receipts pipeline on the right. The contrast is the point — current tooling says green, receipts pipeline says specifically-why-no.
3. **Pull a current real package from the community repo** — not a synthetic example — run the pipeline against it, see what fires. This is by far the most memorable option and the one most likely to generate genuine tension in the room. Obvious risks: (a) don't publicly shame a specific maintainer on stage, (b) handle responsibly if the rules catch something real. Use an author-known package or one Adil owns.

The current "fork the repo and open a PR" loop is the 2-star version of any of these.

### 6. Transitions and connective tissue

Where the audience gets lost or disengages:

- **Slide 15 → 16 (end of threats into PowerShell Pipeline section break).** Six threats, then a section header, then "let's build a pipeline." The connection between *which threats we're actually solving in this pipeline* is implied, not drawn. A single transition slide — "Six threats. Here's the coverage matrix against the PowerShell pipeline we're about to build" — would do huge work.
- **Slide 24 → 25 (PowerShell full picture into Chocolatey section).** "Now let's talk about why Chocolatey needs its own version" — the *why* is assumed. A specific example of a threat that's different in Chocolatey (elevated install + external binary) would earn the section break.
- **Slide 31 → 32 (Chocolatey pipeline into Bigger Picture).** Hard cut from SBOM + provenance back to integration tiers. The audience has just learned about build-time artifacts; they're not primed to care about enterprise SCA ingestion. Needs a bridge — either "okay, you've built it, now who looks at it?" or cut the Bigger Picture section entirely and fold the useful bits into the adoption path.
- **Slide 34 → 35 (Runtime Context into Adoption Path).** Sharpest flavor-change in the deck — goes from vendor-shaped slide to "start small, adopt one action at a time." The adoption-path advice is the right ending; the Wiz-shaped slide that precedes it taints it.

### 7. README

The README (`README.md`) is substantively accurate but does the wrong job for a talk companion. It reads as a README for a reusable GitHub Actions library — which it partly is — but the talk-companion dimension is relegated to a "Background" section three-quarters of the way down.

Specific issues:

- The hook is "Supply chain guardrails for PowerShell modules and Chocolatey packages." That's fine copy for a library. For a talk companion it should foreground the argument, not the toolchain.
- "Why This Exists" is where the thesis sits. It's well-written but readers have already scrolled past the table-of-contents tree above it. Move it up.
- The repo-structure tree is long. For a post-conference reader, they want three things fast: (1) "what's the argument?" (2) "how do I try it?" (3) "where's the talk?". The current structure makes them work for all three.
- Post-conference discoverability. Someone who finds the repo a week after Summit won't know the talk title off the top of their head. The README should lead with it.
- "Chocolatey Fest 2026" is in the README once, near the bottom. Someone linking to this six months from now wants that context near the top.

### 8. Biggest risks — what will make this talk fall flat

**Risk 1 — Vendor-pitch perception on the Wiz slides.** The speaker works at Wiz, cites Wiz by name on slide 33, and illustrates runtime context with a Wiz-flavored example on slide 34. For a Chocolatey Fest audience, this is the single most likely complaint on post-talk feedback. The talk isn't actually a Wiz pitch, but a few minutes look like one, and that's what the detractors will remember.

**Risk 2 — Density fatigue at the 60-minute mark.** By the time you're midway through Section 3 (Chocolatey Pipeline), you've been through 28 slides, 6 threats, 5 tools, and 2 example codebases. The pacing is uniform — same-shaped slides, same cadence. Senior technical audiences tolerate density but not monotony. The deck needs a rhythm change around slide 25 to keep the room.

**Risk 3 — The "nothing new" critique.** SBOM, SARIF, SLSA provenance, Syft + Grype — this is 2023/2024 vocabulary in 2026. For an audience that has heard "SBOM" at every conference they've attended for two years, the talk needs to say something that isn't just "here's the mainstream supply chain playbook applied to PowerShell." The PowerShell-specific angles *are* in the deck (typosquatting research, the PSGallery API unlisted-package gap, the PowerShell lockfile gap, VERIFICATION.txt being unenforced) but they're mixed in with the generic material rather than foregrounded. A version of this talk that relentlessly foregrounded the *PowerShell- and Chocolatey-specific* gaps would be much more memorable. The version that's there foregrounds the generic playbook and sprinkles the ecosystem-specific stuff as illustrations.

---

## PHASE 2 — Build Something Better

### 1. Revised talk structure and narrative arc

**Run time:** 90 minutes including demo and Q&A. Target 75 minutes of content, 5 minutes of buffer, 10 minutes of Q&A.

**Core revision:** drop the "four sections" scaffold. Use a three-act shape that *is* a narrative: the setup ("here's what you don't have"), the build ("here's what adding it looks like"), the payoff ("here's what's still broken, and what you can do Monday"). This produces natural rhythm and reduces pattern-shape monotony.

**Act I — The Ecosystem Gap (0:00 – 0:20)**

Open cold on a real-looking package. Not synthetic, not obviously broken. A package that passes `choco pack`, `Test-ModuleManifest`, PSGallery publish, and the Chocolatey community validator. A package that would install tomorrow on a real corporate machine and be considered fine. Then: open `chocolateyInstall.ps1` and walk through what's actually happening. This is the room-wakeup.

From there: articulate the ecosystem-specific gap. Not "supply chain security matters" — a room this far in already believes that. The specific claim: PowerShell and Chocolatey both lack the enforcement plumbing that every other major package ecosystem now takes for granted. No lockfile. No moniker rules. VERIFICATION.txt is a norm, not a contract. PSGallery's unlisted-package API has no scrubbing. The community repo's validators catch some of this; internal repos catch none of it. The registries aren't negligent — they can't issue receipts because the receipts aren't in their layer.

Close the act with the three questions (what's in it / what did you check / can you prove how it was built), but *frame them as questions the maintainer can't currently answer*, not as a wholesome checklist. The rest of the talk is about what it takes to answer them — and honest acknowledgement of which ones we can answer today, which ones we can't.

**Act II — Building the Receipts (0:20 – 0:55)**

Split into two subacts: PowerShell side, then Chocolatey side. But rather than running the same tool-parade twice, use the PowerShell subact to establish the pattern and the Chocolatey subact to show what changes when you add elevated execution and external binaries to the threat model.

PowerShell subact (20 min): Take the flawed `ExampleModule`. Put it through the pipeline live. The interesting beats are *not* "here's how PSScriptAnalyzer works" — those are setup. The interesting beats are:

- The moment Semgrep catches a multi-statement chain that PSScriptAnalyzer doesn't (hardcoded key + TLS bypass + download-execute in the same function).
- The moment the SBOM generation exposes the lockfile gap — the SBOM records what you shipped, not what resolves on a consumer's machine. Speak this gap out loud. Don't hide it. It's the most interesting unsolved problem in PowerShell supply chain right now.
- The moment the provenance artifact is generated — and the acknowledgement that *nobody is going to verify it at install time*. Name this. It's the part of the receipts story that doesn't close yet. That admission is how you earn credibility with this room.

Chocolatey subact (15 min): Take the flawed `example-package`. Now the threat model tightens: elevated execution, external binary fetch, VERIFICATION.txt as an unenforced norm, internal repos with no moderation. Show checksum enforcement, show install-script analysis, show the VERIFICATION.txt match check closing the "maintainer-updated-the-URL-but-not-the-hash" drift gap. The demo beats are more concrete here because the consequences are more concrete (admin execution, system-wide install).

The two subacts share tools but solve different-shaped problems. The structural claim: receipts are ecosystem-shaped. The PowerShell pipeline produces a different set of receipts than the Chocolatey pipeline because the risks are different. Same philosophy, different checks.

**Act III — What's Still Missing and What You Can Do Monday (0:55 – 1:20)**

This is where the talk earns the senior-audience label.

Three specific unsolved problems, named plainly:

- **The lockfile gap.** No PowerShell lockfile exists. Your SBOM records shipped state, not consumer-resolved state. Here's what a real fix would look like. Here's the current workaround (pinning `RequiredVersion`, not `ModuleVersion`, in manifests — and the `dependency-pin-check` action that enforces it).
- **Receipt consumers don't exist.** Provenance is produced. Almost nobody verifies it at install time. The registries don't demand it. `choco install` doesn't demand it. What would it take to close this loop? A short, concrete sketch — not a fantasy roadmap.
- **Internal repos.** Community repos have moderation. Internal repos typically have nothing. The pipeline is the only line of defense. A specific recommendation for the Chocolatey-for-internal-deployment crowd: what's the minimum receipts profile that works for you?

Close with a Monday-morning adoption path. Three things to do in the first week. What to expect for false positives. What not to try to enforce yet. Then a single closing line — not a repeat of the thesis slide.

Q&A: 10 minutes. Prepared answers for the obvious questions (code signing, Azure DevOps, internal repos, false positives, Wiz/CSPM — yes, take the Wiz question directly, don't hide from it).

### 2. Improved slide deck content

Target: 28 slides (down from 39). Cuts are real.

Numbering below is the *new* deck order. Each entry: title, what the slide shows, speaker note in spoken voice, visual/demo notes.

**Slide 1 — Title**
- Title: "Provenance Before Publish"
- Subtitle: "What your PowerShell and Chocolatey receipts should look like — and what's still unsigned."
- Adil's name and repo URL.
- *Note:* Walk up. Let it sit. Don't thank the sponsors yet; there's a sponsor slide coming.

**Slide 2 — Sponsors (required)**
- Sponsor logos.
- *Note:* "Thank the sponsors. This is where the funding for the room you're sitting in comes from. 15 seconds."

**Slide 3 — The package that passed every check**
- Screenshot or live browser view of a real-feeling Chocolatey package (the flawed `example-package` dressed convincingly) passing `choco pack`, passing `Test-ModuleManifest` where applicable, receiving a green CI check, and being "approvable" by the CCR Validator.
- No bullet points. Just the green checkmarks.
- *Note:* "This package installed on my lab machine last night. It passed every automated gate the Chocolatey community repository runs. If I pushed it, a moderator might catch it. If I pushed it to an internal repo — where most of you are actually publishing — nothing would. Let me show you what it does."

**Slide 4 — What it actually does (the cold open)**
- Side-by-side: the `chocolateyInstall.ps1` code on the left, plain-English annotations on the right.
- Call out: unverified `Invoke-WebRequest`, undocumented PATH modification with no uninstall cleanup, registry writes containing a hardcoded internal URL.
- *Note:* "Three things. One download with no checksum — it's fetched every time the package updates, and any compromise of the source URL lands on the machine as admin. One PATH modification, no uninstall cleanup, which is a local privilege escalation vector if the install directory is ever writable. One registry write containing what looks like a corporate internal URL that's going to ship if this package ever leaves the internal repo. `choco install` prints 'The install was successful.' It always prints that."

**Slide 5 — The gap this talk is about**
- Single sentence, large: "PowerShell and Chocolatey lack the enforcement plumbing every other major ecosystem now takes for granted."
- Small caption below: "No lockfile. No moniker rules. VERIFICATION.txt is a norm, not a contract. Moderation doesn't scale to internal repos. The registries aren't the problem — the plumbing is missing."
- *Note:* "This isn't a problem with the maintainers of PSGallery or the Chocolatey community repo. Both teams are doing real, non-trivial work. The gap is the thing that sits before their moderation runs. npm has package-lock.json. cargo has Cargo.lock. PowerShell has `RequiredModules` with a minimum version. That's a list of floors, not a lock. Same pattern up and down the ecosystem."

**Slide 6 — What the registries already do (compressed)**
- Two-column: CCR (Validator, Verifier, VirusTotal + moderation) vs. PSGallery (manifest validation, install testing, AV scan, error-level PSScriptAnalyzer).
- *Note:* "Give them credit. This is real work. It's the starting point, not the finish line. None of it produces a machine-readable inventory of what's in your package, and none of it can prove that the binary in the package came from the commit in the repo. That's what we're going to add."

**Slide 7 — The three questions**
- What's in this package? → SBOM
- What did you check? → scan results (SARIF)
- Can you prove how it was built? → provenance
- *Note:* "Three questions a maintainer should be able to answer before publishing. In a moment we're going to see how well we can actually answer each one today — because the honest answer is different for each, and for each ecosystem. That honesty is the point."

**Slide 8 — Act I closer: threats you'll see downstream**
- Five-row table. Threat category | real incident | why the ecosystem is susceptible.
  - Name impersonation → Aqua `Az.Table` PoC, 2023 → no moniker rules on PSGallery
  - Download-execute → Serpent campaign, 2022 → `Invoke-WebRequest | Invoke-Expression` pattern is normalized
  - Floating dependency → no named incident, structural → `ModuleVersion` is a floor, no lockfile
  - Unverified binary drift → 3CX supply chain compromise, 2023 → VERIFICATION.txt unenforced
  - Secret leakage → Aqua PSGallery API research, 2023 → unlisted packages still served via API
- *Note:* "Five threats I'm going to hold you to in the rest of the talk. They map directly to the pipeline steps coming next. I'm deliberately not listing a sixth generic 'unsafe install patterns' bucket — the talk-track file has a longer list but the five on this slide have real incidents behind them and they're what we're going to instrument against. If I'd listed eight threats you'd have forgotten the first three. Five you can hold."

**Slide 9 — Act II setup: the flawed module**
- Screenshot of `examples/powershell-module/ExampleModule/` directory.
- Callouts: `.psd1` floating dep + `ScriptsToProcess`; `Invoke-UnsafeFunction.ps1` four flaws; tests pass.
- *Note:* "Flawed PowerShell module. Not cartoonishly broken. This loads. Pester passes. PSGallery would accept it. Let me show you what the receipts pipeline sees."

**Slide 10 — The multi-statement pattern PSScriptAnalyzer can't catch**
- Code block: the four-line sequence from `Invoke-UnsafeFunction.ps1` — hardcoded key, TLS bypass, `Invoke-WebRequest` assignment, `Invoke-Expression` on the result.
- Below the code, two annotations:
  - PSScriptAnalyzer flags line 4 (`Invoke-Expression`) as a code-quality warning.
  - Semgrep flags lines 1–4 as a single download-execute chain with a hardcoded credential.
- *Note:* "This is the difference I want you to remember. PSScriptAnalyzer is a linter. It's doing the right job for a linter. The thing it's not doing — the thing nothing in your current toolchain is doing — is looking at a sequence of statements and saying 'this is a remote code execution pattern, and the credential feeding the remote request is hardcoded right above it.' That's the multi-statement reasoning supply chain rules need, and that's what Semgrep buys you."

**Slide 11 — A Semgrep rule, unabridged**
- Full YAML of the `invoke-expression-from-web` rule.
- *Note:* "Semgrep rules are YAML. No DSL, no plugin, no IDE dependency. The `$X` metavariable binds an identifier across lines — that's how the rule catches the assignment-then-exec pattern. The rules live in `semgrep-rules/` in the repo. Twelve for PowerShell, twelve for Chocolatey. Fork them, extend them, send a PR if you add one. The point isn't that my rules are complete. The point is that the authoring cost is low enough that your team's specific patterns can get their own rules in an afternoon."

**Slide 12 — Demo beat: live SARIF in the PR**
- Screenshot / live browser: PR with inline SARIF annotations from PSScriptAnalyzer and Semgrep.
- *Note:* "This is the output. Annotations in the diff, aggregated in the Security tab, filterable by tool. The dollar cost of this is zero. The setup is a single `codeql-action/upload-sarif` step at the end of the workflow. If you took one thing from this talk and put it in your pipeline next week, this is the thing."

**Slide 13 — The SBOM, and the gap inside it**
- Snippet of the generated `powershell-module-sbom.cdx.json` showing a `components` array with PURLs.
- Below, a blunt callout: "Your SBOM records what you shipped. It doesn't record what resolves on the consumer's machine."
- *Note:* "The SBOM is here. It's CycloneDX. Syft generated it. The components have PURLs, versions are resolved at build time, the file hashes are embedded. Useful. Now the honest part. This SBOM describes my build. It doesn't describe what installs on your machine. PowerShell has no lockfile — `Install-Module` resolves `RequiredModules` at install time against whatever is currently the highest-satisfying version in PSGallery. Ship the module Monday, install it Tuesday, you might get a different dependency graph. The SBOM on this slide is a snapshot of what I built, which is an audit artifact, not a guarantee of what runs. That's the lockfile gap. No tool on this slide closes it. I'll come back to what to do about it in Act III."

**Slide 14 — Vulnerability scan results, and what they mean retroactively**
- Screenshot of Grype SARIF findings.
- *Note:* "Grype reads the SBOM, matches against NVD and the GitHub Advisory Database. Findings land back in Code Scanning. The live-at-build-time part is the obvious value. The less-obvious value is retroactive: the SBOM is stored as an artifact for 365 days, so when a CVE drops against a dependency six months from now you can re-run Grype against the stored SBOM and know in seconds which past releases were exposed. That's incident response, not prevention. Both matter."

**Slide 15 — Provenance, and the consumer who isn't there**
- The provenance JSON on screen. Highlight: source repo, commit SHA, workflow ref, artifact hash.
- Below: "This is the receipt. Nobody is verifying it at install time. Yet."
- *Note:* "Here's what I'm not going to tell you: that this is verified by the consumer. It isn't. `Install-Module` doesn't check this. `choco install` doesn't check this. No registry today enforces presence of a SLSA attestation. I could say this is all fine because the provenance is still useful for maintainer-side audit — proving the artifact in the registry came from a specific commit and pipeline run — and that *is* useful. But the full loop isn't closed. If you take only one thing from this act of the talk: maintainers can produce receipts today. Consumers aren't reading them yet. We'll talk about what that takes in Act III."

**Slide 16 — PowerShell pipeline — actual run**
- A screenshot of the actual GitHub Actions run graph with step timings.
- *Note:* "Full pipeline, end-to-end. Runs in about three and a half minutes on a cold runner, under two minutes once Grype's database is cached. Non-blocking by default. You adopt one step at a time — everything in this repo is a composite action you can pull into your existing workflow without taking all of it."

**Slide 17 — Chocolatey changes the threat model**
- Three rows, each a short before-Chocolatey vs. after-Chocolatey comparison:
  - Execution context: user → admin
  - Package content: your code → a thin wrapper around an external binary
  - Review: PSGallery AV + PSScriptAnalyzer → CCR moderation for community, nothing for internal
- *Note:* "Everything we just built for PowerShell applies. On top of that, Chocolatey is a different animal because of three things. Install scripts run as admin. The package is usually not the software — the software is an external binary fetched at install time. And moderation doesn't reach internal repos, which is where a lot of you are actually shipping. That combination changes which checks matter most."

**Slide 18 — The flawed Chocolatey package**
- Screenshot of `examples/chocolatey-package/` — nuspec, install script, VERIFICATION.txt.
- *Note:* "The package from the cold open. Three intentional issues across three files. `choco pack` succeeded. `choco install` succeeded. Let me show you what the Chocolatey-specific checks see."

**Slide 19 — Naming validation (briefly)**
- Levenshtein check, CCR API query, flags on near-matches.
- *Note:* "Naming validation queries the community repo API, runs a Levenshtein similarity check. Fast, narrow in what it catches, zero-cost to run. Not going to spend long on this — it's the cheapest check in the pipeline and it catches typosquat collisions before you publish. If you want the attacker-side research behind it, Aqua's 2023 `Az.Table` writeup is the canonical one. Moving on."

**Slide 20 — Checksums, integrity, and VERIFICATION.txt drift**
- Code: `Install-ChocolateyPackage` call showing required checksum fields.
- Below: a short narrative of the drift scenario (maintainer updates URL, forgets the hash, VERIFICATION.txt silently wrong, `choco pack` succeeds anyway).
- *Note:* "Three checks. Every external download has a checksum. The algorithm is SHA256 or better. And the VERIFICATION.txt entries match the actual embedded files on disk. That third check is the one that catches real drift — a maintainer updates the binary URL for a new release, regenerates the package, forgets to update VERIFICATION.txt. The package ships. Nothing is malicious. The receipts just stop matching reality. Without this check, nobody notices."

**Slide 21 — Install-script analysis, with the rules visible**
- Four rule names from `chocolatey-install-patterns.yml` alongside a one-line description each:
  - `choco-unverified-download` — raw `Invoke-WebRequest` outside Chocolatey helpers
  - `choco-registry-write-undocumented` — HKLM writes with no cleanup or doc comment
  - `choco-path-modification-undocumented` — PATH change, no uninstall cleanup
  - `choco-hardcoded-internal-url` — internal-looking URLs / UNC paths
- *Note:* "These are opinionated. Some findings will be intentional and suppress with a `# nosemgrep:` comment with a justification. The suppression ships in SARIF, it's visible in the PR, a reviewer can audit it. The PATH-modification one is the most load-bearing. Let me tell you exactly why."

**Slide 22 — The PATH modification story**
- Diagram: `chocolateyInstall.ps1` adds `C:\tools\myapp`; uninstall leaves it; someone writes `git.exe` into the directory; next user running `git` executes the planted binary.
- *Note:* "Install script appends `C:\tools\myapp` to the machine PATH. No cleanup in the uninstall script. Six months later, someone uninstalls the package. PATH entry stays. If that directory's ACLs were ever lax — and with a lot of tools directories under `C:\` they are, depending on how the app was installed — anyone with local shell access can drop a `git.exe`, a `python.exe`, a `node.exe` there. Windows PATH resolution finds that binary before the real one. That's local privilege escalation from a forgotten Chocolatey package. The Semgrep rule doesn't know whether the directory is writable. It knows the cleanup is missing. That's enough to make it a reviewable finding."

**Slide 23 — Chocolatey pipeline — actual run**
- Screenshot of the actual `chocolatey-supply-chain.yml` run graph.
- *Note:* "Chocolatey pipeline. Same five output artifacts — two SARIF reports, an SBOM, Grype results, provenance. Same shape, ecosystem-specific checks."

**Slide 24 — What's still broken: three unsolved problems**
- Three short blocks:
  1. The lockfile gap.
  2. Receipt consumers don't exist.
  3. Internal repos have no moderation.
- *Note:* "Three problems this pipeline does not solve. I want to name them so you don't leave thinking the pipeline closes the loop — it doesn't. One, the lockfile gap: no PowerShell lockfile, SBOMs record shipped state not resolved state, the closest current workaround is pinning `RequiredVersion` and enforcing it with the `dependency-pin-check` action. Two, nobody verifies provenance at install time — the consumer side of the receipts story isn't built yet. Three, internal repos have no moderation. The pipeline is the only thing between your developer and production. Each of these deserves its own talk. I'm happy to take any of them in Q&A."

**Slide 25 — Monday-morning adoption path**
- Three steps:
  1. Add SARIF upload + Semgrep with one rule file, non-blocking. (One afternoon.)
  2. Add SBOM + provenance generation. (One afternoon.)
  3. Tune rules, add suppressions, decide what blocks. (Ongoing.)
- *Note:* "I'm not going to tell you to turn on enforcement on day one. That's how security gates get disabled quietly three months later. Add visibility first. Let the team see what fires. Tune. Then decide what blocks a merge. The action-per-step structure of the repo exists specifically so you can adopt any one of these independently. You don't have to take the whole pipeline. You can take the SBOM step this week and the rest next quarter."

**Slide 26 — The repo**
- `github.com/adilio/publish-with-receipts`
- Four pointers: `examples/`, `actions/`, `semgrep-rules/`, `docs/`.
- *Note:* "Everything is in the repo. Every action is a composite action. Every rule is a YAML file. The docs cover threat model, tooling decisions, and enterprise integration. You don't need to have been at this talk to use the repo. You also don't need my permission to fork it and turn it into something your organization maintains instead."

**Slide 27 — A last line**
- One sentence, no bullets: "Receipts are useful even when nobody reads them — until the day someone does."
- *Note:* "That's the talk. The receipts are worth generating now. The verification loop will close. When it does, you want to already be producing them."

**Slide 28 — Q&A**
- Prompt, name, handle, repo URL.

### 3. Polished talk track

What follows is the continuous spoken track. It's not a read-aloud script. It's how this would sound in the room.

---

*[Slide 1 — Title. Walk up. Let the title sit for a couple seconds. Drink of water.]*

Thanks for coming. I know you had five options this slot. I'll try to make this worth the choice.

*[Slide 2 — Sponsors. 15 seconds of acknowledgement.]*

Quick thank-you to the sponsors — the room you're sitting in and the lunch you're about to eat are courtesy of them. You know the drill.

*[Slide 3 — The package that passed every check. Pull up the browser view.]*

Here's where we're starting. This is a Chocolatey package I built last night in my lab. It's three kilobytes. It installs a binary from a CDN. It runs as admin. It wrote to the registry. It modified PATH. And every automated gate I threw at it came back green.

`choco pack` succeeded. `Test-PackageForVerification` in the Chocolatey extension doesn't see anything wrong. `Test-ModuleManifest` — well, that's PowerShell, not applicable here, but the equivalent nuspec check is clean. If I'd submitted it to the community repository, the Validator would have approved it and the Verifier would have confirmed it installs. A human moderator might have caught something. Probably not everything. If I'd submitted it to an internal repo — which is where most of you are actually publishing — nothing would have caught any of it, because internal repos don't have moderators. They have whoever you designated, which is frequently nobody.

Let me show you what it actually does.

*[Slide 4 — What it actually does. Three callouts on the install script.]*

Three things this package does that nothing in your current toolchain catches. One, it downloads a binary over HTTP from a vendor URL, no checksum. If that URL ever serves a different binary — because the vendor rotated the CDN, because the CDN was compromised, because a maintainer updated the URL without updating the docs — that different binary runs on every machine that installs this package, as admin, and nobody is told.

Two, it appends a directory to the machine PATH and there is no corresponding cleanup in the uninstall script. Someone uninstalls the package six months from now, that directory stays in PATH forever. If the directory was ever writable — and a surprising number of directories under `C:\` are, depending on which installer created them — anyone with local shell access can drop a `git.exe` there, name it `git.exe`, and the next person who runs `git` on the machine runs whatever was planted. That's a real local priv-esc pattern, it's been used in the wild, and it starts with a forgotten Chocolatey package.

Three, this package writes a registry value containing what looks like a corporate internal URL. If this package ever leaves the internal repo — gets copied to an artifact, gets accidentally published to CCR, gets handed to a customer — that URL is in every install that runs.

`choco install` prints "The install was successful." It always prints that. That is also what it prints when nothing weird happened. The problem is the output is the same.

*[Slide 5 — The gap.]*

That's the talk. The gap I'm here to talk about is that PowerShell and Chocolatey both lack the enforcement plumbing every other major package ecosystem took for granted years ago. No lockfile. No moniker rules. VERIFICATION.txt is a norm, not a contract. Moderation doesn't scale to internal repositories. This is not a critique of the people running the community repo or PSGallery — both teams are doing real, non-trivial work. The issue is the layer *before* their work: by the time a package reaches moderation, the receipts have not been generated, and the registries cannot produce the receipts retroactively. That has to happen in your pipeline.

*[Slide 6 — Registries, compressed.]*

Before I move on, credit to the registries. Chocolatey community repo runs a Validator for metadata and script structure, a Verifier that actually installs, upgrades, and uninstalls in a reference environment, a VirusTotal scanner, and a human moderation step for non-trusted packages. PSGallery runs manifest validation, installation testing, antivirus, and PSScriptAnalyzer at error level. This is real infrastructure. I'm not recommending you skip it. I'm recommending that by the time your package arrives, you can hand the moderator three things they don't currently receive: an SBOM, a set of scan results, and a provenance document.

*[Slide 7 — Three questions.]*

Those three things answer three questions. What's in this package — that's the SBOM. What did you check — that's scan results, in SARIF. Can you prove when and how it was built — that's provenance. We're going to build each of those in the next 30 minutes. I also want to be honest with you up front: the answers I can give today are different for each question and different for each ecosystem. The SBOM story works better for Chocolatey packages with embedded binaries than it does for pure PowerShell modules. The provenance story — I can produce a receipt; nobody's reading it at install time yet. We're going to come back to that honest accounting at the end of the talk.

*[Slide 8 — Five threats. Table.]*

Five threats. Each one has a real incident behind it. Name impersonation — Aqua registered `Az.Table` in 2023 to impersonate the popular `AzTable` module, 10 million downloads. Got callbacks from production Azure environments within hours. Download-execute — Serpent malware campaign in 2022 used Chocolatey legitimately to install Python, then deployed a backdoor. Floating dependency — no single dramatic incident; it's the structural one. Your build's dependency graph is reconstructed at install time because PowerShell has no lockfile. 3CX in 2023 — the vendor's build environment was compromised, the signed installer was already backdoored, every Chocolatey package pointing at the official URL distributed malware. And the Aqua PSGallery research — people publishing API keys in unlisted packages, still accessible via the PSGallery API after the authors thought they'd removed them.

I'm going to map the rest of the talk to this table. Each row gets addressed by at least one check in the pipeline we're about to build.

*[Slide 9 — Flawed module. Switch to the repo browser, open the directory.]*

PowerShell side first. This is the flawed module in the repo. Not cartoonishly broken — this is the shape of what ships when you're the solo maintainer and moving fast. Floating dependency in the psd1. `ScriptsToProcess` — same mechanism Aqua used in their typosquat PoC. Exported function with four labeled flaws. Tests pass. PSGallery would publish it. I want you to hold in your head: everything that's wrong with this module is invisible to the tools in your CI right now.

*[Slide 10 — Multi-statement pattern.]*

This is the pattern I want you to remember from the PowerShell side of the talk. Four lines. Hardcoded API key. Disable TLS validation. `Invoke-WebRequest` — content goes into a variable. `Invoke-Expression` — variable gets evaluated.

PSScriptAnalyzer, which PSGallery already runs, will flag line 4 — `Invoke-Expression` is a code quality warning. One finding, one line. What PSScriptAnalyzer is not doing — and is not designed to do — is reading this as a sequence. It's not saying "the thing being evaluated just arrived from the network." It's not saying "the credential feeding the network request is hardcoded two lines up." It's not connecting "TLS validation was disabled earlier in the function" to "a subsequent HTTPS request is about to run in a session with no certificate checks."

Semgrep's job is to see this as one pattern. Multi-statement, variable-binding, cross-line. That is the difference. Not "Semgrep is better than PSScriptAnalyzer" — they do different jobs. Linter versus security scanner. Run both.

*[Slide 11 — Semgrep rule YAML.]*

This is what a Semgrep rule looks like. YAML, no plugin, no DSL. The `$X` binds an identifier across lines — that's how the pattern matches assignment-then-exec even if there are other statements between them. The rules live in the repo. Twelve for PowerShell, twelve for Chocolatey. The authoring cost is low enough that if your team has patterns specific to your environment, you can add rules for them in an afternoon. Fork the repo, extend the YAML, send a PR if you want them upstream.

*[Slide 12 — SARIF in the PR. Switch to live browser, navigate to a PR with populated findings.]*

This is what the output looks like from the reviewer's side. Annotations inline in the diff, aggregated in the Security tab, filterable by tool or severity. The dollar cost of this is zero. The setup is a single SARIF upload step at the end of each scanning job. If you took one thing from this talk and put it in your pipeline next week, this is the thing — visibility in the PR, no additional dashboard to train your team on.

*[Slide 13 — SBOM and the lockfile gap.]*

SBOM next. This is the CycloneDX JSON Syft generates against the module directory. Components array, PURLs, resolved versions, file hashes. Useful for an audit trail.

Now the honest part. This SBOM records what I shipped. It does not record what resolves on the consumer's machine when they `Install-Module` this thing. PowerShell has no lockfile. `Install-Module` resolves `RequiredModules` at install time against whatever is currently the highest-satisfying version in PSGallery. I ship Monday. You install Tuesday. You might have a different dependency graph than my build produced. My SBOM will tell you what I built. It won't tell you what ran on your machine.

That's the lockfile gap. It is the single biggest unsolved problem in PowerShell supply chain security today. No tool on this pipeline fully closes it. The closest current workaround is to pin `RequiredVersion` — the exact version — instead of `ModuleVersion` in your manifest, and to enforce that pinning with the `dependency-pin-check` action in this repo. That gets you a maintainer-side commitment, not a consumer-side guarantee. The consumer-side guarantee requires a lockfile, and PowerShell doesn't have one. I'll come back to what a fix would look like at the end.

*[Slide 14 — Grype findings.]*

Grype reads the SBOM from the previous step, runs it against NVD and the GitHub Advisory Database, findings go back into Code Scanning. Build-time value is obvious. The part that's less obvious: the SBOM is retained as an artifact for a year, so when a CVE drops against a dependency six months from now you re-run Grype against the stored SBOM from that release and you know in seconds whether that release was affected. That's incident response, not prevention. Both matter, and in my experience the incident-response value is what gets this pipeline funded in an enterprise — more than the build-time gating.

*[Slide 15 — Provenance, and the missing consumer.]*

Provenance. Source repo, commit SHA, workflow reference, artifact hash, timestamp. Here's the receipt.

Now. Who's reading this receipt? `Install-Module` doesn't check it. `choco install` doesn't check it. The registries don't require it. No out-of-the-box verifier fires on package install today. I produce the provenance. The consumer never asks to see it.

That is a real problem with the current state of this art, and I'm not going to pretend it isn't. What I can say is the provenance is useful *to the maintainer* right now. If a customer ever asks me "can you prove the module you shipped on this date came from this commit and was built by this pipeline," I can show them the provenance. If an incident happens and I need to say definitively which build produced which artifact, I have it. That is maintainer-side audit value, which is real but narrower than the end-to-end story.

What it takes to close the consumer loop is: the registries requiring signed provenance at upload, and the install tooling verifying it at install. Those are both ecosystem-scale asks. They're not my pipeline's problem to solve. But producing the receipts now means that the day a verifier ships, your back catalog is ready to be read.

*[Slide 16 — Actual run graph.]*

Full pipeline, end-to-end, on the example module. Three and a half minutes cold, under two minutes once Grype's database is cached. Every step is a composite action you can pull independently. You can adopt any one of these without the others.

*[Slide 17 — Chocolatey is different.]*

Switching to Chocolatey. Everything we just built applies. On top of that, Chocolatey tightens the threat model in three ways that matter. Install scripts run as admin. The package is typically a three-kilobyte wrapper around a 50-megabyte binary the install script fetches — which means the package's security is mostly the security of an external download. And moderation doesn't reach internal repositories, which is where a lot of Chocolatey is actually deployed. That combination is why the Chocolatey pipeline adds three checks the PowerShell pipeline doesn't need.

*[Slide 18 — Flawed package.]*

This is the package from the cold open. nuspec with missing metadata and unpinned dependencies. Install script with the three flaws we already looked at. VERIFICATION.txt with no checksums.

*[Slide 19 — Naming validation.]*

Naming validation queries the CCR API and runs a Levenshtein similarity check against existing package names. Cheap to run. Narrow in what it catches — won't stop a determined attacker who's already published, but will catch accidental name collisions before you publish and surface potential typosquat conflicts during code review. Not going to spend long on it. Moving on.

*[Slide 20 — Checksums + VERIFICATION.txt drift.]*

Three checks here. Every external download has a checksum. Algorithm is SHA256 or better. And VERIFICATION.txt entries match the actual embedded files on disk.

The third check is the one I want you to notice. Imagine a maintainer ships v1.0. Downloads come from the vendor's official CDN, checksum documented, VERIFICATION.txt matches. Six months later the vendor rotates their CDN, URL changes, maintainer updates the install script, regenerates the package, forgets to update VERIFICATION.txt. `choco pack` succeeds. Package installs successfully. VERIFICATION.txt now describes the previous binary. Anyone who checks it manually is reading lies. The pipeline catches this at build time by recomputing hashes against the actual files on disk. Nothing malicious required. Just normal maintenance drift.

The malicious version of this same scenario is 3CX, 2023. Attackers compromised the vendor's build environment. The signed installer the vendor distributed was already backdoored. Every Chocolatey package pointing at the official 3CX CDN was distributing malware. If your pipeline doesn't verify what it downloaded against a hash you established at build time, you can't detect that the binary changed.

*[Slide 21 — Install-script analysis.]*

Four rule categories. Raw `Invoke-WebRequest` outside Chocolatey's helpers — bypasses Chocolatey's built-in checksum enforcement. Registry writes and service creation without a documentation comment — in a script that runs as admin, reviewer needs to know why. Hardcoded internal URLs — as I showed in the cold open, those leak your internal topology if the package ever leaves the internal repo. PATH modification without matching uninstall cleanup — this is the one worth its own slide.

*[Slide 22 — PATH story.]*

Install adds `C:\tools\myapp` to the machine PATH. Uninstall doesn't remove it. Six months later, someone uninstalls the package, PATH entry stays. If that directory's ACLs let non-admin users write to it — and depending on how the app was installed, that happens more than you'd like — anyone with a local shell can drop a `git.exe`, a `python.exe`, a `node.exe` in there. Windows PATH resolution finds them before the real ones. Next time someone runs `git` on that machine, they run the planted binary.

This is a documented LPE precondition and a misconfigured PATH entry from a forgotten Chocolatey package is how it commonly gets set up. The Semgrep rule doesn't know whether the directory is writable. It knows the cleanup is missing. In a context where the script runs as admin, that's enough to make it reviewable.

*[Slide 23 — Chocolatey run graph.]*

Chocolatey pipeline run. Same five output artifacts as the PowerShell pipeline. Ecosystem-specific checks. Same shape.

*[Slide 24 — Three unsolved problems.]*

Now the honest accounting. Three things this pipeline does not solve.

One, the lockfile gap. We covered it. The Chocolatey version is slightly better — `.nuspec` dependencies can be pinned to exact versions, the pipeline's `dependency-pin-check` action can enforce it. The PowerShell version is worse, and no amount of composite actions I write is going to fix it. The real fix is a PowerShell lockfile, which is a platform-level change.

Two, consumers aren't reading receipts. `Install-Module` and `choco install` don't verify provenance. Production of receipts is ahead of verification. That gap doesn't close in this talk. It closes when the registries require signed provenance at upload and the clients verify at install. Both of those are ecosystem-level decisions. The worthwhile thing I can do in the meantime is produce the receipts so that the day a verifier exists, my back catalog is ready.

Three, internal repositories. CCR has moderators. Your internal Chocolatey repo typically doesn't. In that context, this pipeline is not a complement to moderation — it is the moderation. That changes how seriously you should take the enforcement decisions. On a community package I'd say "start non-blocking, tune, enforce when ready." On an internal package shipped to thousands of endpoints with no human review — start blocking on critical checks immediately. Don't be polite with your own infrastructure.

*[Slide 25 — Monday morning.]*

Three steps for next week. Step one, one afternoon: add PSScriptAnalyzer with SARIF upload and Semgrep with one rule file, non-blocking. You'll see what fires. You will get false positives. Expect them. Step two, one afternoon, later the same week or next: add SBOM and provenance generation. Both are single-composite-action adoptions. They don't block anything — they produce artifacts. Step three, ongoing: tune rules, add suppressions with justifications, decide which findings block a merge.

What not to do on day one: don't turn on enforcement before you've seen the baseline. That is how security gates get disabled quietly three months later when the team gets tired of them. Visibility first. Enforcement after you've earned it.

*[Slide 26 — Repo.]*

Repo is up on screen. `examples/` has the flawed module and the flawed package, `actions/` has eight composite actions you can adopt individually, `semgrep-rules/` has the YAML rules, `docs/` has threat model, tooling decisions, enterprise integration, and a remediation guide for every finding type the pipeline surfaces. You don't need to have been in this room to use the repo. The decisions are written down.

*[Slide 27 — Last line.]*

Receipts are useful even when nobody reads them — until the day someone does.

That's the talk. I'm going to take questions.

*[Slide 28 — Q&A. Take the obvious ones: Azure DevOps portability, code signing, Wiz/runtime context, internal repo enforcement, false positive rates.]*

---

### 4. Demo and code recommendations

**Minimum viable demo.** One live moment, not a browser tour. Make the MVD this: edit `Invoke-UnsafeFunction.ps1` in front of the audience — swap the hardcoded key for an even cheekier one, something memorable — push, and let the running pipeline catch it while you're still talking. 90 seconds of live CI is more convincing than 10 minutes of pre-populated screenshots.

Fallback: have the pre-populated PR ready in a second tab. If the live push is slow or errors out, cut to the fallback without apologizing — "here's one I prepared earlier" — and keep moving.

**Example code changes to consider:**

- **Split `Invoke-UnsafeFunction.ps1`** into two files. Current version has four labeled flaws in one function which makes it dense to look at on screen. Move the base64-encoded command into a second file (`Invoke-ObfuscatedFunction.ps1`) so the main demo function has three cleanly-visible flaws.
- **Strengthen the Chocolatey example** by giving it a realistic-looking (not generic) name and metadata. `example-package` is too obviously synthetic for the cold-open moment. Rename to something plausible like `corp-dev-tools` or `devtool-helper`, add a real-looking `projectUrl`, add a `tags` list. The *point* of the cold open is "this looks real" — the current example fails that test.
- **Add a deliberately drift-broken VERIFICATION.txt** to the Chocolatey example. Current VERIFICATION.txt has no checksums, which is one failure mode. Drift — wrong checksum for a real binary — is the more interesting failure mode and the one slide 20 in the revised deck depends on. Add a second fixture demonstrating drift.
- **Add a CVE-reachable dependency** to the PowerShell module. Grype needs a finding to make slide 14 meaningful. Add a NuGet-addressable dependency with a known CVE (or a transitively-resolvable dep with one) — otherwise the "Grype findings" demo is an empty table, which is worse than no demo.
- **The Semgrep-scan and vulnerability-scan actions in this repo are non-blocking by default.** That's correct for the audience adoption story. For the *demo*, you might want a second workflow variant with enforcement on, just to be able to show "and here's what it looks like when this gets escalated to blocking" if a question goes that direction.

**What would feel contrived on stage:**

- The synthetic-looking `example-package` name. See above.
- The provenance demo as currently written — opening the JSON file and pointing at fields. That's a static demo and it will feel like a YAML walkthrough. A better provenance beat: generate the provenance during the talk, then take the artifact hash out of it and hash the actual artifact in a second terminal — show the match. It's the minimum theater needed to make "receipt" feel like a real object.
- The "Three Integration Tiers" table (slide 33 in the current deck; cut in the revision). Integration-tier tables read as vendor-pitch unless you explicitly pick one and show it working. Better to cut and fold the genuinely useful bits into the adoption-path slide.

**Demo rehearsal notes:**

- Run the full pipeline twice end-to-end in the week before. Know the actual timings on your laptop and the Summit conference Wi-Fi.
- Pre-warm Grype's cache on whatever machine runs the live demo. First-run Grype on a cold runner spends 30+ seconds downloading the vulnerability database, which will kill stage pacing.
- Have the SARIF, SBOM, and provenance JSON open in a second editor window at the start. If the browser-based view of Code Scanning is slow, you can pivot to the raw files without losing the thread.
- Pre-populate a PR with a known set of findings so you always have a reliable visual to fall back on.

---

## Summary of changes

- Deck: 39 slides → 28 slides.
- Structure: four-section "tool parade" shape → three-act narrative (ecosystem gap → build → what's unsolved).
- Thesis: "three receipts, all equally weighted" → "receipts for maintainer audit today, ecosystem verification when the registries catch up."
- Chocolatey content: expanded and front-loaded (cold open is a Chocolatey package, not an abstract gap diagram).
- Demo: passive browser tour → one live push + prepared fallback.
- Closing: thesis-repeat slide → concrete Monday-morning adoption path → one-line close.
- Wiz/vendor optics: Wiz-named slides cut; runtime-context point absorbed into Q&A as a prepared answer.
- Honest accounting: the lockfile gap and consumer-side verification gap are named plainly as unsolved, not hidden.
