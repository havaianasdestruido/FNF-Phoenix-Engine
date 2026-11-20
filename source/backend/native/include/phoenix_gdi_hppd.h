#ifndef PHOENIX_GDI_HPPD_H
#define PHOENIX_GDI_HPPD_H

/**
 * Native Windows GDI payloads ported from HPPD (Hallucinogen Persisting
 * Perception Disorder), https://github.com/havaianasdestruido/HPPD
 * (Apache License 2.0).
 *
 * This header is the single shared surface for the HPPD port: the seed
 * system, the HSL helpers, the shared DIB surfaces, the FX timing helpers
 * and the payload declarations. It replaces HPPD's payloads.h,
 * gdi/gdibuffer.h, gdi/fxcache.h, utils/colors.h, utils/seed.h,
 * gdi/light.h and gdi/heavy.h, which are merged here so the Phoenix
 * translation units share one definition.
 *
 * Only the GDI-only payloads are ported (see docs/GDI_HPPD.md for the full
 * catalog and the exclusion rationale):
 * - heavy: 1, 2, 5-11, 13-15, 17, 19-24, 40, 48, 50-63
 * - light: 3, 4, 12, 16, 18, 25-26, 28-49 (except 27, which does not
 *   exist upstream), 69-72
 * - Death Month: the shared RunDeathMask renderer with 31 day variants
 *   (payloads.cpp in HPPD), exposed as IDs 101-131.
 *
 * Deliberately NOT ported (not GDI-only): 64 (XM + MessageBox date egg),
 * 65 (drive eject IOCTL), 66 (printer spooler), 67 (host recon + address
 * book dump), 68 FileInfect (recursive .bat/.ps1/.pdf infection that
 * inserts Stop-Computer payloads), 73 (mouse-button swap) and 74
 * (wallpaper swap via temp file). Those need file, spooler, IOCTL and
 * recon subsystems that have no place in a game engine.
 *
 * Each payload is a DWORD WINAPI thread function that runs for about
 * 5 seconds (or a fixed frame count) and aborts early on ESC or on the
 * Phoenix stop latch. Heavy payloads serialize through a single mutex
 * (HPPD's gHeavySlot); light payloads overlap freely.
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

/* windows.h defines min()/max() as macros unless NOMINMAX is set, which
 * breaks std::min/std::max in the payload translation units when this
 * header is seen before hxcpp.h. Pin it here so the header is safe on
 * its own, in either include order. */
#if !defined(NOMINMAX)
#define NOMINMAX
#endif

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif

#include <windows.h>
#include <cstdint>
#include <algorithm>
#include <atomic>
#include <cmath>
#include <cstddef>
#include <vector>

#if defined(_MSC_VER)
#pragma comment(lib, "Msimg32.lib")
#endif

/* ------------------------------------------------------------------------- */
/*                               SEED SYSTEM                                 */
/* ------------------------------------------------------------------------- */

/**
 * Global runtime seed, picked once when the GDI subsystem initializes.
 * Every payload derives a stable per-payload variant from it so each
 * run looks slightly different. Defined in phoenix_gdi_hppd_common.cpp.
 */
extern uint32_t gPhoenixHppdSeed;

/**
 * Per-payload seed variant: phase, direction, amplitude and RNG state.
 * Computed once per payload ID from the global seed; never per-pixel.
 */
struct PhoenixHppdSeedVariant
{
    int phase;       /**< Extra phase for periodic/wave formulas (0..2047). */
    int dir;         /**< Sign flip, -1 or +1. */
    int amp;         /**< Amplitude / loop / zoom tweak (1..8). */
    uint32_t rng;    /**< Nonzero derived state for FXRand / srand. */
};

/**
 * Returns the cached seed variant for a payload ID.
 * @param payloadId HPPD payload number (1..74, or 101..131 for Death Month).
 * @return Reference to the cached variant (valid for the process lifetime).
 */
const PhoenixHppdSeedVariant& PhoenixHppdSeedGet(int payloadId);

/**
 * Seed value to pass to srand() so rand()-based payloads vary per run.
 * @param payloadId HPPD payload number.
 * @return Unsigned seed derived from the payload variant.
 */
static inline unsigned PhoenixHppdSeedRand(int payloadId)
{
    return static_cast<unsigned>(
        PhoenixHppdSeedGet(payloadId).rng
    );
}

