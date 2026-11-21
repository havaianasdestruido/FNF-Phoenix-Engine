#include "phoenix_gdi_hppd.h"

#if defined(_WIN32)

/**
 * HPPD heavy payloads (full-screen per-pixel renderers), ported from
 * HPPD gdi/heavy.cpp (Apache License 2.0,
 * https://github.com/havaianasdestruido/HPPD).
 *
 * Payloads 1, 2, 5-11, 13-15, 17, 19-24, 40, 48, 50-63. Each runs for
 * about 5 seconds (or a fixed frame count) and aborts on ESC / stop.
 * Heavy payloads serialize through the heavy mutex in
 * phoenix_gdi_hppd_common.cpp (HPPD's gHeavySlot).
 *
 * Adaptations vs upstream: includes point at phoenix_gdi_hppd.h (which
 * merges payloads.h + gdibuffer.h + fxcache.h + colors.h + seed.h);
 * SeedGet/SeedRand/GDISurface/ShiftHSL/PackRGB are renamed to the
 * PhoenixHppd* spellings; the stop latch is the atomic
 * gPhoenixHppdStop instead of volatile gFxStop. Payload bodies are
 * otherwise verbatim.
 */

#ifdef _MSC_VER
#pragma comment(lib, "Msimg32.lib")
#endif

#define _USE_MATH_DEFINES
#include <cmath>
#include <cstdlib>
#include <vector>

// ============================================================
// HEAVY PAYLOADS
//
// Full-screen per-pixel renderers (fractals, Julia, reaction
// diffusion, ...). gHeavySlot in start.cpp keeps these running
// one at a time.
//
//  1, 2, 5-11  original visual GDI effects.
//  13-24       fast visual GDI effects (5s, ESC aborts).
//  40, 48      ported GDI-effects dump.
//  50-63       GDI demoscene FX packs (per-pixel shaders).
// ============================================================

// ============================================================
// PAYLOAD 1
// Screen feedback / microscopic distortion
// ============================================================
DWORD WINAPI GDIPayload1(LPVOID)
{
    const PhoenixHppdSeedVariant& sd = PhoenixHppdSeedGet(1);
    srand(PhoenixHppdSeedRand(1));

    HDC dc = GetDC(NULL);

    if (!dc)
        return 0;

    const int w = GetSystemMetrics(SM_CXSCREEN);
    const int h = GetSystemMetrics(SM_CYSCREEN);

    HDC dcCopy = CreateCompatibleDC(dc);

    if (!dcCopy)
    {
        ReleaseDC(NULL, dc);
        return 0;
    }

    HBITMAP bmp = CreateCompatibleBitmap(dc, w, h);

    if (!bmp)
    {
        DeleteDC(dcCopy);
        ReleaseDC(NULL, dc);
        return 0;
    }

    HGDIOBJ oldBmp = SelectObject(dcCopy, bmp);

    for (int frame = 0; frame < 900; ++frame)
    {
        if (FXAbort())
            break;

        StretchBlt(
            dcCopy,
            (rand() % 3) * sd.dir,
            (rand() % 3) * sd.dir,
            w,
            h,
            dc,
            (rand() % 3) * sd.dir,
            (rand() % 3) * sd.dir,
            w,
            h,
            SRCCOPY
        );

        StretchBlt(
            dc,
            0,
            0,
            w,
            h,
            dcCopy,
            0,
            0,
            w,
            h,
            SRCCOPY
        );

        Sleep(rand() % (25 - sd.amp / 2));

        /*if (rand() % 25 == 24)
        {
            RedrawWindow(
                NULL,
                NULL,
                NULL,
                RDW_INVALIDATE |
                RDW_UPDATENOW |
                RDW_ALLCHILDREN
            );
        }*/
    }

    SelectObject(dcCopy, oldBmp);
    DeleteObject(bmp);
    DeleteDC(dcCopy);
    ReleaseDC(NULL, dc);

    return 0;
}

// ============================================================
// PAYLOAD 2
// Pixelation / recursive zoom
// ============================================================
DWORD WINAPI GDIPayload2(LPVOID)
{
    const PhoenixHppdSeedVariant& sd = PhoenixHppdSeedGet(2);
    srand(PhoenixHppdSeedRand(2));

    HDC dc = GetDC(NULL);

    if (!dc)
        return 0;

    const int w = GetSystemMetrics(SM_CXSCREEN);
    const int h = GetSystemMetrics(SM_CYSCREEN);

    HDC dcCopy = CreateCompatibleDC(dc);

    if (!dcCopy)
    {
        ReleaseDC(NULL, dc);
        return 0;
    }

    HBITMAP bmp = CreateCompatibleBitmap(dc, w, h);

    if (!bmp)
    {
        DeleteDC(dcCopy);
        ReleaseDC(NULL, dc);
        return 0;
    }

    HGDIOBJ oldBmp = SelectObject(dcCopy, bmp);

    for (int frame = 0; frame < 600; ++frame)
    {
        if (FXAbort())
            break;

        SetStretchBltMode(dcCopy, COLORONCOLOR);
        SetStretchBltMode(dc, COLORONCOLOR);

        StretchBlt(
            dcCopy,
            0,
            0,
            std::max(1, w / (3 - sd.dir)),
            std::max(1, h / (3 - sd.dir)),
            dc,
            0,
            0,
            w,
            h,
            SRCCOPY
        );

        StretchBlt(
            dc,
            0,
            0,
            w,
            h,
            dcCopy,
            0,
            0,
            std::max(1, w / (3 - sd.dir)),
            std::max(1, h / (3 - sd.dir)),
            SRCCOPY
        );

        if (rand() % 5 == 4)
        {
            StretchBlt(
                dc,
                1,
                1,
                w,
                h,
                dc,
                0,
                0,
                w,
                h,
                SRCAND
            );
        }
    }

    SelectObject(dcCopy, oldBmp);
    DeleteObject(bmp);
    DeleteDC(dcCopy);
    ReleaseDC(NULL, dc);

    return 0;
}

// ============================================================
// PAYLOAD 5
// Alpha feedback / motion blur
// ============================================================
DWORD WINAPI GDIPayload5(LPVOID)
{
    const PhoenixHppdSeedVariant& sd = PhoenixHppdSeedGet(5);
    srand(PhoenixHppdSeedRand(5));

    HDC dc = GetDC(NULL);

    if (!dc)
        return 0;

    const int w = GetSystemMetrics(SM_CXSCREEN);
    const int h = GetSystemMetrics(SM_CYSCREEN);

    HDC dcCopy = CreateCompatibleDC(dc);

    if (!dcCopy)
    {
        ReleaseDC(NULL, dc);
        return 0;
    }

    BITMAPINFO bmpi{};
    bmpi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    bmpi.bmiHeader.biWidth = w;
    bmpi.bmiHeader.biHeight = -h;
    bmpi.bmiHeader.biPlanes = 1;
    bmpi.bmiHeader.biBitCount = 32;
    bmpi.bmiHeader.biCompression = BI_RGB;

    void* bits = nullptr;

    HBITMAP bmp = CreateDIBSection(
        dc,
        &bmpi,
        DIB_RGB_COLORS,
        &bits,
        NULL,
        0
    );

    if (!bmp)
    {
        DeleteDC(dcCopy);
        ReleaseDC(NULL, dc);
        return 0;
    }

    HGDIOBJ oldBmp = SelectObject(dcCopy, bmp);

    BLENDFUNCTION blur{};
    blur.BlendOp = AC_SRC_OVER;
    blur.BlendFlags = 0;
    blur.SourceConstantAlpha = 10;
    blur.AlphaFormat = 0;

    for (int frame = 0; frame < 600; ++frame)
    {
        if (FXAbort())
            break;

        BitBlt(
            dcCopy,
            (rand() % 10) * sd.dir,
            (rand() % 12) * sd.dir,
            w,
            h,
            dc,
            -(rand() % 10),
            -(rand() % 12),
            SRCCOPY
        );

        AlphaBlend(
            dc,
            0,
            0,
            w,
            h,
            dcCopy,
            0,
            0,
            w,
            h,
            blur
        );

        //Sleep(rand() % 25);
    }

    SelectObject(dcCopy, oldBmp);
    DeleteObject(bmp);
    DeleteDC(dcCopy);
    ReleaseDC(NULL, dc);

    return 0;
}

// ============================================================
// PAYLOAD 6
// Hue displacement
// ============================================================
DWORD WINAPI GDIPayload6(LPVOID)
{
    const PhoenixHppdSeedVariant& sd = PhoenixHppdSeedGet(6);

    HDC dc = GetDC(NULL);

    if (!dc)
        return 0;

    const int w = GetSystemMetrics(SM_CXSCREEN);
    const int h = GetSystemMetrics(SM_CYSCREEN);

    HDC dcCopy = CreateCompatibleDC(dc);

    if (!dcCopy)
    {
        ReleaseDC(NULL, dc);
        return 0;
    }

    BITMAPINFO bi{};
    bi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    bi.bmiHeader.biWidth = w;
    bi.bmiHeader.biHeight = -h;
    bi.bmiHeader.biPlanes = 1;
    bi.bmiHeader.biBitCount = 32;
    bi.bmiHeader.biCompression = BI_RGB;

    uint32_t* pixels = nullptr;

    HBITMAP bmp = CreateDIBSection(
        dc,
        &bi,
        DIB_RGB_COLORS,
        reinterpret_cast<void**>(&pixels),
        NULL,
        0
    );

    if (!bmp || !pixels)
    {
        if (bmp)
            DeleteObject(bmp);

        DeleteDC(dcCopy);
        ReleaseDC(NULL, dc);
        return 0;
    }

    HGDIOBJ oldBmp = SelectObject(dcCopy, bmp);

    // RAM cache (reused every frame, allocated once): the
    // per-column wave table is refilled per frame below, but
    // the buffer itself no longer allocates per frame.
    std::vector<int> wave_x(w);

    int t = 0;

    for (int frame = 0; frame < 250; ++frame)
    {
        if (FXAbort())
            break;

        // Repaint the whole screen every 4th frame only.
        if ((frame & 3) != 0)
        {
            Sleep(1);
            continue;
        }

        BitBlt(
            dcCopy,
            0,
            0,
            w,
            h,
            dc,
            0,
            0,
            SRCCOPY
        );

        // Bolt optimization: Extract trig calculation of 'wave' out of per-pixel loops.
        // Avoids redundant w * h trig calls, reducing to w calls per frame.
        // (wave_x itself is allocated once in RAM before the frame loop.)
        for (int x = 0; x < w; ++x)
        {
            wave_x[x] =
                static_cast<int>(
                    std::sin(
                        (x + t * 4 + sd.phase) * 0.025
                    ) * (32 + sd.amp / 2)
                );
        }

        for (int y = 0; y < h; ++y)
        {
            for (int x = 0; x < w; ++x)
            {
                const int i = y * w + x;

                pixels[i] =
                    PhoenixHppdShiftHSL(
                        pixels[i],
                        wave_x[x] / 255.0f * sd.dir,
                        0.0f,
                        0.0f
                    );
            }
        }

        BitBlt(
            dc,
            0,
            0,
            w,
            h,
            dcCopy,
            0,
            0,
            SRCCOPY
        );

        ++t;
    }

    SelectObject(dcCopy, oldBmp);
    DeleteObject(bmp);
    DeleteDC(dcCopy);
    ReleaseDC(NULL, dc);

    return 0;
}

