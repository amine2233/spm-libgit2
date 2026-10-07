---
id: "0001"
title: "Manual CI release pipeline for libgit2 SPM binaries"
type: mini
status: accepted             # draft | in-review | accepted | rejected | implemented | superseded | abandoned
authors: ["Amine BENSALAH <amine.bensalah@intech-consulting.fr>"]
reviewers: []
decider: "amine2233"
created: 2026-10-07
review-deadline: 2026-10-12
discussion: ""           # PR link
supersedes: ""           # "<id> §x.y" when replacing (part of) another proposal
amends: ""               # proposal this one extends without contradicting
amended-by: ""
superseded-by: ""
---

# Proposal 0001 — Manual CI release pipeline for libgit2 SPM binaries

> Format: mini (triage score 2/6 — C1 public package contract, C5 several credible options).
> The key words MUST, MUST NOT, SHOULD, SHOULD NOT and MAY are to be interpreted as described in RFC 2119.

## Summary

We propose a manually triggered GitHub Actions workflow that reads pinned versions from a committed `versions.env`, builds libgit2/libssh2/OpenSSL XCFrameworks, regenerates `Package.swift`, tags the commit and publishes a GitHub Release, so that shipping a new libgit2 version is "edit one file, push, click Run". Unlike a fully automatic pipeline, nothing is built or published without an explicit click; the cost is one human step per release.

## Context and problem

- Build is four local scripts (`bin/build_openssl.sh` → `build_libssh2.sh` → `build_libgit2.sh` → `build_spm.sh`) that need a Mac and manual runs; there is no `.github/` directory.
- Sources (`External/libgit2`, `libssh2`, `openssl`) and two build inputs (`External/cmake/iOS.cmake`, `External/openssl-config/ios-and-catalyst.conf`, used at `bin/build_openssl.sh:52`) were submodule content and were removed, so the scripts cannot run on a clean checkout. Versions are recorded nowhere.
- `Package.swift` (tools 5.3, iOS 13 / macOS 10.15) was hand-edited: four `binaryTarget`s pointing at `releases/download/1.2.1/<lib>.zip` with checksums from `build_spm.sh`. It is stale (libgit2 1.2.1) and every bump means editing URLs and checksums by hand.
- `build_spm.sh` only prints checksums; nothing consumes them.

## Goals and non-goals

**Goals**

- **G1** — Bumping a dependency version is a change to one file (`versions.env`) committed to `main`.
- **G2** — A single manual `workflow_dispatch` run MUST produce `libgit2.zip`, `libssh2.zip`, `libssl.zip`, `libcrypto.zip`, a regenerated `Package.swift` whose URLs/checksums match them, a git tag and a published GitHub Release.
- **G3** — A consumer adds `.package(url: "https://github.com/amine2233/libgit2-spm", from: "<tag>")` and resolves without further steps.
- **G4** — The run MUST fail before publishing anything if a build or checksum step fails.

**Non-goals**

- **NG1** — Automatic triggers (push, schedule) and automatic detection of new upstream versions.
- **NG2** — Linux binaries (not planned, see `CLAUDE.md`).
- **NG3** — Changing the product layout (four zips, same target names) or the platform floor.

## Proposal

```mermaid
flowchart LR
    A[edit versions.env, push to main] --> B[Run workflow: release.yml]
    B --> C[fetch sources at pinned tags]
    C --> D[build_*.sh on macOS runner]
    D --> E[bin/generate_package.sh: checksums + Package.swift]
    E --> F[commit Package.swift, tag]
    F --> G[gh release create with 4 zips]
```

Usage:

```text
# versions.env
LIBGIT2_VERSION=1.9.0
LIBSSH2_VERSION=1.11.1
OPENSSL_VERSION=3.3.2

git commit -am "chore: bump libgit2 to 1.9.0" && git push
GitHub → Actions → Release → Run workflow (branch: main, release_tag: 1.9.0)

# consumer Package.swift
.package(url: "https://github.com/amine2233/libgit2-spm", from: "1.9.0")
```

Design points:

