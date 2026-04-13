# Chocolatey Moderation Review

Reviewed sources:

- https://docs.chocolatey.org/en-us/community-repository/moderation/
- https://docs.chocolatey.org/en-us/community-repository/moderation/package-validator/rules/
- https://docs.chocolatey.org/en-us/community-repository/moderation/package-validator/
- https://docs.chocolatey.org/en-us/community-repository/moderation/package-verifier/

Additional primary sources used in the follow-up validation:

- https://docs.chocolatey.org/en-us/community-repository/moderation/package-validator/rules/cpmr0006/
- https://docs.chocolatey.org/en-us/community-repository/moderation/package-validator/rules/cpmr0073/
- https://docs.chocolatey.org/en-us/create/functions/get-checksumvalid/
- https://docs.chocolatey.org/en-us/information/security/
- https://docs.chocolatey.org/en-us/choco/release-notes/
- https://docs.chocolatey.org/en-us/configuration/
- https://docs.chocolatey.org/en-us/guides/organizations/organizational-deployment-guide/
- https://docs.chocolatey.org/en-us/features/host-packages/

## Assessment status

I re-checked the main claims independently against Chocolatey's official docs and related primary materials. The confidence labels below mean:

- `Confirmed`: directly supported by the cited docs
- `Inference`: not stated in exactly these words, but strongly supported by the cited docs
- `Uncertain`: plausible, but I did not find strong enough primary support to state it confidently

## High-confidence conclusions

- `Confirmed`: CCR moderation is meaningful and consists of multiple automated checks plus human review for non-trusted packages.
- `Confirmed`: CCR does not provide SBOMs or provenance attestations.
- `Confirmed`: `VERIFICATION.txt` presence is enforced for embedded binaries.
- `Confirmed`: checksums are required by CCR moderation for remote downloads.
- `Confirmed`: Chocolatey runtime checksum behavior depends on protocol and configuration.
- `Inference`: internal feeds do not receive CCR-style moderation unless the organization builds or buys that process itself.

## Claim-by-claim review

1. `talk/presentation.md:85`

Current claim:

`Verifier: install, upgrade, uninstall`

Assessment: `Confirmed with nuance`

The verifier page defines the service as checking whether a package installs and uninstalls correctly, has correct dependencies, and can be installed silently. The same page's documented Vagrant flow also includes an `upgrade` step during testing. So my earlier advice to simply remove `upgrade` was too strict.

Safest slide wording:

- `Verifier: install/uninstall, dependency, and silent-install checks`

Also acceptable if you want to preserve the fuller story:

- `Verifier: install/uninstall checks, with upgrade exercised in the documented test flow`

Source:

