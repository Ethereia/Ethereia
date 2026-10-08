## 游戏主场景（阶段2）：Player 闭环 + 调试面板验证 存档/读档/时间推进
extends Node2D

const TEST_SLOT := "test"

const PLAYER_SCENE := preload("res://scenes/characters/Player.tscn")
const TRAINING_DUMMY_SCENE := preload("res://scenes/characters/TrainingDummy.tscn")
const HUD_SCENE := preload("res://scenes/ui/HUD.tscn")

@onready var _time_label: Label = $UILayer/DebugPanel/VBox/TimeLabel
@onready var _advance_button: Button = $UILayer/DebugPanel/VBox/AdvanceMonthButton
@onready var _save_button: Button = $UILayer/DebugPanel/VBox/SaveButton
@onready var _load_button: Button = $UILayer/DebugPanel/VBox/LoadButton
@onready var _menu_button: Button = $UILayer/DebugPanel/VBox/MenuButton

func _ready() -> void:
	# 阶段2：Player 接管 player_state 存档段，本节点不再注册 savable
	_spawn_stage_entities()
	_advance_button.pressed.connect(_on_advance_month_pressed)
	_save_button.pressed.connect(_on_save_pressed)
	_load_button.pressed.connect(_on_load_pressed)
	_menu_button.pressed.connect(_on_menu_pressed)
	EventBus.month_changed.connect(_on_month_changed)
	_refresh_time_label()
	# 主菜单"继续"进入时应用待载入状态（无待载数据时为空操作）
	# 此时 Player 已在 savable 组内（子节点 _ready 先于根节点），可收到待载数据
	SaveManager.apply_pending_load()
	_refresh_time_label()

func _spawn_stage_entities() -> void:
	var player := PLAYER_SCENE.instantiate()
	player.position = Vector2(200, 300)
	add_child(player)
	var dummy := TRAINING_DUMMY_SCENE.instantiate()
	dummy.position = Vector2(460, 300)
	add_child(dummy)
	$UILayer.add_child(HUD_SCENE.instantiate())

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
