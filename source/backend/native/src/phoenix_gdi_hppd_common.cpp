#include "phoenix_gdi_hppd.h"

#if defined(_WIN32)

#include <thread>
#include <mutex>
#include <ctime>

/* ------------------------------------------------------------------------- */
/*                              SEED STORAGE                                 */
/* ------------------------------------------------------------------------- */

/**
 * Global runtime seed. Picked once by phoenixHppdInitializeSeed().
 */
uint32_t gPhoenixHppdSeed = 0;

/**
 * Global stop latch (HPPD's gFxStop, made atomic for worker threads).
 */
std::atomic<bool> gPhoenixHppdStop{false};

/**
 * Cheap integer avalanche mix (xorshift-style). Ported from HPPD
 * utils/seed.cpp Mix32.
 * @param v Input value.
 * @return Mixed value.
 */
static uint32_t PhoenixHppdMix32(uint32_t v)
{
    v ^= v << 13;
    v ^= v >> 17;
    v ^= v << 5;

    v *= 0x85EBCA6Bu;

    v ^= v >> 16;

    return v;
}

namespace
{
    /**
     * Precomputed per-payload seed variants. Sized to cover the highest
     * ported ID (131 for Death Month day 31); HPPD used 128 entries for
     * IDs 0..127.
     */
    struct PhoenixHppdSeedTable
    {
        PhoenixHppdSeedVariant variants[132];

        /**
         * Builds every variant from the current global seed.
         */
        PhoenixHppdSeedTable()
        {
            for (int p = 0; p < 132; ++p)
            {
                uint32_t h =
                    PhoenixHppdMix32(
                        gPhoenixHppdSeed ^
                        static_cast<uint32_t>(p) *
                        0x9E3779B9u
                    );

                variants[p].phase =
                    static_cast<int>(h & 2047);

                variants[p].dir =
                    (h & (1u << 20))
                        ? 1
                        : -1;

                variants[p].amp =
                    1 +
                    static_cast<int>(
                        (h >> 11) & 7
                    );

                variants[p].rng =
                    h | 1u;
            }
        }
    };

    /**
     * Returns the process-wide seed table (built exactly once).
     * @return Reference to the table.
     */
    const PhoenixHppdSeedTable& PhoenixHppdGetSeedTable()
    {
        /* Magic static: C++11 guarantees the constructor runs exactly
         * once, even when payload threads call PhoenixHppdSeedGet()
         * concurrently. */
        static const PhoenixHppdSeedTable table;
        return table;
    }
}

/**
 * Returns the cached seed variant for a payload ID.
 * @param payloadId HPPD payload number.
 * @return Reference to the cached variant.
 */
const PhoenixHppdSeedVariant& PhoenixHppdSeedGet(int payloadId)
{
    if (payloadId < 0 || payloadId >= 132)
        return PhoenixHppdGetSeedTable().variants[0];

    return PhoenixHppdGetSeedTable().variants[payloadId];
}

/* ------------------------------------------------------------------------- */
/*                         PAYLOAD LOOKUP / SLOTS                            */
/* ------------------------------------------------------------------------- */

/**
 * Maps a payload ID to its thread function, or nullptr for unknown,
 * missing (27) or deliberately excluded (64-68, 73, 74) IDs.
 * @param payloadId HPPD payload number.
 * @return Thread function, or nullptr.
 */
