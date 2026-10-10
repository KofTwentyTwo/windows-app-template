#Requires -Version 7.4
# Copyright (c) 2026 James Maes (KofTwentyTwo)
# SPDX-License-Identifier: MIT

<#
.SYNOPSIS
Previews, validates or applies generated-repository GitHub controls.
.DESCRIPTION
Plan is offline and is the default. Apply requires an authorized administrator and
successful checks on the bootstrap PR SHA. Existing conflicting protections are
preserved. This tool never creates a repository, pushes code, merges or publishes.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
   [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9-]*/[A-Za-z0-9_.-]+$')] [string] $Repository = 'KofTwentyTwo/windows-app-template',
   [ValidateSet('Plan', 'Validate', 'Apply')] [string] $Mode = 'Plan',
   [ValidateRange(1, 100)] [int] $MaintainerCount = 1,
   [ValidatePattern('^[a-f0-9]{40}$')] [string] $CheckSha,
   [string] $OutputPath = 'artifacts/repository-setup.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'GitHubRepository.psm1') -Force
$plan = Get-GitHubRepositoryPlan -Repository $Repository -MaintainerCount $MaintainerCount
if($Mode -eq 'Plan')
{
   $OutputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
   if($PSCmdlet.ShouldProcess($OutputPath, 'Write non-secret GitHub configuration plan'))
   {
      $parent = Split-Path $OutputPath -Parent
      New-Item -ItemType Directory -Force -Path $parent | Out-Null
      $plan | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $OutputPath -Encoding utf8NoBOM
   }
   return
}
$setupArguments = @{ Plan = $plan; Mode = $Mode; WhatIf = $WhatIfPreference }
if($CheckSha) { $setupArguments.CheckSha = $CheckSha }
Invoke-GitHubRepositorySetup @setupArguments
