# Set up a generated repository

Generate the app, restore dependencies, commit the resulting locks, install the
hooks, and run [CONTRIBUTING.md](../CONTRIBUTING.md)'s checks. Node 24 and PowerShell
7.4+ are required for repository tooling; neither ships in the app.

## Preview

The default command works offline and writes thirteen non-secret API requests:

```powershell
./build/Initialize-GitHubRepository.ps1 -Repository KofTwentyTwo/windows-app-template
Get-Content artifacts/repository-setup.json
```

Generated names and owner are substituted. Pass `-MaintainerCount 2` when there
are multiple maintainers: this requires one independent approval. The default
single-maintainer policy requires `review / automated` and no bypass on `main`.

## Bootstrap and apply

An administrator must authorize creation and the first push separately. Create a
public repository, push the reviewed initial tree to `main`, and open a small
bootstrap PR. Wait for every documented CI context to succeed. Read the automated
review of its **current** head and post your own acknowledgement on that PR:

```text
<!-- k22-automated-review:FULL_CURRENT_PR_COMMIT_SHA -->
Tool: Codex
Findings: none
Summary: Describe the actual reviewed scope and evidence here.
Maintainer acknowledgement: I read the review and resolved or answered every finding.
```

The privileged review workflow executes trusted `main` code only. New PR commits
need a new record; stale or incomplete records fail. An agent must not acknowledge
on your behalf. Organization-owned repositories must change the configured human
maintainer in `.github/scripts/review-gate.cjs` and its tests before bootstrap.

With GitHub CLI signed in as an authorized administrator:

```powershell
$sha = gh pr view BOOTSTRAP_PR_NUMBER --json headRefOid --jq .headRefOid
./build/Initialize-GitHubRepository.ps1 -Mode Apply -CheckSha $sha -WhatIf
# After reviewing and authorizing this exact plan:
./build/Initialize-GitHubRepository.ps1 -Mode Apply -CheckSha $sha
./build/Initialize-GitHubRepository.ps1 -Mode Validate
```

The tool verifies the exact public target, `main`, administrator access, absence
of repository secrets/self-hosted runners, current bootstrap PR SHA and successful
GitHub Actions checks. It binds required contexts to the observed Actions app ID,
creates both rulesets and the tag-only `release` environment, enables security
features, restricts Actions, and reads settings back. Existing matching policy is
reused; conflicting rules or release policies stop before writes. Unrelated rules
and environment protections are retained. API failures stop immediately; earlier
successful requests may remain, so validate and resolve the reported failure before
rerunning. The tool never creates repositories, pushes, merges, tags or releases.

## Finish and verify

Register ownership/tier in the standards `MAINTAINERS.md` inventory through a
reviewed PR. Set the description/topics and review account community defaults.
Configure signing using the verified existing Azure service; keep credentials in
the protected environment and use OIDC wherever supported. Run the standards
conformance checker against the live repository and try a failing disposable PR
to prove the checks block merging. Enroll in OpenSSF Best Practices with actual
owner attestations; never add an unearned badge.

Local fixture tests prove planning, refusal boundaries, application/readback and
idempotence. A disposable live generated repository has not yet been provisioned;
that proof requires authorized creation/push and successful hosted CI.

API shapes follow GitHub's official [rulesets](https://docs.github.com/en/rest/repos/rules),
[Actions permissions](https://docs.github.com/en/rest/actions/permissions) and
[deployment branch policies](https://docs.github.com/en/rest/deployments/branch-policies)
documentation.