1. **Trigger**: `on: workflow_dispatch` only, inputs `release_tag` (default empty = `LIBGIT2_VERSION`). A guard step fails if `github.ref` is not `refs/heads/main`.
2. **Sources**: a `bin/fetch_sources.sh` shallow-clones the three upstream repos at the versions in `versions.env` into `External/`. `External/cmake/iOS.cmake` and `External/openssl-config/ios-and-catalyst.conf` are vendored (committed) in this repo. `versions.env` pins each source by tag **and** commit SHA; Actions are pinned by SHA.
3. **Build**: unchanged scripts on `macos-latest`, with the SIMULATOR typo already fixed. Outputs `lib/*.zip`.
4. **Package.swift**: `bin/generate_package.sh <tag>` runs `swift package compute-checksum` per zip and writes the file from a template. `Package.swift` stays generated output.
5. **Release order** (SPM resolves the tag's own `Package.swift`): build → `gh release create <tag> --draft lib/*.zip` → generate `Package.swift` → commit to `main` (not protected) → tag that commit → push tag → publish the draft. Any failure before the last step leaves `main` untouched or the draft unpublished; URLs only resolve after publish.
6. **Re-release of the same libgit2 version** (new OpenSSL/libssh2 only): pass an explicit `release_tag`. Not `1.9.0-1`: SemVer sorts it below `1.9.0`, so `from: "1.9.0"` would skip it. An existing tag makes the run fail.

| Case | Behaviour |
| --- | --- |
| Run from a non-main ref | Fails at the guard step |
| Tag already exists | Fails before building |
| Any build/zip missing | Fails before commit/tag/release |
| Draft release creation or upload fails | Nothing committed or tagged; re-run |
| Publish fails after tag push | Tag and `Package.swift` commit exist, draft still unpublished; re-publish the draft |

Goal coverage: G1 `versions.env`; G2 steps 1–5; G3 step 5 and tag naming; G4 job ordering, publish is the last step.

## Alternatives considered

| Option | For | Against | Verdict |
| --- | --- | --- | --- |
| Do nothing | No work | Manual, Mac-only, unreproducible, stale (1.2.1) | Rejected |
| Existing prebuilt libgit2 SPM packages | No maintenance | Not under our control, different target layout and versions | Rejected |
| Automatic on push to `main` or schedule | No clicks | Builds/publishes unreviewed; wastes macOS minutes; user asked for manual | Rejected (NG1) |
| Release first, then commit `Package.swift` | Simpler | Tag points at a commit with stale `Package.swift` | Rejected |
| Keep building locally; add only `fetch_sources.sh` + `generate_package.sh`, upload with `gh` by hand | Delivers G1 and most of G2, no CI | Needs your Mac, not reproducible, easy to forget a step | Rejected: CI gives a clean-machine build and one-click release; the scripts are reused unchanged |
| Manual run, `versions.env` pinned, chosen | Reproducible, explicit | One click per release | **Chosen** |

## Risks

- **Supply chain**: tags are mutable, so sources are pinned by commit SHA and the fetch step verifies the tag resolves to it. Actions are pinned by SHA; `GITHUB_TOKEN` gets `contents: write` for this workflow only.
- **Compatibility**: target names, zip names and platforms unchanged; consumers on `1.2.1` are unaffected. Floor stays iOS 13 / macOS 10.15 (decided); whether libgit2 1.9 and OpenSSL 3.x build at that floor with the legacy scripts is unmeasured and is the main risk. **Spike first**: one local run of the scripts on the pinned versions (also gives runtime and runner cost) before writing the workflow.
- **Rollback**: delete the release and tag; revert the `Package.swift` commit. Published tags SHOULD NOT be reused.
- **Observability**: the workflow uploads `/tmp/*.log` build logs as an artifact on failure.
- **Cost**: macOS runner minutes (~OpenSSL ×6 configs + libssh2 + libgit2 ×4), only when a human triggers it (to measure).

## Open questions

None. Resolved by @amine2233 on 2026-10-07: `main` is not protected (direct push); `iOS.cmake` and `openssl-config` are vendored from upstream at a pinned version; tags follow the libgit2 version, rebuilds take the next patch; floor stays iOS 13 / macOS 10.15.

## Review log

| Date | Reviewer | Verdict | Changes made |
| --- | --- | --- | --- |
| 2026-10-07 | design-proposal-reviewer | Yes, if | Added missing `openssl-config` input; draft-release-first order (fixes G4 contradiction); branch protection answered; SHA pinning; `-N` suffix dropped (SemVer pre-release); local-scripts alternative; spike-first gate. Floor risk acknowledged, not resolved. |

## Decision

Accepted 2026-10-07 by @amine2233. Condition: a local spike (scripts on pinned current versions, iOS 13 / macOS 10.15 floor) precedes writing the workflow; a failed floor is an `assumption` amendment.

## Amendments

<!-- Append-only after acceptance. Use scripts/amend-proposal.sh. See references/evolution.md. -->

### A1 — 2026-10-07 — Legacy build scripts do not run unchanged

- **Kind:** gap
- **Found by:** local spike, 2026-10-07 (sources fetched at libgit2 v1.9.7, libssh2-1.11.1, openssl-3.5.9; `Configure` run against the vendored conf).
- **Why:** `bin/build_openssl.sh` loops over `ios ios64 iossimulator catalyst mac64 macarm64`, but the vendored `ios-and-catalyst.conf` (from mfcollins3/libgit2-ios @ bdb0550) defines no `openssl-mac64` / `openssl-macarm64` target, so `Configure` fails for the macOS configs. It also sets `-fembed-bitcode` (removed from current Xcode), and `iossimulator`/`catalyst` x86_64-only entries are used while their `-arm` variants are unused. `openssl-ios64` configures fine on 3.5.9. Upstream release tags are annotated, so the pinned SHA MUST be the dereferenced commit (`45e844fa…` openssl, `a312b433…` libssh2, `49e408b3…` libgit2).
- **Change:** "Build unchanged scripts" becomes "build with minimal script fixes": add mac targets and arm64 simulator/Catalyst slices to the conf, drop `-fembed-bitcode`. The proposal's design (workflow, `versions.env`, draft-first release) is unchanged. Whether the full build succeeds at the iOS 13 / macOS 10.15 floor is still unmeasured.
- **Impact on goals / contract:** none on G1-G4 or the package layout. Adds script-fix work before the first CI run.
- **Test:** a full local run of the four scripts producing the four zips; first CI run on the same versions.

### A2 — 2026-10-07 — Sources are git submodules, not fetched by script

- **Kind:** detail
- **Found by:** requested by @amine2233, 2026-10-07.
- **Why:** the submodule commit is the version pin, so `versions.env` and `fetch_sources.sh` are redundant; a bump is `git -C External/<lib> checkout <tag>` plus a commit.
- **Change:** design point 2 now reads: sources are submodules (`External/libgit2`, `libssh2`, `openssl`), checked out by `actions/checkout` with `submodules: recursive`. `versions.env` and `bin/fetch_sources.sh` are removed. The default release tag is `git describe --tags` of `External/libgit2`. The SHA verification is implicit in the pinned gitlink.
- **Impact on goals / contract:** none. G1 now means "bump = move the submodule pointer"; goals G2-G4 and the package layout are unchanged.
- **Test:** first CI run checks out all three submodules and builds.
