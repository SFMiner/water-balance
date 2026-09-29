# The Runner’s Water Balance — Implementation Plan

Based on **The Runner’s Water Balance — version 1.1.md**. Prepared September 29, 2026.

## Outcome and scope

Build a browser-based investigation simulator that connects water intake and loss to outside-cell concentration, delayed ADH regulation, osmosis, and cell size. Students compare runs and explain evidence during a 15–25-minute activity.

The GDD is the source of truth. Its equations and rates are provisional teaching-model choices. This plan does not claim that their behavior has been validated or that its curriculum references have been independently verified.

The current folder contains the GDD but no project configuration or implementation files at its top level. The existing osmosis project described in the GDD has not been inspected. Confirm its location before implementation; do not assume this folder is that project or silently create a replacement. Preserve existing osmosis and red-blood-cell behavior.

**Prototype milestone:** A validated model connected to one cell, controls, two graphs, and saved A/B comparisons. This supports internal investigation and tuning, but is not the complete first release.

**First release:** All five investigations, Free Explore, delayed ADH feedback, classroom representations, vocabulary and sentence frames, Investigate/Explain settings, sourced medical-data card, and verified Chromebook operation.

**Deferred:** Calibrated sodium simulation, sports drinks, adjustable salts, detailed nephron physiology, disease modes, weather, individual differences, fish simulation, persistent saves, downloads, accounts, analytics, and dashboards. Audio is unnecessary. Add time acceleration only if pacing tests justify it.

## Architecture and ownership

Use the host project's compatible Godot version and Compatibility renderer after inspection. Do not upgrade the engine or select new dependencies during planning. Use typed GDScript, tabs, and signals between controls and the controller.

| Component | Responsibility |
|---|---|
| `WaterBalanceModel` | Scientific state, fixed-step transfers, absorption, ADH, conservation ledger, limits; independently testable and independent of scene nodes |
| `ModelParameters` | Initial quantities, rates, gains, tolerances, model duration, and model/version identifier |
| `SimulationController` | Clock, run lifecycle, validated control changes, sampling, and snapshot delivery |
| `SessionRuns` | Immutable A/B records for the page session; survives leaving and returning to this view |
| `InvestigationDefinition` | Question, defaults, editable controls, comparison variable, prediction and evidence prompts |
| `ObservationPresenter` | Trend descriptions, current-cell tonicity, capacity observations, and explanation visibility |
| View components | Body diagram, cell, controls, graphs, causal flowchart, tokens, medical card; consume snapshots without changing scientific state |

Suggested feature-local layout, adapted to the host project’s conventions during Phase 0:

```text
water_balance/
	model/          # State, parameters, solver, snapshots, ledger
	controllers/    # Run lifecycle and observations
	data/           # Investigations, parameters, curriculum-card metadata
	views/          # Dedicated scene and visual components
	assets/         # Diagram icons and symbols
	tests/          # Numerical, lifecycle, and scenario checks
```

Keep the model scene-local. Prefer a session owner in the existing persistent application shell for saved runs; if scene replacement removes that shell, introduce one narrowly scoped session AutoLoad. No other new global managers are needed.

Each saved record contains initial state, full parameter snapshot and model version, scenario, initial controls, prediction, samples, timestamped control events, and endpoint reason/time. Samples retain compartment quantities, concentrations, actual volume ratio, H, urine output, and ledger values needed by evidence views. Copy records deeply when saving; renderers must not mutate them. Store curriculum edition/source separately from model records.

## Phase 0 — Confirm integration and contracts

**Estimate:** 0.5–1 working day. **Dependency:** access to the intended host project. **Milestone:** implementation prerequisites settled.

1. Confirm project location, installed and declared engine versions, renderer, viewport, scene navigation, export settings, and project instructions.
2. Inspect the existing cell drawing, amplified radius, particle boundary, concentration inputs, and rupture behavior. Reuse rendering only if it can accept continuous snapshots without original-mode scientific logic.
3. Establish the feature entry/return path and session owner. Record the existing modes’ smoke-test behavior before changes.
4. Define model and snapshot interfaces, run states (`READY`, `RUNNING`, `PAUSED`, `FINISHED`, `MODEL_LIMIT`), and proposed numerical tolerances. Inventory school device/browser and teaching-edition information for later verification.

**Completion gate:** Project opens and produces an initial web build; integration points are identified; old modes have a regression checklist. If the existing project is unavailable, numerical prototype design can proceed, but integration remains explicitly unresolved.

## Phase 1 — Implement and validate the numerical model

