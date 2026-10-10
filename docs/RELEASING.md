# Releasing Kof22 App

<!--#if (templateSource) -->
This runbook applies to generated applications. To publish the source template's
NuGet package, follow [TEMPLATE.md](../TEMPLATE.md#publishing-this-template).
<!--#endif -->

Releases follow the
[KofTwentyTwo release standard](https://github.com/KofTwentyTwo/standards/blob/main/standards/releases.md).
Pushing a protected `v*` tag on `main` runs [`.github/workflows/release.yml`](../.github/workflows/release.yml),
which calls the shared `release-velopack.yml` workflow in KofTwentyTwo/standards.

## Workflow baseline

Shared workflows are pinned to published standards v0.1.2. The release caller checks main ancestry and reruns build, coverage, formatting, UI tests, security scans and CodeQL before publication.
The AppKit dependency locks now match the published 0.1.0 packages. Before changing any package version, regenerate the affected locks and verify a locked restore with a clean package cache.

## Versioning and channels

The version is the tag without the leading `v`, in strict [semver](https://semver.org).

| Tag | Version | GitHub Release | Velopack channel |
| --- | --- | --- | --- |
| `v1.2.3` | `1.2.3` | stable | `stable` |
| `v1.2.3-beta.1` | `1.2.3-beta.1` | prerelease | `dev` |

An installed copy only updates within its own channel. `Directory.Build.props` holds
`VersionPrefix`, the next expected release; local builds are `<prefix>-dev`. Bump it in a
pull request right after each release.

Run the [installed channel smoke test](installed-updates.md) before releasing.
It verifies real stable/dev upgrades and published-output startup with local fixtures.

## What a release does

The shared workflow (SLSA Build L3: the build definition lives in KofTwentyTwo/standards):

1. Validates strict SemVer and repeats locked restore,
   zero-warning build, unit tests, and the 100% coverage gate.
2. Publishes the app unpackaged and self-contained (and the single-file command line),
   signs the binaries when code signing is enabled, and packs them with Velopack: Setup,
   portable zip, full and delta update packages.
3. Generates CycloneDX SBOMs, writes `SHA256SUMS`, and attests provenance and SBOMs.
4. Creates a draft GitHub Release with every asset and generated notes, then publishes
   it (releases are immutable).

The optional `winget` job in `release.yml` then submits the manifest update for stable
releases.

Optional Scoop/Chocolatey candidate generation supports CLI and GUI portable
payloads, using final-byte hashes and verified provenance. Follow the
[distribution presets](distribution.md); no package feed is updated by default.

## One-time setup (owner)

1. **Environment** `release` (Settings → Environments) with a deployment rule that allows
   only tags matching `v*`.
2. **Code signing** (when exception EX-0002 closes): the Azure variables listed at the top
   of `release.yml` on the `release` environment, then `sign: true`.
3. **winget** (optional): submit the first stable release by hand with `wingetcreate new`,
   then add `WINGET_TOKEN` to the `release` environment and the repository variable
   `WINGET_PACKAGE_ID`.

## Cutting a release

1. Make sure `main` is green and the conformance check passes:
   `pwsh ../standards/tools/Test-RepoConformance.ps1 -Repository KofTwentyTwo/windows-app-template -LocalPath .`
2. For a minor or major release, open a release checklist issue from the standards
   template and complete it (security assessment, threat model review, scan results).
3. Tag `main` and push the tag:

   ```powershell
   git switch main
   git pull
   git tag -s v0.1.0 -m "v0.1.0"
   git push origin v0.1.0
   ```

4. Watch the **release** workflow, then verify the release as described in the
   [README](../README.md#verifying-a-release).
5. Open a pull request that bumps `VersionPrefix` in `Directory.Build.props`.

## When something fails

- **Before the release is published:** nothing is public. Delete the draft
  (`gh release delete v0.1.0 --yes`), fix the cause, and re-run the workflow.
- **A published release is broken:** never reuse its version; installed copies may have
  seen it. Fix forward with a new patch release.
