/*
 * Copyright (c) 2026 James Maes
 * SPDX-License-Identifier: MIT
 */

using Microsoft.UI.Xaml;


namespace Kof22App;

/// <summary>Opens only the app's fixed public Help destinations after deliberate native menu actions.</summary>
public sealed partial class MainWindow
{
   /// <summary>Shows this Windows app's repository in the user's default browser.</summary>
   private async void GitHub_Click(object sender, RoutedEventArgs args) => await OpenHelpPageAsync(AppIdentity.Info.RepositoryUrl!);



   /// <summary>Offers the app's issue templates without sending private document data.</summary>
   private async void SubmitIssue_Click(object sender, RoutedEventArgs args) => await OpenHelpPageAsync(AppIdentity.IssuesUrl);



   /// <summary>Opens community questions and tips in this app's repository.</summary>
   private async void CommunitySupport_Click(object sender, RoutedEventArgs args) => await OpenHelpPageAsync(AppIdentity.SupportUrl);



   /// <summary>A missing browser or OS launch failure is visible; no document path/content is included.</summary>
   private async Task OpenHelpPageAsync(Uri target)
   {
      try
      {
         if(!await global::Windows.System.Launcher.LaunchUriAsync(target))
         {
            StatusText.Text = "The link could not be opened. Check your default browser.";
         }
      }
      catch(Exception exception) when(exception is System.Runtime.InteropServices.COMException or InvalidOperationException or ArgumentException)
      {
         StatusText.Text = "The link could not be opened. Check your default browser.";
         App.Log.Warning(FormattableString.Invariant($"A Help link could not be opened ({exception.GetType().Name}, 0x{exception.HResult:X8})."));
      }
   }
}
