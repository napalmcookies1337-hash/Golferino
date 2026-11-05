# Golferino: Game Design Brief (approved 2026-11-03)

Arcade-leaning, side-view golf roguelite in modern pixel art. The same 9-hole
course every run, a shop between holes, then a duel with a cheating rival on a
gauntlet hole. Beating the rival ends the run and totals the score. An infinite
mode comes later: leave room for it, do not build it yet.

## Decisions

| Area | Decision |
|---|---|
| Swing | Driver and Iron use the classic 3-click: start, set power, set accuracy. A second press within 0.1 seconds of the last is a double tap and is ignored, everywhere swing is used in play and in the shop |
| Full power | Reaching the top of the bar, by pressing there or letting it run, is a full power shot: the meter says FULL POWER!! and the ball goes about 15% further. The cursor holds at the top briefly so a late power press can't count as the accuracy press. Accuracy still has to be timed on the way back |
| Putting | Two presses. The first starts the meter sweeping, and the second takes the power at that moment. No accuracy check, no sweet spot shown, no full power bonus |
| Missed accuracy | Early = pops up high and short. Late = low and hot. Both still apply on a full power shot if the accuracy press is badly off |
| Shot control | Each club sets range and a default angle. Player adjusts the launch angle within the club's limits (Driver 10-45, Iron 15-75, Putter stays on the ground) and adds backspin or topspin. Changed from "clubs + spin" after playtesting Milestone 1 |
| Clubs | Fixed bag: Driver, Iron, Putter. Short approaches use the Iron at low power |
| Direction | The golfer always starts each shot facing the cup, and the player can flip to hit the other way for that shot. The game never turns them on its own |
| Trees | Scenery only, with no effect on the ball. Solid trees were tried and removed after playtesting: in a side view they block everything behind them. A tree is two separate pieces, a trunk and one set of leaves, placed and moved independently. Older maps' trees split into pieces on loading |
| Bounce pads | Plain rectangles (not ramps), on the ground or floating anywhere, at any rotation. The upper half is a spring that fires the ball straight out. The back and lower ends are ordinary solid bounces. Usually angled away from the hole as a hazard, sometimes toward it as a reward. Green faces the cup, orange faces away, yellow is flat. Weaker on repeat bounces, and stops after 3 per shot. The aim preview includes them. On the ground, an angled pad settles in around its middle. Original holes never have a pad that fires into water |
| Map editor | In-game, from the title menu, mouse and keyboard. Drag ground points, paint surfaces, place and rotate objects, set every option in a side panel, with undo. Test from the tee or any spot; Esc returns exactly where you were and scores don't count |
| Rotation | Pads, windmills and sprinklers rotate, with collisions following. Carts and geese stay level, because they travel along routes |
| Your maps | Any map can be edited or made from blank. Maps save to `user://maps` as JSON. Originals are never changed: an edit is a copy that replaces it until restored. The player chooses the course's holes and order, and the last hole is the boss |
| Moving hazards | Golf cart, windmill, sprinkler, geese. Carts and geese hit a ball once per shot. The aim preview ignores moving hazards, so the player has to time them |
| Windmill door | A small square door runs through the tower's base, so a ball can pass through. The blades sweep down to the ground, so the player has to time it |
| Reading putts | Putts show no aim line, landing marker or reach, so they're judged purely by eye |
| Posts | A ball starting a shot right beside the windmill tower or on a pad isn't blocked or fired by it, so it can't get stuck |
| Lies | Rough and sand reduce range, reduce spin and shrink the meter's sweet spot. The Driver loses the most range. The HUD shows the current club's range from this lie |
| Slopes | The launch angle tilts by half the ground's slope, and the ball always clears the slope it sits on. Landing downhill runs further, landing uphill runs less |
| Spin | Depends on the club (Driver half as much as Iron), the lie, and how clean the strike is. A full miss has no spin |
| Meter return | Takes the same time at any power, so short shots stay timeable |
| Flagstick | A ball hitting the pin in flight is knocked back and drops near the cup. Low putts pass under it |
| Stickers | Clubs are not sold. Shop sells stickers; each club holds up to 3 and each gives that club a bonus. A new sticker on a full club replaces one the player chooses, and the old one is lost |
| Run structure | Fixed 9 holes, then the boss hole. A shop after every hole, including before the boss |
| Losing a run | Stroke budget, starting at 8 spare strokes. Beating par banks strokes, and strokes over par drain them as they're taken, including penalties. The stroke that uses up the last spare plays out: sinking it saves the run, and otherwise the run ends as the ball stops. Applies on the boss hole too. Restarting a hole is only for testing maps |
| Shop | Between holes, random mixed stock on 4 shelves: two stickers, one ball, perk or bonus strokes, and one of anything. Perks last for the rest of the run. The player carries up to 3 balls, starting with the plain one in a slot. A bought ball goes straight into play, and on full slots it replaces one the player chooses, which is lost. Balls can only be swapped in the shop. The Sticky Ball stops almost where it lands, on any slope, and putts like any other ball. The Rubber Ball bounces far higher and longer, keeps more speed through each bounce, rebounds harder off hazards, and visibly squashes and stretches. Everything costs 3 coins in the first shop, then prices climb evenly to each item's full price (10-28) by the last shop |
| Coins | Completing a hole pays 3 on Holes 1-3 and 5 from Hole 4 on, whatever the score, plus the coins picked up on the course. A hole in one pays 8 more. Perks can add to this: Coin Purse doubles pickups, Birdie Bank pays 5 extra under par, Steady Pay pays 3 extra for par, and Showman makes trick shots pay (hole in one 15, bank shot off a pad 8, chip-in 6, long putt 5, off the pin 4, through a windmill's door 3). Coins are objects placed in the editor. Edited maps from before coins existed get the original hole's coins |
| Boss | Turn-based duel on the course's last hole, player first. Lowest strokes wins; ties go to the rival, and it ends as soon as the result can't change. The rival uses plain clubs and sometimes mishits, and is only on screen for its own turn, and the player only for theirs, though both balls stay visible. Hazards hit its ball just like the player's. It cheats only twice on the hole: its first water ball can be a free drop, and every second turn it pulls one of a headwind on your next shot, grease that speeds your next meter, a kick of its ball toward the cup, or erasing a stroke. Losing ends the run but the score still counts |
| Final score | 100 per hole finished, 100 per stroke under par (minus if over), 50 per spare stroke left, 2 per coin left, 1000 for beating the rival, on a scorecard. An unfinished hole doesn't count for or against par |
| Between runs | Finished runs (that reached a duel result) unlock shop items, one for losing and two for winning (variety, not power). Top 10 high scores saved, including runs that ended early |
| Camera | Free scroll to inspect the hole before a shot, then smooth chase of the ball with some lead |
| Course | One cohesive country-club look. Classic hazards first, escalating to moving and stranger ones |
| Wind | Not part of the normal swing. Only on later holes and as a rival trick |
| Hazards | Water costs a penalty stroke and returns the ball to its last spot |
| Golfer | One original golfer, no multiplayer |
| Art | Modern pixel art, 640x360 scaled 3x to 1080p, 16:9, richer palette, all original |
| Audio | Breezy chiptune, tense shift for the boss, all original |
| Controls | Keyboard and controller |
| Target | Windows only, Godot 4 and GDScript |

Not in this version: multiplayer, online leaderboards, procedural holes,
infinite mode, other platforms.

## The course (par 43)

| Hole | Name | Par | Introduces |
|---|---|---|---|
| 1 | The Opener | 4 | Bunker, pond |
| 2 | Short Hop | 3 | A bunker guarding the green |
| 3 | The Ridge | 4 | Big elevation, first bounce pads |
| 4 | Long Meadow | 5 | First wind, two trouble spots |
| 5 | Cart Path | 4 | Golf cart |
| 6 | The Old Mill | 3 | Windmill |
| 7 | Sprinkler Hill | 4 | Sprinklers, headwind |
| 8 | Goose Pond | 4 | Geese over a wide pond |
| 9 | Clubhouse Climb | 5 | Everything so far |
| Boss | The Gauntlet | 7 | Every hazard in sequence, in a duel with the rival |

## Milestones (stop for review at each)

1. Playable golf prototype: golfer, ball, basic course, camera, meter, a working shot
2. Core golf mechanics: swing, physics, terrain interactions
3. Course design and hazards: the 9 holes and boss hole, course progression
4. UI and game flow: scorekeeping, shop, run flow, stroke budget
5. Art, audio and polish
6. Final testing and delivery

## Architecture

Gameplay rules never touch nodes or drawing, so they run headless in tests.

- `scripts/golf/`: `SwingMeter`, `ShotCalc`, `BallSim`, `Surface`, `ClubData`
- `scripts/course/`: `HoleData`, `CourseData`, `Terrain` (baked height and surface lookup), and `Obstacle` with one subclass per hazard
- `scripts/game/hole_game.gd`: one hole's rules. Views read it and listen to its signals
- `scripts/game/course_run.gd`: progress through the course and scores so far
- `scripts/game/run_state.gd`: one run's budget, coins, what's owned, the shop's stock and the final score
- `scripts/game/items.gd`: everything the shop sells, as data, and how it changes the numbers
- `scripts/game/rival.gd`: the rival's turns, choice of shots and cheats
- `scripts/game/profile.gd`: high scores and unlocks, saved to `user://profile.json`
- `scripts/course/map_library.gd` and `hole_io.gd`: saved maps, restoring originals, the course order
- `scripts/editor/`: `EditorDoc` holds every editing rule with no drawing, `MapEditor` and `EditorUI` are the screen
- `scripts/app.gd`: moves between the title menu, playing and the editor
- `scripts/view/`: everything drawn. Nothing here changes game rules
- `data/`: clubs and holes as `.tres`, so adding one needs no new code
- `tests/`: `test_runner.tscn` for rules, `shots.tscn` for screenshots

Stickers, special balls and perks should change a shot by altering the numbers
passed into `ShotCalc` and `BallSim`, not by adding branches to them.

World scale: 3 pixels = 1 yard.
