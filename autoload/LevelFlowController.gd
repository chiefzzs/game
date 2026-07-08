extends Node
## V0.2 迭代2 T02-P03：LevelFlowController 关卡内流程状态机（并行开发组）
## 7 状态 FSM：LOADING → INTRO → PLAYING ⇄ PAUSED → OBJECTIVE_COMPLETE → EXITING → (下一关)
##                                    ↘ FAIL_STATE → (重试/回检查点/回主菜单)
##
## 对外接口：
##   - start_level(level_id:String, objectives_json:Array=[])  —— 初始化并加载
##   - pause_game() / resume_game()
##   - trigger_fail(reason:String) / retry_level() / exit_to_menu()
##   - complete_objective(obj_id:String)
##   - get_state() -> String
##
## 信号：
##   state_entered(new_state: String, payload: Dictionary)
##   state_exited(old_state: String)
##   objective_completed(obj_id: String, reward: Dictionary)
##   all_objectives_completed(reward: Dictionary)
##   level_failed(reason: String)
##   level_exit(next_level_id: String, checkpoints: Dictionary)

class_name LevelFlowController
const STATE_LOADING := "LOADING"
const STATE_INTRO := "INTRO"
const STATE_PLAYING := "PLAYING"
const STATE_PAUSED := "PAUSED"
const STATE_OBJECTIVE_COMPLETE := "OBJECTIVE_COMPLETE"
const STATE_FAIL := "FAIL_STATE"
const STATE_EXITING := "EXITING"

signal state_entered(new_state: String, payload: Dictionary)
signal state_exited(old_state: String)
signal objective_completed(obj_id: String, reward: Dictionary)
signal all_objectives_completed(reward: Dictionary)
signal level_failed(reason: String, checkpoint_id: String)
signal level_exit(next_level_id: String, flags_snapshot: Dictionary)

var current_level_id: String = ""
var current_state: String = STATE_LOADING
var last_state_before_pause: String = STATE_PLAYING
var intro_timer: float = 0.0   # 显示新手提示的秒数
var intro_duration: float = 3.0
var checkpoints: Dictionary = {"current": "", "checkpoints": {}}
var objectives: Array = []  # [{id, type, status:"pending|done", data, reward}]
var next_level_id: String = ""
var auto_exit_on_complete: bool = true
var last_fail_reason: String = ""

func _ready() -> void:
	set_process(true)

## -------- 外部驱动 --------
func start_level(level_id: String, objectives_arr: Array = [], next: String = "", intro_sec: float = 3.0) -> void:
	current_level_id = level_id
	intro_duration = max(0.5, intro_sec)
	intro_timer = 0.0
	next_level_id = next
	objectives.clear()
	for o in objectives_arr:
		var obj: Dictionary = o.duplicate(true)
		obj["status"] = "pending"
		objectives.append(obj)
	checkpoints = {"current": "", "checkpoints": {}}
	_change_state(STATE_LOADING, {"level_id": level_id, "objectives_count": objectives.size()})
	# simulate loading: 下一帧进入 INTRO（真实项目：MapLoader 完成后调用 on_map_loaded）
	await get_tree().process_frame
	on_map_loaded()

func on_map_loaded() -> void:
	if current_state != STATE_LOADING:
		return
	_change_state(STATE_INTRO, {"level_id": current_level_id, "duration": intro_duration})

func pause_game() -> void:
	if current_state == STATE_PLAYING:
		last_state_before_pause = STATE_PLAYING
		_change_state(STATE_PAUSED, {})
		get_tree().paused = true

func resume_game() -> void:
	if current_state == STATE_PAUSED:
		get_tree().paused = false
		_change_state(last_state_before_pause, {})

func toggle_pause() -> void:
	if current_state == STATE_PLAYING:
		pause_game()
	elif current_state == STATE_PAUSED:
		resume_game()