// ============================================================
// PAYLOAD 7
// Plasma hue effect
// ============================================================
DWORD WINAPI GDIPayload7(LPVOID)
{
    const PhoenixHppdSeedVariant& sd = PhoenixHppdSeedGet(7);

    HDC dc = GetDC(NULL);

    if (!dc)
        return 0;

    const int w = GetSystemMetrics(SM_CXSCREEN);
    const int h = GetSystemMetrics(SM_CYSCREEN);

    HDC dcCopy = CreateCompatibleDC(dc);

    if (!dcCopy)
    {
        ReleaseDC(NULL, dc);
        return 0;
    }

    BITMAPINFO bi{};
    bi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    bi.bmiHeader.biWidth = w;
    bi.bmiHeader.biHeight = -h;
    bi.bmiHeader.biPlanes = 1;
    bi.bmiHeader.biBitCount = 32;
    bi.bmiHeader.biCompression = BI_RGB;

    uint32_t* pixels = nullptr;

    HBITMAP bmp = CreateDIBSection(
        dc,
        &bi,
        DIB_RGB_COLORS,
        reinterpret_cast<void**>(&pixels),
        NULL,
        0
    );

    if (!bmp || !pixels)
    {
        if (bmp)
            DeleteObject(bmp);

        DeleteDC(dcCopy);
        ReleaseDC(NULL, dc);
        return 0;
    }

    HGDIOBJ oldBmp = SelectObject(dcCopy, bmp);

    // RAM cache: three of the four plasma terms never change
    // between frames - sinX depends only on x, sinY only on y,
    // sinDiag only on (x + y) and sinRadial only on the pixel's
    // distance from the origin. Compute every sin()/sqrt()
    // ONCE here (w + h + (w + h) + w*h evaluations) and read
    // them back per frame, instead of redoing 4 trig calls +
    // 1 sqrt for every pixel of every frame. The cached values
    // use the exact same double expressions as the old inner
    // loop, so the picture is bit-identical.
    std::vector<double> sinX(w);
    std::vector<double> sinY(h);
    std::vector<double> sinDiag(w + h);
    std::vector<double> sinRadial(
        static_cast<size_t>(w) * static_cast<size_t>(h)
    );

    for (int x = 0; x < w; ++x)
        sinX[x] = std::sin((x + sd.phase) / (16.0 - sd.amp));

    for (int y = 0; y < h; ++y)
        sinY[y] = std::sin((y + sd.phase) / (8.0 - sd.amp / 2));

    for (int s = 0; s < w + h; ++s)
        sinDiag[s] = std::sin((s + sd.phase) / 16.0);

    for (int y = 0; y < h; ++y)
    {
        for (int x = 0; x < w; ++x)
        {
            sinRadial[static_cast<size_t>(y) * w + x] =
                std::sin(
                    std::sqrt(
                        static_cast<double>(
                            x * x + y * y
                            )
                    ) / (8.0 - sd.amp / 2)
                );
        }
    }

    int t = 0;

    for (int frame = 0; frame < 220; ++frame)
    {
        if (FXAbort())
            break;

        // Repaint the whole screen every 4th frame only.
        if ((frame & 3) != 0)
        {
            Sleep(1);
            continue;
        }

        BitBlt(
            dcCopy,
            0,
            0,
            w,
            h,
            dc,
            0,
            0,
            SRCCOPY
        );

        for (int y = 0; y < h; ++y)
        {
            for (int x = 0; x < w; ++x)
            {
                const int i = y * w + x;

                // All four trig terms come from the RAM
                // cache built before the frame loop.
                double fx =
                    (
                        t +
                        t * sinX[x] +
                        t +
                        t * sinY[y] +
                        t +
                        t * sinDiag[x + y] +
                        t +
                        t * sinRadial[i]
                        ) / 4.0;

                int wave =
                    static_cast<int>(
                        std::sin(fx * 0.02) * 50.0
                        );

                pixels[i] =
                    PhoenixHppdShiftHSL(
                        pixels[i],
                        -wave / 255.0f * sd.dir,
                        0.0f,
                        0.0f
                    );
            }
        }

        BitBlt(
            dc,
            0,
            0,
            w,
            h,
            dcCopy,
            0,
            0,
            SRCCOPY
        );

        ++t;
    }

    SelectObject(dcCopy, oldBmp);
    DeleteObject(bmp);
    DeleteDC(dcCopy);
    ReleaseDC(NULL, dc);

    return 0;
}

// ============================================================
// PAYLOAD 8
// Mandelbrot-inspired RGB distortion
// ============================================================
DWORD WINAPI GDIPayload8(LPVOID)
{
    const PhoenixHppdSeedVariant& sd = PhoenixHppdSeedGet(8);

    HDC dc = GetDC(NULL);

    if (!dc)
        return 0;

    const int w = GetSystemMetrics(SM_CXSCREEN);
    const int h = GetSystemMetrics(SM_CYSCREEN);

    HDC dcCopy = CreateCompatibleDC(dc);

    if (!dcCopy)
    {
        ReleaseDC(NULL, dc);
        return 0;
    }

    BITMAPINFO bi{};
    bi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    bi.bmiHeader.biWidth = w;
    bi.bmiHeader.biHeight = -h;
    bi.bmiHeader.biPlanes = 1;
    bi.bmiHeader.biBitCount = 32;
    bi.bmiHeader.biCompression = BI_RGB;

    uint32_t* pixels = nullptr;

    HBITMAP bmp = CreateDIBSection(
        dc,
        &bi,
        DIB_RGB_COLORS,
        reinterpret_cast<void**>(&pixels),
        NULL,
        0
    );

    if (!bmp || !pixels)
    {
        if (bmp)
            DeleteObject(bmp);

        DeleteDC(dcCopy);
        ReleaseDC(NULL, dc);
        return 0;
    }

    HGDIOBJ oldBmp = SelectObject(dcCopy, bmp);

    // RAM cache: the fractal view never moves (cx/cy have no
    // time term), so the per-pixel iteration count is identical
    // on every frame. Run the up-to-35-step Mandelbrot
    // iteration ONCE into iterMap (1 byte/pixel) and let each
    // frame just colourise from it, instead of re-iterating
    // the fractal w*h times per frame.
    std::vector<uint8_t> iterMap(
        static_cast<size_t>(w) * static_cast<size_t>(h)
    );

    {
        const double fractalX = 2.5 / w;
        const double fractalY = 1.90 / h;

        std::vector<double> colX(w);
        std::vector<double> rowY(h);

        for (int x = 0; x < w; ++x)
            colX[x] = x * fractalX - (2.0 - sd.phase * 0.0001);

        for (int y = 0; y < h; ++y)
            rowY[y] = y * fractalY - (0.95 - sd.phase * 0.0001);

        for (int y = 0; y < h; ++y)
        {
            for (int x = 0; x < w; ++x)
            {
                const double cx = colX[x];
                const double cy = rowY[y];

                double zx = 0;
                double zy = 0;

                int iterations = 0;

                while (
                    zx * zx +
                    zy * zy < 10.0 &&
                    iterations < 35
                    )
                {
                    double newX =
                        zx * zx -
                        zy * zy +
                        cx;

                    double newY =
                        2.0 * zx * zy +
                        cy;

                    zx = newX;
                    zy = newY;

                    ++iterations;
                }

                iterMap[static_cast<size_t>(y) * w + x] =
                    static_cast<uint8_t>(iterations);
            }
        }
    }

    for (int frame = 0; frame < 120; ++frame)
    {
        if (FXAbort())
            break;

        // Repaint the whole screen every 4th frame only.
        if ((frame & 3) != 0)
        {
            Sleep(1);
            continue;
        }

        BitBlt(
            dcCopy,
            0,
            0,
            w,
            h,
            dc,
            0,
            0,
            SRCCOPY
        );

        for (int y = 0; y < h; ++y)
        {
            for (int x = 0; x < w; ++x)
            {
                int i = y * w + x;

                // Iteration count from the RAM cache (the
                // fractal itself was iterated once, above).
                const int iterations = iterMap[i];

                uint32_t px = pixels[i];

                int r = px & 255;
                int g = (px >> 8) & 255;
                int b = (px >> 16) & 255;

                r = (r + iterations * 4) & 255;
                g = (g + iterations * 2) & 255;
                b = (b + iterations * 6) & 255;

                pixels[i] =
                    static_cast<uint32_t>(b) << 16 |
                    static_cast<uint32_t>(g) << 8 |
                    static_cast<uint32_t>(r);
            }
        }

        BitBlt(
            dc,
            0,
            0,
            w,
            h,
            dcCopy,
            0,
            0,
            SRCCOPY
        );
    }

    SelectObject(dcCopy, oldBmp);
    DeleteObject(bmp);
    DeleteDC(dcCopy);
    ReleaseDC(NULL, dc);

    return 0;
}

// ============================================================
// PAYLOAD 9
// Recursive zoom + hue chaos
// ============================================================
DWORD WINAPI GDIPayload9(LPVOID)
{
    const PhoenixHppdSeedVariant& sd = PhoenixHppdSeedGet(9);
    srand(PhoenixHppdSeedRand(9));

    HDC dc = GetDC(NULL);

    if (!dc)
        return 0;

    const int w = GetSystemMetrics(SM_CXSCREEN);
    const int h = GetSystemMetrics(SM_CYSCREEN);

    HDC dcCopy = CreateCompatibleDC(dc);

    if (!dcCopy)
    {
        ReleaseDC(NULL, dc);
        return 0;
    }

    BITMAPINFO bi{};
    bi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    bi.bmiHeader.biWidth = w;
    bi.bmiHeader.biHeight = -h;
    bi.bmiHeader.biPlanes = 1;
    bi.bmiHeader.biBitCount = 32;
    bi.bmiHeader.biCompression = BI_RGB;

    uint32_t* pixels = nullptr;

    HBITMAP bmp = CreateDIBSection(
        dc,
        &bi,
        DIB_RGB_COLORS,
        reinterpret_cast<void**>(&pixels),
        NULL,
        0
    );

    if (!bmp || !pixels)
    {
        if (bmp)
            DeleteObject(bmp);

        DeleteDC(dcCopy);
        ReleaseDC(NULL, dc);
        return 0;
    }

    HGDIOBJ oldBmp = SelectObject(dcCopy, bmp);

    float t = 0.0f;

    // Bolt optimization: Precompute sin/cos for frame-invariant terms to apply angle-addition identities.
    std::vector<float> sinFx(w);
    std::vector<float> cosFx(w);
    std::vector<float> sinGy(h);
    std::vector<float> cosGy(h);

    for (int frame = 0; frame < 150; ++frame)
    {
        if (FXAbort())
            break;

        // Repaint the whole screen every 4th frame only.
        if ((frame & 3) != 0)
        {
            Sleep(1);
            continue;
        }

        int j = sd.amp + rand() % 12;

        SetStretchBltMode(dcCopy, COLORONCOLOR);
        SetStretchBltMode(dc, COLORONCOLOR);

        StretchBlt(
            dcCopy,
            0,
            0,
            std::max(1, w / j),
            std::max(1, h / j),
            dc,
            0,
            0,
            w,
            h,
            SRCCOPY
        );

        int mode = static_cast<int>(t) % 3 ? 1 : (static_cast<int>(t) % 2 ? 2 : 3);

        for (int x = 0; x < w; ++x)
        {
            float termX;
            if (mode == 1) termX = x * 0.025f;
            else if (mode == 2) termX = (t * x + sd.phase) * 0.025f;
            else termX = (t * x * x + sd.phase) * 0.025f;

            sinFx[x] = std::sin(termX);
            cosFx[x] = std::cos(termX);
        }

        for (int y = 0; y < h; ++y)
        {
            float termY;
            if (mode == 1) termY = (y * t + sd.phase) * 0.025f;
            else if (mode == 2) termY = y * 0.025f;
            else termY = y * y * t * 0.025f;

            sinGy[y] = std::sin(termY);
            cosGy[y] = std::cos(termY);
        }

        for (int y = 0; y < h; ++y)
        {
            float sin_Gy = sinGy[y];
            float cos_Gy = cosGy[y];

            for (int x = 0; x < w; ++x)
            {
                int i = y * w + x;

                float wave_f = sinFx[x] * cos_Gy + cosFx[x] * sin_Gy;

                int wave =
                    static_cast<int>(
                        wave_f * (45.0f + sd.amp)
                        );

                pixels[i] =
                    PhoenixHppdShiftHSL(
                        pixels[i],
                        -wave / 255.0f * sd.dir,
                        0.0f,
                        0.0f
                    );
            }
        }

        ++t;

        StretchBlt(
            dc,
            0,
            0,
            w,
            h,
            dcCopy,
            0,
            0,
            std::max(1, w / j),
            std::max(1, h / j),
            SRCCOPY
        );

        /*if (rand() % 25 == 24)
        {
            RedrawWindow(
                NULL,
                NULL,
                NULL,
                RDW_INVALIDATE |
                RDW_UPDATENOW |
                RDW_ALLCHILDREN
            );
        }*/
    }

    SelectObject(dcCopy, oldBmp);
    DeleteObject(bmp);
    DeleteDC(dcCopy);
    ReleaseDC(NULL, dc);

    return 0;
}

// ============================================================
// PAYLOAD 10
// PATINVERT + color pulse
// ============================================================
DWORD WINAPI GDIPayload10(LPVOID)
{
    const PhoenixHppdSeedVariant& sd = PhoenixHppdSeedGet(10);
    srand(PhoenixHppdSeedRand(10));

    HDC dc = GetDC(NULL);

    if (!dc)
        return 0;

    const int w = GetSystemMetrics(SM_CXSCREEN);
    const int h = GetSystemMetrics(SM_CYSCREEN);

    HDC dcCopy = CreateCompatibleDC(dc);

    if (!dcCopy)
    {
        ReleaseDC(NULL, dc);
        return 0;
    }

    HBITMAP bmp = CreateCompatibleBitmap(dc, w, h);

    if (!bmp)
    {
        DeleteDC(dcCopy);
        ReleaseDC(NULL, dc);
        return 0;
    }

    HGDIOBJ oldBmp = SelectObject(dcCopy, bmp);

    for (int frame = 0; frame < 300; ++frame)
    {
        if (FXAbort())
            break;

        // Repaint the whole screen every 4th frame only.
        if ((frame & 3) != 0)
        {
            Sleep(1);
            continue;
        }

        HBRUSH brush = CreateSolidBrush(
            RGB(
                rand() % (255 - sd.amp * 10),
                rand() % (255 - sd.amp * 5),
                rand() % (255 - sd.amp * 20)
            )
        );

        if (brush)
        {
            HGDIOBJ oldBrush = SelectObject(
                dcCopy,
                brush
            );

            StretchBlt(
                dcCopy,
                0,
                0,
                w,
                h,
                dc,
                0,
                0,
                w,
                h,
                SRCCOPY
            );

            PatBlt(
                dcCopy,
                0,
                0,
                w,
                h,
                PATINVERT
            );

            StretchBlt(
                dc,
                0,
                0,
                w,
                h,
                dcCopy,
                0,
                0,
                w,
                h,
                SRCCOPY
            );

            SelectObject(dcCopy, oldBrush);
            DeleteObject(brush);
        }

        //Sleep(50);
    }

    SelectObject(dcCopy, oldBmp);
    DeleteObject(bmp);
    DeleteDC(dcCopy);
    ReleaseDC(NULL, dc);

    return 0;
}

