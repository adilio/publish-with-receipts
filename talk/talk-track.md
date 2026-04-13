# Talk Track — Provenance Before Publish

**Event:** Chocolatey Fest 2026 (PowerShell + DevOps Global Summit 2026, Bellevue, WA)
**Duration:** 90 minutes (~75 min content + 10 min Q&A + 5 min buffer)
**Audience:** Chocolatey and PowerShell practitioners, plus PSGallery and CCR maintainer teams in the room
**Format:** Technical deep-dive — slides, one live demo beat, Q&A

Each section below maps to a slide in `presentation.md`. This is a speaker track, not a read-aloud script — spoken voice, not paragraphs. Stage directions are in italics. `[laugh beat]` marks moments of intended humor — give the line air to land.

Three-act structure:

- **Act I — The Ecosystem Gap** (slides 1–13, ~22–25 min)
- **Act II — Building the Receipts** (slides 14–28, ~33–37 min)
- **Act III — What's Still Missing, and Monday** (slides 29–31, ~10–12 min)
- **Q&A** (slide 32, ~10 min)

---

## Act I — The Ecosystem Gap

### Slide 1 — Title

*Walk up. Let the title sit for two beats. Sip of water.*

"Thanks for coming. I know you had five options this slot. I'll try to make this worth the choice."

---

### Slide 2 — Sponsors

*15 seconds. Don't dawdle.*

"Quick thank-you to the sponsors — the room you're sitting in and the lunch you're about to eat are on them. You know the drill."

---

### Slide 3 — Supply chain attacks are no longer edge cases

"Supply chain attacks used to be something that happened to other people — nation-state targets, critical infrastructure, household names. That's not the world we're in anymore.

XZ Utils: a single maintainer, burned out, two years of patient social engineering by an attacker who contributed code, built trust, and then slipped a backdoor into a compression library that was shipping in Debian, Fedora, and Kali. It was caught by accident — a Microsoft engineer noticed slightly elevated SSH login times. If he hadn't, it ships.

Polyfill.io: a CDN serving JavaScript to over 100,000 websites gets acquired. New owner immediately starts injecting malicious code. The domain itself was the trusted thing. The update mechanism was the attack.

tj-actions: a GitHub Actions step used in CI pipelines across thousands of open-source repos. Compromised in March 2025. Every pipeline that ran it was exfiltrating secrets into public CI logs. Not an exotic target — a utility step that developers treat like a standard library.

The pattern is the same every time. The trusted thing becomes the attack vector. The thing you didn't think twice about is the thing that runs."

---

### Slide 4 — AI is compressing the time to exploit

"The reason supply chain security feels more urgent right now isn't just that attacks are more common. It's that the response window is shrinking.

There's a site — zerodayclock.com — that tracks the time between a CVE being published and active exploitation in the wild. Pull it up some time and just watch the numbers. What used to be measured in weeks is now measured in days. Sometimes hours. AI tooling — the same category of thing as what we all use every day for writing code — is being used by attackers to automate exploit variant generation, to scan for affected systems at scale, and to craft payloads faster than any human team could.

This doesn't change what we're building today. Provenance and SBOMs don't stop a zero-day. But they do mean that when the next one drops — and it will — you can run Grype against your stored SBOMs and know in minutes which of your builds are exposed. Not weeks of manual archaeology. Minutes. That's the value of the receipt."

---

### Slide 5 — This hasn't happened to PSGallery or CCR — that we know of

"I want to be careful here, because the PSGallery team and the CCR team are in this room and they do real work that I respect.

As far as anyone has publicly disclosed, neither registry has been compromised at the infrastructure level. That's genuinely good. It's not luck — it's the result of people taking security seriously.

What I'm pointing at is the structural exposure. PSGallery and CCR have the same shape of risk that made XZ Utils dangerous: install-time execution, trust in package authors, dependency on upstream binaries. They have the same shape of risk that made tj-actions dangerous: a broadly trusted artifact that runs automatically in pipelines.

The difference is that the PowerShell and Chocolatey ecosystems have less publisher-side tooling around provenance and receipts than npm, cargo, or PyPI. Not because the registries failed — because the tooling hasn't been built yet. 'That we know of' is doing a lot of work in the title of this slide. The honest answer is we don't know what we haven't found.

