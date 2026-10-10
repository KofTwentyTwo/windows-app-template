/*
 * Copyright (c) 2026 James Maes
 * SPDX-License-Identifier: MIT
 */

using System.Diagnostics;
using FlaUI.Core;
using FlaUI.Core.AutomationElements;
using FlaUI.Core.Conditions;
using FlaUI.Core.Definitions;
using FlaUI.Core.Input;
using FlaUI.Core.Patterns;
using FlaUI.Core.Tools;
using FlaUI.UIA3;


namespace Kof22App.UiTests;

/// <summary>
/// One launched app plus the UIA3 automation that drives it. Each session gets a fresh
/// temp directory passed as the app's data-folder variable, so tests start with no
/// settings or logs and never touch the real profile. Unless a test asks for the
/// splash, the session pre-writes settings that skip it and the startup update check.
/// </summary>
public sealed class AppSession : IDisposable
{
   private static readonly TimeSpan s_defaultTimeout = TimeSpan.FromSeconds(10);
   private static readonly TimeSpan s_launchTimeout = TimeSpan.FromSeconds(30);
   private static readonly TimeSpan s_pollInterval = TimeSpan.FromMilliseconds(250);
   private readonly DpiAwarenessScope _dpi;



   /// <summary>Launches the app against a fresh temporary data folder and waits for its main window.</summary>
   public AppSession(bool showSplash = false)
   {
      ExePath = ResolveExePath();
      DataDirectory = Path.Combine(Path.GetTempPath(), AppIdentity.Info.Id + "-uitests", Guid.NewGuid().ToString("N"));
      Directory.CreateDirectory(DataDirectory);
      File.WriteAllText(
          Path.Combine(DataDirectory, "settings.json"),
          $$"""{ "ShowSplashScreen": {{(showSplash ? "true" : "false")}}, "CheckForUpdatesOnStartup": false }""");

      var startInfo = new ProcessStartInfo(ExePath) { WorkingDirectory = Path.GetDirectoryName(ExePath) ?? "" };
      startInfo.Environment[AppIdentity.Info.DataDirectoryVariable] = DataDirectory;

      _dpi = new DpiAwarenessScope();
      try
      {
         Automation = new UIA3Automation();
         App = Application.Launch(startInfo);
         MainWindow = WaitForMainWindow();
      }
      catch
      {
         Dispose();
         throw;
      }
   }



   public string ExePath { get; }

   public string DataDirectory { get; }

   public UIA3Automation Automation { get; }

   public Application App { get; }

   public Window MainWindow { get; }

   /// <summary>Observed mouse target and focus, retained in timeout diagnostics.</summary>
   public string LastMouseInput { get; private set; } = "No physical input observed.";



   /// <summary>Text of every log file the app wrote so far.</summary>
   public string ReadLogs()
   {
      string logs = Path.Combine(DataDirectory, "logs");
      return Directory.Exists(logs)
          ? string.Concat(Directory.GetFiles(logs, "*.log").Select(ReadShared))
          : "";
   }



   /// <summary>The settings file as the app last saved it.</summary>
   public string ReadSettings() => ReadShared(Path.Combine(DataDirectory, "settings.json"));



   /// <summary>
   /// Finds the first match in the main window or any other top-level window of the
   /// app's process (WinUI menu flyouts and secondary windows are separate HWNDs).
   /// </summary>
   public AutomationElement? FindInApp(Func<ConditionFactory, ConditionBase> condition)
       => MainWindow.FindFirstDescendant(condition)
           ?? TopLevelWindows().Where(w => !w.Equals(MainWindow)).Select(w => w.FindFirstDescendant(condition)).FirstOrDefault(found => found is not null);



   /// <summary>Top-level windows owned by the app's process.</summary>
   public AutomationElement[] TopLevelWindows()
       => Automation.GetDesktop().FindAllChildren(cf => cf.ByProcessId(App.ProcessId));



   /// <summary>Retries the lookup until it returns an element, or fails naming what was awaited.</summary>
   public AutomationElement WaitFor(Func<AutomationElement?> lookup, string description, TimeSpan? timeout = null)
   {
      TimeSpan effective = timeout ?? s_defaultTimeout;
      RetryResult<AutomationElement?> result = Retry.WhileNull(lookup, timeout: effective, interval: s_pollInterval, ignoreException: true);
      return result.Result
          ?? throw new TimeoutException($"Timed out after {effective.TotalSeconds:0}s waiting for {description}. (app exited: {App.HasExited})");
   }



