# Golferino: Game Design Brief (approved 2026-11-03)

Arcade-leaning, side-view golf roguelite in modern pixel art. The same 9-hole
course every run, a shop between holes, then a duel with a cheating rival on a
gauntlet hole. Beating the rival ends the run and totals the score. An infinite
mode comes later: leave room for it, do not build it yet.

## Decisions

| Area | Decision |
|---|---|
| Swing | Classic 3-click: start, set power, set accuracy |
| Missed accuracy | Early = pops up high and short. Late = low and hot |
| Shot control | Each club sets range and a default angle. Player adjusts the launch angle within the club's limits (Driver 10-45, Iron 15-75, Putter stays on the ground) and adds backspin or topspin. Changed from "clubs + spin" after playtesting Milestone 1 |
| Clubs | Fixed bag: Driver, Iron, Putter. Short approaches use the Iron at low power |
| Direction | The golfer always hits toward the cup. There is no manual flip (removed after playtesting Milestone 1) |
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
- `scripts/course/`: `HoleData`, `Terrain` (baked height and surface lookup)
- `scripts/game/hole_game.gd`: one hole's rules. Views read it and listen to its signals
- `scripts/view/`: everything drawn. Nothing here changes game rules
- `data/`: clubs and holes as `.tres`, so adding one needs no new code
- `tests/`: `test_runner.tscn` for rules, `shots.tscn` for screenshots

Stickers, special balls and perks should change a shot by altering the numbers
passed into `ShotCalc` and `BallSim`, not by adding branches to them.

World scale: 3 pixels = 1 yard.
