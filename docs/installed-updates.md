# Installed release smoke tests

Run on an interactive Windows x64 desktop with the pinned .NET SDK and Velopack
1.2.161. The test packages and installs only uniquely named local fixtures; it
does not create GitHub releases, use Azure, or produce release-signing evidence.
Reserve at least 8 GB free on the repository artifact volume. The harness checks
this before building; retained archives, portable copies and installations can
otherwise exhaust the volume during extraction.

```powershell
dotnet tool install vpk --version 1.2.161 --tool-path artifacts/smoke-tools
./build/Test-InstalledUpdates.ps1 -VpkPath ./artifacts/smoke-tools/vpk.exe
```

The harness publishes the actual starter app four times with locked dependencies,
self-contained .NET and Windows App SDK settings matching the release builder.
Core and CLI declare the Windows runtime identifiers so their committed locks
support runtime-specific publishing. Their single-file analyzer setting also locks
the SDK's ILLink tool dependency used when publishing the CLI as one executable.
The harness publishes and runs each CLI version when that head exists.
Keep `VelopackApp.Build().Run()` directly in
the app's entry point: the packer's startup check cannot recognize an indirect
AppKit wrapper call. Do not disable that pack-time check.

The app's publish target explicitly includes its generated PRI and XBF resources.
This fixes the unpackaged publish omission documented in
[WindowsAppSDK#6720](https://github.com/microsoft/WindowsAppSDK/issues/6720):
without the app PRI, `MainWindow.xaml` fails to load even when Debug UI tests pass.

## What the harness checks

- Loose published output launches and passes the full UI suite; AppKit reports
  self-update unavailable when no Velopack manifest/updater exists.
- Real Setup installs `stable` 0.1.0 and `dev` 0.3.0-beta.1 into separate, bounded
  test directories using one unique test package ID. No shortcuts are requested.
- The probe calls AppKit's public `CheckAsync` and `DownloadAndApplyAsync` methods.
  A test-only downloader maps GitHub response URLs to local assets and refuses
  other URLs. Reflection replaces only transport in the pinned AppKit 0.1.0 /
  Velopack 1.2.161 source, failing closed if its private symbols change. The actual
  backend, update manager, locator and channel selection remain unchanged.
- Stable offers only 0.4.0; dev offers only 0.3.0-beta.2, even though the stable
  version is higher. Requests must never fetch the other channel's feed.
- Velopack downloads and verifies the real package, applies it, and restarts the
  actual WinUI app. Its window must appear. Post-upgrade AppKit version and channel
  must match, with no remaining offer; six applicable UI tests run after each upgrade.
- Published executable headers must parse before archive comparisons. Both archive
  payloads must preserve every original non-PDB publish file outside
  Velopack's default exclusions. SHA256 comparisons reject changed or missing
  dependencies before installation, including a locally observed corrupt runtime DLL.
- Complete portable bundles preserve their channel and support updates. They differ
  from loose F5/publish output; a `.portable` marker does not disable self-update.

The probe records public check errors and apply calls, including the target asset
request before apply exits. The harness separately requires the installed target
manifest, exact application hash and restarted window. The AppKit UI's live GitHub
check/apply flow and public release hosting remain separate acceptance items. This
does not prove Authenticode signing, installer trust, deltas or ARM64/x86.
Only the probe's executable, assembly and runtime manifests are added to smoke
packages. Its framework dependency copies never overwrite the application's
published payload. The probe is never added to production publish output.

A fresh GUI-only run passed both installed upgrades, restart, all four byte gates
and nineteen UI checks. Each version preserved 532 original publish files in both
archive formats. CLI attempts also passed every byte gate and the stable upgrade,
but two installed UI suites timed out on input-driven checks; AppKit issue #23
tracks that separate acceptance gap. A published-output recurrence showed the
crash button's clickable point belonged to Windows Terminal despite app keyboard
focus. Physical input now waits until the app owns an unobscured clickable point,
then clicks once. Results record process/point observations without unrelated
window text; crash/greeting failures include isolated app state and logs. The
guarded seven-case suite passed on the exact failed published executable, but
hosted CI and complete CLI acceptance remain required.

A later CLI run completed both channel upgrades and passed eighteen of nineteen
UI cases, then timed out on the dev theme menu. Menu/control input now foregrounds
the app, matching the foundation samples; every physical fallback uses the same
point-ownership guard. Three focused theme checks and the six-feature sequence
passed on the exact dev publish payload. Those diagnostic passes do not replace
a complete fresh-template installed run or erase its retained failure.

Original publish/archive corruption fixtures remain retained under AppKit
issue #22. These successful staging checks do not establish their cause. Do not attribute
the corruption to a particular tool or machine component without proof.

## Evidence and cleanup

CI requires `installed-updates` and retains JSON results, process/installer logs
and TRX UI reports. Local evidence stays under a fresh `artifacts/installed-smoke-*`
directory. Existing output directories are refused so each attempt tests fresh
packages and results. Packer children receive a private `VELOPACK_TEMP` directory
named for the unique test package ID, isolating staging from other app builds.
Publish and probe output also use that private system temporary directory. This
matches the Windows CI staging location and avoids repeated writes into the
checkout during local diagnostics; it does not establish the corruption's cause.
`build-directory.txt` records its location. Build inputs are retained there for
investigation, while packages and reports remain under the repository artifacts
directory.
Each successful/failing installed test
attempts uninstall in `finally`, checking the bounded root and unique manifest ID
first. Unexpected existing installations fail rather than being overwritten.

See the official [Setup switches](https://docs.velopack.io/reference/cli/content/setup-windows)
and [updater switches](https://docs.velopack.io/reference/cli/content/update-windows).
