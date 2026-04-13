---
marp: true
theme: summit-2026
paginate: true
---

<!--
  Presentation reviewed using the death-by-ppt skill by HeyItsGilbert
  https://github.com/HeyItsGilbert/marketplace/blob/main/plugins/presentation-review/skills/death-by-ppt/SKILL.md
-->

<!-- _class: title -->

# Provenance Before Publish

## What your PowerShell and Chocolatey receipts should look like — and what's still unsigned

<p class="name wide">Adil Leghari</p>
<p class="handle wide">github.com/adilio/publish-with-receipts</p>

<!--
*Walk up. Let the title sit for two beats. Sip of water.*

"Thanks for coming. I know you had five options this slot. I'll try to make this worth the choice."
-->

---


<!-- _class: sponsors -->

# Thanks!

<!--
Gotta thank the sponsors!
-->

<!--
*15 seconds. Don't dawdle.*

"Quick thank-you to the sponsors — the room you're sitting in and the lunch you're about to eat are on them. You know the drill."
-->

---


## Supply chain attacks are no longer edge cases

<ul class="primary-list">
<li><strong>XZ Utils (2024)</strong> — two years of social engineering to backdoor a Linux compression library shipping in major distros</li>
<li><strong>Axios (2026)</strong> — compromised npm maintainer account published malicious versions with a post-install payload</li>
<li><strong>tj-actions/changed-files (2025)</strong> — widely-used GitHub Actions step compromised, CI pipelines across thousands of repos exfiltrating secrets</li>
</ul>

<p class="muted">The pattern is the same every time: trusted infrastructure becomes the attack vector. The thing that was supposed to be safe is the thing that runs.</p>

<!--
"Supply chain attacks used to sound like something that happened to other people — nation-state targets, critical infrastructure, household names. That's not the world we're in anymore.

Let me give you the three on the slide, because they're worth knowing by name.

**XZ Utils, 2024.** Jia Tan — a persona that now appears to have been a nation-state-backed identity — spent roughly two years building trust as a contributor to XZ Utils, a compression library that ships in virtually every Linux distribution. In 2024, that persona introduced a carefully hidden backdoor into the build system — specifically in the M4 autoconf macros used to build the library on Debian- and RPM-based systems. The backdoor was a function hook injected into liblzma that intercepted RSA key operations in OpenSSH when the library was dynamically linked. On the affected systems, anyone holding the right private key could authenticate over SSH without a password. Two years of social engineering. The trust was built slowly, patiently, and with legitimate contributions. The Debian and Fedora unstable and testing branches had already picked up the compromised version. It was caught by Andres Freund at Microsoft — not by any automated scan — when he noticed that SSH logins on his machine were using 500ms more CPU than expected. That's how close it got.

**Axios, 2026.** More recent, and the shape is simpler. An npm maintainer account for the Axios HTTP library — which gets downloaded roughly a billion times a month — was compromised. The attacker published a malicious minor version with a post-install script that executed a payload on every machine that ran `npm install axios`. Installation itself was the delivery step. No exploit required. The package manager ran the code because that's what package managers do when they install something.

**tj-actions/changed-files, 2025.** A widely-used GitHub Actions step — one of the most-referenced actions in CI configs across the whole GitHub ecosystem, used to detect which files changed in a PR — was compromised. The attacker modified the action to print CI secrets to the job log. Because of how GitHub Actions passes secrets, many pipelines had tokens, API keys, and cloud credentials flowing through jobs that referenced this action. Thousands of repositories were affected. The interesting detail: the compromise happened by injecting into the action's code, not the caller's workflow. Every workflow that pinned to a mutable tag like `@v35` instead of a specific commit SHA got the malicious version automatically.

What connects all three: **trusted infrastructure became the attack vector.** Not a malicious email. Not a misconfigured server. The thing that was supposed to be safe is exactly the thing that ran. And in each case, the compromise had a window — sometimes hours, sometimes months — during which normal builds, normal package installs, and normal CI runs were spreading it.

So the lesson is not 'trust nothing.' It's 'assume the routine-looking thing is exactly where the abuse will hide.'"
-->

---

## AI is compressing the time to exploit

<div class="columns">
<div>

### Before AI
<ul class="secondary-list">
<li>Weeks from disclosure to working exploit</li>
<li>Skilled team required</li>
<li>High cost per target</li>
</ul>

</div>
<div>

### Now
<ul class="quaternary-list">
<li>Days — sometimes hours — from CVE to working exploit</li>
<li>Automated variant generation</li>
<li>zerodayclock.com</li>
</ul>

</div>
</div>

<p class="muted">The window between "vulnerability disclosed" and "vulnerability exploited" is closing faster than patch cycles. Provenance and receipts don't stop a zero-day — but they tell you which builds are exposed in minutes, not weeks.</p>

<!--
"The reason supply-chain security feels more urgent right now isn't just that attacks are more common. It's that the response window is shrinking.

There's a site — zerodayclock.com — that tracks the time between a CVE being published and active exploitation in the wild. Pull it up sometime and just watch the numbers. What used to be measured in weeks is now measured in days. Sometimes hours. AI tooling is being used by attackers to generate variants, scan at scale, and move faster than a human response team can.

This doesn't change what we're building today. Provenance and SBOMs don't stop a zero-day. But they do mean that when the next one drops — and it will — you can run Grype against your stored SBOMs and know in minutes which of your builds are exposed. Not weeks of manual archaeology. Minutes. That's the value of the receipt."
-->

---

## This hasn't happened to PSGallery or CCR — that we know of

<div class="callout secondary">

### The registries do real work. The attack surface is real too.
PSGallery hosts tens of thousands of modules. CCR serves packages to millions of installs. Neither has been compromised at the infrastructure level — as far as anyone has publicly disclosed.

</div>

<ul class="quaternary-list">
<li>Same dependency on trusted CDNs, author credentials, and build pipelines</li>
<li>Same install-time execution model that made XZ and tj-actions dangerous</li>
<li>No lockfile. No mandatory provenance. No install-time receipt verification.</li>
</ul>

<p class="muted">The gap isn't the registries. The gap is the layer before them — the publisher's pipeline. That's what this talk is about.</p>

<!--
"I want to be careful here, because the PSGallery team and the CCR team are in this room and they do real work that I respect.

As far as anyone has publicly disclosed, neither registry has been compromised at the infrastructure level. That's genuinely good. It's not luck — it's the result of people taking security seriously.

What I'm pointing at is the structural exposure. PSGallery and CCR still have the same shape of risk that made XZ, Axios, and tj-actions dangerous: install-time execution, trust in package authors, dependency on upstream binaries, and no install-time receipt verification.

The difference is that the publisher-side tools for provenance and receipts are thinner here than in ecosystems like npm or cargo. Not because the registries failed — because the tooling hasn't been built yet. That we know of is doing a lot of work in the title of this slide. The honest answer is we don't know what we haven't found, which is another way of saying the absence of evidence is not evidence of absence.

That's the gap. And that's what we're here to close — on the publisher side, before the package reaches the registry."
-->

---


## The six attacks you need names for

<ol class="primary-list">
<li><strong>Name confusion</strong> — typosquats and lookalikes</li>
<li><strong>Dependency confusion</strong> — internal vs. public resolution</li>
<li><strong>Download-and-execute</strong> — install-time code fetches</li>
<li><strong>Floating dependencies</strong> — no lockfile, no floor</li>
<li><strong>Build-pipeline compromise</strong> — the vendor was the problem</li>
<li><strong>Secret leakage &amp; artifact drift</strong> — what you shipped isn't what you meant to ship</li>
</ol>

