#include "phoenix_gdi.h"

#if defined(_WIN32)

/* ------------------------------------------------------------------------- */
/*                          GDI EFFECT IMPLEMENTATIONS                       */
/* ------------------------------------------------------------------------- */
/* Ported from Slushi Engine's SlushiWinGDI.hx @:cppFileCode block.
 * Original comment: "some of the GDI effect code is taken from the MENZ
 * malware source code" - these are visual effects only, not malicious. */

static float g_elapsedTime = 0.0f;

static int payloadDrawErrors()
{
    int ix = GetSystemMetrics(SM_CXICON) / 2;
    int iy = GetSystemMetrics(SM_CYICON) / 2;

    HWND hwnd = GetDesktopWindow();
    HDC hdc = GetWindowDC(hwnd);

    POINT cursor;
    GetCursorPos(&cursor);

    DrawIcon(hdc, cursor.x - ix, cursor.y - iy, LoadIcon(NULL, IDI_ERROR));

    if (rand() % (int)(10.0f / (g_elapsedTime / 500.0f + 1.0f) + 1) == 0)
    {
        DrawIcon(hdc,
                 rand() % GetSystemMetrics(SM_CXSCREEN),
                 rand() % GetSystemMetrics(SM_CYSCREEN),
                 LoadIcon(NULL, IDI_WARNING));
    }

    ReleaseDC(hwnd, hdc);
    return 2;
}

static int payloadBlink()
{
    HWND hwnd = GetDesktopWindow();
    HDC hdc = GetWindowDC(hwnd);
    RECT rekt;
    GetWindowRect(hwnd, &rekt);
    BitBlt(hdc, 0, 0, rekt.right - rekt.left, rekt.bottom - rekt.top, hdc, 0, 0, NOTSRCCOPY);
    ReleaseDC(hwnd, hdc);
    return 100;
}

static int payloadGlitchs()
{
    HWND hwnd = GetDesktopWindow();
    HDC hdc = GetWindowDC(hwnd);
    RECT rekt;
    GetWindowRect(hwnd, &rekt);

    int x1 = rand() % (rekt.right - 100);
    int y1 = rand() % (rekt.bottom - 100);
    int x2 = rand() % (rekt.right - 100);
    int y2 = rand() % (rekt.bottom - 100);
    int width = rand() % 600;
    int height = rand() % 600;

    BitBlt(hdc, x1, y1, width, height, hdc, x2, y2, SRCCOPY);
    ReleaseDC(hwnd, hdc);

    return static_cast<int>(200.0f / (g_elapsedTime / 5.0f + 1.0f) + 3);
}

static int payloadTunnel()
{
    HWND hwnd = GetDesktopWindow();
    HDC hdc = GetWindowDC(hwnd);
    RECT rekt;
    GetWindowRect(hwnd, &rekt);
    StretchBlt(hdc, 50, 50, rekt.right - 100, rekt.bottom - 100, hdc, 0, 0, rekt.right, rekt.bottom, SRCCOPY);
    ReleaseDC(hwnd, hdc);

    return static_cast<int>(200.0f / (g_elapsedTime / 5.0f + 1.0f) + 4);
}

static int payloadScreenShake()
{
    HDC hdc = GetDC(0);
    int w = GetSystemMetrics(0);
    int h = GetSystemMetrics(1);
    BitBlt(hdc, rand() % 2, rand() % 2, w, h, hdc, rand() % 2, rand() % 2, SRCCOPY);
    Sleep(10);
    ReleaseDC(0, hdc);
    return 0;
}

/* Callback for EnumChildWindows - sets window title text. */
static BOOL CALLBACK EnumChildProc(HWND hwnd, LPARAM lParam)
{
    LPCWSTR newText = reinterpret_cast<LPCWSTR>(lParam);
    SendMessageTimeoutW(hwnd, WM_SETTEXT, NULL, reinterpret_cast<LPARAM>(newText), SMTO_ABORTIFHUNG, 0, NULL);
    return TRUE;
}

/* ------------------------------------------------------------------------- */
/*                      BACKGROUND THREAD MANAGEMENT                         */
/* ------------------------------------------------------------------------- */

struct GdiEffectData
{
    std::string name;
    bool enabled = false;
    float waitMs = 0.0f;
    /* Effect type determines which payload to run. */
    enum Type
    {
        None,
        DrawIcons,
        ScreenBlink,
        ScreenGlitches,
        ScreenTunnel,
        ScreenShake,
        SetTitleText
    } type = None;
    std::string titleText; // for SetTitleText effect
};

static std::map<std::string, GdiEffectData> g_effects;
static std::mutex g_effectsMutex;
static std::thread g_gdiThread;
static std::atomic<bool> g_running{false};
static std::atomic<bool> g_paused{false};
static std::atomic<float> g_sharedElapsedTime{0.0f};

/** Map effect name string to internal enum. */
static GdiEffectData::Type effectNameToType(const std::string &name)
{
    if (name == "DrawIcons") return GdiEffectData::DrawIcons;
    if (name == "ScreenBlink") return GdiEffectData::ScreenBlink;
    if (name == "ScreenGlitches") return GdiEffectData::ScreenGlitches;
    if (name == "ScreenTunnel") return GdiEffectData::ScreenTunnel;
    if (name == "ScreenShake") return GdiEffectData::ScreenShake;
    if (name == "SetTitleText") return GdiEffectData::SetTitleText;
    return GdiEffectData::None;
}

