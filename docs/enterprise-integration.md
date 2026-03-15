# Enterprise Integration Guide

The `publish-with-receipts` pipeline produces three classes of artifacts:

| Artifact | Format | Purpose |
|----------|--------|---------|
| SARIF files | `.sarif` (JSON) | Security findings from PSScriptAnalyzer, Semgrep, Grype |
| SBOM | CycloneDX JSON | Bill of materials for the built package |
| Provenance | SLSA v0.2 JSON | Build metadata — where, when, how |

These artifacts are useful on their own (via GitHub's native integration), but they become significantly more powerful when connected to enterprise platforms. This document describes the integration tiers and how to connect pipeline outputs to each.

---

## Tier 1: GitHub-Native (Zero Cost, Zero Setup)

### Code Scanning (SARIF)

All three scanning steps (PSScriptAnalyzer, Semgrep, Grype) upload SARIF to GitHub Code Scanning via `github/codeql-action/upload-sarif`. This requires:

- The `security-events: write` permission in the workflow
- A repository with Code Scanning enabled (free for public repos; requires GitHub Advanced Security for private repos)

**What you get:**
- Findings appear in the **Security → Code Scanning** tab
- Findings appear as annotations on PR diffs — reviewers see them without leaving the PR
- Findings persist per-branch; resolved findings are automatically closed when the code is fixed
- The Security tab shows historical trends (finding count over time)

**Configuration:**

No extra configuration is needed beyond what's already in the workflow files. To enable Code Scanning on a private repository, enable GitHub Advanced Security in the repository settings.

### Artifact Attestations

The `provenance-generate` action uploads the provenance document as a build artifact. GitHub also supports native [Artifact Attestations](https://docs.github.com/en/actions/security-for-github-actions/using-artifact-attestations/using-artifact-attestations-to-establish-provenance-for-builds) (currently in beta as of early 2026), which produce Sigstore-signed provenance that can be verified with the `gh attestation verify` CLI command.

To upgrade from the lightweight provenance action to GitHub's native attestations:

```yaml
- name: Attest build provenance
  uses: actions/attest-build-provenance@v1
  with:
    subject-path: 'path/to/artifact'
```

This requires the `id-token: write` permission (already present in the workflow) and produces a provenance statement that is published to Sigstore's transparency log.

### Dependabot

Dependabot operates at the repository level and can detect some dependency issues automatically. It does not consume the SBOM from this pipeline, but it complements it: Dependabot catches dependency updates for the repo's own dependencies (e.g., the GitHub Actions versions used in the workflow), while the SBOM captures the package's declared dependencies.

---

## Tier 2: SCA Platforms

Software Composition Analysis (SCA) platforms provide continuous monitoring that the pipeline alone cannot: they alert when *new* CVEs are published against packages that were already built and deployed. The pipeline catches CVEs at build time; the SCA platform catches CVEs discovered after the build.

### CycloneDX SBOM Ingestion

The SBOM produced by Syft (`*.cdx.json`) follows the CycloneDX 1.4+ schema, which is supported by all major SCA platforms:

| Platform | SBOM Import Method |
|----------|-------------------|
| Snyk | `snyk sbom --file sbom.cdx.json` or via API |
| Mend (WhiteSource) | REST API upload |
| Black Duck | Hub BOM import |
| Dependency-Track | REST API (`/api/v1/bom`) — native CycloneDX support |
| FOSSA | `fossa analyze` with SBOM input |

**Recommended open-source option — OWASP Dependency-Track:**

[Dependency-Track](https://dependencytrack.org/) is a free, self-hosted platform that natively consumes CycloneDX SBOMs. It provides:

- Continuous vulnerability monitoring (alerts when new CVEs affect your components)
- Policy evaluation (fail on critical vulns, SBOM completeness checks)
- REST API for automation

To push the SBOM to Dependency-Track from the pipeline, add a step after SBOM generation:

```yaml
- name: Upload SBOM to Dependency-Track
  shell: bash
  run: |
    curl -s -X POST \
      -H "X-Api-Key: ${{ secrets.DTRACK_API_KEY }}" \
      -H "Content-Type: multipart/form-data" \
      -F "autoCreate=true" \
      -F "projectName=example-package" \
      -F "projectVersion=${{ github.ref_name }}" \
      -F "bom=@sbom.cdx.json" \
      "${{ vars.DTRACK_URL }}/api/v1/bom"
```

### SARIF Ingestion

Most SCA platforms also accept SARIF for importing static analysis findings. Consult your platform's documentation for the specific API endpoint. GitHub Code Scanning's own SARIF format is generally compatible with platform-specific importers.

---

## Tier 3: Cloud Security / Runtime Context

The pipeline produces a point-in-time snapshot: "here's what was in the package when it was built, and here's what the tools found." Cloud security platforms add the runtime dimension: "which of these findings actually matter in our environment?"

### The Context Problem

A Grype finding that reports a critical CVE in a dependency is an important signal. But it becomes more (or less) urgent depending on:

- Is this package actually deployed anywhere?
- Is it deployed to production or a dev sandbox?
- Is the affected component reachable from the internet?
- Is it running with elevated privileges?
- Is the vulnerable code path actually called?

The pipeline can't answer these questions — it doesn't know your deployment topology. A cloud security platform that has visibility into your environment can correlate the SBOM finding with deployed workloads and provide this context.

### Example: Integrating with Wiz

[Wiz](https://www.wiz.io/) is one example of a cloud security platform that can ingest SBOMs and correlate findings with cloud environment context. The general pattern is:

1. The pipeline generates an SBOM and uploads it to a well-known location (artifact storage, object storage, Dependency-Track).
2. The cloud security platform ingests the SBOM and stores component inventory.
3. When a new CVE is published (or when a scan is triggered), the platform correlates the affected component with deployed workloads.
4. The platform surfaces findings with context: "This critical CVE affects `example-package` v2.1.0, which is deployed to 3 production VMs and is network-reachable."

This is the difference between a vulnerability list and risk prioritisation.

**Architecture pattern:**

```
Pipeline
  │
  ├─── SARIF → GitHub Code Scanning (PR annotations, Security tab)
  │
  ├─── SBOM  → Dependency-Track (continuous CVE monitoring)
  │             │
  │             └─── Wiz / CSPM (runtime context + risk scoring)
  │
  └─── Provenance → GitHub Artifacts / Sigstore (build integrity)
```

### For organisations without a cloud security platform

The SBOM + Dependency-Track combination (both free and open source) provides most of the continuous monitoring value without a commercial platform. The key capabilities:

- Upload SBOM at build time
- Dependency-Track queries NVD, GitHub Advisory, and OSV for new CVEs against your inventory
- Alert (email, webhook, Slack) when new CVEs affect tracked components
- Dashboard showing vulnerability status across all your packages

This is a reasonable starting point for teams that want continuous monitoring without a commercial tool.

---

## Storing and Accessing Pipeline Artifacts

### GitHub Actions Artifacts

By default, all pipeline artifacts (SBOM, provenance, Grype JSON) are uploaded with `retention-days: 90`. Adjust this in the `upload-artifact` calls in each composite action.

For long-term retention (beyond GitHub's maximum artifact retention), push artifacts to:
- An S3-compatible bucket (`aws s3 cp sbom.cdx.json s3://your-bucket/...`)
- Azure Blob Storage
- A container registry with OCI artifact support (using `oras` to push non-container artifacts)

### OCI Artifact Storage (Advanced)

OCI registries (Docker Hub, GHCR, ECR, ACR) support storing arbitrary artifacts, not just container images. Using `oras` (OCI Registry as Storage), you can push SBOMs and provenance documents to the same registry as your packages:

```bash
oras push ghcr.io/your-org/example-package:sbom-2.1.0 \
  --artifact-type application/vnd.cyclonedx+json \
  sbom.cdx.json:application/vnd.cyclonedx+json
```

This makes SBOMs discoverable alongside the packages they describe and enables tools like Notation (for signing) and Ratify (for policy enforcement) to work with the full artifact graph.

---

## Connecting to Incident Response

When a new CVE is published that affects a component you've shipped, the SBOM answers the first responder question: "which of our packages are affected?"

**Response workflow:**

1. New CVE published (e.g., CVE-2026-XXXXX in `Az.Accounts` v2.0.x)
2. Dependency-Track / SCA platform alerts: "3 packages in your inventory use a vulnerable version"
3. Use the provenance document to identify which commit and pipeline run produced each affected package
4. Re-run the pipeline on the updated dependency to generate a new provenance chain
5. Publish the patched package; the new SBOM documents the fix

The provenance chain answers: "can we prove that the patched version was built correctly and doesn't re-introduce the issue?"