That's the gap. And that's what we're here to close — on the publisher side, before the package reaches the registry."

---

### Slide 6 — The six attacks you need names for

"Before we go anywhere near tooling, I want to give you names for six things. Because in my experience — and this might just be me — practitioners know something bad can happen here, but they haven't had the categories put to them plainly. And once you have names for the categories, the defenses fall out naturally.

Six slides. One each. Analogy, real incident, one line on why our ecosystem specifically is susceptible. If you have heard all six and want to zone out for six minutes, I will not be offended. [laugh beat] If you haven't, the rest of the talk assumes these names."

---

### Slide 7 — Name confusion

"First one. **Name confusion.** Attacker registers a package whose name differs from a popular one by one character, one dot, one dash. A developer mistypes. Autocomplete confidently recommends the wrong one. Somebody copies from a Stack Overflow answer from 2019 where the typo was already baked in. The wrong package installs. The wrong package runs.

Aqua Nautilus did this for real in 2023. They registered `Az.Table` — same letters, extra dot — to impersonate `AzTable`, which at the time had more than ten million downloads. Callbacks from production Azure environments within hours. Not a prank. A proof of concept that worked the first time they tried it.

The reason it worked is that PSGallery, unlike npm, doesn't have moniker rules at the registry layer. That isn't a failing of the PSGallery team. Moniker rules are a big lift, they have false-positive consequences for legitimate forks, and there are reasonable arguments about whether the registry or the publisher should own name hygiene. Shared-challenge problem.

Microsoft's in-progress answer at the registry layer — and if you want the deep version, Michael Green and Sydney Smith walked us through it at Summit last year — is the Microsoft Artifact Registry and PSResourceGet going over OCI. Structural fix: only Microsoft can publish under the MAR namespace, so you literally can't squat on `MAR/PSResource/Az.Accounts`. Different layer from this talk. Also not shipped for most of what you install today — only the Azure PowerShell team is fully onboarded, and MAR doesn't help for community packages or third-party vendor modules. Which means if you care whether your package is confusable with someone else's, the check still has to live in your pipeline. We'll do it in forty minutes."

---

### Slide 8 — Dependency confusion

"Second one. **Dependency confusion.** Close cousin of name confusion. Your org has an internal package — call it `AcmeSecrets`. It lives on an internal feed. An attacker notices you reference it in a public job log, in a workflow file, in a screenshot on a conference talk. [laugh beat] The attacker publishes a package with the same name to the public registry, with a higher version number. Next time your CI installs dependencies, the resolver picks the higher version. The higher version happens to be the attacker's.

Alex Birsan demonstrated this in 2021 against Apple, Microsoft, Tesla, PayPal, Shopify, Netflix, and a long list of others. Ten-thousand-dollar bug bounties all around. The PowerShell ecosystem has the same shape of risk the moment you have private modules with names that could be squatted publicly. The defense is to scope your resolver explicitly — the internal feed is authoritative for internal names, and those names aren't resolvable externally even by accident. Publisher-side discipline question. The pipeline's job is to remind you when you've forgotten."

---

### Slide 9 — Download-and-execute

"Third one. **Download-and-execute.** The install script fetches something at install time and runs it. The thing being fetched is not what was reviewed. The thing being reviewed is the *code that fetches*, not the code that runs.

This is the pattern. Hardcoded URL. `Invoke-WebRequest` into a variable. `Invoke-Expression` on the variable. Or the Chocolatey equivalent — `Install-ChocolateyPackage` with a URL but no checksum. Four lines. Each line on its own is legal PowerShell. Each line on its own is something you have probably written. The chain of four is remote code execution with no integrity guarantee.

Real incident: Serpent, 2022, targeting French organizations. Attackers used Chocolatey completely legitimately — installed Python through the real Chocolatey infrastructure — and then their own downstream tooling, running in the already-elevated context Chocolatey installs kick off, reached out and pulled a backdoor hidden in an image. Steganography. Chocolatey wasn't compromised. The pipeline around it had no idea what was executing.

The point I want you to sit with is that download-and-execute isn't exotic. It's normalized. Every vendor that ships a Chocolatey package wrapping a `.exe` installer is doing some version of this. The question isn't whether you download-and-execute. It's whether you pin what you downloaded against a hash you trusted at build time."