<p class="muted">One slide each. Analogy, real incident, one line on why our ecosystem is susceptible.</p>

<!--
"Before we go anywhere near tooling, I want to give you names for six things. Because in my experience — and this might just be me — practitioners know something bad can happen here, but they haven't had the categories put to them plainly. And once you have names for the categories, the defenses fall out naturally.

Six slides. One each. Analogy, real incident, one line on why our ecosystem specifically is susceptible. If you have heard all six and want to zone out for six minutes, I will not be offended. [laugh beat] If you haven't, the rest of the talk assumes these names.

I'm not giving you labels for their own sake. I'm giving you a shared vocabulary for the thing we already know is wrong. Once the room agrees on the shape of the problem, the rest of the talk becomes easier to follow."
-->

---


## Threat 1 — Name confusion

<div class="columns">
<div>

### `AzTable`  vs.  `Az.Table`

One dot. Ten million downloads of impersonation surface.

<ul class="secondary-list">
<li>Aqua Nautilus, 2023 — registered <code>Az.Table</code> to impersonate <code>AzTable</code></li>
<li>Callbacks from production Azure within hours</li>
</ul>

</div>
<div>

### Why it works here

<ul class="quaternary-list">
<li>PSGallery has no moniker rules — a shared-challenge problem</li>
<li>npm and cargo have structural name checks; we don't</li>
<li>MAR (via PSResourceGet/OCI) is the registry-layer answer for <em>Microsoft-published</em> modules — may not help community or third-party</li>
</ul>

</div>
</div>

<p class="muted">Registry-layer direction: Michael Green &amp; Sydney Smith, Summit 2025 — "Supply Chain Security: PSResourceGet Direction."</p>

<!--
"First one. **Name confusion.** Attacker registers a package whose name differs from a popular one by one character, one dot, one dash. A developer mistypes. Autocomplete confidently recommends the wrong one. Somebody copies from a Stack Overflow answer from 2019 where the typo was already baked in. The wrong package installs. The wrong package runs.

Aqua Nautilus did this for real in 2023. They registered `Az.Table` — same letters, extra dot — to impersonate `AzTable`, which at the time had more than ten million downloads. Callbacks from production Azure environments within hours. Not a prank. A proof of concept that worked the first time they tried it.

The reason it worked is that PSGallery, unlike npm, doesn't have moniker rules at the registry layer. That's not a failing of the PSGallery team — and I want to explain why, because it's worth understanding.

Moniker rules — rules that say 'this name is too similar to an existing package and we won't accept it' — sound simple but they're genuinely hard to get right. The problem is that **legitimate forks exist**. If you maintain a module, and someone forks it to fix a bug you haven't merged, the fork will often have a closely related name. `Az.Table` and `AzTable` could be a squatter and a victim — or two maintainers who legitimately chose similar names. The registry can't always know which. A false positive blocks a legitimate publisher. A false negative lets the squatter through. And the community gets upset at both outcomes.

It gets harder in an open-source ecosystem with forks. On npm or cargo, there are namespace mechanisms — you publish under your org's scope, so `@mycompany/package` is structurally distinct from `@othercompany/package`. PowerShell's name resolution doesn't have a scope concept like that. Every module in PSGallery is in a flat namespace. Which means the edit distance between a legitimate fork and a typosquat can be exactly one character — and the registry has no structural signal to tell them apart. The whole challenge is distinguishing 'intentional fork' from 'malicious lookalike' using only the name, the metadata, and whatever download history exists.

So when I say 'shared-challenge problem,' I mean it: the registry can implement heuristics and flag suspicious names for human review, but without a scope system or cryptographic publisher identity, there's a hard ceiling on what automated name rules can do. CCR moderators actually shoulder a significant part of this for community packages — human review catches things the automation can't.

Microsoft's in-progress answer at the registry layer is the Microsoft Artifact Registry and PSResourceGet over OCI. Structural fix: only Microsoft can publish under the MAR namespace, so you literally can't squat on `MAR/PSResource/Az.Accounts`. Different layer from this talk. Also not shipped for most of what you install today — only the Azure PowerShell team is fully onboarded, and MAR doesn't help for community packages or third-party vendor modules. Which means if you care whether your package is confusable with someone else's, the check still has to live in your pipeline."

In practice, this is why I don't treat typosquat prevention as a registry-only problem. Registry support is great when it exists, but the maintainer still needs a pre-publish signal that says 'this name is dangerously close to something else' before the package gets out the door."
-->

---


## Threat 2 — Dependency confusion

```
Internal feed:    AcmeSecrets v1.2.3
Public PSGallery: AcmeSecrets v9.9.9   ← higher version wins
```

<ul class="secondary-list">
<li>Attacker publishes <code>AcmeSecrets</code> publicly with a higher version</li>
<li>Resolver picks the higher version — which is the attacker's</li>
<li>Alex Birsan, 2021 — the same trick against Apple, Microsoft, Tesla, PayPal, Shopify, Netflix</li>
</ul>

**Defense:** scope your resolver explicitly — internal feed is authoritative for internal names, and those names aren't resolvable externally even by accident.

<!--
"Second one. **Dependency confusion.** Close cousin of name confusion. Your org has an internal package — call it `AcmeSecrets`. It lives on an internal feed. An attacker notices you reference it in a public job log, in a workflow file, in a screenshot on a conference talk. [laugh beat] The attacker publishes a package with the same name to the public registry, with a higher version number. Next time your CI installs dependencies, the resolver picks the higher version. The higher version happens to be the attacker's.

Alex Birsan demonstrated this in 2021 against Apple, Microsoft, Tesla, PayPal, Shopify, Netflix, and a long list of others. Ten-thousand-dollar bug bounties all around. The PowerShell ecosystem has the same shape of risk the moment you have private modules with names that could be squatted publicly.

The defense is to scope your resolver explicitly — the internal feed is authoritative for internal names, and those names aren't resolvable externally even by accident.

And here Chocolatey actually has a useful mechanism worth knowing: **source priority.** When you have Chocolatey configured with multiple sources — say an internal Nexus or Artifactory repo alongside the public CCR — you can set a priority on each source. Lower numbers win. If your internal feed is priority 1 and CCR is priority 100, the resolver reaches your internal feed first for every package name. If `AcmeSecrets` exists at priority 1, the resolver never even asks CCR for it, regardless of version number. This is not a perfect defense — you still have to name your internal packages thoughtfully, and source priority can be misconfigured — but it's a concrete tool that exists today for Chocolatey environments. `choco source add --name internal --source https://your-nexus/repo --priority 1`. Publisher-side discipline question; the pipeline's job is to remind you when you've forgotten.

The painful part is how ordinary the mistake looks. Nobody has to be reckless. A build log, a pasted command, a debug screenshot, and suddenly your internal package name is public enough for somebody else to race you to the registry."
-->

---


## Threat 3 — Download-and-execute

```powershell
$url = "https://example.com/bootstrap.ps1"
$X   = Invoke-WebRequest -Uri $url
Invoke-Expression $X                # content is not what was reviewed

# Or the Chocolatey equivalent:
Install-ChocolateyPackage -Url $url # no checksum, no integrity guarantee
```

