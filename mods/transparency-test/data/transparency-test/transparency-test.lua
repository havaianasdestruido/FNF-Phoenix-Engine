-- Color-key transparency smoke test for the Phoenix Engine desktop window.
-- RGB(1, 1, 1) is the engine's default transparency key on Windows.
local transparencyKey = '010101'
local previousWindowAlpha = 1.0

function onCreatePost()
    -- Keep the camera background a perfectly flat, opaque match for the key.
    previousWindowAlpha = getWindowAlpha()
    setProperty('camGame.bgColor', transparencyKey)
    setWindowTransparencyColor(transparencyKey)
    setWindowAlpha(1.0)

    -- Safe no-op on platforms without color-key support; it logs the limitation.
    setWindowTransparent(true)
end

function onDestroy()
    -- The native window outlives the song script, so always remove the key.
    setWindowTransparent(false)
    setWindowAlpha(previousWindowAlpha)
end
