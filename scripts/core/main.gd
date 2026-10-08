## 主入口场景脚本：启动后跳转主菜单（Main.tscn 仅作为启动引导）
extends Node

func _ready() -> void:
	SceneManager.goto("main_menu")
