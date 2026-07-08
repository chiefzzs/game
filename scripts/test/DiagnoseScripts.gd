extends Node
func _ready() -> void:
	var paths: Array[String] = [
		"res://scripts/config/CharacterEnums.gd",
		"res://scripts/editor/CharacterBase.gd",
		"res://scripts/characters/PlayerBase.gd",
		"res://scripts/characters/CompanionBase.gd",
		"res://scripts/characters/EnemyBase.gd",
		"res://scripts/characters/FarmerPlayer.gd",
		"res://scripts/characters/AxemanCompanion.gd",
		"res://scripts/characters/HunterCompanion.gd",
		"res://scripts/characters/ShepherdCompanion.gd",
		"res://scripts/characters/WalkSoldierEnemy.gd",
		"res://scripts/characters/JumpScoutEnemy.gd",
		"res://scripts/characters/DummyEnemy.gd",
		"res://scripts/ui/CombatHUDController.gd",
		"res://scripts/systems/PickupItem.gd",
		"res://scripts/combat/CombatDamageCalculator.gd",
		"res://scripts/test/V03a_SmokeTest.gd",
		"res://scripts/test/V03b_DamageTest.gd",
		"res://scenes/test/V03b_DamageDemo.gd",
		"res://scenes/main_menu/MainMenu.gd",
	]
	print("[Diagnose] Reloading ", paths.size(), " scripts:")
	for p in paths:
		var scr = load(p)
		if scr == null:
			print("  LOAD_FAIL: ", p)
			continue
		var gdscr: GDScript = scr
		var rc: Error = gdscr.reload()
		var s: String = "OK" if rc == OK else "ERR_%d" % int(rc)
		print("  [", s, "] ", p)
	print("[Diagnose] done.")
	get_tree().quit()