   /// <summary>Retries until the lookup returns nothing, or fails naming what was expected to disappear.</summary>
   public static void WaitUntilGone(Func<AutomationElement?> lookup, string description, TimeSpan? timeout = null)
   {
      TimeSpan effective = timeout ?? s_defaultTimeout;
      if(!Retry.WhileTrue(() => lookup() is not null, timeout: effective, interval: s_pollInterval, ignoreException: true).Success)
      {
         throw new TimeoutException($"Timed out after {effective.TotalSeconds:0}s waiting for {description} to go away.");
      }
   }



   /// <summary>Waits for the element with the given automation id in any of the app&apos;s windows.</summary>
   public AutomationElement WaitForElement(string automationId, TimeSpan? timeout = null)
       => WaitFor(() => FindInApp(cf => cf.ByAutomationId(automationId)), $"element '{automationId}'", timeout);



   /// <summary>Waits until no element with the given automation id remains.</summary>
   public void WaitForElementGone(string automationId, TimeSpan? timeout = null)
       => WaitUntilGone(() => FindInApp(cf => cf.ByAutomationId(automationId)), $"element '{automationId}'", timeout);



   /// <summary>
   /// Opens the top-level menu named <paramref name="menuName"/> and invokes the item
   /// <paramref name="itemAutomationId"/>. A freshly started app can swallow the first
   /// expand (its flyout opens before the menu is ready), so the menu is re-opened
   /// until the item appears.
   /// </summary>
   public void InvokeMenuItem(string menuName, string itemAutomationId)
   {
      AutomationElement menu = WaitFor(
          () => MainWindow.FindFirstDescendant(cf => cf.ByControlType(ControlType.MenuItem).And(cf.ByName(menuName))),
          $"menu '{menuName}'");
      AutomationElement? item = null;
      for(int attempt = 0; attempt < 4 && item is null; attempt++)
      {
         if(menu.Patterns.ExpandCollapse.TryGetPattern(out IExpandCollapsePattern? expandCollapse))
         {
            expandCollapse.Expand();
         }
         else
         {
            Invoke(menu);
         }
         Wait.UntilInputIsProcessed();
         item = Retry.WhileNull(() => FindInApp(cf => cf.ByAutomationId(itemAutomationId)), timeout: TimeSpan.FromSeconds(3), interval: s_pollInterval, ignoreException: true).Result;
      }
      Invoke(item ?? throw new TimeoutException($"Menu item '{itemAutomationId}' never appeared under '{menuName}'. (app exited: {App.HasExited})"));
   }



   /// <summary>Invokes the button named <paramref name="name"/> (XAML buttons only, not caption buttons).</summary>
   public void ClickButton(string name)
       => Invoke(WaitFor(
           () => FindInApp(cf => cf.ByControlType(ControlType.Button).And(cf.ByName(name)).And(cf.ByClassName("Button"))),
           $"button '{name}'"));



   /// <summary>
   /// Clicks with the real mouse. Needed where the handler throws: WinUI hands an
   /// exception raised during a UIA Invoke back to the automation client instead of
   /// raising Application.UnhandledException, which is what a user's click does.
   /// </summary>
   public void MouseClickElement(string automationId)
   {
      AutomationElement element = WaitForElement(automationId);
      element.Focus();
      Wait.UntilInputIsProcessed();
      WaitFor(
         () =>
         {
            MainWindow.SetForeground();
            if(!element.TryGetClickablePoint(out System.Drawing.Point point))
            {
               LastMouseInput = $"Expected PID={App.ProcessId}; target={automationId}; no clickable point.";
               return null;
            }
            AutomationElement hit = Automation.FromPoint(point);
            AutomationElement focused = Automation.FocusedElement();
            int hitProcess = hit.Properties.ProcessId.ValueOrDefault;
            string? hitId = hitProcess == App.ProcessId ? hit.Properties.AutomationId.ValueOrDefault : "outside app";
            LastMouseInput = $"Expected PID={App.ProcessId}; target={automationId}; rectangle={element.BoundingRectangle}; point={point}; hit PID={hitProcess}; hit ID={hitId}; focus PID={focused.Properties.ProcessId.ValueOrDefault}; enabled={element.IsEnabled}; offscreen={element.IsOffscreen}.";
            return hitProcess == App.ProcessId && element.IsEnabled && !element.IsOffscreen ? element : null;
         },
         $"an unobscured mouse target '{automationId}'");
      element.Click();
      Wait.UntilInputIsProcessed();
      LastMouseInput += $" Mouse after={Mouse.Position}; hit PID={Automation.FromPoint(Mouse.Position).Properties.ProcessId.ValueOrDefault}.";
   }



