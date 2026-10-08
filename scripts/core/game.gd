## 游戏主场景（阶段0骨架）：用调试面板验证 存档/读档/时间推进 闭环（里程碑 M1）
extends Node2D

const TEST_SLOT := "test"

@onready var _time_label: Label = $UILayer/DebugPanel/VBox/TimeLabel
@onready var _advance_button: Button = $UILayer/DebugPanel/VBox/AdvanceMonthButton
@onready var _save_button: Button = $UILayer/DebugPanel/VBox/SaveButton
@onready var _load_button: Button = $UILayer/DebugPanel/VBox/LoadButton
@onready var _menu_button: Button = $UILayer/DebugPanel/VBox/MenuButton

func _ready() -> void:
	add_to_group("savable")  # 阶段1重构为 doc 16 的 11 段存档结构
	_advance_button.pressed.connect(_on_advance_month_pressed)
	_save_button.pressed.connect(_on_save_pressed)
	_load_button.pressed.connect(_on_load_pressed)
	_menu_button.pressed.connect(_on_menu_pressed)
	EventBus.month_changed.connect(_on_month_changed)
	_refresh_time_label()
	# 主菜单"继续"进入时应用待载入状态（无待载数据时为空操作）
	SaveManager.apply_pending_load()
	_refresh_time_label()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("game_menu"):
		GameManager.return_to_menu()

func get_save_section() -> String:
	return "player_state"  # 阶段2后由 Player 节点接管此段

func get_save_state() -> Dictionary:
	# 占位：真实玩家状态在阶段2由 Player 接管
	return {"skeleton_marker": "stage0_game"}

func load_save_state(_state: Dictionary) -> void:
	_refresh_time_label()

func _on_advance_month_pressed() -> void:
	TimeManager.advance_month()

func _on_save_pressed() -> void:
	SaveManager.save_game(TEST_SLOT)

func _on_load_pressed() -> void:
	SaveManager.load_game(TEST_SLOT)
	_refresh_time_label()

func _on_menu_pressed() -> void:
	GameManager.return_to_menu()

func _on_month_changed(_year: int, _month: int) -> void:
	_refresh_time_label()

func _refresh_time_label() -> void:
	_time_label.text = "第 %d 年 %d 月" % [TimeManager.year, TimeManager.month]
