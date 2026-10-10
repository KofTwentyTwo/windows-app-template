#Requires -Version 7.4
# Copyright (c) 2026 James Maes (KofTwentyTwo)
# SPDX-License-Identifier: MIT

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
Builds a non-secret, offline configuration plan for a generated public repository.
#>
function Get-GitHubRepositoryPlan
{
   [CmdletBinding()]
   [OutputType([hashtable])]
   param(
      [Parameter(Mandatory)] [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9-]*/[A-Za-z0-9_.-]+$')] [string] $Repository,
      [ValidateRange(1, 100)] [int] $MaintainerCount = 1
   )

   $root = "repos/$Repository"
   $contexts = @('pr / title', 'pr / dco', 'pr / dependency-review', 'security / secrets',
      'security / sca', 'security / workflows', 'codeql / analyze (csharp)',
      'codeql / analyze (actions)', 'codeql / analyze (javascript-typescript)',
      'ci / build-test', 'ci / format', 'ci / ui-tests', 'installed-updates', 'powershell', 'javascript')
   if(Test-Path -LiteralPath (Join-Path (Split-Path -Parent $PSScriptRoot) 'templates/KofTwentyTwo.Templates.WindowsApp.csproj'))
   {
      $contexts += 'template'
   }
   if($MaintainerCount -eq 1)
   {
      $contexts += 'review / automated'
   }
   $main = @{
      name = 'protect-main'; target = 'branch'; enforcement = 'active'; bypass_actors = @()
      conditions = @{ ref_name = @{ include = @('refs/heads/main'); exclude = @() } }
      rules      = @(
         @{ type = 'deletion' }, @{ type = 'non_fast_forward' }, @{ type = 'required_linear_history' },
         @{ type = 'required_signatures' },
         @{ type = 'pull_request'; parameters = @{
               required_approving_review_count = [int]($MaintainerCount -gt 1)
               dismiss_stale_reviews_on_push = $true; require_code_owner_review = $false
               require_last_push_approval = ($MaintainerCount -gt 1); required_review_thread_resolution = $true
            }
         },
         @{ type = 'required_status_checks'; parameters = @{
               strict_required_status_checks_policy = $true
               required_status_checks               = @($contexts | ForEach-Object { @{ context = $_ } })
            }
         }
      )
   }
   $tags = @{
      name = 'protect-release-tags'; target = 'tag'; enforcement = 'active'
      bypass_actors = @(@{ actor_id = 5; actor_type = 'RepositoryRole'; bypass_mode = 'always' })
      conditions    = @{ ref_name = @{ include = @('refs/tags/v*'); exclude = @() } }
      rules         = @(@{ type = 'creation' }, @{ type = 'deletion' }, @{ type = 'update' }, @{ type = 'non_fast_forward' })
   }
   $requests = @(
      @{ Method = 'PATCH'; Path = $root; Body = @{
            allow_squash_merge = $true; allow_merge_commit = $false; allow_rebase_merge = $false
            squash_merge_commit_title = 'PR_TITLE'; squash_merge_commit_message = 'PR_BODY'
            delete_branch_on_merge = $true; has_issues = $true; has_wiki = $false
            homepage              = "https://github.com/$Repository#readme"
            security_and_analysis = @{
               secret_scanning = @{ status = 'enabled' }; secret_scanning_push_protection = @{ status = 'enabled' }
            }
         }
      },
      @{ Method = 'PUT'; Path = "$root/private-vulnerability-reporting"; Body = @{}; Expected = @{ enabled = $true } },
      @{ Method = 'PUT'; Path = "$root/vulnerability-alerts"; Body = @{}; Expected = @{} },
      @{ Method = 'PUT'; Path = "$root/automated-security-fixes"; Body = @{}; Expected = @{ enabled = $true; paused = $false } },
      @{ Method = 'PUT'; Path = "$root/immutable-releases"; Body = @{}; Expected = @{ enabled = $true } },
      @{ Method = 'PUT'; Path = "$root/actions/permissions/workflow"; Body = @{ default_workflow_permissions = 'read'; can_approve_pull_request_reviews = $false } },
      @{ Method = 'PUT'; Path = "$root/actions/permissions/fork-pr-contributor-approval"; Body = @{ approval_policy = 'all_external_contributors' } },
      @{ Method = 'PUT'; Path = "$root/actions/permissions"; Body = @{ enabled = $true; allowed_actions = 'selected' } },
      @{ Method = 'PUT'; Path = "$root/actions/permissions/selected-actions"; Body = @{ github_owned_allowed = $true; verified_allowed = $true; patterns_allowed = @('KofTwentyTwo/standards/*@*') } },
      @{ Method = 'PUT'; Path = "$root/environments/release"; Body = @{ deployment_branch_policy = @{ protected_branches = $false; custom_branch_policies = $true } } },
      @{ Method = 'POST'; Path = "$root/environments/release/deployment-branch-policies"; Body = @{ name = 'v*'; type = 'tag' } },
      @{ Method = 'POST'; Path = "$root/rulesets"; Body = $main },
      @{ Method = 'POST'; Path = "$root/rulesets"; Body = $tags }
   )
   return @{ SchemaVersion = 1; Repository = $Repository; MaintainerCount = $MaintainerCount; Contexts = $contexts; Requests = $requests }
}



