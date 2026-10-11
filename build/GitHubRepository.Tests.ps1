#Requires -Version 7.4
# Copyright (c) 2026 James Maes (KofTwentyTwo)
# SPDX-License-Identifier: MIT

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'GitHubRepository.psm1') -Force

Describe 'Offline setup preview location' `
{
   It 'writes relative output beneath the current PowerShell location' `
   {
      $setupScript = Join-Path $PSScriptRoot 'Initialize-GitHubRepository.ps1'
      Push-Location $TestDrive
      try
      {
         & $setupScript -Repository 'Example/Notes'
         $plan = Get-Content -LiteralPath (Join-Path $TestDrive 'artifacts/repository-setup.json') -Raw | ConvertFrom-Json
         $plan.Repository | Should -Be 'Example/Notes'
         $plan.Requests.Count | Should -Be 13
      }
      finally
      {
         Pop-Location
      }
   }
}

Describe 'Required checks match standalone workflow jobs' `
{
   It 'requires the actual check names from both CI and script workflows' `
   {
      $plan = Get-GitHubRepositoryPlan -Repository 'Example/Notes'
      $workflowRoot = Join-Path (Split-Path -Parent $PSScriptRoot) '.github/workflows'
      foreach($workflow in @('ci.yml', 'scripts.yml'))
      {
         $names = @(Select-String -LiteralPath (Join-Path $workflowRoot $workflow) -Pattern '^    name: ')
         $names.Count | Should -BeGreaterThan 0
         foreach($name in $names)
         {
            $plan.Contexts | Should -Contain $name.Line.Trim().Substring('name: '.Length)
         }
      }
   }
}