// ============================================================
// PAYLOAD 11
// RGB noise + zoom
// ============================================================
DWORD WINAPI GDIPayload11(LPVOID)
{
    const PhoenixHppdSeedVariant& sd = PhoenixHppdSeedGet(11);
    srand(PhoenixHppdSeedRand(11));

    HDC dc = GetDC(NULL);

    if (!dc)
        return 0;

    const int w = GetSystemMetrics(SM_CXSCREEN);
    const int h = GetSystemMetrics(SM_CYSCREEN);

    HDC dcCopy = CreateCompatibleDC(dc);

    if (!dcCopy)
    {
        ReleaseDC(NULL, dc);
        return 0;
    }

    BITMAPINFO bi{};
    bi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    bi.bmiHeader.biWidth = w;
    bi.bmiHeader.biHeight = -h;
    bi.bmiHeader.biPlanes = 1;
    bi.bmiHeader.biBitCount = 32;
    bi.bmiHeader.biCompression = BI_RGB;

    uint32_t* pixels = nullptr;

    HBITMAP bmp = CreateDIBSection(
        dc,
        &bi,
        DIB_RGB_COLORS,
        reinterpret_cast<void**>(&pixels),
        NULL,
        0
    );

    if (!bmp || !pixels)
    {
        if (bmp)
            DeleteObject(bmp);

        DeleteDC(dcCopy);
        ReleaseDC(NULL, dc);
        return 0;
    }

    HGDIOBJ oldBmp = SelectObject(dcCopy, bmp);

    int intensity = 15 - sd.amp / 2;

    for (int frame = 0; frame < 300; ++frame)
    {
        if (FXAbort())
            break;

        // Repaint the whole screen every 4th frame only.
        if ((frame & 3) != 0)
        {
            Sleep(1);
            continue;
        }

        SetStretchBltMode(
            dc,
            COLORONCOLOR
        );

        SetStretchBltMode(
            dcCopy,
            COLORONCOLOR
        );

        StretchBlt(
            dcCopy,
            rand() % 3,
            rand() % 3,
            std::max(1, w / (5 - sd.amp / 4)),
            std::max(1, h / (5 - sd.amp / 4)),
            dc,
            rand() % 3,
            rand() % 3,
            w,
            h,
            SRCCOPY
        );

        for (int y = 0; y < h; ++y)
        {
            for (int x = 0; x < w; ++x)
            {
                int i = y * w + x;

                uint32_t px = pixels[i];

                int r = px & 255;
                int g = (px >> 8) & 255;
                int b = (px >> 16) & 255;

                int channel = (rand() + sd.phase / 4) % 3;
                int amount =
                    rand() % (intensity + 1);

                if (channel == 0)
                    r = std::min(255, r + amount);
                else if (channel == 1)
                    g = std::min(255, g + amount);
                else
                    b = std::min(255, b + amount);

                pixels[i] =
                    static_cast<uint32_t>(b) << 16 |
                    static_cast<uint32_t>(g) << 8 |
                    static_cast<uint32_t>(r);
            }
        }

        ++intensity;

        if (intensity > 255)
            intensity = 15;

        StretchBlt(
            dc,
            0,
            0,
            w,
            h,
            dcCopy,
            0,
            0,
            std::max(1, w / (5 - sd.amp / 4)),
            std::max(1, h / (5 - sd.amp / 4)),
            SRCCOPY
        );

        //Sleep(25);
    }

    SelectObject(dcCopy, oldBmp);
    DeleteObject(bmp);
    DeleteDC(dcCopy);
    ReleaseDC(NULL, dc);

    return 0;
}

// ============================================================
// PAYLOAD 13
// Chromatic plasma
// ============================================================
DWORD WINAPI GDIPayload13(LPVOID)
{
    const PhoenixHppdSeedVariant& sd = PhoenixHppdSeedGet(13);

    PhoenixHppdSurface s;

    if (!s.Init())
        return 0;

    static int sine[1024];
    static bool initialized = false;

    if (!initialized)
    {
        for (int i = 0; i < 1024; ++i)
        {
            sine[i] =
                static_cast<int>(
                    std::sin(
                        i *
                        6.28318530718 /
                        1024.0
                    ) *
                    127.0
                    ) + 128;
        }

        initialized = true;
    }

    int t = 0;

    ULONGLONG start =
        GetTickCount64();

    ULONGLONG nextFrame = start;

    while (!FXTimeout(start, 5000))
    {
        s.Capture();

        uint32_t* p =
            s.pixels;

        for (int y = 0; y < s.h; ++y)
        {
            int sy =
                (y * 3 + t * 5 + sd.phase / 2)
                & 1023;

            for (int x = 0; x < s.w; ++x)
            {
                int i =
                    y * s.w + x;

                int rWave =
                    sine[
                        (x + t * 4 + sd.phase)
                            & 1023
                    ];

                int gWave =
                    sine[
                        (x * 2 +
                            y * 3 +
                            t * 2 +
                            sd.phase)
                            & 1023
                    ];

                int bWave =
                    sine[
                        (sy + x)
                            & 1023
                    ];

                p[i] =
                    PhoenixHppdShiftHSL(
                        p[i],
                        (rWave + gWave + bWave)
                            / 3.0f / 255.0f * sd.dir,
                        0.0f,
                        0.0f
                    );
            }
        }

        s.Present();

        t += 7;

        FPS16(nextFrame);
    }

    return 0;
}

// ============================================================
// PAYLOAD 14
// RGB displacement
// ============================================================
DWORD WINAPI GDIPayload14(LPVOID)
{
    const PhoenixHppdSeedVariant& sd = PhoenixHppdSeedGet(14);

    PhoenixHppdSurface s;

    if (!s.Init())
        return 0;

    int t = 0;

    ULONGLONG start =
        GetTickCount64();

    ULONGLONG nextFrame = start;

    while (!FXTimeout(start, 5000))
    {
        s.Capture();

        uint32_t* p =
            s.pixels;

        for (int y = 0; y < s.h; ++y)
        {
            int wave =
                static_cast<int>(
                    std::sin(
                        (y + t + sd.phase / 4) * 0.035
                    ) *
                    (32.0 * sd.amp / 4)
                    );

            for (int x = 0; x < s.w; ++x)
            {
                int i =
                    y * s.w + x;

                uint32_t px =
                    p[i];

                int r =
                    px & 255;

                int g =
                    (px >> 8) & 255;

                int b =
                    (px >> 16) & 255;

                int rShift =
                    ((x + wave * sd.dir) & 31)
                    - 16;

                int gShift =
                    ((x - wave * sd.dir) & 31)
                    - 16;

                p[i] =
                    PhoenixHppdPackRGB(
                        r + rShift,
                        g + gShift,
                        b
                    );
            }
        }

        s.Present();

        t += 5;

        FPS16(nextFrame);
    }

    return 0;
}

// ============================================================
// PAYLOAD 15
// Feedback tunnel
// ============================================================
DWORD WINAPI GDIPayload15(LPVOID)
{
    const PhoenixHppdSeedVariant& sd = PhoenixHppdSeedGet(15);

    HDC dc = GetDC(nullptr);

    if (!dc)
        return 0;

    const int w =
        GetSystemMetrics(
            SM_CXSCREEN
        );

    const int h =
        GetSystemMetrics(
            SM_CYSCREEN
        );

    int t = 0;

    ULONGLONG start =
        GetTickCount64();

    ULONGLONG nextFrame = start;

    while (!FXTimeout(start, 5000))
    {
        int offset =
            static_cast<int>(
                std::sin(
                    (t + sd.phase / 2) * 0.07
                ) *
                (35.0 + sd.amp)
                );

        int zoom =
            static_cast<int>(
                std::sin(
                    (t + sd.phase / 3) * 0.035
                ) *
                (35.0 * sd.amp / 4)
                );

        StretchBlt(
            dc,
            zoom + offset,
            zoom,
            std::max(
                1,
                w - zoom * 2
            ),
            std::max(
                1,
                h - zoom * 2
            ),
            dc,
            0,
            0,
            w,
            h,
            SRCCOPY
        );

        if ((t & 15) == 0)
        {
            PatBlt(
                dc,
                0,
                0,
                w,
                h,
                DSTINVERT
            );
        }

        ++t;

        FPS16(nextFrame);
    }

    ReleaseDC(nullptr, dc);

    return 0;
}

// ============================================================
// PAYLOAD 17
// Neon edge inversion
// ============================================================
DWORD WINAPI GDIPayload17(LPVOID)
{
    const PhoenixHppdSeedVariant& sd = PhoenixHppdSeedGet(17);

    PhoenixHppdSurface s;

    if (!s.Init())
        return 0;

    int t = 0;

    ULONGLONG start =
        GetTickCount64();

    ULONGLONG nextFrame = start;

    // RAM cache for the per-diagonal pulse table (refilled
    // per frame inside the loop, allocated once here).
    std::vector<int> pulseDiag(s.w + s.h);

    while (!FXTimeout(start, 5000))
    {
        s.Capture();

        uint32_t* p =
            s.pixels;

        // RAM cache refill: 'pulse' only depends on (x + y),
        // so evaluate its sin() once per diagonal (w + h
        // calls) instead of once per pixel (w * h calls).
        for (int d = 0; d < s.w + s.h; ++d)
        {
            pulseDiag[d] =
                static_cast<int>(
                    std::sin(
                        (d + t + sd.phase / 2)
                        * 0.025
                    ) *
                    (30.0 + sd.amp * 2)
                    );
        }

        for (int y = 1;
            y < s.h - 1;
            ++y)
        {
            for (int x = 1;
                x < s.w - 1;
                ++x)
            {
                int i =
                    y * s.w + x;

                uint32_t left =
                    p[i - 1];

                uint32_t right =
                    p[i + 1];

                uint32_t up =
                    p[i - s.w];

                uint32_t down =
                    p[i + s.w];

                int lr =
                    left & 255;

                int rr =
                    right & 255;

                int ur =
                    up & 255;

                int dr =
                    down & 255;

                int lg =
                    (left >> 8) & 255;

                int rg =
                    (right >> 8) & 255;

                int ug =
                    (up >> 8) & 255;

                int dg =
                    (down >> 8) & 255;

                int lb =
                    (left >> 16) & 255;

                int rb =
                    (right >> 16) & 255;

                int ub =
                    (up >> 16) & 255;

                int db =
                    (down >> 16) & 255;

                int edgeR =
                    abs(lr - rr) +
                    abs(ur - dr);

                int edgeG =
                    abs(lg - rg) +
                    abs(ug - dg);

                int edgeB =
                    abs(lb - rb) +
                    abs(ub - db);

                int pulse =
                    pulseDiag[x + y];

                p[i] =
                    PhoenixHppdShiftHSL(
                        p[i],
                        pulse / 255.0f,
                        (edgeR + edgeG + edgeB)
                            / 3.0f / 255.0f,
                        (edgeR + edgeG + edgeB)
                            / 6.0f / 255.0f
                    );
            }
        }

        s.Present();

        ++t;

        FPS16(nextFrame);
    }

    return 0;
}

// ============================================================
// PAYLOAD 19
// Quantum spiral
// ============================================================
DWORD WINAPI GDIPayload19(LPVOID)
{
    const PhoenixHppdSeedVariant& sd = PhoenixHppdSeedGet(19);

    HDC dc = GetDC(nullptr);

    if (!dc)
        return 0;

    const int w =
        GetSystemMetrics(
            SM_CXSCREEN
        );

    const int h =
        GetSystemMetrics(
            SM_CYSCREEN
        );

    int t = 0;

    ULONGLONG start =
        GetTickCount64();

    ULONGLONG nextFrame = start;

    while (!FXTimeout(start, 5000))
    {
        int cx = w / 2;
        int cy = h / 2;

        int wave =
            static_cast<int>(
                std::sin(
                    (t + sd.phase / 8) * 0.04
                ) *
                (100.0 * sd.amp / 4)
                );

        POINT pts[3];

        pts[0] =
        {
            cx - w / 2 + wave,
            cy - h / 2
        };

        pts[1] =
        {
            cx + w / 2,
            cy - h / 2 - wave
        };

        pts[2] =
        {
            cx - w / 2 - wave,
            cy + h / 2
        };

        PlgBlt(
            dc,
            pts,
            dc,
            0,
            0,
            w,
            h,
            nullptr,
            0,
            0
        );

        if ((t % 30) == 0)
        {
            PatBlt(
                dc,
                0,
                0,
                w,
                h,
                NOTSRCCOPY
            );
        }

        ++t;

        FPS16(nextFrame);
    }

    ReleaseDC(nullptr, dc);

    return 0;
}