/* ------------------------------------------------------------------------- */
/*                               HSL HELPERS                                 */
/* ------------------------------------------------------------------------- */

/**
 * HSL color in the 0..1 range, as used by the HPPD hue-shift payloads.
 * Ported from HPPD utils/colors.h (originally Wipet / SleepMod via Lixo).
 */
typedef struct
{
    FLOAT h; /**< Hue (0..1). */
    FLOAT s; /**< Saturation (0..1). */
    FLOAT l; /**< Lightness (0..1). */
} PhoenixHppdHSL;

/**
 * HSL <-> RGB conversions used by ShiftHSL. Header-only, like upstream.
 */
namespace PhoenixHppdColors
{
    /**
     * Converts an RGBQUAD to HSL.
     * @param rgb Source color.
     * @return HSL representation.
     */
    static inline PhoenixHppdHSL rgb2hsl(RGBQUAD rgb)
    {
        PhoenixHppdHSL hsl;

        BYTE r = rgb.rgbRed;
        BYTE g = rgb.rgbGreen;
        BYTE b = rgb.rgbBlue;

        FLOAT _r = (FLOAT)r / 255.f;
        FLOAT _g = (FLOAT)g / 255.f;
        FLOAT _b = (FLOAT)b / 255.f;

        FLOAT rgbMin = std::min(std::min(_r, _g), _b);
        FLOAT rgbMax = std::max(std::max(_r, _g), _b);

        FLOAT fDelta = rgbMax - rgbMin;
        FLOAT deltaR;
        FLOAT deltaG;
        FLOAT deltaB;

        FLOAT h = 0.f;
        FLOAT s = 0.f;
        FLOAT l = (FLOAT)((rgbMax + rgbMin) / 2.f);

        if (fDelta != 0.f)
        {
            s = l < .5f ? (FLOAT)(fDelta / (rgbMax + rgbMin)) : (FLOAT)(fDelta / (2.f - rgbMax - rgbMin));
            deltaR = (FLOAT)(((rgbMax - _r) / 6.f + (fDelta / 2.f)) / fDelta);
            deltaG = (FLOAT)(((rgbMax - _g) / 6.f + (fDelta / 2.f)) / fDelta);
            deltaB = (FLOAT)(((rgbMax - _b) / 6.f + (fDelta / 2.f)) / fDelta);

            if (_r == rgbMax)      h = deltaB - deltaG;
            else if (_g == rgbMax) h = (1.f / 3.f) + deltaR - deltaB;
            else if (_b == rgbMax) h = (2.f / 3.f) + deltaG - deltaR;
            if (h < 0.f)           h += 1.f;
            if (h > 1.f)           h -= 1.f;
        }

        hsl.h = h;
        hsl.s = s;
        hsl.l = l;
        return hsl;
    }

    /**
     * Converts HSL to RGBQUAD.
     * @param hsl Source color.
     * @return RGBQUAD representation.
     */
    static inline RGBQUAD hsl2rgb(PhoenixHppdHSL hsl)
    {
        RGBQUAD rgb;

        FLOAT r = hsl.l;
        FLOAT g = hsl.l;
        FLOAT b = hsl.l;

        FLOAT h = hsl.h;
        FLOAT sl = hsl.s;
        FLOAT l = hsl.l;
        FLOAT v = (l <= .5f) ? (l * (1.f + sl)) : (l + sl - l * sl);

        FLOAT m;
        FLOAT sv;
        FLOAT fract;
        FLOAT vsf;
        FLOAT mid1;
        FLOAT mid2;

        INT sextant;

        if (v > 0.f)
        {
            m = l + l - v;
            sv = (v - m) / v;
            h *= 6.f;
            sextant = (INT)h;
            fract = h - sextant;
            vsf = v * sv * fract;
            mid1 = m + vsf;
            mid2 = v - vsf;

            switch (sextant)
            {
                case 0:
                    r = v;
                    g = mid1;
                    b = m;
                    break;
                case 1:
                    r = mid2;
                    g = v;
                    b = m;
                    break;
                case 2:
                    r = m;
                    g = v;
                    b = mid1;
                    break;
                case 3:
                    r = m;
                    g = mid2;
                    b = v;
                    break;
                case 4:
                    r = mid1;
                    g = m;
                    b = v;
                    break;
                case 5:
                    r = v;
                    g = m;
                    b = mid2;
                    break;
            }
        }

        rgb.rgbRed = (BYTE)(r * 255.f);
        rgb.rgbGreen = (BYTE)(g * 255.f);
        rgb.rgbBlue = (BYTE)(b * 255.f);

        return rgb;
    }
}

