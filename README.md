# Golferino

An arcade side-view golf roguelite, built in Godot 4.6 with GDScript. Windows only.
The approved design and architecture are in [DESIGN.md](DESIGN.md).

**Status:** Milestone 3, the full course: 9 holes and the boss hole, with hazards and wind.

## Run it

Double-click `Play.bat`, or run it from PowerShell:

```powershell
D:\ClaudeCode\Golferino\Play.bat
```

To work on it, open this folder in the Godot 4.6 editor and press F5.

## Map editor

Choose **Map Editor** on the title menu. It uses mouse and keyboard.

| Action | Control |
|---|---|
| Tools: select, ground, paint, add | 1 / 2 / 3 / 4 |
| Move the view | WASD, arrows, or right-drag |
| Zoom | Mouse wheel |
| Rotate a pad, windmill or sprinkler | Drag its ring, or hold Q / E |
| Rotate in 15 degree steps | Hold Shift while dragging, or Shift+Q / Shift+E |
| Remove the selected object | Delete |
| Add a ground point / remove one | Click the ground / right-click the point |
| Undo / redo | Ctrl+Z / Ctrl+Y |
| Save | Ctrl+S |
| Test from the tee | F5 |
| Test from the mouse position | T |
| Leave a test | Esc |

Dragging the last ground point changes the hole's length. **Maps** lists every map and the
course order. Original holes are never overwritten, and **Restore** brings one back.
Maps are saved in `%APPDATA%\Godot\app_userdata\Golferino\maps`.

## Controls

| Action | Keyboard | Controller |
|---|---|---|
| Swing (3 presses), or putt (2 presses) | Space or Enter | A |
| Launch angle (hold) | Up / Down | D-pad up / down |
| Look along the hole | A / D or Left / Right | D-pad left / right or left stick |
| Change club | Q / E, or 1 / 2 / 3 | LB / RB |
| Spin | W / S | Y / B |
| Flip to hit the other way (this shot only) | F | X |
| Scorecard (or restart, when testing a map) | Tab (or R) | Back |
| Pause, or end the run | Esc | Start |
| Menus and the shop | Arrow keys or W / A / S / D, then Space | D-pad or left stick, then A |
| Skip to next / previous hole (for reviewing) | Page Down / Page Up | |
| Fullscreen on or off | F11 | |

## Tests

From this folder, in PowerShell:

```powershell
& E:\GoDOT\Godot_v4.6.2-stable_win64_console.exe --headless --path . --quit-after 3000 res://tests/test_runner.tscn
& E:\GoDOT\Godot_v4.6.2-stable_win64_console.exe --path . --windowed --resolution 1280x720 --quit-after 3000 res://tests/shots.tscn
```

The first runs the rules tests and takes about two minutes, because simulated players
play every hole. Check for "0 failed": a script parse error can still exit with code 0.
The second plays the real scene, checks the input
bindings, and saves screenshots to `tests/shots`. `tests/editor_check.tscn` runs the same
way, and drives the title menu and map editor with real mouse clicks, using its own map folder. Keep `--quit-after`: a script error
would otherwise leave Godot running forever instead of exiting.