**Estimate:** 2–4 working days. **Dependency:** Phase 0 model contracts. **Milestone:** scientific foundation.

1. Implement initial stores `(W_out, S_out, W_in, S_in) = (1, 1, 2, 2)`, derived concentrations, actual cell volume, and cumulative external-transfer ledgers.
2. Implement drinking absorption, activity-dependent sweat, automatic ADH, fixed urine output, and equal-and-opposite osmosis at `dt = 0.02`.
3. Implement donor limits, overshoot protection, finite-value checks, endpoint detection, and deterministic reset.
4. Add focused headless tests and a scenario sweep covering the 24 activity/drinking/kidney combinations. Record trajectories and tune parameters before writing scenario claims.

### Numerical contract

Use a documented update order: evaluate controls for the step; update absorption and apply absorbed water; remove sweat; recompute concentrations and update H; calculate automatic or fixed urine output and remove urine; recompute concentrations; calculate and apply osmosis; derive observations and record the state. Use available material for every external transfer and record actual transferred quantities. Validate this order with the scientific review rather than relying on incidental scene execution order.

Represent absorption as a pending-water store with a three-unit first-order time constant and zero initial pending water. Track consumed water and absorbed water separately. This makes delayed water explicit: consumed water equals absorbed water plus pending water. Body-water conservation uses absorbed water as input. Confirm that this smooth lag produces the GDD’s intended classroom behavior.

For each output, compute the proposed water and solute removal together; scale both by the same availability factor if necessary. For osmosis, limit proposed transfer by donor availability and the amount that would equalize current concentrations. Do not independently clamp compartment values or silently correct ledger errors.

Use the GDD's H target and exponential lag, with H initialized at the derived H_base. Fixed mode keeps urine at U_base while allowing H to respond; the view will mark the disconnected kidney response. Reject invalid parameter configurations such as U_max ≤ U_min.

Detect the earliest configured model boundary encountered by the solver. If a step crosses a boundary, locate and accept the boundary state using a bounded fractional-step search from the last valid state, conserving all accepted transfers; then stop. Do not continue with a visually clamped compartment. Handle the duration endpoint exactly as well.

Test these identities with a documented floating-point tolerance, initially targeting `1e-8` absolute error over a standard run:

- Body water = initial body water + absorbed water − sweat water − urine water.
- Body solute = initial body solute − sweat solute − urine solute.
- Intracellular solute remains fixed; internal water transfers cancel exactly within tolerance.

**Completion gate:** Equal concentrations produce zero net osmosis; direction and transfer conservation are correct; all standard scenarios remain finite with valid stores; feedback respects bounds and delays; identical inputs repeat. Find shrinking, swelling, compensation, and persistent-imbalance examples before declaring model validation complete. Do not force rest/no-drinking to remain perfectly stable.

## Phase 2 — Build the live simulation view

**Estimate:** 2–3 working days. **Dependency:** Phase 1 validated snapshots. **Milestone:** observable prototype.

1. Add the dedicated scene: top navigation, body-flow diagram, outside-fluid reservoir, magnified cell, observation text, and bottom controls.
2. Connect Rest/Jog/Run and None/Low/Medium/High controls, Run/Pause, Restart, optional prediction, and Free Explore events to the controller.
3. Draw the brain/pituitary → ADH → kidney signal separately from water and solute flows. Implement the signal meter and held-fixed label. Decorative message animation may follow after the meter is verified.
4. Implement current-cell tonicity and net-flow labels with documented tolerances, accessible definitions, reduced motion, and optional numerical Details.

Derive radius from the cube root of actual volume ratio, then apply the existing 2× radius amplification around the starting radius. Use that same displayed radius for membrane and particle containment. Keep the neutral outline and “Size changes exaggerated” label visible. No rupture behavior belongs in this view.

All model and animation progression shares the controller's pause state. Opening tokens pauses the run. Navigation back into Water Balance starts a neutral paused run. Restart resets H, pending absorption, ledgers, traces, events, prediction/live observations, and time while retaining selected controls and saved A/B records. Changing investigation restores its defaults and a neutral paused run while retaining A/B.

When the browser tab is hidden, pause explicitly; do not simulate a large catch-up interval on return. Ordinary frame-rate variation is handled by a fixed-step accumulator.

**Completion gate:** Visuals match recorded state, pause freezes every moving representation, reset is reproducible, keyboard focus is visible, and old simulation modes still work.

## Phase 3 — Add traces and reproducible A/B comparisons

