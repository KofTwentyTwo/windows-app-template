/*
 * Copyright (c) 2026 James Maes
 * SPDX-License-Identifier: MIT
 */

namespace Kof22App.Cli.Tests;

/// <summary>Tests of the command line, run in-process with captured output.</summary>
public class CliAppTests
{
   /// <summary>A clock fixed at 09:30 local time.</summary>
   private sealed class MorningClock : TimeProvider
   {
      /// <summary>09:30 UTC.</summary>
      public override DateTimeOffset GetUtcNow() => new(2026, 3, 15, 9, 30, 0, TimeSpan.Zero);



      /// <summary>UTC, so local time equals the fixed time.</summary>
      public override TimeZoneInfo LocalTimeZone => TimeZoneInfo.Utc;
   }



   /// <summary>Runs the CLI and returns the exit code and both outputs.</summary>
   private static (int Code, string Output, string Error) Run(params string[] args)
   {
      using var output = new StringWriter();
      using var error = new StringWriter();
      int code = CliApp.Run(args, output, error, new MorningClock());
      return (code, output.ToString(), error.ToString());
   }



   /// <summary>No arguments: prints usage and exits with the usage error code.</summary>
   [Fact]
   public void NoArguments_PrintsUsage()
   {
      (int code, string output, _) = Run();
      Assert.Equal(CliApp.UsageError, code);
      Assert.Contains("Usage:", output, StringComparison.Ordinal);
   }



   /// <summary>Help, in every spelling, succeeds.</summary>
   [Theory]
   [InlineData("--help")]
   [InlineData("-h")]
   [InlineData("help")]
   public void Help_Succeeds(string flag)
   {
      (int code, string output, _) = Run(flag);
      Assert.Equal(CliApp.Success, code);
      Assert.Equal(CliApp.Usage() + Environment.NewLine, output);
   }



   /// <summary>Version: the display name and the build identity.</summary>
   [Theory]
   [InlineData("--version")]
   [InlineData("version")]
   public void Version_PrintsNameAndVersion(string flag)
   {
      (int code, string output, _) = Run(flag);
      Assert.Equal(CliApp.Success, code);
      Assert.StartsWith("Kof22 App ", output, StringComparison.Ordinal);
   }



   /// <summary>Greet: with and without a name.</summary>
   [Theory]
   [InlineData(new[] { "greet" }, "Good morning, there!")]
   [InlineData(new[] { "greet", "--name", "Ada" }, "Good morning, Ada!")]
   public void Greet_PrintsTheGreeting(string[] args, string expected)
   {
      (int code, string output, string error) = Run(args);
      Assert.Equal(CliApp.Success, code);
      Assert.Equal(expected + Environment.NewLine, output);
      Assert.Empty(error);
   }



   /// <summary>Greet: an unexpected or incomplete argument is a usage error.</summary>
   [Theory]
   [InlineData("greet", "--bogus")]
   [InlineData("greet", "--name")]
   public void Greet_RejectsBadArguments(params string[] args)
   {
      (int code, _, string error) = Run(args);
      Assert.Equal(CliApp.UsageError, code);
      Assert.StartsWith("Unexpected argument", error, StringComparison.Ordinal);
   }



   /// <summary>Greet: a rejected name fails with the reason.</summary>
   [Fact]
   public void Greet_ReportsARejectedName()
   {
      (int code, _, string error) = Run("greet", "--name", new string('x', 101));
      Assert.Equal(CliApp.Failure, code);
      Assert.StartsWith("A name can be at most", error, StringComparison.Ordinal);
   }



   /// <summary>An unknown command is a usage error.</summary>
   [Fact]
   public void UnknownCommand_IsAUsageError()
   {
      (int code, _, string error) = Run("frobnicate");
      Assert.Equal(CliApp.UsageError, code);
      Assert.Contains("Unknown command 'frobnicate'", error, StringComparison.Ordinal);
   }



   /// <summary>Run: arguments and writers are required.</summary>
   [Fact]
   public void Run_ValidatesArguments()
   {
      Assert.Throws<ArgumentNullException>(() => CliApp.Run(null!, TextWriter.Null, TextWriter.Null));
      Assert.Throws<ArgumentNullException>(() => CliApp.Run([], null!, TextWriter.Null));
      Assert.Throws<ArgumentNullException>(() => CliApp.Run([], TextWriter.Null, null!));
   }



   /// <summary>Main: wires the console and the system clock.</summary>
   [Fact]
   public void Main_RunsAgainstTheConsole()
   {
      Assert.Equal(CliApp.Success, Program.Main(["--version"]));
   }
}
