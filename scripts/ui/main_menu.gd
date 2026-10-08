## 主菜单：新的游戏 / 继续 / 设置 / 退出
extends Control

@onready var _new_game_button: Button = $Center/VBox/NewGameButton
@onready var _continue_button: Button = $Center/VBox/ContinueButton
@onready var _settings_button: Button = $Center/VBox/SettingsButton
@onready var _quit_button: Button = $Center/VBox/QuitButton

func _ready() -> void:
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_continue_button.pressed.connect(_on_continue_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_continue_button.disabled = not SaveManager.has_any_save()

func _on_new_game_pressed() -> void:
	GameManager.new_game()

func _on_continue_pressed() -> void:
	GameManager.continue_game()

func _on_settings_pressed() -> void:
	pass  # 占位：设置界面在后续阶段实现

func _on_quit_pressed() -> void:
	get_tree().quit()
