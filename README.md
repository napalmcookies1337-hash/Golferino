# Golferino

An arcade side-view golf roguelite, built in Godot 4.6 with GDScript. Windows only.
The approved design and architecture are in [DESIGN.md](DESIGN.md).

**Status:** Milestone 1, a playable prototype with one hole.

## Run it

Double-click `Play.bat`, or run it from PowerShell:

```powershell
D:\ClaudeCode\Golferino\Play.bat
```

To work on it, open this folder in the Godot 4.6 editor and press F5.

## Controls

| Action | Keyboard | Controller |
|---|---|---|
| Swing (3 presses) | Space or Enter | A |
| Look along the hole | A / D or Left / Right | D-pad or left stick |
| Change club | Q / E, or 1 / 2 / 3 | LB / RB |
| Spin | W / S or Up / Down | D-pad up / down |
| Hit the other way | F | X |
| Restart hole | R | Back |
| Fullscreen on or off | F11 | |
| Quit | Esc | |

## Tests

From this folder, in PowerShell:

```powershell
& E:\GoDOT\Godot_v4.6.2-stable_win64_console.exe --headless --path . --quit-after 3000 res://tests/test_runner.tscn
& E:\GoDOT\Godot_v4.6.2-stable_win64_console.exe --path . --windowed --resolution 1280x720 --quit-after 3000 res://tests/shots.tscn
```

The first runs the rules tests. The second plays the real scene, checks the input
bindings, and saves screenshots to `tests/shots`. Keep `--quit-after`: a script error
would otherwise leave Godot running forever instead of exiting.
