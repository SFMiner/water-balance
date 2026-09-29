# The Runner’s Water Balance

Implementation begins with the independent numerical model described in the GDD and implementation plan. This repository is not yet a playable classroom application.

## Layout

- `AGENTS.md`: project instructions and scientific constraints.
- `water_balance/model/`: finite-compartment water/solute model and parameters.
- `water_balance/tests/run_model_tests.gd`: headless scientific tests and 24-scenario sweep.
- `water_balance/project.godot`: isolated numerical validation harness, not a replacement for the existing osmosis application.

## Run validation

Godot 4.5 is installed on this desktop. From this repository in PowerShell:

```powershell
& 'C:/Users/seanm/Nextcloud2/Gamedev/Godot_v4.5-stable_win64.exe' --headless --path water_balance --script res://tests/run_model_tests.gd | Out-String
```

The runner exits nonzero on assertion failure and writes `water_balance/tests/reports/latest.json`. Also inspect engine output for script errors, which can interrupt a test function independently of the assertion count. Piping to `Out-String` keeps PowerShell attached to the Windows executable until output finishes. Godot needs access to its normal application-data log folder. This generated development report includes parameters, conservation errors, endpoints, and representative one-unit traces. These traces are for numerical inspection; the classroom controller's 0.25-unit sampling is a later implementation step. Generated reports and Godot caches are ignored by Git.

The tests exercise osmosis direction and equilibrium, transfer conservation, delayed ADH, fixed output, pending absorption, reset, detached snapshots, invalid controls/parameters, boundary localization, exact duration termination, and repeatability across all 24 activity/drinking/kidney combinations.

## Integration status

The repository initially contained design documents only. The host osmosis project's location and compatible engine version remain to be confirmed. Numerical validation currently targets the installed Godot 4.5 executable, without modifying any other project or existing simulation mode.

No AutoLoads, classroom UI, assets, persistent saves, web export, or hosting have been added. Provisional parameters must still demonstrate suitable teaching comparisons before scenario wording is finalized. Numerical tests alone do not establish biological calibration, accessibility, or classroom readiness.
