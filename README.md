# Marathon Runner: Water Balance

A one-screen model of the Marathon Runner anchor phenomenon (New Visions Biology, Marathon Runner, Water
Balance 5E). Students choose whether the runner stops or runs and how much (and what) she drinks, run a 4-, 6- or
8-hour race in one to two minutes, and watch sweat, drinking, blood water and salt, the brain's ADH signal and the
kidneys' urine. Cell size and osmosis are left to the separate osmosis simulation. Blood sodium is shown on an illustrative mEq/L scale against the curriculum's
normal range, 135-145 mEq/L, so students can compare with the runner's Medical Tent Data.

The Godot 4.5 project is `water_balance/` (main scene `scenes/main.tscn`). It is a standalone game for
sims.mr-miner.com (decided 2026-10-10), not a mode of the osmosis simulation.

## Features
- [x] Validated numerical model: water and salt in blood (fluid outside cells) and in cells, osmosis, delayed
      ADH feedback strong enough that healthy kidneys clear a moderate surplus (model 0.3.0 tuning; 0.4.0 options), kidney urine output that saves salt when the blood is dilute (0.5.0), delayed absorption of drinks; conservation ledgers (`model/`)
- [x] Pace: Stop (resting, 1/8 of Run's sweat) / Run; amount: None / Medium / Lots; drink: Water / Sports drink
- [x] Race length: 4 hours (default) / 6 hours / 8 hours. Same rates, just a longer run (15 model time units per
      hour); the graphs keep their width and their hour marks squeeze in. Lengthening a paused race lets it continue
- [x] Sports drink adds a little salt with its water (about 20 mEq/L, 0.15 of blood)
- [x] Body diagram: drink in, sweat (water + salt) out, blood water level and salt crowding, ADH meter and
      signal path, kidneys and urine (arrow width follows urine output)
- [x] Blood sodium gauge (illustrative mEq/L = 140 x the model's blood concentration) with the 135-145 band
- [x] Graph over race time: blood sodium (with the normal band), 100-180 mEq/L
- [x] The runner collapses (the race stops, with the reason on screen) when blood water leaves 65-150% of its start
      or sodium leaves 110-170 mEq/L: classroom stops so extreme runs don't show unsurvivable values
- [x] Keep this run: a dashed, labelled line to compare with the next run
- [x] Body pane: the diagram and observation on the left; on the right the water and salt tally (drunk, sweat,
      urine) as percentages of what the blood held at the start, with what the numbers mean, then
      "blood saltiness = salt ÷ water = ... mEq/L", the sodium gauge and the medical data. Students see a runner
      lose more salt than a resting runner yet keep saltier blood (sweat takes out even more water)
- [x] Plain-language observation line (blood saltier/diluted, water into/out of cells, ADH and kidneys)
- [x] Medical-data card: normal range 135-145 mEq/L (source: Water Balance 5E, Evaluate)
- [x] Start / pause / restart, speed 1x / 2x / 4x (a 4-hour race takes 60 s at 1x, 8 hours 120 s)
- [x] Keyboard: Tab through all 15 buttons with a yellow focus outline; Space starts and pauses; Tab past
      the last, Shift+Tab before the first, or Escape sends `sims:leave-game` (sims-site SPEC section 6)
- [x] Small frames and phones: text stays >= 85% size, the panels wrap and the page scrolls
- [x] Web export (2D lean template): `..\exports\water-balance\`, checked in headless Chromium (7 checks)
- [ ] Classroom try-out on Chromebooks
- [x] Put on sims.mr-miner.com (published 2026-10-14; also sfminer.github.io/water-balance)
- [x] Teacher guide and student worksheet (`docs/`, built by `docs/make_worksheet.py`)

Not included (from the full design, `The Runner's Water Balance — version 1.1.md`): guided investigations,
A/B pairs beyond one kept run, causal flowchart, token snapshot, sentence frames, Investigate/Explain settings.

### Model results (end of the race, illustrative mEq/L)
| Race | Pace | None | Medium | Lots of water | Lots of sports drink |
|---|---|---|---|---|---|
| 4 h | Stop | 143 | 136 | 113 | 122 |
| 4 h | Run | 164 | 139 | 125 | 132 |
| 6 h | Stop | 145 | 135 | collapses at 4.6 h (110) | 118 |
| 6 h | Run | collapses at 5.0 h (170) | 139 | 121 | 132 |
| 8 h | Stop | 146 | 135 | collapses at 4.6 h (110) | collapses at 6.2 h (too much blood water) |
| 8 h | Run | collapses at 5.0 h (170) | 138 | 117 | 132 |

Model 0.5.0 (2026-10-14): the 0.3.0 tuning with only the screen's options; Stop is resting and sweats 1/8 as fast
as Run (0.001). The kidneys save salt when the blood is dilute (urine salt falls to zero by about 133 mEq/L), so
Run + Lots of water for 8 hours keeps 88% of the blood's starting water instead of 59%. Lots is 0.021 (was 0.018) so
that run still passes the lesson's 120 mEq/L (117 at 8 h) without collapsing. At Medium, ADH falls and the kidneys remove the resting runner's extra water, so she ends at the
bottom of the normal range. Lots is more than sweat plus the kidneys' maximum can remove: ADH reaches zero and the
blood still dilutes, most when she stops (she sweats least). Sweat is about 0.3 times as salty as blood, so the
runner loses more salt than the resting runner but keeps saltier blood. A sports drink raises the Lots values a
little but does not prevent the drop. (0.2.0 had a weak ADH response: Walk + Medium fell to 128 with ADH "medium".)

## Tests
From `water_balance/` (bash):

```bash
GODOT=../../../Godot_v4.5-stable_win64.exe bash tests/run_all_tests.sh
```

Suites: `run_model_tests` (93 checks, 12 scenarios), `run_controller_tests` (31), `run_ui_tests` (62: drink type, collapse,
the anchor endpoints, ADH feedback and sweat salt, the tally, keyboard exit, Space, toggles, kept run). `run_refinement_tests` is the slower step-size study.
Screenshot (windowed, optional `WB_PACE=0..1`): `WB_T=40 WB_OUT=<png> ../../../Godot_v4.5-stable_win64.exe --path . --resolution 1280x720 --script res://tools/screenshot.gd`.

## Export
`python ..\..\..\godot-2d-web-template\check_web_template.py water_balance` reports the GUI template only because
the old prototype in `views/` uses OptionButton; `views/` and `preview.tscn` are excluded from the export, so the
preset uses the 2D template. Export: `Godot --headless --path water_balance --export-release "Web" ../../exports/water-balance/index.html`.