// ============================================================
// PAYLOAD 20
// Color worm
// ============================================================
DWORD WINAPI GDIPayload20(LPVOID)
{
    const PhoenixHppdSeedVariant& sd = PhoenixHppdSeedGet(20);

    PhoenixHppdSurface s;

    if (!s.Init())
        return 0;

    static int sine[2048];
    static bool initialized = false;

    if (!initialized)
    {
        for (int i = 0; i < 2048; ++i)
        {
            sine[i] =
                static_cast<int>(
                    std::sin(
                        i *
                        6.28318530718 /
                        2048.0
                    ) *
                    127.0
                    ) +
                128;
        }

        initialized = true;
    }

    int t = 0;

    ULONGLONG start =
        GetTickCount64();

    ULONGLONG nextFrame = start;

    while (!FXTimeout(start, 5000))
    {
        s.Capture();

        uint32_t* p =
            s.pixels;

        for (int y = 0; y < s.h; ++y)
        {
            int rowWave =
                sine[
                    (y * 3 + t * 4 + sd.phase / 2)
                        & 2047
                ];

            for (int x = 0; x < s.w; ++x)
            {
                int i =
                    y * s.w + x;

                int wave =
                    sine[
                        (
                            x * 2 +
                            rowWave +
                            t * 7 +
                            sd.phase
                            ) & 2047
                    ];

                p[i] =
                    PhoenixHppdShiftHSL(
                        p[i],
                        wave / 255.0f * sd.dir,
                        0.0f,
                        (sine[(wave + t * 5) & 2047] - 128)
                            / 255.0f / 4.0f
                    );
            }
        }

        s.Present();

        t += 3;

        FPS16(nextFrame);
    }

    return 0;
}

// ============================================================
// PAYLOAD 21
// Radial shockwave
// ============================================================
DWORD WINAPI GDIPayload21(LPVOID)
{
    const PhoenixHppdSeedVariant& sd = PhoenixHppdSeedGet(21);

    HDC dc = GetDC(nullptr);

    if (!dc)
        return 0;

    const int w =
        GetSystemMetrics(
            SM_CXSCREEN
        );

    const int h =
        GetSystemMetrics(
            SM_CYSCREEN
        );

    int t = 0;

    ULONGLONG start =
        GetTickCount64();

    ULONGLONG nextFrame = start;

    while (!FXTimeout(start, 5000))
    {
        double phase =
            (t + sd.phase / 8) * 0.06;

        int radius =
            static_cast<int>(
                (
                    std::sin(phase) +
                    1.0
                    ) *
                0.5 *
                (w / 2) *
                (sd.amp / 4.0)
                );

        int distortion =
            static_cast<int>(
                std::sin(
                    phase * 2.0
                ) *
                (55.0 + sd.amp * 4)
                );

        int left =
            std::max(
                0,
                radius / 4 +
                distortion
            );

        int top =
            std::max(
                0,
                radius / 6
            );

        int rw =
            std::max(
                1,
                w - left * 2
            );

        int rh =
            std::max(
                1,
                h - top * 2
            );

        StretchBlt(
            dc,
            left,
            top,
            rw,
            rh,
            dc,
            0,
            0,
            w,
            h,
            SRCCOPY
        );

        if ((t % 40) < 3)
        {
            PatBlt(
                dc,
                0,
                0,
                w,
                h,
                DSTINVERT
            );
        }

        ++t;

        FPS16(nextFrame);
    }

    ReleaseDC(nullptr, dc);

    return 0;
}

// ============================================================
// PAYLOAD 22
// RGB void
// ============================================================
DWORD WINAPI GDIPayload22(LPVOID)
{
    const PhoenixHppdSeedVariant& sd = PhoenixHppdSeedGet(22);

    PhoenixHppdSurface s;

    if (!s.Init())
        return 0;

    static int sine[2048];
    static bool initialized = false;

    if (!initialized)
    {
        for (int i = 0; i < 2048; ++i)
        {
            sine[i] =
                static_cast<int>(
                    std::sin(
                        i *
                        6.28318530718 /
                        2048.0
                    ) *
                    127.0
                    );
        }

        initialized = true;
    }

    const int cx =
        s.w / 2;

    const int cy =
        s.h / 2;

    // RAM cache (frame-invariant): every pixel's dx*dx and dy*dy
    // only depend on x and y, so compute them ONCE here and read
    // them back per frame instead of redoing it per pixel.
    std::vector<uint32_t> dx2(s.w);
    std::vector<uint32_t> dy2(s.h);

    for (int x = 0; x < s.w; ++x)
    {
        int dx = x - cx;
        dx2[x] = static_cast<uint32_t>(dx * dx);
    }

    for (int y = 0; y < s.h; ++y)
    {
        int dy = y - cy;
        dy2[y] = static_cast<uint32_t>(dy * dy);
    }

    int t = 0;

    ULONGLONG start =
        GetTickCount64();

    ULONGLONG nextFrame = start;

    while (!FXTimeout(start, 5000))
    {
        s.Capture();

        uint32_t* p =
            s.pixels;

        for (int y = 0; y < s.h; ++y)
        {
            uint32_t dy_sq = dy2[y];

            for (int x = 0; x < s.w; ++x)
            {
                int i =
                    y * s.w + x;

                uint32_t dist2 =
                    dx2[x] + dy_sq;

                int wave =
                    sine[
                        (
                            (dist2 >> 10) +
                            t * 8 +
                            sd.phase
                            ) & 2047
                    ];

                p[i] =
                    PhoenixHppdShiftHSL(
                        p[i],
                        wave / 255.0f / 2.0f * sd.dir,
                        0.0f,
                        wave / 255.0f / 4.0f
                    );
            }
        }

        s.Present();

        ++t;

        FPS16(nextFrame);
    }

    return 0;
}

// ============================================================
// PAYLOAD 23
// Retro CRT
// ============================================================
DWORD WINAPI GDIPayload23(LPVOID)
{
    const PhoenixHppdSeedVariant& sd = PhoenixHppdSeedGet(23);

    PhoenixHppdSurface s;

    if (!s.Init())
        return 0;

    int t = 0;

    ULONGLONG start =
        GetTickCount64();

    ULONGLONG nextFrame = start;

    // RAM cache for the per-column aberration table (refilled
    // per frame inside the loop, allocated once here).
    std::vector<int> aberrX(s.w);

    while (!FXTimeout(start, 5000))
    {
        s.Capture();

        uint32_t* p =
            s.pixels;

        // RAM cache refill: 'aberration' only depends on x,
        // so evaluate its sin() once per column (w calls)
        // instead of once per pixel (w * h calls).
        for (int x = 0; x < s.w; ++x)
        {
            aberrX[x] =
                static_cast<int>(
                    std::sin(
                        x * 0.015 +
                        t * 0.08 +
                        sd.phase * 0.0002
                    ) *
                    (16.0 + sd.amp)
                    );
        }

        for (int y = 0; y < s.h; ++y)
        {
            int scanline =
                (y + t) & 3;

            for (int x = 0; x < s.w; ++x)
            {
                int i =
                    y * s.w + x;

                int aberration =
                    aberrX[x];

                p[i] =
                    PhoenixHppdShiftHSL(
                        p[i],
                        aberration / 255.0f * sd.dir,
                        0.0f,
                        scanline == 0 ? -0.20f : 0.0f
                    );
            }
        }

        s.Present();

        ++t;

        FPS16(nextFrame);
    }

    return 0;
}

// ============================================================
// PAYLOAD 24
// Absolute GDI chaos
// ============================================================
DWORD WINAPI GDIPayload24(LPVOID)
{
    const PhoenixHppdSeedVariant& sd = PhoenixHppdSeedGet(24);

    HDC dc = GetDC(nullptr);

    if (!dc)
        return 0;

    const int w =
        GetSystemMetrics(
            SM_CXSCREEN
        );

    const int h =
        GetSystemMetrics(
            SM_CYSCREEN
        );

    uint32_t rng =
        sd.rng;

    int frame = 0;

    ULONGLONG start =
        GetTickCount64();

    ULONGLONG nextFrame = start;

    while (!FXTimeout(start, 5000))
    {
        int mode =
            FXRand(rng) & 7;

        switch (mode)
        {
        case 0:

            BitBlt(
                dc,
                0,
                0,
                w,
                h,
                dc,
                6,
                0,
                SRCCOPY
            );

            break;

        case 1:

            BitBlt(
                dc,
                0,
                0,
                w,
                h,
                dc,
                -6,
                0,
                NOTSRCCOPY
            );

            break;

        case 2:

            BitBlt(
                dc,
                0,
                4,
                w,
                h,
                dc,
                0,
                0,
                SRCPAINT
            );

            break;

        case 3:

            BitBlt(
                dc,
                0,
                0,
                w,
                h,
                dc,
                0,
                4,
                SRCAND
            );

            break;

        case 4:
        {
            int inset =
                10 +
                static_cast<int>(
                    FXRand(rng) % 80
                    );

            StretchBlt(
                dc,
                inset,
                inset,
                std::max(
                    1,
                    w - inset * 2
                ),
                std::max(
                    1,
                    h - inset * 2
                ),
                dc,
                0,
                0,
                w,
                h,
                SRCCOPY
            );

            break;
        }

        case 5:
        {
            int y =
                FXRand(rng) % h;

            int height =
                4 +
                FXRand(rng) % (40 + sd.amp * 5);

            int offset =
                static_cast<int>(
                    FXRand(rng) % (200 + sd.amp * 15)
                    ) -
                (100 + sd.amp * 8);

            BitBlt(
                dc,
                offset,
                y,
                w,
                height,
                dc,
                0,
                y,
                SRCCOPY
            );

            break;
        }

        case 6:

            PatBlt(
                dc,
                0,
                0,
                w,
                h,
                DSTINVERT
            );

            break;

        case 7:
        {
            POINT pts[3];

            int wobble =
                static_cast<int>(
                    std::sin(
                        (frame + sd.phase / 6) * 0.05
                    ) *
                    (100.0 * sd.amp / 4)
                    );

            pts[0] =
            {
                -wobble,
                0
            };

            pts[1] =
            {
                w + wobble,
                20
            };

            pts[2] =
            {
                30,
                h
            };

            PlgBlt(
                dc,
                pts,
                dc,
                0,
                0,
                w,
                h,
                nullptr,
                0,
                0
            );

            break;
        }
        }

        ++frame;

        FPS16(nextFrame);
    }

    ReleaseDC(
        nullptr,
        dc
    );

    return 0;
}

// 40 - Rotate (PlgBlt wobble, two opposing sweeps)
DWORD WINAPI GDIPayload40(LPVOID)
{
    const PhoenixHppdSeedVariant& sd = PhoenixHppdSeedGet(40);
    (void)sd;
    srand(PhoenixHppdSeedRand(40));

    HDC hdc = GetDC(0);

    if (!hdc)
        return 0;

    RECT rekt{};
    POINT rotate[3];

    ULONGLONG start = GetTickCount64();

    while (!FXTimeout(start, 5000))
    {
        int rnd = rand() % 65 + 60;

        for (int i = 0; i < rnd; i += 20)
        {
            if (FXAbort())
                break;

            GetWindowRect(GetDesktopWindow(), &rekt);

            rotate[0].x = rekt.left + i;
            rotate[0].y = rekt.top - i;
            rotate[1].x = rekt.right + i;
            rotate[1].y = rekt.top + i;
            rotate[2].x = rekt.left - i;
            rotate[2].y = rekt.bottom - i;

            PlgBlt(
                hdc, rotate, hdc, 0, 0,
                rekt.right - rekt.left,
                rekt.bottom - rekt.top,
                0, 0, 0
            );

            //Sleep(40);
        }

        for (int i = 0; i < rnd; i += 20)
        {
            if (FXAbort())
                break;

            GetWindowRect(GetDesktopWindow(), &rekt);

            rotate[0].x = rekt.left - i;
            rotate[0].y = rekt.top + i;
            rotate[1].x = rekt.right - i;
            rotate[1].y = rekt.top - i;
            rotate[2].x = rekt.left + i;
            rotate[2].y = rekt.bottom + i;

            PlgBlt(
                hdc, rotate, hdc, 0, 0,
                rekt.right - rekt.left,
                rekt.bottom - rekt.top,
                0, 0, 0
            );

            //Sleep(40);
        }
    }

    ReleaseDC(0, hdc);
    return 0;
}

// 48 - ExtremeRotation (alternating ±90 px rotate wobble)
DWORD WINAPI GDIPayload48(LPVOID)
{
    const PhoenixHppdSeedVariant& sd = PhoenixHppdSeedGet(48);
    (void)sd;
    srand(PhoenixHppdSeedRand(48));

    HDC hdc = GetDC(0);

    if (!hdc)
        return 0;

    RECT rekt{};
    POINT rotate[3];

    ULONGLONG start = GetTickCount64();

    while (!FXTimeout(start, 5000))
    {
        if (FXAbort())
            break;

        bool direction = (rand() % 2) == 0;

        for (int runtime = 0; runtime < 30; runtime++)
        {
            if (FXAbort())
                break;

            GetWindowRect(GetDesktopWindow(), &rekt);

            if (direction)
            {
                rotate[0].x = rekt.left + 90;
                rotate[0].y = rekt.top - 90;
                rotate[1].x = rekt.right + 90;
                rotate[1].y = rekt.top + 90;
                rotate[2].x = rekt.left - 90;
                rotate[2].y = rekt.bottom - 90;
            }
            else
            {
                rotate[0].x = rekt.left - 90;
                rotate[0].y = rekt.top + 90;
                rotate[1].x = rekt.right - 90;
                rotate[1].y = rekt.top - 90;
                rotate[2].x = rekt.left + 90;
                rotate[2].y = rekt.bottom + 90;
            }

            PlgBlt(
                hdc, rotate, hdc, 0, 0,
                rekt.right - rekt.left,
                rekt.bottom - rekt.top,
                0, 0, 0
            );
        }
    }

    ReleaseDC(0, hdc);
    return 0;
}

