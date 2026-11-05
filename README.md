# Golferino

An arcade side-view golf roguelite, built in Godot 4.6 with GDScript. Windows only.
The approved design and architecture are in [DESIGN.md](DESIGN.md).

**Status:** in final testing (Milestone 6). The full run is playable, with art, music, sound and polish.

## Download

[Download Golferino for Windows](https://github.com/napalmcookies1337-hash/Golferino/releases/latest/download/Golferino-Windows.zip)

Unzip it and double-click `Golferino.exe`, keeping `Golferino.pck` in the same folder.
Windows may warn about an unknown publisher: choose **More info**, then **Run anyway**.

## Run it from the source

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
| Music and sound levels (title and pause menus) | Left / Right on the row, or click it | D-pad left / right |
| Fullscreen on or off | F11 | |

## Infinite mode

Beat the rival once in the main game to open **Infinite Mode** on the title menu. You play
generated sets of nine holes and a boss, different every run, until you run out of strokes or
lose a duel. Beating a boss cashes in your spare strokes for coins and puts them back to 8, keeps
your coins and gear, and raises the difficulty one step, up to 10. It has its own page of high
scores.

## Floating Isles

An accuracy mode, open from the start, on the title menu. Choose a course of 1000, 2000 or 4000
yards: the hole is that far out across a chain of small islands, on a new map every time. Land on
them: a ball that falls off goes back to the tee, and your strokes carry on from where they were,
with no extra penalty. A checkered flag marks a checkpoint on an island about halfway. Once your
ball has come to rest on that island or any beyond it, falls return there instead. Reach the hole
to see your score and choose Try Again or Main Menu. There's no shop or stroke limit, and the
fewest strokes top each length's own table on the high scores screen. Leaving early doesn't record
a score.

## Collection

Choose **Collection** on the title menu to see everything the shop can sell. Items you haven't
earned yet are silhouettes. Finishing a duel with the rival unlocks the next one, and beating
the rival unlocks two. Pictures are drawn as text in `scripts/view/item_art.gd`. To see it as a
new player does, without touching your save, run `Play.bat res://tests/collection_preview.tscn`.

## Sound

Every sound is composed and synthesized by `tools/make_audio.gd`, so nothing comes from
outside. The melodies are written as note lists at the top of each song, and the finished
files are saved in `audio/`. After changing the script, make the files again from this folder:

```powershell
& E:\GoDOT\Godot_v4.6.2-stable_win64_console.exe --headless --path . -s tools/make_audio.gd --quit-after 100000
```

## Tests

From this folder, in PowerShell:

```powershell
& E:\GoDOT\Godot_v4.6.2-stable_win64_console.exe --headless --path . --quit-after 12000 res://tests/test_runner.tscn
& E:\GoDOT\Godot_v4.6.2-stable_win64_console.exe --path . --windowed --resolution 1280x720 --quit-after 40000 res://tests/shots.tscn
& E:\GoDOT\Godot_v4.6.2-stable_win64_console.exe --path . --windowed --resolution 1280x720 --quit-after 20000 res://tests/editor_check.tscn
```

- The first runs the rules tests and takes about seven minutes, because simulated players play
  every hole. Check for "0 failed": a script parse error can still exit with code 0. The two
  "Parse JSON failed" errors and two "Couldn't read map" warnings are expected, because it
  feeds the game damaged files on purpose.
- The second plays the real scene, checks the input bindings, and clears and refills
  `tests/shots` with screenshots. Run it before the third.
- The third drives the title menu, map editor and collection with real mouse clicks, using its
  own map folder, and adds its screenshots to the same place.

`tests/generator_check.tscn` plays generated holes with simulated players at every difficulty,
headless, and takes about twelve minutes. It prints the seed of any hole that fails.
`tests/isles_check.tscn` does the same for Floating Isles with a careful bot, taking a few minutes
per 4000 yard map: add `-- maps swing_error first_seed yards`, such as `-- 3 0.08 200 2000`.

Keep `--quit-after`: a script error would otherwise leave Godot running forever instead of
exiting. None of these touch your own scores, maps or settings.

## Build the Windows version

Needs the Godot 4.6.2 export templates, installed with **Editor > Manage Export Templates**.
From this folder, in PowerShell:

```powershell
New-Item -ItemType Directory -Force build\Golferino
& E:\GoDOT\Godot_v4.6.2-stable_win64_console.exe --headless --path . --export-release "Windows Desktop" build\Golferino\Golferino.exe
```

This makes `Golferino.exe` and `Golferino.pck`, which need to stay together. `export_presets.cfg`
leaves out the tests and tools.
