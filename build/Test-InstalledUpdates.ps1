# Copyright (c) 2026 James Maes
# SPDX-License-Identifier: MIT
<#
.SYNOPSIS
Packages four local starter releases and verifies installed stable/dev update isolation.
.DESCRIPTION
Uses a unique package ID, bounded directories and offline GitHub response fixtures.
Runs on an interactive Windows desktop. Never publishes releases or uses signing credentials.
#>
[CmdletBinding()]
param(
   [string]$AppId = 'kof22-app',
   [string]$VpkPath = 'vpk',
   [string]$OutputDirectory = ('artifacts/installed-smoke-' + [guid]::NewGuid().ToString('N'))
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$outputRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputDirectory)
$allowedRoot = [IO.Path]::GetFullPath((Join-Path $repositoryRoot 'artifacts')) + [IO.Path]::DirectorySeparatorChar
if(-not $outputRoot.StartsWith($allowedRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Smoke output must be inside this repository artifacts directory.' }
if(-not $IsWindows) { throw 'Installed smoke tests require Windows.' }
$solution = @(Get-ChildItem -LiteralPath $repositoryRoot -Filter '*.slnx')
if($solution.Count -ne 1) { throw 'Expected exactly one app solution.' }
$name = $solution[0].BaseName
$identity = [regex]::Match((Get-Content -LiteralPath "$repositoryRoot/src/$name.Core/AppIdentity.cs" -Raw), '(?m)^\s*Id\s*=\s*"([a-z0-9][a-z0-9-]*)"')
if(-not $identity.Success -or $identity.Groups[1].Value -cne $AppId) { throw 'AppId must match the declared AppIdentity to isolate real profile data.' }
$mainExe = "$name.exe"
$probeExe = "$name.UpdateProbe.exe"
$vpk = (Get-Command $VpkPath -CommandType Application -ErrorAction Stop).Source
if(Test-Path -LiteralPath $outputRoot) { throw 'Choose a fresh smoke output directory.' }
$outputDrive = [IO.DriveInfo]::new([IO.Path]::GetPathRoot($outputRoot))
if($outputDrive.AvailableFreeSpace -lt 8GB) { throw 'Installed smoke needs at least 8 GB free on the output volume. Move completed fixtures before retrying.' }
New-Item -ItemType Directory -Path $outputRoot | Out-Null
$idFile = Join-Path $outputRoot 'package-id.txt'
$packageId = 'k22-smoke-' + [guid]::NewGuid().ToString('N')
$buildRoot = Join-Path ([IO.Path]::GetTempPath()) $packageId
if(Test-Path -LiteralPath $buildRoot) { throw 'Private build directory already exists.' }
New-Item -ItemType Directory -Path $buildRoot | Out-Null
Set-Content -LiteralPath $idFile -Value $packageId
Set-Content -LiteralPath (Join-Path $outputRoot 'build-directory.txt') -Value $buildRoot
$fixtureRoot = Join-Path $outputRoot 'fixture'
$dataVariable = $AppId.ToUpperInvariant().Replace('-', '_') + '_DATA_DIR'
$oldDataDirectory = [Environment]::GetEnvironmentVariable($dataVariable)
$oldUiExe = $env:K22_UITEST_EXE
$versions = @(
   @{ channel = 'stable'; version = '0.1.0'; target = '0.4.0' },
   @{ channel = 'stable'; version = '0.4.0'; target = $null },
   @{ channel = 'dev'; version = '0.3.0-beta.1'; target = '0.3.0-beta.2' },
   @{ channel = 'dev'; version = '0.3.0-beta.2'; target = $null }
)
$script:smokeProcessNumber = 0

<#
.SYNOPSIS
Runs one process with literal arguments, bounded duration and checked exit status.
#>
function Invoke-SmokeProcess
{
   [CmdletBinding()]
   param([string]$File, [string[]]$Arguments, [int]$TimeoutSeconds = 180)
   $start = [Diagnostics.ProcessStartInfo]::new($File)
   $start.UseShellExecute = $false
   $start.CreateNoWindow = $true
   $start.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
   $start.WorkingDirectory = $repositoryRoot
   $start.RedirectStandardOutput = $true
   $start.RedirectStandardError = $true
   if($File -eq $vpk)
   {
      $start.Environment['VELOPACK_TEMP'] = Join-Path ([IO.Path]::GetTempPath()) $packageId
   }
   foreach($argument in $Arguments) { $start.ArgumentList.Add($argument) }
   $process = [Diagnostics.Process]::Start($start)
   $stdout = $process.StandardOutput.ReadToEndAsync()
   $stderr = $process.StandardError.ReadToEndAsync()
   try
   {
      if(-not $process.WaitForExit($TimeoutSeconds * 1000))
      {
         $process.Kill($true)
         throw "Process timed out: $File"
      }
      $script:smokeProcessNumber++
      $log = Join-Path $outputRoot "process-$script:smokeProcessNumber.log"
      $text = $stdout.GetAwaiter().GetResult() + $stderr.GetAwaiter().GetResult()
      Set-Content -LiteralPath $log -Value $text
      if($process.ExitCode -ne 0) { throw "Process failed ($($process.ExitCode)): $File. Log: $log`n$text" }
   }
   finally { $process.Dispose() }
}

<#
.SYNOPSIS
Reads the result emitted from a real loose, portable or installed probe process.
#>
function Get-SmokeResult
{
   [CmdletBinding()]
   param([string]$Exe, [string]$ResultPath, [string]$Mode = 'check')
   Invoke-SmokeProcess -File $Exe -Arguments @($fixtureRoot, $ResultPath, $Mode)
   if(-not (Test-Path -LiteralPath $ResultPath)) { throw 'Probe did not emit a result.' }
   $result = Get-Content -LiteralPath $ResultPath -Raw | ConvertFrom-Json
   if($result.UpdateDriver -ne 'AppKit') { throw 'Probe did not use the public AppKit update service.' }
   if($result.AppKitSupported -and $null -ne $result.AppKitCheckError) { throw 'Public AppKit update check failed.' }
   if($Mode -eq 'apply' -and (-not $result.AppKitApplyCalled -or $null -ne $result.AppKitApplyError)) { throw 'Public AppKit download/apply failed or was not called.' }
   $result
}

<#
.SYNOPSIS
Checks the CLI's complete version token with or without optional SourceLink metadata.
#>
function Assert-SmokeCliVersion
{
   [CmdletBinding()]
   param([string]$Output, [string]$Version)
   $pattern = ' ' + [regex]::Escape($Version) + '(?: \([^()\r\n]+\))?$'
   if($Output.TrimEnd() -cnotmatch $pattern) { throw 'Published CLI reports an incorrect version.' }
}

<#
.SYNOPSIS
Closes only the app process launched from the exact test installation directory.
#>
function Stop-SmokeApp
{
   [CmdletBinding(SupportsShouldProcess)]
   param([string]$Exe)
   foreach($process in @(Get-Process -Name $name -ErrorAction SilentlyContinue))
   {
      try
      {
         if($process.Path -eq $Exe -and $PSCmdlet.ShouldProcess($Exe, 'Close isolated smoke application'))
         {
            [void]$process.CloseMainWindow()
            if(-not $process.WaitForExit(5000)) { $process.Kill() }
         }
      }
      finally { $process.Dispose() }
   }
}

$records = [Collections.Generic.List[object]]::new()
try
{
   foreach($release in $versions)
   {
      $version = $release.version
      Write-Output "Packaging $version ($($release.channel))"
      $publish = Join-Path $buildRoot "publish/$version"
      $probe = Join-Path $buildRoot "probe/$version"
      Invoke-SmokeProcess -File 'dotnet' -Arguments @('publish', "$repositoryRoot/src/$name/$name.csproj", '-c', 'Release', '-r', 'win-x64', '-p:Platform=x64', "-p:Version=$version", '-p:SelfContained=true', '-p:WindowsAppSDKSelfContained=true', '-p:RestoreLockedMode=true', '-o', $publish) -TimeoutSeconds 300
      Invoke-SmokeProcess -File 'dotnet' -Arguments @('publish', "$repositoryRoot/tests/$name.UpdateProbe/$name.UpdateProbe.csproj", '-c', 'Release', '-r', 'win-x64', "-p:Version=$version", '-p:SelfContained=true', '-p:RestoreLockedMode=true', '-o', $probe) -TimeoutSeconds 300
      foreach($extension in @('.exe', '.dll', '.deps.json', '.runtimeconfig.json'))
      {
         Copy-Item -LiteralPath (Join-Path $probe "$name.UpdateProbe$extension") -Destination $publish
      }
      if(Test-Path -LiteralPath "$repositoryRoot/src/$name.Cli/$name.Cli.csproj")
      {
         $cli = Join-Path $buildRoot "cli/$version"
         Invoke-SmokeProcess -File 'dotnet' -Arguments @('publish', "$repositoryRoot/src/$name.Cli/$name.Cli.csproj", '-c', 'Release', '-r', 'win-x64', "-p:Version=$version", '-p:SelfContained=true', '-p:PublishSingleFile=true', '-p:RestoreLockedMode=true', '-o', $cli) -TimeoutSeconds 300
         Invoke-SmokeProcess -File (Join-Path $cli "$AppId.exe") -Arguments @('--version')
         $versionOutput = Get-Content -LiteralPath (Join-Path $outputRoot "process-$script:smokeProcessNumber.log") -Raw
         Assert-SmokeCliVersion -Output $versionOutput -Version $version
      }
      Invoke-SmokeProcess -File $vpk -Arguments @('pack', '--runtime', 'win-x64', '--packId', $packageId, '--packVersion', $version, '--packDir', $publish, '--mainExe', $mainExe, '--channel', $release.channel, '--outputDir', (Join-Path $fixtureRoot $version), '--shortcuts', 'None', '--delta', 'None', '--skip-updates', '--yes') -TimeoutSeconds 300
      & "$PSScriptRoot/Assert-PackageBytes.ps1" -PublishDirectory $publish -PortableArchive (Join-Path $fixtureRoot "$version/$packageId-$($release.channel)-Portable.zip") -FullPackage (Join-Path $fixtureRoot "$version/$packageId-$version-$($release.channel)-full.nupkg")
   }
   $releases = foreach($release in $versions)
   {
      $version = $release.version
      $assets = foreach($file in Get-ChildItem -LiteralPath (Join-Path $fixtureRoot $version) -File)
      {
         @{ name = $file.Name; browser_download_url = "https://github.com/Example/InstalledProbe/releases/download/$version/$($file.Name)" }
      }
      @{ name = "v$version"; prerelease = $release.channel -eq 'dev'; published_at = '2026-10-10T12:00:00Z'; assets = @($assets) }
   }
   ConvertTo-Json -InputObject @($releases) -Depth 8 | Set-Content -LiteralPath (Join-Path $fixtureRoot 'releases.json')
   Invoke-SmokeProcess -File 'dotnet' -Arguments @('build', $solution[0].FullName, '-p:Platform=x64', '-p:RestoreLockedMode=true', '-warnaserror') -TimeoutSeconds 300
   $loose = Get-SmokeResult -Exe (Join-Path $buildRoot "publish/0.1.0/$probeExe") -ResultPath (Join-Path $outputRoot 'loose.json')
   if($loose.Installed -or $loose.AppKitSupported -or $null -ne $loose.Version) { throw 'Loose publish output unexpectedly supports updates.' }
   $records.Add(@{ kind = 'loose'; result = $loose })
   $env:K22_UITEST_EXE = Join-Path $buildRoot "publish/0.1.0/$mainExe"
   Invoke-SmokeProcess -File 'dotnet' -Arguments @('test', "$repositoryRoot/tests/$name.UiTests", '--no-build', '--logger', 'trx;LogFileName=published-ui.trx', '--results-directory', $outputRoot) -TimeoutSeconds 180
   foreach($initial in @($versions[0], $versions[2]))
   {
      $portableDirectory = Join-Path $outputRoot "portable-$($initial.channel)"
      [IO.Compression.ZipFile]::ExtractToDirectory((Join-Path $fixtureRoot "$($initial.version)/$packageId-$($initial.channel)-Portable.zip"), $portableDirectory)
      $portable = Get-SmokeResult -Exe (Join-Path $portableDirectory "current/$probeExe") -ResultPath (Join-Path $outputRoot "$($initial.channel)-portable.json")
      if(-not $portable.Installed -or -not $portable.IsPortable -or -not $portable.AppKitSupported -or $portable.Channel -ne $initial.channel -or $portable.UpdateVersion -ne $initial.target) { throw 'Portable bundle identity/update behavior is incorrect.' }
      $records.Add(@{ kind = 'portable'; result = $portable })
   }
   foreach($initial in @($versions[0], $versions[2]))
   {
      $channel = $initial.channel
      $install = Join-Path $outputRoot "installed-$channel"
      if(Test-Path -LiteralPath $install) { throw "Existing installation requires investigation: $install" }
      $setup = Join-Path $fixtureRoot "$($initial.version)/$packageId-$channel-Setup.exe"
      $data = Join-Path $outputRoot "data-$channel"
      New-Item -ItemType Directory -Path $data -Force | Out-Null
      '{"ShowSplashScreen":false,"CheckForUpdatesOnStartup":false}' | Set-Content -LiteralPath (Join-Path $data 'settings.json')
      [Environment]::SetEnvironmentVariable($dataVariable, $data)
      Invoke-SmokeProcess -File $setup -Arguments @('--silent', '--installto', $install, '--log', (Join-Path $outputRoot "install-$channel.log"))
      try
      {
         $currentExe = Join-Path $install "current/$mainExe"
         $installedProbe = Join-Path $install "current/$probeExe"
         $before = Get-SmokeResult -Exe $installedProbe -ResultPath (Join-Path $outputRoot "$channel-before.json") -Mode 'apply'
         if(-not $before.Installed -or -not $before.AppKitSupported -or $before.IsPortable -or $before.Version -ne $initial.version -or $before.AppKitVersion -ne $initial.version -or $before.Channel -ne $channel -or $before.UpdateVersion -ne $initial.target -or $before.IncludePrereleases -ne ($channel -eq 'dev')) { throw "Incorrect $channel installed update offer." }
         $feeds = @($before.Requests | Where-Object { $_ -match '/releases\.(stable|dev)\.json$' })
         if($feeds.Count -eq 0 -or @($feeds | Where-Object { $_ -notmatch "/releases\.$channel\.json$" }).Count -ne 0) { throw 'Channel feed is missing or a cross-channel feed was requested.' }
         if(@($before.Requests | Where-Object { $_ -like "*/$($initial.target)/*-full.nupkg" }).Count -ne 1) { throw 'AppKit did not request the target full update package.' }
         $manifest = Join-Path $install 'current/sq.version'
         $deadline = [DateTime]::UtcNow.AddSeconds(90)
         do
         {
            Start-Sleep -Milliseconds 300
            $actual = if(Test-Path -LiteralPath $manifest) { [xml](Get-Content -LiteralPath $manifest -Raw) } else { $null }
         } while(($null -eq $actual -or $actual.package.metadata.version -ne $initial.target) -and [DateTime]::UtcNow -lt $deadline)
         if($null -eq $actual -or $actual.package.metadata.version -ne $initial.target) { throw "Update did not install $($initial.target)." }
         $deadline = [DateTime]::UtcNow.AddSeconds(30)
         do
         {
            Start-Sleep -Milliseconds 300
            $started = @(Get-Process -Name $name -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $currentExe -and $_.MainWindowHandle -ne 0 })
         } while($started.Count -eq 0 -and [DateTime]::UtcNow -lt $deadline)
         if($started.Count -eq 0) { throw 'Updated main application did not restart with a window.' }
         $installedHash = (Get-FileHash -LiteralPath (Join-Path $install "current/$name.dll") -Algorithm SHA256).Hash
         $publishedHash = (Get-FileHash -LiteralPath (Join-Path $buildRoot "publish/$($initial.target)/$name.dll") -Algorithm SHA256).Hash
         if($installedHash -ne $publishedHash) { throw 'Installed app bytes do not match the target published assembly.' }
         Stop-SmokeApp -Exe $currentExe -Confirm:$false
         $after = Get-SmokeResult -Exe $installedProbe -ResultPath (Join-Path $outputRoot "$channel-after.json")
         if($after.Version -ne $initial.target -or $after.Channel -ne $channel -or $null -ne $after.UpdateVersion -or $after.AppKitVersion -ne $initial.target) { throw 'Post-upgrade identity or channel is incorrect.' }
         $env:K22_UITEST_EXE = $currentExe
         Invoke-SmokeProcess -File 'dotnet' -Arguments @('test', "$repositoryRoot/tests/$name.UiTests", '--no-build', '--filter', 'FullyQualifiedName!~CheckForUpdates_InALooseBuild', '--logger', "trx;LogFileName=installed-$channel-ui.trx", '--results-directory', $outputRoot) -TimeoutSeconds 180
         $records.Add(@{ kind = 'installed'; channel = $channel; before = $before; after = $after; restarted = $true; appSha256 = $installedHash })
      }
      finally
      {
         Stop-SmokeApp -Exe (Join-Path $install "current/$mainExe") -Confirm:$false
         $updater = Join-Path $install 'Update.exe'
         if(Test-Path -LiteralPath $updater)
         {
            $manifestPath = Join-Path $install 'current/sq.version'
            $manifestValue = [xml](Get-Content -LiteralPath $manifestPath -Raw)
            if(-not $install.StartsWith($allowedRoot, [StringComparison]::OrdinalIgnoreCase) -or $manifestValue.package.metadata.id -ne $packageId) { throw 'Refusing to uninstall an unexpected application.' }
            Invoke-SmokeProcess -File $updater -Arguments @('--silent', '--rootDir', $install, 'uninstall')
            $deadline = [DateTime]::UtcNow.AddSeconds(10)
            while((Test-Path -LiteralPath $install) -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 200 }
            if(Test-Path -LiteralPath $install) { throw "Smoke installation was not removed: $install" }
            if(Test-Path -LiteralPath "HKCU:/Software/Microsoft/Windows/CurrentVersion/Uninstall/$packageId") { throw 'Smoke uninstall registry entry remains.' }
         }
      }
   }
   ConvertTo-Json -InputObject @($records) -Depth 10 | Set-Content -LiteralPath (Join-Path $outputRoot 'results.json')
   Write-Output "Installed stable/dev smoke passed: $outputRoot/results.json"
}
finally
{
   [Environment]::SetEnvironmentVariable($dataVariable, $oldDataDirectory)
   $env:K22_UITEST_EXE = $oldUiExe
}
