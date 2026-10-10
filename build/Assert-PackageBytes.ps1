#Requires -Version 7.4
# Copyright (c) 2026 James Maes
# SPDX-License-Identifier: MIT
<#
.SYNOPSIS
Verifies the published runtime payload is preserved in Velopack portable and full packages.
.DESCRIPTION
Compares every non-PDB publish file except Velopack's documented default exclusions.
Checks original files, not generated launchers or manifest additions; does not verify signatures.
#>
[CmdletBinding()]
param(
   [Parameter(Mandatory)] [string]$PublishDirectory,
   [Parameter(Mandatory)] [string]$PortableArchive,
   [Parameter(Mandatory)] [string]$FullPackage
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$source = (Get-Item -LiteralPath $PublishDirectory).FullName
$files = @(Get-ChildItem -LiteralPath $source -File -Recurse | Where-Object {
      $_.Extension -ne '.pdb' -and $_.FullName -notmatch '[\\/]createdump[^\\/]*|\.vshost\.|\.nupkg$'
   })
if($files.Count -eq 0) { throw 'Publish payload is empty.' }
foreach($specification in @(@{ path = $PortableArchive; prefix = 'current/' }, @{ path = $FullPackage; prefix = 'lib/app/' }))
{
   $archive = [IO.Compression.ZipFile]::OpenRead((Get-Item -LiteralPath $specification.path).FullName)
   try
   {
      foreach($file in $files)
      {
         $relative = [IO.Path]::GetRelativePath($source, $file.FullName).Replace('\', '/')
         $entry = $archive.GetEntry($specification.prefix + $relative)
         if($null -eq $entry) { throw "Package omits published file: $relative ($($specification.path))" }
         $stream = $entry.Open()
         try { $actual = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($stream)) }
         finally { $stream.Dispose() }
         $expected = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
         if($actual -ne $expected) { throw "Package changed published bytes: $relative ($($specification.path))" }
      }
   }
   finally { $archive.Dispose() }
}
Write-Output "Verified $($files.Count) published files in both Velopack payloads."
