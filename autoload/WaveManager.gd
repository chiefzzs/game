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

# ---------- V0.3i 新增 KDA 信号（与 GameEvents 同签名，解耦WM自身事件总线；场景层 relay 到 GE 即可） ----------
signal kda_stat_changed(stat_name: String, value: int)
signal combo_changed(current: int, max_now: int)
signal block_succeeded(absorbed: int)

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

# ---------- V0.3i 新增 KDA 字段（全默认 0 / 0.0，OneTrack 不影响V0.3h） ----------
## KDA 三要素 + 辅助 4 项
var stat_player_hits: int = 0
var stat_player_deaths: int = 0
var stat_blocks: int = 0
var stat_max_combo: int = 0
var stat_combo_now: int = 0
var stat_damage_dealt: int = 0
var _combo_timer_left: float = 0.0
const COMBO_TIMEOUT_SEC: float = 2.5

func _process(delta: float) -> void:
	if state == WaveState.SPAWNING:
		_gap_timer_left -= delta
		if _gap_timer_left <= 0.0:
			_start_active()
	if state == WaveState.ACTIVE:
		total_elapsed = Time.get_ticks_msec() / 1000.0 - _time_started
		# ---- V0.3i combo 超时倒计时（超 2.5s 归零） ----
		if stat_combo_now > 0:
			_combo_timer_left -= delta
			if _combo_timer_left <= 0.0:
				_reset_combo_only_now()

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
	# V0.3i 追加：同步 KDA kills 字段与信号
	_emit_kda_changed("kills", total_kills)
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
	# V0.3i 追加：KDA 清零
	stat_player_hits = 0
	stat_player_deaths = 0
	stat_blocks = 0
	stat_max_combo = 0
	stat_combo_now = 0
	stat_damage_dealt = 0
	_combo_timer_left = 0.0

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

# ============================================================
# V0.3i KDA API（全新增，OneTrack 不影响 V0.3h 任何调用）
# ============================================================

## V0.3i: 玩家受击 → D 的 hit 计数
func notify_player_hit() -> void:
	stat_player_hits += 1
	_emit_kda_changed("player_hits", stat_player_hits)

## V0.3i: 玩家死亡 → D 的 death 计数（同时重置 combo）
func notify_player_death() -> void:
	stat_player_deaths += 1
	_reset_combo_both()
	_emit_kda_changed("deaths", stat_player_deaths)

## V0.3i: 玩家成功格挡（吸收 absorbed 点伤害）→ A 的 block 计数
func notify_block_success(absorbed: int = 0) -> void:
	stat_blocks += 1
	_emit_kda_changed("blocks", stat_blocks)
	if has_signal("block_succeeded"):
		emit_signal("block_succeeded", absorbed)

## V0.3i: 对敌造成伤害（每刀一次）→ combo +1 + 总伤害 + 刷新 max
func notify_dealt_damage(amount: int, is_kill: bool = false) -> void:
	if amount > 0:
		stat_damage_dealt += amount
		_emit_kda_changed("damage_dealt", stat_damage_dealt)
	stat_combo_now += 1
	_combo_timer_left = COMBO_TIMEOUT_SEC
	if stat_combo_now > stat_max_combo:
		stat_max_combo = stat_combo_now
		_emit_kda_changed("max_combo", stat_max_combo)
	if has_signal("combo_changed"):
		emit_signal("combo_changed", stat_combo_now, stat_max_combo)

## V0.3i: 总伤害输出（Headless 用）
func final_damage_dealt() -> int:
	return stat_damage_dealt

## V0.3i: 综合评分 S/A/B/C/D（详细公式见设计文档§四 / 用户手册§四）
## Score = (Kills*3) + (Blocks*2) + (MaxCombo*1.5) + (Deaths*-6) + (<60s ? +10 : 0)
func compute_rating() -> String:
	var k: float = float(max(0, total_kills))
	var b: float = float(max(0, stat_blocks))
	var mc: float = float(max(0, stat_max_combo))
	var d: float = float(max(0, stat_player_deaths))
	var sec: float = max(0.0, total_elapsed)
	var sc: float = k * 3.0 + b * 2.0 + mc * 1.5 + d * (-6.0)
	if sec < 60.0:
		sc += 10.0
	if sc >= 40.0 and int(d) == 0:
		return "S"
	if sc >= 28.0:
		return "A"
	if sc >= 18.0:
		return "B"
	if sc >= 10.0:
		return "C"
	return "D"

## V0.3i: 数值版 compute_rating（测试 UC07/08 直接用）
func compute_score_raw() -> float:
	var k: float = float(max(0, total_kills))
	var b: float = float(max(0, stat_blocks))
	var mc: float = float(max(0, stat_max_combo))
	var d: float = float(max(0, stat_player_deaths))
	var sec: float = max(0.0, total_elapsed)
	var sc: float = k * 3.0 + b * 2.0 + mc * 1.5 + d * (-6.0)
	if sec < 60.0:
		sc += 10.0
	return sc

# ---------- internal helpers（V0.3i） ----------
func _reset_combo_only_now() -> void:
	if stat_combo_now == 0:
		return
	stat_combo_now = 0
	if has_signal("combo_changed"):
		emit_signal("combo_changed", stat_combo_now, stat_max_combo)

func _reset_combo_both() -> void:
	stat_combo_now = 0
	stat_max_combo = max(0, stat_max_combo)  # 不清 max（死亡 Max 继续保留给结算）
	_combo_timer_left = 0.0
	if has_signal("combo_changed"):
		emit_signal("combo_changed", stat_combo_now, stat_max_combo)

func _emit_kda_changed(name: String, v: int) -> void:
	if has_signal("kda_stat_changed"):
		emit_signal("kda_stat_changed", name, v)