---

### Slide 10 — Floating dependencies (the lockfile gap)

"Fourth one. **Floating dependencies.** No single dramatic incident — it's the structural one, and that's what makes it scary.

Look at this `.psd1`. `RequiredModules` with `ModuleVersion = '2.0.0'`. That is not a pin. That is a floor. It means 'at least 2.0.0.' The consumer installs 'whatever is currently the highest version in PSGallery that satisfies the floor.' Monday's build and Tuesday's install can resolve to different dependency graphs with zero change to your code.

If you came from npm or cargo or Go, you already know what a lockfile is — a byte-identical pin of every transitive dependency, checked into source, applied at install. `package-lock.json`. `Cargo.lock`. `go.sum`. PowerShell doesn't have this. Not a missing feature about to ship — a genuinely unsolved ecosystem problem. Which means every PowerShell SBOM you have ever seen is describing *the author's build*, not *the consumer's install*. We're going to name that gap again later, because it changes what our receipts actually mean.

No attacker required here. Normal day, different resolution, potentially different behavior. The attacker version is when a transitive dependency quietly changes ownership and the new owner decides to test what happens when a popular module starts calling home. Which has happened in every other ecosystem. [laugh beat] Just not to us yet. That we know of."

---

### Slide 11 — Build-pipeline compromise

"Fifth one. **Build-pipeline compromise.** The scariest category, because the defenses you're used to trusting don't help you.

The attacker doesn't compromise the package. They don't compromise the vendor's code. They compromise the vendor's *build environment*. The installer that comes out is the real installer, from the real vendor, signed with the real code-signing cert — and it is already backdoored before anybody signs it. Every downstream check that asks 'is this from the vendor?' returns yes. Because it is.

Canonical incident: 3CX, 2023. Attackers compromised the build pipeline of a VoIP desktop app with around twelve million users. The signed installer the vendor distributed was already malicious. Every Chocolatey package that pointed at the official 3CX download URL — including perfectly well-maintained, well-intentioned ones — was distributing malware. The maintainers did nothing wrong. The checksums they had documented matched the file the vendor was serving. The file the vendor was serving was what the vendor meant to serve. The problem was one layer upstream.

The only defense here is in depth: pin hashes at build time, detect drift when they change, keep historical artifacts re-verifiable, and have provenance that lets you answer 'which of my builds consumed the bad upstream version.' None of those individually would have stopped 3CX. All of them together make the cleanup tractable instead of impossible."

---

### Slide 12 — Secret leakage and artifact drift

"Sixth one, and then we move on. **Secret leakage and artifact drift.**

Secret leakage — Aqua Nautilus, same 2023 research. They found PSGallery publishers who had accidentally shipped `.git/config` with GitHub tokens. They found publishing scripts containing PSGallery API keys in *unlisted* packages — packages the authors thought they had hidden — still accessible via the PSGallery API after the authors thought they had removed them. Because unlisting changes search visibility, not API reachability. PSGallery has improved this since; they responded. But the existence of the keys in the first place was a publisher-side failure, not a registry-side failure. We shipped the secrets. The registry just made them reachable longer than we wanted.

Artifact drift — and I want to be precise about how this actually works, because it's easy to get wrong.

`choco install` doesn't read `VERIFICATION.txt`. It only enforces checksums that are embedded directly in the install script via `-Checksum` and `-ChecksumType` parameters in `Install-ChocolateyPackage`. `VERIFICATION.txt` is documentation — for human reviewers, for CCR moderators, for anyone auditing the package manually. It has no effect at install time.

So the drift scenario is: vendor rotates the CDN, maintainer updates the URL in `chocolateyInstall.ps1`, forgets to update the `-Checksum` parameter. Or the install script never had one in the first place. `choco install` fetches whatever the new URL serves and runs it. No error. No warning. The install succeeds. [laugh beat, grim]

The malicious version of that is 3CX — the URL still looks right, the vendor is still the vendor, but the binary is already backdoored. The non-malicious version is every one of us on a Thursday afternoon. The install succeeds either way. The defense is the same in both cases: your pipeline pins the hash at build time and fails if it changes."

---

