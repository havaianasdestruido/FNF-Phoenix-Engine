/*
 * Native notification helpers must treat mod-supplied strings as data, never
 * as shell syntax. Ported from the former Python harness. The runner installs
 * fake `notify-send` / `osascript` capture scripts on PATH and sets CAPTURE.
 */
#include "phoenix_desktop_dialog.h"
#include <cassert>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <sstream>
#include <string>

static std::string readFile(const std::string &path)
{
  std::ifstream in(path.c_str());
  std::ostringstream ss;
  ss << in.rdbuf();
  return ss.str();
}

int main()
{
  const char *capture = std::getenv("CAPTURE");
  assert(capture != NULL);
  const std::string dir(capture);

  assert(phoenixShowLinuxNotification("--title", "$(touch /tmp/phoenix-injection)"));
  assert(phoenixShowMacNotification("a\"b", "line\n\\end"));
  assert(phoenixMacNotificationScript("a\"b", "line\n\\end") ==
    "display notification \"line\\n\\\\end\" with title \"a\\\"b\"");

  // The leading "--" stops notify-send from interpreting a mod-supplied title
  // as an option; the payload is passed verbatim, never evaluated by a shell.
  assert(readFile(dir + "/notify-send.args") ==
    "--\n--title\n$(touch /tmp/phoenix-injection)\n");
  assert(readFile(dir + "/osascript.args") ==
    "-e\ndisplay notification \"line\\n\\\\end\" with title \"a\\\"b\"\n");

  std::printf("desktop notification helpers passed\n");
  return 0;
}