- [Package Verifier](https://docs.chocolatey.org/en-us/community-repository/moderation/package-verifier/)

2. `talk/presentation.md:86`

Current claim:

`VirusTotal plus human review for community packages`

Assessment: `Confirmed with wording improvement`

Chocolatey's official security documentation says community packages go through automated validation, automated verification, VirusTotal, and human review for non-trusted packages. If you want terminology that sounds closer to their ecosystem language, `Package Scanner / VirusTotal` is slightly better than `VirusTotal` alone.

Recommended wording:

- `Package Scanner / VirusTotal plus human review for non-trusted community packages`

Sources:

- [Security](https://docs.chocolatey.org/en-us/information/security/)
- [Moderation](https://docs.chocolatey.org/en-us/community-repository/moderation/)

3. `talk/presentation.md:118`

Current claim:

`Monitors for URL or binary drift after approval`

Assessment: `Needs softening`

The verifier reruns existing packages every two weeks, so there is some post-approval checking. What the docs do not provide is provenance or a strong guarantee of binary identity over time. So the stronger version of your point is about lack of durable supply-chain evidence, not absence of any post-approval checking.

Recommended wording:

- `Does not provide provenance or continuous binary-identity guarantees after approval`

Source:

- [Package Verifier](https://docs.chocolatey.org/en-us/community-repository/moderation/package-verifier/)

4. `talk/presentation.md:128` and `talk/presentation.md:466`

Current claim:

`VERIFICATION.txt is convention, not enforcement`

Assessment: `Partly confirmed, but too absolute`

`CPMR0006` confirms the validator enforces the presence of a verification file when binaries are included. What I did not find is documentation showing that Chocolatey's automation parses that file and reconciles its contents against embedded binaries or install-script URLs.

So the most accurate framing is:

- presence is enforced programmatically
- content quality and reconciliation still appear to rely largely on human moderation

Recommended wording:

- `VERIFICATION.txt is required for embedded binaries, but its contents do not appear to be automatically reconciled against scripts or binaries`

Sources:

- [CPMR0006](https://docs.chocolatey.org/en-us/community-repository/moderation/package-validator/rules/cpmr0006/)
- [Moderation](https://docs.chocolatey.org/en-us/community-repository/moderation/)

5. `talk/presentation.md:479`

Current claim:

`Missing metadata, unpinned dependency`

Assessment: `Partly confirmed`

Missing metadata is aligned with validator-style moderation concerns. `Unpinned dependency` is a reasonable supply-chain critique, but I did not find primary support that CCR moderation flags minimum-version dependency expressions simply for being unpinned. The documented rule I found is for dependencies with no version.

Recommended wording:

- `Missing metadata, dependency versioning risk`

Source:

- [Validator Rules](https://docs.chocolatey.org/en-us/community-repository/moderation/package-validator/rules/)

6. `talk/presentation.md:481`

Current claim:

`VERIFICATION.txt`

Assessment: `Repo nit`

That file is actually located at `examples/chocolatey-package/tools/VERIFICATION.txt` in this repository. This is not a correctness problem for the talk, but it is worth being precise if you live-demo the example package.

7. `talk/presentation.md:483`

Current claim:

`The package installs. choco install succeeds. That's the problem.`

Assessment: `Needs scope clarification`

This is not universally true across Chocolatey:

- In CCR moderation, missing checksums on remote downloads are a documented failure condition.
- At runtime, HTTP/FTP downloads without checksums fail by default.
- HTTPS downloads may still succeed without checksums unless stricter settings are enabled.

So this line is strongest when framed as:

- a statement about your intentionally flawed demo package
- or a statement about default HTTPS runtime behavior outside CCR moderation

Recommended wording:

- `Outside CCR moderation, an HTTPS-backed package can still install without a checksum unless you tighten Chocolatey's config`

Sources:

- [CPMR0073](https://docs.chocolatey.org/en-us/community-repository/moderation/package-validator/rules/cpmr0073/)
- [Release Notes](https://docs.chocolatey.org/en-us/choco/release-notes/)
- [Configuration](https://docs.chocolatey.org/en-us/configuration/)

8. `talk/presentation.md:491-492`

Current claim:

`Step 1: Naming Validation`
`Checks metadata completeness (projectUrl, iconUrl, tags)`

Assessment: `Fine as your pipeline, not as Chocolatey's exact internal phase model`

Chocolatey's docs present these as validator rules, not as one built-in moderation phase called `Naming Validation` that also owns metadata completeness. If this slide is describing your own pre-publish pipeline, it is fine. If it is describing Chocolatey's architecture, it is too compressed.

Recommended wording:

- `Step 1: Pre-publish validation`
- `Checks naming conflict risk and metadata completeness`

Sources:

- [Package Validator](https://docs.chocolatey.org/en-us/community-repository/moderation/package-validator/)
- [Validator Rules](https://docs.chocolatey.org/en-us/community-repository/moderation/package-validator/rules/)

9. `talk/presentation.md:505`

Current claim:

`Checksums present and using strong algorithm (SHA256+)`

Assessment: `Checksums confirmed, algorithm enforcement uncertain`

The docs clearly support the checksum requirement. They also clearly recommend SHA256 or better. What I did not find is a validator rule stating that MD5 or SHA1 are outright rejected by automation. Chocolatey's helper docs still describe MD5, SHA1, SHA256, and SHA512 as supported values while warning that MD5 and SHA1 are no longer secure.

Recommended wording:

- `Checksums present for remote downloads`
- `Prefer SHA256 or better`

Sources:

- [CPMR0073](https://docs.chocolatey.org/en-us/community-repository/moderation/package-validator/rules/cpmr0073/)
- [Get-ChecksumValid](https://docs.chocolatey.org/en-us/create/functions/get-checksumvalid/)

10. `talk/presentation.md:506`

Current claim:

`VERIFICATION.txt entries match embedded files`

Assessment: `Good requirement for your pipeline, not confirmed as CCR automation`

I did not find primary support that CCR automation currently performs this reconciliation. That does not mean moderators do not check it; it means I would not attribute this to automated validator/verifier behavior without a stronger source.

Recommended wording:

- `Our pipeline cross-checks VERIFICATION.txt against embedded files`

Source:

- [CPMR0006](https://docs.chocolatey.org/en-us/community-repository/moderation/package-validator/rules/cpmr0006/)

11. `talk/presentation.md:467`

Current claim:

`Internal repos — typically zero moderation`

Assessment: `Inference, but strong`

The moderation, validator, and verifier docs are all scoped to the Community Repository. Chocolatey's organizational guidance tells customers to host packages internally and manage trust through internalization and internal processes. I did not find a doc that literally says `internal repos have zero moderation`, but the overall picture strongly supports your point that CCR moderation does not automatically carry over to internal feeds.

Recommended wording:

- `Internal feeds do not get CCR-style moderation unless you build or buy that process yourself`

Sources:

- [Moderation](https://docs.chocolatey.org/en-us/community-repository/moderation/)
- [Security](https://docs.chocolatey.org/en-us/information/security/)
- [Organizational Deployment Guide](https://docs.chocolatey.org/en-us/guides/organizations/organizational-deployment-guide/)
- [Host Packages Internally](https://docs.chocolatey.org/en-us/features/host-packages/)

## Recommended talk-track wording

- `CCR moderation is roughly: Validator, Verifier, Package Scanner / VirusTotal, then human review for non-trusted packages.`
- `VERIFICATION.txt is required for embedded binaries, but its contents do not appear to be automatically reconciled against scripts or binaries.`
- `CCR requires checksums for remote downloads, but Chocolatey runtime behavior outside CCR is looser: HTTP/FTP without checksums fails by default, while HTTPS may still install unless you require checksums.`
- `Internal feeds do not get CCR moderation automatically. Your moderation is whatever checks you run before packages hit that feed.`

## Bottom line

Your thesis is still strong after the extra research:

- CCR already does meaningful moderation.
- That moderation reduces risk, but it is not the same thing as supply-chain evidence.
- Your proposed pipeline still adds value because it creates artifacts CCR does not produce: SBOM, scan receipts, and provenance.

The most important deck fixes I would make now are:

- soften the verifier description to match the documented scope,
- replace the absolute `VERIFICATION.txt` line with the presence-vs-content nuance,
- clarify the runtime checksum behavior so HTTP/FTP and HTTPS are not conflated,
- weaken `SHA256+ required` to `prefer SHA256 or better`,
- and present your custom checks as your pipeline rather than as Chocolatey's exact internal service boundaries.

## Questions for the Chocolatey team

- Does CCR automation do anything with `VERIFICATION.txt` beyond checking that a verification file exists for embedded binaries?
- Does any automated moderation step reconcile `VERIFICATION.txt` contents against embedded binaries or install-script URLs, or is that entirely a human moderator task?
- Are MD5 and SHA1 ever auto-rejected during moderation today, even if the public validator rules do not explicitly say so?
- When the verifier reruns packages every two weeks, how much upstream drift detection does that realistically provide for changed binaries, URLs, or installer behavior?
- Should `upgrade` be described as part of the verifier's responsibility in a short architectural summary, or is it better treated as part of the documented test flow rather than the top-level service definition?
- For enterprise/internal feeds, are there Chocolatey-supported products or patterns that you would consider the closest equivalent to CCR-style moderation, so users do not hear `internal repos have no moderation` as more absolute than intended?
