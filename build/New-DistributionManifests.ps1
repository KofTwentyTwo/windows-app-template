#Requires -Version 7.4
# Copyright (c) 2026 James Maes (KofTwentyTwo)
# SPDX-License-Identifier: MIT

<#
.SYNOPSIS
Generates optional stable Scoop and Chocolatey manifests from final release bytes.
.DESCRIPTION
Accepts a final x64 ZIP; checks its layout and hashes the actual bytes. No network,
credentials or publishing are involved. Package managers own portable updates.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
   [Parameter(Mandatory)] [ValidatePattern('^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$')] [string] $Version,
   [Parameter(Mandatory)] [string] $ArtifactPath,
   [ValidateSet('Cli', 'Portable')] [string] $ArtifactKind = 'Portable',
   [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9-]*/[A-Za-z0-9_.-]+$')] [string] $Repository = 'KofTwentyTwo/windows-app-template',
   [ValidatePattern('^[a-z][a-z0-9-]*$')] [string] $AppId = 'kof22-app',
   [ValidatePattern('^[A-Za-z0-9_.-]+\.exe$')] [string] $MainExe = 'Kof22App.exe',
   [string] $DisplayName = 'Kof22 App',
   [string] $Description = 'A KofTwentyTwo Windows desktop application.',
   [string] $Author = 'James Maes',
   [string] $OutputDirectory = 'artifacts/distribution'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$artifact = Get-Item -LiteralPath $ArtifactPath
$executable = if($ArtifactKind -eq 'Cli') { "$AppId.exe" } else { $MainExe }
$assetName = $artifact.Name
if($ArtifactKind -eq 'Cli' -and $assetName -cne "$AppId-cli-win-x64-$Version.zip")
{
   throw 'CLI asset name does not match the app identity and stable version.'
}
if($ArtifactKind -eq 'Portable' -and $assetName -cne "$AppId-stable-Portable.zip")
{
   throw 'Portable asset name does not match the stable Windows release asset.'
}
$archive = [IO.Compression.ZipFile]::OpenRead($artifact.FullName)
try
{
   $entries = @($archive.Entries | ForEach-Object { $_.FullName.Replace('\', '/') })
   if(@($entries | Where-Object { $_ -match '(^/|^[A-Za-z]:|(^|/)\.\.(/|$))' }).Count -gt 0)
   {
      throw 'Archive contains an unsafe path.'
   }
   if(@($entries | Where-Object { $_ -ceq $executable }).Count -ne 1)
   {
      throw "Release archive must contain exactly one root $executable."
   }
}
finally
{
   $archive.Dispose()
}
$sha256 = (Get-FileHash -LiteralPath $artifact.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
$homepage = "https://github.com/$Repository"
$url = "$homepage/releases/download/v$Version/$assetName"
$packageId = if($ArtifactKind -eq 'Cli') { "$AppId-cli" } else { "$AppId-portable" }
$scoop = [ordered]@{
   version = $Version; description = $Description; homepage = $homepage; license = 'MIT'
   architecture = @{ '64bit' = @{ url = $url; hash = $sha256 } }
   notes        = 'Portable distribution: use this package manager to update; Velopack self-update is unavailable.'
}
if($ArtifactKind -eq 'Cli') { $scoop.bin = $executable }
else { $scoop.shortcuts = , @($executable, $DisplayName) }

# Serialize text as data for both XML and PowerShell; never interpolate raw metadata as code.
$xmlValues = @{}
foreach($pair in @{ id = $packageId; version = $Version; title = $DisplayName; authors = $Author; description = $Description; homepage = $homepage }.GetEnumerator())
{
   $xmlValues[$pair.Key] = [Security.SecurityElement]::Escape($pair.Value)
}
$nuspec = @"
<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://schemas.microsoft.com/packaging/2015/06/nuspec.xsd">
  <metadata>
    <id>$($xmlValues.id)</id>
    <version>$($xmlValues.version)</version>
    <title>$($xmlValues.title)</title>
    <authors>$($xmlValues.authors)</authors>
    <description>$($xmlValues.description)</description>
    <projectUrl>$($xmlValues.homepage)</projectUrl>
    <licenseUrl>$($xmlValues.homepage)/blob/main/LICENSE</licenseUrl>
    <requireLicenseAcceptance>false</requireLicenseAcceptance>
    <releaseNotes>$($xmlValues.homepage)/releases/tag/v$Version</releaseNotes>
    <tags>windows portable $ArtifactKind</tags>
  </metadata>
  <files><file src="tools\**" target="tools" /></files>
</package>
"@
$install = @'
# Copyright (c) 2026 James Maes (KofTwentyTwo)
# SPDX-License-Identifier: MIT
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$toolsDirectory = Split-Path -Parent $MyInvocation.MyCommand.Definition
$destination = Join-Path $toolsDirectory 'app'
$packageArguments = @{
   packageName = '__PACKAGE__'
   unzipLocation = $destination
   url64bit = '__URL__'
   checksum64 = '__HASH__'
   checksumType64 = 'sha256'
}
Install-ChocolateyZipPackage @packageArguments
$mainExecutable = Join-Path $destination '__EXE__'
foreach($binary in Get-ChildItem -LiteralPath $destination -Recurse -Filter '*.exe')
{
   if($binary.FullName -ne $mainExecutable)
   {
      New-Item -ItemType File -Force -Path "$($binary.FullName).ignore" | Out-Null
   }
}
'@
$install = $install.Replace('__PACKAGE__', $packageId).Replace('__URL__', $url.Replace("'", "''")).Replace('__HASH__', $sha256).Replace('__EXE__', $executable)
$OutputDirectory = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputDirectory)
if($PSCmdlet.ShouldProcess($OutputDirectory, "Generate $packageId $Version manifests from SHA256 $sha256"))
{
   $bucket = Join-Path $OutputDirectory 'bucket'
   $chocolatey = Join-Path $OutputDirectory "chocolatey/$packageId"
   $toolsDirectory = Join-Path $chocolatey 'tools'
   New-Item -ItemType Directory -Force -Path $bucket, $toolsDirectory | Out-Null
   $scoop | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $bucket "$packageId.json") -Encoding utf8NoBOM
   [IO.File]::WriteAllText((Join-Path $chocolatey "$packageId.nuspec"), $nuspec + "`n", [Text.UTF8Encoding]::new($false))
   [IO.File]::WriteAllText((Join-Path $toolsDirectory 'chocolateyinstall.ps1'), $install + "`n", [Text.UTF8Encoding]::new($false))
   Copy-Item -LiteralPath (Join-Path $PSScriptRoot '../LICENSE') -Destination (Join-Path $toolsDirectory 'LICENSE.txt')
}
