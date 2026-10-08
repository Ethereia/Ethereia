## 游戏 HUD（Phase 2）：境界/HP/MP 显示 + 暂停切换
## process_mode=ALWAYS：暂停时仍需响应 pause_toggle 解除暂停
## 数据获取：连接无参信号 player_stats_changed 后主动从 player 组拉取（doc 15：UI 不反向调玩家私有逻辑）
extends CanvasLayer

@onready var _realm_label: Label = $TopRight/VBox/RealmLabel
@onready var _hp_bar: ProgressBar = $TopRight/VBox/HPBox/HPBar
@onready var _mp_bar: ProgressBar = $TopRight/VBox/MPBox/MPBar
@onready var _paused_label: Label = $PausedLabel


func _ready() -> void:
	EventBus.player_stats_changed.connect(_refresh)
	_paused_label.visible = false
	_refresh()  # Player 可能先于 HUD ready（已补发信号），也可能晚于（此处兜底拉取）


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_toggle"):
		get_tree().paused = not get_tree().paused
		_paused_label.visible = get_tree().paused


func _refresh() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null or player.stats.data == null:
		return
	var s := player.stats
	_hp_bar.max_value = s.max_hp
	_hp_bar.value = s.current_hp
	_mp_bar.max_value = s.max_mp
	_mp_bar.value = s.current_mp
	_realm_label.text = "%s（%s）" % [s.data.display_name, CultivationUtils.realm_display(s.data.realm_index, s.data.realm_layer)]
