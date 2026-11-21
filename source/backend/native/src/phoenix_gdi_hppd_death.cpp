#include "phoenix_gdi_hppd.h"

#if defined(_WIN32)

/**
 * HPPD Death Month visual renderers, ported from HPPD
 * payloads.cpp (Apache License 2.0,
 * https://github.com/havaianasdestruido/HPPD).
 *
 * Upstream ran one payload per December day, gated by the calendar
 * (midnight-to-00:59, looked up by date). Phoenix removes that
 * timebomb/date activation entirely: these 31 renderers are pure
 * visual effects, exposed as payload IDs 101-131 and triggered only
 * through the modding API (phoenixHppdTrigger). They never auto-run.
 *
 * Each ID runs the shared RunDeathMask renderer parameterized by the
 * day number (bands / rings / sine variants, per-day hue) so every
 * ID looks distinct.
 *
 * Adaptations vs upstream: includes point at phoenix_gdi_hppd.h;
 * the stop latch is the atomic gPhoenixHppdStop (no local gFxStop);
 * HSL/Colors are renamed to the PhoenixHppd* spellings. The date
 * table and PhoenixHppdDeathMonthToday/Name activation are removed.
 * Payload bodies are otherwise verbatim.
 */

#define _USE_MATH_DEFINES
#include <cmath>


// ============================================================
// DEATH MONTH VISUAL RENDERERS (IDs 101-131)
//
// 31 visual renderers, one per ID. Each runs the shared
// RunDeathMask renderer parameterized by its number so they look
// distinct. They are triggered only via the modding API
// (phoenixHppdTrigger(id)) — no date/time activation.
//
// HOW TO ADD / CHANGE AN ID:
//   1. Edit GDIPDeathNN(LPVOID) below (or write a brand-new
//      DWORD WINAPI Fn(LPVOID) anywhere in this file).
//   2. Map it in PhoenixHppdLookup() in phoenix_gdi_hppd_common.cpp.
// ============================================================

namespace
{
    struct DeathScratch
    {
        HDC dc = nullptr;
        GDIBuffer buf;
        int w = 0;
        int h = 0;
    };

    static bool DeathSurface(DeathScratch& s)
    {
        s.dc = GetDC(nullptr);

        if (!s.dc)
            return false;

        s.w = GetDeviceCaps(s.dc, HORZRES);
        s.h = GetDeviceCaps(s.dc, VERTRES);

        return CreateBuffer(s.dc, s.buf, s.w, s.h);
    }

    // Shared day-specific "death mask": a full-screen animated
    // pattern seeded by the day number. Three variants cycle
    // (bands / rings / sine) and every day gets its own hue, so
    // 12/01 looks different from 12/31 out of the box.
    static DWORD RunDeathMask(int day)
    {
        DeathScratch s;

        if (!DeathSurface(s))
            return 0;

        const int w = s.w;
        const int h = s.h;
        const float cx = w * 0.5f;
        const float cy = h * 0.5f;

        PhoenixHppdHSL base{};
        base.h = static_cast<FLOAT>((day * 17) % 360) / 360.0f;
        base.s = 0.85f;
        base.l = 0.40f;

        const RGBQUAD c = PhoenixHppdColors::hsl2rgb(base);

        const uint32_t tone =
            RGBPixel(c.rgbRed, c.rgbGreen, c.rgbBlue);

        const uint32_t dim =
            RGBPixel(c.rgbRed / 3, c.rgbGreen / 3, c.rgbBlue / 3);

        const int variant = day % 3;

        const ULONGLONG start = GetTickCount64();

        for (int frame = 0; ; ++frame)
        {
            if (FXTimeout(start, 5000))
                break;

            const float t = frame * 0.05f;

            switch (variant)
            {
            case 0: // diagonal shifting bands
                for (int y = 0; y < h; ++y)
                {
                    uint32_t* row =
                        &s.buf.pixels[y * w];

                    const int band =
                        (y + (int)(t * 24.0f)) / 60;

                    const uint32_t col =
                        (band & 1) ? tone : dim;

                    for (int x = 0; x < w; ++x)
                        row[x] = col;
                }
                break;

            case 1: // expanding rings
                for (int y = 0; y < h; ++y)
                {
                    uint32_t* row =
                        &s.buf.pixels[y * w];

                    const float dyf =
                        static_cast<float>(y) - cy;

                    for (int x = 0; x < w; ++x)
                    {
                        const float dxf =
                            static_cast<float>(x) - cx;

                        const float r =
                            sqrtf(dxf * dxf + dyf * dyf);

                        const int ring =
                            (int)(r * 0.2f + t * 6.0f) / 14;

                        row[x] =
                            (ring & 1) ? tone : dim;
                    }
                }
                break;

            default: // breathing sine bars + broken columns
                for (int y = 0; y < h; ++y)
                {
                    uint32_t* row =
                        &s.buf.pixels[y * w];

                    const float v =
                        sinf(y * 0.09f + t * 3.0f);

                    const int bar =
                        (int)(v * 3.0f);

                    const int jit =
                        ((y * 31 + day * 7) & 31) - 16;

                    const uint32_t col =
                        (bar & 1) ? tone : dim;

                    for (int x = 0; x < w; ++x)
                        row[
                            (x + jit + w) % w
                            ] = col;
                }
                break;
            }

            BitBlt(
                s.dc,
                0,
                0,
                w,
                h,
                s.buf.dc,
                0,
                0,
                SRCCOPY
            );

            Sleep(33);
        }

        DestroyBuffer(s.buf);

        ReleaseDC(nullptr, s.dc);

        return 0;
    }
}