func complete_objective(obj_id: String) -> void:
	if current_state == STATE_FAIL or current_state == STATE_EXITING:
		return
	for idx in range(objectives.size()):
		var obj: Dictionary = objectives[idx]
		if obj.get("id", "") == obj_id and obj.get("status", "") != "done":
			obj["status"] = "done"
			var reward: Dictionary = obj.get("reward", {})
			objective_completed.emit(obj_id, reward)
			if ProgressFlags:
				ProgressFlags.Set("obj_done_" + current_level_id + "_" + obj_id)
			break
	# Check all done: if status of root is AND, all must be done; if OR, any done triggers
	if _evaluate_root_done():
		var total_reward := _accumulate_reward()
		all_objectives_completed.emit(total_reward)
		if auto_exit_on_complete:
			await get_tree().create_timer(1.2).timeout
			if current_state != STATE_FAIL and current_state != STATE_EXITING:
				_change_state(STATE_OBJECTIVE_COMPLETE, {"reward": total_reward})
				await get_tree().create_timer(1.0).timeout
				exit_level(next_level_id)

func trigger_checkpoint(cp_id: String, pos: Vector2, flags: Dictionary = {}) -> void:
	checkpoints["current"] = cp_id
	var cp_data: Dictionary = {"pos": {"x": pos.x, "y": pos.y}, "flags": flags, "ts": Time.get_ticks_msec()}
	checkpoints["checkpoints"][cp_id] = cp_data
	if ProgressFlags:
		ProgressFlags.SetKV("cp_" + current_level_id + "_" + cp_id, cp_data)

func trigger_fail(reason: String) -> void:
	last_fail_reason = reason
	level_failed.emit(reason, str(checkpoints.get("current", "")))
	_change_state(STATE_FAIL, {"reason": reason, "checkpoint": checkpoints.get("current", "")})

func retry_level() -> void:
	if current_state != STATE_FAIL:
		return
	# 真实项目：切回检查点或重新加载 level；此处为骨架：回到 PLAYING + reset HP 等
	var cp_id := str(checkpoints.get("current", ""))
	var cp_pos: Dictionary = checkpoints.get("checkpoints", {}).get(cp_id, {}).get("pos", {"x": 0, "y": 0})
	_change_state(STATE_PLAYING, {"mode": "retry", "checkpoint": cp_id, "pos": cp_pos})

func exit_to_menu() -> void:
	if current_state == STATE_EXITING:
		return
	_change_state(STATE_EXITING, {"target": "main_menu"})

func exit_level(next_id: String) -> void:
	if current_state == STATE_EXITING:
		return
	var snap: Dictionary = {}
	if ProgressFlags:
		snap = ProgressFlags.SerializeKV()
	_change_state(STATE_EXITING, {"target": "next_level", "next_level": next_id})
	level_exit.emit(next_id, snap)

## -------- 内部实现 --------
func get_state() -> String:
	return current_state

func list_objectives(status: String = "") -> Array:
	var out := []
	for o in objectives:
		if status == "" or o.get("status", "") == status:
			out.append(o)
	return out

func _evaluate_root_done() -> bool:
	# root logic: default AND (all leaf done → all done).  First element with "logic":"OR" 覆盖.
	if objectives.is_empty():
		return false
	var logic := "AND"
	if objectives.size() > 0 and objectives[0] is Dictionary and objectives[0].has("logic"):
		logic = str(objectives[0]["logic"]).to_upper()
	if logic == "OR":
		for o in objectives:
			if o.get("status", "") == "done":
				return true
		return false
	# AND: 所有非纯逻辑项都 done
	for o in objectives:
		if o is Dictionary and o.has("id") and o.has("type") and o.get("status", "") != "done":
			return false
	return true

func _accumulate_reward() -> Dictionary:
	var total: Dictionary = {"gold": 0, "unlock": PackedStringArray(), "items": {}}
	for o in objectives:
		var r: Dictionary = o.get("reward", {})
		if r.is_empty():
			continue
		if r.has("gold"): total["gold"] += int(r["gold"])
		if r.has("unlock"):
			for u in r["unlock"]:
				if not total["unlock"].has(u):
					total["unlock"].append(u)
		if r.has("items"):
			for k in r["items"].keys():
				total["items"][k] = int(total["items"].get(k, 0)) + int(r["items"][k])
	return total

func _change_state(new_state: String, payload: Dictionary) -> void:
	if new_state == current_state:
		return
	var old := current_state
	state_exited.emit(old)
	current_state = new_state
	state_entered.emit(new_state, payload)

func _process(delta: float) -> void:
	if current_state == STATE_INTRO:
		intro_timer += delta
		if intro_timer >= intro_duration:
			_change_state(STATE_PLAYING, {"elapsed": intro_timer})
