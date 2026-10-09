/*
 * Copyright (c) 2026 James Maes
 * SPDX-License-Identifier: MIT
 */

using KofTwentyTwo.AppKit.Logging;


namespace Kof22App.Core.Tests;

/// <summary>Tests of the app's identity and the services derived from it.</summary>
public class AppIdentityTests
{
   /// <summary>Info: the id and display name are the app's.</summary>
   [Fact]
   public void Info_IdentifiesTheApp()
   {
      Assert.Equal("kof22-app", AppIdentity.Info.Id);
      Assert.Equal("Kof22 App", AppIdentity.Info.DisplayName);
      Assert.EndsWith("_DATA_DIR", AppIdentity.Info.DataDirectoryVariable, StringComparison.Ordinal);
      Assert.NotNull(AppIdentity.Info.RepositoryUrl);
      Assert.NotEmpty(AppIdentity.Info.Attributions);
   }



   /// <summary>Paths and SettingsStore: settings live in the app's data folder.</summary>
   [Fact]
   public void SettingsStore_UsesTheAppsSettingsFile()
   {
      Assert.Equal(AppIdentity.Paths.SettingsFile, AppIdentity.SettingsStore.Path);
      Assert.EndsWith("settings.json", AppIdentity.SettingsStore.Path, StringComparison.Ordinal);
   }



   /// <summary>CreateLog: writes daily files in the app's logs folder, named after the id.</summary>
   [Fact]
   public void CreateLog_WritesToTheAppsLogsFolder()
   {
      IActivityLog log = AppIdentity.CreateLog();
      Assert.Equal(AppIdentity.Paths.LogsDirectory, log.LogDirectory);
      Assert.StartsWith("kof22-app-", Path.GetFileName(log.CurrentLogFilePath), StringComparison.Ordinal);
   }
}



/// <summary>Tests of the app's settings.</summary>
public class AppSettingsTests
{
   /// <summary>Sanitize: a null name from JSON becomes empty, and the shell settings are repaired too.</summary>
   [Fact]
   public void Sanitize_RepairsNullsAndShellSettings()
   {
      var settings = new AppSettings { LastName = null!, Theme = "Purple" };
      settings.Sanitize();
      Assert.Equal("", settings.LastName);
      Assert.Equal("System", settings.Theme);
   }



   /// <summary>Round trip: the name survives a save and a load.</summary>
   [Fact]
   public void SaveAndLoad_KeepTheName()
   {
      using var temp = new TempDirectory();
      var store = new KofTwentyTwo.AppKit.Settings.SettingsStore<AppSettings>(temp.File("settings.json"), AppSettingsContext.Default.AppSettings);
      Assert.True(store.Save(new AppSettings { LastName = "Ada" }));
      Assert.Equal("Ada", store.Load().LastName);
   }
}
