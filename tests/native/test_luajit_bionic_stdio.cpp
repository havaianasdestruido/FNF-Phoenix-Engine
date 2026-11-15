/*
 * Behaviour of the bionic stdio shim that lets Android link LuaJIT at API 21.
 *
 * hxluajit ships prebuilt Android LuaJIT libraries that reference the
 * `stdin`/`stdout`/`stderr` stdio variables. Bionic only exports those from
 * API 23 on (bionic's libc.map.txt marks them `introduced=23`) while the
 * engine supports API 21, so the Android link fails with
 *
 *     ld.lld: error: undefined symbol: stdout
 *     ld.lld: error: undefined symbol: stdin
 *     ld.lld: error: undefined symbol: stderr
 *     clang++: error: linker command failed with exit code 1
 *
 * The shim in source/backend/native/src/phoenix_luajit_bionic_stdio.cpp
 * defines the three variables on top of bionic's `FILE __sF[3]` stream array,
 * which has existed since API 1. tests/native/run.sh compiles that translation
 * unit with the Android defines, renames the three stream symbols with
 * objcopy (so they cannot shadow the host libc's, which this test needs for
 * its own output) and links it in here. The checks are:
 *
 *   Android build  (--object <o> --source <cpp> --include <dir>): the object
 *       defines all three streams, and the emitted assembly takes each of them
 *       from a distinct `__sF` entry;
 *   other builds   (--object <o> --expect-none): the object defines none of
 *       them, so desktop iOS/web links keep the platform libc's streams.
 *
 * Run by tests/native/run.sh.
 */
#include "phoenix_luajit_bionic_stdio.h"

#include <cassert>
#include <cstdio>
#include <cstring>
#include <string>

#ifndef PHOENIX_TEST_SHIM_OBJECT
#error "PHOENIX_TEST_SHIM_OBJECT must point at the compiled shim object"
#endif
#ifndef PHOENIX_TEST_SHIM_SOURCE
#error "PHOENIX_TEST_SHIM_SOURCE must point at the shim translation unit"
#endif
#ifndef PHOENIX_TEST_INCLUDE_DIR
#error "PHOENIX_TEST_INCLUDE_DIR must point at the shim include folder"
#endif

/*
 * When the shim object is linked in (after objcopy renamed its streams), its
 * `__sF` reference must resolve. On a device that symbol is bionic's stream
 * array; here a local stand-in with the same three-slot shape lets the test
 * check that each stream really lands on a different slot.
 */
#include <cstdio>
extern "C"
{
// Same stride as the shim's FILE (the shim is compiled for Android with the
// host <stdio.h> here, so both translations units agree on the element size).
char __sF[3 * sizeof(FILE)] = {};
#if defined(PHOENIX_TEST_SHIM_LINKED)
extern void* phoenix_test_shim_stdin;
extern void* phoenix_test_shim_stdout;
extern void* phoenix_test_shim_stderr;
#endif
}

static std::string run(const std::string& command)
{
  std::string output;
  FILE* pipe = popen(command.c_str(), "r");
  if (pipe == NULL) return output;
  char buffer[4096];
  while (fgets(buffer, sizeof(buffer), pipe) != NULL) output += buffer;
  pclose(pipe);
  return output;
}

/** Whether `nm` output *defines* (rather than imports) the given symbol. */
static bool defines(const std::string& nmOutput, const char* symbol)
{
  return nmOutput.find(std::string(" ") + symbol + "\n") != std::string::npos;
}

int main(int argc, char** argv)
{
  bool expectDefinitions = true;
  for (int i = 1; i < argc; ++i)
    if (std::string(argv[i]) == "--expect-none") expectDefinitions = false;

  // `nm --defined-only` leaves imports (`U`) out: the Android link error was
  // an *undefined* symbol, so only definitions count as a fix.
  const std::string symbols = run("nm --defined-only --extern-only '" +
                                  std::string(PHOENIX_TEST_SHIM_OBJECT) + "' 2>/dev/null");
  const char* streams[] = {"stdin", "stdout", "stderr"};

  if (!expectDefinitions)
  {
    for (const char* stream : streams)
      assert(!defines(symbols, stream) &&
             "non-Android / opted-out builds must not define the stdio streams");
    assert(phoenixLuajitBionicStdio() == 0);
    std::printf("bionic stdio shim behaviour: OK (defines no streams)\n");
    return 0;
  }

  for (const char* stream : streams)
    assert(defines(symbols, stream) &&
           "the Android shim must define stdin/stdout/stderr");

  // On bionic the variables must point at the stream array, not at a private
  // FILE: __sF is API 1, the variables are API 23. The host libc has a
  // different layout, so check what the shim emitted for Android instead:
  //   stdin  -> __sF + 0
  //   stdout -> __sF + sizeof(FILE)
  //   stderr -> __sF + 2 * sizeof(FILE)
  const std::string assembly =
      run("cc -std=c++11 -D__ANDROID__ -DLUA_ALLOWED -I" +
          std::string(PHOENIX_TEST_INCLUDE_DIR) + " -S -o - '" +
          std::string(PHOENIX_TEST_SHIM_SOURCE) + "' 2>/dev/null");
  assert(!assembly.empty() && "the shim must compile for Android");

  size_t references = 0;
  for (size_t pos = assembly.find("__sF"); pos != std::string::npos;
       pos = assembly.find("__sF", pos + 1))
    ++references;
  assert(references >= 3 && "each stream must be a separate __sF entry");
  assert(assembly.find("__sF\n") != std::string::npos &&
         "stdin must be the first __sF entry");

  assert(phoenixLuajitBionicStdio() == 1);

#if defined(PHOENIX_TEST_SHIM_LINKED)
  // The linked pointers must be the bionic slots: stdin, stdout, stderr.
  const char* slots = reinterpret_cast<const char*>(__sF);
  assert(reinterpret_cast<const char*>(phoenix_test_shim_stdin) == slots);
  assert(reinterpret_cast<const char*>(phoenix_test_shim_stdout) == slots + sizeof(FILE));
  assert(reinterpret_cast<const char*>(phoenix_test_shim_stderr) == slots + 2 * sizeof(FILE));
#endif

  std::printf("bionic stdio shim behaviour: OK (defines stdin/stdout/stderr)\n");
  return 0;
}
