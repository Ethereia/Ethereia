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
	get_tree().change_scene_to_file(SCENES[key])