/* ------------------------------------------------------------------------- */
/*                          SHARED DIB SURFACES                              */
/* ------------------------------------------------------------------------- */

/**
 * Clamps an integer into [low, high].
 * @param value Value to clamp.
 * @param low Lower bound.
 * @param high Upper bound.
 * @return Clamped value.
 */
static inline int PhoenixHppdClampInt(int value, int low, int high)
{
    if (value < low)
        return low;

    if (value > high)
        return high;

    return value;
}

/**
 * Fast shared 32-bit top-down DIB surface used by payloads 13-24.
 * Ported from HPPD payloads.h GDISurface.
 */
struct PhoenixHppdSurface
{
    HDC screen = nullptr;        /**< Screen DC. */
    HDC memDC = nullptr;         /**< Memory DC holding the DIB. */
    HBITMAP bitmap = nullptr;    /**< DIB section bitmap. */
    HGDIOBJ oldBitmap = nullptr; /**< Previously selected bitmap. */
    uint32_t* pixels = nullptr;  /**< Pixel pointer (BGRx, top-down). */
    int w = 0;                   /**< Width in pixels. */
    int h = 0;                   /**< Height in pixels. */

    /**
     * Creates the screen-sized DIB surface.
     * @return true on success, false if any GDI call failed.
     */
    bool Init()
    {
        screen = GetDC(nullptr);

        if (!screen)
            return false;

        w = GetSystemMetrics(SM_CXSCREEN);
        h = GetSystemMetrics(SM_CYSCREEN);

        memDC = CreateCompatibleDC(screen);

        if (!memDC)
            return false;

        BITMAPINFO bi{};

        bi.bmiHeader.biSize =
            sizeof(BITMAPINFOHEADER);

        bi.bmiHeader.biWidth = w;

        /* Top-down DIB. */
        bi.bmiHeader.biHeight = -h;

        bi.bmiHeader.biPlanes = 1;
        bi.bmiHeader.biBitCount = 32;
        bi.bmiHeader.biCompression = BI_RGB;

        bitmap = CreateDIBSection(
            screen,
            &bi,
            DIB_RGB_COLORS,
            reinterpret_cast<void**>(&pixels),
            nullptr,
            0
        );

        if (!bitmap || !pixels)
            return false;

        oldBitmap =
            SelectObject(
                memDC,
                bitmap
            );

        return true;
    }

    /** Copies the current screen contents into the DIB. */
    void Capture()
    {
        BitBlt(
            memDC,
            0,
            0,
            w,
            h,
            screen,
            0,
            0,
            SRCCOPY
        );
    }

    /** Presents the DIB contents back to the screen. */
    void Present()
    {
        BitBlt(
            screen,
            0,
            0,
            w,
            h,
            memDC,
            0,
            0,
            SRCCOPY
        );
    }

    /** Releases all GDI resources held by this surface. */
    void Destroy()
    {
        if (memDC && oldBitmap)
            SelectObject(
                memDC,
                oldBitmap
            );

        if (bitmap)
            DeleteObject(bitmap);

        if (memDC)
            DeleteDC(memDC);

        if (screen)
            ReleaseDC(
                nullptr,
                screen
            );

        bitmap = nullptr;
        memDC = nullptr;
        screen = nullptr;
        pixels = nullptr;
    }

    /** Releases the surface. */
    ~PhoenixHppdSurface()
    {
        Destroy();
    }
};

/**
 * Clamps an integer channel value into [0, 255].
 * @param v Value to clamp.
 * @return Clamped 8-bit value.
 */
static inline uint8_t PhoenixHppdClamp8(int v)
{
    if (v < 0)
        return 0;

    if (v > 255)
        return 255;

    return static_cast<uint8_t>(v);
}

/**
 * Packs RGB channels into a BGRx pixel (matching the DIB layout).
 * @param r Red channel.
 * @param g Green channel.
 * @param b Blue channel.
 * @return Packed pixel.
 */
