# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Swift Package shipping libgit2 and its deps (libssh2, OpenSSL `libssl`/`libcrypto`) as prebuilt static libraries for Apple platforms and Linux. No Swift source, no tests.

## Target workflow (CI-driven)

CI builds everything; nothing is built or released by hand:

1. Build static libs: XCFrameworks for Apple (iOS, simulator, Catalyst, macOS).
2. Publish the artifacts (zips) to a GitHub Release.
3. Generate `Package.swift` (binary targets, URLs, checksums via `swift package compute-checksum`) and commit it.

`Package.swift` is generated output: change the CI/generator, not the file by hand.

## Current state

- `bin/build_openssl.sh` → `build_libssh2.sh` → `build_libgit2.sh` → `build_spm.sh` (checksums) are the legacy Apple-only scripts, and they run in that order. They are the starting point for the CI jobs. They need `cmake`, `xcodebuild` and `lipo`, and write logs to `/tmp/<lib>-<PLATFORM>.log`.
- Sources are git submodules (`External/libgit2`, `libssh2`, `openssl`); the pinned commit is the version. To bump: `git -C External/<lib> fetch --tags && git -C External/<lib> checkout <tag>`, then commit. `External/openssl-config/` is vendored. CMake builds use native iOS/Catalyst settings (no toolchain file).
- `.github/workflows/release.yml` (manual, main only) builds, regenerates `Package.swift` via `bin/generate_package.sh`, tags and publishes a release. The three build scripts were verified locally (all four zips produced, SSH+HTTPS enabled); the workflow itself has not run yet.
- Linux is not supported yet and not planned.

## Design proposals (Notion, not in the repo)

Design proposals/ADRs live in Notion, never under `docs/` in this repo. Create new ones as pages in `proposal_database` and link them to this project via the `Project` relation.

- Project page `spm-libgit2` (`proposal_project_database`; Repository: https://github.com/amine2233/libgit2-spm): https://app.notion.com/p/3f25ab33ba8e800caf1aedeccdb05e2b
- `proposal_project_database`: https://app.notion.com/p/61400aa381b0427c8234362f48b4a96e (data source `collection://08585a1d-6e28-4505-a40d-8420ed12e3b6`)
- `proposal_database`: https://app.notion.com/p/f27ffb1fd8c14025aec182840c0c8990 (data source `collection://f62aaef9-b201-464e-8c0b-160023363a98`); properties: Name, Category (Architecture/Feature/Tooling/Other), Project, Status
