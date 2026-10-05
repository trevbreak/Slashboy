#!/bin/sh
# Launch the Godot (native Metal) build of Slashboy. Extra args after -- go to the game, e.g.:
#   ./play.sh -- --quality=ultra
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/godot" && exec "$GODOT" --path . "$@"