// ============================================================
// GDI DEMOSCENE FX PACK (PAYLOADS 50-63)
//
// Per-pixel remap/shaders running on a temporary screen-sized
// DIB (see gdi/gdibuffer.h). Each payload grabs the screen HDC
// itself and owns a matching ReleaseDC, like the rest of the file.
// ============================================================
// ============================================================
// PAYLOAD 50
// Chromatic vortex / RGB separation
// ============================================================
DWORD WINAPI GDIPayload50(LPVOID)
{
    const PhoenixHppdSeedVariant& sd = PhoenixHppdSeedGet(50);

    HDC dc = GetDC(nullptr);

    if (!dc)
        return 0;

    const int w = GetDeviceCaps(dc, HORZRES);
    const int h = GetDeviceCaps(dc, VERTRES);

    GDIBuffer src;

    if (!CreateBuffer(dc, src, w, h))
    {
        ReleaseDC(nullptr, dc);
        return 0;
    }

    const float cx = w * 0.5f;
    const float cy = h * 0.5f;

    // RAM cache: radius + angle of every pixel are the same
    // on every frame, so compute sqrtf/atan2f ONCE here and
    // read them back per frame (see gdi/fxcache.h).
    FxCache::PolarMap polar;

    polar.Build(
        w, h, cx, cy,
        FxCache::PolarRadius | FxCache::PolarAngle
    );

    // cos/sin of the +/-0.035 rad channel offset, for the
    // angle-addition identities used in the pixel loop.
    const float cosOff = cosf(0.035f);
    const float sinOff = sinf(0.035f);

    // Bolt optimization: Cache sin/cos of radius outside the frame loop
    const size_t pixelCount = static_cast<size_t>(w) * static_cast<size_t>(h);
    std::vector<float> sinR(pixelCount);
    std::vector<float> cosR(pixelCount);
    for (size_t i = 0; i < pixelCount; ++i)
    {
        sinR[i] = sinf(polar.radius[i] * 0.012f);
        cosR[i] = cosf(polar.radius[i] * 0.012f);
    }

    for (int frame = 0; frame < 260; ++frame)
    {
        if (FXAbort())
            break;

        // Repaint the whole screen every 4th frame only.
        if ((frame & 3) != 0)
        {
            Sleep(1);
            continue;
        }

        BitBlt(
            src.dc,
            0,
            0,
            w,
            h,
            dc,
            0,
            0,
            SRCCOPY
        );

        float time = frame * 0.035f;

        // Bolt optimization: Time terms using angle-addition identity
        const float t4 = time * 4.0f;
        const float cosT = cosf(t4);
        const float sinT = sinf(t4);

        for (int y = 0; y < h; ++y)
        {
            for (int x = 0; x < w; ++x)
            {
                const size_t pi =
                    static_cast<size_t>(y) * w + x;

                // Radius/angle from the RAM cache (built once
                // before the frame loop, not per frame).
                float radius =
                    polar.radius[pi];

                float angle =
                    polar.angle[pi];

                float vortex =
                    (sinR[pi] * cosT - cosR[pi] * sinT) *
                    (0.12f + sd.amp * 0.004f);

                float a = angle + vortex;

                // One cosf/sinf pair per pixel; the +/-0.035
                // channel angles come from the angle-addition
                // identities (algebraically identical, saves
                // 4 more trig calls per pixel).
                float ca = cosf(a);
                float sa = sinf(a);

                float caP = ca * cosOff - sa * sinOff;
                float saP = sa * cosOff + ca * sinOff;
                float caM = ca * cosOff + sa * sinOff;
                float saM = sa * cosOff - ca * sinOff;

                int rx =
                    ClampI(
                        (int)(cx + ca * radius),
                        0,
                        w - 1
                    );

                int gx =
                    ClampI(
                        (int)(cx + caP * radius),
                        0,
                        w - 1
                    );

                int bx =
                    ClampI(
                        (int)(cx + caM * radius),
                        0,
                        w - 1
                    );

                int ry =
                    ClampI(
                        (int)(cy + sa * radius),
                        0,
                        h - 1
                    );

                int gy =
                    ClampI(
                        (int)(cy + saP * radius),
                        0,
                        h - 1
                    );

                int by =
                    ClampI(
                        (int)(cy + saM * radius),
                        0,
                        h - 1
                    );

                int pr, pg, pb;

                SplitRGB(
                    src.pixels[ry * w + rx],
                    pr,
                    pg,
                    pb
                );

                int r2, g2, b2;

                SplitRGB(
                    src.pixels[gy * w + gx],
                    r2,
                    g2,
                    b2
                );

                int r3, g3, b3;

                SplitRGB(
                    src.pixels[by * w + bx],
                    r3,
                    g3,
                    b3
                );

                src.pixels[y * w + x] =
                    RGBPixel(
                        pr,
                        g2,
                        b3
                    );
            }
        }

        BitBlt(
            dc,
            0,
            0,
            w,
            h,
            src.dc,
            0,
            0,
            SRCCOPY
        );
    }

    DestroyBuffer(src);

    ReleaseDC(nullptr, dc);

    return 0;
}

// ============================================================
// PAYLOAD 51
// Polar liquid distortion
// ============================================================
DWORD WINAPI GDIPayload51(LPVOID)
{
    const PhoenixHppdSeedVariant& sd = PhoenixHppdSeedGet(51);

    HDC dc = GetDC(nullptr);

    if (!dc)
        return 0;

    const int w = GetDeviceCaps(dc, HORZRES);
    const int h = GetDeviceCaps(dc, VERTRES);

    GDIBuffer src;

    if (!CreateBuffer(dc, src, w, h))
    {
        ReleaseDC(nullptr, dc);
        return 0;
    }

    const float cx = w * .5f;
    const float cy = h * .5f;

    // RAM cache: radius / angle / unit vectors of every pixel
    // never change between frames - compute sqrtf, atan2f,
    // cosf and sinf ONCE here (see gdi/fxcache.h). The extra
    // sinA7/cosA7 maps cache sinf/cosf of (angle * 7) so the
    // per-frame sinf(a * 7 + t) also becomes two multiplies
    // via the angle-addition identity.
    FxCache::PolarMap polar;

    polar.Build(w, h, cx, cy);

    const size_t pixelCount =
        static_cast<size_t>(w) * static_cast<size_t>(h);

    std::vector<float> sinA7(pixelCount);
    std::vector<float> cosA7(pixelCount);

    for (size_t i = 0; i < pixelCount; ++i)
    {
        const float a7 = polar.angle[i] * 7.0f;

        sinA7[i] = sinf(a7);
        cosA7[i] = cosf(a7);
    }

    // The raw angle map is only needed to build the maps
    // above; release it so RAM holds just what frames read.
    std::vector<float>().swap(polar.angle);

    for (int frame = 0; frame < 240; ++frame)
    {
        if (FXAbort())
            break;

        // Repaint the whole screen every 4th frame only.
        if ((frame & 3) != 0)
        {
            Sleep(1);
            continue;
        }

        BitBlt(
            src.dc,
            0,
            0,
            w,
            h,
            dc,
            0,
            0,
            SRCCOPY
        );

        float t = frame * .055f;

        // Per-frame scalars for sinf(a * 7 + t) via the
        // cached sinA7/cosA7 maps (angle-addition identity).
        const float cosT = cosf(t);
        const float sinT = sinf(t);

        for (int y = 0; y < h; ++y)
        {
            for (int x = 0; x < w; ++x)
            {
                const size_t pi =
                    static_cast<size_t>(y) * w + x;

                // Radius + unit vectors from the RAM cache.
                float r =
                    polar.radius[pi];

                float wave =
                    sinf(
                        r * 0.028f +
                        (sinA7[pi] * cosT + cosA7[pi] * sinT) * 3.0f -
                        t * 3.0f
                    );

                float displacement =
                    wave *
                    (7.0f + sd.amp * 0.7f);

                float sx =
                    cx +
                    polar.cosA[pi] *
                    (r + displacement);

                float sy =
                    cy +
                    polar.sinA[pi] *
                    (r + displacement);

                int ix =
                    ClampI((int)sx, 0, w - 1);

                int iy =
                    ClampI((int)sy, 0, h - 1);

                src.pixels[y * w + x] =
                    src.pixels[iy * w + ix];
            }
        }

        BitBlt(
            dc,
            0,
            0,
            w,
            h,
            src.dc,
            0,
            0,
            SRCCOPY
        );
    }

    DestroyBuffer(src);

    ReleaseDC(nullptr, dc);

    return 0;
}

// ============================================================
// PAYLOAD 52
// Kaleidoscope recursion
// ============================================================
DWORD WINAPI GDIPayload52(LPVOID)
{
    const PhoenixHppdSeedVariant& sd = PhoenixHppdSeedGet(52);
    (void)sd;

    HDC dc = GetDC(nullptr);

    if (!dc)
        return 0;

    int w = GetDeviceCaps(dc, HORZRES);
    int h = GetDeviceCaps(dc, VERTRES);

    GDIBuffer a;
    GDIBuffer b;

    if (!CreateBuffer(dc, a, w, h))
    {
        ReleaseDC(nullptr, dc);
        return 0;
    }

    if (!CreateBuffer(dc, b, w, h))
    {
        DestroyBuffer(a);
        ReleaseDC(nullptr, dc);
        return 0;
    }

    for (int frame = 0; frame < 300; ++frame)
    {
        if (FXAbort())
            break;

        // Repaint the whole screen every 4th frame only.
        if ((frame & 3) != 0)
        {
            Sleep(1);
            continue;
        }

        BitBlt(
            a.dc,
            0,
            0,
            w,
            h,
            dc,
            0,
            0,
            SRCCOPY
        );

        int cx = w / 2;
        int cy = h / 2;

        float pulse =
            1.0f +
            sinf(frame * .07f) * .06f;

        for (int sector = 0; sector < 8; ++sector)
        {
            float angle =
                sector * 3.14159265f / 4.0f +
                frame * .006f;

            int sw =
                (int)(w * .52f * pulse);

            int sh =
                (int)(h * .52f * pulse);

            int ox =
                (int)(cosf(angle) * w * .08f);

            int oy =
                (int)(sinf(angle) * h * .08f);

            StretchBlt(
                b.dc,
                cx - sw / 2 + ox,
                cy - sh / 2 + oy,
                sw,
                sh,
                a.dc,
                0,
                0,
                w,
                h,
                SRCCOPY
            );
        }

        BitBlt(
            dc,
            0,
            0,
            w,
            h,
            b.dc,
            0,
            0,
            SRCCOPY
        );
    }

    DestroyBuffer(a);
    DestroyBuffer(b);

    ReleaseDC(nullptr, dc);

    return 0;
}

// ============================================================
// PAYLOAD 53
// Radial tunnel
// ============================================================
DWORD WINAPI GDIPayload53(LPVOID)
{
    const PhoenixHppdSeedVariant& sd = PhoenixHppdSeedGet(53);

    HDC dc = GetDC(nullptr);

    if (!dc)
        return 0;

    int w = GetDeviceCaps(dc, HORZRES);
    int h = GetDeviceCaps(dc, VERTRES);

    GDIBuffer buf;

    if (!CreateBuffer(dc, buf, w, h))
    {
        ReleaseDC(nullptr, dc);
        return 0;
    }

    int cx = w / 2;
    int cy = h / 2;

    // RAM cache: radius / unit vectors of every pixel never
    // change between frames - compute sqrtf, atan2f, cosf and
    // sinf ONCE here (see gdi/fxcache.h). sinA6 additionally
    // caches sinf(angle * 6), the tunnel's static twist term.
    FxCache::PolarMap polar;

    polar.Build(
        w, h,
        static_cast<float>(cx),
        static_cast<float>(cy)
    );

    const size_t pixelCount =
        static_cast<size_t>(w) * static_cast<size_t>(h);

    std::vector<float> sinA6(pixelCount);

    // Bolt optimization: Precompute sin/cos for frame-invariant terms to apply angle-addition identities.
    std::vector<float> sinTunnel(pixelCount);
    std::vector<float> cosTunnel(pixelCount);
    std::vector<float> sinHue(pixelCount);
    std::vector<float> cosHue(pixelCount);

    for (size_t i = 0; i < pixelCount; ++i)
    {
        sinA6[i] = sinf(polar.angle[i] * 6.0f);

        float tunnelInv = polar.radius[i] * .025f + sinA6[i] * 2.0f;
        sinTunnel[i] = sinf(tunnelInv);
        cosTunnel[i] = cosf(tunnelInv);

        float hueInv = polar.radius[i] * .01f;
        sinHue[i] = sinf(hueInv);
        cosHue[i] = cosf(hueInv);
    }

    // The raw angle map is only needed to build sinA6;
    // release it so RAM holds just what frames read.
    std::vector<float>().swap(polar.angle);

    for (int frame = 0; frame < 240; ++frame)
    {
        if (FXAbort())
            break;

        // Repaint the whole screen every 4th frame only.
        if ((frame & 3) != 0)
        {
            Sleep(1);
            continue;
        }

        BitBlt(
            buf.dc,
            0,
            0,
            w,
            h,
            dc,
            0,
            0,
            SRCCOPY
        );

        float t =
            frame * .035f;

        float zoom =
            1.0f +
            sinf(t) * .025f;

        // Bolt optimization: Time terms for tunnel and hue using angle-addition identity
        const float t5 = t * 5.0f;
        const float cosT5 = cosf(t5);
        const float sinT5 = sinf(t5);

        const float t3 = t * 3.0f;
        const float cosT3 = cosf(t3);
        const float sinT3 = sinf(t3);

        for (int y = 0; y < h; ++y)
        {
            for (int x = 0; x < w; ++x)
            {
                const size_t pi =
                    static_cast<size_t>(y) * w + x;

                // Radius + unit vectors + twist from the
                // RAM cache (built once, not per frame).
                float r =
                    polar.radius[pi];

                float tunnel =
                    1.0f +
                    (sinTunnel[pi] * cosT5 - cosTunnel[pi] * sinT5) * .04f;

                float nr =
                    r * tunnel * zoom;

                int sx =
                    ClampI(
                        (int)(cx + polar.cosA[pi] * nr),
                        0,
                        w - 1
                    );

                int sy =
                    ClampI(
                        (int)(cy + polar.sinA[pi] * nr),
                        0,
                        h - 1
                    );

                uint32_t p =
                    buf.pixels[sy * w + sx];

                float hue =
                    (sinHue[pi] * cosT3 - cosHue[pi] * sinT3) *
                    .18f;

                buf.pixels[y * w + x] =
                    PhoenixHppdShiftHSL(
                        p,
                        hue * sd.dir,
                        0.0f,
                        0.0f
                    );
            }
        }

        BitBlt(
            dc,
            0,
            0,
            w,
            h,
            buf.dc,
            0,
            0,
            SRCCOPY
        );
    }

    DestroyBuffer(buf);

    ReleaseDC(nullptr, dc);

    return 0;
}

