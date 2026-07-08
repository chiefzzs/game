extends SceneTree
var _t: int = 0

func _process(_d: float) -> bool:
	_t += 1
	if _t == 1:
		var ml = Engine.get_main_loop()
		print("PROBE3: ml type=", typeof(ml), " is SceneTree=", ml is SceneTree)
		if ml is SceneTree:
			var st: SceneTree = ml
			print("PROBE3: root=", st.root, " root.name=", st.root.name)
			var cn = st.root.get_node_or_null(NodePath("/root/ConfigManager"))
			var pf = st.root.get_node_or_null(NodePath("/root/ProgressFlags"))
			var ge = st.root.get_node_or_null(NodePath("/root/GameEvents"))
			var sm = st.root.get_node_or_null(NodePath("/root/SaveSlotManager"))
			print("PROBE3: ConfigManager=", cn != null, " ProgressFlags=", pf != null, " GameEvents=", ge != null, " SaveSlotManager=", sm != null)
			if cn != null:
				print("PROBE3: ConfigManager.cfg_get(version)=", cn.call("cfg_get", "version", "NF"))
			call_deferred("_q", 0 if cn != null else 2)
		else:
			call_deferred("_q", 99)
	elif _t > 10:
		call_deferred("_q", 98)
	return false

func _q(c: int) -> void:
	quit(c)