### Slide 13 — What the registries already do

"Before we pivot to tooling, I want to spend a slide on what the registries are already doing, because I think the shared narrative in our industry has been unfair to them.

The Chocolatey Community Repository runs a Validator for nuspec, script structure, and metadata rules. It runs a Verifier that actually performs install, uninstall, dependency checks, and silent-install verification in a reference VM — which is not free to operate. It runs Package Scanner through VirusTotal. It has a human moderation pass for non-trusted packages. Most of that is volunteer time.

PowerShell Gallery runs manifest validation, installation testing during validation, antivirus scanning, and PSScriptAnalyzer at error level on every upload. That's a non-trivial amount of automated scrutiny on every module that lands.

This is real infrastructure. I am not recommending you skip it. I am not recommending the pipeline we're about to build replaces it. What I *am* recommending is that by the time your package arrives at one of these registries, you can hand the moderator three things they don't currently receive: an SBOM, scan results, and a provenance document. Because the registries can't generate those retroactively — the source of truth is in the publisher's pipeline, and the publisher is *us*. [laugh beat: point at room] The receipts are ours to produce. That's the premise of the rest of the talk."

---

### Slide 14 — The three questions

"Three questions a maintainer should be able to answer before publishing.

What's in this package? SBOM. What did you check? Scan results in SARIF. Can you prove when and how it was built? Provenance.

I want to be honest up front: the answers I can give today are different for each question, and different for each ecosystem. The SBOM story works better for Chocolatey packages with embedded binaries than for pure PowerShell modules. The provenance story — I can produce a receipt; nobody's reading it at install time yet. I'm going to come back to that honest accounting at the end of the talk. This is the part where we earn the right to make those admissions."

---

## Act II — Building the Receipts

### Slide 15 — The flawed module

*Switch to the repo browser. Open `examples/powershell-module/ExampleModule/`.*

"PowerShell side first. This is the flawed module in the repo. Read it for what it is: not cartoonishly broken. This is the shape of the thing that ships when you're the solo maintainer, it's Friday, your toddler has an ear infection, and the release has to go out today. [laugh beat]

Floating dependency in the `.psd1`. `ScriptsToProcess` — same mechanism Aqua used in their typosquat PoC. An exported function with four labeled flaws. Pester passes. PSGallery would publish it. Everything that's wrong with this module is invisible to the tools in your CI right now. That's what to hold in your head."

---

### Slide 16 — The multi-statement pattern

"This is the pattern I want you to remember from the PowerShell side. Four lines.

PSScriptAnalyzer — which PSGallery already runs at publish time, and which is an excellent piece of software written by people who understand PowerShell more deeply than I do — will flag line four. `Invoke-Expression` is a code-quality warning. One finding, one line.

What PSScriptAnalyzer is *not* doing — and isn't designed to do, because it's a linter — is reading these four lines as a sequence. It's not saying 'the thing being evaluated just arrived from the network.' It's not saying 'the credential feeding the network request is hardcoded two lines up.' It's not connecting 'TLS validation was disabled earlier in the function' to 'a subsequent HTTPS request is about to run with no certificate checks.'

Semgrep's job is to see this as one pattern. Multi-statement. Variable-binding. Cross-line. That's the difference. Not 'Semgrep is better than PSScriptAnalyzer.' They do different jobs. Linter versus security scanner. Run both.

If you want the author-hygiene version of this whole conversation in depth — PSScriptAnalyzer extensions, InjectionHunter, custom AST rules for PII, SecretManagement and SecretStore for credentials at rest — Rob Pleau's Summit 2025 session, 'Stop Writing Insecure PowerShell,' is the layer below this one. Watch it if you haven't. This talk assumes that layer of hygiene is already the baseline; what we're doing here is what shows up when you go to publish."

---

### Slide 17 — A Semgrep rule, unabridged

"This is what a Semgrep rule looks like. YAML. No plugin. No DSL. No IDE dependency. The `$X` is a metavariable — binds an identifier across lines, which is how the pattern matches assignment-then-exec even with other statements between them.

The rules live in `semgrep-rules/` in the repo. Twelve for PowerShell, twelve for Chocolatey. Authoring cost is low enough that if your team has patterns specific to your environment — and you do, I promise you do — you can add rules for them in an afternoon. Fork the repo, extend the YAML, send a PR if you want them upstream. I will merge it. That is a promise. [laugh beat]"

