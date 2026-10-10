/*
 * Copyright (c) 2026 James Maes
 * SPDX-License-Identifier: MIT
 */

using Microsoft.UI.Dispatching;
using Velopack;


namespace Kof22App;

/// <summary>
/// Custom entry point (DISABLE_XAML_GENERATED_MAIN) so Velopack handles its install,
/// update, and uninstall hooks before any UI exists.
/// </summary>
public static class Program
{
   /// <summary>Runs Velopack's hooks first (they may exit the process), then starts the WinUI application.</summary>
   [STAThread]
   private static void Main()
   {
      // Keep this direct call: vpk verifies the entry assembly before creating installers.
      VelopackApp.Build().Run();

      // The remainder mirrors the XAML-generated Main.
      WinRT.ComWrappersSupport.InitializeComWrappers();
      Microsoft.UI.Xaml.Application.Start(callbackParams =>
      {
         SynchronizationContext.SetSynchronizationContext(new DispatcherQueueSynchronizationContext(DispatcherQueue.GetForCurrentThread()));
         _ = new App();
      });
   }
}
