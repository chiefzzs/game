extends Node
## V0.3g PartyManager Autoload —— 3角色编队管理单例
## ⚠️ 去掉了class_name PartyManager 避免 Godot "Class X hides an autoload singleton" 报错
## 单向依赖：无（下层）；上层Demo/UI 调用 switch_next/switch_to
## 保证：OneTrack 新增文件，不修改旧模块内部逻辑

const MAX_PARTY_SIZE: int = 3

var members: Array[CharacterBody2D] = []
var active_idx: int = 0

signal party_changed
signal party_switched(old_idx: int, new_idx: int, new_char: CharacterBody2D)

func register(ch: CharacterBody2D) -> Error:
	if ch == null or not is_instance_valid(ch):
		return ERR_INVALID_PARAMETER
	if members.size() >= MAX_PARTY_SIZE:
		return ERR_OUT_OF_MEMORY
	if members.has(ch):
		return ERR_ALREADY_EXISTS
	members.append(ch)
	if members.size() == 1:
		_activate_internal(0)
	party_changed.emit()
	return OK

func unregister(ch: CharacterBody2D) -> Error:
	if ch == null: return ERR_INVALID_PARAMETER
	var i: int = members.find(ch)
	if i < 0: return ERR_DOES_NOT_EXIST
	members.remove_at(i)
	if active_idx >= members.size() and not members.is_empty():
		active_idx = members.size() - 1
	party_changed.emit()
	return OK

func switch_next() -> int:
	if members.is_empty(): return -1
	var ni: int = (active_idx + 1) % members.size()
	return _activate_internal(ni)

func switch_prev() -> int:
	if members.is_empty(): return -1
	var ni: int = (active_idx - 1 + members.size()) % members.size()
	return _activate_internal(ni)

func switch_to(idx: int) -> int:
	if members.is_empty(): return -1
	if idx < 0 or idx >= members.size(): return -1
	return _activate_internal(idx)

func get_active() -> CharacterBody2D:
	if members.is_empty(): return null
	return members[active_idx]

func size() -> int:
	return members.size()

func is_active(ch: CharacterBody2D) -> bool:
	if members.is_empty(): return false
	if ch == null: return false
	return members[active_idx] == ch

func _activate_internal(idx: int) -> int:
	var old: int = active_idx
	active_idx = idx
	var nc: CharacterBody2D = members[idx]
	party_switched.emit(old, idx, nc)
	party_changed.emit()
	return idx

func clear() -> void:
	members.clear()
	active_idx = 0
	party_changed.emit()