**Serpent, 2022:** used Chocolatey legitimately to install Python, then downstream tooling pulled a backdoor hidden in an image (steganography). Chocolatey wasn't compromised. The pipeline around it had no idea what was executing.

<p class="muted">Every vendor wrapping a <code>.exe</code> installer does some version of this. The question isn't whether you download-and-execute — it's whether you pin what you downloaded against a hash you trusted at build time.</p>

<!--
"Third one. **Download-and-execute.** Let me explain the concept before we name the incident, because I want the pattern to be clear.

When you install a package, you typically expect the package to *contain* the code it runs. You reviewed what's in the package. You trust what's in the package. But download-and-execute breaks that assumption: the package contains a *script that fetches something* at install time, and then *runs that fetched thing*. The reviewed artifact — the thing you submitted to CCR, the thing the moderator looked at — is the fetching code. Not the executed code. Those are two different things, and only one of them is what actually runs on the end user's machine.

That's the gap. You reviewed the courier. You didn't review what was in the envelope. And the envelope arrives at install time, from a URL you don't control.

The pattern looks like this. Hardcoded URL. `Invoke-WebRequest` into a variable. `Invoke-Expression` on the variable. Or the Chocolatey equivalent: `Install-ChocolateyPackage` with a URL but no `-Checksum` parameter. Four lines. Each line on its own is legal PowerShell. Each line on its own is something you've probably written for a totally valid reason. The chain of four is remote code execution with no integrity guarantee at install time.

Now the incident. **Serpent, 2022.** This campaign targeted French entities — construction and real estate companies — in what appears to have been a targeted espionage operation. The attackers sent phishing emails containing Chocolatey install commands. When the recipient ran them, Chocolatey did exactly what Chocolatey is supposed to do: it installed Python. Completely legitimate. Real Python, from the real infrastructure, no compromise in Chocolatey itself.

But the attackers had also planted tools that, once Python was installed and running in that already-elevated administrative context that Chocolatey operates in, reached out over the network to fetch a second-stage payload. That payload was hidden inside an image file using steganography — a technique where data is concealed within the pixel values of an ordinary-looking image. The image looked like a picture. The tools extracted a backdoor from it.

At no point did a security tool flag Chocolatey's behavior as malicious, because Chocolatey's behavior wasn't malicious. The install looked legitimate. The image looked legitimate. The malicious part was the *combination* — the trusted tool, the elevated context, and the unaudited network fetch that happened after the package ran.

The point I want you to sit with is that download-and-execute isn't exotic. It's normalized. Every vendor that ships a Chocolatey package wrapping a `.exe` installer is doing some version of this. The question isn't whether you download-and-execute. It's whether you pin what you downloaded against a hash you trusted at build time — before the package left your hands — so that the thing that runs on the end user's machine is provably the thing you tested."

This is why I keep repeating 'build time' instead of 'install time.' Once the machine is already executing the script, you've lost the best chance to prove what was supposed to happen. The only place you still have enough context to validate the fetch is before you publish."
-->

---


## Threat 4 — Floating dependencies (the lockfile gap)

```powershell
# .psd1 — a floor, not a pin
RequiredModules = @(
    @{ ModuleName = 'Az.Accounts'; ModuleVersion = '2.0.0' }
)
```

<ul class="quaternary-list">
<li>Resolved at <em>install</em> time, not publish time</li>
<li>Monday's build and Tuesday's install can differ, with no code change</li>
<li>npm has <code>package-lock.json</code>, cargo has <code>Cargo.lock</code>, Go has <code>go.sum</code> — PowerShell has a list of floors</li>
</ul>

<p class="muted">This is the structural one. No attacker needed — normal day, different resolution, potentially different behavior. We'll name it again when we get to SBOMs.</p>

<!--
"Fourth one. **Floating dependencies.** No single dramatic incident — it's the structural one, and that's what makes it scary.

Look at this `.psd1`. `RequiredModules` with `ModuleVersion = '2.0.0'`. That is not a pin. That is a floor. It means 'at least 2.0.0.' The consumer installs 'whatever is currently the highest version in PSGallery that satisfies the floor.' Monday's build and Tuesday's install can resolve to different dependency graphs with zero change to your code.

If you came from npm or cargo or Go, you already know what a lockfile is — a byte-identical pin of every transitive dependency, checked into source, applied at install. `package-lock.json`. `Cargo.lock`. `go.sum`. PowerShell doesn't have this. Not a missing feature about to ship — a genuinely unsolved ecosystem problem. Which means every PowerShell SBOM you have ever seen is describing *the author's build*, not *the consumer's install*. We're going to name that gap again later, because it changes what our receipts actually mean.

No attacker required here. Normal day, different resolution, potentially different behavior. The attacker version is when a transitive dependency quietly changes ownership and the new owner decides to test what happens when a popular module starts calling home. Which has happened in every other ecosystem. [laugh beat] Just not to us yet. That we know of."

This is the kind of bug that slips through because nothing looks broken. The build passes. The package installs. The only thing that changed is the resolver. That's exactly why it belongs in the talk about receipts."
-->

---


## Threat 5 — Build-pipeline compromise

```
vendor source → [ compromised build env ] → signed installer → your package
                            ↑ backdoored before signing
```

**3CX, 2023.** Attackers compromised the vendor's build pipeline. The signed installer the vendor distributed was already malicious. Every package pointing at the official 3CX URL — including perfectly well-maintained ones — was distributing malware.

<p class="muted">Defense is in-depth: pin hashes at build time, detect drift, keep historical artifacts re-verifiable, and have provenance that answers "which of my builds consumed the bad upstream." None stops 3CX alone. All together make the cleanup tractable.</p>

<!--
"Fifth one. **Build-pipeline compromise.** The scariest category, because the defenses you're used to trusting don't help you.

The attacker doesn't compromise the package. They don't compromise the vendor's code. They compromise the vendor's *build environment*. The installer that comes out is the real installer, from the real vendor, signed with the real code-signing cert — and it is already backdoored before anybody signs it. Every downstream check that asks 'is this from the vendor?' returns yes. Because it is.

Canonical incident: 3CX, 2023. Attackers compromised the build pipeline of a VoIP desktop app with around twelve million users. The signed installer the vendor distributed was already malicious. Every Chocolatey package that pointed at the official 3CX download URL — including perfectly well-maintained, well-intentioned ones — was distributing malware. The maintainers did nothing wrong. The checksums they had documented matched the file the vendor was serving. The file the vendor was serving was what the vendor meant to serve. The problem was one layer upstream.

The only defense here is in depth: pin hashes at build time, detect drift when they change, keep historical artifacts re-verifiable, and have provenance that lets you answer 'which of my builds consumed the bad upstream version.' None of those individually would have stopped 3CX. All of them together make the cleanup tractable instead of impossible."

This is the category that makes people stop and stare because it breaks the normal trust chain. The vendor is not malicious, the installer is signed, the checksum matches, and the compromise still lands. That's why receipt generation has to happen before the vendor artifact becomes your package."
-->

---


## Threat 6 — Secret leakage &amp; artifact drift

<div class="columns">
<div>

### Secret leakage

<ul class="secondary-list">
<li>Aqua Nautilus, 2023 — <code>.git/config</code> with GitHub tokens</li>
<li>PSGallery API keys in <em>unlisted</em> packages — unlisting changes search visibility, not API reachability</li>
<li>PSGallery has since improved this; existence of the keys was still a publisher-side failure</li>
</ul>

