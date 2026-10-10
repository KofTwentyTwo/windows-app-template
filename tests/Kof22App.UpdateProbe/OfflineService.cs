/*
 * Copyright (c) 2026 James Maes
 * SPDX-License-Identifier: MIT
 */

using System.Reflection;
using KofTwentyTwo.AppKit.Updates;
using Velopack;
using Velopack.Sources;


namespace Kof22App.UpdateProbe;

/// <summary>Replaces only HTTP transport in the pinned production service; never supplies a backend or locator.</summary>
internal static class OfflineService
{
   /// <summary>Fails closed when private symbols change rather than falling back to network access.</summary>
   public static (UpdateManager Manager, GithubSource Source) Attach(VelopackUpdateService service, FixtureDownloader downloader)
   {
      const BindingFlags Flags = BindingFlags.Instance | BindingFlags.NonPublic;
      _ = service.IsSupported;
      object backend = typeof(VelopackUpdateService).GetField("_backend", Flags)?.GetValue(service)
         ?? throw new InvalidOperationException("The pinned AppKit backend was not created.");
      UpdateManager manager = backend.GetType().GetField("_manager", Flags)?.GetValue(backend) as UpdateManager
         ?? throw new InvalidOperationException("The pinned AppKit update manager was not found.");
      GithubSource source = typeof(UpdateManager).GetProperty("Source", Flags)?.GetValue(manager) as GithubSource
         ?? throw new InvalidOperationException("The pinned AppKit GitHub source was not found.");
      FieldInfo transport = source.GetType().BaseType?.GetField("<Downloader>k__BackingField", Flags)
         ?? throw new InvalidOperationException("The pinned Velopack downloader field was not found.");
      transport.SetValue(source, downloader);
      if(!ReferenceEquals(source.Downloader, downloader))
      {
         throw new InvalidOperationException("Offline transport was not installed; refusing to check for updates.");
      }
      return (manager, source);
   }
}