// ============================================================
// PAYLOAD 54
// Cellular / Voronoi-style distortion
// ============================================================
DWORD WINAPI GDIPayload54(LPVOID)
{
    const PhoenixHppdSeedVariant& sd = PhoenixHppdSeedGet(54);
    (void)sd;

    HDC dc = GetDC(nullptr);

    if (!dc)
        return 0;

    int w = GetDeviceCaps(dc, HORZRES);
    int h = GetDeviceCaps(dc, VERTRES);

    GDIBuffer buf;

    if (!CreateBuffer(dc, buf, w, h))
    {
        ReleaseDC(nullptr, dc);
        return 0;
    }

    const int cell = 80;

    // RAM cache (frame-invariant): each pixel's cell-space
    // position fx/fy and cell index gx/gy only depend on x/y,
    // so the division + floorf are done ONCE here instead of
    // for every pixel of every frame.
    std::vector<float> colFx(w);
    std::vector<float> colGx(w);
    std::vector<float> rowFy(h);
    std::vector<float> rowGy(h);

    for (int x = 0; x < w; ++x)
    {
        colFx[x] = x / (float)cell;
        colGx[x] = floorf(colFx[x]);
    }

    for (int y = 0; y < h; ++y)
    {
        rowFy[y] = y / (float)cell;
        rowGy[y] = floorf(rowFy[y]);
    }

    // RAM cache (refilled per frame): the feature-point trig
    // in the 3x3 cell search only depends on the CELL index
    // and t - sinf(gy + oy + t) / cosf(gx + ox - t) - yet the
    // old loop re-evaluated both 9 times per pixel. One entry
    // per possible cell coordinate (index = cell + 1, covering
    // the -1 neighbour) reduces that to ~w/80 + h/80 trig
    // calls per frame. Table values use the exact same float
    // expressions as the old inner loop.
    const int maxCellX = static_cast<int>(colGx[w - 1]);
    const int maxCellY = static_cast<int>(rowGy[h - 1]);

    std::vector<float> sinCellY(maxCellY + 3);
    std::vector<float> cosCellX(maxCellX + 3);

    for (int frame = 0; frame < 160; ++frame)
    {
        if (FXAbort())
            break;

        // Repaint the whole screen every 4th frame only.
        if ((frame & 3) != 0)
        {
            Sleep(1);
            continue;
        }

        BitBlt(
            buf.dc,
            0,
            0,
            w,
            h,
            dc,
            0,
            0,
            SRCCOPY
        );

        float t =
            frame * .035f;

        // Refill the per-frame cell trig tables (see the RAM
        // cache built before the frame loop) and hoist the
        // frame-constant sinf(t) out of the pixel loop.
        for (int c = -1; c <= maxCellY + 1; ++c)
            sinCellY[c + 1] = sinf(static_cast<float>(c) + t);

        for (int c = -1; c <= maxCellX + 1; ++c)
            cosCellX[c + 1] = cosf(static_cast<float>(c) - t);

        const float sinT = sinf(t);

        for (int y = 0; y < h; ++y)
        {
            for (int x = 0; x < w; ++x)
            {
                // Cell-space position/index from the RAM cache.
                float fx =
                    colFx[x];

                float fy =
                    rowFy[y];

                float gx =
                    colGx[x];

                float gy =
                    rowGy[y];

                float best = 999999.0f;

                for (int oy = -1; oy <= 1; ++oy)
                {
                    for (int ox = -1; ox <= 1; ++ox)
                    {
                        float px =
                            gx + ox +
                            .5f *
                            sinCellY[
                                static_cast<int>(gy) + oy + 1
                            ];

                        float py =
                            gy + oy +
                            .5f *
                            cosCellX[
                                static_cast<int>(gx) + ox + 1
                            ];

                        float dx = fx - px;
                        float dy = fy - py;

                        float d =
                            dx * dx +
                            dy * dy;

                        best =
                            std::min(best, d);
                    }
                }

                float edge =
                    expf(-best * 35.0f);

                buf.pixels[y * w + x] =
                    PhoenixHppdShiftHSL(
                        buf.pixels[y * w + x],
                        edge *
                        sinT *
                        .3f,
                        edge * .08f,
                        0.0f
                    );
            }
        }

        BitBlt(
            dc,
            0,
            0,
            w,
            h,
            buf.dc,
            0,
            0,
            SRCCOPY
        );
    }

    DestroyBuffer(buf);

    ReleaseDC(nullptr, dc);

    return 0;
}

// ============================================================
// PAYLOAD 55
// Sine-folding distortion
// ============================================================
DWORD WINAPI GDIPayload55(LPVOID)
{
    const PhoenixHppdSeedVariant& sd = PhoenixHppdSeedGet(55);

    HDC dc = GetDC(nullptr);

    if (!dc)
        return 0;

    int w = GetDeviceCaps(dc, HORZRES);
    int h = GetDeviceCaps(dc, VERTRES);

    GDIBuffer buf;

    if (!CreateBuffer(dc, buf, w, h))
    {
        ReleaseDC(nullptr, dc);
        return 0;
    }

    // RAM cache: the normalised coordinates and their scaled
    // forms only depend on x or y, so build them ONCE here.
    // rowSin/colCos are refilled per frame (they carry t);
    // the rest never change. This halves the per-pixel trig:
    // the inner sinf(ny * 8 + t) / cosf(nx * 9 + t) become
    // table reads, leaving only the two outer sinf calls.
    std::vector<float> colNx17(w);
    std::vector<float> colNx9(w);
    std::vector<float> rowNy13(h);
    std::vector<float> rowNy8(h);
    std::vector<float> colCos(w);
    std::vector<float> rowSin(h);

    // Bolt optimization: Precompute sin/cos for frame-invariant terms to apply angle-addition identities.
    std::vector<float> sinNx17(w);
    std::vector<float> cosNx17(w);
    std::vector<float> sinNy13(h);
    std::vector<float> cosNy13(h);

    for (int x = 0; x < w; ++x)
    {
        const float nx =
            (x - w * .5f) /
            (float)w;

        colNx17[x] = nx * 17.0f;
        colNx9[x] = nx * 9.0f;
        sinNx17[x] = sinf(colNx17[x]);
        cosNx17[x] = cosf(colNx17[x]);
    }

    for (int y = 0; y < h; ++y)
    {
        const float ny =
            (y - h * .5f) /
            (float)h;

        rowNy13[y] = ny * 13.0f;
        rowNy8[y] = ny * 8.0f;
        sinNy13[y] = sinf(rowNy13[y]);
        cosNy13[y] = cosf(rowNy13[y]);
    }

    // Bolt optimization: Frame-varying tables for angle-addition identity
    std::vector<float> sinRowSin(h);
    std::vector<float> cosRowSin(h);
    std::vector<float> sinColCos(w);
    std::vector<float> cosColCos(w);

    for (int frame = 0; frame < 230; ++frame)
    {
        if (FXAbort())
            break;

        // Repaint the whole screen every 4th frame only.
        if ((frame & 3) != 0)
        {
            Sleep(1);
            continue;
        }

        BitBlt(
            buf.dc,
            0,
            0,
            w,
            h,
            dc,
            0,
            0,
            SRCCOPY
        );

        float t =
            frame * .04f;

        // Refill the two time-carrying axis tables.
        for (int x = 0; x < w; ++x)
        {
            float cx = cosf(colNx9[x] + t);
            colCos[x] = cx;
            sinColCos[x] = sinf(cx);
            cosColCos[x] = cosf(cx);
        }

        for (int y = 0; y < h; ++y)
        {
            float ry = sinf(rowNy8[y] + t);
            rowSin[y] = ry;
            sinRowSin[y] = sinf(ry);
            cosRowSin[y] = cosf(ry);
        }

        for (int y = 0; y < h; ++y)
        {
            float sinRy = sinRowSin[y];
            float cosRy = cosRowSin[y];
            float sinNy = sinNy13[y];
            float cosNy = cosNy13[y];

            for (int x = 0; x < w; ++x)
            {
                // Bolt optimization: Replace O(w * h) nested trig calls with O(w * h) basic math
                // by using sin(A +/- B) angle-addition identities.
                float q = sinNx17[x] * cosRy + cosNx17[x] * sinRy;
                float r = sinNy * cosColCos[x] - cosNy * sinColCos[x];

                int sx =
                    ClampI(
                        x +
                        (int)(
                            q *
                            (12 + sd.amp)
                        ),
                        0,
                        w - 1
                    );

                int sy =
                    ClampI(
                        y +
                        (int)(
                            r *
                            (12 + sd.amp)
                        ),
                        0,
                        h - 1
                    );

                uint32_t p =
                    buf.pixels[sy * w + sx];

                buf.pixels[y * w + x] =
                    PhoenixHppdShiftHSL(
                        p,
                        (q - r) * .08f,
                        0.0f,
                        0.0f
                    );
            }
        }

        BitBlt(
            dc,
            0,
            0,
            w,
            h,
            buf.dc,
            0,
            0,
            SRCCOPY
        );
    }

    DestroyBuffer(buf);

    ReleaseDC(nullptr, dc);

    return 0;
}

// ============================================================
// PAYLOAD 56
// Radial chromatic aberration
// ============================================================
DWORD WINAPI GDIPayload56(LPVOID)
{
    const PhoenixHppdSeedVariant& sd = PhoenixHppdSeedGet(56);
    (void)sd;

    HDC dc = GetDC(nullptr);

    if (!dc)
        return 0;

    int w = GetDeviceCaps(dc, HORZRES);
    int h = GetDeviceCaps(dc, VERTRES);

    GDIBuffer buf;

    if (!CreateBuffer(dc, buf, w, h))
    {
        ReleaseDC(nullptr, dc);
        return 0;
    }

    int cx = w / 2;
    int cy = h / 2;

    // RAM cache: every pixel's distance from the centre is
    // the same on every frame, so the sqrtf runs ONCE here
    // and frames just read the radius back (gdi/fxcache.h
    // documents the shared polar-cache scheme; this payload
    // only needs the radius part).
    FxCache::PolarMap polar;

    polar.Build(
        w, h,
        static_cast<float>(cx),
        static_cast<float>(cy),
        FxCache::PolarRadius
    );

    // Bolt optimization: Cache sin/cos of radius outside the frame loop
    const size_t pixelCount = static_cast<size_t>(w) * static_cast<size_t>(h);
    std::vector<float> sinR(pixelCount);
    std::vector<float> cosR(pixelCount);
    for (size_t i = 0; i < pixelCount; ++i)
    {
        sinR[i] = sinf(polar.radius[i] * 0.02f);
        cosR[i] = cosf(polar.radius[i] * 0.02f);
    }

    for (int frame = 0; frame < 260; ++frame)
    {
        if (FXAbort())
            break;

        // Repaint the whole screen every 4th frame only.
        if ((frame & 3) != 0)
        {
            Sleep(1);
            continue;
        }

        BitBlt(
            buf.dc,
            0,
            0,
            w,
            h,
            dc,
            0,
            0,
            SRCCOPY
        );

        float t =
            frame * .055f;
        (void)t;

        // Bolt optimization: Time terms using angle-addition identity
        const float t4 = frame * .055f * 4.0f;
        const float cosT = cosf(t4);
        const float sinT = sinf(t4);

        for (int y = 0; y < h; ++y)
        {
            for (int x = 0; x < w; ++x)
            {
                float dx = (float)(x - cx);
                float dy = (float)(y - cy);

                const size_t pi = static_cast<size_t>(y) * w + x;

                float factor =
                    1.0f +
                    (sinR[pi] * cosT - cosR[pi] * sinT) *
                    .035f;

                int rx =
                    ClampI(
                        cx + (int)(dx * factor * 1.025f),
                        0,
                        w - 1
                    );

                int gx =
                    ClampI(
                        cx + (int)(dx * factor),
                        0,
                        w - 1
                    );

                int bx =
                    ClampI(
                        cx + (int)(dx * factor * .975f),
                        0,
                        w - 1
                    );

                int ry =
                    ClampI(
                        cy + (int)(dy * factor * 1.025f),
                        0,
                        h - 1
                    );

                int gy =
                    ClampI(
                        cy + (int)(dy * factor),
                        0,
                        h - 1
                    );

                int by =
                    ClampI(
                        cy + (int)(dy * factor * .975f),
                        0,
                        h - 1
                    );

                int rr, rg, rb;

                SplitRGB(
                    buf.pixels[ry * w + rx],
                    rr,
                    rg,
                    rb
                );

                int gr, gg, gb;

                SplitRGB(
                    buf.pixels[gy * w + gx],
                    gr,
                    gg,
                    gb
                );

                int br, bg, bb;

                SplitRGB(
                    buf.pixels[by * w + bx],
                    br,
                    bg,
                    bb
                );

                buf.pixels[y * w + x] =
                    RGBPixel(
                        rr,
                        gg,
                        bb
                    );
            }
        }

        BitBlt(
            dc,
            0,
            0,
            w,
            h,
            buf.dc,
            0,
            0,
            SRCCOPY
        );
    }

    DestroyBuffer(buf);

    ReleaseDC(nullptr, dc);

    return 0;
}