static inline uint32_t PhoenixHppdPackRGB(
    int r,
    int g,
    int b
)
{
    return
        static_cast<uint32_t>(
            PhoenixHppdClamp8(b)
            ) << 16 |
        static_cast<uint32_t>(
            PhoenixHppdClamp8(g)
            ) << 8 |
        static_cast<uint32_t>(
            PhoenixHppdClamp8(r)
            );
}

/**
 * Shifts a packed BGR pixel through HSL space.
 * @param px Packed pixel.
 * @param dHue Hue delta.
 * @param dSat Saturation delta.
 * @param dLight Lightness delta.
 * @return Shifted packed pixel.
 */
static inline uint32_t PhoenixHppdShiftHSL(
    uint32_t px,
    FLOAT dHue,
    FLOAT dSat,
    FLOAT dLight
)
{
    RGBQUAD rgb{};

    rgb.rgbRed =
        px & 255;

    rgb.rgbGreen =
        (px >> 8) & 255;

    rgb.rgbBlue =
        (px >> 16) & 255;

    PhoenixHppdHSL hsl =
        PhoenixHppdColors::rgb2hsl(rgb);

    hsl.h += dHue;
    hsl.s += dSat;
    hsl.l += dLight;

    if (hsl.h < 0.f)
        hsl.h += 1.f;

    if (hsl.h >= 1.f)
        hsl.h -= 1.f;

    if (hsl.s < 0.f)
        hsl.s = 0.f;

    if (hsl.s > 1.f)
        hsl.s = 1.f;

    if (hsl.l < 0.f)
        hsl.l = 0.f;

    if (hsl.l > 1.f)
        hsl.l = 1.f;

    RGBQUAD out =
        PhoenixHppdColors::hsl2rgb(hsl);

    return PhoenixHppdPackRGB(
        out.rgbRed,
        out.rgbGreen,
        out.rgbBlue
    );
}

/* ------------------------------------------------------------------------- */
/*                        SHARED GDI BUFFER (DIB)                            */
/* ------------------------------------------------------------------------- */

/**
 * Shared DIB buffer helpers for the per-pixel FX packs (50-63, 69-72 and
 * Death Month). Ported from HPPD gdi/gdibuffer.h. The helpers live in an
 * anonymous namespace so every translation unit sees the same inline
 * definitions without ODR collisions, exactly like upstream.
 */
namespace
{
    /**
     * Clamps an integer into [a, b].
     * @param x Value to clamp.
     * @param a Lower bound.
     * @param b Upper bound.
     * @return Clamped value.
     */
    inline int ClampI(int x, int a, int b)
    {
        return std::max(a, std::min(b, x));
    }

    /**
     * Packs RGB channels into a BGRx pixel.
     * @param r Red channel.
     * @param g Green channel.
     * @param b Blue channel.
     * @return Packed pixel.
     */
    inline uint32_t RGBPixel(int r, int g, int b)
    {
        return
            ((uint32_t)ClampI(b, 0, 255) << 16) |
            ((uint32_t)ClampI(g, 0, 255) << 8) |
            (uint32_t)ClampI(r, 0, 255);
    }

    /**
     * Splits a packed BGRx pixel into channels.
     * @param p Packed pixel.
     * @param r Red channel (out).
     * @param g Green channel (out).
     * @param b Blue channel (out).
     */
    inline void SplitRGB(
        uint32_t p,
        int& r,
        int& g,
        int& b
    )
    {
        r = p & 255;
        g = (p >> 8) & 255;
        b = (p >> 16) & 255;
    }

    /**
     * Screen-sized 32-bit top-down DIB buffer.
     */
    struct GDIBuffer
    {
        HDC dc = nullptr;        /**< Memory DC. */
        HBITMAP bmp = nullptr;   /**< DIB section bitmap. */
        HGDIOBJ old = nullptr;   /**< Previously selected bitmap. */
        uint32_t* pixels = nullptr; /**< Pixel pointer (BGRx, top-down). */
        int w = 0;               /**< Width in pixels. */
        int h = 0;               /**< Height in pixels. */
    };

