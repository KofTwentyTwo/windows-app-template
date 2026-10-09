/*
 * Copyright (c) 2026 James Maes
 * SPDX-License-Identifier: MIT
 */

using KofTwentyTwo.AppKit.Settings;
using KofTwentyTwo.AppKit.Updates;
using KofTwentyTwo.AppKit.WinUI;
using Microsoft.UI.Xaml;


namespace Kof22App;

/// <summary>
/// The main window: the AppKit shell (splash, About, activity log, update checks, theme)
/// around the app's content. Handlers here only route to AppKit or to view models in Core.
/// </summary>
public sealed partial class MainWindow : Window
{
   private readonly AppSettings _settings = AppIdentity.SettingsStore.Load();
   private readonly UpdateCoordinator _updates;



   /// <summary>Sizes and brands the window, creates the view model, shows the splash, and schedules the quiet startup update check.</summary>
   public MainWindow()
   {
      ViewModel = new GreetingViewModel(new GreetingService(), _settings, AppIdentity.SettingsStore, App.Log);
      InitializeComponent();
      Title = AppIdentity.Info.DisplayName;
      this.ResizeForDpi(900, 600);
      this.SetMinimumSize(640, 420);
      this.SetAppIcon(AppIdentity.Info);

      _updates = new UpdateCoordinator(
         new VelopackUpdateService(AppIdentity.Info.RepositoryUrl!),
         new ContentDialogPrompter(() => Content.XamlRoot),
         AppIdentity.Info.DisplayName,
         App.Log);

      SplashToggle.IsChecked = _settings.ShowSplashScreen;
      UpdateCheckToggle.IsChecked = _settings.CheckForUpdatesOnStartup;
      (_settings.ThemeKind switch { AppTheme.Light => ThemeLight, AppTheme.Dark => ThemeDark, _ => ThemeSystem }).IsChecked = true;

      SplashOverlay.ShowOver(RootGrid, AppIdentity.Info, _settings);
      Closed += (_, _) => LogWindow.CloseCurrent(); // a log-only process would linger otherwise

      if(_settings.CheckForUpdatesOnStartup)
      {
         // The constructor runs on the UI thread, so the check resumes there to show dialogs.
         _ = CheckForUpdatesAfterStartupAsync();
      }
   }



   /// <summary>The greeting screen's state; x:Bind targets it.</summary>
   public GreetingViewModel ViewModel { get; }



   /// <summary>
   /// Waits for the splash to clear (dialogs need the window's XamlRoot), then runs the
   /// quiet startup update check, which only speaks up when an update exists.
   /// </summary>
   private async Task CheckForUpdatesAfterStartupAsync()
   {
      await Task.Delay(_settings.ShowSplashScreen ? _settings.SplashMilliseconds + 500 : 1000);
      await _updates.CheckQuietlyAsync();
   }



   /// <summary>File, Exit.</summary>
   private void Exit_Click(object sender, RoutedEventArgs e) => Close();



   /// <summary>View, theme: applies the chosen theme to the window and saves it.</summary>
   private void Theme_Click(object sender, RoutedEventArgs e)
   {
      _settings.Theme = (string)((FrameworkElement)sender).Tag;
      WinUIShell.ApplyTheme(RootGrid, _settings.ThemeKind);
      Save();
   }



   /// <summary>View, Show splash at startup: saves the preference.</summary>
   private void Splash_Click(object sender, RoutedEventArgs e)
   {
      _settings.ShowSplashScreen = SplashToggle.IsChecked;
      Save();
   }



   /// <summary>View, Check for updates at startup: saves the preference.</summary>
   private void UpdateCheck_Click(object sender, RoutedEventArgs e)
   {
      _settings.CheckForUpdatesOnStartup = UpdateCheckToggle.IsChecked;
      Save();
   }



   /// <summary>Help, Check for updates: runs the interactive update flow.</summary>
   private async void CheckForUpdates_Click(object sender, RoutedEventArgs e) => await _updates.CheckInteractivelyAsync();



   /// <summary>Help, Activity log: opens the live log window, or brings the open one forward.</summary>
   private void ActivityLog_Click(object sender, RoutedEventArgs e) => LogWindow.ShowSingle(App.Log, AppIdentity.Info);



   /// <summary>Help, About: shows the About dialog.</summary>
   private async void About_Click(object sender, RoutedEventArgs e) => await AboutDialog.ShowAsync(AppIdentity.Info, Content.XamlRoot);



   /// <summary>Throws on purpose: proves the crash net logs the exception and the app keeps running. Remove it from a real app.</summary>
   private void Throw_Click(object sender, RoutedEventArgs e)
   {
      StatusText.Text = "Threw; the crash net logged it and the app kept running.";
      throw new InvalidOperationException("Deliberately unhandled exception from the template.");
   }



   /// <summary>Saves the settings and reports a failed save in the status line.</summary>
   private void Save()
   {
      if(!AppIdentity.SettingsStore.Save(_settings))
      {
         StatusText.Text = "Could not save settings.";
      }
   }
}
