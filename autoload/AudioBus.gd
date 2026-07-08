extends Node
## V0.3 AudioBus.gd — Autoload音频总线（占位：Phase3交付）
## 后续可接入BGM/SFX播放；当前仅暴露占位函数使调用方不报错

class_name AudioBusCore

var volume_master: float = 0.8
var volume_bgm: float = 0.7
var volume_sfx: float = 1.0
var muted: bool = false

signal sfx_played(name: String, volume: float)
signal bgm_changed(track_name: String, volume: float)

func play_sfx(name: String, vol: float = -1.0) -> void:
	if muted:
		return
	var v := vol if vol >= 0.0 else volume_sfx * volume_master
	emit_signal("sfx_played", name, v)

func play_bgm(track: String, vol: float = -1.0) -> void:
	if muted:
		return
	var v := vol if vol >= 0.0 else volume_bgm * volume_master
	emit_signal("bgm_changed", track, v)

func set_master(v: float) -> void:
	volume_master = clamp(v, 0.0, 1.0)

func set_muted(b: bool) -> void:
	muted = b
