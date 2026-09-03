class_name EnemyDropTable
extends Resource

@export_category("Independent Drop Rolls")
@export var item_ids: Array[StringName] = []
@export var drop_chances: Array[float] = []
@export var minimum_amounts: Array[int] = []
@export var maximum_amounts: Array[int] = []


func roll_drops(rng: RandomNumberGenerator = null, chance_multiplier := 1.0) -> Array[Dictionary]:
	var roller := rng
	if roller == null:
		roller = RandomNumberGenerator.new()
		roller.randomize()
	var results: Array[Dictionary] = []
	var entry_count := mini(item_ids.size(), drop_chances.size())
	for index in range(entry_count):
		var chance := clampf(drop_chances[index] * chance_multiplier, 0.0, 1.0)
		if roller.randf() > chance:
			continue
		var minimum: int = maxi(minimum_amounts[index] if index < minimum_amounts.size() else 1, 1)
		var maximum: int = maxi(maximum_amounts[index] if index < maximum_amounts.size() else minimum, minimum)
		results.append({
			"item_id": item_ids[index],
			"amount": roller.randi_range(minimum, maximum),
		})
	return results