    /**
     * Creates a screen-sized DIB buffer on the given source DC.
     * @param source Source DC for CreateDIBSection.
     * @param out Buffer to fill.
     * @param w Width in pixels.
     * @param h Height in pixels.
     * @return true on success, false if any GDI call failed.
     */
    inline bool CreateBuffer(
        HDC source,
        GDIBuffer& out,
        int w,
        int h
    )
    {
        out.w = w;
        out.h = h;

        out.dc = CreateCompatibleDC(source);

        if (!out.dc)
            return false;

        BITMAPINFO bi{};
        bi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
        bi.bmiHeader.biWidth = w;
        bi.bmiHeader.biHeight = -h;
        bi.bmiHeader.biPlanes = 1;
        bi.bmiHeader.biBitCount = 32;
        bi.bmiHeader.biCompression = BI_RGB;

        out.bmp =
            CreateDIBSection(
                source,
                &bi,
                DIB_RGB_COLORS,
                reinterpret_cast<void**>(&out.pixels),
                nullptr,
                0
            );

        if (!out.bmp || !out.pixels)
        {
            if (out.bmp)
                DeleteObject(out.bmp);

            DeleteDC(out.dc);

            out.dc = nullptr;
            out.bmp = nullptr;
            out.pixels = nullptr;

            return false;
        }

        out.old = SelectObject(out.dc, out.bmp);

        return true;
    }

    /**
     * Releases a buffer created by CreateBuffer.
     * @param b Buffer to destroy.
     */
    inline void DestroyBuffer(GDIBuffer& b)
    {
        if (b.dc)
        {
            SelectObject(b.dc, b.old);
            DeleteDC(b.dc);
        }

        if (b.bmp)
            DeleteObject(b.bmp);

        b = {};
    }
}

/* ------------------------------------------------------------------------- */
/*                              FX RAM CACHE                                 */
/* ------------------------------------------------------------------------- */

/**
 * RAM-resident caches that stop per-pixel recomputation of sqrtf / atan2f /
 * sinf / cosf. Ported verbatim from HPPD gdi/fxcache.h (plain math, no
 * WinAPI, so the values are bit-identical to recomputing them inline).
 */
namespace FxCache
{
    /**
     * Which per-pixel maps a PolarMap should materialise.
     */
    enum PolarParts : unsigned
    {
        PolarRadius = 1u << 0,  /**< sqrtf(dx*dx + dy*dy). */
        PolarAngle  = 1u << 1,  /**< atan2f(dy, dx). */
        PolarUnit   = 1u << 2,  /**< cosf(angle), sinf(angle). */
        PolarAll    = PolarRadius | PolarAngle | PolarUnit /**< All parts. */
    };

    /**
     * Per-pixel polar coordinates around a centre, indexed [y * w + x].
     */
    struct PolarMap
    {
        int w = 0;                    /**< Width in pixels. */
        int h = 0;                    /**< Height in pixels. */
        std::vector<float> radius;    /**< PolarRadius part. */
        std::vector<float> angle;     /**< PolarAngle part. */
        std::vector<float> cosA;      /**< PolarUnit: cosf(angle). */
        std::vector<float> sinA;      /**< PolarUnit: sinf(angle). */

        /**
         * Builds the requested maps for the given centre.
         * @param w_ Width in pixels.
         * @param h_ Height in pixels.
         * @param cx Centre x.
         * @param cy Centre y.
         * @param parts Which maps to build (default: all).
         * @return true on success, false for a degenerate size.
         */
        bool Build(
            int w_,
            int h_,
            float cx,
            float cy,
            unsigned parts = PolarAll
        )
        {
            w = w_;
            h = h_;

            if (w <= 0 || h <= 0)
                return false;

            const size_t count =
                static_cast<size_t>(w) * static_cast<size_t>(h);

            if (parts & PolarRadius)
                radius.resize(count);

            if (parts & PolarAngle)
                angle.resize(count);

            if (parts & PolarUnit)
            {
                cosA.resize(count);
                sinA.resize(count);
            }

            const bool wantR = (parts & PolarRadius) != 0;
            const bool wantA = (parts & PolarAngle) != 0;
            const bool wantU = (parts & PolarUnit) != 0;

            for (int y = 0; y < h; ++y)
            {
                const float dy = static_cast<float>(y) - cy;
                const size_t row = static_cast<size_t>(y) * w;

                for (int x = 0; x < w; ++x)
                {
                    const float dx = static_cast<float>(x) - cx;
                    const size_t i = row + static_cast<size_t>(x);

                    if (wantR)
                        radius[i] = sqrtf(dx * dx + dy * dy);

                    if (wantA || wantU)
                    {
                        const float a = atan2f(dy, dx);

                        if (wantA)
                            angle[i] = a;

                        if (wantU)
                        {
                            cosA[i] = cosf(a);
                            sinA[i] = sinf(a);
                        }
                    }
                }
            }

            return true;
        }

