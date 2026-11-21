#ifndef PHOENIX_GDI_H
#define PHOENIX_GDI_H

/* Native Windows GDI effects for meta-horror / 4th-wall-breaking mods.
 * Ported from Slushi Engine (SlushiWinGDI.hx / WindowsCPP.hx).
 * Each payload is a self-contained C++ function that draws on the desktop
 * using raw GDI. They run on a background thread so the game never lags.
 *
 * The HPPD payloads (phoenix_gdi_hppd.h) are declared at the end of this
 * header so the hxcpp bridge (GdiNative) sees both APIs from one include.
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

/* windows.h defines min()/max() as macros unless NOMINMAX is set, which breaks
 * the std::min call in phoenix_gdi.cpp when this header is seen before
 * hxcpp.h (it defines NOMINMAX too). Pin it here so the header is safe on its
 * own, in either include order. */
#if !defined(NOMINMAX)
#define NOMINMAX
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
#include <condition_variable>
/* std::min lives in <algorithm>; MSVC's STL does not pull it in transitively
 * the way libstdc++ happens to, so it must be included explicitly. Same story
 * for rand(), which the payloads use to pick random coordinates. */
#include <algorithm>
#include <cstdlib>

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

/**
 * Initialize the GDI subsystem (starts the background thread).
 * @return true on success, false if thread creation failed.
 */
bool phoenixGdiInitialize();

/**
 * Shutdown the GDI subsystem (stops the background thread).
 * Wakes up the worker thread and waits for it to finish.
 */
void phoenixGdiShutdown();

/**
 * Update the global elapsed time (in seconds) used by time-varying payloads.
 * @param elapsed Elapsed time in seconds.
 */
void phoenixGdiSetElapsedTime(float elapsed);

/**
 * Pause/resume the GDI thread without destroying it.
 * @param paused true to pause, false to resume.
 */
void phoenixGdiSetPaused(bool paused);

/* ---- Effect registration ---- */

/**
 * Register a GDI effect by name.
 * @param name Effect name (e.g., "DrawIcons", "ScreenGlitches", etc.)
 * @return true on success, false if unknown effect name.
 */
bool phoenixGdiRegisterEffect(const char *name);

/**
 * Unregister a GDI effect by name.
 * @param name Effect name to unregister.
 */
void phoenixGdiUnregisterEffect(const char *name);

/**
 * Enable or disable a registered effect.
 * @param name Effect name.
 * @param enabled true to enable, false to disable.
 */
void phoenixGdiSetEffectEnabled(const char *name, bool enabled);

/**
 * Get whether a registered effect is currently enabled.
 * @param name Effect name.
 * @return true if enabled, false if disabled or not found.
 */
bool phoenixGdiGetEffectEnabled(const char *name);

/**
 * Set the wait time (in milliseconds) between frames for an effect.
 * @param name Effect name.
 * @param waitMs Milliseconds to wait between executions.
 */
void phoenixGdiSetEffectWait(const char *name, float waitMs);

/**
 * Set the custom title text for the SetTitleText effect.
 * @param name Effect name (must be "SetTitleText").
 * @param text UTF-8 text to display on window title bars.
 */
void phoenixGdiSetEffectTitleText(const char *name, const char *text);

/* ---- Individual payload triggers (for one-shot use) ---- */

/**
 * Draw error/warning icons following the mouse cursor (one-shot).
 */
void phoenixGdiDrawIcons();

/**
 * Invert the desktop colors (blink effect, one-shot).
 */
void phoenixGdiScreenBlink();

/**
 * Copy random screen rectangles to random positions (glitch effect, one-shot).
 */
void phoenixGdiScreenGlitches();

/**
 * Recursive StretchBlt tunnel effect (one-shot).
 */
void phoenixGdiScreenTunnel();

/**
 * Shake the screen by blitting with small random offsets (one-shot).
 */
void phoenixGdiScreenShake();

/**
 * Set custom text on all top-level window title bars (one-shot).
 * @param text UTF-8 text to display.
 */
void phoenixGdiSetCustomTitleText(const char *text);

/* ---- HPPD payloads (phoenix_gdi_hppd.h) ---- */
/**
 * The HPPD GDI-only payloads (light + heavy + Death Month) live in
 * phoenix_gdi_hppd.h / phoenix_gdi_hppd_*.cpp. Including it here keeps
 * the hxcpp bridge to a single header. See docs/GDI_HPPD.md.
 */
#include "phoenix_gdi_hppd.h"

#endif /* _WIN32 */
#endif /* PHOENIX_GDI_H */