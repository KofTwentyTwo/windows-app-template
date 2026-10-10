# Windows release signing

Application releases require Authenticode signing. The generated caller starts
with `sign: false` so it remains compatible with its currently published builder,
but its preflight blocks publication until the reviewed signing builder is
published, pinned and configured. The source template's content-only NuGet package
does not contain application binaries and uses a separate release workflow.

## Configure the protected environment

Use an existing authorized Artifact Signing account and Active Public Trust
profile. Verify its deployed region/endpoint, actual tenant GUID and full
certificate publisher subject. A subscription ID or directory domain is not the
tenant GUID. Each repository needs an approved CI identity, GitHub OIDC trust
restricted to `repo:Owner/Repository:environment:release`, and the Artifact Signing
Certificate Profile Signer role scoped to its profile. Owner/Contributor alone
does not grant signing permission. Preserve other identities and assignments.

Set these non-secret variables in the protected `release` environment, permitting
only the intended `v*` release tags:

| Variable | Verified value |
| --- | --- |
| `AZURE_TENANT_ID` | Tenant GUID |
| `AZURE_CLIENT_ID` | Approved CI application/client GUID |
| `AZURE_SUBSCRIPTION_ID` | Signing resource's subscription GUID |
| `ARTIFACT_SIGNING_ENDPOINT` | Actual regional HTTPS endpoint |
| `ARTIFACT_SIGNING_ACCOUNT` | Existing signing account name |
| `ARTIFACT_SIGNING_PROFILE` | Actual active certificate profile |
| `ARTIFACT_SIGNING_SUBJECT` | Exact verified certificate subject |

Legacy `TRUSTED_SIGNING_*` configuration names remain accepted for the last four
values. Do not copy another repository's client ID without verifying its trust
and signer assignment. Template consumers do not inherit access to KofTwentyTwo's
signing service. Never export a PFX or put administrative passwords in CI.

## Enable the reviewed builder

Pin a published shared builder that supports an explicit `signing-files` catalog
and verifies the final shipped bytes/signatures. Standards v1.0.0 contains gclo's
Velopack signing fix, but lacks this catalog interface; do not enable a partial
path or pin unpublished commits. After the prepared builder is reviewed and
published, update the caller's full commit SHA/version comment and add:

```yaml
sign: true
signing-files: |
  app/Kof22App.exe
  app/Kof22App.dll
  app/Kof22App.Core.dll
  app/KofTwentyTwo.AppKit.dll
  app/KofTwentyTwo.AppKit.Updates.dll
  app/KofTwentyTwo.AppKit.WinUI.dll
```

For a CLI-enabled app, include `cli/kof22-app.exe`. Adapt names to the generated
project. Keep signing confined to protected Windows release jobs using the
official pinned Azure login/signing actions and their CLI-backed OIDC credential.
Pull requests receive no signing access. Preserve third-party signatures; sign
owned binaries before packaging and generated helpers/installers through the
packaging hook. Checksums, updater metadata and attestations follow signing.

## Verify before publication

The configuration preflight does not prove authorization or a valid signature.
Run representative real signing and `signtool verify /pa /all /v <artifact>` on
the exact shipped binaries and installers. Require the expected publisher,
trusted signatures, SHA256 digests and RFC3161 timestamps. Verification failures
must stop publication. For future MSIX packaging, its Publisher must match the
verified subject. Local signing uses Microsoft's Artifact Signing Client Tools
and the installed SignTool/dlib paths with an authorized identity.