</div>
<div>

### Artifact drift

<ul class="quaternary-list">
<li>Vendor rotates CDN — maintainer updates the URL, forgets to update <code>-Checksum</code> in the install script</li>
<li><code>choco install</code> succeeds — it only checks checksums specified in the install script, not in <code>VERIFICATION.txt</code></li>
<li><code>VERIFICATION.txt</code> is documentation for moderators, not runtime enforcement</li>
</ul>

</div>
</div>

<p class="muted">Malicious version: 3CX. Non-malicious version: every one of us, under time pressure, on a Thursday afternoon. The install succeeds either way.</p>

<!--
"Sixth one, and then we move on. **Secret leakage and artifact drift.**

Secret leakage — Aqua Nautilus, same 2023 research. They found PSGallery publishers who had accidentally shipped `.git/config` with GitHub tokens. They found publishing scripts containing PSGallery API keys in *unlisted* packages — packages the authors thought they had hidden — still accessible via the PSGallery API after the authors thought they had removed them. Because unlisting changes search visibility, not API reachability. PSGallery has improved this since; they responded. But the existence of the keys in the first place was a publisher-side failure, not a registry-side failure. We shipped the secrets. The registry just made them reachable longer than we wanted.

Artifact drift — and I want to be precise about how this actually works, because it's easy to get wrong.

`choco install` doesn't read `VERIFICATION.txt`. It only enforces checksums that are embedded directly in the install script via `-Checksum` and `-ChecksumType` parameters. `VERIFICATION.txt` is documentation — for human reviewers, for CCR moderators, for anyone auditing the package manually. It has no effect at install time.

So the drift scenario is: vendor rotates the CDN, maintainer updates the URL in `chocolateyInstall.ps1`, forgets to update the `-Checksum` parameter. Or the install script never had one in the first place. `choco install` fetches whatever the new URL serves and runs it. No error. No warning. The install succeeds. [laugh beat, grim]

The malicious version of that is 3CX — the URL still looks right, the vendor is still the vendor, but the binary is already backdoored. The non-malicious version is every one of us on a Thursday afternoon. The install succeeds either way. The defense is the same in both cases: your pipeline pins the hash at build time and fails if it changes."
-->

---


## What the registries already do

<div class="columns">
<div>

### Chocolatey Community Repository

<ul class="primary-list">
<li>Validator — nuspec, script structure, metadata rules</li>
<li>Verifier — install / uninstall, dependency, and silent-install checks in a reference VM</li>
<li>Package Scanner / VirusTotal</li>
<li>Human moderation for non-trusted packages</li>
</ul>

</div>
<div>

### PowerShell Gallery

<ul class="secondary-list">
<li>Manifest validation — version, GUID, author, description</li>
<li>Installation testing during validation</li>
<li>Antivirus scanning</li>
<li>PSScriptAnalyzer at error level on every upload</li>
</ul>

</div>
</div>

<p class="muted">This is real infrastructure, much of it volunteer time. The rest of this talk is the layer <em>before</em> it — not instead of it.</p>

<!--
"Before we pivot to tooling, I want to spend a slide on what the registries are already doing, because I think the shared narrative in our industry has been unfair to them.

The Chocolatey Community Repository runs a Validator for nuspec, script structure, and metadata rules. It runs a Verifier that actually performs install, uninstall, dependency checks, and silent-install verification in a reference VM — which is not free to operate. It runs Package Scanner through VirusTotal. It has a human moderation pass for non-trusted packages.

And I want to be explicit about something that's easy to gloss over: **most of that is volunteer time.** The people who moderate packages on CCR are doing it on top of day jobs, evenings, weekends. When you submit a package to CCR and a human reviews it, that's a person who chose to spend their Saturday on your package. I want to say plainly that I have enormous respect for what the CCR moderation team has built and continues to maintain. The same is true for the PowerShell Gallery team — every PSScriptAnalyzer run, every AV scan, every validation check is infrastructure someone wrote and someone keeps running. It doesn't happen for free. It happens because people in this community care enough to make it happen.

PowerShell Gallery runs manifest validation, installation testing during validation, antivirus scanning, and PSScriptAnalyzer at error level on every upload. That's a non-trivial amount of automated scrutiny on every module that lands.

This is real infrastructure. I am not recommending you skip it. I am not recommending the pipeline we're about to build replaces it. What I *am* recommending is that by the time your package arrives at one of these registries, you can hand the moderator three things they don't currently receive: an SBOM, scan results, and a provenance document. Not to make their jobs harder — to make their jobs faster. Because the registries can't generate those retroactively — the source of truth is in the publisher's pipeline, and the publisher is *us*. [laugh beat: point at room] The receipts are ours to produce. That's the premise of the rest of the talk."
-->

---


## The three questions

**<span class="gradient-text">Three questions</span> a maintainer should answer before publishing:**

<ul class="primary-list">
<li>What's in this package? → <span class="primary-bg">SBOM</span></li>
<li>What did you check? → <span class="secondary-bg">scan results (SARIF)</span></li>
<li>Can you prove when and how it was built? → <span class="quaternary-bg">provenance</span></li>
</ul>

<div class="callout gradient">

### The answers are different for each question — and different for each ecosystem. We'll be honest about which are solved.

</div>

<!--
"Three questions a maintainer should be able to answer before publishing.

What's in this package? SBOM. What did you check? Scan results in SARIF. Can you prove when and how it was built? Provenance.

I want to be honest up front: the answers I can give today are different for each question, and different for each ecosystem. The SBOM story works better for Chocolatey packages with embedded binaries than for pure PowerShell modules. The provenance story — I can produce a receipt; nobody's reading it at install time yet. I'm going to come back to that honest accounting at the end of the talk. This is the part where we earn the right to make those admissions."

---

## Act II — Building the Receipts
-->

---


<!-- _class: big-statement -->

# Act II

## Building the Receipts

---


## The flawed module

`examples/powershell-module/ExampleModule/`

| File | What's wrong |
|------|--------------|
| `ExampleModule.psd1` | Floating dependency, `ScriptsToProcess` |
| `Invoke-UnsafeFunction.ps1` | Hardcoded key, TLS bypass, download-and-execute |
| `ExampleModule.Tests.ps1` | Passes. Every supply-chain issue is invisible to Pester. |

<p class="muted">Not cartoonishly broken. This is the shape of what ships when you're the solo maintainer on a Friday and the release has to go out today.</p>

<!--
*Switch to the repo browser. Open `examples/powershell-module/ExampleModule/`.*

"PowerShell side first. This is the flawed module in the repo. Read it for what it is: not cartoonishly broken. This is the shape of the thing that ships when you're the solo maintainer, it's Friday, your toddler has an ear infection, and the release has to go out today. [laugh beat]

Floating dependency in the `.psd1`. `ScriptsToProcess` — same mechanism Aqua used in their typosquat PoC. An exported function with four labeled flaws. Pester passes. PSGallery would publish it. Everything that's wrong with this module is invisible to the tools in your CI right now. That's what to hold in your head."
-->

---


## The multi-statement pattern

```powershell
$ApiKey = "sk-live-abc123..."                              # (1) hardcoded credential
[ServicePointManager]::ServerCertificateValidationCallback = {$true}  # (2) TLS bypass
$X = Invoke-WebRequest -Uri $url -Headers @{ Authorization = $ApiKey }  # (3) network call
Invoke-Expression $X                                        # (4) execute remote content
```