**Estimate:** 1.5–3 working days. **Dependency:** Phase 2 lifecycle and Phase 1 model. **Milestone:** internal investigation MVP.

1. Add the two time-aligned plots for relative outside concentration and actual cell volume, each with its starting-value line.
2. Record samples every 0.25 model-time units, including initial and terminal states; retain H and urine output for inspection and flowcharts.
3. Add Keep A/B, Compare, and Clear comparisons, with immutable session records and explicit labels for settings, predictions, events, and model version.
4. Show distinct line styles and shared axes; preserve a shorter run’s endpoint without extrapolating its curve. Make saved-slot replacement deliberate and visibly identify the replacement.

The 0.25 sampling interval is not an integer multiple of 0.02. Sample at exact requested timestamps by interpolating adjacent fixed-step states for display/recording, clearly treating these as observations, not new solver states. Calculate concentrations from interpolated stores rather than independently interpolating derived ratios. Store exact terminal snapshots without duplicates. Validate sampling at 30 and 60 FPS.

**Completion gate:** Two runs can be kept, restarted, overlaid, and inspected without changing the saved data; live control changes have model-time timestamps; returning between modes preserves A/B and refresh clears them. This milestone is suitable for internal tuning, not yet classroom release.

## Phase 4 — Author the five investigations and feedback evidence

**Estimate:** 1.5–3 working days. **Dependency:** Phase 3 plus validated scenario sweep.

| Investigation | Implementation and validation |
|---|---|
| Where does cell water go? | Same activity with None/Low drinking; show a validated outward-water/shrinking comparison |
| Can added water change a cell? | Same activity with Low/High drinking; show dilution and inward net movement |
| What do the kidneys change? | Identical activity/intake with Automatic/Fixed output; expose H, delayed response, and differing trajectories |
| When can feedback compensate? | Run activity with None/intermediate/High intake across successive A/B pairs; explain how to retain an observation before replacing a slot |
| Explain the runner | Student-selected pair, separate curriculum evidence, and a supported causal explanation |

Make every investigation available immediately. Guided controls remain fixed after a run starts, including after pausing; restart allows setting the next comparison. Kidney mode is exposed only in its investigation and Free Explore. Explain the runner allows selecting conditions before each run.

Define compensation operationally for validation: an initial disturbance followed by a sustained reduction in concentration error and flattening of the late-run trajectory. Define persistent imbalance as sustained drift despite the regulatory response. Select documented observation windows and slope/error tolerances from prototype results; these are model-analysis criteria, not clinical categories. Do not require endpoint contact or label Medium intake universally balanced.

Add incomplete disturbance → detected change → ADH → kidney response → resulting conditions flowcharts with a feedback return arrow. Saved-run flowcharts derive from that run’s samples. Investigate retains observations and vocabulary but withholds completed causal links and case conclusions; Explain reveals them. Changing presentation never changes the model.

**Completion gate:** Each investigation has a reproducible evidence pair and a clear one-variable comparison; at least one shows compensation and one persistent imbalance without relying on a model boundary.

## Phase 5 — Complete classroom representations and source review

**Estimate:** 2–3 working days. **Dependency:** Phase 4 evidence contracts; teaching materials for final source approval.

1. Add independently selectable sentence frames, word bank, prediction supports, and text observations. Introduce representations one at a time through graph/flowchart/token views.
2. Implement a paused token snapshot with labeled compartments, a consistent within-snapshot key, rounded quantities, and a readily hand-copied compartment outline. Treat the proposed 15-water/10-solute starter preset as configurable and unconfirmed.
3. Preserve discrete conservation in illustrated token transfers by moving tokens between represented compartments and explicit source/sink areas. Choose initial rounded counts once for a sequence; track residual fractions rather than independently re-rounding each panel. Always show that tokens approximate the untouched exact model state.
4. Build the separate curriculum-data card with source title, edition, URL, verification status, and the supplied reference band. Verify the teaching edition before release; add case values only from verified materials. The GDD-permitted printed-data workflow is acceptable if digital case values are unavailable.
5. Review all biological wording and Investigate/Explain visibility, including Help, tooltips, badges, saved-run summaries, and flowcharts. Confirm exact curriculum wording and flowchart conventions before attributing them.

Keep simulated units relative, model time separate from real exercise time, and generic solute separate from sodium. Do not label a cell-volume band healthy, the fixed-output experiment kidney failure, or model endpoints injury thresholds. Do not infer urine color or chemistry from the bookkeeping fraction.

**Completion gate:** Tokens conserve their represented transfers, approximation is disclosed, all supports work in both presentation settings, and sourced curriculum evidence is visually distinct from generated data.

