Songs are rendered here!

This folder is created automatically when Rendering Mode starts, so deleting it is safe.

Video Rendering Mode (the default on desktop) needs FFmpeg. The game looks for it in this order:
 1. the PHOENIX_FFMPEG environment variable (the .exe itself or the folder that holds it);
 2. the folder that contains the game;
 3. the folder the game was started from;
 4. every folder on your PATH (so "winget install ffmpeg", scoop and choco all work);
 5. the usual install folders, e.g. C:\ffmpeg\bin, %ProgramFiles%\ffmpeg\bin,
    %LOCALAPPDATA%\Microsoft\WinGet\Links, %USERPROFILE%\scoop\shims and
    C:\ProgramData\chocolatey\bin.
If FFmpeg cannot be found the game tells you and the song plays without being recorded.

Classic Rendering Mode writes every frame into a folder named after the song instead. You'll
need FFmpeg to turn those frames into an MP4! Don't worry about organizing the folders by song
name, the engine does it automatically :)

For converting, here's the command I use:

ffmpeg -r 60 -i ./phobiaphobia/%07d.jpg  LOL.mp4

Replace phobiaphobia with the name of the song you rendered, and you can name the file whatever
you want instead of "LOL".

Alternatively, just run the bat file next to this one to make things simpler.
