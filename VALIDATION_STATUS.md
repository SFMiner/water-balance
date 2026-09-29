# Numerical foundation — September 29, 2026

The independent GDScript model passes **139 assertions across 24 standard scenarios** under Godot 4.5 stable. The final engine output contains no script or parse errors. A headless editor import also registered the model classes and test script successfully.

Implemented and checked: compartment conservation, osmosis direction and equilibrium limits, delayed ADH and fixed urine output, analytical absorption with pending-water accounting, deterministic replay, detached snapshots and parameter ownership, reset, invalid inputs, fractional duration and boundary endpoints, and overflow rejection preserving the last valid state.

Largest observed ledger error across standard scenarios is approximately **4.21 × 10⁻¹³**, below the configured 10⁻⁸ tolerance. The machine-readable report is generated at `water_balance/tests/reports/latest.json`; regenerate it using the README command.

## Preliminary scenario evidence

All 24 standard combinations reached the 60-unit duration without a model boundary. For Run activity with automatic kidney response:

| Drinking | Final outside concentration | Final cell-volume ratio |
|---|---:|---:|
| None | 1.1712 | 0.8932 |
| Medium | 0.9487 | 1.0335 |
| High | 0.6501 | 1.2810 |

These traces demonstrate shrinking and swelling with conserved quantities. They are relative teaching-model results, not physiological calibration or hydration advice.

**Phase 1 is not yet fully signed off.** Medium drinking initially raises concentration slightly, then crosses the starting value and continues drifting lower. Its final-ten-unit slope is approximately −0.000699 concentration units per model-time unit. Confirm compensation criteria and an appropriate observation window before describing this condition as balanced or using it as the guided compensation example. No tuning has been silently applied to force an intended result.

## Remaining work

- Confirm the existing osmosis host's location/version and integration contracts; this folder initially contained design documents only.
- Complete numerical step-refinement and scenario-meaning validation. Boundary checks occur after each documented transfer stage; fractional bisection assumes a single first crossing as the interval grows. Arbitrary retuning needs dedicated refinement checks before claiming a general earliest-boundary guarantee.
- Build the shared-clock controller, classroom sampling, session comparisons, and views after model/scenario validation.
- Implement and test classroom accessibility, web export, representative Chromebook operation, and classroom pilot.

The nested Godot project is deliberately a numerical harness. No root application project, legacy-mode edits, commits, pushes, or deployment were made.
