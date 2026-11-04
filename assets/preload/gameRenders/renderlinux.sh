#!/bin/bash

echo "hello there!"
echo "PS: this will only work if you have ffmpeg installed and are using the classic rendering mode."

read -p "enter the name of the song you'd like to render! (this is the folder that you'll use): " renderFolder

read -p "what would you like to name your rendered video?: " renderName

read -p "what is the framerate of your images/video? (defaults to 60): " vidFPS

if [ -z "$vidFPS" ]; then
    vidFPS=60
fi

read -p "lastly, are you rendering your video in a lossless format? (y/n, default n, makes the renderer find pngs instead of jpgs): " useLossless
if [ -z "$useLossless" ]; then
    useLossless="n"
fi

if [[ "${useLossless,,}" == "y" ]]; then
    fExt="png"
else
    fExt="jpg"
fi

echo
echo "Starting..."
echo

ffmpeg -r "$vidFPS" -i "$(dirname "$0")/$renderFolder/%07d.$fExt" "$renderName.mp4"

read -p "Press enter to continue..."
