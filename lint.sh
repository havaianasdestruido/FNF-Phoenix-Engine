#!/bin/bash
export HAXELIB_PATH="$(pwd)/.haxelib"
haxelib install checkstyle
haxelib run checkstyle -c checkstyle.json -s source
