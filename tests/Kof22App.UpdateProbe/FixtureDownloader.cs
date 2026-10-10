/*
 * Copyright (c) 2026 James Maes
 * SPDX-License-Identifier: MIT
 */

using Velopack.Sources;


namespace Kof22App.UpdateProbe;

/// <summary>Maps only the smoke fixture's GitHub API and asset URLs to local bytes; never uses the network.</summary>
internal sealed class FixtureDownloader(string fixtureDirectory) : IFileDownloader
{
   public List<string> Requests { get; } = [];



   /// <summary>Persists request evidence before AppKit's apply operation exits the probe process.</summary>
   public Action? RequestRecorded { get; set; }



   /// <summary>Copies the exact release package for Velopack's normal hash verification.</summary>
   public Task DownloadFile(string url, string targetFile, Action<int> progress, IDictionary<string, string>? headers = null, double timeout = 30, CancellationToken cancelToken = default)
   {
      cancelToken.ThrowIfCancellationRequested();
      File.Copy(Resolve(url), targetFile, overwrite: true);
      progress?.Invoke(100);
      return Task.CompletedTask;
   }



   /// <summary>Reads a release channel feed without changing its bytes.</summary>
   public Task<byte[]> DownloadBytes(string url, IDictionary<string, string>? headers = null, double timeout = 30)
       => File.ReadAllBytesAsync(Resolve(url));



   /// <summary>Reads the GitHub release list used by the production GithubSource.</summary>
   public Task<string> DownloadString(string url, IDictionary<string, string>? headers = null, double timeout = 30)
       => File.ReadAllTextAsync(Resolve(url));



   /// <summary>Rejects unexpected hosts, paths, missing assets and traversal instead of falling back to HTTP.</summary>
   private string Resolve(string url)
   {
      Requests.Add(url);
      RequestRecorded?.Invoke();
      var uri = new Uri(url);
      string relative;
      if(string.Equals(uri.Host, "api.github.com", StringComparison.Ordinal) && string.Equals(uri.AbsolutePath, "/repos/Example/InstalledProbe/releases", StringComparison.Ordinal))
      {
         relative = "releases.json";
      }
      else if(string.Equals(uri.Host, "github.com", StringComparison.Ordinal) && uri.AbsolutePath.StartsWith("/Example/InstalledProbe/releases/download/", StringComparison.Ordinal))
      {
         relative = uri.AbsolutePath["/Example/InstalledProbe/releases/download/".Length..];
      }
      else
      {
         throw new InvalidOperationException($"Unexpected fixture URL: {url}");
      }
      string root = Path.GetFullPath(fixtureDirectory) + Path.DirectorySeparatorChar;
      string path = Path.GetFullPath(Path.Combine(root, Uri.UnescapeDataString(relative)));
      if(!path.StartsWith(root, StringComparison.OrdinalIgnoreCase) || !File.Exists(path))
      {
         throw new FileNotFoundException("Fixture asset is missing or outside its root.", path);
      }
      return path;
   }
}