<div class="columns">
<div>

### PSScriptAnalyzer (linter)
Flags line 4. One finding, one line. Doing its job.

</div>
<div>

### Semgrep (security scanner)
Flags 1–4 as a single multi-statement chain: credential → TLS bypass → network → exec.

</div>
</div>

<p class="muted">For the author-hygiene layer below this one — PSScriptAnalyzer extensions, InjectionHunter, SecretManagement — see Rob Pleau's Summit 2025 session, "Stop Writing Insecure PowerShell."</p>

<!--
"This is the pattern I want you to remember from the PowerShell side. Four lines.

PSScriptAnalyzer — which PSGallery already runs at publish time, and which is an excellent piece of software written by people who understand PowerShell more deeply than I do — will flag line four. `Invoke-Expression` is a code-quality warning. One finding, one line.

What PSScriptAnalyzer is *not* doing — and isn't designed to do, because it's a linter — is reading these four lines as a sequence. It's not saying 'the thing being evaluated just arrived from the network.' It's not saying 'the credential feeding the network request is hardcoded two lines up.' It's not connecting 'TLS validation was disabled earlier in the function' to 'a subsequent HTTPS request is about to run with no certificate checks.'

Semgrep's job is to see this as one pattern. Multi-statement. Variable-binding. Cross-line. That's the difference. Not 'Semgrep is better than PSScriptAnalyzer.' They do different jobs. Linter versus security scanner. Run both.

If you want the author-hygiene version of this whole conversation in depth — PSScriptAnalyzer extensions, InjectionHunter, custom AST rules for PII, SecretManagement and SecretStore for credentials at rest — Rob Pleau's Summit 2025 session, 'Stop Writing Insecure PowerShell,' is the layer below this one. Watch it if you haven't. This talk assumes that layer of hygiene is already the baseline; what we're doing here is what shows up when you go to publish."
-->

---


## A Semgrep rule, unabridged

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

<p class="muted"><code>$X</code> is a metavariable — binds an identifier across lines, matches assignment-then-exec even with statements between. Twelve rules for PowerShell, twelve for Chocolatey, in <code>semgrep-rules/</code>. Authoring cost: one afternoon.</p>

<!--
"This is what a Semgrep rule looks like. YAML. No plugin. No DSL. No IDE dependency. The `$X` is a metavariable — binds an identifier across lines, which is how the pattern matches assignment-then-exec even with other statements between them.

The rules live in `semgrep-rules/` in the repo. Twelve for PowerShell, twelve for Chocolatey. Authoring cost is low enough that if your team has patterns specific to your environment — and you do, I promise you do — you can add rules for them in an afternoon. Fork the repo, extend the YAML, send a PR if you want them upstream. I will merge it. That is a promise. [laugh beat]"
-->

---


## SARIF in the PR

<!--
LIVE DEMO BEAT (Slide 17). Switch to browser with PR showing inline SARIF annotations.
Optional live push: edit Invoke-UnsafeFunction.ps1, commit, push, narrate while pipeline runs.
Fallback: stay on pre-populated PR. Don't narrate the switch.
-->

<ul class="primary-list">
<li>Annotations inline in the diff</li>
<li>Aggregated in the Security tab, filterable by tool and severity</li>
<li>One <code>github/codeql-action/upload-sarif</code> step per scanning job</li>
<li>Dollar cost: zero</li>
</ul>

<div class="callout secondary">

### If you take one thing from this talk and ship it next week — this is the thing.
Visibility in the PR, no new dashboard to train your team on.

</div>

<!--
*[LIVE DEMO BEAT] Switch to a live browser tab. Show a PR with inline SARIF annotations.*

"This is the output from the reviewer's side. Annotations inline in the diff. Aggregated in the Security tab. Filterable by tool and severity.

The dollar cost of this is zero. The setup is one `github/codeql-action/upload-sarif` step at the end of each scanning job. If you took one thing from this talk and put it in your pipeline next week, this is the thing — visibility in the PR, no new dashboard to train your team on. Because we all know how training your team on a new dashboard goes. [laugh beat]"

