@tool
extends EditorScript
## V0.3 scripts/test/Phase1ExistenceChecker.gd — Phase1存在性检查（41文件）
## 与验收runner共用逻辑，可在编辑器/headless中分别运行

class_name Phase1ExistenceChecker

var SCRIPT_LIST: Array[String] = [
	"res://autoload/InputBus.gd",
	"res://autoload/GameEvents.gd",
	"res://autoload/ConfigManager.gd",
	"res://autoload/SaveSlotManager.gd",
	"res://autoload/LevelFlowController.gd",
	"res://autoload/PickupSystem.gd",
	"res://autoload/AudioBus.gd",
	"res://scripts/editor/MapSchemaValidatorHeadless.gd",
	"res://scripts/editor/SmokeTestMapIO.gd",
	"res://scripts/editor/CharacterBase.gd",
	"res://scripts/editor/MapLoader.gd",
	"res://scripts/combat/CombatDamageCalculator.gd",
	"res://scripts/characters/PlayerBase.gd",
	"res://scripts/characters/FarmerPlayer.gd",
	"res://scripts/characters/CompanionBase.gd",
	"res://scripts/characters/AxemanCompanion.gd",
	"res://scripts/characters/HunterCompanion.gd",
	"res://scripts/characters/ShepherdCompanion.gd",
	"res://scripts/characters/EnemyBase.gd",
	"res://scripts/characters/WalkSoldierEnemy.gd",
	"res://scripts/characters/JumpScoutEnemy.gd",
	"res://scripts/characters/DummyEnemy.gd",
	"res://scripts/characters/ProjectileArrow.gd",
	"res://scripts/systems/PickupSystem.gd",
	"res://scripts/systems/PickupItem.gd",
	"res://scripts/ui/CombatHUDController.gd",
	"res://scripts/test/Phase1ExistenceChecker.gd",
	"res://scripts/test/HeadlessSmokeTestRunner.gd",
	"res://scripts/test/CombatDamageSmokeTest.gd",
	"res://scripts/test/FSMBasicSmokeTest.gd"
]

var SCENE_LIST: Array[String] = [
	"res://scenes/characters/PlayerFarmer.tscn",
	"res://scenes/characters/CompanionAxeman.tscn",
	"res://scenes/characters/CompanionHunter.tscn",
	"res://scenes/characters/CompanionShepherd.tscn",
	"res://scenes/characters/EnemyWalkSoldier.tscn",
	"res://scenes/characters/EnemyJumpScout.tscn",
	"res://scenes/characters/EnemyDummy.tscn",
	"res://scenes/characters/ProjectileArrow.tscn",
	"res://scenes/characters/CombatHUD.tscn",
	"res://scenes/characters/GoldPickup.tscn",
	"res://scenes/test/Level1Intro.tscn",
	"res://scenes/test/CombatArena.tscn"
]

var CONFIG_LIST: Array[String] = [
	"res://config/L1_constants/constants.json",
	"res://config/L2_balance/player.json",
	"res://config/L2_balance/companions.json",
	"res://config/L2_balance/enemies.json",
	"res://config/L2_balance/combat_formula.json",
	"res://config/L2_balance/pickups.json",
	"res://config/L3_levels/level_1_intro.json",
	"res://config/L3_levels/level_2_forest_edge.json"
]

var errors: Array[String] = []
var passed: Array[String] = []

func run() -> Dictionary:
	errors.clear(); passed.clear()
	_check_files("SCRIPT", SCRIPT_LIST)
	_check_files("SCENE",  SCENE_LIST)
	_check_files("CONFIG", CONFIG_LIST)
	_check_file("PROJECT", "res://project.godot")
	var total: int = SCRIPT_LIST.size() + SCENE_LIST.size() + CONFIG_LIST.size() + 1
	var result: Dictionary = {
		"total_expect": total,
		"pass_count": passed.size(),
		"fail_count": errors.size(),
		"passed": passed.duplicate(),
		"failed": errors.duplicate(),
		"ok": errors.is_empty()
	}
	return result

func _check_files(tag: String, arr: Array[String]) -> void:
	for f in arr: _check_file(tag, f)

func _check_file(tag: String, path: String) -> void:
	if ResourceLoader.exists(path) or FileAccess.file_exists(path):
		passed.append(tag + ":OK " + path)
	else:
		errors.append(tag + ":MISSING " + path)

func _run() -> void:
	var r: Dictionary = run()
	if r.ok:
		print("[Phase1] PASS %d/%d — all expected files present" % [r.pass_count, r.total_expect])
	else:
		push_error("[Phase1] FAIL %d/%d — missing files:" % [r.fail_count, r.total_expect])
		for e in errors: push_error("   " + e)