        /**
         * Total bytes held in RAM by this map.
         * @return Byte count.
         */
        size_t Bytes() const
        {
            return (
                radius.size() +
                angle.size() +
                cosA.size() +
                sinA.size()
            ) * sizeof(float);
        }
    };

    /**
     * Ordered-dither (Bayer 4x4) quantizer cache for payload 71:
     * level[thresholdIndex][channelValue] holds the exact 2-bit/channel
     * result (0, 85, 170 or 255).
     */
    struct Bayer4Lut
    {
        uint8_t level[16][256]; /**< Quantizer results. */
    };

    /**
     * Builds the Bayer 4x4 quantizer lookup table.
     * @return Populated lookup table.
     */
    static inline Bayer4Lut BuildBayer4Lut()
    {
        Bayer4Lut lut{};

        for (int thIndex = 0; thIndex < 16; ++thIndex)
        {
            const int th = thIndex * 4;

            for (int v = 0; v < 256; ++v)
            {
                int c = v >> 6;

                if (c > 3)
                    c = 3;

                if ((v & 63) > th)
                    ++c;

                if (c > 3)
                    c = 3;

                lut.level[thIndex][v] =
                    static_cast<uint8_t>(c * 85);
            }
        }

        return lut;
    }
}

/* ------------------------------------------------------------------------- */
/*                            FX TIMING HELPERS                              */
/* ------------------------------------------------------------------------- */

/**
 * Global "stop payload" latch. Set by phoenixHppdStopAll(), by pause and
 * by shutdown; cleared when a new payload is triggered. HPPD used a
 * volatile bool (gFxStop); Phoenix uses an atomic so worker threads
 * observe the stop promptly.
 */
extern std::atomic<bool> gPhoenixHppdStop;

/**
 * Whether the current payload should abort (ESC pressed or stop latched).
 * @return true if the payload should stop.
 */
static inline bool FXAbort()
{
    return (
        GetAsyncKeyState(VK_ESCAPE)
        & 0x8000
        ) != 0 ||
        gPhoenixHppdStop.load();
}

/**
 * Sleeps until the next 16 ms frame boundary (60 fps pacing).
 * @param nextFrame Next frame deadline (in/out, GetTickCount64 domain).
 */
static inline void FPS16(
    ULONGLONG& nextFrame
)
{
    nextFrame += 16;

    ULONGLONG now =
        GetTickCount64();

    if (now < nextFrame)
    {
        Sleep(
            static_cast<DWORD>(
                nextFrame - now
                )
        );
    }
    else
    {
        nextFrame = now;
    }
}

/**
 * Whether a payload has timed out or should abort.
 * @param start Payload start time (GetTickCount64 domain).
 * @param duration Payload duration in milliseconds.
 * @return true if the payload should stop.
 */
static inline bool FXTimeout(
    ULONGLONG start,
    DWORD duration
)
{
    return
        FXAbort() ||
        (
            GetTickCount64() -
            start >= duration
            );
}

/**
 * Extremely cheap xorshift RNG.
 * @param state RNG state (in/out, must be nonzero).
 * @return Next random value.
 */
static inline uint32_t FXRand(
    uint32_t& state
)
{
    state ^= state << 13;
    state ^= state >> 17;
    state ^= state << 5;

    return state;
}

/* ------------------------------------------------------------------------- */
/*                          PAYLOAD DECLARATIONS                             */
/* ------------------------------------------------------------------------- */

