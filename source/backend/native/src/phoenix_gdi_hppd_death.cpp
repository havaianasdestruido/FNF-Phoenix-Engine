#include "phoenix_gdi_hppd.h"

#if defined(_WIN32)

/**
 * HPPD Death Month payloads (December), ported from HPPD
 * payloads.cpp (Apache License 2.0,
 * https://github.com/havaianasdestruido/HPPD).
 *
 * Every December day runs the shared RunDeathMask renderer
 * parameterized by the day number (bands / rings / sine variants,
 * per-day hue). Exposed in Phoenix as IDs 101-131 (day 1..31) and
 * serialized with the other heavy payloads.
 *
 * Adaptations vs upstream: includes point at phoenix_gdi_hppd.h;
 * the stop latch is the atomic gPhoenixHppdStop (no local gFxStop);
 * DeathMonthEntry/gDeathMonth/DeathMonthToday/DeathMonthName and
 * HSL/Colors are renamed to the PhoenixHppd* spellings. Payload
 * bodies are otherwise verbatim.
 */

#define _USE_MATH_DEFINES
#include <cmath>


// ============================================================
// DEATH MONTH (DECEMBER)
//
// Every December day, from midnight to 00:59, the demo runs a
// dedicated payload for that exact day, independent of the
// gPayloads catalog. Each day has its own GDIPDeathNN function;
// today's payload is looked up by PhoenixHppdDeathMonthToday() in main.cpp.
//
// HOW TO ADD / CHANGE A DAY:
//   1. Edit GDIPDeathNN(LPVOID) below (or write a brand-new
//      DWORD WINAPI Fn(LPVOID) anywhere in this file).
//   2. Map/add the { day, L"label", ms, Fn } row in gPhoenixHppdDeathMonth[].
// That's it. Days without a row, or any moment outside the
// midnight-to-00:01 window, skip silently.
//
// Every day currently runs the shared RunDeathMask renderer,
// parameterized by the day number so each day looks distinct.
// Replace any day's body with custom code when you want more.
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

// ============================================================
// Table: December day (1..31) -> its dedicated payload.
// Add/remove rows freely; missing days skip silently.
// ============================================================

const PhoenixHppdDeathEntry gPhoenixHppdDeathMonth[] =
{
    {  1, L"12/01 - Death Mask",     5000, GDIPDeath01 },
    {  2, L"12/02 - Death Mask",     5000, GDIPDeath02 },
    {  3, L"12/03 - Death Mask",     5000, GDIPDeath03 },
    {  4, L"12/04 - Death Mask",     5000, GDIPDeath04 },
    {  5, L"12/05 - Death Mask",     5000, GDIPDeath05 },
    {  6, L"12/06 - Death Mask",     5000, GDIPDeath06 },
    {  7, L"12/07 - Death Mask",     5000, GDIPDeath07 },
    {  8, L"12/08 - Death Mask",     5000, GDIPDeath08 },
    {  9, L"12/09 - Death Mask",     5000, GDIPDeath09 },
    { 10, L"12/10 - Death Mask",     5000, GDIPDeath10 },
    { 11, L"12/11 - Death Mask",     5000, GDIPDeath11 },
    { 12, L"12/12 - Death Mask",     5000, GDIPDeath12 },
    { 13, L"12/13 - Death Mask",     5000, GDIPDeath13 },
    { 14, L"12/14 - Death Mask",     5000, GDIPDeath14 },
    { 15, L"12/15 - Death Mask",     5000, GDIPDeath15 },
    { 16, L"12/16 - Death Mask",     5000, GDIPDeath16 },
    { 17, L"12/17 - Death Mask",     5000, GDIPDeath17 },
    { 18, L"12/18 - Death Mask",     5000, GDIPDeath18 },
    { 19, L"12/19 - Death Mask",     5000, GDIPDeath19 },
    { 20, L"12/20 - Death Mask",     5000, GDIPDeath20 },
    { 21, L"12/21 - Death Mask",     5000, GDIPDeath21 },
    { 22, L"12/22 - Death Mask",     5000, GDIPDeath22 },
    { 23, L"12/23 - Death Mask",     5000, GDIPDeath23 },
    { 24, L"12/24 - Death Mask",     5000, GDIPDeath24 },
    { 25, L"12/25 - Death Mask",     5000, GDIPDeath25 },
    { 26, L"12/26 - Death Mask",     5000, GDIPDeath26 },
    { 27, L"12/27 - Death Mask",     5000, GDIPDeath27 },
    { 28, L"12/28 - Death Mask",     5000, GDIPDeath28 },
    { 29, L"12/29 - Death Mask",     5000, GDIPDeath29 },
    { 30, L"12/30 - Death Mask",     5000, GDIPDeath30 },
    { 31, L"12/31 - Death Mask",     5000, GDIPDeath31 },
};

const int gPhoenixHppdDeathMonthCount =
    static_cast<int>(
        sizeof(gPhoenixHppdDeathMonth) /
        sizeof(gPhoenixHppdDeathMonth[0])
    );

// Returns the active entry (December 00:00-00:59) or nullptr.
const PhoenixHppdDeathEntry* PhoenixHppdDeathMonthToday()
{
    SYSTEMTIME st;
    GetLocalTime(&st);

    if (st.wMonth != 12)
        return nullptr;

    if (st.wHour != 0)
        return nullptr;

    const int d = st.wDay;

    for (int i = 0; i < gPhoenixHppdDeathMonthCount; ++i)
        if (gPhoenixHppdDeathMonth[i].day == d)
            return &gPhoenixHppdDeathMonth[i];

    return nullptr;
}

// Short banner shown at the demo start while Death Month is on.
const char* PhoenixHppdDeathMonthName()
{
    return PhoenixHppdDeathMonthToday() ? "DEATH MONTH" : nullptr;
}

#endif /* _WIN32 */