## Phase 6 — Validate the exported classroom release

**Estimate:** 2–4 working days, plus scheduling a classroom pilot. **Dependency:** Phases 0–5.

1. Run focused numerical regression tests after final parameter tuning. Record parameter/model version and evidence traces; invalidate or clearly separate saved records from incompatible model versions.
2. Test the exported build on a representative school Chromebook: target at least 30 FPS, resizing, touchpad/touch, visible keyboard focus, controls at least 44 pixels high, and Space behavior while controls consume keyboard input.
3. Test screen-reader behavior directly. If essential controls or observations are inaccessible through the canvas, document the gap and provide an accessible equivalent interaction/readout before describing the release as screen-reader accessible.
4. Cap decorative particles, avoid per-particle physics, and check graph/trace performance over repeated restarts and comparisons. Verify hidden-tab pause and reentry behavior.
5. Pilot the activity within 15–25 minutes. Observe whether students can explain input → concentration → osmosis → size with two pieces of evidence and name a simplification. Record difficulties and revise prompts before defining a quantitative learning target.

Only add common 1×/2×/4× speed controls or extend duration if pacing/evidence tests call for it. Speed changes execute more fixed steps, retain model-time axes, and apply consistently across comparisons. Revalidate scenarios after any duration change.

**Release gate:** All GDD acceptance criteria have evidence, no critical numerical or navigation failures remain, old modes pass regression checks, target-device operation is verified, and pilot issues have been addressed. Prepare the web export and brief teacher guidance; choose hosting and publish only as a separately authorized implementation step.

## Dependencies, estimates, and review points

**Critical path:** host/project contracts → numerical validation → live lifecycle → saved comparisons → validated investigations → classroom supports/source review → exported-device testing and pilot.

Work that can overlap without changing that dependency chain includes diagram/icon preparation, responsive layout mockups, curriculum-edition verification, teacher wording review, and target-device arrangements. This is a scheduling option, not an instruction to start parallel agents.

Estimated effort is **11.5–21 working days**, plus access and classroom-pilot scheduling. These are planning ranges for implementation, debugging, and review, not calendar commitments. Model retuning, unsuitable legacy cell coupling, or browser accessibility remediation can increase them.

Review the work at four useful points:

1. **After Phase 0:** integration path and reuse decision.
2. **After Phase 1:** conservation report, scenario traces, and numerical assumptions.
3. **After Phase 3:** usable evidence-comparison prototype.
4. **Before release:** sourced teaching content, accessibility findings, and classroom observations.

## Decisions to resolve during implementation

| Decision | Default or next action | Blocks |
|---|---|---|
| Host project and compatible engine | Locate with Sean; inspect project and installed engine | Integration, not independent numerical design |
| Cell-renderer reuse | Reuse only rendering with compatible radius/particle contracts | Phase 2 integration |
| Numerical gains and scenario defaults | Start with GDD values; tune against conservation and evidence gates | Scenario claims |
| Model tolerances and boundary handling | Document and test Phase 1 proposals | Scientific model acceptance |
| Curriculum edition and case data | Verify teacher materials; allow printed case-data comparison | Final medical card/content approval |
| Token arrangement and flowchart conventions | Configurable defaults; confirm with classroom materials | Final classroom representation review |
| School device and browser | Arrange representative exported-build testing | Release performance/accessibility claim |
| Duration or acceleration | Keep 60 units at 1× unless pacing tests justify change | Final scenario/pacing sign-off |

## Acceptance coverage

| GDD requirement group | Evidence produced |
|---|---|
| Conservation, osmosis, valid stores, limits | Phase 1 unit/invariant tests and scenario sweep; Phase 6 regression |
| Shrinking/swelling, ADH direction/delay, compensation/imbalance | Phase 1 traces and Phase 4 reproducible comparisons |
| Tonicity, amplified cell geometry, accurate observations | Phase 2 snapshot-to-view checks |
| Repeatability, pause/reset, immutable comparisons | Phase 2 lifecycle checks and Phase 3 replay/sampling checks |
| Sodium/source distinction and instructional visibility | Phase 5 content/source and presentation review |
| Token conservation and language supports | Phase 5 representation review |
| Chromebook, keyboard, resizing, performance | Phase 6 exported-device testing |
| Evidence-based student explanation and limitations | Phase 6 classroom pilot notes |

The next implementation deliverable should be Phase 0’s integration record and Phase 1’s numerical prototype—not a polished animated scene.
