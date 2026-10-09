# Releasing Kof22 App

Releases follow the
[KofTwentyTwo release standard](https://github.com/KofTwentyTwo/standards/blob/main/standards/releases.md).
Pushing a protected `v*` tag on `main` runs [`.github/workflows/release.yml`](../.github/workflows/release.yml),
which calls the shared `release-velopack.yml` workflow in KofTwentyTwo/standards.

## Pending before the first release

- **Repin the release workflow.** `release.yml` is pinned to the head of
  KofTwentyTwo/standards#5 (the Velopack release workflow) while that pull request is in
  review; repin it, like the other workflows, to a commit on standards `main`.
- **Regenerate the lock files against the published AppKit.** The committed
  `packages.lock.json` files were produced from a locally built AppKit 0.1.0, whose
  content hashes differ from the package published on nuget.org. Once AppKit 0.1.0 is on
  nuget.org, run `dotnet restore Kof22App.slnx -p:Platform=x64 --force-evaluate` and
  commit the updated lock files; CI's locked restore fails until then.

## Versioning and channels

The version is the tag without the leading `v`, in strict [semver](https://semver.org).

| Tag | Version | GitHub Release | Velopack channel |
| --- | --- | --- | --- |
| `v1.2.3` | `1.2.3` | stable | `stable` |
| `v1.2.3-beta.1` | `1.2.3-beta.1` | prerelease | `dev` |

An installed copy only updates within its own channel. `Directory.Build.props` holds
`VersionPrefix`, the next expected release; local builds are `<prefix>-dev`. Bump it in a
pull request right after each release.

## What a release does

The shared workflow (SLSA Build L3: the build definition lives in KofTwentyTwo/standards):

1. Validates the tag and re-runs every gate that guards `main`: locked restore,
   zero-warning build, unit tests, and the 100% coverage gate.
2. Publishes the app unpackaged and self-contained (and the single-file command line),
   signs the binaries when code signing is enabled, and packs them with Velopack: Setup,
   portable zip, full and delta update packages.
3. Generates CycloneDX SBOMs, writes `SHA256SUMS`, and attests provenance and SBOMs.
4. Creates a draft GitHub Release with every asset and generated notes, then publishes
   it (releases are immutable).

The optional `winget` job in `release.yml` then submits the manifest update for stable
releases.

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
   `pwsh ../standards/tools/Test-RepoConformance.ps1 -Repository KofTwentyTwo/Kof22App -LocalPath .`
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
