# Optional package-manager distributions

Velopack Setup and portable downloads remain the standard release artifacts.
Scoop, Chocolatey and winget are optional. Choose one portable payload for the
Scoop/Chocolatey presets: the single-file CLI (when enabled) or the GUI portable ZIP.
These package managers manage upgrades themselves; portable copies do not use
Velopack self-update. Settings stay under `%LOCALAPPDATA%\kof22-app` across upgrades.

## Generate and validate

Generate manifests from the **final verified release ZIP**, after signing, packaging
and provenance verification. The generator checks identity/version, rejects unsafe
archive paths, requires the root executable, and hashes the actual archive:

```powershell
# GUI portable, available with or without a CLI:
./build/New-DistributionManifests.ps1 -Version 1.2.3 `
   -ArtifactPath artifacts/kof22-app-stable-Portable.zip
# Optional CLI:
./build/New-DistributionManifests.ps1 -Version 1.2.3 -ArtifactKind Cli `
   -ArtifactPath artifacts/kof22-app-cli-win-x64-1.2.3.zip
```

The output is `artifacts/distribution/bucket/<app-id>-portable.json` (or `-cli`),
a Chocolatey nuspec, installation script and license. Metadata is XML escaped;
URLs/hashes are serialized as data. Only strict stable versions are accepted.
Generation and `-WhatIf` need no credentials. Keep app IDs and package IDs permanent
after the first publication. Both presets target x64 only.

Set the repository variable `DISTRIBUTION_ARTIFACT` to `portable` or `cli` to enable
the optional stable release job (`cli` requires a generated CLI). The job downloads
the immutable release ZIP and `SHA256SUMS`, verifies the hash and GitHub provenance,
generates manifests and runs `choco pack`. It uploads the candidate manifests and
package for review. It uses only read access and the protected `release` environment.
No package feed is updated automatically; enabling generation does not authorize
publication.

## Publish selected integrations

For Scoop, review the generated JSON and propose it as `bucket/<package-id>.json`
in this repository or your dedicated bucket. Validate against Scoop's schema and
test `scoop install`, `update` and `uninstall` with a disposable user before merging.
Users add the bucket with `scoop bucket add kof22-app https://github.com/KofTwentyTwo/windows-app-template`.
No token is needed by the generated consumer manifest.

For Chocolatey, inspect the generated nuspec/script and packed package, then test
installation, upgrade and uninstall in a disposable Windows environment. The
script verifies SHA256 and ignores helper executables when creating command shims.
The package includes its license. Claim/reserve your actual package ID with the feed
before publishing; community moderation may require additional product metadata.
Configure any publishing credential through the approved environment/secret store
and authorized publisher tooling, never in source or command-line arguments. These
presets intentionally do not embed a feed credential.

For winget, submit the first stable signed Setup using `wingetcreate new`, then set
`WINGET_PACKAGE_ID` and the `release` environment's `WINGET_TOKEN` for subsequent
updates. A configured integration with a missing token must fail. See
[release setup](RELEASING.md#one-time-setup-owner).
The pinned winget client reads `WINGET_CREATE_GITHUB_TOKEN` from the job environment;
the workflow keeps the token out of command-line arguments, following its verified
[v1.12.13.0 token helper](https://github.com/microsoft/winget-create/blob/v1.12.13.0/src/WingetCreateCLI/TokenHelper.cs).

## Evidence limits

Fixture tests cover stable-only versions, archive identity/layout, unsafe paths,
actual-byte hashes, XML metadata and CLI/no-CLI manifest shapes. Source generation
and package construction do not prove live feed installation or upgrade behavior.
Both presets were additionally generated from provenance-verified gclo 1.0.1 CLI
and portable ZIPs and passed the installed official Scoop schema. Fresh packaged
CLI/no-CLI templates generate the correct custom owner, app ID and executable.
Keep selected integrations pending until their disposable install/upgrade/uninstall
tests and actual publisher configuration succeed.

Manifest conventions follow [Scoop's official reference](https://github.com/ScoopInstaller/Scoop/wiki/App-Manifests)
and [Chocolatey's ZIP installation API](https://docs.chocolatey.org/en-us/create/functions/install-chocolateyzippackage/).
