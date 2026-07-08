extends Node
## V0.3 GameEvents.gd - 全局事件总线（跨模块解耦唯一通道）
## 所有跨层 / 跨实体通知 MUST 走这里，禁止直接循环引用

# === 战斗核心事件 (V0.3新增) ===
signal damage_calculated(result: Dictionary)      # { attacker, victim, raw_atk, final_damage, is_crit, is_backstab, is_blocked, is_miss, type, knockback }
signal combo_changed(character: Node, current: int, total: int, window_left_sec: float)
signal character_hp_changed(character: Node, new_hp: int, max_hp: int, delta: int, source: Node)
signal character_stamina_changed(character: Node, new_st: float, max_st: float)
signal character_died(character: Node, killer: Node)
signal enemy_killed(enemy: Node, by_whom: Node, position: Vector2)
signal companion_died(companion: Node, by_whom: Node)
signal player_died(position: Vector2)
signal character_attack_connected(attacker: Node, victim: Node, damage: int)
signal shield_broken(character: Node, by_whom: Node)
signal weapon_changed(character: Node, weapon_id: String)
signal character_stats_changed(character: Node)

# === 掉落/拾取系统 ===
signal pickup_spawned(item: Node, kind: String, value: Variant, position: Vector2)
signal gold_picked(amount: int, by_whom: Node, total_gold: int)
signal potion_picked(heal_value: int, by_whom: Node)
signal generic_picked(item_id: String, value: Variant, by_whom: Node)
signal manual_pickup_available(item: Node)
signal manual_pickup_unavailable(item: Node)

# === 目标/流程 (V0.2/V0.3兼容) ===
signal objective_done(key: String)
signal objective_partial(key: String, progress: int, total: int)
signal chapter_entered(chapter_id: int, chapter_key: String)
signal checkpoint_reached(key: String, position: Vector2)
signal dialog_started(dialog_id: String)
signal dialog_finished(dialog_id: String)
signal save_completed(slot: int, path: String)
signal load_completed(slot: int)
signal float_damage_requested(position: Vector2, text: String, color: Color, font_size: int)

# === 性能统计（验收用）===
signal headless_phase_completed(phase: String, exit_code: int)
