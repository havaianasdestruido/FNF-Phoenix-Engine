# Desktop notifications

The existing `PlatformUtil.sendNotification(title, message)` API and the
Windows Notification chart event also work on Linux and macOS desktop builds.
Windows uses its notification-area implementation; Linux invokes `notify-send`
(from libnotify) and macOS invokes `osascript` to request a notification. No
shell interprets the supplied text. Other targets return `false`.

The result indicates whether the platform helper accepted the request, not
whether a notification appeared. Desktop notification settings, permissions,
focus modes, or a missing notification service may suppress it. On Linux,
`notify-send` must be installed and a desktop notification service available.
The helper runs synchronously, so avoid sending notifications every frame.
The event reports failure in the script debug output.
