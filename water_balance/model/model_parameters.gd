# === HEADER COMMENT ===
# Provisional teaching-model quantities; these are not clinical measurements.
class_name ModelParameters
extends Resource

# === EXPORTS ===
@export var initial_w_out: float = 1.0
@export var initial_s_out: float = 1.0
@export var initial_w_in: float = 2.0
@export var initial_s_in: float = 2.0
@export var dt: float = 0.02
@export var duration: float = 60.0
@export var absorption_tau: float = 3.0
@export var sweat_fraction: float = 0.3
@export var urine_fraction: float = 0.2
# Kidneys save salt when the blood is dilute (an aldosterone stand-in, 0.5.0): urine salt falls from urine_fraction
# toward zero as the outside concentration drops, reaching zero at 1 - 1 / urine_salt_gain. It never rises above it.
@export var urine_salt_gain: float = 20.0
@export var k: float = 0.08
# ADH falls to about half within ~3.5% dilution, so healthy kidneys clear a moderate surplus (0.3.0).
@export var g_c: float = 14.0
@export var g_w: float = 0.5
@export var tau_h: float = 5.0
@export var u_min: float = 0.0002
@export var u_base: float = 0.001
@export var u_max: float = 0.012
# Rates tuned 2026-10-10 (0.3.0) so 140 x outside concentration (the screen's illustrative mEq/L) ends a 4-hour
# race near Run 164 / 139 / 127 for None / Medium / Lots of water. Lots is more than sweat plus the kidneys'
# maximum can remove, so ADH reaches zero and the blood still dilutes. 0.4.0 (2026-10-14) keeps only the options
# the screen offers: drinking None / Medium / Lots, activity Stop / Run. Stop is resting, sweating 1/8 as fast as Run.
# 0.5.0 (2026-10-14): kidneys save salt when the blood is dilute, so Lots no longer shrinks the blood to about 60%;
# Lots rose from 0.018 to 0.021 so Run + Lots of water still reaches the lesson's 120 mEq/L (in an 8-hour race).
@export var drinking_rates: Array[float] = [0.0, 0.007, 0.021]
@export var sweat_rates: Array[float] = [0.001, 0.008]
# Solute per unit of drink water, relative to the starting outside concentration: water, sports drink.
# A sports drink carries roughly 20 mEq/L sodium against about 140 in plasma, so about 0.15.
@export var drink_solute: Array[float] = [0.0, 0.15]
@export var min_water_fraction: float = 0.25
@export var min_concentration: float = 0.5
@export var max_concentration: float = 1.5
@export var min_volume_ratio: float = 0.65
@export var max_volume_ratio: float = 1.4
# The runner collapses (the race stops) when the blood holds too little or too much water, or its sodium leaves
# 110-170 on the screen's illustrative mEq/L scale (140 x concentration). Classroom stops chosen by Sean (2026-10-14)
# so extreme runs end instead of showing unsurvivable values; they are not clinical thresholds. 110 keeps the
# lesson's 120 reachable.
@export var collapse_min_blood_water: float = 0.65
@export var collapse_max_blood_water: float = 1.5
@export var collapse_min_concentration: float = 110.0 / 140.0
@export var collapse_max_concentration: float = 170.0 / 140.0
@export var model_version: String = "water-balance-0.5.0-provisional"

# === PUBLIC METHODS ===
func to_dictionary() -> Dictionary:
	var result: Dictionary = {}
	for property: Dictionary in get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			result[String(property.name)] = get(property.name)
	return result.duplicate(true)

func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	var values: Dictionary = to_dictionary()
	for key: String in values:
		if values[key] is float and not is_finite(float(values[key])):
			errors.append(key + " must be finite")
	for key: String in ["initial_w_out", "initial_s_out", "initial_w_in", "initial_s_in", "dt", "duration", "absorption_tau", "tau_h"]:
		if float(values[key]) <= 0.0:
			errors.append(key + " must be positive")
	for key: String in ["k", "g_c", "g_w", "u_min", "urine_salt_gain"]:
		if float(values[key]) < 0.0:
			errors.append(key + " must be nonnegative")
	if u_max <= u_min or u_base < u_min or u_base > u_max:
		errors.append("Urine bounds require u_min <= u_base <= u_max and u_min < u_max")
	if sweat_fraction < 0.0 or sweat_fraction > 1.0 or urine_fraction < 0.0 or urine_fraction > 1.0:
		errors.append("Output solute fractions must be between zero and one")
	if drinking_rates.size() != 3 or sweat_rates.size() != 2:
		errors.append("Expected three drinking rates and two sweat rates")
	if drink_solute.is_empty():
		errors.append("Expected at least one drink type")
	for amount: float in drink_solute:
		if not is_finite(amount) or amount < 0.0:
			errors.append("Drink solute amounts must be finite and nonnegative")
	for rates: Array[float] in [drinking_rates, sweat_rates]:
		for rate: float in rates:
			if not is_finite(rate) or rate < 0.0:
				errors.append("Control rates must be finite and nonnegative")
	if min_water_fraction <= 0.0 or min_water_fraction >= 1.0:
		errors.append("Minimum water fraction must lie strictly between zero and one")
	if min_concentration <= 0.0 or max_concentration <= min_concentration:
		errors.append("Concentration bounds must be positive and ordered")
	if min_volume_ratio <= 0.0 or min_volume_ratio >= 1.0 or max_volume_ratio <= 1.0:
		errors.append("Volume bounds must surround the initial ratio of one")
	if initial_w_out > 0.0 and initial_w_in > 0.0:
		for concentration: float in [initial_s_out / initial_w_out, initial_s_in / initial_w_in]:
			if concentration <= min_concentration or concentration >= max_concentration:
				errors.append("Initial concentrations must be inside the model boundaries")
	if collapse_min_blood_water <= 0.0 or collapse_min_blood_water >= 1.0 or collapse_max_blood_water <= 1.0:
		errors.append("Collapse water limits must surround the starting blood water")
	if collapse_min_concentration >= 1.0 or collapse_max_concentration <= 1.0:
		errors.append("Collapse concentration limits must surround the starting concentration")
	if model_version.strip_edges().is_empty():
		errors.append("A model version is required")
	return errors
