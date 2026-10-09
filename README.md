# Kof22 App

A KofTwentyTwo Windows desktop application.

[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/KofTwentyTwo/windows-app-template/badge)](https://scorecard.dev/viewer/?uri=github.com/KofTwentyTwo/windows-app-template)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)

<!--#if (templateSource) -->
> **This repository is also the KofTwentyTwo Windows app template.** It is a complete,
> working app, and `dotnet new k22-winapp` turns it into a new one with your names. See
> [TEMPLATE.md](TEMPLATE.md).

<!--#endif -->
| | |
| --- | --- |
| **Tier** | Product ([scope](https://github.com/KofTwentyTwo/standards/blob/main/policies/README.md#scope)) |
| **Standards** | Adopting [KofTwentyTwo standards](https://github.com/KofTwentyTwo/standards) (pre-v1.0); built from the KofTwentyTwo Windows app template |
| **Latest release** | [Releases](https://github.com/KofTwentyTwo/windows-app-template/releases/latest) |

## Install

Download `kof22-app-stable-Setup.exe` from the
[latest release](https://github.com/KofTwentyTwo/windows-app-template/releases/latest) and run it. It
installs per user (no administrator rights needed) and updates itself in place from
**Help → Check for updates**. `kof22-app-stable-Portable.zip` is a portable build that
does not self-update.

Prerelease tags (`v1.2.3-beta.1`) publish to the `dev` channel
(`kof22-app-dev-Setup.exe`); an installation only ever updates within its own channel.

<!--#if (cli) -->
The command-line tool ships in each release as a self-contained single-file
`kof22-app.exe` (no .NET runtime needed).

<!--#endif -->
## Usage

- **Greeting (example feature):** type a name and press **Greet**. The name is remembered
  for next time. This is the template's example of a feature: logic and state in
  `Kof22App.Core`, a thin view in `Kof22App`.
- **View:** choose the light, dark, or system theme; turn the startup splash and the
  startup update check on or off. Choices are saved immediately.
- **Help → Activity log:** a live view of the app's log, with an errors-only filter and a
  shortcut to the log folder.
- **Help → Check for updates** and **Help → About**.
<!--#if (cli) -->
- **Command line:** `kof22-app greet --name Ada`, `kof22-app --version`, `kof22-app --help`.
<!--#endif -->

Settings and logs live in `%LOCALAPPDATA%\kof22-app`. Set the data-folder environment
variable the app reports in its log (the app id in capitals, plus `_DATA_DIR`) to use a
different folder, for example a portable one.

## Building from source

Prerequisites:

- Windows 10 version 1809 or later, x64 or ARM64
- .NET 10 SDK (the feature band is pinned by `global.json`)
- Optionally Visual Studio 2026 (Windows App SDK workload) or Rider

```powershell
dotnet restore Kof22App.slnx -p:Platform=x64 --locked-mode
dotnet build Kof22App.slnx -p:Platform=x64 -warnaserror
dotnet test Kof22App.slnx -p:Platform=x64 --no-build --filter "FullyQualifiedName!~UiTests"
dotnet test tests/Kof22App.UiTests --no-build   # launches the app on the desktop
```

Package versions are declared in `Directory.Packages.props` and locked in each project's
`packages.lock.json`. [CONTRIBUTING.md](CONTRIBUTING.md) has the full local workflow,
including the coverage gate and the format check that CI runs.

## Verifying a release

Every release asset is listed in `SHA256SUMS` and has a build-provenance attestation
signed by the KofTwentyTwo release workflow:

```powershell
# Integrity: the file matches the published checksum
(Get-FileHash .\kof22-app-stable-Setup.exe -Algorithm SHA256).Hash   # compare to SHA256SUMS

# Origin: built by the KofTwentyTwo release workflow from this repository
gh attestation verify .\kof22-app-stable-Setup.exe --repo KofTwentyTwo/windows-app-template --signer-repo KofTwentyTwo/standards

# Publisher: Authenticode signature (once code signing is enabled; see SECURITY.md)
Get-AuthenticodeSignature .\kof22-app-stable-Setup.exe | Format-List Status, SignerCertificate
```

## Support

The latest minor release receives fixes; see [SECURITY.md](SECURITY.md#supported-versions)
for the full support policy.

## Security

Report vulnerabilities privately; see [SECURITY.md](SECURITY.md). The app's attack
surface is described in its [threat model](docs/security/threat-model.md).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE). Copyright (c) 2026 James Maes.