// ============================================================
// PAYLOAD 57
// Recursive mirror feedback
// ============================================================
DWORD WINAPI GDIPayload57(LPVOID)
{
    const PhoenixHppdSeedVariant& sd = PhoenixHppdSeedGet(57);

    HDC dc = GetDC(nullptr);

    if (!dc)
        return 0;

    int w = GetDeviceCaps(dc, HORZRES);
    int h = GetDeviceCaps(dc, VERTRES);

    GDIBuffer a;
    GDIBuffer b;

    if (!CreateBuffer(dc, a, w, h))
    {
        ReleaseDC(nullptr, dc);
        return 0;
    }

    if (!CreateBuffer(dc, b, w, h))
    {
        DestroyBuffer(a);
        ReleaseDC(nullptr, dc);
        return 0;
    }

    SetStretchBltMode(
        a.dc,
        HALFTONE
    );

    SetStretchBltMode(
        b.dc,
        HALFTONE
    );

    for (int frame = 0; frame < 350; ++frame)
    {
        if (FXAbort())
            break;

        // Repaint the whole screen every 4th frame only.
        if ((frame & 3) != 0)
        {
            Sleep(1);
            continue;
        }

        BitBlt(
            a.dc,
            0,
            0,
            w,
            h,
            dc,
            0,
            0,
            SRCCOPY
        );

        float t =
            frame * .035f;

        int margin =
            8 +
            (int)(
                sinf(t * 2.0f) *
                (4 + sd.amp)
            );

        StretchBlt(
            b.dc,
            margin,
            margin,
            w - margin * 2,
            h - margin * 2,
            a.dc,
            0,
            0,
            w,
            h,
            SRCCOPY
        );

        StretchBlt(
            b.dc,
            0,
            0,
            w,
            h,
            b.dc,
            0,
            0,
            w,
            h,
            SRCINVERT
        );

        AlphaBlend(
            a.dc,
            0,
            0,
            w,
            h,
            b.dc,
            0,
            0,
            w,
            h,
            {
                AC_SRC_OVER,
                0,
                38,
                0
            }
        );

        int wobble =
            (int)(
                sinf(t * 3.0f) *
                (5 + sd.amp)
            );

        BitBlt(
            dc,
            wobble,
            0,
            w - abs(wobble),
            h,
            a.dc,
            0,
            0,
            SRCCOPY
        );
    }

    DestroyBuffer(a);
    DestroyBuffer(b);

    ReleaseDC(nullptr, dc);

    return 0;
}

// ============================================================
// PAYLOAD 58
// Temporal echo stack (ghost trail) - per-pixel frame
// accumulation of the last N frames, fading + rotating.
// ============================================================
DWORD WINAPI GDIPayload58(LPVOID)
{
    const PhoenixHppdSeedVariant& sd = PhoenixHppdSeedGet(58);
    srand(PhoenixHppdSeedRand(58));

    HDC dc = GetDC(nullptr);

    if (!dc)
        return 0;

    const int w = GetDeviceCaps(dc, HORZRES);
    const int h = GetDeviceCaps(dc, VERTRES);

    GDIBuffer a;
    GDIBuffer b;
    GDIBuffer snap;

    if (!CreateBuffer(dc, a, w, h))
    {
        ReleaseDC(nullptr, dc);
        return 0;
    }

    if (!CreateBuffer(dc, b, w, h))
    {
        DestroyBuffer(a);
        ReleaseDC(nullptr, dc);
        return 0;
    }

    if (!CreateBuffer(dc, snap, w, h))
    {
        DestroyBuffer(a);
        DestroyBuffer(b);
        ReleaseDC(nullptr, dc);
        return 0;
    }

    const int layers = 3 + (sd.amp % 3);
    const float scaleUp = 0.86f;
    (void)scaleUp;
    const float rotStep = (float)(sd.phase - 1024) / 1024.0f * 0.02f;

    // RAM cache (refilled per layer): the rotated coordinates
    // are separable - x * c, x * s depend only on x and
    // y * s, y * c only on y - so the four per-pixel float
    // multiplies become two table reads + one add/subtract.
    std::vector<float> xCos(w);
    std::vector<float> xSin(w);
    std::vector<float> ySin(h);
    std::vector<float> yCos(h);

    for (int frame = 0; frame < 260; ++frame)
    {
        if (FXAbort())
            break;

        // Repaint the whole screen every 4th frame only.
        if ((frame & 3) != 0)
        {
            Sleep(1);
            continue;
        }

        BitBlt(snap.dc, 0, 0, w, h, dc, 0, 0, SRCCOPY);

        for (int i = 0; i < layers; ++i)
        {
            float t = frame * 0.03f + i * 0.4f;
            float ang = t * rotStep;
            float c = cosf(ang);
            float s = sinf(ang);

            // Refill this layer's axis tables + hoist the
            // per-pixel (int)(t * 6) shift (layer-constant).
            for (int x = 0; x < w; ++x)
            {
                xCos[x] = x * c;
                xSin[x] = x * s;
            }

            for (int y = 0; y < h; ++y)
            {
                ySin[y] = y * s;
                yCos[y] = y * c;
            }

            const int tShift = (int)(t * 6);

            for (int y = 0; y < h; ++y)
            {
                for (int x = 0; x < w; ++x)
                {
                    int xm = (int)(xCos[x] - ySin[y]) + tShift;
                    int ym = (int)(xSin[x] + yCos[y]);

                    xm = (xm + w) % w;
                    ym = (ym + h) % h;

                    uint32_t p = snap.pixels[ym * w + xm];

                    int r, g, bl;
                    SplitRGB(p, r, g, bl);

                    float f = 0.22f;
                    r = (int)(r * f);
                    g = (int)(g * f);
                    bl = (int)(bl * f);

                    b.pixels[y * w + x] =
                        RGBPixel(r, g, bl);
                }
            }

            BitBlt(snap.dc, 0, 0, w, h, b.dc, 0, 0, SRCCOPY);
        }

        BitBlt(dc, 0, 0, w, h, snap.dc, 0, 0, SRCCOPY);
    }

    DestroyBuffer(snap);
    DestroyBuffer(b);
    DestroyBuffer(a);

    ReleaseDC(nullptr, dc);

    return 0;
}

// ============================================================
// PAYLOAD 59
// Liquid crystal / interference fringes - multi-source wave
// interference mapped to hue, overlaid on live capture.
// ============================================================
DWORD WINAPI GDIPayload59(LPVOID)
{
    const PhoenixHppdSeedVariant& sd = PhoenixHppdSeedGet(59);
    srand(PhoenixHppdSeedRand(59));

    HDC dc = GetDC(nullptr);

    if (!dc)
        return 0;

    const int w = GetDeviceCaps(dc, HORZRES);
    const int h = GetDeviceCaps(dc, VERTRES);

    GDIBuffer src;
    GDIBuffer out;

    if (!CreateBuffer(dc, src, w, h))
    {
        ReleaseDC(nullptr, dc);
        return 0;
    }

    if (!CreateBuffer(dc, out, w, h))
    {
        DestroyBuffer(src);
        ReleaseDC(nullptr, dc);
        return 0;
    }

    const int sources = 3 + (sd.amp % 2);
    const float speed = 0.015f + sd.amp * 0.003f;

    // RAM cache: the wave sources never move (their positions
    // have no time term), so each source's per-pixel distance
    // - and the d * 0.03f phase fed to sinf - is identical on
    // every frame. Compute the sqrtf ONCE here into srcPhase
    // (one float map per source) and let frames read it back
    // instead of redoing sources * w * h sqrtf per frame.
    std::vector<float> src_x(sources);
    std::vector<float> src_y(sources);

    for (int i = 0; i < sources; ++i)
    {
        src_x[i] = w * 0.5f + cosf(sd.phase + i * 4.1f) * w * 0.25f;
        src_y[i] = h * 0.5f + sinf(sd.phase + i * 2.7f) * h * 0.25f;
    }

    const size_t pixelCount =
        static_cast<size_t>(w) * static_cast<size_t>(h);

    std::vector<float> srcPhase(
        static_cast<size_t>(sources) * pixelCount
    );

    for (int i = 0; i < sources; ++i)
    {
        for (int y = 0; y < h; ++y)
        {
            for (int x = 0; x < w; ++x)
            {
                float dx = x - src_x[i];
                float dy = y - src_y[i];
                float d = sqrtf(dx * dx + dy * dy);

                srcPhase[
                    static_cast<size_t>(i) * pixelCount +
                    static_cast<size_t>(y) * w + x
                ] = d * 0.03f;
            }
        }
    }

    for (int frame = 0; frame < 260; ++frame)
    {
        if (FXAbort())
            break;

        // Repaint the whole screen every 4th frame only.
        if ((frame & 3) != 0)
        {
            Sleep(1);
            continue;
        }

        BitBlt(src.dc, 0, 0, w, h, dc, 0, 0, SRCCOPY);

        const float t = frame * 0.02f * speed;

        // Source positions + per-source distance phases come
        // from the RAM cache built before the frame loop
        // (they are frame-invariant; see above).

        for (int y = 0; y < h; ++y)
        {
            for (int x = 0; x < w; ++x)
            {
                const size_t pi =
                    static_cast<size_t>(y) * w + x;

                float acc = 0.0f;

                for (int i = 0; i < sources; ++i)
                {
                    const float phase =
                        srcPhase[
                            static_cast<size_t>(i) * pixelCount + pi
                        ];

                    acc += sinf(phase - t - i * 2.0f) * 0.5f + 0.5f;
                }

                float n = acc / (float)sources;

                float hh = n;
                float ss = 0.8f;
                float ll = 0.4f + n * 0.3f;

                RGBQUAD rgb{};
                rgb.rgbRed = (BYTE)(121.0f * n + 80);
                rgb.rgbGreen = (BYTE)(255.0f * (1.0f - n));
                rgb.rgbBlue = (BYTE)(160.0f * n + 40);

                uint32_t fringe =
                    PhoenixHppdPackRGB(rgb.rgbRed, rgb.rgbGreen, rgb.rgbBlue);

                uint32_t p = src.pixels[y * w + x];

                int r, g, bl;
                SplitRGB(p, r, g, bl);

                r = (int)(r * 0.5f + (rgb.rgbRed * 0.5f));
                g = (int)(g * 0.5f + (rgb.rgbGreen * 0.5f));
                bl = (int)(bl * 0.5f + (rgb.rgbBlue * 0.5f));

                (void)fringe;
                (void)hh;
                (void)ss;
                (void)ll;

                out.pixels[y * w + x] = RGBPixel(r, g, bl);
            }
        }

        BitBlt(dc, 0, 0, w, h, out.dc, 0, 0, SRCCOPY);
    }

    DestroyBuffer(out);
    DestroyBuffer(src);

    ReleaseDC(nullptr, dc);

    return 0;
}

