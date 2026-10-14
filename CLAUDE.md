# CLAUDE.md

This file is the single copy of the project conventions; AGENTS.md only points here.

# The Runner’s Water Balance — Project Context

## Current direction (Sean, 2026-10-10)
- The classroom version is a **focused one-screen model of the Marathon Runner anchor phenomenon**, not the whole 5E
  lesson or the full design document: `water_balance/` is a standalone game for sims.mr-miner.com (not an osmosis mode).
  Its features and tests are in `README.md`. Sean chose an **illustrative mEq/L sodium gauge** (140 x blood concentration,
  normal band 135-145 from the 5E Evaluate phase) and a **water / sports drink choice**; these override the older "no clinical
  sodium output" and "sports drinks deferred" lines below. The runner's own Medical Tent values are not in the files we have:
  never invent them; students use their printed data.
- UI is built in code in `ui/` (`main_view.gd` owns the controller and drives time; views only read snapshots). Toggle
  buttons, not OptionButtons, so the 2D web template works. Tab order is the list at the end of `MainView._build()`; changing
  it means updating `EXPECTED_STOPS` in `tests/run_ui_tests.gd`. Model 0.5.0 (ADH gain, rates, drink solute, kidney salt saving; options Stop/Run and None/Medium/Lots) is in `ModelParameters`.
- No cell diagram or cell-size graph: Sean has a separate osmosis/cell-size sim (2026-10-14). The body pane keeps
  the diagram on the left and its numbers, in % of the blood's starting amounts, on the right.
- `views/` and `preview.tscn` are the older prototype, kept but excluded from the export.

## Purpose and authority
- Build the middle-school investigation simulator described by `The Runner’s Water Balance — version 1.1.md` and `IMPLEMENTATION_PLAN.md` in this directory. The original documents are authoritative; Manus suggestion copies are review inputs, not specifications.
- Teach water/solute amount versus concentration, osmosis, and delayed, limited ADH feedback through reproducible comparisons. Support student explanation rather than scoring or diagnosing.
- User instructions override generic pipeline defaults. Do not commit, push, install tools, or publish without Sean's request.

## Implementation conventions
- Typed GDScript with tabs, reusable model classes, and signals between controller and views. Keep scientific equations independent of scene nodes and rendering.
- Start with numerical validation before animation. Use installed Godot 4.5 for isolated model checks; confirm the host project's version before integration. Compatibility renderer is the target; do not upgrade an existing project implicitly.
- Model parameters and scientific changes require a model version; content/UI changes have separate revisions. Preserve source edition metadata independently.
- Keep changes scoped to this project. Ask before searching other directories for the existing osmosis project. Do not replace or alter its original osmosis/RBC modes without inspecting their contracts.

## Architecture
- `water_balance/model/`: parameters, compartment state, transfer solver, ledger, snapshots.
- `water_balance/tests/`: headless numerical tests and reproducible scenario validation.
- Later: controller, session-only A/B records, data-driven investigations, and code-built views. No AutoLoads yet; choose session ownership after host integration is confirmed.
- `water_balance/project.godot` is now the game itself (main scene `scenes/main.tscn`).

## Scientific invariants
- Outside/intracellular initial water and solute are 1/1 and 2/2. Intracellular solute stays fixed. Every external transfer enters a ledger; osmosis transfers equal and opposite water amounts.
- ADH is a dimensionless signal, not calibrated hormone concentration. Fixed urine output is an experimental comparison, not kidney failure.
- Fixed 0.02 model-time steps; provisional parameters remain hypotheses until validated. Absorption tracks pending water. Clamp transfers by available material, never silently clamp stores or manufacture solute.
- Model boundaries are software limits, not injury thresholds, except the collapse stops (blood water 65-150%, sodium
  110-170 mEq/L) Sean asked for on 2026-10-14 so extreme runs end; keep the lesson's 120 mEq/L reachable while running
  (8 h Run + Lots). No rupture, clinical sodium output, universal drinking recommendation, or invented medical case data.
- Visual interpolation and exaggerated radius must never change scientific state or graph volume.

## Interaction and instruction
- Predictions remain optional. Guided conditions lock after starting; restart restores neutral paused state while retaining selected conditions and saved A/B runs.
- Investigate withholds completed explanations; Explain changes visibility only. Keep supports independently selectable and essential actions accessible.
- Session A/B records are deep-copied and memory-only; refresh clears them. No browser persistence, analytics, accounts, or student health records.
- Tokens approximate model quantities; starter counts remain configurable until classroom materials are confirmed. Use “solute,” not calibrated sodium/salt claims.

## Current phase and limitations
- The classroom screen, web export and browser checks exist (README). Not yet tried on Chromebooks or with students.
- Numerical foundation passes 93 checks over 12 scenarios (model 0.5.0) in Godot 4.5; `VALIDATION_STATUS.md` is the 2026-09-29 report (139 / 24, older options). Phase 1 remains open for step refinement and compensation evidence. Keep model parameters owned by each run and return defensive copies to callers.
- Run focused headless tests after scientific changes; retain machine-readable reports with parameters, scenario IDs, invariant errors, and endpoint evidence. Record integration and testing commands in README as they become available.

## Learning log
- The ADH response is proportional, so before the kidneys max out, a steady surplus dilutes the blood by about
  (base ADH - needed ADH) / g_c. With g_c 2, Walk + Medium settled at 128 mEq/L with ADH still "medium", contradicting
  the feedback the unit teaches (Sean caught it, 2026-10-10); g_c 14 holds a moderate surplus within ~4%. Only drinking
  more than sweat plus u_max should cause hyponatremia, so Lots (0.018) exceeds that at every pace. tau_h barely changes end values.
- Sweat and urine remove salt from the blood (the fluid outside cells) only, so with fixed cell salt the blood shrinks
  as salt leaves even when total water is normal: 8 h Run + Lots ended at 59% of its water (fatal in reality; Sean
  caught it, 2026-10-14). 0.5.0 cuts urine salt as the blood dilutes. Scaling the displayed volume can't fix it without
  breaking the salt tally, and scaling all flows also shrinks the sodium change.
- The gauge shows concentration, not amount: students (and teachers) read "the runner loses more sodium" from a lower
  number. Keep the water/salt tally and "salt / water" line visible whenever sweat salt matters.
- Keep model development independent of legacy cell rendering because finite outside-fluid quantities and continuous concentration cannot be driven through the original eleven-position slider.
- Godot 4.5 can abort before running scripts if its application-data log directory is inaccessible; request the required filesystem permission and inspect the actual engine log as well as the process exit code. A GDScript test function can abort while later tests still run, so a zero failure count alone is insufficient.
