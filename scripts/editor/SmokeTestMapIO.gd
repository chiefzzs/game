extends RefCounted

static func _autoload(name: String) -> Node:
	var ml = Engine.get_main_loop()
	if typeof(ml) != TYPE_OBJECT or ml == null:
		return null
	if not (ml is SceneTree):
		return null
	var st: SceneTree = ml
	return st.root.get_node_or_null(NodePath("/root/" + name))
## V0.3 SmokeTestMapIO.gd — Phase3验收: Save-Load冒烟 (V0.2回归兼容)
## 目标: 1.PF serialize/deserialize roundtrip 2.SaveSlotManager 槽读写 roundtrip
## run_headless() => Dictionary with io_ok flag

const ID_PF := "ProgressFlags"
const ID_SM := "SaveSlotManager"

func run_headless(map_name: String = "", slot: int = 0) -> Dictionary:
	var out: Dictionary = {
		"io_ok": false, "errors": [], "map_name": map_name, "slot": slot,
		"progress_passes": 0, "save_passes": 0
	}
	if not Engine.has_singleton(ID_PF) or not Engine.has_singleton(ID_SM):
		out.errors.append("Missing required autoload singletons")
		return out
	var PF: Node = Engine.get_singleton(ID_PF)
	var SM: Node = Engine.get_singleton(ID_SM)
	if PF == null or SM == null:
		out.errors.append("Failed to access singleton nodes")
		return out
	var pf_pass := 0
	PF.call("Set", "v03_t1", true)
	PF.call("Set", "v03_t2", false)
	PF.call("SetKV", "gold", 123)
	PF.call("SetKV", "weapon", "axe")
	var snap1: Dictionary = PF.call("serialize")
	PF.call("clear_all")
	if PF.call("Get", "v03_t1") == false and PF.call("GetKV", "gold", 0) == 0:
		pf_pass += 1
	PF.call("deserialize", snap1)
	if PF.call("Get", "v03_t1") == true and PF.call("Get", "v03_t2") == false \
	   and PF.call("GetKV", "gold", 0) == 123 and PF.call("GetKV", "weapon","") == "axe":
		pf_pass += 1
	out.progress_passes = pf_pass
	if pf_pass < 2:
		out.errors.append("PF roundtrip failed (2 expected, got %d)" % pf_pass)
	var sm_pass := 0
	var test_slot: int = 5
	SM.call("DeleteSlot", test_slot)
	var err: int = int(SM.call("NewGame", test_slot))
	if err == OK:
		sm_pass += 1
	var data: Dictionary = SM.call("Load", test_slot)
	if (data is Dictionary) and data.has("version") and int(data.get("version", 0)) >= 1:
		sm_pass += 1
	SM.call("DeleteSlot", test_slot)
	out.save_passes = sm_pass
	if sm_pass < 2:
		out.errors.append("SaveSlot roundtrip failed (2 expected, got %d)" % sm_pass)
	out.io_ok = (pf_pass == 2) and (sm_pass == 2)
	print("[SmokeTestMapIO][run_headless] io_ok=%s pf=%d/2 sm=%d/2" % [
		str(out.io_ok), pf_pass, sm_pass])
	return out
