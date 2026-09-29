# The Runner’s Water Balance — Project Context

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
- No root `project.godot` until host-versus-standalone setup is resolved. An explicitly labeled validation harness may run the independent model.

## Scientific invariants
- Outside/intracellular initial water and solute are 1/1 and 2/2. Intracellular solute stays fixed. Every external transfer enters a ledger; osmosis transfers equal and opposite water amounts.
- ADH is a dimensionless signal, not calibrated hormone concentration. Fixed urine output is an experimental comparison, not kidney failure.
- Fixed 0.02 model-time steps; provisional parameters remain hypotheses until validated. Absorption tracks pending water. Clamp transfers by available material, never silently clamp stores or manufacture solute.
- Model boundaries are software limits, not injury thresholds. No rupture, clinical sodium output, universal drinking recommendation, or invented medical case data.
- Visual interpolation and exaggerated radius must never change scientific state or graph volume.

## Interaction and instruction
- Predictions remain optional. Guided conditions lock after starting; restart restores neutral paused state while retaining selected conditions and saved A/B runs.
- Investigate withholds completed explanations; Explain changes visibility only. Keep supports independently selectable and essential actions accessible.
- Session A/B records are deep-copied and memory-only; refresh clears them. No browser persistence, analytics, accounts, or student health records.
- Tokens approximate model quantities; starter counts remain configurable until classroom materials are confirmed. Use “solute,” not calibrated sodium/salt claims.

## Current phase and limitations
- Phase 0/1: independent numerical foundation. Existing osmosis host location is awaiting confirmation; current repository initially contained documents only.
- Numerical foundation passes 139 checks over 24 scenarios in Godot 4.5; see `VALIDATION_STATUS.md`. Phase 1 remains open for step refinement and compensation evidence. Keep model parameters owned by each run and return defensive copies to callers.
- No classroom UI, assets, web export, target-device validation, or classroom pilot yet. Do not label this a release-ready game.
- The nested `water_balance/project.godot` is a numerical test harness, not a decision to replace the host. Godot MCP tools are configured but no editor was connected; headless validation is available.
- Run focused headless tests after scientific changes; retain machine-readable reports with parameters, scenario IDs, invariant errors, and endpoint evidence. Record integration and testing commands in README as they become available.

## Learning log
- Keep model development independent of legacy cell rendering because finite outside-fluid quantities and continuous concentration cannot be driven through the original eleven-position slider.
- Godot 4.5 can abort before running scripts if its application-data log directory is inaccessible; request the required filesystem permission and inspect the actual engine log as well as the process exit code. A GDScript test function can abort while later tests still run, so a zero failure count alone is insufficient.