<#
.SYNOPSIS
Calls GitHub without printing authentication or including a token in argv.
#>
function Invoke-RepositoryApi
{
   [CmdletBinding()]
   [OutputType([hashtable], [System.Collections.IDictionary])]
   param([Parameter(Mandatory)] [string] $Path, [string] $Method = 'GET', [hashtable] $Body)

   $arguments = @('api', $Path, '--method', $Method, '-H', 'X-GitHub-Api-Version: 2022-11-28')
   if($null -ne $Body -and $Body.Count -gt 0)
   {
      $output = $Body | ConvertTo-Json -Depth 30 -Compress | & gh @arguments --input -
   }
   else
   {
      $output = & gh @arguments
   }
   if($LASTEXITCODE -ne 0)
   {
      throw "GitHub request failed: $Method $Path. No successful configuration is implied."
   }
   if($output)
   {
      return ($output -join "`n" | ConvertFrom-Json -AsHashtable)
   }
   return @{}
}



<#
.SYNOPSIS
Compares intended values while allowing unrelated object properties to remain.
#>
function Test-RepositoryValue
{
   [CmdletBinding()]
   [OutputType([bool])]
   param([AllowNull()] $Actual, [AllowNull()] $Expected)

   if($Expected -is [System.Collections.IDictionary])
   {
      if($Actual -isnot [System.Collections.IDictionary]) { return $false }
      foreach($key in $Expected.Keys)
      {
         if(-not $Actual.Contains($key) -or -not (Test-RepositoryValue $Actual[$key] $Expected[$key])) { return $false }
      }
      return $true
   }
   if($Expected -is [array])
   {
      if(@($Actual).Count -ne $Expected.Count) { return $false }
      foreach($item in $Expected)
      {
         if(-not (@($Actual | Where-Object { Test-RepositoryValue $_ $item }).Count -eq 1)) { return $false }
      }
      return $true
   }
   return $Actual -ceq $Expected
}