/* Heavy payloads: full-screen per-pixel renderers, one at a time. */
DWORD WINAPI GDIPayload1(LPVOID);
DWORD WINAPI GDIPayload2(LPVOID);
DWORD WINAPI GDIPayload5(LPVOID);
DWORD WINAPI GDIPayload6(LPVOID);
DWORD WINAPI GDIPayload7(LPVOID);
DWORD WINAPI GDIPayload8(LPVOID);
DWORD WINAPI GDIPayload9(LPVOID);
DWORD WINAPI GDIPayload10(LPVOID);
DWORD WINAPI GDIPayload11(LPVOID);
DWORD WINAPI GDIPayload13(LPVOID);
DWORD WINAPI GDIPayload14(LPVOID);
DWORD WINAPI GDIPayload15(LPVOID);
DWORD WINAPI GDIPayload17(LPVOID);
DWORD WINAPI GDIPayload19(LPVOID);
DWORD WINAPI GDIPayload20(LPVOID);
DWORD WINAPI GDIPayload21(LPVOID);
DWORD WINAPI GDIPayload22(LPVOID);
DWORD WINAPI GDIPayload23(LPVOID);
DWORD WINAPI GDIPayload24(LPVOID);
DWORD WINAPI GDIPayload40(LPVOID);
DWORD WINAPI GDIPayload48(LPVOID);
DWORD WINAPI GDIPayload50(LPVOID);
DWORD WINAPI GDIPayload51(LPVOID);
DWORD WINAPI GDIPayload52(LPVOID);
DWORD WINAPI GDIPayload53(LPVOID);
DWORD WINAPI GDIPayload54(LPVOID);
DWORD WINAPI GDIPayload55(LPVOID);
DWORD WINAPI GDIPayload56(LPVOID);
DWORD WINAPI GDIPayload57(LPVOID);
DWORD WINAPI GDIPayload58(LPVOID);
DWORD WINAPI GDIPayload59(LPVOID);
DWORD WINAPI GDIPayload60(LPVOID);
DWORD WINAPI GDIPayload61(LPVOID);
DWORD WINAPI GDIPayload62(LPVOID);
DWORD WINAPI GDIPayload63(LPVOID);

/* Light payloads: overlays / modifiers that overlap freely. */
DWORD WINAPI GDIPayload3(LPVOID);
DWORD WINAPI GDIPayload4(LPVOID);
DWORD WINAPI GDIPayload12(LPVOID);
DWORD WINAPI GDIPayload16(LPVOID);
DWORD WINAPI GDIPayload18(LPVOID);
DWORD WINAPI GDIPayload25(LPVOID);
DWORD WINAPI GDIPayload26(LPVOID);
DWORD WINAPI GDIPayload28(LPVOID);
DWORD WINAPI GDIPayload29(LPVOID);
DWORD WINAPI GDIPayload30(LPVOID);
DWORD WINAPI GDIPayload31(LPVOID);
DWORD WINAPI GDIPayload32(LPVOID);
DWORD WINAPI GDIPayload33(LPVOID);
DWORD WINAPI GDIPayload34(LPVOID);
DWORD WINAPI GDIPayload35(LPVOID);
DWORD WINAPI GDIPayload36(LPVOID);
DWORD WINAPI GDIPayload37(LPVOID);
DWORD WINAPI GDIPayload38(LPVOID);
DWORD WINAPI GDIPayload39(LPVOID);
DWORD WINAPI GDIPayload41(LPVOID);
DWORD WINAPI GDIPayload42(LPVOID);
DWORD WINAPI GDIPayload43(LPVOID);
DWORD WINAPI GDIPayload44(LPVOID);
DWORD WINAPI GDIPayload45(LPVOID);
DWORD WINAPI GDIPayload46(LPVOID);
DWORD WINAPI GDIPayload47(LPVOID);
DWORD WINAPI GDIPayload49(LPVOID);
DWORD WINAPI GDIPayload69(LPVOID);
DWORD WINAPI GDIPayload70(LPVOID);
DWORD WINAPI GDIPayload71(LPVOID);
DWORD WINAPI GDIPayload72(LPVOID);

