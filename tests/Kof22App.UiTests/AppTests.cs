/*
 * Copyright (c) 2026 James Maes
 * SPDX-License-Identifier: MIT
 */

using FlaUI.Core.AutomationElements;
using Xunit.Abstractions;


namespace Kof22App.UiTests;

/// <summary>
/// End-to-end tests of the real app: the AppKit shell pieces and the example feature.
/// UI tests share one desktop, so they never run in parallel.
/// </summary>
[Collection("Desktop")]
public class AppTests
{
   private readonly ITestOutputHelper _output;



   /// <summary>Records input observations in both passing and failing test results.</summary>
   public AppTests(ITestOutputHelper output) => _output = output;



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
      try
      {
         session.MouseClickElement("ThrowButton");
         _output.WriteLine(session.LastMouseInput);
         session.WaitFor(
            () => session.ReadLogs().Contains("Deliberately unhandled exception from the template", StringComparison.Ordinal) ? session.MainWindow : null,
            "the crash net's log entry");
      }
      catch(TimeoutException exception)
      {
         AutomationElement? status = session.FindInApp(cf => cf.ByAutomationId("StatusText"));
         throw new TimeoutException($"{exception.Message} {session.LastMouseInput} Observed status: '{status?.Properties.Name.ValueOrDefault}'. App logs: {session.ReadLogs()}", exception);
      }
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
      string? observedGreeting = null;
      try
      {
         session.WaitFor(
            () =>
            {
               AutomationElement? text = session.FindInApp(cf => cf.ByAutomationId("GreetingText"));
               observedGreeting = text?.Properties.Name.ValueOrDefault;
               return observedGreeting?.EndsWith(", Ada!", StringComparison.Ordinal) == true ? text : null;
            },
            "the greeting");
      }
      catch(TimeoutException exception)
      {
         throw new TimeoutException($"{exception.Message} Observed greeting: '{observedGreeting}'. App logs: {session.ReadLogs()}", exception);
      }
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
