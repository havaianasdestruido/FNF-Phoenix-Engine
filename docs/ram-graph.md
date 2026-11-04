# Gameplay RAM graph

The graph is off by default. Pause a song and select **RAM Graph: OFF** to turn
it on; select it again to turn it off. The setting is saved between sessions.
The graph samples twice per second during gameplay and starts a fresh history
when enabled. It stops sampling while the song is paused.

Each bar is one sample and the cyan line smoothly passes through the tops of
adjacent bars. The header shows current usage and the displayed vertical range.
The range automatically follows the visible history, so bar colors indicate
relative position within that range, **not** how close the system is to running
out of RAM. The history covers about 23 seconds when full.

Like the existing FPS counter, the graph reports process resident memory on C++
targets and the managed heap on other targets. Some platforms may not expose a
meaningful memory measurement.
