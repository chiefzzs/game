extends Node
## V0.3h WaveManager Autoload — 多波次战斗FSM（默认3波）
## ⚠️ 不加 class_name WaveManager（避免和 Autoload 名冲突）
## 用法（场景层调用）：
##   WaveManager.start_from_first()   重开
##   WaveManager.notify_enemy_killed() 每死一只敌人调用一次
## 监听信号：
##   wave_started(idx, total, n)     波次开始（对应场景画大字）
##   wave_cleared(idx, nwave, total) 清波（飘右上提示）
##   all_waves_cleared(total, sec)   全通关（弹胜利卡）

signal wave_started(wave_idx: int, total_waves: int, enemy_count: int)
signal wave_cleared(wave_idx: int, kills_in_wave: int, total_kills: int)
signal all_waves_cleared(total_kills: int, total_seconds: float)

enum WaveState {
	IDLE = 0,      # 还没 start_from_first
	SPAWNING = 1,  # 波开始前 gap
	ACTIVE = 2,    # 战斗中
	VICTORY = 3,   # 通关
}

const DEFAULT_WAVES: Array[Dictionary] = [
	{"enemies": 1, "gap_sec": 1.8, "hint": "热身：1 只史莱姆"},
	{"enemies": 2, "gap_sec": 2.0, "hint": "进阶：2 只史莱姆围攻"},
	{"enemies": 3, "gap_sec": 2.2, "hint": "终局：3 只史莱姆围殴"},
]

const INVALID_IDX: int = -1

var waves_cfg: Array[Dictionary] = DEFAULT_WAVES.duplicate()
var current_wave_idx: int = INVALID_IDX   # 0-based；对外展示 = idx+1
var enemies_left_this_wave: int = 0
var kills_this_wave: int = 0
var total_kills: int = 0
var wave_started_at_sec: float = 0.0
var total_elapsed: float = 0.0
var state: int = WaveState.IDLE

var _gap_timer_left: float = 0.0
var _time_started: float = 0.0

func _process(delta: float) -> void:
	if state == WaveState.SPAWNING:
		_gap_timer_left -= delta
		if _gap_timer_left <= 0.0:
			_start_active()
	if state == WaveState.ACTIVE:
		total_elapsed = Time.get_ticks_msec() / 1000.0 - _time_started

func total_waves() -> int:
	return max(0, waves_cfg.size())

func current_wave_display() -> int:
	if current_wave_idx < 0 or current_wave_idx >= total_waves():
		return 0
	return current_wave_idx + 1

func set_waves(custom_waves: Array[Dictionary]) -> void:
	if state != WaveState.IDLE and state != WaveState.VICTORY:
		return
	waves_cfg = custom_waves.duplicate()
	if waves_cfg.is_empty():
		waves_cfg = DEFAULT_WAVES.duplicate()

func start_from_first() -> void:
	_reset_all()
	state = WaveState.SPAWNING
	current_wave_idx = 0
	_gap_timer_left = _gap_sec_for(0)
	_time_started = Time.get_ticks_msec() / 1000.0
	wave_started_at_sec = 0.0

func force_next_wave() -> int:
	if total_waves() <= 0:
		return INVALID_IDX
	if current_wave_idx < 0:
		start_from_first()
		return 0
	var next_idx: int = current_wave_idx + 1
	if next_idx >= total_waves():
		state = WaveState.VICTORY
		_emit_victory()
		return INVALID_IDX
	current_wave_idx = next_idx
	state = WaveState.SPAWNING
	_gap_timer_left = _gap_sec_for(next_idx)
	return next_idx

func notify_enemy_killed() -> void:
	if state != WaveState.ACTIVE:
		return
	total_kills += 1
	kills_this_wave += 1
	enemies_left_this_wave = max(0, enemies_left_this_wave - 1)
	if enemies_left_this_wave <= 0:
		_on_wave_cleared()

func has_won() -> bool:
	return state == WaveState.VICTORY

func clear() -> void:
	_reset_all()

# ---------------- internal ----------------

func _reset_all() -> void:
	current_wave_idx = INVALID_IDX
	enemies_left_this_wave = 0
	kills_this_wave = 0
	total_kills = 0
	total_elapsed = 0.0
	state = WaveState.IDLE
	_gap_timer_left = 0.0
	_time_started = 0.0

func _start_active() -> void:
	var idx: int = current_wave_idx
	var n: int = int(_enemy_count_for(idx))
	state = WaveState.ACTIVE
	enemies_left_this_wave = n
	kills_this_wave = 0
	wave_started_at_sec = Time.get_ticks_msec() / 1000.0 - _time_started
	if has_signal("wave_started"):
		emit_signal("wave_started", idx, total_waves(), n)

func _on_wave_cleared() -> void:
	var idx: int = current_wave_idx
	if has_signal("wave_cleared"):
		emit_signal("wave_cleared", idx, kills_this_wave, total_kills)
	var next_idx: int = idx + 1
	if next_idx >= total_waves():
		state = WaveState.VICTORY
		_emit_victory()
		return
	current_wave_idx = next_idx
	state = WaveState.SPAWNING
	_gap_timer_left = _gap_sec_for(next_idx)

func _emit_victory() -> void:
	total_elapsed = max(total_elapsed, Time.get_ticks_msec() / 1000.0 - _time_started)
	if has_signal("all_waves_cleared"):
		emit_signal("all_waves_cleared", total_kills, total_elapsed)

func _enemy_count_for(idx: int) -> int:
	if idx < 0 or idx >= waves_cfg.size():
		return 0
	var d: Dictionary = waves_cfg[idx]
	return int(d.get("enemies", 1))

func _gap_sec_for(idx: int) -> float:
	if idx < 0 or idx >= waves_cfg.size():
		return 1.5
	var d: Dictionary = waves_cfg[idx]
	return float(d.get("gap_sec", 1.8))