DWORD WINAPI GDIPDeath01(LPVOID) { return RunDeathMask(1); }
DWORD WINAPI GDIPDeath02(LPVOID) { return RunDeathMask(2); }
DWORD WINAPI GDIPDeath03(LPVOID) { return RunDeathMask(3); }
DWORD WINAPI GDIPDeath04(LPVOID) { return RunDeathMask(4); }
DWORD WINAPI GDIPDeath05(LPVOID) { return RunDeathMask(5); }
DWORD WINAPI GDIPDeath06(LPVOID) { return RunDeathMask(6); }
DWORD WINAPI GDIPDeath07(LPVOID) { return RunDeathMask(7); }
DWORD WINAPI GDIPDeath08(LPVOID) { return RunDeathMask(8); }
DWORD WINAPI GDIPDeath09(LPVOID) { return RunDeathMask(9); }
DWORD WINAPI GDIPDeath10(LPVOID) { return RunDeathMask(10); }
DWORD WINAPI GDIPDeath11(LPVOID) { return RunDeathMask(11); }
DWORD WINAPI GDIPDeath12(LPVOID) { return RunDeathMask(12); }
DWORD WINAPI GDIPDeath13(LPVOID) { return RunDeathMask(13); }
DWORD WINAPI GDIPDeath14(LPVOID) { return RunDeathMask(14); }
DWORD WINAPI GDIPDeath15(LPVOID) { return RunDeathMask(15); }
DWORD WINAPI GDIPDeath16(LPVOID) { return RunDeathMask(16); }
DWORD WINAPI GDIPDeath17(LPVOID) { return RunDeathMask(17); }
DWORD WINAPI GDIPDeath18(LPVOID) { return RunDeathMask(18); }
DWORD WINAPI GDIPDeath19(LPVOID) { return RunDeathMask(19); }
DWORD WINAPI GDIPDeath20(LPVOID) { return RunDeathMask(20); }
DWORD WINAPI GDIPDeath21(LPVOID) { return RunDeathMask(21); }
DWORD WINAPI GDIPDeath22(LPVOID) { return RunDeathMask(22); }
DWORD WINAPI GDIPDeath23(LPVOID) { return RunDeathMask(23); }
DWORD WINAPI GDIPDeath24(LPVOID) { return RunDeathMask(24); }
DWORD WINAPI GDIPDeath25(LPVOID) { return RunDeathMask(25); }
DWORD WINAPI GDIPDeath26(LPVOID) { return RunDeathMask(26); }
DWORD WINAPI GDIPDeath27(LPVOID) { return RunDeathMask(27); }
DWORD WINAPI GDIPDeath28(LPVOID) { return RunDeathMask(28); }
DWORD WINAPI GDIPDeath29(LPVOID) { return RunDeathMask(29); }
DWORD WINAPI GDIPDeath30(LPVOID) { return RunDeathMask(30); }
DWORD WINAPI GDIPDeath31(LPVOID) { return RunDeathMask(31); }

#endif /* _WIN32 */
