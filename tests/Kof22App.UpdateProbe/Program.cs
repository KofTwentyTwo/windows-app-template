/*
 * Copyright (c) 2026 James Maes
 * SPDX-License-Identifier: MIT
 */

using System.Reflection;
using System.Text.Json;
using KofTwentyTwo.AppKit;
using KofTwentyTwo.AppKit.Updates;
using Velopack;
using Velopack.Locators;
using Velopack.Sources;


namespace Kof22App.UpdateProbe;

/// <summary>Checks real installed metadata and exercises Velopack with offline GitHub release fixtures.</summary>
internal static class Program
{
   /// <summary>Records the installed channel, update offer and requests; optionally downloads and applies it.</summary>
   private static async Task<int> Main(string[] args)
   {
      VelopackStartup.Run();
      if(args.Length != 3)
      {
         throw new ArgumentException("Usage: UpdateProbe <fixture-directory> <result-json> <check|apply>", nameof(args));
      }

      bool includePrereleases = BuildVersion.IsPrerelease(Assembly.GetExecutingAssembly());
      var repository = new Uri("https://github.com/Example/InstalledProbe");
      var publicService = new VelopackUpdateService(repository);
      var downloader = new FixtureDownloader(args[0]);
      var manager = new UpdateManager(new GithubSource(repository.ToString(), accessToken: null, prerelease: includePrereleases, downloader));
      UpdateInfo? update = manager.IsInstalled ? await manager.CheckForUpdatesAsync().ConfigureAwait(false) : null;
      string? download = null;
      if(string.Equals(args[2], "apply", StringComparison.Ordinal) && update is not null)
      {
         await manager.DownloadUpdatesAsync(update).ConfigureAwait(false);
         download = Path.Combine(VelopackLocator.Current.PackagesDir!, update.TargetFullRelease.FileName);
      }

      File.WriteAllText(args[1], JsonSerializer.Serialize(new
      {
         Installed = manager.IsInstalled,
         AppKitSupported = publicService.IsSupported,
         AppKitVersion = publicService.CurrentVersion,
         Version = manager.CurrentVersion?.ToString(),
         VelopackLocator.Current.Channel,
         manager.IsPortable,
         IncludePrereleases = includePrereleases,
         UpdateVersion = update?.TargetFullRelease.Version.ToString(),
         Download = download,
         downloader.Requests
      }));

      if(string.Equals(args[2], "apply", StringComparison.Ordinal))
      {
         if(update is null)
         {
            throw new InvalidOperationException("No update was offered to apply.");
         }
         manager.ApplyUpdatesAndRestart(update.TargetFullRelease);
      }
      return 0;
   }
}
