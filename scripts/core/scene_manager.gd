## 场景管理器：统一场景切换入口，禁止各系统直接调用 change_scene
extends Node

const SCENES := {
	"main_menu": "res://scenes/main/MainMenu.tscn",
	"game": "res://scenes/main/Game.tscn",
}

func goto(key: String) -> void:
	if not SCENES.has(key):
		push_error("SceneManager: 未知场景键 %s" % key)
		return
	# 延迟到帧末切换：在 _ready 阶段直接切换会触发
	# "Parent node is busy adding/removing children" 错误
	get_tree().change_scene_to_file.call_deferred(SCENES[key])
