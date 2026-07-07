extends Node
## 全局EventBus（Autoload单例，Node名：GameEvents）
## 模块间解耦通信，不要互相持有引用，统一发信号

signal GameBootCompleted()
signal ScenePreChange(next_scene_path: String)
signal SceneChanged(now_path: String)
signal Paused(paused: bool)
