## 游戏总管理器：全局流程状态机（主菜单/游戏中）
## 只管流程与全局状态，不承载具体系统逻辑（doc 15 §3：不要做巨型 Manager）
extends Node

enum GameState { MAIN_MENU, PLAYING }

var state: GameState = GameState.MAIN_MENU
var current_slot: String = ""

func new_game() -> void:
	TimeManager.reset()
	state = GameState.PLAYING
	EventBus.game_started.emit()
	SceneManager.goto("game")

func continue_game() -> void:
	var slot := SaveManager.get_latest_slot()
	if slot == "":
		push_warning("GameManager: 没有可读取的存档")
		return
	current_slot = slot
	# 先读数据缓存为待应用状态，切到 Game 场景后由 apply_pending_load 落地
	if SaveManager.load_game(slot, false):
		state = GameState.PLAYING
		SceneManager.goto("game")

func return_to_menu() -> void:
	state = GameState.MAIN_MENU
	EventBus.returned_to_menu.emit()
	SceneManager.goto("main_menu")