<#
.SYNOPSIS
Checks all setup prerequisites and preserves existing policy instead of replacing it.
#>
function Invoke-GitHubRepositorySetup
{
   [CmdletBinding(SupportsShouldProcess)]
   [OutputType([hashtable])]
   param(
      [Parameter(Mandatory)] [hashtable] $Plan,
      [ValidateSet('Validate', 'Apply')] [string] $Mode = 'Validate',
      [ValidatePattern('^[a-f0-9]{40}$')] [string] $CheckSha
   )

   # Never accept an arbitrary JSON request file as an administration program.
   $canonical = Get-GitHubRepositoryPlan -Repository $Plan.Repository -MaintainerCount $Plan.MaintainerCount
   if(-not (Test-RepositoryValue $Plan $canonical) -or -not (Test-RepositoryValue $canonical $Plan)) { throw 'Plan differs from the generated policy. Regenerate it.' }
   # Bind a fresh policy copy; the caller's reviewed offline plan must remain reusable.
   $Plan = $canonical
   $root = "repos/$($Plan.Repository)"
   $repositoryState = Invoke-RepositoryApi $root
   if($repositoryState.full_name -ine $Plan.Repository -or $repositoryState.private -or $repositoryState.default_branch -ne 'main')
   {
      throw 'Target must be the exact existing public repository with main already pushed.'
   }
   if(-not $repositoryState.permissions.admin) { throw 'Repository administration permission is required.' }
   $null = Invoke-RepositoryApi "$root/branches/main"
   $actionsApp = Invoke-RepositoryApi 'apps/github-actions'
   if($actionsApp -isnot [System.Collections.IDictionary] -or -not $actionsApp.Contains('slug') -or
      $actionsApp.slug -cne 'github-actions' -or -not $actionsApp.Contains('owner') -or
      $actionsApp.owner -isnot [System.Collections.IDictionary] -or -not $actionsApp.owner.Contains('login') -or
      $actionsApp.owner.login -cne 'github' -or -not $actionsApp.Contains('id') -or
      ($actionsApp.id -isnot [int] -and $actionsApp.id -isnot [long]) -or $actionsApp.id -le 0)
   {
      throw 'The trusted GitHub Actions application identity could not be verified.'
   }
   $checkRule = $Plan.Requests[-2].Body.rules | Where-Object type -EQ 'required_status_checks'
   foreach($check in $checkRule.parameters.required_status_checks) { $check.integration_id = $actionsApp.id }
   $repositorySecrets = Invoke-RepositoryApi "$root/actions/secrets?per_page=100"
   if($repositorySecrets.total_count -ne 0) { throw 'Move repository-level secrets to protected environments or OIDC before setup.' }
   $runners = Invoke-RepositoryApi "$root/actions/runners?per_page=100"
   if($runners.total_count -ne 0) { throw 'Remove self-hosted runner registrations before public repository setup.' }
   $rulesets = @(Invoke-RepositoryApi "$root/rulesets?includes_parents=true&per_page=100")
   if($rulesets.Count -ge 100) { throw 'Ruleset listing exceeds the supported setup scope. Review separately.' }
   $environments = Invoke-RepositoryApi "$root/environments?per_page=100"
   $releaseEnvironment = @($environments.environments | Where-Object name -EQ 'release')
   $policies = @()
   if($releaseEnvironment.Count -gt 0)
   {
      $policy = $releaseEnvironment[0].deployment_branch_policy
      if(-not $policy -or -not $policy.custom_branch_policies -or $policy.protected_branches)
      {
         throw 'Existing release environment is not custom tag restricted. Review it separately; no settings were changed.'
      }
      $policyResponse = Invoke-RepositoryApi "$root/environments/release/deployment-branch-policies?per_page=100"
      $policies = @($policyResponse.branch_policies)
      if(@($policies | Where-Object { $_.type -ne 'tag' -or $_.name -ne 'v*' }).Count -gt 0)
      {
         throw 'Existing release environment allows other refs. Preserve and review it separately.'
      }
   }
   $operations = [System.Collections.Generic.List[hashtable]]::new()
   foreach($request in $Plan.Requests)
   {
      $operation = @{} + $request
      if($request.Path -eq "$root/rulesets")
      {
         $existing = @($rulesets | Where-Object name -EQ $request.Body.name)
         if($existing.Count -gt 1) { throw "Multiple rulesets named $($request.Body.name)." }
         if($existing.Count -eq 1)
         {
            $detail = Invoke-RepositoryApi "$root/rulesets/$($existing[0].id)"
            if(-not (Test-RepositoryValue $detail $request.Body)) { throw "Existing $($request.Body.name) differs; no ruleset will be replaced." }
            continue
         }
      }
      elseif($request.Path.EndsWith('/deployment-branch-policies') -and $policies.Count -gt 0) { continue }
      elseif($request.Path.EndsWith('/environments/release') -and $releaseEnvironment.Count -gt 0) { continue }
      $operations.Add($operation)
   }
   if($Mode -eq 'Apply')
   {
      if(-not $CheckSha) { throw 'Apply requires the exact successful bootstrap PR CheckSha.' }
      $pulls = @(Invoke-RepositoryApi "$root/pulls?state=open&base=main&per_page=100")
      if(@($pulls | Where-Object { $_.head.sha -ceq $CheckSha }).Count -ne 1)
      {
         throw 'CheckSha must be the current head of one open bootstrap PR targeting main.'
      }
      $checks = Invoke-RepositoryApi "$root/commits/$CheckSha/check-runs?per_page=100"
      foreach($context in $Plan.Contexts)
      {
         $check = @($checks.check_runs | Where-Object { $_.name -ceq $context -and $_.app.slug -eq 'github-actions' -and $_.app.id -eq $actionsApp.id } |
               Sort-Object started_at -Descending | Select-Object -First 1)
         if($check.Count -ne 1 -or $check[0].conclusion -ne 'success') { throw "Bootstrap check not successful: $context. No settings were changed." }
      }
      foreach($operation in $operations)
      {
         if($PSCmdlet.ShouldProcess($Plan.Repository, "$($operation.Method) $($operation.Path)"))
         {
            $null = Invoke-RepositoryApi -Path $operation.Path -Method $operation.Method -Body $operation.Body
         }
      }
      if($WhatIfPreference) { return @{ Mode = 'Preview'; PendingRequests = $operations.Count } }
   }
   $problems = [System.Collections.Generic.List[string]]::new()
   foreach($request in $Plan.Requests)
   {
      if($request.Method -eq 'POST')
      {
         if($request.Path.EndsWith('/rulesets'))
         {
            $currentRules = @(Invoke-RepositoryApi "$root/rulesets?includes_parents=true&per_page=100")
            $existing = @($currentRules | Where-Object name -EQ $request.Body.name)
            if($existing.Count -ne 1) { $problems.Add("Missing unique $($request.Body.name)"); continue }
            $actual = Invoke-RepositoryApi "$root/rulesets/$($existing[0].id)"
            $expected = $request.Body
         }
         else
         {
            if($releaseEnvironment.Count -eq 0 -and $Mode -eq 'Validate') { $problems.Add('Missing release tag policy'); continue }
            $actual = Invoke-RepositoryApi "$root/environments/release/deployment-branch-policies?per_page=100"
            if(@($actual.branch_policies).Count -ne 1 -or -not (Test-RepositoryValue $actual.branch_policies[0] $request.Body))
            {
               $problems.Add('Release must permit only v* tags')
            }
            continue
         }
      }
      else
      {
         if($request.Path.EndsWith('/environments/release') -and $releaseEnvironment.Count -eq 0 -and $Mode -eq 'Validate')
         {
            $problems.Add('Missing release environment'); continue
         }
         $actual = Invoke-RepositoryApi $request.Path
         $expected = if($request.ContainsKey('Expected')) { $request.Expected } else { $request.Body }
      }
      if(-not (Test-RepositoryValue $actual $expected)) { $problems.Add("Configuration mismatch: $($request.Path)") }
   }
   $analyses = @(Invoke-RepositoryApi "$root/code-scanning/analyses?per_page=1")
   if($analyses.Count -eq 0) { $problems.Add('Code scanning has no successful published analysis') }
   if($problems.Count -gt 0) { throw ($problems -join "`n") }
   return @{ Mode = $Mode; Repository = $Plan.Repository; SettingsVerified = $true; RequiredContexts = $Plan.Contexts }
}

Export-ModuleMember -Function Get-GitHubRepositoryPlan, Invoke-GitHubRepositorySetup
