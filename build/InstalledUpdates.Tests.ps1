#Requires -Version 7.4
# Copyright (c) 2026 James Maes
# SPDX-License-Identifier: MIT

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Describe 'Installed update smoke boundaries' `
{
   BeforeAll `
   {
      $script:SmokeHarness = Join-Path $PSScriptRoot 'Test-InstalledUpdates.ps1'
      $script:SmokeArtifacts = Join-Path (Split-Path -Parent $PSScriptRoot) 'artifacts'
      $script:SmokeAppId = [regex]::Match((Get-Content -LiteralPath (Join-Path (Split-Path -Parent $PSScriptRoot) 'src/Kof22App.Core/AppIdentity.cs') -Raw), '(?m)^\s*Id\s*=\s*"([a-z0-9][a-z0-9-]*)"').Groups[1].Value
   }

   It 'refuses output outside the repository artifact boundary before running tools' `
   {
      { & $script:SmokeHarness -OutputDirectory (Join-Path $TestDrive 'outside') } | Should -Throw '*inside this repository artifacts*'
      Join-Path $TestDrive 'outside' | Should -Not -Exist
   }

   It 'refuses an identity mismatch that would fail to isolate the real user profile' `
   {
      $output = Join-Path $script:SmokeArtifacts ('identity-rejected-' + [guid]::NewGuid().ToString('N'))
      { & $script:SmokeHarness -AppId 'incorrect-smoke-identity' -OutputDirectory $output } | Should -Throw '*AppId must match*'
      $output | Should -Not -Exist
   }

   It 'refuses existing output instead of overwriting or consuming stale results' `
   {
      $output = Join-Path $script:SmokeArtifacts ('existing-rejected-' + [guid]::NewGuid().ToString('N'))
      New-Item -ItemType Directory -Path $output | Out-Null
      try
      {
         { & $script:SmokeHarness -AppId $script:SmokeAppId -VpkPath (Get-Command dotnet -CommandType Application).Source -OutputDirectory $output } | Should -Throw '*fresh smoke output*'
         @(Get-ChildItem -LiteralPath $output).Count | Should -Be 0
      }
      finally { Remove-Item -LiteralPath $output }
   }
}
