# Golferino: Game Design Brief (approved 2026-11-03)

Arcade-leaning, side-view golf roguelite in modern pixel art. The same 9-hole
course every run, a shop between holes, then a duel with a cheating rival on a
gauntlet hole. Beating the rival ends the run and totals the score. An infinite
mode comes later: leave room for it, do not build it yet.

## Decisions

| Area | Decision |
|---|---|
| Swing | Driver and Iron use the classic 3-click: start, set power, set accuracy |
| Putting | One press. With the Putter in hand the meter sweeps by itself, and pressing takes the power at that moment. No accuracy check, and no sweet spot shown |
| Missed accuracy | Early = pops up high and short. Late = low and hot |
| Shot control | Each club sets range and a default angle. Player adjusts the launch angle within the club's limits (Driver 10-45, Iron 15-75, Putter stays on the ground) and adds backspin or topspin. Changed from "clubs + spin" after playtesting Milestone 1 |
| Clubs | Fixed bag: Driver, Iron, Putter. Short approaches use the Iron at low power |
| Direction | The golfer hits toward the cup, with no manual flip (removed after playtesting Milestone 1). If no club has a safe shot that way, they turn and play back with the Iron offered, and the HUD says why |
| Trees | Scenery only, with no effect on the ball. Solid trees were tried and removed after playtesting: in a side view they block everything behind them. A tree is two separate pieces, a trunk and one set of leaves, placed and moved independently. Older maps' trees split into pieces on loading |
| Bounce pads | Plain rectangles (not ramps), on the ground or floating anywhere, at any rotation. The upper half is a spring that fires the ball straight out. The back and lower ends are ordinary solid bounces. Usually angled away from the hole as a hazard, sometimes toward it as a reward. Green faces the cup, orange faces away, yellow is flat. Weaker on repeat bounces, and stops after 3 per shot. The aim preview includes them. On the ground, an angled pad settles in around its middle. Original holes never have a pad that fires into water |
| Map editor | In-game, from the title menu, mouse and keyboard. Drag ground points, paint surfaces, place and rotate objects, set every option in a side panel, with undo. Test from the tee or any spot; Esc returns exactly where you were and scores don't count |
| Rotation | Pads, windmills and sprinklers rotate, with collisions following. Carts and geese stay level, because they travel along routes |
| Your maps | Any map can be edited or made from blank. Maps save to `user://maps` as JSON. Originals are never changed: an edit is a copy that replaces it until restored. The player chooses the course's holes and order, and the last hole is the boss |
| Moving hazards | Golf cart, windmill, sprinkler, geese. Carts and geese hit a ball once per shot. The aim preview ignores moving hazards, so the player has to time them |
| Posts | A ball starting a shot right beside the windmill tower or on a pad isn't blocked or fired by it, so it can't get stuck |
| Lies | Rough and sand reduce range, reduce spin and shrink the meter's sweet spot. The Driver loses the most range. The HUD shows the current club's range from this lie |
| Slopes | The launch angle tilts by half the ground's slope, and the ball always clears the slope it sits on. Landing downhill runs further, landing uphill runs less |
| Spin | Depends on the club (Driver half as much as Iron), the lie, and how clean the strike is. A full miss has no spin |
| Meter return | Takes the same time at any power, so short shots stay timeable |
| Flagstick | A ball hitting the pin in flight is knocked back and drops near the cup. Low putts pass under it |
| Stickers | Clubs are not sold. Shop sells stickers; each club holds up to 3 and each gives that club a bonus. A new sticker on a full club replaces one the player chooses, and the old one is lost |
| Run structure | Fixed 9 holes, then the boss hole |
| Losing a run | Stroke budget, starting at about 8 spare strokes. Beating par banks strokes, bogeys drain them. Zero ends the run immediately, even mid-hole, including on the boss hole |
| Shop | Between holes, random mixed stock: stickers, special balls, passive perks, bonus strokes |
| Coins | Score payout + course pickups + trick shot bonuses |
| Boss | Turn-based duel on a gauntlet hole. Lowest strokes wins; ties go to the rival. The rival cheats. Losing ends the run but the score still counts |
| Final score | Strokes under par, leftover strokes and coins, bonus for beating the rival, on a scorecard |
| Between runs | Finished runs unlock new stickers and perks for the shop (variety, not power). High scores saved |
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
| Boss | The Gauntlet | 7 | Every hazard in sequence. Plays solo until the duel arrives in Milestone 4 |

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
- `scripts/course/map_library.gd` and `hole_io.gd`: saved maps, restoring originals, the course order
- `scripts/editor/`: `EditorDoc` holds every editing rule with no drawing, `MapEditor` and `EditorUI` are the screen
- `scripts/app.gd`: moves between the title menu, playing and the editor
- `scripts/view/`: everything drawn. Nothing here changes game rules
- `data/`: clubs and holes as `.tres`, so adding one needs no new code
- `tests/`: `test_runner.tscn` for rules, `shots.tscn` for screenshots

Stickers, special balls and perks should change a shot by altering the numbers
passed into `ShotCalc` and `BallSim`, not by adding branches to them.

World scale: 3 pixels = 1 yard.
