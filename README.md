# Marathon Runner: Water Balance

A one-screen model of the Marathon Runner anchor phenomenon (New Visions Biology, Marathon Runner, Water
Balance 5E). Students set the runner's pace and how much (and what) she drinks, run a 4-hour race in about a
minute, and watch sweat, drinking, blood water and salt, the brain's ADH signal, the kidneys' urine and a body
cell that swells or shrinks. Blood sodium is shown on an illustrative mEq/L scale against the curriculum's
normal range, 135-145 mEq/L, so students can compare with the runner's Medical Tent Data.

The Godot 4.5 project is `water_balance/` (main scene `scenes/main.tscn`). It is a standalone game for
sims.mr-miner.com (decided 2026-10-10), not a mode of the osmosis simulation.

## Features
- [x] Validated numerical model: water and salt in blood (fluid outside cells) and in cells, osmosis, delayed
      ADH feedback strong enough that healthy kidneys clear a moderate surplus (model 0.3.0), kidney urine output, delayed absorption of drinks; conservation ledgers (`model/`)
- [x] Pace: Walk / Jog / Run (sweat rate); amount: None / A little / Medium / Lots; drink: Water / Sports drink
- [x] Sports drink adds a little salt with its water (about 20 mEq/L, 0.15 of blood)
- [x] Body diagram: drink in, sweat (water + salt) out, blood water level and salt crowding, ADH meter and
      signal path, kidneys and urine (arrow width follows urine output)
- [x] Body cell with its starting size dashed, size changes drawn 2x, net water arrows
- [x] Blood sodium gauge (illustrative mEq/L = 140 x the model's blood concentration) with the 135-145 band
- [x] Graphs over race time: blood sodium (with the normal band) and cell size
- [x] Keep this run: a dashed, labelled line to compare with the next run
- [x] Water and salt tally: drunk, sweat, urine and blood now, plus "blood saltiness = salt / water", so students
      see a runner lose more salt than a walker yet keep saltier blood (sweat takes out even more water)
- [x] Plain-language observation line (blood saltier/diluted, water into/out of cells, ADH and kidneys)
- [x] Medical-data card: normal range 135-145 mEq/L (source: Water Balance 5E, Evaluate)
- [x] Start / pause / restart, speed 1x / 2x / 4x (a race takes 60 s at 1x)
- [x] Keyboard: Tab through all 14 buttons with a yellow focus outline; Space starts and pauses; Tab past
      the last, Shift+Tab before the first, or Escape sends `sims:leave-game` (sims-site SPEC section 6)
- [x] Small frames and phones: text stays >= 85% size, the panels wrap and the page scrolls
- [x] Web export (2D lean template): `..\exports\water-balance\`, checked in headless Chromium (7 checks)
- [ ] Classroom try-out on Chromebooks
- [ ] Put on sims.mr-miner.com (hidden first)

Not included (from the full design, `The Runner's Water Balance — version 1.1.md`): guided investigations,
A/B pairs beyond one kept run, causal flowchart, token snapshot, sentence frames, Investigate/Explain settings.

### Model results (end of the 4-hour race, illustrative mEq/L)
| Pace | None | A little | Medium | Lots of water | Lots of sports drink |
|---|---|---|---|---|---|
| Walk | 146 | 139 | 135 | 116 | 124 |
| Jog | 155 | 143 | 137 | 121 | 130 |
| Run | 164 | 151 | 139 | 127 | 132 |

Model 0.3.0 (2026-10-10). At Medium, ADH falls and the kidneys remove the walker's extra water, so she ends just at
the bottom of the normal range. Lots is more than sweat plus the kidneys' maximum can remove: ADH reaches zero and
the blood still dilutes, most for the walker (she sweats least). Sweat is about 0.3 times as salty as blood, so the
runner loses more salt than the walker but keeps saltier blood. A sports drink raises the Lots values a little but
does not prevent the drop. (0.2.0 had a weak ADH response: Walk + Medium fell to 128 with ADH still "medium".)

## Tests
From `water_balance/` (bash):

```bash
GODOT=../../../Godot_v4.5-stable_win64.exe bash tests/run_all_tests.sh
```

Suites: `run_model_tests` (139 checks, 24 scenarios), `run_controller_tests` (31), `run_ui_tests` (80: drink type,
the anchor endpoints, ADH feedback and sweat salt, the tally, keyboard exit, Space, toggles, kept run). `run_refinement_tests` is the slower step-size study.
Screenshot (windowed, optional `WB_PACE=0..2`): `WB_T=40 WB_OUT=<png> ../../../Godot_v4.5-stable_win64.exe --path . --resolution 1280x720 --script res://tools/screenshot.gd`.

## Export
`python ..\..\..\godot-2d-web-template\check_web_template.py water_balance` reports the GUI template only because
the old prototype in `views/` uses OptionButton; `views/` and `preview.tscn` are excluded from the export, so the
preset uses the 2D template. Export: `Godot --headless --path water_balance --export-release "Web" ../../exports/water-balance/index.html`.
