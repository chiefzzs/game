extends Node
## 全局EventBus（Autoload单例，Node名：GameEvents）
## 模块间解耦通信，不要互相持有引用，统一发信号

signal GameBootCompleted()
signal ScenePreChange(next_scene_path: String)
signal SceneChanged(now_path: String)
signal Paused(paused: bool)

# ---------- V0.3 战斗系统 8 信号（V0.3a-A9 追加，旧信号不动，O03 签名冻结） ----------
signal damage_calculated(attacker: Node, victim: Node, details: Dictionary)
signal character_stats_changed(who: Node, key: String, new_value)
signal gold_changed(now_gold: int, delta: int, reason: String)
signal combo_applied(combo_step: int, attacker: Node)
signal enemy_hp_changed(enemy_id: String, who: Node, now_hp: int, max_hp: int)
signal enemy_died(who: Node, id_key: String, pos: Vector2)
signal item_picked(item_id: String, amount: int, pos: Vector2)
signal shield_broken(who: Node, by_whom: Node)

# ---------- V0.3g 3角色编队切换信号（新增，历史信号未改，OneTrack OK） ----------
signal party_switched(old_idx: int, new_idx: int, new_char: Node)
