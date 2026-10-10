/*
 * Copyright (c) 2026 James Maes
 * SPDX-License-Identifier: MIT
 */

using System.Text.Json;
using KofTwentyTwo.AppKit.Updates;
using Velopack;
using Velopack.Locators;
using Velopack.Sources;


namespace Kof22App.UpdateProbe;

/// <summary>Exercises AppKit's public installed update flow with offline GitHub release fixtures.</summary>
internal static class Program
{
   /// <summary>Records the installed channel, update offer and requests; optionally downloads and applies it.</summary>
   private static async Task<int> Main(string[] args)
   {
      VelopackStartup.Run();
      if(args.Length != 3 || args[2] is not ("check" or "apply"))
      {
         throw new ArgumentException("Usage: UpdateProbe <fixture-directory> <result-json> <check|apply>", nameof(args));
      }

      var repository = new Uri("https://github.com/Example/InstalledProbe");
      var publicService = new VelopackUpdateService(repository);
      var downloader = new FixtureDownloader(args[0]);
      (UpdateManager manager, GithubSource source) = OfflineService.Attach(publicService, downloader);
      UpdateCheckResult update = await publicService.CheckAsync().ConfigureAwait(false);
      if(update.Error is not null && (manager.IsInstalled || !string.Equals(update.Error, UpdateText.NotSupported, StringComparison.Ordinal)))
      {
         throw new InvalidOperationException(update.Error);
      }

      bool applyCalled = false;
      string? applyError = null;
      // Apply exits this process. Record every download request synchronously before that happens.
      Action saveResult = () => File.WriteAllText(args[1], JsonSerializer.Serialize(new
      {
         UpdateDriver = "AppKit",
         Installed = manager.IsInstalled,
         AppKitSupported = publicService.IsSupported,
         AppKitVersion = publicService.CurrentVersion,
         Version = manager.CurrentVersion?.ToString(),
         VelopackLocator.Current.Channel,
         manager.IsPortable,
         IncludePrereleases = source.Prerelease,
         UpdateVersion = update.AvailableVersion,
         AppKitCheckError = update.Error,
         AppKitApplyCalled = applyCalled,
         AppKitApplyError = applyError,
         downloader.Requests
      }));
      downloader.RequestRecorded = saveResult;
      saveResult();

      if(string.Equals(args[2], "apply", StringComparison.Ordinal))
      {
         if(!update.IsUpdateAvailable)
         {
            throw new InvalidOperationException("No update was offered to apply.");
         }
         applyCalled = true;
         saveResult();
         applyError = await publicService.DownloadAndApplyAsync().ConfigureAwait(false);
         saveResult();
         if(applyError is not null)
         {
            throw new InvalidOperationException(applyError);
         }
      }
      return 0;
   }
}
