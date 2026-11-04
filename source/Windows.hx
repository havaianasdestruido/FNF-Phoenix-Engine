package;

/**
 * Public alias for the native desktop facade.
 *
 * The implementation lives in `backend.Windows`: a root module named
 * `Windows.hx` would generate `include/Windows.h`, which collides with the
 * Windows SDK's `windows.h` on case-insensitive filesystems.
 */
typedef Windows = backend.Windows;
