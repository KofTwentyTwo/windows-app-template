/*
 * Copyright (c) 2026 James Maes
 * SPDX-License-Identifier: MIT
 */

using FlaUI.Core.AutomationElements;


namespace Kof22App.UiTests;

/// <summary>
/// End-to-end tests of the real app: the AppKit shell pieces and the example feature.
/// UI tests share one desktop, so they never run in parallel.
/// </summary>
[Collection("Desktop")]
public class AppTests
{
   /// <summary>Splash: shows, then dismisses itself.</summary>
   [Fact]
   public void Splash_ShowsThenDismissesItself()
   {
      using var session = new AppSession(showSplash: true);
      session.WaitForElement("AppKitSplash");
      session.WaitForElementGone("AppKitSplash", TimeSpan.FromSeconds(15));
   }



   /// <summary>About: shows the build version.</summary>
   [Fact]
   public void About_ShowsTheBuildVersion()
   {
      using var session = new AppSession();
      session.InvokeMenuItem("Help", "AboutMenuItem");
      AutomationElement version = session.WaitForElement("AboutVersionText");
      Assert.StartsWith("Version ", version.Name, StringComparison.Ordinal);
      session.ClickButton("Close");
      session.WaitForElementGone("AboutVersionText");
   }



   /// <summary>Crash net: an unhandled exception is logged and the app keeps running.</summary>
   [Fact]
   public void UnhandledException_IsLoggedAndTheAppSurvives()
   {
      using var session = new AppSession();
      session.MouseClickElement("ThrowButton");
      session.WaitFor(
         () => session.ReadLogs().Contains("Deliberately unhandled exception from the template", StringComparison.Ordinal) ? session.MainWindow : null,
         "the crash net's log entry");
      Assert.False(session.App.HasExited);
      Assert.Contains("Unhandled UI exception", session.ReadLogs(), StringComparison.Ordinal);
   }



   /// <summary>Activity log: opens a window showing the log.</summary>
   [Fact]
   public void ActivityLog_OpensAWindowShowingTheLog()
   {
      using var session = new AppSession();
      session.InvokeMenuItem("Help", "ActivityLogMenuItem");
      string title = AppIdentity.Info.DisplayName + " — Activity log";
      session.WaitFor(
         () => session.TopLevelWindows().FirstOrDefault(window => string.Equals(window.Name, title, StringComparison.Ordinal)),
         "the activity log window");
   }



   /// <summary>Theme: the choice is saved to settings.json.</summary>
   [Fact]
   public void ThemeChoice_IsSaved()
   {
      using var session = new AppSession();
      session.InvokeMenuItem("View", "ThemeDark");
      session.WaitFor(
         () => session.ReadSettings().Contains("\"Theme\": \"Dark\"", StringComparison.Ordinal) ? session.MainWindow : null,
         "settings.json to record the dark theme");
   }



   /// <summary>Updates: a build that was not installed by Velopack says updates need an install.</summary>
   [Fact]
   public void CheckForUpdates_InALooseBuild_SaysUpdatesNeedAnInstall()
   {
      using var session = new AppSession();
      session.InvokeMenuItem("Help", "CheckForUpdatesMenuItem");
      session.WaitFor(
         () => session.FindInApp(cf => cf.ByName("Updates are only available in installed builds.")),
         "the not-installed message");
      session.ClickButton("OK");
   }



   /// <summary>Example feature: greeting a name shows the greeting and saves the name.</summary>
   [Fact]
   public void Greet_ShowsTheGreetingAndSavesTheName()
   {
      using var session = new AppSession();
      session.EnterText("NameBox", "Ada");
      session.ClickElement("GreetButton");
      session.WaitFor(
         () => session.FindInApp(cf => cf.ByAutomationId("GreetingText")) is { } text && text.Name.EndsWith(", Ada!", StringComparison.Ordinal) ? text : null,
         "the greeting");
      session.WaitFor(
         () => session.ReadSettings().Contains("\"LastName\": \"Ada\"", StringComparison.Ordinal) ? session.MainWindow : null,
         "settings.json to record the name");
   }
}



/// <summary>UI tests share one desktop, so the collection never runs in parallel.</summary>
[CollectionDefinition("Desktop", DisableParallelization = true)]
public class DesktopCollectionDefinition
{
}
