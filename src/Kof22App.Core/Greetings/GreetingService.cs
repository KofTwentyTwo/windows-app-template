/*
 * Copyright (c) 2026 James Maes
 * SPDX-License-Identifier: MIT
 */

namespace Kof22App.Core.Greetings;

/// <summary>
/// The template's example feature: a greeting that depends on the time of day. It shows
/// the shape every feature takes: UI-free logic in Core, the clock injected through
/// <see cref="TimeProvider"/> so tests are deterministic (K22-TEST-20), and input
/// validated where it enters (K22-CODE-22). Replace it with the app's real features.
/// </summary>
public sealed class GreetingService
{
   /// <summary>Longest name accepted, so a pasted document cannot become a greeting.</summary>
   public const int MaxNameLength = 100;

   private readonly TimeProvider _time;



   /// <summary>Creates the service over <paramref name="time"/>; the system clock when null.</summary>
   public GreetingService(TimeProvider? time = null)
   {
      _time = time ?? TimeProvider.System;
   }



   /// <summary>
   /// "Good morning, Ada!" (or afternoon, or evening, by local time). A blank name greets
   /// "there".
   /// </summary>
   /// <exception cref="ArgumentException">The name is longer than <see cref="MaxNameLength"/>.</exception>
   public string Greet(string? name)
   {
      string trimmed = name?.Trim() ?? "";
      if(trimmed.Length > MaxNameLength)
      {
         throw new ArgumentException($"A name can be at most {MaxNameLength} characters.", nameof(name));
      }

      return $"{PartOfDay()}, {(trimmed.Length == 0 ? "there" : trimmed)}!";
   }



   /// <summary>Morning before noon, afternoon before six, evening after.</summary>
   private string PartOfDay()
   {
      int hour = _time.GetLocalNow().Hour;
      return hour switch
      {
         < 12 => "Good morning",
         < 18 => "Good afternoon",
         _ => "Good evening",
      };
   }
}
