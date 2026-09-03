extends ZoneMap


func _ready() -> void:
	super._ready()
	GameManager.mark_hive_entered()
	hud.set_objective(GameManager.current_objective, GameManager.current_objective_details)
	hud.call_deferred("show_echo", "Biological energy levels exceed previous measurements. Proceed with caution.")

