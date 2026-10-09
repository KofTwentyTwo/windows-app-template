/*
 * Copyright (c) 2026 James Maes
 * SPDX-License-Identifier: MIT
 */

using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using KofTwentyTwo.AppKit.Logging;
using KofTwentyTwo.AppKit.Settings;


namespace Kof22App.Core.Greetings;

/// <summary>
/// Presentation state for the greeting screen. It lives in Core, not in the WinUI project,
/// so it is tested headlessly; the window binds to it with x:Bind and holds no logic.
/// </summary>
public sealed partial class GreetingViewModel : ObservableObject
{
   private readonly GreetingService _greetings;
   private readonly AppSettings _settings;
   private readonly SettingsStore<AppSettings> _store;
   private readonly IActivityLog _log;



   /// <summary>Creates the view model, starting from the name saved last time.</summary>
   public GreetingViewModel(GreetingService greetings, AppSettings settings, SettingsStore<AppSettings> store, IActivityLog log)
   {
      ArgumentNullException.ThrowIfNull(greetings);
      ArgumentNullException.ThrowIfNull(settings);
      ArgumentNullException.ThrowIfNull(store);
      ArgumentNullException.ThrowIfNull(log);
      _greetings = greetings;
      _settings = settings;
      _store = store;
      _log = log;
      Name = settings.LastName;
   }



   /// <summary>The name typed by the user.</summary>
   [ObservableProperty]
   public partial string Name { get; set; } = "";



   /// <summary>The greeting shown, or the reason the name was rejected.</summary>
   [ObservableProperty]
   public partial string Message { get; set; } = "";



   /// <summary>Greets <see cref="Name"/>, remembers it for next time, and logs the event.</summary>
   [RelayCommand]
   private void Greet()
   {
      try
      {
         Message = _greetings.Greet(Name);
      }
      catch(ArgumentException ex)
      {
         Message = ex.Message;
         _log.Warning($"Greeting rejected: {ex.Message}");
         return;
      }

      _settings.LastName = Name.Trim();
      if(!_store.Save(_settings))
      {
         _log.Warning("Could not save the last greeted name.");
      }
      _log.Info("Greeted the user.");
   }
}