static LPTHREAD_START_ROUTINE PhoenixHppdLookup(int payloadId)
{
    switch (payloadId)
    {
        case 1: return GDIPayload1;
        case 2: return GDIPayload2;
        case 3: return GDIPayload3;
        case 4: return GDIPayload4;
        case 5: return GDIPayload5;
        case 6: return GDIPayload6;
        case 7: return GDIPayload7;
        case 8: return GDIPayload8;
        case 9: return GDIPayload9;
        case 10: return GDIPayload10;
        case 11: return GDIPayload11;
        case 12: return GDIPayload12;
        case 13: return GDIPayload13;
        case 14: return GDIPayload14;
        case 15: return GDIPayload15;
        case 16: return GDIPayload16;
        case 17: return GDIPayload17;
        case 18: return GDIPayload18;
        case 19: return GDIPayload19;
        case 20: return GDIPayload20;
        case 21: return GDIPayload21;
        case 22: return GDIPayload22;
        case 23: return GDIPayload23;
        case 24: return GDIPayload24;
        case 25: return GDIPayload25;
        case 26: return GDIPayload26;
        case 28: return GDIPayload28;
        case 29: return GDIPayload29;
        case 30: return GDIPayload30;
        case 31: return GDIPayload31;
        case 32: return GDIPayload32;
        case 33: return GDIPayload33;
        case 34: return GDIPayload34;
        case 35: return GDIPayload35;
        case 36: return GDIPayload36;
        case 37: return GDIPayload37;
        case 38: return GDIPayload38;
        case 39: return GDIPayload39;
        case 40: return GDIPayload40;
        case 41: return GDIPayload41;
        case 42: return GDIPayload42;
        case 43: return GDIPayload43;
        case 44: return GDIPayload44;
        case 45: return GDIPayload45;
        case 46: return GDIPayload46;
        case 47: return GDIPayload47;
        case 48: return GDIPayload48;
        case 49: return GDIPayload49;
        case 50: return GDIPayload50;
        case 51: return GDIPayload51;
        case 52: return GDIPayload52;
        case 53: return GDIPayload53;
        case 54: return GDIPayload54;
        case 55: return GDIPayload55;
        case 56: return GDIPayload56;
        case 57: return GDIPayload57;
        case 58: return GDIPayload58;
        case 59: return GDIPayload59;
        case 60: return GDIPayload60;
        case 61: return GDIPayload61;
        case 62: return GDIPayload62;
        case 63: return GDIPayload63;
        case 69: return GDIPayload69;
        case 70: return GDIPayload70;
        case 71: return GDIPayload71;
        case 72: return GDIPayload72;
        case 101: return GDIPDeath01;
        case 102: return GDIPDeath02;
        case 103: return GDIPDeath03;
        case 104: return GDIPDeath04;
        case 105: return GDIPDeath05;
        case 106: return GDIPDeath06;
        case 107: return GDIPDeath07;
        case 108: return GDIPDeath08;
        case 109: return GDIPDeath09;
        case 110: return GDIPDeath10;
        case 111: return GDIPDeath11;
        case 112: return GDIPDeath12;
        case 113: return GDIPDeath13;
        case 114: return GDIPDeath14;
        case 115: return GDIPDeath15;
        case 116: return GDIPDeath16;
        case 117: return GDIPDeath17;
        case 118: return GDIPDeath18;
        case 119: return GDIPDeath19;
        case 120: return GDIPDeath20;
        case 121: return GDIPDeath21;
        case 122: return GDIPDeath22;
        case 123: return GDIPDeath23;
        case 124: return GDIPDeath24;
        case 125: return GDIPDeath25;
        case 126: return GDIPDeath26;
        case 127: return GDIPDeath27;
        case 128: return GDIPDeath28;
        case 129: return GDIPDeath29;
        case 130: return GDIPDeath30;
        case 131: return GDIPDeath31;
        default: return nullptr;
    }
}

/**
 * Whether a payload ID is a heavy (serialized) payload.
 * @param payloadId HPPD payload number.
 * @return true for heavy payloads.
 */
static bool PhoenixHppdIsHeavyId(int payloadId)
{
    switch (payloadId)
    {
        case 1:
        case 2:
        case 5:
        case 6:
        case 7:
        case 8:
        case 9:
        case 10:
        case 11:
        case 13:
        case 14:
        case 15:
        case 17:
        case 19:
        case 20:
        case 21:
        case 22:
        case 23:
        case 24:
        case 40:
        case 48:
        case 50:
        case 51:
        case 52:
        case 53:
        case 54:
        case 55:
        case 56:
        case 57:
        case 58:
        case 59:
        case 60:
        case 61:
        case 62:
        case 63:
            return true;
        default:
            /* Death Month (101..131) is a full-screen per-pixel
             * renderer, so it serializes with the other heavy payloads. */
            return payloadId >= 101 && payloadId <= 131;
    }
}

namespace
{
    /**
     * Per-payload running flags and worker threads, indexed by payload ID.
     */
    std::atomic<bool> gPhoenixHppdRunning[132]{};
    std::thread gPhoenixHppdThreads[132];
    std::mutex gPhoenixHppdThreadsMutex;

    /**
     * Heavy slot: only one full-screen per-pixel renderer paints at a
     * time (HPPD's gHeavySlot mutex in start.cpp).
     */
    std::mutex gPhoenixHppdHeavyMutex;

