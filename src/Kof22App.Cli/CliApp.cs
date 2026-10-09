/*
 * Copyright (c) 2026 James Maes
 * SPDX-License-Identifier: MIT
 */

using System.Reflection;
using KofTwentyTwo.AppKit;


namespace Kof22App.Cli;

/// <summary>
/// The command-line interface. It takes its output streams and clock as parameters, so
/// tests drive every path in-process (K22-TEST-10). Exit codes: 0 success, 1 the command
/// failed, 2 the command line was wrong.
/// </summary>
internal static class CliApp
{
   internal const int Success = 0;
   internal const int Failure = 1;
   internal const int UsageError = 2;



   /// <summary>Parses <paramref name="args"/> and runs the command they name.</summary>
   internal static int Run(string[] args, TextWriter output, TextWriter error, TimeProvider? time = null)
   {
      ArgumentNullException.ThrowIfNull(args);
      ArgumentNullException.ThrowIfNull(output);
      ArgumentNullException.ThrowIfNull(error);

      if(args.Length == 0 || args[0] is "-h" or "--help" or "help")
      {
         output.WriteLine(Usage());
         return args.Length == 0 ? UsageError : Success;
      }

      return args[0] switch
      {
         "--version" or "version" => PrintVersion(output),
         "greet" => Greet(args[1..], output, error, time),
         _ => Unknown(args[0], error),
      };
   }



   /// <summary>The help text.</summary>
   internal static string Usage()
      => $"""
         {AppIdentity.Info.DisplayName} command line

         Usage:
           kof22-app greet [--name <name>]   Print a greeting for the time of day
           kof22-app --version               Print the version and commit
           kof22-app --help                  Show this help
         """;



   /// <summary>Prints "Kof22 App 1.2.3 (abc123456)".</summary>
   private static int PrintVersion(TextWriter output)
   {
      output.WriteLine($"{AppIdentity.Info.DisplayName} {BuildVersion.Describe(Assembly.GetExecutingAssembly())}");
      return Success;
   }



   /// <summary>The greet command: an optional --name value.</summary>
   private static int Greet(string[] args, TextWriter output, TextWriter error, TimeProvider? time)
   {
      string? name = null;
      for(int index = 0; index < args.Length; index++)
      {
         if(string.Equals(args[index], "--name", StringComparison.Ordinal) && index + 1 < args.Length)
         {
            name = args[++index];
         }
         else
         {
            error.WriteLine($"Unexpected argument '{args[index]}'. Usage: kof22-app greet [--name <name>]");
            return UsageError;
         }
      }

      try
      {
         output.WriteLine(new GreetingService(time).Greet(name));
         return Success;
      }
      catch(ArgumentException ex)
      {
         error.WriteLine(ex.Message);
         return Failure;
      }
   }



   /// <summary>Reports an unknown command.</summary>
   private static int Unknown(string command, TextWriter error)
   {
      error.WriteLine($"Unknown command '{command}'. Run 'kof22-app --help'.");
      return UsageError;
   }
}
