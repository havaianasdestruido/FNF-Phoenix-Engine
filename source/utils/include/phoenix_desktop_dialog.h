#ifndef PHOENIX_DESKTOP_DIALOG_H
#define PHOENIX_DESKTOP_DIALOG_H

/*
 * Native desktop crash dialogs. Programs are launched with posix_spawnp rather
 * than through a shell, so a crash message is always data, never shell syntax.
 * Keep these helpers header-only because hxcpp generates multiple translation
 * units that include native metadata.
 */

#if defined(__unix__) || defined(__APPLE__)

#include <cerrno>
#include <cstdio>
#include <cstdlib>
#include <spawn.h>
#include <string>
#include <sys/wait.h>
#include <unistd.h>
#include <vector>

extern char **environ;

static const char *const PHOENIX_DESKTOP_DIALOG_TITLE = "Friday Night Funkin' - Phoenix Engine";

/** Execute an argv vector directly, returning the child exit status or -1. */
static inline int phoenixRunDesktopDialogProgram(const std::vector<std::string> &arguments)
{
  if (arguments.empty())
    return -1;

  std::vector<char *> argv;
  argv.reserve(arguments.size() + 1);
  for (size_t index = 0; index < arguments.size(); ++index)
    argv.push_back(const_cast<char *>(arguments[index].c_str()));
  argv.push_back(NULL);

  pid_t process = 0;
  const int spawnResult = posix_spawnp(&process, argv[0], NULL, NULL, argv.data(), environ);
  if (spawnResult != 0)
    return -1;

  int status = 0;
  while (waitpid(process, &status, 0) == -1)
  {
    if (errno != EINTR)
      return -1;
  }

  return WIFEXITED(status) ? WEXITSTATUS(status) : -1;
}

/** Last-resort reporting when no supported desktop dialog program is present. */
static inline void phoenixWriteDesktopDialogFallback(const std::string &message)
{
  std::fprintf(stderr, "%s:\n", PHOENIX_DESKTOP_DIALOG_TITLE);
  std::fwrite(message.data(), 1, message.size(), stderr);
  std::fputc('\n', stderr);
  std::fflush(stderr);
}

/**
 * Quote a value for an AppleScript string literal. This is separate from shell
 * escaping: osascript receives the completed script as a direct argv entry.
 */
static inline std::string phoenixEscapeAppleScriptString(const std::string &value)
{
  std::string escaped;
  escaped.reserve(value.size());
  for (size_t index = 0; index < value.size(); ++index)
  {
    switch (value[index])
    {
      case '\\': escaped += "\\\\"; break;
      case '"': escaped += "\\\""; break;
      case '\n': escaped += "\\n"; break;
      case '\r': escaped += "\\r"; break;
      case '\t': escaped += "\\t"; break;
      default: escaped += value[index]; break;
    }
  }
  return escaped;
}

static inline std::string phoenixMacDesktopAlertScript(const std::string &message)
{
  return std::string("display alert \"") + PHOENIX_DESKTOP_DIALOG_TITLE + "\" message \"" +
    phoenixEscapeAppleScriptString(message) + "\" as critical";
}

/** Show an osascript alert on macOS, printing to stderr if osascript cannot run. */
static inline int phoenixShowMacDesktopDialog(const std::string &message)
{
  const std::vector<std::string> arguments = {
    "osascript", "-e", phoenixMacDesktopAlertScript(message)
  };
  const int result = phoenixRunDesktopDialogProgram(arguments);
  if (result != -1)
    return result;

  phoenixWriteDesktopDialogFallback(message);
  return 0;
}

/** Show a zenity dialog, then try kdialog, then report the message to stderr. */
static inline int phoenixShowLinuxDesktopDialog(const std::string &message)
{
  const std::vector<std::string> zenityArguments = {
    "zenity", "--error", "--title=Friday Night Funkin' - Phoenix Engine",
    std::string("--text=") + message
  };
  int result = phoenixRunDesktopDialogProgram(zenityArguments);
  if (result != -1)
    return result;

  const std::vector<std::string> kdialogArguments = {
    "kdialog", "--title", PHOENIX_DESKTOP_DIALOG_TITLE, "--error", message
  };
  result = phoenixRunDesktopDialogProgram(kdialogArguments);
  if (result != -1)
    return result;

  phoenixWriteDesktopDialogFallback(message);
  return 0;
}

#endif

#endif