   /// <summary>Invokes the element carrying <paramref name="automationId"/> (a button, for example).</summary>
   public void ClickElement(string automationId) => Invoke(WaitForElement(automationId));



   /// <summary>
   /// Replaces the text of the element carrying <paramref name="automationId"/>: through the
   /// UI Automation Value pattern (no focus needed), or by typing when the pattern is absent.
   /// </summary>
   public void EnterText(string automationId, string text)
   {
      AutomationElement element = WaitForElement(automationId);
      if(element.Patterns.Value.TryGetPattern(out IValuePattern? value) && !value.IsReadOnly.ValueOrDefault)
      {
         value.SetValue(text);
      }
      else
      {
         element.Focus();
         Wait.UntilInputIsProcessed();
         Keyboard.Type(text);
      }
      Wait.UntilInputIsProcessed();
   }



   /// <summary>Invokes an element through UI Automation, falling back to a mouse click.</summary>
   private static void Invoke(AutomationElement element)
   {
      if(element.Patterns.Invoke.TryGetPattern(out IInvokePattern? invoke))
      {
         invoke.Invoke();
      }
      else
      {
         element.Click();
      }
      Wait.UntilInputIsProcessed();
   }



   /// <summary>Waits for the app&apos;s main window, failing fast if the process exits.</summary>
   private Window WaitForMainWindow()
   {
      RetryResult<Window?> result = Retry.WhileNull(
          () =>
          {
             if(App.HasExited)
             {
                throw new InvalidOperationException($"The app exited while starting (exit code {App.ExitCode}). Exe: {ExePath}");
             }
             try
             {
                return App.GetMainWindow(Automation, TimeSpan.FromMilliseconds(500));
             }
             catch
             {
                return null;
             }
          },
          timeout: s_launchTimeout,
          interval: s_pollInterval);
      return result.Result ?? throw new TimeoutException($"The main window did not appear within {s_launchTimeout.TotalSeconds:0}s. Exe: {ExePath}");
   }



   /// <summary>Reads a file the app may still be writing, without locking it.</summary>
   private static string ReadShared(string path)
   {
      if(!File.Exists(path))
      {
         return "";
      }
      using var stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete);
      return new StreamReader(stream).ReadToEnd();
   }



   /// <summary>The exe to drive: K22_UITEST_EXE when set, else the repo's newest Debug build.</summary>
   private static string ResolveExePath()
   {
      const string Variable = "K22_UITEST_EXE";
      if(Environment.GetEnvironmentVariable(Variable) is { Length: > 0 } fromEnv)
      {
         return File.Exists(fromEnv) ? fromEnv : throw new FileNotFoundException($"{Variable} points at '{fromEnv}', which does not exist.", fromEnv);
      }

      for(DirectoryInfo? current = new(AppContext.BaseDirectory); current is not null; current = current.Parent)
      {
         if(!File.Exists(Path.Combine(current.FullName, "Kof22App.slnx")))
         {
            continue;
         }

         string bin = Path.Combine(current.FullName, "src", "Kof22App", "bin");
         string? found = Directory.Exists(bin)
            ? Directory.EnumerateFiles(bin, "Kof22App.exe", SearchOption.AllDirectories)
               .Where(path => path.Contains($"{Path.DirectorySeparatorChar}Debug{Path.DirectorySeparatorChar}", StringComparison.Ordinal))
               .OrderByDescending(File.GetLastWriteTimeUtc)
               .FirstOrDefault()
            : null;
         return found ?? throw new FileNotFoundException($"Kof22App.exe not found under '{bin}'. Build first: dotnet build Kof22App.slnx -p:Platform=x64");
      }

      throw new FileNotFoundException($"No Kof22App.slnx above '{AppContext.BaseDirectory}'. Set {Variable}.");
   }



   /// <summary>Closes the app (killing it if needed), then disposes the automation and deletes the data folder.</summary>
   public void Dispose()
   {
      try
      {
         try
         {
            App?.Close();
         }
         catch
         {
            // Already gone; the kill below double-checks.
         }
         try
         {
            if(App is { HasExited: false })
            {
               App.Kill();
            }
         }
         catch
         {
            // Best effort.
         }
         App?.Dispose();
         Automation?.Dispose();
         try
         {
            Directory.Delete(DataDirectory, recursive: true);
         }
         catch
         {
            // A log handle can linger briefly after exit; the temp cleaner gets it.
         }
      }
      finally
      {
         _dpi.Dispose();
      }
   }
}
