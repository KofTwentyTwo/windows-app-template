#Requires -Version 7.4
# Copyright (c) 2026 James Maes
# SPDX-License-Identifier: MIT

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

BeforeAll `
{
   $script:Preflight = Join-Path $PSScriptRoot 'Assert-ReleaseSigning.ps1'
   # Fixtures remain valid after an owner enables signing in the actual caller.
   $script:Caller = "jobs:`n  release:`n    with:`n      sign: false`n"
   $script:Settings = @{
      AZURE_CLIENT_ID           = '11111111-1111-4111-8111-111111111111'
      AZURE_TENANT_ID           = '22222222-2222-4222-8222-222222222222'
      AZURE_SUBSCRIPTION_ID     = '33333333-3333-4333-8333-333333333333'
      ARTIFACT_SIGNING_ENDPOINT = 'https://eus.codesigning.azure.net'
      ARTIFACT_SIGNING_ACCOUNT  = 'example-signing'
      ARTIFACT_SIGNING_PROFILE  = 'releases'
      ARTIFACT_SIGNING_SUBJECT  = 'CN=Verified Example Publisher'
   }
   $script:OldSettings = @{}
   foreach($name in $script:Settings.Keys) { $script:OldSettings[$name] = [Environment]::GetEnvironmentVariable($name) }
}

AfterAll `
{
   foreach($name in $script:OldSettings.Keys) { [Environment]::SetEnvironmentVariable($name, $script:OldSettings[$name]) }
}

Describe 'Application release signing preflight' `
{
   BeforeEach `
   {
      foreach($name in $script:Settings.Keys) { [Environment]::SetEnvironmentVariable($name, $script:Settings[$name]) }
      $script:Workflow = Join-Path $TestDrive 'release.yml'
      $script:EnabledCaller = $script:Caller -replace '(?m)^      sign: false.*$', "      sign: true`n      signing-files: |`n        app/Kof22App.dll"
      Set-Content -LiteralPath $script:Workflow -Value $script:EnabledCaller
   }

   It 'accepts complete configuration without contacting Azure' `
   {
      { & $script:Preflight -WorkflowPath $script:Workflow } | Should -Not -Throw
   }

   It 'blocks an unsigned caller even when environment variables are present' `
   {
      Set-Content -LiteralPath $script:Workflow -Value $script:Caller
      { & $script:Preflight -WorkflowPath $script:Workflow } | Should -Throw '*Release signing is required*'
   }

   It 'blocks signing without an explicit owned-file catalog' `
   {
      Set-Content -LiteralPath $script:Workflow -Value ($script:Caller -replace '(?m)^      sign: false.*$', '      sign: true')
      { & $script:Preflight -WorkflowPath $script:Workflow } | Should -Throw '*explicit signing-files catalog*'
   }

   It 'blocks an empty owned-file catalog' `
   {
      Set-Content -LiteralPath $script:Workflow -Value ($script:EnabledCaller -replace '(?m)^        app/.*$', '')
      { & $script:Preflight -WorkflowPath $script:Workflow } | Should -Throw '*explicit signing-files catalog*'
   }

   It 'blocks a missing publisher subject before release work starts' `
   {
      $env:ARTIFACT_SIGNING_SUBJECT = ''
      { & $script:Preflight -WorkflowPath $script:Workflow } | Should -Throw '*Missing verified signing variable: ARTIFACT_SIGNING_SUBJECT*'
   }

   It 'does not accept a directory domain as the tenant GUID' `
   {
      $env:AZURE_TENANT_ID = 'example.onmicrosoft.com'
      { & $script:Preflight -WorkflowPath $script:Workflow } | Should -Throw '*Invalid signing identifier: AZURE_TENANT_ID*'
   }

   It 'rejects an empty client identifier' `
   {
      $env:AZURE_CLIENT_ID = [guid]::Empty.ToString()
      { & $script:Preflight -WorkflowPath $script:Workflow } | Should -Throw '*Invalid signing identifier: AZURE_CLIENT_ID*'
   }

   It 'rejects an unrelated endpoint that must not receive signing requests' `
   {
      $env:ARTIFACT_SIGNING_ENDPOINT = 'https://example.com'
      { & $script:Preflight -WorkflowPath $script:Workflow } | Should -Throw '*endpoint must use HTTPS*'
   }

   It 'rejects an unencrypted signing endpoint' `
   {
      $env:ARTIFACT_SIGNING_ENDPOINT = 'http://eus.codesigning.azure.net'
      { & $script:Preflight -WorkflowPath $script:Workflow } | Should -Throw '*endpoint must use HTTPS*'
   }
}
