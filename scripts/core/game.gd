## 游戏主场景（阶段3）：世界/玩家/UI 全套静态实例化，本脚本仅负责调试面板与流程
extends Node2D

const TEST_SLOT := "test"

@onready var _time_label: Label = $UILayer/DebugPanel/VBox/TimeLabel
@onready var _advance_button: Button = $UILayer/DebugPanel/VBox/AdvanceMonthButton
@onready var _save_button: Button = $UILayer/DebugPanel/VBox/SaveButton
@onready var _load_button: Button = $UILayer/DebugPanel/VBox/LoadButton
@onready var _menu_button: Button = $UILayer/DebugPanel/VBox/MenuButton

func _ready() -> void:
	_advance_button.pressed.connect(_on_advance_month_pressed)
	_save_button.pressed.connect(_on_save_pressed)
	_load_button.pressed.connect(_on_load_pressed)
	_menu_button.pressed.connect(_on_menu_pressed)
	EventBus.month_changed.connect(_on_month_changed)
	_refresh_time_label()
	# 主菜单"继续"进入时应用待载入状态（无待载数据时为空操作）
	# 子节点（World/Player/InventoryManager/QuestManager）_ready 先于根节点，均已在 savable 组
	SaveManager.apply_pending_load()
	_refresh_time_label()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("game_menu"):
		GameManager.return_to_menu()

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