*[Optional live beat: edit `Invoke-UnsafeFunction.ps1` on stage to introduce a slightly-changed flaw, commit, push, narrate for 60–90 seconds while the pipeline runs, show the annotation landing. Fallback: stay on the pre-populated PR, don't apologize for the switch — "here's one I prepared earlier" is fine.]*
-->

---


## SBOM — and the gap inside it

- Syft scans the module directory
- Output: **CycloneDX JSON** — components, PURLs, resolved versions, file hashes
- Useful as an audit trail today, incident-response input tomorrow

<div class="callout secondary">

### The lockfile gap
The SBOM records what *I shipped*. It does not record what resolves on *your* machine at `Install-Module` time. PowerShell has no lockfile — not missing about-to-ship, a genuinely unsolved ecosystem problem. Current workaround: pin `RequiredVersion` and enforce with `dependency-pin-check`. Maintainer-side commitment, not a consumer-side guarantee.

</div>

<!--
"SBOM next. CycloneDX JSON, generated by Syft against the module directory. Components array. PURLs. Resolved versions. File hashes. Useful as an audit trail.

Syft is the inventory pass. It walks the directory, figures out what packages and files are there, and emits a machine-readable bill of materials. In plain English: it tells you what is in the box. It does not tell you whether the box is safe. That distinction matters.

Now the honest part. This SBOM records what I shipped. It does *not* record what resolves on the consumer's machine when they `Install-Module` this thing. PowerShell has no lockfile. `Install-Module` resolves `RequiredModules` at install time against whatever is currently the highest-satisfying version in PSGallery. I ship Monday. You install Tuesday. Your dependency graph might differ from mine. My SBOM tells you what I built. It doesn't tell you what ran on your machine.

That is the single biggest unsolved problem in PowerShell supply chain security today. The current workaround is to pin `RequiredVersion` — exact version — instead of `ModuleVersion`, and enforce with `dependency-pin-check`. Maintainer-side commitment, not a consumer-side guarantee. One practical thing to say out loud: the SBOM becomes really valuable when something goes wrong later. If a CVE drops, or incident response needs to know which releases were exposed, the SBOM gives you a fast answer without rebuilding the world or re-scanning every source repo from scratch."

The other way to say it is that the SBOM is your inventory control sheet. It answers 'what did I put in the package?' and gives incident responders something they can query later without re-running the whole build just to answer a basic question."
-->

---


## Vulnerability scan — and the retroactive payoff

- Grype reads the SBOM, checks NVD + GitHub Advisory Database
- Findings go back to Code Scanning as SARIF
- SBOM retained as an artifact (365 days by default)

<div class="callout primary">

### Re-runnable
When a CVE drops six months from now, you re-run Grype against the stored SBOM and know in seconds which builds are affected. That's incident response, not prevention. Both matter — and the incident-response case is what actually gets this pipeline funded.

</div>

<!--
"Grype is the second half of the pair. Syft inventories what is there; Grype looks at that inventory and asks whether any of the components have known vulnerabilities. It reads the SBOM, matches packages and versions against vulnerability data, and reports the results back into Code Scanning.

That split is worth calling out because it keeps the steps honest. Inventory is still inventory, and vulnerability scanning is still vulnerability scanning. When people collapse both into one vague 'scan' word, they lose the point of each tool.

Build-time value is obvious. The less-obvious value is retroactive. The SBOM is retained as an artifact for a year by default. When a CVE drops six months from now against a dependency you shipped, you re-run Grype against the stored SBOM from that release and you know in seconds which builds were affected. That's incident response, not prevention. Both matter — and in my experience the incident-response case is what gets this pipeline funded in an enterprise, not the build-time gating."

That retroactive angle is the thing people underestimate. You are not just scanning today; you're creating a record you can come back to when the next advisory lands and somebody asks, 'which releases are we on the hook for?'"
-->

---


## Provenance — and the consumer who isn't there

```json
{
  "source_repo": "adilio/publish-with-receipts",
  "commit_sha":  "abc123...",
  "workflow":    "powershell-supply-chain.yml",
  "build_time":  "2026-04-13T14:30:00Z",
  "artifact_hash": "sha256:def456..."
}
```

<p class="muted"><code>Install-Module</code> doesn't check this. <code>choco install</code> doesn't check this. No install-time verifier ships in the ecosystem today.</p>

<div class="callout secondary">

### Maintainer-side audit value today. Back catalog ready for the day a verifier ships. That's the bet.

</div>

<!--
"Provenance. Here's the receipt. And I want to spend a few minutes on what this actually means — not just the JSON — because it's the piece of this talk that tends to land as vague unless I explain the model carefully.

**What is provenance, concretely?**

Provenance is the documented, verifiable answer to: where did this artifact come from, and can you prove it? Think of it like chain of custody in a legal context. A police department doesn't just say 'we have this evidence.' They have a log: who collected it, when, under what circumstances, who transferred it, who had it at each step. If the chain breaks — if there's an unexplained gap — the evidence is tainted. Provenance for software artifacts is the same idea: source repo, source commit, workflow name, build time, the hash of the artifact that came out the other end.

**Where does SLSA fit in?**

SLSA — Supply-chain Levels for Software Artifacts, pronounced 'salsa' — is a framework from Google that defines a graduated set of requirements for supply chain integrity. Think of it like a rating system. Level 0 is no guarantees at all. Level 1 means the build process is documented and provenance is generated. Level 2 means the provenance is produced by a hosted build system — like GitHub Actions — and is *signed* by that system so you can prove it wasn't generated by the developer on their laptop after the fact and uploaded manually. Level 3 adds requirements about the build environment itself: hardened runners, no persistent credentials, build instructions defined in reusable workflows outside the repository so they get organizational vetting before they run.

What we're producing with `actions/attest-build-provenance` is SLSA v1.0 Build Level 2 by default. That's meaningful. It means the provenance document was produced and signed by GitHub's hosted runner infrastructure, not by you. The attestation is evidence that a specific CI system produced a specific artifact — not a claim you're making about yourself.

**The Sigstore mechanism — how the signing actually works**

This is the part that's worth understanding at least once, because it's not obvious.

When the attestation step runs, here's what happens under the hood:

1. The GitHub Actions job has an OIDC token — a short-lived, job-scoped identity token that proves 'this is workflow run X on repo Y at time Z.'
2. That token is used to request a short-lived X.509 signing certificate from Fulcio — Sigstore's certificate authority. The certificate is issued to the workflow identity, not a person.
3. A keypair is generated. The private key is used to sign the provenance statement — which is formatted as an in-toto attestation, a standard format for supply-chain metadata. The statement is also counter-signed by a Timestamp Authority, so the signing time is provably recorded.
4. Then — and this is the important part — **the private key is destroyed.** It cannot be recovered. It existed only long enough to sign this one statement.
5. The Sigstore bundle (signed statement + certificate chain) is stored in GitHub's attestation store. For public repos, it's also written to the Sigstore Public Good Instance — a public, append-only transparency log.

Why does the key destruction matter? Because it means the provenance cannot be forged or backdated later, even if someone with full repo admin access wanted to. The signing event was a one-time, ephemeral operation tied to that specific CI run. You can't sign something 'as' a past build.

A consumer runs `gh attestation verify <artifact> -R owner/repo` and gets back confirmation that this exact file — matched by SHA-256 hash — was produced by the named workflow on that repo. If the hash doesn't match the artifact's current state, verification fails. That's the guarantee.

**A caveat that matters for our ecosystem: the registry modification problem**

Andrew Lock wrote about this in detail for NuGet packages, and I want to flag it because the same question applies here.

When NuGet.org accepts a package upload, it *modifies* the package — it adds a `.signature.p7s` file before serving it to consumers. That changes the SHA-256 hash of the package. Which means the GitHub attestation you generated before upload — which was computed against the original file hash — no longer matches what a consumer downloads. The verification breaks. The artifact the consumer has is not the artifact the attestation was signed against.

The workaround for NuGet is to strip the `.signature.p7s` before verifying. But the larger point is: **does PSGallery or CCR modify packages after upload?** I don't have a definitive answer for both registries right now. It's a question worth asking the teams directly — and if you're in the room and you know, I'd genuinely like to know. Because if the registry transforms the artifact in any way between publisher upload and consumer download, the chain of custody has a gap in it, and the attestation story gets more complicated.

**What this doesn't do**

I want to be honest. This JSON on screen is not magic. It doesn't make your package more secure at install time, because nothing in the current PSGallery or CCR install flow reads it. `Install-Module` doesn't check it. `choco install` doesn't check it. No install-time verifier ships in the ecosystem today.

I produce the provenance. The consumer never asks to see it.

That's a real gap, and I'm not going to dress it up. What I can say is the provenance is immediately useful to the *maintainer*. If a customer asks 'can you prove the version you shipped on this date came from this commit and was built by this pipeline' — I can answer. Not with a handwave. With a cryptographically signed document that a verifier can check. If an incident happens and I need to establish definitively which build produced which artifact — I can.

**The bet**

The full loop closes when the registries require signed provenance at upload and the install clients verify at install time. Both are ecosystem-scale asks — they require registry policy changes, client changes, and backward-compatibility work. The PSResourceGet team's direction with MAR and OCI is pointing toward this. It's not shipped everywhere yet.

What I can do in the meantime is produce the receipts now, so that when a verifier eventually ships, my back catalog is already signed and readable. The cost of doing it today is minimal. The cost of retroactively generating provenance for releases you already shipped is that you can't — the original build environment and its OIDC token are long gone. Sign it at the moment of build, or accept that you'll never be able to."

This is the part that sounds abstract until you have an incident and everyone wants to know whether the thing in prod came from the commit you think it did. Provenance is how you answer that without a forensic scramble."
-->

---


## PowerShell pipeline — actual run

```
Push / PR
    ↓
PSScriptAnalyzer  →  SARIF  →  PR annotations
    ↓
Semgrep           →  SARIF  →  PR annotations
    ↓
Syft              →  CycloneDX SBOM  →  artifact
    ↓
Grype             →  SARIF + JSON  →  PR annotations
    ↓
Provenance        →  JSON  →  artifact (365-day retention)
```

<p class="muted">~3.5 min cold runner. Under 2 min once Grype's DB is cached. Non-blocking by default. Eight composite actions — adopt any one without the others.</p>

<!--
"Full pipeline, end to end. Three and a half minutes cold. Under two minutes once Grype's database is cached. Non-blocking by default. Every step is a composite action you can pull independently. You don't have to buy the whole pipeline."
-->

---


## Chocolatey changes the threat model

| Dimension | PowerShell module | Chocolatey package |
|-----------|-------------------|--------------------|
| Execution context | User | **Admin** |
| Package content | Your code | **Wrapper around an external binary** |
| Moderation reach | PSGallery AV + PSScriptAnalyzer | **CCR for community, none for internal** |

<p class="muted">Everything from Act II still applies. The Chocolatey pipeline adds three checks the PowerShell pipeline doesn't need.</p>

<!--
"Switching to Chocolatey. Everything we just built applies. On top of that, Chocolatey tightens the threat model in three ways.

Install scripts run as admin. The package is typically a three-kilobyte wrapper around a fifty-megabyte external binary, which means the package's security is mostly the security of an external download. And moderation doesn't reach internal repositories, which is where a lot of Chocolatey is actually deployed — and where, again, the CCR volunteers can't help you, even if they wanted to.

That combination is why the Chocolatey pipeline adds three checks the PowerShell pipeline doesn't need."
-->

---


## The flawed Chocolatey package

`examples/chocolatey-package/`

| File | What's wrong |
|------|--------------|
| `example-package.nuspec` | Missing metadata, dependency versioning risk |
| `tools/chocolateyInstall.ps1` | No checksum, PATH change with no uninstall cleanup, internal URL |
| `tools/VERIFICATION.txt` | No checksums, vague source URL |

<p class="muted">This is not contrived. This is the shape of something I have personally helped review in two enterprises. Both times the author was senior. Both times the package had been in production for months.</p>

<!--
"This is the package from the cold open. Nuspec with missing metadata and dependency versioning risk. Install script with the three flaws we already looked at. `VERIFICATION.txt` with no checksums.

Not a contrived example. This is the shape of something I have personally helped review in two different enterprises. [laugh beat, rueful] Both times the author was extremely senior. Both times the package had been in production for months. Neither time was the author trying to do anything wrong. They were trying to ship the thing."
-->

---


## Step 1 — Pre-publish validation

- Queries the CCR API, runs a Levenshtein similarity check against existing package names
- Checks nuspec metadata completeness (`projectUrl`, `iconUrl`, tags, description)
- Flags naming-conflict risk and surfaces potential typosquat neighbors for review

<p class="muted">Cheap, narrow, non-heroic. Won't stop a determined attacker who has already published — catches accidental collisions before you publish. Cheapest check in the pipeline.</p>

<!--
"First Chocolatey-specific check: pre-publish validation. Queries the CCR API, runs a Levenshtein similarity check against existing package names, and checks nuspec metadata completeness — `projectUrl`, `iconUrl`, tags, description.

Cheap to run. Narrow in what it catches — won't stop a determined attacker who has already published, but it catches accidental name collisions before *you* publish, and surfaces potential typosquat neighbors for reviewers.

I want to be precise about what this is: this is *our* pipeline doing these checks. This is not a CCR moderation phase. CCR has its own validator rules. We're front-running some of them so the feedback lands in your PR instead of in a moderation queue.

Levenshtein itself is just edit distance — how many inserts, deletes, or substitutions it takes to turn one string into another. That's what makes it useful here: it catches lookalike names that humans routinely miss when they're typing package names by hand. It won't stop a determined attacker, and it won't prove intent, but it does catch the typo-shaped mistakes that turn into embarrassing publishes.

Not going to spend long on this. Cheapest check in the pipeline. Moving on."
-->

---


## Step 2 — Checksums &amp; VERIFICATION.txt drift

```powershell
Install-ChocolateyPackage `
  -Url "https://example.com/setup.exe" `
  -Checksum "abc123..."         # present? matches?
  -ChecksumType "sha256"        # prefer SHA256 or better
```

<ul class="secondary-list">
<li>Every external download has a <code>-Checksum</code> in the install script — this is what the runtime enforces</li>
<li>Algorithm is SHA256 or better (MD5 / SHA1 flagged)</li>
<li><code>VERIFICATION.txt</code> is documentation — our pipeline verifies its hashes match what the install script will actually fetch</li>
</ul>

<p class="muted"><code>choco install</code> doesn't read <code>VERIFICATION.txt</code>. It reads <code>-Checksum</code> in <code>Install-ChocolateyPackage</code>. Missing or stale checksum = silent success. Our pipeline catches this at build time.</p>

<!--
"Three checks. Every external download has a checksum in the install script — that's what the Chocolatey runtime actually enforces. The algorithm is SHA256 or better. And our pipeline verifies that the hashes in `VERIFICATION.txt` match what the install script will actually fetch.

Two things worth being precise about. First: `choco install` does not read `VERIFICATION.txt`. It only enforces checksums specified directly in `Install-ChocolateyPackage` via `-Checksum` and `-ChecksumType`. `VERIFICATION.txt` is documentation — for human reviewers and CCR moderators. If the `-Checksum` parameter is missing or stale, the install succeeds regardless of what `VERIFICATION.txt` says.

Second: CCR's validator checks that a `VERIFICATION.txt` file exists for embedded binaries — that's CPMR0006. Whether the automated tooling also checks that the hashes inside match the binaries, I genuinely don't know — and if there's a CCR person in the room, I'd love to hear it. Either way, doing this check in your own pipeline means you catch drift before the package ever reaches moderation.

The drift scenario: vendor rotates the CDN, maintainer updates the URL, forgets to update `-Checksum`. `choco install` fetches whatever the new URL serves and runs it. No error. No warning. The install succeeds. The malicious version of that is 3CX. The non-malicious version is every one of us on a Thursday afternoon. The install succeeds either way."
-->

---


## Step 3 — Install-script analysis

`semgrep-rules/chocolatey-install-patterns.yml`

<ul class="quaternary-list">
<li><code>choco-unverified-download</code> — raw <code>Invoke-WebRequest</code> outside Chocolatey helpers, bypassing built-in checksum enforcement</li>
<li><code>choco-registry-write-undocumented</code> — HKLM writes / service creation without a doc comment</li>
<li><code>choco-hardcoded-internal-url</code> — internal URLs / UNC paths leak topology</li>
<li><code>choco-path-modification-undocumented</code> — PATH change without uninstall cleanup</li>
</ul>

<p class="muted">Every script here runs as admin. The bar for "document your intent" should reflect that.</p>

<!--
"Four rule categories. Raw `Invoke-WebRequest` outside Chocolatey's helpers — bypasses Chocolatey's built-in checksum enforcement, which exists and is good, and if you're writing around it you should probably stop. [laugh beat] Registry writes and service creation without a documentation comment — in a script that runs as admin, the reviewer needs to know why. Hardcoded internal URLs — leaks your internal topology if the package ever leaves the internal repo. PATH modification without matching uninstall cleanup — that one gets its own slide."
-->

---


## The PATH story

```
chocolateyInstall.ps1      →  appends C:\tools\myapp to machine PATH
chocolateyUninstall.ps1    →  no cleanup
6 months later             →  uninstall removes the package, PATH stays
non-admin writable dir?    →  attacker drops git.exe / python.exe / node.exe
next user types "git"      →  planted binary runs (LPE precondition)
```

<p class="muted">The Semgrep rule doesn't know whether the directory is writable. It knows the uninstall cleanup is missing. In a script that runs as admin, that's enough to make it reviewable — and it's the finding I most often see get fixed quietly with no fuss.</p>

<!--
"Install script appends `C:\tools\myapp` to the machine PATH. Uninstall script doesn't remove it. Six months later, someone uninstalls the package — the PATH entry stays.

If that directory's ACLs ever let non-admins write to it — depending on the installer that created it, that happens more than you'd like — anyone with a local shell can drop a `git.exe`, a `python.exe`, a `node.exe` there. Windows PATH resolution finds them before the real ones. The next person who types `git` on that machine runs whatever got dropped.

Documented LPE precondition. Misconfigured PATH entry from a forgotten Chocolatey package is a common way it gets set up. The Semgrep rule doesn't know whether the directory is writable. It knows the cleanup is missing. In a context where the script runs as admin, that's enough to make it reviewable — and it's the finding I most often see get fixed quietly with no fuss, because the author immediately recognizes the shape of the problem."
-->

---


## Chocolatey pipeline — actual run

```
Push / PR
    ↓
Pre-publish validation  →  JSON   →  PR annotations
    ↓
Checksum + VERIFICATION.txt drift check  →  SARIF
    ↓
Semgrep (Chocolatey ruleset)  →  SARIF  →  PR annotations
    ↓
Syft (incl. embedded binaries)  →  CycloneDX SBOM  →  artifact
    ↓
Grype  →  SARIF + JSON
    ↓
Provenance  →  JSON  →  artifact
```

<p class="muted">Same five output artifacts as the PowerShell pipeline. Ecosystem-specific checks. Same shape.</p>

<!--
"Chocolatey pipeline. Same five output artifacts as the PowerShell pipeline — two SARIF reports, an SBOM, Grype results, provenance. Ecosystem-specific checks. Same shape."

---

## Act III — What's Still Missing, and Monday
-->

---


<!-- _class: big-statement -->

# Act III

## What's Still Missing, and Monday

---


## Three unsolved problems

<ol class="primary-list">
<li><strong>The lockfile gap.</strong> Chocolatey nuspec can be pinned and the pipeline enforces it. PowerShell can't — <code>RequiredVersion</code> is a maintainer commitment, not a consumer guarantee. Real fix is a PowerShell lockfile — a platform-level change.</li>
<li><strong>Consumers aren't reading receipts.</strong> No install-time verifier ships today. Gap closes when registries require signed provenance at upload <em>and</em> clients verify at install. Direction: MAR + PSResourceGet over OCI — Michael Green &amp; Sydney Smith, Summit 2025. Not yet shipped ecosystem-wide.</li>
<li><strong>Internal repositories.</strong> CCR has moderators. Your internal feed doesn't. This pipeline isn't a complement — it <em>is</em> the moderation. Don't be polite with your own infrastructure.</li>
</ol>

<!--
"Now the honest accounting. Three things this pipeline does not solve.

**One, the lockfile gap.** Covered it. The Chocolatey version is slightly better — `.nuspec` dependencies can be pinned to exact versions, and `dependency-pin-check` in our pipeline enforces it. The PowerShell version is worse, and no composite action I write is going to fix it. Real fix is a PowerShell lockfile — a platform-level change. If that's something you work on or can advocate for, this is me advocating for it.

**Two, consumers aren't reading receipts.** `Install-Module` and `choco install` don't verify provenance. Production of receipts runs ahead of verification. Gap closes when the registries require signed provenance at upload and the clients verify at install. Both are ecosystem-level decisions — and CCR and PSGallery are in the room, and they know it, and the answer to 'why haven't you shipped this yet' is always 'backward compatibility, resource constraints, and a careful rollout plan.' Which, when I was sysadmin-side of this conversation, I had opinions about. Now that I've been on the other side of ship-versus-don't-break-everyone decisions, I have more patience with the answer. [laugh beat]

The PSResourceGet team has been showing direction — Michael Green and Sydney Smith at Summit last year walked through MAR, PSResourceGet over OCI, GPO allowlisting through Intune and Azure Policy. That's the closed-loop version of what we're producing receipts for: the client knows which registries to trust, and the registry publishes signed artifacts with identity-level guarantees. Not shipped everywhere — discovery across vendor registries, dependency resolution across MAR and PSGallery, and caching from the NuGet-v2 gallery into an OCI registry are all still open questions they're actively soliciting feedback on. The worthwhile thing I can do in the meantime is produce the receipts now, so the day a verifier ships, my back catalog is ready to be read.

**Three, internal repositories.** CCR has moderators. Your internal Chocolatey repo typically doesn't. In that context, this pipeline is not a *complement* to moderation — it *is* the moderation. That changes how seriously you take enforcement. On a community package I'd say 'start non-blocking, tune, enforce when ready.' On an internal package shipped to thousands of endpoints with no human review — start blocking on critical checks immediately. Don't be polite with your own infrastructure."
-->

---


## Monday-morning adoption path

<div class="checklist">

1. **One afternoon.** PSScriptAnalyzer with SARIF upload + Semgrep with one rule file, non-blocking. Expect false positives. Do not open seventy-four Jira tickets on day one.
2. **One afternoon, later that week.** SBOM + provenance generation. Both single-composite-action adoptions. Neither blocks anything — they produce artifacts.
3. **Ongoing.** Tune rules, add inline suppressions with justifications, decide which findings block a merge.

</div>

<p class="muted">What <em>not</em> to do: don't turn on enforcement before you've seen the baseline. That's how security gates get disabled quietly three months later. Visibility first. Enforcement after you've earned it.</p>

<!--
"Three steps for next week.

One, one afternoon: PSScriptAnalyzer with SARIF upload and Semgrep with one rule file, non-blocking. You'll see what fires. You will get false positives. Expect them. Do not open seventy-four Jira tickets on day one. [laugh beat]

Two, one afternoon, later the same week or next: SBOM and provenance generation. Both single-composite-action adoptions. Neither blocks anything — they produce artifacts.

Three, ongoing: tune rules, add suppressions with justifications, decide which findings block a merge.

What *not* to do on day one: don't turn on enforcement before you've seen the baseline. That is how security gates get disabled quietly three months later when the team gets tired of them. Visibility first. Enforcement after you've earned it."
-->

---


## The repo

`github.com/adilio/publish-with-receipts`

<ul class="primary-list">
<li><code>examples/</code> — flawed module + flawed package. Fork and run the pipeline.</li>
<li><code>actions/</code> — eight composite actions. Adopt one at a time.</li>
<li><code>semgrep-rules/</code> — PowerShell + Chocolatey rulesets. Extend for your patterns.</li>
<li><code>docs/</code> — threat model, tooling decisions, enterprise integration, remediation guide per finding.</li>
</ul>

<div class="callout gradient">

### Receipts are useful even when nobody reads them — until the day someone does.

</div>

<!--
"Repo is on screen. `examples/` has the flawed module and the flawed package. `actions/` has eight composite actions you can adopt individually. `semgrep-rules/` has the YAML rules. `docs/` has the threat model, tooling decisions, enterprise integration, and a remediation guide for every finding type the pipeline surfaces.

You don't need to have been in this room to use the repo. The decisions are written down — so when your VP of Engineering asks 'wait, why are we doing this?' six months from now, you have something to point at that isn't a hand-wave. [laugh beat]

That's the talk. Receipts are useful even when nobody reads them — until the day someone does. I'll take questions."
-->

---


<!-- _class: title -->

# Questions?

<p class="name wide">Adil Leghari</p>
<p class="handle wide">github.com/adilio/publish-with-receipts</p>

![QR code for github.com/adilio/publish-with-receipts w:200 h:200](https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=https://github.com/adilio/publish-with-receipts)

<!--
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
-->
