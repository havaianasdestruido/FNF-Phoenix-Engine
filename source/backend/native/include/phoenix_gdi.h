#ifndef PHOENIX_GDI_H
#define PHOENIX_GDI_H

/* Native Windows GDI effects for meta-horror / 4th-wall-breaking mods.
 * Ported from Slushi Engine (SlushiWinGDI.hx / WindowsCPP.hx).
 * Each payload is a self-contained C++ function that draws on the desktop
 * using raw GDI. They run on a background thread so the game never lags.
 */

#if defined(_WIN32)

/* hxcpp can include native metadata before its own target-architecture
 * defines. Seed the macro Windows headers expect so winnt.h does not emit
 * "No Target Architecture" when this header is seen first. */
#if !defined(_AMD64_) && !defined(_X86_) && !defined(_ARM_) && !defined(_ARM64_)
#if defined(_M_X64) || defined(__x86_64__)
#define _AMD64_
#elif defined(_M_IX86) || defined(__i386__)
#define _X86_
#elif defined(_M_ARM64) || defined(__aarch64__)
#define _ARM64_
#elif defined(_M_ARM) || defined(__arm__)
#define _ARM_
#endif
#endif

#include <windows.h>
#include <dwmapi.h>
#include <winuser.h>
#include <string>
#include <vector>
#include <map>
#include <thread>
#include <atomic>
#include <mutex>
#include <chrono>

#if defined(_MSC_VER)
#pragma comment(lib, "dwmapi.lib")
#pragma comment(lib, "user32.lib")
#pragma comment(lib, "gdi32.lib")
#pragma comment(lib, "shell32.lib")
#pragma comment(lib, "ntdll.lib")
#endif

#if defined(__GNUC__) || defined(__clang__)
#define PHOENIX_GDI_UNUSED __attribute__((unused))
#else
#define PHOENIX_GDI_UNUSED
#endif

/* ------------------------------------------------------------------------- */
/*                                    API                                    */
/* ------------------------------------------------------------------------- */

/** Initialize the GDI subsystem (starts the background thread). */
bool phoenixGdiInitialize();

/** Shutdown the GDI subsystem (stops the background thread). */
void phoenixGdiShutdown();

/** Update the global elapsed time (in frames) used by time-varying payloads. */
void phoenixGdiSetElapsedTime(float elapsed);

/** Pause/resume the GDI thread without destroying it. */
void phoenixGdiSetPaused(bool paused);

/* ---- Effect registration ---- */

/** Register a GDI effect by name. Returns true on success. */
bool phoenixGdiRegisterEffect(const char *name);

/** Unregister a GDI effect by name. */
void phoenixGdiUnregisterEffect(const char *name);

/** Enable or disable a registered effect. */
void phoenixGdiSetEffectEnabled(const char *name, bool enabled);

/** Set the wait time (in milliseconds) between frames for an effect. */
void phoenixGdiSetEffectWait(const char *name, float waitMs);

/* ---- Individual payload triggers (for one-shot use) ---- */

/** Draw error/warning icons following the mouse cursor. */
void phoenixGdiDrawIcons();

/** Invert the desktop colors (blink effect). */
void phoenixGdiScreenBlink();

/** Copy random screen rectangles to random positions (glitch effect). */
void phoenixGdiScreenGlitches();

/** Recursive StretchBlt tunnel effect. */
void phoenixGdiScreenTunnel();

/** Shake the screen by blitting with small random offsets. */
void phoenixGdiScreenShake();

/** Set custom text on all top-level window title bars. */
void phoenixGdiSetCustomTitleText(const char *text);

#endif /* _WIN32 */
#endif /* PHOENIX_GDI_H */