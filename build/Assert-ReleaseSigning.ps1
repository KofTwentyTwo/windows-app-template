#Requires -Version 7.4
# Copyright (c) 2026 James Maes
# SPDX-License-Identifier: MIT
<#
.SYNOPSIS
Rejects application release publication without explicit signing and required configuration.
.DESCRIPTION
Checks the reviewed caller and protected-environment variables before running release gates.
This is configuration validation, not proof of Azure access or a valid signature.
#>
[CmdletBinding()]
param(
   [string]$WorkflowPath = (Join-Path $PSScriptRoot '../.github/workflows/release.yml')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$workflow = Get-Content -LiteralPath $WorkflowPath -Raw
if($workflow -notmatch '(?m)^[ \t]+sign:[ \t]+true(?:[ \t]+#.*)?[ \t]*\r?$')
{
   throw 'Release signing is required. Publish and pin the reviewed signing builder, configure sign: true and its owned-file catalog. See docs/release-signing.md.'
}
if($workflow -notmatch '(?m)^([ \t]+)signing-files:[ \t]*\|[ \t]*\r?\n\1[ \t]+[^#\s]')
{
   throw 'Release signing requires an explicit signing-files catalog. See docs/release-signing.md.'
}
$guidVariables = @('AZURE_CLIENT_ID', 'AZURE_TENANT_ID', 'AZURE_SUBSCRIPTION_ID')
foreach($name in @($guidVariables) + @('ARTIFACT_SIGNING_ENDPOINT', 'ARTIFACT_SIGNING_ACCOUNT', 'ARTIFACT_SIGNING_PROFILE', 'ARTIFACT_SIGNING_SUBJECT'))
{
   $value = [Environment]::GetEnvironmentVariable($name)
   if([string]::IsNullOrWhiteSpace($value)) { throw "Missing verified signing variable: $name" }
   if($name -in $guidVariables)
   {
      $identifier = [guid]::Empty
      if(-not [guid]::TryParseExact($value, 'D', [ref]$identifier) -or $identifier -eq [guid]::Empty) { throw "Invalid signing identifier: $name" }
   }
}
$endpoint = $null
if(-not [uri]::TryCreate($env:ARTIFACT_SIGNING_ENDPOINT, [UriKind]::Absolute, [ref]$endpoint) -or $endpoint.Scheme -ne 'https' -or -not $endpoint.Host.EndsWith('.codesigning.azure.net', [StringComparison]::OrdinalIgnoreCase))
{
   throw 'The verified Artifact Signing endpoint must use HTTPS on codesigning.azure.net.'
}
Write-Output 'Windows release signing configuration is present; Azure access and final signatures still require verification.'
