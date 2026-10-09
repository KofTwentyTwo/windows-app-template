/*
 * Copyright (c) 2026 James Maes
 * SPDX-License-Identifier: MIT
 */

namespace Kof22App.Cli;

/// <summary>Entry point: hands the arguments and the console streams to <see cref="CliApp"/>.</summary>
internal static class Program
{
   /// <summary>Runs one command and returns its exit code.</summary>
   internal static int Main(string[] args) => CliApp.Run(args, Console.Out, Console.Error);
}
