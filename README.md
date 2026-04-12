# publish-with-receipts

[![Test Suite](https://github.com/adilio/publish-with-receipts/actions/workflows/run-tests.yml/badge.svg)](https://github.com/adilio/publish-with-receipts/actions/workflows/run-tests.yml)
[![PowerShell Supply Chain](https://github.com/adilio/publish-with-receipts/actions/workflows/powershell-supply-chain.yml/badge.svg)](https://github.com/adilio/publish-with-receipts/actions/workflows/powershell-supply-chain.yml)
[![Chocolatey Supply Chain](https://github.com/adilio/publish-with-receipts/actions/workflows/chocolatey-supply-chain.yml/badge.svg)](https://github.com/adilio/publish-with-receipts/actions/workflows/chocolatey-supply-chain.yml)

> Companion repo for **"Provenance Before Publish"** — a Chocolatey Fest session at PowerShell + DevOps Global Summit 2026 (Bellevue, WA, April 13–16).

**The argument:** PowerShell and Chocolatey lack the enforcement plumbing every other major package ecosystem took for granted years ago. No lockfile. No moniker rules. `VERIFICATION.txt` is a norm, not a contract. Moderation doesn't scale to internal repositories. The registries aren't negligent — they can't issue receipts for work that happens before their layer.

This repo is the plumbing, shaped as composite GitHub Actions you can adopt one at a time. It generates three artifacts on every push so you can answer three questions about any package you publish:

| Question | Artifact | Tool |
|---|---|---|
| What's in this package? | SBOM (CycloneDX) | Syft |
| What did you check? | Scan results (SARIF) | PSScriptAnalyzer + Semgrep + Grype |
| Can you prove how it was built? | Provenance (SLSA-style) | GitHub Attestations |

Not a green checkmark. Receipts.

## What's honest about the current state

Producing receipts today runs ahead of consuming them. `Install-Module` doesn't verify a SLSA attestation. `choco install` doesn't either. The registries don't require one at upload. The maintainer-side audit value is real — if you ever need to prove the artifact in the registry came from a specific commit and pipeline run, you can. The consumer-side verification loop will close when the registries require signed provenance at upload and the clients verify at install. That's an ecosystem-level change this repo doesn't claim to drive; it only claims that producing the receipts now means your back catalog is ready the day someone starts reading them.

Two other gaps the talk and repo name plainly:

- **No PowerShell lockfile.** An SBOM records what you *shipped*, not what resolves on the consumer's machine. The closest current workaround is pinning `RequiredVersion` (exact) instead of `ModuleVersion` (floor) and enforcing it with `dependency-pin-check`. That's a maintainer-side commitment, not a consumer-side guarantee.
- **Internal repos have no moderation.** The community repo has human reviewers; your internal Chocolatey repo typically has nobody. In that context this pipeline is not a complement to moderation — it *is* the moderation. Enforce accordingly.

## Repo layout

```
publish-with-receipts/
├── examples/
│   ├── powershell-module/          # Intentionally flawed PS module (demo fixture)
│   └── chocolatey-package/         # Intentionally flawed Choco package (demo fixture)
│
├── .github/workflows/
│   ├── powershell-supply-chain.yml # Full pipeline for PowerShell modules
│   └── chocolatey-supply-chain.yml # Full pipeline for Chocolatey packages
│
├── actions/                        # Reusable composite actions — adopt any one independently
│   ├── ps-script-analysis/         # PSScriptAnalyzer → SARIF
│   ├── semgrep-scan/               # Pattern matching for unsafe code → SARIF
│   ├── dependency-pin-check/       # Floating-dependency detection (.psd1 / .nuspec)
│   ├── choco-naming-validation/    # Levenshtein similarity against CCR
│   ├── choco-integrity-check/      # Checksum + VERIFICATION.txt drift check
│   ├── sbom-generate/              # SBOM via Syft
│   ├── vulnerability-scan/         # Grype against the SBOM → SARIF
│   └── provenance-generate/        # SLSA-style provenance artifact
│
├── semgrep-rules/
│   ├── powershell-unsafe-patterns.yml    # 12 rules: download-execute, secrets, obfuscation, pinning
│   └── chocolatey-install-patterns.yml   # 12 rules: checksums, PATH/registry/service, pinning
│
├── scripts/
│   └── Invoke-LocalValidation.ps1  # Run the checks locally before pushing
│
├── docs/
│   ├── threat-model.md             # Threats this pipeline addresses, with real-incident grounding
│   ├── tooling-decisions.md        # Why these tools, what was considered, what the tradeoffs are
│   ├── enterprise-integration.md   # How the pipeline outputs feed into SCA and CSPM platforms
│   └── remediation-guide.md        # Copy-paste fixes for every finding type the pipeline surfaces
│
├── talk/                           # Slide deck + speaker track + Summit 2026 Marp theme
│   ├── presentation.md
│   ├── talk-track.md
│   └── summit-2026.css
│
├── ANALYSIS.md                     # Pre-talk critique + revised structure, slides, and track
└── CONTRIBUTING.md                 # How to add rules, actions, and examples
```

## Quick start

### Try it against the flawed examples

```powershell
# Clone, run locally
git clone https://github.com/adilio/publish-with-receipts.git
cd publish-with-receipts
./scripts/Invoke-LocalValidation.ps1 -Target both
```

Required tools: `Install-Module PSScriptAnalyzer`, `pip install semgrep`, and optionally [Syft](https://github.com/anchore/syft) and [Grype](https://github.com/anchore/grype).

### Use a single action in your own workflow

Every action is self-contained. You do not need to adopt the whole pipeline.

```yaml
# Minimum adoption: SBOM + SARIF
- uses: adilio/publish-with-receipts/actions/sbom-generate@main
  with:
    path: ./your-module
    output-file: sbom.cdx.json
    artifact-name: sbom

- uses: adilio/publish-with-receipts/actions/vulnerability-scan@main
  with:
    sbom-path: sbom.cdx.json
    sarif-output: grype.sarif
```

### Fork it

Open a PR that edits anything in `examples/` and watch the pipeline produce SARIF annotations directly in the PR diff.

## What the example fixtures demonstrate

Both example packages are *intentionally flawed in realistic ways* — the kind of thing that ships when somebody is moving fast, not cartoonishly broken.

**PowerShell module (`examples/powershell-module/`)**

- Floating dependency in `RequiredModules`
- `ScriptsToProcess` — the same mechanism used in Aqua's 2023 typosquat PoC
- An exported function combining a hardcoded API key, TLS validation bypass, `Invoke-WebRequest | Invoke-Expression`, and base64-encoded command execution
- Missing metadata (`ProjectUri`, `LicenseUri`, `ReleaseNotes`)
- A Pester test suite that passes — the supply chain issues are invisible to traditional CI

**Chocolatey package (`examples/chocolatey-package/`)**

- Missing checksums on external binary downloads
- `Invoke-WebRequest` outside Chocolatey's built-in helpers
- Undocumented PATH modification with no matching uninstall cleanup (local priv-esc precondition)
- Registry writes containing a hardcoded internal URL
- `VERIFICATION.txt` with no checksums

## Threats the pipeline addresses

The short list, each backed by a real incident. Full write-up in [`docs/threat-model.md`](docs/threat-model.md).

| Threat | Real-world grounding |
|---|---|
| Name impersonation | Aqua Nautilus `Az.Table` PoC, 2023 — production Azure callbacks within hours |
| Download-and-execute | Serpent malware campaign, 2022 — legitimate Chocolatey use to install a backdoor |
| Floating dependency | Structural — no PowerShell lockfile, `ModuleVersion` is a floor |
| Unverified binary drift | 3CX supply chain compromise, 2023 — vendor's signed installer pre-backdoored |
| Secret leakage | Aqua PSGallery research, 2023 — unlisted packages still served via API |
| Unsafe install patterns | Under-reviewed in internal repos; PATH modification → LPE chain |

## Toolchain (free, open source)

| Tool | Purpose | Output |
|---|---|---|
| [PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer) | PowerShell static analysis | SARIF |
| [Semgrep](https://github.com/semgrep/semgrep) | Pattern-based scanning (custom rules) | SARIF |
| [Syft](https://github.com/anchore/syft) | SBOM generation | CycloneDX JSON |
| [Grype](https://github.com/anchore/grype) | Vulnerability scanning | SARIF + JSON |
| [SLSA / GitHub Attestations](https://slsa.dev/) | Provenance | in-toto JSON |

No vendor licenses. No proprietary platforms. Everything runs on GitHub Actions public runners.

## Monday-morning adoption path

You do not need to take the whole pipeline on day one. Three-step path:

1. **One afternoon — visibility.** Add `ps-script-analysis` + `semgrep-scan` with SARIF upload, non-blocking. Let your team see what fires in the PR diff.
2. **One afternoon, later — artifacts.** Add `sbom-generate` + `provenance-generate`. Neither blocks anything; both produce receipts that become useful when you need them.
3. **Ongoing — tune, suppress with justification, decide what blocks.** Treat enforcement as a decision you earn by first seeing the baseline, not a flag you flip on day one.

For internal Chocolatey repos, that last step moves up the priority list. Community repos have moderation. Your internal repo has whatever you enforce in CI.

## Required GitHub workflow permissions

```yaml
permissions:
  contents: read
  security-events: write  # SARIF upload to Code Scanning
  id-token: write         # provenance attestation signing
  actions: read
```

`id-token: write` is required for signed provenance via `slsa-verifier`. Without it, the provenance artifact is still produced and uploaded, but it cannot be cryptographically verified. If you don't need signed attestations, omit it — the rest of the pipeline still runs.

## Suppressing false positives

When a Semgrep or PSScriptAnalyzer finding is a known false positive, suppress inline with a justification comment:

```powershell
# nosemgrep: powershell-invoke-expression — intentional: local script block, not remote content
$result = Invoke-Expression $localScriptBlock
```

```powershell
[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
param()
```

Suppressions ship in SARIF and are visible in the PR. See [`docs/remediation-guide.md`](docs/remediation-guide.md) for the full suppression reference and copy-paste fixes for every finding type the pipeline surfaces.

## Running checks locally

```powershell
# Full check, both examples
./scripts/Invoke-LocalValidation.ps1 -Target both

# Quick PS-only check (skip Syft/Grype)
./scripts/Invoke-LocalValidation.ps1 -Target powershell -SkipSBOM

# CI-equivalent mode (fail on findings)
./scripts/Invoke-LocalValidation.ps1 -Target both -FailOnFindings
```

## Talk materials

All talk content lives under `talk/`:

- [`talk/presentation.md`](talk/presentation.md) — the Marp deck
- [`talk/talk-track.md`](talk/talk-track.md) — continuous speaker track for the 90-minute session
- [`talk/summit-2026.css`](talk/summit-2026.css) — the Summit 2026 Marp theme (by [@HeyItsGilbert](https://github.com/HeyItsGilbert/PSSummit2026))

Export instructions and theme notes: [`AGENTS.md`](AGENTS.md).

The pre-delivery review was done with the **death-by-ppt** skill by [@HeyItsGilbert](https://github.com/HeyItsGilbert/marketplace/blob/main/plugins/presentation-review/skills/death-by-ppt/SKILL.md). A full critique and the revised deck structure are in [`ANALYSIS.md`](ANALYSIS.md).

## Contributing

Issues and PRs welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for how to add Semgrep rules, composite actions, and example anti-patterns. If there's a threat vector you think should be covered — or a tool that fits the pipeline better — open an issue.

## License

MIT. Use it, fork it, adapt it, ship it.
