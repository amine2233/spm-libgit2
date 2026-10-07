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
- `.github/workflows/release.yml` (manual, main only) builds, regenerates `Package.swift` via `bin/generate_package.sh`, tags and publishes a release. Design: `docs/proposals/0001-*.md`. The three build scripts were verified locally (all four zips produced, SSH+HTTPS enabled); the workflow itself has not run yet.
- Linux is not supported yet and not planned.
