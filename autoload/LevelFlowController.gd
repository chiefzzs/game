extends Node
## V0.3 LevelFlowController.gd - 关卡流程FSM
## 状态: BOOT / MAIN_MENU / LOADING / PLAYING / PAUSED / CUTSCENE / GAME_OVER / VICTORY

enum FlowState { BOOT, MAIN_MENU, LOADING, PLAYING, PAUSED, CUTSCENE, GAME_OVER, VICTORY }

var current: FlowState = FlowState.BOOT
var current_chapter_id: int = 0
var current_chapter_key: String = "prologue_farm"
var current_checkpoint: String = ""
var pending_load_path: String = ""
signal state_changed(from: int, to: int)
signal chapter_loaded(chapter_id: int, key: String)
signal game_over(reason: String)
signal victory()

func _ready() -> void:
	change_state(FlowState.BOOT, FlowState.MAIN_MENU)
	if GameEvents:
		GameEvents.player_died.connect(_on_player_died)
		GameEvents.checkpoint_reached.connect(_on_checkpoint)
		GameEvents.chapter_entered.connect(_on_chapter_entered)

func change_state(from: FlowState, to: FlowState) -> void:
	current = to
	emit_signal("state_changed", from, to)

func start_new_game(slot: int) -> void:
	if SaveSlotManager:
		SaveSlotManager.NewGame(slot)
	change_state(current, FlowState.LOADING)
	pending_load_path = "res://scenes/test/V03_CombatArena.tscn"
	change_state(FlowState.LOADING, FlowState.PLAYING)
	current_chapter_id = 0
	current_chapter_key = "prologue_farm"
	emit_signal("chapter_loaded", 0, current_chapter_key)

func load_slot(slot: int) -> void:
	var data := SaveSlotManager.Load(slot)
	if data == null or data.is_empty():
		return
	change_state(current, FlowState.LOADING)
	var pr: Dictionary = data.get("progress", {})
	current_chapter_id = int(pr.get("chapter_id", 0))
	current_chapter_key = String(pr.get("chapter_key", "prologue_farm"))
	current_checkpoint = String(pr.get("checkpoint_key", ""))
	pending_load_path = "res://scenes/test/V03_CombatArena.tscn"
	change_state(FlowState.LOADING, FlowState.PLAYING)
	emit_signal("chapter_loaded", current_chapter_id, current_chapter_key)

func toggle_pause() -> void:
	if current == FlowState.PLAYING:
		change_state(FlowState.PLAYING, FlowState.PAUSED)
		get_tree().paused = true
	elif current == FlowState.PAUSED:
		get_tree().paused = false
		change_state(FlowState.PAUSED, FlowState.PLAYING)

func quit_to_menu() -> void:
	get_tree().paused = false
	change_state(current, FlowState.MAIN_MENU)
	pending_load_path = ""

func _on_player_died(_pos: Vector2) -> void:
	change_state(FlowState.PLAYING, FlowState.GAME_OVER)
	emit_signal("game_over", "player_died")

func _on_checkpoint(key: String, _pos: Vector2) -> void:
	current_checkpoint = key

func _on_chapter_entered(ch_id: int, ch_key: String) -> void:
	current_chapter_id = ch_id
	current_chapter_key = ch_key