/* Death Month (December): one shared renderer, 31 day variants. */
DWORD WINAPI GDIPDeath01(LPVOID);
DWORD WINAPI GDIPDeath02(LPVOID);
DWORD WINAPI GDIPDeath03(LPVOID);
DWORD WINAPI GDIPDeath04(LPVOID);
DWORD WINAPI GDIPDeath05(LPVOID);
DWORD WINAPI GDIPDeath06(LPVOID);
DWORD WINAPI GDIPDeath07(LPVOID);
DWORD WINAPI GDIPDeath08(LPVOID);
DWORD WINAPI GDIPDeath09(LPVOID);
DWORD WINAPI GDIPDeath10(LPVOID);
DWORD WINAPI GDIPDeath11(LPVOID);
DWORD WINAPI GDIPDeath12(LPVOID);
DWORD WINAPI GDIPDeath13(LPVOID);
DWORD WINAPI GDIPDeath14(LPVOID);
DWORD WINAPI GDIPDeath15(LPVOID);
DWORD WINAPI GDIPDeath16(LPVOID);
DWORD WINAPI GDIPDeath17(LPVOID);
DWORD WINAPI GDIPDeath18(LPVOID);
DWORD WINAPI GDIPDeath19(LPVOID);
DWORD WINAPI GDIPDeath20(LPVOID);
DWORD WINAPI GDIPDeath21(LPVOID);
DWORD WINAPI GDIPDeath22(LPVOID);
DWORD WINAPI GDIPDeath23(LPVOID);
DWORD WINAPI GDIPDeath24(LPVOID);
DWORD WINAPI GDIPDeath25(LPVOID);
DWORD WINAPI GDIPDeath26(LPVOID);
DWORD WINAPI GDIPDeath27(LPVOID);
DWORD WINAPI GDIPDeath28(LPVOID);
DWORD WINAPI GDIPDeath29(LPVOID);
DWORD WINAPI GDIPDeath30(LPVOID);
DWORD WINAPI GDIPDeath31(LPVOID);

/**
 * Death Month table entry: December day (1..31) -> its payload.
 */
struct PhoenixHppdDeathEntry
{
    int day;                    /**< December day (1..31). */
    const wchar_t* name;        /**< Overlay label. */
    DWORD ms;                   /**< Overlay duration. */
    LPTHREAD_START_ROUTINE fn;  /**< Payload to run. */
};

/**
 * Death Month table (December day -> payload). Defined in
 * phoenix_gdi_hppd_death.cpp.
 */
extern const PhoenixHppdDeathEntry gPhoenixHppdDeathMonth[];

/**
 * Number of Death Month entries.
 */
extern const int gPhoenixHppdDeathMonthCount;

/**
 * Returns the active Death Month entry (December 00:00-00:59) or nullptr.
 * @return Active entry, or nullptr outside the window.
 */
const PhoenixHppdDeathEntry* PhoenixHppdDeathMonthToday();

/**
 * Short banner shown while Death Month is active.
 * @return "DEATH MONTH" when active, nullptr otherwise.
 */
const char* PhoenixHppdDeathMonthName();

/* ------------------------------------------------------------------------- */
/*                           PHOENIX HPPD API                                */
/* ------------------------------------------------------------------------- */

/**
 * Picks the global seed for this process. Called once by
 * phoenixGdiInitialize() before any payload runs; later calls are no-ops
 * for the seed table (the table is built lazily on first use).
 */
void phoenixHppdInitializeSeed();

/**
 * Triggers an HPPD payload on its own worker thread (non-blocking).
 * Heavy payloads serialize through the heavy mutex; light payloads run
 * concurrently. Triggering an already-running payload is a no-op.
 * @param payloadId HPPD payload number (1..63, 69..72, or 101..131 for
 *                  Death Month day 1..31).
 * @return true if a worker was started, false if the ID is unknown or
 *         already running.
 */
bool phoenixHppdTrigger(int payloadId);

/**
 * Latches the global stop flag so every running HPPD payload aborts at
 * its next FXAbort()/FXTimeout() check. Non-blocking.
 */
void phoenixHppdStopAll();

/**
 * Whether an HPPD payload worker is currently running.
 * @param payloadId HPPD payload number.
 * @return true if running, false otherwise (including unknown IDs).
 */
bool phoenixHppdIsRunning(int payloadId);

/**
 * Whether a payload ID is a heavy (serialized) payload.
 * @param payloadId HPPD payload number.
 * @return true for heavy payloads, false for light or unknown IDs.
 */
bool phoenixHppdIsHeavy(int payloadId);

/**
 * Number of ported HPPD payloads (light + heavy + Death Month).
 * @return Payload count.
 */
int phoenixHppdCount();

/**
 * Joins all HPPD worker threads. Called by phoenixGdiShutdown().
 */
void phoenixHppdShutdown();

#endif /* _WIN32 */
#endif /* PHOENIX_GDI_HPPD_H */