    /**
     * Worker entry point: runs the payload (under the heavy mutex for
     * heavy payloads) and clears the running flag on exit.
     * @param payloadId Payload ID (for the running flag).
     * @param fn Payload thread function.
     * @param heavy Whether to hold the heavy mutex.
     */
    void PhoenixHppdWorker(int payloadId, LPTHREAD_START_ROUTINE fn, bool heavy)
    {
        if (heavy)
        {
            std::lock_guard<std::mutex> lock(gPhoenixHppdHeavyMutex);
            fn(nullptr);
        }
        else
        {
            fn(nullptr);
        }

        gPhoenixHppdRunning[payloadId].store(false);
    }
}

/* ------------------------------------------------------------------------- */
/*                              PUBLIC API                                   */
/* ------------------------------------------------------------------------- */

/**
 * Picks the global seed for this process.
 */
void phoenixHppdInitializeSeed()
{
    if (gPhoenixHppdSeed != 0)
        return;

    ULONGLONG tick = GetTickCount64();
    uint32_t seed = static_cast<uint32_t>(tick ^ (tick >> 32));
    seed ^= GetCurrentProcessId() * 0x9E3779B9u;
    seed ^= static_cast<uint32_t>(std::time(nullptr));

    if (seed == 0)
        seed = 0x12345678u;

    gPhoenixHppdSeed = seed;
    gPhoenixHppdStop.store(false);
}

/**
 * Triggers an HPPD payload on its own worker thread (non-blocking).
 * @param payloadId HPPD payload number.
 * @return true if a worker was started.
 */
bool phoenixHppdTrigger(int payloadId)
{
    if (payloadId < 0 || payloadId >= 132)
        return false;

    LPTHREAD_START_ROUTINE fn = PhoenixHppdLookup(payloadId);

    if (!fn)
        return false;

    const bool heavy = PhoenixHppdIsHeavyId(payloadId);

    std::lock_guard<std::mutex> lock(gPhoenixHppdThreadsMutex);

    if (gPhoenixHppdRunning[payloadId].load())
        return false;

    /* Reap a finished worker before replacing it. */
    if (gPhoenixHppdThreads[payloadId].joinable())
        gPhoenixHppdThreads[payloadId].join();

    /* A fresh trigger clears the stop latch so the new burst runs even
     * after a previous StopAll(). Already-aborted workers exit at their
     * next FXAbort() check; the brief overlap is benign for visual
     * effects (same race as HPPD's STOP + restart). */
    gPhoenixHppdStop.store(false);
    gPhoenixHppdRunning[payloadId].store(true);

    try
    {
        gPhoenixHppdThreads[payloadId] =
            std::thread(PhoenixHppdWorker, payloadId, fn, heavy);
        return true;
    }
    catch (...)
    {
        gPhoenixHppdRunning[payloadId].store(false);
        return false;
    }
}

/**
 * Latches the global stop flag so every running HPPD payload aborts.
 */
void phoenixHppdStopAll()
{
    gPhoenixHppdStop.store(true);
}

/**
 * Whether an HPPD payload worker is currently running.
 * @param payloadId HPPD payload number.
 * @return true if running.
 */
bool phoenixHppdIsRunning(int payloadId)
{
    if (payloadId < 0 || payloadId >= 132)
        return false;

    return gPhoenixHppdRunning[payloadId].load();
}

/**
 * Whether a payload ID is a heavy (serialized) payload.
 * @param payloadId HPPD payload number.
 * @return true for heavy payloads.
 */
bool phoenixHppdIsHeavy(int payloadId)
{
    return PhoenixHppdIsHeavyId(payloadId);
}

/**
 * Number of ported HPPD payloads (light + heavy + Death Month).
 * @return Payload count (97).
 */
int phoenixHppdCount()
{
    /* 35 heavy + 31 light + 31 Death Month. */
    return 97;
}

/**
 * Joins all HPPD worker threads.
 */
void phoenixHppdShutdown()
{
    gPhoenixHppdStop.store(true);

    std::lock_guard<std::mutex> lock(gPhoenixHppdThreadsMutex);

    for (int i = 0; i < 132; ++i)
    {
        if (gPhoenixHppdThreads[i].joinable())
            gPhoenixHppdThreads[i].join();

        gPhoenixHppdRunning[i].store(false);
    }
}

#endif /* _WIN32 */
