# Golferino: Game Design Brief (approved 2026-11-03)

Arcade-leaning, side-view golf roguelite in modern pixel art. The same two courses
every run, Grassy Greens then Swampy Shores, each 9 holes with a shop between holes
and a duel with a cheating rival on a gauntlet hole. Beating the second rival ends the
run and totals the score. Infinite mode carries on with generated holes, set after set,
for as long as the player lasts.

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
| Trees | Scenery only, with no effect on the ball. Solid trees were tried and removed after playtesting: in a side view they block everything behind them. A tree is two separate pieces, a trunk and one set of leaves, placed and moved independently. Older maps' trees split into pieces on loading. Trees the game makes (original and generated holes) never show a gap: leaves always cover at least the top 5 pixels of the trunk across its whole width. Pieces placed by hand in the editor stay exactly where they're put |
| Bounce pads | Plain rectangles (not ramps), on the ground or floating anywhere, at any rotation. The upper half is a spring that fires the ball straight out. The back and lower ends are ordinary solid bounces. Usually angled away from the hole as a hazard, sometimes toward it as a reward. Green faces the cup, orange faces away, yellow is flat. Weaker on repeat bounces, and stops after 3 per shot. The aim preview includes them. On the ground, an angled pad settles in around its middle. Original holes never have a pad that fires into water |
| Map editor | In-game, from the title menu, mouse and keyboard. Drag ground points, paint surfaces, place and rotate objects, set every option in a side panel, with undo. Test from the tee or any spot; Esc returns exactly where you were and scores don't count |
| Rotation | Pads, windmills and sprinklers rotate, with collisions following. Carts and geese stay level, because they travel along routes |
| Your maps | Any map can be edited or made from blank. Maps save to `user://maps` as JSON. Originals are never changed: an edit is a copy that replaces it until restored. The player chooses the course's holes and order, and the last hole is the boss |
| Moving hazards | Golf cart, windmill, sprinkler, geese. Carts and geese hit a ball once per shot. The aim preview ignores moving hazards, so the player has to time them |
| Windmill door | A small square door runs through the tower's base, so a ball can pass through. The blades sweep down to the ground, so the player has to time it |
| Aim guide | Full swings show a dotted arc for the start of the shot, with no marker where it lands and no reach in yards, so the landing is judged by eye. The HUD gives the distance to the pin and the wind. The Landing Arrow perk adds back an arrow marking where a full-power shot lands. It costs 60 coins in every shop, without the usual low early prices, though the Coupon Book and infinite difficulty still change that. Putts never show one |
| Reading putts | Putts show no aim line, landing marker or reach, so they're judged purely by eye |
| Posts | A ball starting a shot right beside the windmill tower or on a pad isn't blocked or fired by it, so it can't get stuck |
| Lies | Rough and sand reduce range, reduce spin and shrink the meter's sweet spot. The Driver loses the most range. The HUD shows the share of the current club's power available from this lie |
| Slopes | The launch angle tilts by half the ground's slope, and the ball always clears the slope it sits on. Landing downhill runs further, landing uphill runs less |
| Spin | Depends on the club (Driver half as much as Iron), the lie, and how clean the strike is. A full miss has no spin |
| Meter return | Takes the same time at any power, so short shots stay timeable |
| Flagstick | A ball hitting the pin in flight is knocked back and drops near the cup. Low putts pass under it |
| Stickers | Clubs are not sold. Shop sells stickers; each club has 3 slots and each sticker gives that club a bonus. More of the same sticker stacks in its slot, up to 3, and the bonuses add up (three Wide Angles give 30 degrees). A reduction such as Forgiver's applies again to what's left, so it can never pass 100%. A new kind of sticker on a full club replaces a slot the player chooses, and that whole stack is lost. Overdrive (Driver and Iron) trades control for distance: each one adds 15% real carry and runs the meter 20% faster, so three give +45% and 1.6x speed |
| Run structure | Fixed 9 holes, then the boss hole. A shop after every hole, including before the boss |
| Losing a run | Stroke budget, starting at 8 spare strokes. Beating par banks strokes, and strokes over par drain them as they're taken, including penalties. The stroke that uses up the last spare plays out: sinking it saves the run, and otherwise the run ends as the ball stops. Applies on the boss hole too. Restarting a hole is only for testing maps |
| Shop | Between holes, random mixed stock on 4 shelves: two stickers, one ball, perk or bonus strokes, and one of anything. Perks last for the rest of the run. The player carries up to 3 balls, starting with the plain one in a slot. A bought ball goes straight into play, and on full slots it replaces one the player chooses, which is lost. Balls can only be swapped in the shop. The Sticky Ball stops almost where it lands, on any slope, and putts like any other ball. The Rubber Ball bounces far higher and longer, keeps more speed through each bounce, rebounds harder off hazards, and visibly squashes and stretches. Everything costs 3 coins in the first shop, then prices climb evenly to each item's full price (10-28) by the last shop. A reroll button puts new items on every shelf, including ones already bought from. It costs 3 coins, doubling with each use (3, 6, 12...), and goes back to 3 in the next shop. Discounts and difficulty never change that price |
| Coins | Completing a hole pays 3 on Holes 1-3 and 5 from Hole 4 on, whatever the score, plus the coins picked up on the course. A hole in one pays 8 more. Perks can add to this: Coin Purse doubles pickups, Birdie Bank pays 5 extra under par, Steady Pay pays 3 extra for par, and Showman makes trick shots pay (hole in one 15, bank shot off a pad 8, chip-in 6, long putt 5, off the pin 4, through a windmill's door 3). Coins are objects placed in the editor. Edited maps from before coins existed get the original hole's coins |
| Boss | Turn-based duel on the course's last hole, player first. Lowest strokes wins; ties go to the rival, and it ends as soon as the result can't change. The rival uses plain clubs and sometimes mishits, and is only on screen for its own turn, and the player only for theirs, though both balls stay visible. Hazards hit its ball just like the player's. It cheats only twice on the hole: its first water ball can be a free drop, and every second turn it pulls one of a headwind on your next shot, grease that speeds your next meter, a kick of its ball toward the cup, or erasing a stroke. Losing ends the run but the score still counts |
| Final score | 100 per hole finished, 100 per stroke under par (minus if over), 50 per spare stroke left, 2 per coin left, 1000 for beating the rival, on a scorecard. An unfinished hole doesn't count for or against par |
| Between runs | Finished runs (that reached a duel result) unlock shop items, one for losing and two for winning (variety, not power). Top 10 high scores saved, including runs that ended early |
| Collection | On the title menu. Shows everything the shop can sell plus the plain ball, grouped by kind, each with its own picture, which the shop's cards use too. The items on sale from the start are always shown. An item still to be earned is a dark silhouette with its name and effect hidden, and a gold corner marks one that has been earned |
| Infinite mode | A separate mode on the title menu, locked until the rival has been beaten once in the main game. Sets of 9 generated holes and a boss duel, using the same stroke budget, shops and rules. Every run is different. Running out of strokes or losing a duel ends the run. Beating a boss adds a reward of 6 strokes (shrinking to 1 at the top difficulty) to the spare strokes, banks them all for half as many coins, rounded down, and puts the spare strokes back to the starting 8. Coins and gear carry over, the difficulty rises one step, and a shop leads to the next set. The set and difficulty show in the score box |
| Infinite difficulty | 10 small steps, then it stays at the top while the sets carry on. Each step makes holes longer for the same par, greens narrower, hazards faster and more numerous, and wind stronger. The rival mishits less, plans more finely and cheats more often. Shop prices rise 4% and the boss reward shrinks. All the numbers are in `difficulty.gd`, and level 0 is the main game's own values |
| Generated holes | Meant to feel unlike the main course. Every hole has one of eight shapes: a long climb, a descent, a valley, a hump, big waves, steep terraces, a chain of islands, or badlands of broken fairway and waste sand. A set deals them out so it uses them all before repeating, and until difficulty 4 its first two holes avoid the harshest three. About a third play right to left. Pars are a shuffled mix that can include par 6, some pads float in the air, and past the green there may be a bank, a flat shelf or a slope away. Hazards are the usual bunkers, ponds, pads, carts, windmills, sprinklers and geese. Each set ramps up, with the stranger hazards arriving later, and higher difficulty brings them forward. No pond starts within a normal drive of the tee on a par 4 or longer. The boss hole always has every moving hazard. Pads are checked by firing a real ball at them, so none aims into water |
| Infinite scoring | Same score as the main game over the whole run, plus 1000 per boss beaten, with its own top 10 showing the set reached and bosses beaten. The scorecard shows the current set, and the running total covers every set. Each boss beaten unlocks two shop items, and the duel that ends a run in a loss unlocks one. From the second set on, shop items cost full price and every hole pays the full payout |
| Camera | Free scroll to inspect the hole before a shot, then smooth chase of the ball with some lead |
| Course | One cohesive country-club look. Classic hazards first, escalating to moving and stranger ones |
| Wind | Not part of the normal swing. Only on later holes and as a rival trick |
| Hazards | Water costs a penalty stroke and returns the ball to its last spot |
| Golfer | One original golfer, no multiplayer |
| Art | Modern pixel art, 640x360 scaled 3x to 1080p, 16:9, richer palette, all original |
| Time of day | The sky moves on as the course goes: morning on the first holes, midday, then a golden afternoon. The boss hole is always dusk. The clubhouse stands on the far hills throughout. A map being tested stays at midday. Looks only |
| Golfer's moods | Your golfer breathes while waiting, hangs their head at a penalty, and when a hole is finished jogs over to the cup, in from off screen after a long shot, and jumps for joy. The rival's shoulders shake with laughter when it cheats |
| Impact | A full power strike briefly holds the picture, shakes the view and leaves a golden streak. A perfect strike throws white sparks. These never change how a shot plays |
| Audio | A breezy chiptune for the title screen only. Courses have music by biome: Grassy Greens is an upbeat jazzy swing with the tense faster track for its rival, and Swampy Shores is a grungy, bassy underground bump with a grungy, bassy, frantic track for its rival. Floating Isles has its own airy track, and one relaxed tune plays in every shop and the map editor. A Jukebox on the title menu, under the Music and Sound rows, plays them all. Jingles for each result, sound effects throughout, and soft birdsong outdoors. Music and sound each have a 0-10 level on the title and pause menus, remembered between runs. All original, all generated by `tools/make_audio.gd` |
| Final score screen | The score is read out a row at a time and the total counts up. The first press shows the rest straight away, and the next one moves on |
| Controls | Keyboard and controller |
| Target | Windows only, Godot 4 and GDScript |

Not in this version: multiplayer, online leaderboards, other platforms.

## Swampy Shores

The second biome and the main game's second course. Grassy Greens is the first course. Beating its
rival leads through a shop to Swampy Shores, with coins, gear and exact spare strokes carried over.

| Rule | Decision |
|---|---|
| Course | 9 fixed holes and a boss, par 44, in `data/course_02.tres`. `tools/make_swamp_holes.gd` writes the files, and the map editor treats them like any other original |
| Prices and pay | Full shop prices and full hole payouts, the same as any later set |
| Mud | A new surface. The ball barely bounces or runs, and a shot out of it has 72% range and a smaller sweet spot, a little better than sand |
| Murky water | Looks different, plays like any water: a penalty stroke and back to the last spot. The Skipper still skips |
| Lily pads | Floating on water. A ball can land on one, rest and be played from it, at 88% range. Rolling off the edge goes in the water. Placed as an object with a width |
| Swamp windmill | The same object as the normal windmill, with the same door, blades and collisions, drawn dilapidated: rotten grey boards, moss, a sagging roof and torn sails. Mangrove roots were tried and removed after playtesting |
| Gators | Lie still on land. Their jaws open as a ball nears, and a ball that comes within 13 pixels of the body is eaten: a penalty just like water, back to the last spot, which a Mulligan covers. The gator then flashes and is gone for the rest of the hole. High shots pass over. They don't move, so the game's own club choice and the rival's planning both avoid them. A ball struck from right beside one isn't eaten. The rival's ball can feed them too |
| Snapping frogs | Hop back and forth along a route, on land or water, and knock away a ball that hits them, once per shot. The aim guide ignores them |
| Gas vents | Quiet, then a bubbling warning, then a burst that throws a ball upward once per burst. The sideways drift changes each burst in a fixed pattern, so it looks random but rolls no dice, and it never goes past a set limit. The aim guide ignores them, and a ball struck from beside one isn't caught |
| Rival | The same rival in swamp colors with its own ball color. It plays four difficulty steps better than it would otherwise, but always cheats at most twice a hole, free drops included, even at top difficulty |
| Scoring and unlocks | 1000 points for each rival beaten, and two shop unlocks for each. Losing a duel ends the run and unlocks one. Infinite Mode still opens from beating the first rival |
| Look | Hazy green-grey sky, dead trees, mist, mossy trees and dark peat, darker in three steps along the course, with a sickly glow behind the boss hole. Trees follow the same no-gap rule. Looks only |
| Sound | Its own music and rival music, and its own ambience of crickets and distant frogs. Mud, frogs, vents and gators have their own sound effects |
| Infinite Mode | Sets alternate, Grassy Greens first. Generated swamp holes use the same shapes, with frogs in place of carts, vents in place of sprinklers, the swamp windmill, gators from the third hole on and always on the boss, lily pads on every pond, and mud in place of sand and rough stretches |
| Editor | A map's look can be toggled between grassy and swampy, mud can be painted, and frogs, vents, gators and lily pads placed. The maps screen shows and edits either course's order |

## Floating Isles

An accuracy training mode, open from the start on the title menu. The player chooses 1000, 2000
or 4000 yards, and gets one random hole of that length across a chain of small islands with only
sky between them.

| Rule | Decision |
|---|---|
| Map | New every time, including after Try Again. Islands are 110-210 px wide and level on top, gaps are 80-340 px, and neighbours differ in height by up to 55 px. The tee has the first island and the green the last |
| Falling | Falling off an island, or off either end of the map, returns the ball to the tee, or to the checkpoint once reached. Strokes taken so far stay, and the fall itself adds no stroke |
| Checkpoint | A checkered flag on a pole, with no hole, on the island nearest halfway (never the tee's or the green's). It's reached when the ball comes to rest on that island or any beyond it, so a long shot over it still counts. The flag doesn't touch the ball. A returned ball sits just on the tee side of the flag |
| Clubs and rules | The plain three clubs and plain ball. Every shot starts on the Iron, or the Putter once on the green, and the player can still change club. No wind, coins, shop, stroke limit or unlocks |
| Rock | An island has an underside: a ball can hit its side and bounce away, or pass beneath it. It only lands on an island from above |
| Finishing | The golfer appears right beside the cup instead of running over, and the hole gives confetti, then a congratulations screen with the strokes, falls and place on the leaderboard, offering Try Again or Main Menu |
| Leaderboard | A top ten for each length, side by side on the high scores screen. Fewest strokes first, then fewest falls. Leaving from the pause menu records nothing. Try Again keeps the same length on a new map |
| Look | A sea of cloud below instead of the hills, at midday |

The rules live in `IslesGenerator`, `Terrain` (`void_spans`, `is_void`, `underside_y`), `BallSim`
and `HoleGame.falls_return_to_tee`. Ordinary holes have no void spans and play exactly as before.

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
- `scripts/game/difficulty.gd`: every number infinite mode raises, in one place
- `scripts/course/hole_generator.gd`: makes infinite mode's holes as ordinary `HoleData`
- `scripts/game/profile.gd`: high scores and unlocks, saved to `user://profile.json`
- `scripts/course/map_library.gd` and `hole_io.gd`: saved maps, restoring originals, the course order
- `scripts/editor/`: `EditorDoc` holds every editing rule with no drawing, `MapEditor` and `EditorUI` are the screen
- `scripts/app.gd`: moves between the title menu, playing and the editor
- `scripts/view/`: everything drawn. Nothing here changes game rules. `item_art.gd` holds every item's picture as text
- `scripts/audio/`: `Sound` plays everything and keeps the volume levels, and `GameAudio` listens to one hole's rules and picks what to play
- `tools/make_audio.gd`: composes and synthesizes every sound into `audio/`. The game only loads the finished files
- `data/`: clubs and holes as `.tres`, so adding one needs no new code
- `tests/`: `test_runner.tscn` for rules, `shots.tscn` for screenshots of a real run, `editor_check.tscn` for the menus and editor, `generator_check.tscn` to play generated holes at every difficulty, `collection_preview.tscn` to see the collection with an empty save, `swamp_preview.tscn` to start a run on Swampy Shores, `swamp_check.tscn` to play that course with simulated players

Stickers, special balls and perks should change a shot by altering the numbers
passed into `ShotCalc` and `BallSim`, not by adding branches to them.

World scale: 3 pixels = 1 yard.
