## 游戏 HUD（Phase 2）：境界/HP/MP 显示 + 暂停切换
## process_mode=ALWAYS：暂停时仍需响应 pause_toggle 解除暂停
## 数据获取：连接无参信号 player_stats_changed 后主动从 player 组拉取（doc 15：UI 不反向调玩家私有逻辑）
extends CanvasLayer

@onready var _realm_label: Label = $TopRight/VBox/RealmLabel
@onready var _hp_bar: ProgressBar = $TopRight/VBox/HPBox/HPBar
@onready var _mp_bar: ProgressBar = $TopRight/VBox/MPBox/MPBar
@onready var _paused_label: Label = $PausedLabel
@onready var _cd_labels: Array[Label] = [$SkillBar/Slot1/VBox/CDLabel, $SkillBar/Slot2/VBox/CDLabel, $SkillBar/Slot3/VBox/CDLabel]


func _ready() -> void:
	EventBus.player_stats_changed.connect(_refresh)
	_paused_label.visible = false
	_refresh()  # Player 可能先于 HUD ready（已补发信号），也可能晚于（此处兜底拉取）


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_toggle"):
		# 对话已暂停世界：此时空格不切换暂停（防对话中误解除导致敌人恢复活动）
		var dialogs := get_tree().get_nodes_in_group("dialogue_ui")
		if dialogs.size() > 0 and bool(dialogs[0].get("is_open")):
			return
		get_tree().paused = not get_tree().paused
		_paused_label.visible = get_tree().paused


func _process(_delta: float) -> void:
	_refresh_skillbar()


func _refresh_skillbar() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not "skill_controller" in player.get_parent():
		return
	var ctl: Node = player.get_node("SkillController")
	var mp: float = player.stats.current_mp
	for slot in range(1, 4):
		var label := _cd_labels[slot - 1]
		var remaining: float = ctl.get_remaining(slot)
		if remaining > 0.01:
			label.text = "%.1fs" % remaining
		else:
			label.text = " "
		# MP 不足置灰（冷却中已显橙色）
		var skill_id: String = ctl.SKILL_SLOTS.get(slot, "")
		var skill := DataManager.get_entry("skills", skill_id) as SkillData
		var enough_mp: bool = skill == null or mp >= float(skill.mp_cost)
		label.get_parent().get_parent().modulate = Color(1, 1, 1, 1) if enough_mp else Color(0.5, 0.5, 0.5, 1)


func _refresh() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null or player.stats.data == null:
		return
	var s := player.stats
	_hp_bar.max_value = s.max_hp
	_hp_bar.value = s.current_hp
	_mp_bar.max_value = s.max_mp
	_mp_bar.value = s.current_mp
	# 境界显示源 = CultivationManager（realm 运行时值归修仙系统所有，阶段5）
	var managers := get_tree().get_nodes_in_group("cultivation_manager")
	if managers.size() > 0:
		var cm: Node = managers[0]
		_realm_label.text = "%s（%s）" % [s.data.display_name, CultivationUtils.realm_display(cm.realm_index, cm.realm_layer)]
	else:
		_realm_label.text = "%s（%s）" % [s.data.display_name, CultivationUtils.realm_display(s.data.realm_index, s.data.realm_layer)]