Describe 'Generated repository administration' `
{
   InModuleScope GitHubRepository `
   {
      BeforeEach `
      {
         $script:Plan = Get-GitHubRepositoryPlan -Repository 'Example/Notes'
         $script:Root = 'repos/Example/Notes'
         $script:Writes = [System.Collections.Generic.List[string]]::new()
         $script:State = @{
            'apps/github-actions'                                      = @{ id = 15368; slug = 'github-actions'; owner = @{ login = 'github' } }
            $script:Root                                               = @{ full_name = 'Example/Notes'; private = $false; default_branch = 'main'; permissions = @{ admin = $true } }
            "$script:Root/rulesets?includes_parents=true&per_page=100" = @()
            "$script:Root/environments?per_page=100"                   = @{ environments = @() }
         }
         $script:Checks = @($script:Plan.Contexts | ForEach-Object {
               @{ name = $_; conclusion = 'success'; started_at = '2026-01-01'; app = @{ slug = 'github-actions'; id = 15368 } }
            })
         $script:State["$script:Root/branches/main"] = @{ name = 'main' }
         $script:State["$script:Root/actions/secrets?per_page=100"] = @{ total_count = 0; secrets = @() }
         $script:State["$script:Root/actions/runners?per_page=100"] = @{ total_count = 0; runners = @() }
         $script:State["$script:Root/pulls?state=open&base=main&per_page=100"] = @(@{ head = @{ sha = ('a' * 40) } })
         $script:State["$script:Root/code-scanning/analyses?per_page=1"] = @(@{ id = 1 })
         Mock Invoke-RepositoryApi `
         {
            if(-not $Method) { $Method = 'GET' }
            if($Path -match '/commits/.+/check-runs') { return @{ check_runs = $script:Checks } }
            if($Method -eq 'GET')
            {
               if(-not $script:State.ContainsKey($Path)) { throw "Fixture has no response: $Path" }
               return $script:State[$Path]
            }
            $script:Writes.Add("$Method $Path")
            if($Path.EndsWith('/rulesets'))
            {
               $id = 100 + $script:Writes.Count
               $script:State["$script:Root/rulesets?includes_parents=true&per_page=100"] += @(@{ name = $Body.name; id = $id })
               $script:State["$script:Root/rulesets/$id"] = $Body
            }
            elseif($Path.EndsWith('/deployment-branch-policies'))
            {
               $script:State["$Path`?per_page=100"] = @{ branch_policies = @($Body) }
            }
            elseif($Path.EndsWith('/environments/release'))
            {
               $script:State[$Path] = $Body
               $script:State["$script:Root/environments?per_page=100"] = @{ environments = @(@{ name = 'release'; deployment_branch_policy = $Body.deployment_branch_policy }) }
            }
            elseif($Path -eq $script:Root)
            {
               foreach($key in $Body.Keys) { $script:State[$Path][$key] = $Body[$key] }
            }
            elseif($Path.EndsWith('/private-vulnerability-reporting')) { $script:State[$Path] = @{ enabled = $true } }
            elseif($Path.EndsWith('/automated-security-fixes')) { $script:State[$Path] = @{ enabled = $true; paused = $false } }
            elseif($Path.EndsWith('/immutable-releases')) { $script:State[$Path] = @{ enabled = $true } }
            else { $script:State[$Path] = $Body }
            return @{}
         }
      }

      It 'builds a single-maintainer plan with review, scoped tags and no main bypass' `
      {
         $script:Plan.Contexts | Should -Contain 'review / automated'
         $script:Plan.Requests[-2].Body.bypass_actors.Count | Should -Be 0
         $script:Plan.Requests[-2].Body.rules[4].parameters.required_approving_review_count | Should -Be 0
         $script:Plan.Requests[-3].Body.type | Should -Be 'tag'
         $script:Writes.Count | Should -Be 0
      }

      It 'requires independent approval when more than one maintainer exists' `
      {
         $plan = Get-GitHubRepositoryPlan -Repository 'Example/Notes' -MaintainerCount 2
         $plan.Contexts | Should -Not -Contain 'review / automated'
         $plan.Requests[-2].Body.rules[4].parameters.required_approving_review_count | Should -Be 1
         $plan.Requests[-2].Body.rules[4].parameters.require_last_push_approval | Should -BeTrue
      }

      It 'applies and reads back all settings without recreating policies on a second run' `
      {
         $result = Invoke-GitHubRepositorySetup -Plan $script:Plan -Mode Apply -CheckSha ('a' * 40) -Confirm:$false
         $result.SettingsVerified | Should -BeTrue
         $script:Writes.Count | Should -Be 13
         $main = $script:State["$script:Root/rulesets?includes_parents=true&per_page=100"] | Where-Object name -EQ 'protect-main'
         $script:State["$script:Root/rulesets/$($main.id)"].rules[-1].parameters.required_status_checks[0].integration_id | Should -Be 15368
         $script:Writes.Clear()
         $newPlan = Get-GitHubRepositoryPlan -Repository 'Example/Notes'
         Invoke-GitHubRepositorySetup -Plan $newPlan -Mode Apply -CheckSha ('a' * 40) -Confirm:$false
         @($script:Writes | Where-Object { $_ -match 'POST|environments/release$' }).Count | Should -Be 0
      }

      It 'requires community Discussions and detects disabled support without writing' `
      {
         Invoke-GitHubRepositorySetup -Plan $script:Plan -Mode Apply -CheckSha ('a' * 40) -Confirm:$false
         $script:State[$script:Root].has_discussions | Should -BeTrue
         $script:State[$script:Root].has_discussions = $false
         $script:Writes.Clear()
         { Invoke-GitHubRepositorySetup -Plan $script:Plan -Mode Validate } | Should -Throw '*Configuration mismatch: repos/Example/Notes*'
         $script:Writes.Count | Should -Be 0
      }

      It 'previews all mutations without writing' `
      {
         Invoke-GitHubRepositorySetup -Plan $script:Plan -Mode Apply -CheckSha ('a' * 40) -WhatIf
         $script:Writes.Count | Should -Be 0
      }

      It 'rejects <Binding> required-check application binding during read-only validation' -ForEach @(
         @{ Binding = 'incorrect' }, @{ Binding = 'missing' }
      ) `
      {
         Invoke-GitHubRepositorySetup -Plan $script:Plan -Mode Apply -CheckSha ('a' * 40) -Confirm:$false
         $main = $script:State["$script:Root/rulesets?includes_parents=true&per_page=100"] | Where-Object name -EQ 'protect-main'
         $check = $script:State["$script:Root/rulesets/$($main.id)"].rules[-1].parameters.required_status_checks[0]
         if($Binding -eq 'missing') { $check.Remove('integration_id') } else { $check.integration_id = 777 }
         $script:Writes.Clear()
         $plan = Get-GitHubRepositoryPlan -Repository 'Example/Notes'
         { Invoke-GitHubRepositorySetup -Plan $plan -Mode Validate } | Should -Throw '*protect-main*'
         $script:Writes.Count | Should -Be 0
      }

      It 'preserves the caller plan and validates correct bindings without writing' `
      {
         $original = $script:Plan | ConvertTo-Json -Depth 30 -Compress
         Invoke-GitHubRepositorySetup -Plan $script:Plan -Mode Apply -CheckSha ('a' * 40) -Confirm:$false
         ($script:Plan | ConvertTo-Json -Depth 30 -Compress) | Should -Be $original
         $script:Writes.Clear()
         $result = Invoke-GitHubRepositorySetup -Plan $script:Plan -Mode Validate
         $result.SettingsVerified | Should -BeTrue
         $script:Writes.Count | Should -Be 0
      }

      It 'rejects an invalid GitHub Actions application identity: <Invalid>' -ForEach @(
         @{ Invalid = 'owner' }, @{ Invalid = 'slug' }, @{ Invalid = 'missing id' }, @{ Invalid = 'zero id' }
      ) `
      {
         $app = $script:State['apps/github-actions']
         switch($Invalid)
         {
            'owner' { $app.owner.login = 'untrusted' }
            'slug' { $app.slug = 'other-actions' }
            'missing id' { $app.Remove('id') }
            'zero id' { $app.id = 0 }
         }
         { Invoke-GitHubRepositorySetup -Plan $script:Plan -Mode Apply -CheckSha ('a' * 40) } | Should -Throw '*trusted GitHub Actions application identity*'
         $script:Writes.Count | Should -Be 0
      }

      It 'rejects a bootstrap check from a different application before writing' `
      {
         $script:Checks[0].app.id = 777
         { Invoke-GitHubRepositorySetup -Plan $script:Plan -Mode Apply -CheckSha ('a' * 40) } | Should -Throw '*Bootstrap check not successful*'
         $script:Writes.Count | Should -Be 0
      }

      It 'rejects a changed target repository before writing' `
      {
         $script:State[$script:Root].full_name = 'Other/Notes'
         { Invoke-GitHubRepositorySetup -Plan $script:Plan -Mode Apply -CheckSha ('a' * 40) } | Should -Throw '*exact existing public repository*'
         $script:Writes.Count | Should -Be 0
      }

      It 'rejects plan changes including unexpected nested settings' `
      {
         $script:Plan.Requests[0].Body.private = $true
         { Invoke-GitHubRepositorySetup -Plan $script:Plan -Mode Apply -CheckSha ('a' * 40) } | Should -Throw '*differs*'
         $script:Writes.Count | Should -Be 0
      }

      It 'requires successful bootstrap checks before writing' `
      {
         $script:Checks[-1].conclusion = 'failure'
         { Invoke-GitHubRepositorySetup -Plan $script:Plan -Mode Apply -CheckSha ('a' * 40) } | Should -Throw '*review / automated*'
         $script:Writes.Count | Should -Be 0
      }

      It 'rejects existing conflicting main protection before writing' `
      {
         $script:State["$script:Root/rulesets?includes_parents=true&per_page=100"] = @(@{ name = 'protect-main'; id = 1 })
         $script:State["$script:Root/rulesets/1"] = @{ name = 'protect-main'; enforcement = 'disabled' }
         { Invoke-GitHubRepositorySetup -Plan $script:Plan -Mode Apply -CheckSha ('a' * 40) } | Should -Throw '*will be replaced*'
         $script:Writes.Count | Should -Be 0
      }

      It 'preserves a release environment that allows branch deployments' `
      {
         $script:State["$script:Root/environments?per_page=100"] = @{ environments = @(@{ name = 'release'; deployment_branch_policy = @{ protected_branches = $true; custom_branch_policies = $false } }) }
         { Invoke-GitHubRepositorySetup -Plan $script:Plan -Mode Apply -CheckSha ('a' * 40) } | Should -Throw '*not custom tag restricted*'
         $script:Writes.Count | Should -Be 0
      }

      It 'rejects a stale bootstrap PR commit before writing' `
      {
         $script:State["$script:Root/pulls?state=open&base=main&per_page=100"][0].head.sha = 'b' * 40
         { Invoke-GitHubRepositorySetup -Plan $script:Plan -Mode Apply -CheckSha ('a' * 40) } | Should -Throw '*current head*'
         $script:Writes.Count | Should -Be 0
      }

      It 'rejects repository secrets before changing policy' `
      {
         $script:State["$script:Root/actions/secrets?per_page=100"].total_count = 1
         { Invoke-GitHubRepositorySetup -Plan $script:Plan -Mode Apply -CheckSha ('a' * 40) } | Should -Throw '*repository-level secrets*'
         $script:Writes.Count | Should -Be 0
      }

      It 'reports missing settings in validation without changing them' `
      {
         foreach($request in $script:Plan.Requests | Where-Object Method -NE 'POST')
         {
            if($request.Path -ne $script:Root) { $script:State[$request.Path] = @{} }
         }
         { Invoke-GitHubRepositorySetup -Plan $script:Plan -Mode Validate } | Should -Throw '*Missing unique protect-main*'
         $script:Writes.Count | Should -Be 0
      }
   }
}