// ============================================================
// PAYLOAD 60
// Pixel sort - classic column-based luma sort with random
// threshold gates, over the live capture.
// ============================================================
DWORD WINAPI GDIPayload60(LPVOID)
{
    const PhoenixHppdSeedVariant& sd = PhoenixHppdSeedGet(60);
    (void)sd;
    srand(PhoenixHppdSeedRand(60));

    HDC dc = GetDC(nullptr);

    if (!dc)
        return 0;

    const int w = GetDeviceCaps(dc, HORZRES);
    const int h = GetDeviceCaps(dc, VERTRES);

    GDIBuffer buf;

    if (!CreateBuffer(dc, buf, w, h))
    {
        ReleaseDC(nullptr, dc);
        return 0;
    }

    for (int frame = 0; frame < 260; ++frame)
    {
        if (FXAbort())
            break;

        // Repaint the whole screen every 4th frame only.
        if ((frame & 3) != 0)
        {
            Sleep(1);
            continue;
        }

        BitBlt(buf.dc, 0, 0, w, h, dc, 0, 0, SRCCOPY);

        const int gate =
            64 + (int)((rand() % 96) * (0.75f + frame * 0.001f));

        for (int x = 0; x < w; ++x)
        {
            int start = 0;

            for (int y = 0; y <= h; ++y)
            {
                int luma = 0;

                if (y < h)
                {
                    uint32_t p = buf.pixels[y * w + x];
                    int r = p & 255;
                    int g = (p >> 8) & 255;
                    int bl = (p >> 16) & 255;
                    luma = (r + g + bl) / 3;
                }

                if (y == h || luma <= gate)
                {
                    if (y - start > 1)
                    {
                        int lo = start;
                        int hi = y;

                        if (y == h)
                            hi = h;

                        for (int i = lo; i < hi - 1; ++i)
                        {
                            for (int j = lo; j < hi - 1; ++j)
                            {
                                uint32_t pa = buf.pixels[j * w + x];
                                uint32_t pb = buf.pixels[(j + 1) * w + x];

                                int la = pa & 255;
                                int lb = pb & 255;

                                if (lb < la)
                                {
                                    buf.pixels[j * w + x] = pb;
                                    buf.pixels[(j + 1) * w + x] = pa;
                                }
                            }
                        }
                    }

                    start = y + 1;
                }
            }
        }

        BitBlt(dc, 0, 0, w, h, buf.dc, 0, 0, SRCCOPY);
    }

    DestroyBuffer(buf);

    ReleaseDC(nullptr, dc);

    return 0;
}

// ============================================================
// PAYLOAD 61
// Fractal Julia set RGB overlay - per-pixel Julia iteration
// colors the offset by its iteration depth, blended in.
// ============================================================
DWORD WINAPI GDIPayload61(LPVOID)
{
    const PhoenixHppdSeedVariant& sd = PhoenixHppdSeedGet(61);
    srand(PhoenixHppdSeedRand(61));

    HDC dc = GetDC(nullptr);

    if (!dc)
        return 0;

    const int w = GetDeviceCaps(dc, HORZRES);
    const int h = GetDeviceCaps(dc, VERTRES);

    GDIBuffer buf;

    if (!CreateBuffer(dc, buf, w, h))
    {
        ReleaseDC(nullptr, dc);
        return 0;
    }

    const double scale = 0.0028 + sd.amp * 0.0002;
    const double cr = -0.744;
    const double ci = 0.148;

    // RAM cache: the Julia start point separates into a
    // per-column part (only the frame time shift is added per
    // frame) and a per-row part, and the iteration-depth ->
    // colour mapping has just 64 possible inputs. Cache both
    // so the per-pixel loop keeps only the (inherently
    // time-varying) Julia iteration itself.
    std::vector<double> colZx(w);
    std::vector<double> rowZy(h);

    for (int x = 0; x < w; ++x)
        colZx[x] = (x - w * 0.5) * scale;

    for (int y = 0; y < h; ++y)
        rowZy[y] = (y - h * 0.5) * scale;

    int iterR[64];
    int iterG[64];
    int iterB[64];

    for (int iter = 0; iter < 64; ++iter)
    {
        const double f = iter / 64.0;

        iterR[iter] = (int)(f * 255);
        iterG[iter] = (int)((1.0 - f) * 200);
        iterB[iter] = (int)(255 - f * 150);
    }

    for (int frame = 0; frame < 260; ++frame)
    {
        if (FXAbort())
            break;

        // Repaint the whole screen every 4th frame only.
        if ((frame & 3) != 0)
        {
            Sleep(1);
            continue;
        }

        BitBlt(buf.dc, 0, 0, w, h, dc, 0, 0, SRCCOPY);

        const double t = frame * 0.004;

        for (int y = 0; y < h; ++y)
        {
            for (int x = 0; x < w; ++x)
            {
                double zx =
                    colZx[x] + t * 0.2;
                double zy =
                    rowZy[y];
                double ox = zx;
                double oy = zy;
                int iter = 0;

                while (iter < 64 && (zx * zx + zy * zy) < 16.0)
                {
                    double nx = zx * zx - zy * zy + cr;
                    double ny = 2.0 * zx * zy + ci;
                    zx = nx;
                    zy = ny;
                    ++iter;
                }

                if (iter == 64)
                {
                    buf.pixels[y * w + x] = RGBPixel(0, 0, 0);
                    continue;
                }

                // Iteration colour from the 64-entry RAM LUT.
                int r = iterR[iter];
                int g = iterG[iter];
                int bl = iterB[iter];

                uint32_t p = buf.pixels[y * w + x];
                int sr, sg, sb;
                SplitRGB(p, sr, sg, sb);

                (void)ox;
                (void)oy;

                sr = (int)(sr * 0.4 + r * 0.6);
                sg = (int)(sg * 0.4 + g * 0.6);
                sb = (int)(sb * 0.4 + bl * 0.6);

                buf.pixels[y * w + x] = RGBPixel(sr, sg, sb);
            }
        }

        BitBlt(dc, 0, 0, w, h, buf.dc, 0, 0, SRCCOPY);
    }

    DestroyBuffer(buf);

    ReleaseDC(nullptr, dc);

    return 0;
}

// ============================================================
// PAYLOAD 62
// Turbulent flow field - pseudo-noise vector field advects a
// fading trace, hues shift along the flow.
// ============================================================
DWORD WINAPI GDIPayload62(LPVOID)
{
    const PhoenixHppdSeedVariant& sd = PhoenixHppdSeedGet(62);
    srand(PhoenixHppdSeedRand(62));

    HDC dc = GetDC(nullptr);

    if (!dc)
        return 0;

    const int w = GetDeviceCaps(dc, HORZRES);
    const int h = GetDeviceCaps(dc, VERTRES);

    GDIBuffer a;
    GDIBuffer b;

    if (!CreateBuffer(dc, a, w, h))
    {
        ReleaseDC(nullptr, dc);
        return 0;
    }

    if (!CreateBuffer(dc, b, w, h))
    {
        DestroyBuffer(a);
        ReleaseDC(nullptr, dc);
        return 0;
    }

    const float step = 3.0f + sd.amp * 0.5f;
    const float freq = 0.008f + sd.amp * 0.001f;

    // RAM cache (refilled per frame): the flow field separates
    // into sinf(x-term) * cosf(y-term) plus a diagonal term in
    // (x + y). Evaluating those as axis/diagonal tables costs
    // w + h + (w + h) trig calls per frame instead of 3 per
    // pixel; only the flow angle's cosf/sinf stays per pixel.
    std::vector<float> sinX(w);
    std::vector<float> cosY(h);
    std::vector<float> sinDiag(w + h);

    for (int frame = 0; frame < 260; ++frame)
    {
        if (FXAbort())
            break;

        // Repaint the whole screen every 4th frame only.
        if ((frame & 3) != 0)
        {
            Sleep(1);
            continue;
        }

        // Refill the axis/diagonal tables for this frame.
        for (int x = 0; x < w; ++x)
            sinX[x] = sinf(x * freq + frame * 0.03f);

        for (int y = 0; y < h; ++y)
            cosY[y] = cosf(y * freq - frame * 0.02f);

        for (int s = 0; s < w + h; ++s)
            sinDiag[s] = sinf(s * freq * 0.5f + sd.phase * 0.001f);

        for (int y = 0; y < h; ++y)
        {
            for (int x = 0; x < w; ++x)
            {
                float n =
                    sinX[x] *
                    cosY[y] +
                    sinDiag[x + y] * 0.6f;

                float angle = n * 6.2831853f;

                int sx = x + (int)(cosf(angle) * step);
                int sy = y + (int)(sinf(angle) * step);

                uint32_t p;

                if (sx >= 0 && sx < w && sy >= 0 && sy < h)
                    p = a.pixels[sy * w + sx];
                else
                    p = RGBPixel(0, 0, 0);

                int r, g, bl;
                SplitRGB(p, r, g, bl);

                float hueMul = (n * 0.5f + 0.5f);

                r = (int)(r * hueMul);
                g = (int)(g * (1.0f - hueMul * 0.5f));
                bl = (int)(bl * (0.5f + hueMul * 0.5f));

                b.pixels[y * w + x] = RGBPixel(r, g, bl);
            }
        }

        BitBlt(a.dc, 0, 0, w, h, dc, 0, 0, SRCCOPY);
        BitBlt(dc, 0, 0, w, h, b.dc, 0, 0, SRCCOPY);
    }

    DestroyBuffer(b);
    DestroyBuffer(a);

    ReleaseDC(nullptr, dc);

    return 0;
}

// ============================================================
// PAYLOAD 63
// Reaction - diffusion overlay (Gray-Scott) - simulates B-Z
// / Gray-Scott on a small grid and blends it over the capture.
// ============================================================
DWORD WINAPI GDIPayload63(LPVOID)
{
    const PhoenixHppdSeedVariant& sd = PhoenixHppdSeedGet(63);
    srand(PhoenixHppdSeedRand(63));

    HDC dc = GetDC(nullptr);

    if (!dc)
        return 0;

    const int w = GetDeviceCaps(dc, HORZRES);
    const int h = GetDeviceCaps(dc, VERTRES);

    GDIBuffer buf;

    if (!CreateBuffer(dc, buf, w, h))
    {
        ReleaseDC(nullptr, dc);
        return 0;
    }

    const int gw = 160;
    const int gh = 90;
    const int steps = 4;

    std::vector<float> U(gw * gh, 1.0f);
    std::vector<float> V(gw * gh, 0.0f);

    srand(PhoenixHppdSeedRand(63));

    const float DA = 1.0f;
    const float DB = 0.5f;
    const float feed = 0.055f + sd.amp * 0.002f;
    const float kill = 0.062f;

    const int cx0 = gw / 2;
    const int cy0 = gh / 2;

    // RAM cache: the screen -> simulation-grid coordinate
    // maps only depend on x/y and the (fixed) grid size, so
    // the per-pixel multiply + integer divide runs ONCE here
    // instead of for every pixel of every frame.
    std::vector<int> colGx(w);
    std::vector<int> rowGy(h);

    for (int x = 0; x < w; ++x)
        colGx[x] = (x * gw) / w;

    for (int y = 0; y < h; ++y)
        rowGy[y] = (y * gh) / h;

    for (int frame = 0; frame < 260; ++frame)
    {
        if (FXAbort())
            break;

        // Repaint the whole screen every 4th frame only.
        if ((frame & 3) != 0)
        {
            Sleep(1);
            continue;
        }

        for (int s = 0; s < steps; ++s)
        {
            for (int y = 1; y < gh - 1; ++y)
            {
                for (int x = 1; x < gw - 1; ++x)
                {
                    float u0 = U[y * gw + x];
                    float v0 = V[y * gw + x];

                    float s1 = -1.0f, s2 = 1.0f;

                    float lapU =
                        U[y * gw + (x + (int)s1)] +
                        U[y * gw + (x + (int)s2)] +
                        U[(y + (int)s1) * gw + x] +
                        U[(y + (int)s2) * gw + x] -
                        4.0f * u0;

                    float lapV =
                        V[y * gw + (x + (int)s1)] +
                        V[y * gw + (x + (int)s2)] +
                        V[(y + (int)s1) * gw + x] +
                        V[(y + (int)s2) * gw + x] -
                        4.0f * v0;

                    float reaction = u0 * v0 * v0;

                    float du = DA * lapU - reaction + feed * (1.0f - u0);
                    float dv = DB * lapV + reaction - (kill + feed) * v0;

                    U[y * gw + x] += du * 0.02f;
                    V[y * gw + x] += dv * 0.02f;
                }
            }

            int seedPts = 24;

            for (int i = 0; i < seedPts; ++i)
            {
                int px = cx0 + (rand() % 17) - 8;
                int py = cy0 + (rand() % 17) - 8;

                px = (px + gw) % gw;
                py = (py + gh) % gh;

                V[py * gw + px] = 1.0f;
            }
        }

        BitBlt(buf.dc, 0, 0, w, h, dc, 0, 0, SRCCOPY);

        for (int y = 0; y < h; ++y)
        {
            for (int x = 0; x < w; ++x)
            {
                int gx = colGx[x];
                int gy = rowGy[y];

                float v = V[gy * gw + gx];

                uint32_t p = buf.pixels[y * w + x];

                int r, g, bl;
                SplitRGB(p, r, g, bl);

                float over = 0.35f + v * 0.65f;

                r = (int)(r * (1.0f - over * 0.5f) + 200 * over * 0.5f);
                g = (int)(g * (1.0f - over * 0.5f) + (10 + v * 240) * over * 0.5f);
                bl = (int)(bl * (1.0f - over * 0.5f) + (30 + v * 60) * over * 0.5f);

                buf.pixels[y * w + x] = RGBPixel(r, g, bl);
            }
        }

        BitBlt(dc, 0, 0, w, h, buf.dc, 0, 0, SRCCOPY);
    }

    DestroyBuffer(buf);

    ReleaseDC(nullptr, dc);

    return 0;
}

#endif /* _WIN32 */
