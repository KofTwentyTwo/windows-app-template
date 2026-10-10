#Requires -Version 7.4
# Copyright (c) 2026 James Maes
# SPDX-License-Identifier: MIT

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

BeforeAll `
{
   $script:PackageByteGate = Join-Path $PSScriptRoot 'Assert-PackageBytes.ps1'
}

Describe 'Final package byte preservation' `
{
   BeforeEach `
   {
      $script:ByteFixture = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
      New-Item -ItemType Directory -Path "$script:ByteFixture/source", "$script:ByteFixture/portable/current", "$script:ByteFixture/full/lib/app" | Out-Null
      foreach($directory in @('source', 'portable/current', 'full/lib/app'))
      {
         Copy-Item -LiteralPath (Join-Path $PSHOME 'System.Runtime.dll') -Destination "$script:ByteFixture/$directory/Runtime.dll"
      }
   }

   It 'accepts exact source bytes with the actual Velopack archive prefixes' `
   {
      [IO.Compression.ZipFile]::CreateFromDirectory("$script:ByteFixture/portable", "$script:ByteFixture/portable.zip")
      [IO.Compression.ZipFile]::CreateFromDirectory("$script:ByteFixture/full", "$script:ByteFixture/full.nupkg")
      & $script:PackageByteGate -PublishDirectory "$script:ByteFixture/source" -PortableArchive "$script:ByteFixture/portable.zip" -FullPackage "$script:ByteFixture/full.nupkg" | Should -BeLike 'Verified 1*'
   }

   It 'rejects changed framework bytes even when file length is unchanged' `
   {
      $changed = [IO.File]::ReadAllBytes("$script:ByteFixture/portable/current/Runtime.dll")
      $changed[0] = 0
      [IO.File]::WriteAllBytes("$script:ByteFixture/portable/current/Runtime.dll", $changed)
      [IO.Compression.ZipFile]::CreateFromDirectory("$script:ByteFixture/portable", "$script:ByteFixture/portable.zip")
      [IO.Compression.ZipFile]::CreateFromDirectory("$script:ByteFixture/full", "$script:ByteFixture/full.nupkg")
      { & $script:PackageByteGate -PublishDirectory "$script:ByteFixture/source" -PortableArchive "$script:ByteFixture/portable.zip" -FullPackage "$script:ByteFixture/full.nupkg" } | Should -Throw '*changed published bytes*Runtime.dll*'
   }

   It 'rejects a full package that omits a dependency' `
   {
      Remove-Item -LiteralPath "$script:ByteFixture/full/lib/app/Runtime.dll"
      [IO.Compression.ZipFile]::CreateFromDirectory("$script:ByteFixture/portable", "$script:ByteFixture/portable.zip")
      [IO.Compression.ZipFile]::CreateFromDirectory("$script:ByteFixture/full", "$script:ByteFixture/full.nupkg")
      { & $script:PackageByteGate -PublishDirectory "$script:ByteFixture/source" -PortableArchive "$script:ByteFixture/portable.zip" -FullPackage "$script:ByteFixture/full.nupkg" } | Should -Throw '*omits published file*Runtime.dll*'
   }

   It 'rejects a corrupt published executable header before comparing archives' `
   {
      $changed = [IO.File]::ReadAllBytes("$script:ByteFixture/source/Runtime.dll")
      $changed[0] = 0
      [IO.File]::WriteAllBytes("$script:ByteFixture/source/Runtime.dll", $changed)
      [IO.Compression.ZipFile]::CreateFromDirectory("$script:ByteFixture/portable", "$script:ByteFixture/portable.zip")
      [IO.Compression.ZipFile]::CreateFromDirectory("$script:ByteFixture/full", "$script:ByteFixture/full.nupkg")
      { & $script:PackageByteGate -PublishDirectory "$script:ByteFixture/source" -PortableArchive "$script:ByteFixture/portable.zip" -FullPackage "$script:ByteFixture/full.nupkg" } | Should -Throw '*Invalid published PE binary: Runtime.dll*'
   }
}
