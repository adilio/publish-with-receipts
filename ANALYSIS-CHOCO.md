# Chocolatey Moderation Review

Reviewed sources:

- https://docs.chocolatey.org/en-us/community-repository/moderation/
- https://docs.chocolatey.org/en-us/community-repository/moderation/package-validator/rules/
- https://docs.chocolatey.org/en-us/community-repository/moderation/package-validator/
- https://docs.chocolatey.org/en-us/community-repository/moderation/package-verifier/

## Findings

1. `talk/presentation.md:85`

`Verifier: install, upgrade, uninstall` is not what the verifier doc says. The official page says it checks that a package “installs and uninstalls correctly,” has the right dependencies, and “can be installed silently,” plus it rechecks existing packages every two weeks. I’d drop `upgrade` unless you have a stronger source for that. Source: [Package Verifier](https://docs.chocolatey.org/en-us/community-repository/moderation/package-verifier/)

2. `talk/presentation.md:128` and `talk/presentation.md:466`

`VERIFICATION.txt is convention, not enforcement` is too broad. The validator rules explicitly include `CPMR0006 - VERIFICATION.txt file missing when binaries included`, so the file’s presence is enforced for packages with included binaries. A more accurate line is: “`VERIFICATION.txt` is required when binaries are included, but the quality/completeness of its contents is still partly reviewer-driven.” Sources: [Validator Rules](https://docs.chocolatey.org/en-us/community-repository/moderation/package-validator/rules/), [Moderation](https://docs.chocolatey.org/en-us/community-repository/moderation/)

3. `talk/presentation.md:86`

`VirusTotal plus human review for community packages` is only half-supported by the pages you asked me to review. The moderation doc does confirm human review for new package versions, with a trusted-package path that bypasses human review after automated checks. But the pages you linked do not mention VirusTotal. If you keep that claim, I’d cite a different Chocolatey source; otherwise reword to “automated checks plus human review.” Source: [Moderation](https://docs.chocolatey.org/en-us/community-repository/moderation/)

4. `talk/presentation.md:476` and `examples/chocolatey-package/example-package.nuspec:24`

`Missing metadata, unpinned dependency` is a mismatch with Chocolatey’s documented rules. Your example has minimum versions (`version="1.0"` / `version="6.0"`), which are not the same as “no version,” and the validator rules page only explicitly calls out `CPMR0052 - Dependency With No Version`. So “unpinned dependency” is valid as your own supply-chain critique, but not as “Chocolatey moderation would flag this.” Source: [Validator Rules](https://docs.chocolatey.org/en-us/community-repository/moderation/package-validator/rules/)

5. `talk/presentation.md:491`

`Checks metadata completeness ...` is bundled under “Step 1: Naming Validation,” but the docs treat these as separate validator rules, not one naming-specific moderation step. If this is your pipeline, that’s fine; I’d just present it as “our pre-publish validation” rather than implying that Chocolatey has a single built-in naming-validation phase covering `projectUrl`, `iconUrl`, and `tags`. Source: [Package Validator](https://docs.chocolatey.org/en-us/community-repository/moderation/package-validator/), [Validator Rules](https://docs.chocolatey.org/en-us/community-repository/moderation/package-validator/rules/)

## Repo / talk-track nits

- `talk/presentation.md:481` references `VERIFICATION.txt` generically, but in your repo the file is actually `examples/chocolatey-package/tools/VERIFICATION.txt`. Not wrong, just worth being precise if you demo file paths live.
- `talk/presentation.md:118` says the registry doesn’t monitor drift after approval. That’s directionally fair, but the verifier does rerun existing packages every two weeks, so it’s better framed as “doesn’t give provenance or continuous binary-identity guarantees” rather than “no post-approval checking.” Source: [Package Verifier](https://docs.chocolatey.org/en-us/community-repository/moderation/package-verifier/)

## Bottom line

Your core story holds up: CCR already does meaningful moderation, but it does not produce SBOMs/provenance “receipts.” The main fixes I’d make are:

- remove `upgrade` from verifier,
- narrow the `VERIFICATION.txt` claim,
- avoid attributing your custom dependency/naming checks to Chocolatey’s built-in moderation,
- and either source or soften the `VirusTotal` wording.

If you want, I can do a second pass and suggest exact replacement wording slide-by-slide.
