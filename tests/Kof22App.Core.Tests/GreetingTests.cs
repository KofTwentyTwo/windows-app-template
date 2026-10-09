/*
 * Copyright (c) 2026 James Maes
 * SPDX-License-Identifier: MIT
 */

using KofTwentyTwo.AppKit.Settings;


namespace Kof22App.Core.Tests;

/// <summary>Tests of the example greeting feature's logic.</summary>
public class GreetingServiceTests
{
   /// <summary>Greet: the part of the day follows the local hour, including the boundaries.</summary>
   [Theory]
   [InlineData(0, "Good morning, Ada!")]
   [InlineData(11, "Good morning, Ada!")]
   [InlineData(12, "Good afternoon, Ada!")]
   [InlineData(17, "Good afternoon, Ada!")]
   [InlineData(18, "Good evening, Ada!")]
   [InlineData(23, "Good evening, Ada!")]
   public void Greet_FollowsTheTimeOfDay(int hour, string expected)
   {
      Assert.Equal(expected, new GreetingService(new FixedTimeProvider(hour)).Greet("Ada"));
   }



   /// <summary>Greet: a blank or missing name greets "there"; surrounding spaces are trimmed.</summary>
   [Theory]
   [InlineData(null, "Good morning, there!")]
   [InlineData("   ", "Good morning, there!")]
   [InlineData("  Ada  ", "Good morning, Ada!")]
   public void Greet_HandlesBlankAndPaddedNames(string? name, string expected)
   {
      Assert.Equal(expected, new GreetingService(new FixedTimeProvider(9)).Greet(name));
   }



   /// <summary>Greet: a name longer than the limit is rejected.</summary>
   [Fact]
   public void Greet_RejectsOverlongNames()
   {
      ArgumentException ex = Assert.Throws<ArgumentException>(() => new GreetingService().Greet(new string('x', GreetingService.MaxNameLength + 1)));
      Assert.Equal("name", ex.ParamName);
   }
}



/// <summary>Tests of the greeting screen's view model.</summary>
public sealed class GreetingViewModelTests : IDisposable
{
   private readonly TempDirectory _temp = new();
   private readonly RecordingLog _log = new();



   /// <summary>Deletes the temporary settings folder.</summary>
   public void Dispose() => _temp.Dispose();



   /// <summary>A view model over a settings store in the temporary folder.</summary>
   private GreetingViewModel Create(AppSettings settings, string? settingsPath = null)
   {
      var store = new SettingsStore<AppSettings>(settingsPath ?? _temp.File("settings.json"), AppSettingsContext.Default.AppSettings);
      return new GreetingViewModel(new GreetingService(new FixedTimeProvider(20)), settings, store, _log);
   }



   /// <summary>Construction: starts from the name saved last time.</summary>
   [Fact]
   public void StartsWithTheSavedName()
   {
      Assert.Equal("Grace", Create(new AppSettings { LastName = "Grace" }).Name);
   }



   /// <summary>Greet: shows the greeting, saves the trimmed name, and logs it.</summary>
   [Fact]
   public void Greet_ShowsSavesAndLogs()
   {
      var settings = new AppSettings();
      GreetingViewModel model = Create(settings);
      var changed = new List<string?>();
      model.PropertyChanged += (_, e) => changed.Add(e.PropertyName);

      model.Name = " Ada ";
      model.GreetCommand.Execute(null);

      Assert.Equal("Good evening, Ada!", model.Message);
      Assert.Equal("Ada", settings.LastName);
      Assert.Contains(changed, name => string.Equals(name, nameof(GreetingViewModel.Message), StringComparison.Ordinal));
      Assert.Equal("Ada", new SettingsStore<AppSettings>(_temp.File("settings.json"), AppSettingsContext.Default.AppSettings).Load().LastName);
      Assert.Equal(["INFO Greeted the user."], _log.Entries);
   }



   /// <summary>Greet: an overlong name shows the reason, warns, and saves nothing.</summary>
   [Fact]
   public void Greet_RejectsAndWarns()
   {
      var settings = new AppSettings { LastName = "Kept" };
      GreetingViewModel model = Create(settings);
      model.Name = new string('x', GreetingService.MaxNameLength + 1);
      model.GreetCommand.Execute(null);

      Assert.StartsWith("A name can be at most", model.Message, StringComparison.Ordinal);
      Assert.Equal("Kept", settings.LastName);
      Assert.StartsWith("WARN Greeting rejected", Assert.Single(_log.Entries), StringComparison.Ordinal);
   }



   /// <summary>Greet: a failed settings save is logged, and the greeting still shows.</summary>
   [Fact]
   public void Greet_LogsAFailedSave()
   {
      string notADirectory = _temp.File("file");
      File.WriteAllText(notADirectory, "");
      GreetingViewModel model = Create(new AppSettings(), Path.Combine(notADirectory, "settings.json"));
      model.Name = "Ada";
      model.GreetCommand.Execute(null);

      Assert.Equal("Good evening, Ada!", model.Message);
      Assert.Equal(["WARN Could not save the last greeted name.", "INFO Greeted the user."], _log.Entries);
   }



   /// <summary>Construction: every dependency is required.</summary>
   [Fact]
   public void Constructor_ValidatesArguments()
   {
      var store = new SettingsStore<AppSettings>(_temp.File("settings.json"), AppSettingsContext.Default.AppSettings);
      var service = new GreetingService();
      var settings = new AppSettings();
      Assert.Throws<ArgumentNullException>(() => new GreetingViewModel(null!, settings, store, _log));
      Assert.Throws<ArgumentNullException>(() => new GreetingViewModel(service, null!, store, _log));
      Assert.Throws<ArgumentNullException>(() => new GreetingViewModel(service, settings, null!, _log));
      Assert.Throws<ArgumentNullException>(() => new GreetingViewModel(service, settings, store, null!));
   }
}
