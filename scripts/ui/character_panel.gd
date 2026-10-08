## 角色面板（阶段5）：C 键开关四区——属性/修为（打坐+突破）/功法/灵根道心
## 数据拉取：CultivationManager（境界/经验/功法）+ PlayerStats（属性），经信号统一刷新
extends Control

@onready var _stats_label: Label = $Panel/VBox/StatsLabel
@onready var _realm_label: Label = $Panel/VBox/CultivationBox/RealmLabel
@onready var _exp_bar: ProgressBar = $Panel/VBox/CultivationBox/ExpBar
@onready var _exp_label: Label = $Panel/VBox/CultivationBox/ExpLabel
@onready var _meditate_button: Button = $Panel/VBox/CultivationBox/MeditateButton
@onready var _breakthrough_button: Button = $Panel/VBox/CultivationBox/BreakthroughButton
@onready var _technique_label: Label = $Panel/VBox/TechniqueLabel
@onready var _tech_progress_bar: ProgressBar = $Panel/VBox/TechProgressBar
@onready var _roots_label: Label = $Panel/VBox/RootsLabel
@onready var _close_button: Button = $Panel/VBox/CloseButton


func _ready() -> void:
	visible = false
	EventBus.cultivation_state_changed.connect(_refresh)
	EventBus.player_stats_changed.connect(_refresh)
	_meditate_button.pressed.connect(_on_meditate_pressed)
	_breakthrough_button.pressed.connect(_on_breakthrough_pressed)
	_close_button.pressed.connect(_toggle)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("character_panel"):
		_toggle()


func _toggle() -> void:
	visible = not visible
	if visible:
		_refresh()


func _on_meditate_pressed() -> void:
	var cm := _manager()
	if cm != null:
		cm.set_meditating(not cm.meditating)


func _on_breakthrough_pressed() -> void:
	var cm := _manager()
	if cm != null:
		cm.attempt_major_breakthrough()


func _manager() -> Node:
	var arr := get_tree().get_nodes_in_group("cultivation_manager")
	return arr[0] if arr.size() > 0 else null


func _refresh() -> void:
	var player := get_tree().get_first_node_in_group("player")
	var cm := _manager()
	if player == null or cm == null:
		return
	var s = player.stats
	# --- 属性区 ---
	_stats_label.text = "气血 %d/%d　灵力 %d/%d\n攻击 %d　防御 %d　法攻 %d　法抗 %d" % [int(s.current_hp), int(s.max_hp), int(s.current_mp), int(s.max_mp), int(s.atk), int(s.defense), int(s.m_atk), int(s.m_def)]
	# --- 修为区 ---
	_realm_label.text = CultivationUtils.realm_display(cm.realm_index, cm.realm_layer)
	var need: int = CultivationUtils.required_exp(cm.realm_index, cm.realm_layer)
	_exp_bar.max_value = need
	_exp_bar.value = cm.realm_exp
	_exp_label.text = "境界经验 %d/%d" % [cm.realm_exp, need]
	var can_breakthrough: bool = cm.realm_layer >= CultivationConstants.LAYERS_PER_REALM and cm.realm_exp >= need
	_breakthrough_button.disabled = not can_breakthrough
	_breakthrough_button.text = "尝试大境界突破" if can_breakthrough else "九层满后可突破"
	_meditate_button.text = "收功" if cm.meditating else "打坐"
	# --- 功法区 ---
	var tech_text := ""
	for id: String in cm.learned_techniques:
		var tech := DataManager.get_entry("techniques", id) as TechniqueData
		var tech_name: String = tech.display_name if tech != null else id
		var mark := "【运功】" if id == cm.active_technique else ""
		tech_text += "%s%s\n" % [mark, tech_name]
	if cm.active_technique.is_empty():
		tech_text += "（未运功，效率 1.0）"
	_technique_label.text = tech_text
	var active_tech: TechniqueData = null
	if not cm.active_technique.is_empty():
		active_tech = DataManager.get_entry("techniques", cm.active_technique) as TechniqueData
	if active_tech != null:
		_tech_progress_bar.max_value = active_tech.cultivation_progress_max
		_tech_progress_bar.value = int(cm.technique_progress.get(cm.active_technique, 0))
		_tech_progress_bar.visible = true
	else:
		_tech_progress_bar.visible = false
	# --- 灵根道心区 ---
	if s.data != null:
		_roots_label.text = "灵根 %s　道心 %s" % [str(s.data.spirit_roots), str(s.data.dao_heart)]
