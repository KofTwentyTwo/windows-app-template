#Requires -Version 7.4
# Copyright (c) 2026 James Maes (KofTwentyTwo)
# SPDX-License-Identifier: MIT

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

BeforeAll `
{
   $script:Generator = Join-Path $PSScriptRoot 'New-DistributionManifests.ps1'
   <#
   .SYNOPSIS
   Registers the package-manager API for a test double without network or installs.
   #>
   function Install-ChocolateyZipPackage
   {
      param($PackageName, $UnzipLocation, $Url64bit, $Checksum64, $ChecksumType64)
      throw "Missing Chocolatey test double: $PackageName at $UnzipLocation from $Url64bit ($ChecksumType64 $Checksum64)."
   }
}

Describe 'Optional distribution boundaries' `
{
   BeforeEach `
   {
      $script:Root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
      New-Item -ItemType Directory -Path $script:Root | Out-Null
      $script:Output = Join-Path $script:Root 'output'
      $script:Artifact = Join-Path $script:Root 'notes-cli-win-x64-1.2.3.zip'
      $archive = [IO.Compression.ZipFile]::Open($script:Artifact, [IO.Compression.ZipArchiveMode]::Create)
      try
      {
         $entry = $archive.CreateEntry('notes.exe')
         $writer = [IO.StreamWriter]::new($entry.Open())
         $writer.Write('fixture bytes, never executed')
         $writer.Dispose()
      }
      finally { $archive.Dispose() }
   }

   It 'uses the actual final bytes, generated identities and stable release URL' `
   {
      & $script:Generator -Version 1.2.3 -ArtifactPath $script:Artifact -ArtifactKind Cli -AppId notes -Repository 'Example/Notes' -DisplayName 'Notes & More' -OutputDirectory $script:Output
      $manifest = Get-Content "$script:Output/bucket/notes-cli.json" -Raw | ConvertFrom-Json
      $manifest.architecture.'64bit'.hash | Should -Be (Get-FileHash $script:Artifact -Algorithm SHA256).Hash.ToLowerInvariant()
      $manifest.architecture.'64bit'.url | Should -Be 'https://github.com/Example/Notes/releases/download/v1.2.3/notes-cli-win-x64-1.2.3.zip'
      $manifest.bin | Should -Be 'notes.exe'
      $spec = [xml](Get-Content "$script:Output/chocolatey/notes-cli/notes-cli.nuspec" -Raw)
      $spec.package.metadata.title | Should -Be 'Notes & More'
      $spec.package.metadata.id | Should -Be 'notes-cli'
      Test-Path "$script:Output/chocolatey/notes-cli/tools/LICENSE.txt" | Should -BeTrue
   }

   It 'refuses prerelease versions before writing any manifests' `
   {
      { & $script:Generator -Version '1.2.3-beta.1' -ArtifactPath $script:Artifact -OutputDirectory $script:Output } | Should -Throw
      Test-Path $script:Output | Should -BeFalse
   }

   It 'refuses mismatched version or app identity' `
   {
      { & $script:Generator -Version 1.2.4 -ArtifactPath $script:Artifact -ArtifactKind Cli -AppId notes -OutputDirectory $script:Output } | Should -Throw '*does not match*'
      Test-Path $script:Output | Should -BeFalse
   }

   It 'rejects traversal inside an archive before writing' `
   {
      $archive = [IO.Compression.ZipFile]::Open($script:Artifact, [IO.Compression.ZipArchiveMode]::Update)
      try { $null = $archive.CreateEntry('../outside.exe') } finally { $archive.Dispose() }
      { & $script:Generator -Version 1.2.3 -ArtifactPath $script:Artifact -ArtifactKind Cli -AppId notes -OutputDirectory $script:Output } | Should -Throw '*unsafe path*'
      Test-Path $script:Output | Should -BeFalse
   }

   It 'does not write during WhatIf' `
   {
      & $script:Generator -Version 1.2.3 -ArtifactPath $script:Artifact -ArtifactKind Cli -AppId notes -OutputDirectory $script:Output -WhatIf
      Test-Path $script:Output | Should -BeFalse
   }

   It 'supports GUI-only portable archives without requiring a CLI' `
   {
      $portable = Join-Path $script:Root 'notes-stable-Portable.zip'
      $archive = [IO.Compression.ZipFile]::Open($portable, [IO.Compression.ZipArchiveMode]::Create)
      try { $null = $archive.CreateEntry('Notes.exe') } finally { $archive.Dispose() }
      & $script:Generator -Version 1.2.3 -ArtifactPath $portable -ArtifactKind Portable -AppId notes -MainExe Notes.exe -DisplayName 'Notes & More' -OutputDirectory $script:Output
      $manifest = Get-Content "$script:Output/bucket/notes-portable.json" -Raw | ConvertFrom-Json
      $manifest.shortcuts[0][0] | Should -Be 'Notes.exe'
      $manifest.shortcuts[0][1] | Should -Be 'Notes & More'
      $manifest.PSObject.Properties.Name | Should -Not -Contain 'bin'
   }

   It 'creates a shim only for the selected executable and passes the verified checksum' `
   {
      $archive = [IO.Compression.ZipFile]::Open($script:Artifact, [IO.Compression.ZipArchiveMode]::Update)
      try { $null = $archive.CreateEntry('helpers/Update.exe') } finally { $archive.Dispose() }
      & $script:Generator -Version 1.2.3 -ArtifactPath $script:Artifact -ArtifactKind Cli -AppId notes -OutputDirectory $script:Output
      $fixtureArchive = $script:Artifact
      Mock Install-ChocolateyZipPackage -MockWith (
         {
            param($PackageName, $UnzipLocation, $Url64bit, $Checksum64, $ChecksumType64)
            $PackageName | Should -Be 'notes-cli'
            $Url64bit | Should -Match '/releases/download/v1.2.3/'
            $ChecksumType64 | Should -Be 'sha256'
            $Checksum64 | Should -Be (Get-FileHash $fixtureArchive -Algorithm SHA256).Hash.ToLowerInvariant()
            [IO.Compression.ZipFile]::ExtractToDirectory($fixtureArchive, $UnzipLocation)
         }.GetNewClosure())
      $toolsDirectory = "$script:Output/chocolatey/notes-cli/tools"
      & "$toolsDirectory/chocolateyinstall.ps1"
      Test-Path "$toolsDirectory/app/notes.exe.ignore" | Should -BeFalse
      Test-Path "$toolsDirectory/app/helpers/Update.exe.ignore" | Should -BeTrue
      Should -Invoke Install-ChocolateyZipPackage -Times 1 -Exactly
   }
}
