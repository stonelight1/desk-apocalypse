extends RefCounted

static func calculate(
	atk: float,
	attack_multiplier: float,
	crit_rate: float,
	crit_damage: float,
	enemy_def: float,
	random_value: float = -1.0
) -> Dictionary:
	var raw_damage := atk * attack_multiplier
	var roll := randf() if random_value < 0.0 else random_value
	var critical := roll < crit_rate
	if critical:
		raw_damage *= crit_damage

	var defense_multiplier := 100.0 / (100.0 + enemy_def)
	var final_damage := maxi(1, roundi(raw_damage * defense_multiplier))
	return {
		"raw_damage": raw_damage,
		"critical": critical,
		"defense_multiplier": defense_multiplier,
		"final_damage": final_damage,
	}