---

### Slide 18 — Live SARIF in the PR

*[LIVE DEMO BEAT] Switch to a live browser tab. Show a PR with inline SARIF annotations.*

"This is the output from the reviewer's side. Annotations inline in the diff. Aggregated in the Security tab. Filterable by tool and severity.

The dollar cost of this is zero. The setup is one `github/codeql-action/upload-sarif` step at the end of each scanning job. If you took one thing from this talk and put it in your pipeline next week, this is the thing — visibility in the PR, no new dashboard to train your team on. Because we all know how training your team on a new dashboard goes. [laugh beat]"

*[Optional live beat: edit `Invoke-UnsafeFunction.ps1` on stage to introduce a slightly-changed flaw, commit, push, narrate for 60–90 seconds while the pipeline runs, show the annotation landing. Fallback: stay on the pre-populated PR, don't apologize for the switch — "here's one I prepared earlier" is fine.]*

---

### Slide 19 — The SBOM, and the gap inside it

"SBOM next. CycloneDX JSON, generated by Syft against the module directory. Components array. PURLs. Resolved versions. File hashes. Useful as an audit trail.

Now the honest part — this is the lockfile gap from Act I finally landing. This SBOM records what *I shipped*. It does *not* record what resolves on the consumer's machine when they `Install-Module` this thing. PowerShell has no lockfile. `Install-Module` resolves `RequiredModules` at install time against whatever is currently the highest-satisfying version in PSGallery. I ship Monday. You install Tuesday. Your dependency graph might differ from mine. My SBOM tells you what I built. It doesn't tell you what ran on your machine.

That is the single biggest unsolved problem in PowerShell supply chain security today, and I want to be clear: nobody on stage or in the registry team has a clever fix hiding in their back pocket. Not me. Not PSGallery. Not Microsoft. The current workaround is to pin `RequiredVersion` — exact version — instead of `ModuleVersion`, and enforce with `dependency-pin-check`. Maintainer-side commitment, not a consumer-side guarantee. We come back to this in Act III."

---

### Slide 20 — Vulnerability scan, and the retroactive payoff

"Grype reads the SBOM from the previous step. Runs it against NVD and the GitHub Advisory Database. Findings go back into Code Scanning.

Build-time value: obvious. Less-obvious value: retroactive. The SBOM is retained as an artifact for a year by default. When a CVE drops six months from now against a dependency you shipped, you re-run Grype against the stored SBOM from that release and you know in seconds which builds were affected. That is incident response, not prevention. Both matter — and in my experience, in an enterprise, the incident-response case is what actually gets this pipeline funded, not the build-time gating. Because leadership has sat through the other kind of incident, the one where you're trying to figure out *after the fact* whether a given build is exposed, and nobody has an answer, and everybody stays late. [laugh beat, knowing]"

---

### Slide 21 — Provenance, and the consumer who isn't there

"Provenance. Source repo, commit SHA, workflow reference, artifact hash, timestamp. Here's the receipt.

Now. Who's reading this receipt? `Install-Module` doesn't check it. `choco install` doesn't check it. The registries don't require it at upload. No install-time verifier ships in the ecosystem today. I produce the provenance. The consumer never asks to see it.

That is a real problem with the current state of this, and I'm not going to pretend it isn't. What I can say is the provenance is useful *to the maintainer* right now. If a customer ever asks 'can you prove the module you shipped on this date came from this commit and was built by this pipeline,' I can answer. If an incident happens and I need to establish definitively which build produced which artifact, I have it. That's maintainer-side audit value — real, but narrower than an end-to-end story.

The full loop closes when the registries require signed provenance at upload and the install tooling verifies at install. Both are ecosystem-scale asks. Not my pipeline's problem to solve, and frankly, not any single pipeline's problem to solve. What I can do in the meantime is produce the receipts now, so the day a verifier ships, my back catalog is ready to be read. That's the bet."

---

### Slide 22 — PowerShell pipeline, actual run

"Full pipeline, end to end. Three and a half minutes cold. Under two minutes once Grype's database is cached. Non-blocking by default. Every step is a composite action you can pull independently. You don't have to buy the whole pipeline."

---

### Slide 23 — Chocolatey changes the threat model

"Switching to Chocolatey. Everything we just built applies. On top of that, Chocolatey tightens the threat model in three ways.

Install scripts run as admin. The package is typically a three-kilobyte wrapper around a fifty-megabyte external binary, which means the package's security is mostly the security of an external download. And moderation doesn't reach internal repositories, which is where a lot of Chocolatey is actually deployed — and where, again, the CCR volunteers can't help you, even if they wanted to.

That combination is why the Chocolatey pipeline adds three checks the PowerShell pipeline doesn't need."

---

### Slide 24 — The flawed Chocolatey package

"This is the package from the cold open. Nuspec with missing metadata and dependency versioning risk. Install script with the three flaws we already looked at. `VERIFICATION.txt` with no checksums.

Not a contrived example. This is the shape of something I have personally helped review in two different enterprises. [laugh beat, rueful] Both times the author was extremely senior. Both times the package had been in production for months. Neither time was the author trying to do anything wrong. They were trying to ship the thing."

---

### Slide 25 — Pre-publish validation

"First Chocolatey-specific check: pre-publish validation. Queries the CCR API, runs a Levenshtein similarity check against existing package names, and checks nuspec metadata completeness — `projectUrl`, `iconUrl`, tags, description.

Cheap to run. Narrow in what it catches — won't stop a determined attacker who has already published, but it catches accidental name collisions before *you* publish, and surfaces potential typosquat neighbors for reviewers.

I want to be precise about what this is: this is *our* pipeline doing these checks. This is not a CCR moderation phase. CCR has its own validator rules. We're front-running some of them so the feedback lands in your PR instead of in a moderation queue.

Not going to spend long on this. Cheapest check in the pipeline. Moving on."

---

### Slide 26 — Checksums and VERIFICATION.txt drift

"Three checks. Every external download has a checksum. The algorithm is SHA256 or better — the pipeline prefers SHA256+ and flags MD5 or SHA1 for reviewer attention. And our pipeline cross-checks `VERIFICATION.txt` entries against the actual embedded files on disk.

Two things I want to be precise about. First: CCR moderation requires checksums on remote downloads — that's their policy, and it's a good one. Outside CCR moderation, Chocolatey's runtime behavior is looser — HTTP or FTP without a checksum fails by default, but HTTPS downloads may still install unless you tighten the runtime config. So the 'no checksum' problem doesn't always surface at install time. Our pipeline surfaces it at build time.

Second: the `VERIFICATION.txt` reconciliation is our pipeline's check. CCR's validator checks that a `VERIFICATION.txt` file exists — that's CPMR0006. Whether the automated tooling also checks that the hashes *inside* that file actually match the binaries in the package, I genuinely don't know — and if there's a CCR person in the room, I'd love to hear it. Either way, doing this check in your own pipeline means you catch drift before the package ever reaches moderation.

I already told the drift story in Act I, so I'll keep it short — but with the precise mechanism now clear. The runtime doesn't read `VERIFICATION.txt`. What it reads is the `-Checksum` parameter in `Install-ChocolateyPackage`. If that parameter is missing or stale, the install succeeds regardless of what `VERIFICATION.txt` says. Our pipeline catches this at build time by verifying that every external download has a checksum in the install script and that it matches what's actually being served.

Malicious version: 3CX. Non-malicious version: every one of us. The install succeeds either way. This is the most specifically-Chocolatey check in the pipeline and, in my experience, the one that catches the most real issues in internal-repo packages."

---

### Slide 27 — Install-script analysis

"Four rule categories. Raw `Invoke-WebRequest` outside Chocolatey's helpers — bypasses Chocolatey's built-in checksum enforcement, which exists and is good, and if you're writing around it you should probably stop. [laugh beat] Registry writes and service creation without a documentation comment — in a script that runs as admin, the reviewer needs to know why. Hardcoded internal URLs — leaks your internal topology if the package ever leaves the internal repo. PATH modification without matching uninstall cleanup — that one gets its own slide."

---

### Slide 28 — The PATH story

"Install script appends `C:\tools\myapp` to the machine PATH. Uninstall script doesn't remove it. Six months later, someone uninstalls the package — the PATH entry stays.

If that directory's ACLs ever let non-admins write to it — depending on the installer that created it, that happens more than you'd like — anyone with a local shell can drop a `git.exe`, a `python.exe`, a `node.exe` there. Windows PATH resolution finds them before the real ones. The next person who types `git` on that machine runs whatever got dropped.

Documented LPE precondition. Misconfigured PATH entry from a forgotten Chocolatey package is a common way it gets set up. The Semgrep rule doesn't know whether the directory is writable. It knows the cleanup is missing. In a context where the script runs as admin, that's enough to make it reviewable — and it's the finding I most often see get fixed quietly with no fuss, because the author immediately recognizes the shape of the problem."

---

### Slide 29 — Chocolatey pipeline, actual run

"Chocolatey pipeline. Same five output artifacts as the PowerShell pipeline — two SARIF reports, an SBOM, Grype results, provenance. Ecosystem-specific checks. Same shape."

---

## Act III — What's Still Missing, and Monday

### Slide 30 — Three unsolved problems

"Now the honest accounting. Three things this pipeline does not solve.

**One, the lockfile gap.** Covered it. The Chocolatey version is slightly better — `.nuspec` dependencies can be pinned to exact versions, and `dependency-pin-check` in our pipeline enforces it. The PowerShell version is worse, and no composite action I write is going to fix it. Real fix is a PowerShell lockfile — a platform-level change. If that's something you work on or can advocate for, this is me advocating for it.

**Two, consumers aren't reading receipts.** `Install-Module` and `choco install` don't verify provenance. Production of receipts runs ahead of verification. Gap closes when the registries require signed provenance at upload and the clients verify at install. Both are ecosystem-level decisions — and CCR and PSGallery are in the room, and they know it, and the answer to 'why haven't you shipped this yet' is always 'backward compatibility, resource constraints, and a careful rollout plan.' Which, when I was sysadmin-side of this conversation, I had opinions about. Now that I've been on the other side of ship-versus-don't-break-everyone decisions, I have more patience with the answer. [laugh beat]

The PSResourceGet team has been showing direction — Michael Green and Sydney Smith at Summit last year walked through MAR, PSResourceGet over OCI, GPO allowlisting through Intune and Azure Policy. That's the closed-loop version of what we're producing receipts for: the client knows which registries to trust, and the registry publishes signed artifacts with identity-level guarantees. Not shipped everywhere — discovery across vendor registries, dependency resolution across MAR and PSGallery, and caching from the NuGet-v2 gallery into an OCI registry are all still open questions they're actively soliciting feedback on. The worthwhile thing I can do in the meantime is produce the receipts now, so the day a verifier ships, my back catalog is ready to be read.

**Three, internal repositories.** CCR has moderators. Your internal Chocolatey repo typically doesn't. In that context, this pipeline is not a *complement* to moderation — it *is* the moderation. That changes how seriously you take enforcement. On a community package I'd say 'start non-blocking, tune, enforce when ready.' On an internal package shipped to thousands of endpoints with no human review — start blocking on critical checks immediately. Don't be polite with your own infrastructure."

---

### Slide 31 — Monday-morning adoption path

"Three steps for next week.

One, one afternoon: PSScriptAnalyzer with SARIF upload and Semgrep with one rule file, non-blocking. You'll see what fires. You will get false positives. Expect them. Do not open seventy-four Jira tickets on day one. [laugh beat]

Two, one afternoon, later the same week or next: SBOM and provenance generation. Both single-composite-action adoptions. Neither blocks anything — they produce artifacts.

Three, ongoing: tune rules, add suppressions with justifications, decide which findings block a merge.

What *not* to do on day one: don't turn on enforcement before you've seen the baseline. That is how security gates get disabled quietly three months later when the team gets tired of them. Visibility first. Enforcement after you've earned it."

---

### Slide 32 — The repo, and the last line

"Repo is on screen. `examples/` has the flawed module and the flawed package. `actions/` has eight composite actions you can adopt individually. `semgrep-rules/` has the YAML rules. `docs/` has the threat model, tooling decisions, enterprise integration, and a remediation guide for every finding type the pipeline surfaces.

You don't need to have been in this room to use the repo. The decisions are written down — so when your VP of Engineering asks 'wait, why are we doing this?' six months from now, you have something to point at that isn't a hand-wave. [laugh beat]

That's the talk. Receipts are useful even when nobody reads them — until the day someone does. I'll take questions."

---

### Slide 33 — Q&A

*Pause. Look up. Don't fill the silence.*

"While you're thinking, a few I get often:

- **How does this compare to Chocolatey's moderation?** Complementary. Moderation is registry-side. This pipeline runs before your package reaches the registry. You want both. And the moderators would like you to send them packages that are easier to moderate. Everyone wins.
- **Does this work with Azure DevOps?** Concepts are identical, tools are portable. The composite actions are GitHub-specific. The tools — PSScriptAnalyzer, Semgrep, Syft, Grype — run anywhere. SARIF upload is the main thing that changes.
- **What about internal Chocolatey repos?** This is actually where the pipeline adds the most value. Internal feeds don't get CCR-style moderation unless you build or buy that process yourself. You're the only line of defense.
- **You work at Wiz — is this a vendor pitch?** No, and let me say it plainly. Nothing in this pipeline depends on Wiz or any proprietary platform. Everything is free and open source. The reason runtime context matters — whether you use Wiz, a competing CSPM, or nothing — is that a CVE at build time doesn't tell you whether the vulnerable component is deployed, reachable, or running with privilege. That's a real gap, and somebody will close it. I have opinions about who. That's not the point of this talk. [laugh beat]
- **How do you handle legitimate `Invoke-WebRequest` usage that gets flagged?** Inline suppression with justification. Flag everything, suppress with a comment explaining why it's intentional, the suppression ships in SARIF, reviewers see it in the PR.
- **Does this slow CI?** Two to five minutes for a typical module or package. Most of that is Grype downloading its vulnerability database on first run. Caches after.

What else have you got?"

---

## Demo and delivery notes

### Before the talk

- Repo open in a browser tab with a PR whose pipeline results are already populated (fallback path).
- Second tab: a working checkout ready to edit and push (live path, optional).
- Pre-loaded tabs: repo overview, PR with SARIF annotations, Actions workflow run, SBOM artifact, provenance artifact.
- SARIF JSON, SBOM JSON, and provenance JSON open locally in an editor as deep fallback if the browser dies.
- Pre-warm Grype's cache on the demo machine.
- Test both workflows end-to-end at least twice in the week prior.
- Verify Grype has a non-empty finding set — add a dependency with a known CVE to the example module if needed, otherwise slide 19 lands on an empty table.

### Live demo beat (slide 17)

If scheduling and Wi-Fi allow, live moment: edit `Invoke-UnsafeFunction.ps1` on stage to introduce a slightly-changed flaw, commit and push, narrate for 60–90 seconds while the pipeline runs, show the annotation landing in the PR. High reward, moderate risk.

Fallback: stay on the pre-populated PR, show the existing annotations, move on. Don't apologize or narrate the switch — "here's one I prepared earlier" is fine.

### Timing guide (90 minutes)

| Section | Slides | Target |
|---------|--------|--------|
| Act I — Ecosystem gap + six threats | 1–13 | 22–25 min |
| Act II — Building (PowerShell) | 14–21 | 18–20 min |
| Act II — Building (Chocolatey) | 22–28 | 15–17 min |
| Act III — Unsolved + Monday | 29–31 | 10–12 min |
| Q&A | 32 | 10 min |

### If you fall behind

Drop slides 7 (dependency confusion) and 19 (Grype) first. Dependency confusion can be folded into slide 6 as a two-sentence coda. Grype can be mentioned on slide 18 as "SBOM feeds a CVE scanner, here are the findings, moving on." Both are single-beat slides whose content survives compression.

### If you finish early

Go deeper on any of the three unsolved problems in Act III — each could be its own 20-minute talk, and a Chocolatey Fest audience will have specific questions about internal-repo enforcement in particular. Take them.

### Delivery reminders

- `[laugh beat]` markers indicate where the line is intended to land. Give the line air; don't step on it.
- Collegial framing for PSGallery and CCR throughout. The gap is the layer before their work, not their work.
- The receipts belong to the publisher. That's the thesis. Say it plainly when asked.
