/*
 * Copyright (c) 2026 James Maes
 * SPDX-License-Identifier: MIT
 */

using System.ComponentModel;
using System.Runtime.InteropServices;


namespace Kof22App.UiTests;

/// <summary>Uses physical screen coordinates for input and restores the synchronous test thread afterwards.</summary>
internal sealed class DpiAwarenessScope : IDisposable
{
   private readonly nint _previous;



   /// <summary>Disables DPI virtualization on this thread with per-monitor awareness v2.</summary>
   public DpiAwarenessScope()
   {
      _previous = SetThreadDpiAwarenessContext(-4);
      if(_previous == 0)
      {
         throw new Win32Exception(Marshal.GetLastPInvokeError());
      }
   }



   /// <summary>Restores the context on the thread that ran the synchronous UI test.</summary>
   public void Dispose() => SetThreadDpiAwarenessContext(_previous);



   /// <summary>Overrides the current Windows thread's DPI awareness.</summary>
   [DllImport("user32.dll", ExactSpelling = true, SetLastError = true)]
   private static extern nint SetThreadDpiAwarenessContext(nint dpiContext);
}