/** Main GDI thread loop. */
static void gdiThreadMain()
{
    while (g_running.load())
    {
        if (g_paused.load())
        {
            std::this_thread::sleep_for(std::chrono::milliseconds(16));
            continue;
        }

        float elapsed = g_sharedElapsedTime.load();
        g_elapsedTime = elapsed;

        std::vector<GdiEffectData*> toRun;
        {
            std::lock_guard<std::mutex> lock(g_effectsMutex);
            for (auto &kv : g_effects)
            {
                if (kv.second.enabled)
                    toRun.push_back(&kv.second);
            }
        }

        for (GdiEffectData *effect : toRun)
        {
            if (effect->waitMs > 0.0f)
            {
                std::this_thread::sleep_for(std::chrono::milliseconds(static_cast<int>(effect->waitMs)));
            }

            switch (effect->type)
            {
                case GdiEffectData::DrawIcons:
                    payloadDrawErrors();
                    break;
                case GdiEffectData::ScreenBlink:
                    payloadBlink();
                    break;
                case GdiEffectData::ScreenGlitches:
                    payloadGlitchs();
                    break;
                case GdiEffectData::ScreenTunnel:
                    payloadTunnel();
                    break;
                case GdiEffectData::ScreenShake:
                    payloadScreenShake();
                    break;
                case GdiEffectData::SetTitleText:
                    {
                        /* Convert UTF-8 to wide string for EnumChildWindows. */
                        int wideLen = MultiByteToWideChar(CP_UTF8, 0, effect->titleText.c_str(), -1, NULL, 0);
                        if (wideLen > 0)
                        {
                            std::vector<wchar_t> wide(wideLen);
                            MultiByteToWideChar(CP_UTF8, 0, effect->titleText.c_str(), -1, wide.data(), wideLen);
                            EnumChildWindows(GetDesktopWindow(), EnumChildProc, reinterpret_cast<LPARAM>(wide.data()));
                        }
                    }
                    break;
                default:
                    break;
            }
        }

        /* Small sleep to avoid 100% CPU when no effects or very short waits. */
        if (toRun.empty())
            std::this_thread::sleep_for(std::chrono::milliseconds(16));
    }
}

/* ------------------------------------------------------------------------- */
/*                              PUBLIC API                                   */
/* ------------------------------------------------------------------------- */

bool phoenixGdiInitialize()
{
    if (g_running.load())
        return true;

    g_running.store(true);
    g_paused.store(false);
    g_sharedElapsedTime.store(0.0f);

    try
    {
        g_gdiThread = std::thread(gdiThreadMain);
        return true;
    }
    catch (...)
    {
        g_running.store(false);
        return false;
    }
}

void phoenixGdiShutdown()
{
    if (!g_running.load())
        return;

    g_running.store(false);
    if (g_gdiThread.joinable())
        g_gdiThread.join();

    std::lock_guard<std::mutex> lock(g_effectsMutex);
    g_effects.clear();
}

void phoenixGdiSetElapsedTime(float elapsed)
{
    g_sharedElapsedTime.store(elapsed);
}

void phoenixGdiSetPaused(bool paused)
{
    g_paused.store(paused);
}

bool phoenixGdiRegisterEffect(const char *name)
{
    if (!name)
        return false;

    std::string nameStr(name);
    GdiEffectData::Type type = effectNameToType(nameStr);
    if (type == GdiEffectData::None)
        return false;

    std::lock_guard<std::mutex> lock(g_effectsMutex);
    if (g_effects.find(nameStr) != g_effects.end())
        return true; // already registered

    GdiEffectData data;
    data.name = nameStr;
    data.type = type;
    data.enabled = false;
    data.waitMs = 0.0f;
    g_effects.emplace(std::move(nameStr), std::move(data));
    return true;
}

void phoenixGdiUnregisterEffect(const char *name)
{
    if (!name)
        return;

    std::lock_guard<std::mutex> lock(g_effectsMutex);
    g_effects.erase(name);
}

void phoenixGdiSetEffectEnabled(const char *name, bool enabled)
{
    if (!name)
        return;

    std::lock_guard<std::mutex> lock(g_effectsMutex);
    auto it = g_effects.find(name);
    if (it != g_effects.end())
        it->second.enabled = enabled;
}

void phoenixGdiSetEffectWait(const char *name, float waitMs)
{
    if (!name)
        return;

    std::lock_guard<std::mutex> lock(g_effectsMutex);
    auto it = g_effects.find(name);
    if (it != g_effects.end())
        it->second.waitMs = waitMs;
}

/* ---- One-shot payload triggers ---- */

void phoenixGdiDrawIcons()
{
    payloadDrawErrors();
}

void phoenixGdiScreenBlink()
{
    payloadBlink();
}

void phoenixGdiScreenGlitches()
{
    payloadGlitchs();
}

void phoenixGdiScreenTunnel()
{
    payloadTunnel();
}

void phoenixGdiScreenShake()
{
    payloadScreenShake();
}

void phoenixGdiSetCustomTitleText(const char *text)
{
    if (!text)
        return;

    int wideLen = MultiByteToWideChar(CP_UTF8, 0, text, -1, NULL, 0);
    if (wideLen > 0)
    {
        std::vector<wchar_t> wide(wideLen);
        MultiByteToWideChar(CP_UTF8, 0, text, -1, wide.data(), wideLen);
        EnumChildWindows(GetDesktopWindow(), EnumChildProc, reinterpret_cast<LPARAM>(wide.data()));
    }
}

#endif /* _WIN32 */