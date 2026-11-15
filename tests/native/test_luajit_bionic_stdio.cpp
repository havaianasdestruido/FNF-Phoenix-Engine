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
 * unit against a model of bionic's `<stdio.h>` (NOT the host libc: glibc
 * declares the streams as ordinary variables, while bionic makes them macros
 * over `__sF` below API 23, and compiling against glibc hides exactly the
 * failure this test exists to catch). It then renames the three stream symbols
 * with objcopy (so they cannot shadow the host libc's, which this test needs
 * for its own output) and links the object in here. The checks are:
 *
 *   Android, API 21 (--object <o> --source <cpp> --include <dir>): the object
 *       defines all three streams (each taken from a distinct `__sF` entry)
 *       and LuaJIT's fseeko64/ftello64 wrappers;
 *   everything else (--object <o> --expect-none): API 23+, the
 *       NO_LUAJIT_BIONIC_STDIO escape hatch and non-Android builds define none
 *       of them, so those links keep their platform libc's streams.
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
#ifndef PHOENIX_TEST_BIONIC_MODEL
#error "PHOENIX_TEST_BIONIC_MODEL must point at the model bionic include folder"
#endif

/*
 * When the shim object is linked in (after objcopy renamed its streams), its
 * `__sF` reference must resolve. On a device that symbol is bionic's stream
 * array; here a local stand-in with the same three-slot shape lets the test
 * check that each stream really lands on a different slot.
 */
/*
 * The shim is compiled against the model of bionic's <stdio.h>, whose
 * `struct __sFILE` is `PHOENIX_TEST_BIONIC_FILE_BYTES` bytes; this test is
 * compiled against the host libc, whose FILE has a different size. The
 * stand-in therefore uses the model's stride, passed in from run.sh, so the
 * linked pointers land on the slots the shim emitted.
 */
#include <cstdio>
extern "C"
{
char __sF[3 * PHOENIX_TEST_BIONIC_FILE_BYTES] = {};
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
  // The shim provides the three streams *and* LuaJIT's fseeko64/ftello64
  // (bionic only exports those from API 24). All five belong to the same fix.
  const char* streams[] = {"stdin", "stdout", "stderr"};
  const char* seeks[] = {"fseeko64", "ftello64"};

  if (!expectDefinitions)
  {
    for (const char* stream : streams)
      assert(!defines(symbols, stream) &&
             "non-Android / opted-out builds must not define the stdio streams");
    for (const char* seek : seeks)
      assert(!defines(symbols, seek) &&
             "non-Android / opted-out builds must not define the 64-bit seek shims");
    assert(phoenixLuajitBionicStdio() == 0);
    std::printf("bionic stdio shim behaviour: OK (defines no streams)\n");
    return 0;
  }

  for (const char* stream : streams)
    assert(defines(symbols, stream) &&
           "the Android shim must define stdin/stdout/stderr");
  for (const char* seek : seeks)
    assert(defines(symbols, seek) &&
           "the Android shim must define fseeko64/ftello64 (LuaJIT's lib_io.c)");

  // On bionic the variables must point at the stream array, not at a private
  // FILE: __sF is API 1, the variables are API 23. The shim is recompiled to
  // assembly against the *model* of bionic's <stdio.h> (never the host libc,
  // which declares the streams as ordinary variables) and the emitted slots
  // are inspected:
  //   stdin  -> __sF + 0
  //   stdout -> __sF + sizeof(FILE)
  //   stderr -> __sF + 2 * sizeof(FILE)
  const std::string assembly =
      run("${CXX:-cc} -std=c++11 -D__ANDROID__ -D__ANDROID_API__=21 -I" +
          std::string(PHOENIX_TEST_BIONIC_MODEL) + " -I" +
          std::string(PHOENIX_TEST_INCLUDE_DIR) + " -S -o - '" +
          std::string(PHOENIX_TEST_SHIM_SOURCE) + "' 2>/dev/null");
  assert(!assembly.empty() && "the shim must compile against bionic's stdio.h");

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
  const size_t stride = PHOENIX_TEST_BIONIC_FILE_BYTES;
  assert(reinterpret_cast<const char*>(phoenix_test_shim_stdin) == slots);
  assert(reinterpret_cast<const char*>(phoenix_test_shim_stdout) == slots + stride);
  assert(reinterpret_cast<const char*>(phoenix_test_shim_stderr) == slots + 2 * stride);
#endif

  std::printf("bionic stdio shim behaviour: OK (defines stdin/stdout/stderr)\n");
  return 0;
}
