## 宗门面板（阶段6）：G 键开关——驻地/聚灵阵/弟子三区
## 数据拉取 SectManager；按钮直接调管理器方法，失败由管理器 print 提示
extends Control

@onready var _status_label: Label = $Panel/VBox/StatusLabel
@onready var _jueling_label: Label = $Panel/VBox/JuelingLabel
@onready var _upgrade_button: Button = $Panel/VBox/UpgradeButton
@onready var _disciples_label: Label = $Panel/VBox/DisciplesLabel
@onready var _recruit_button: Button = $Panel/VBox/RecruitButton
@onready var _establish_button: Button = $Panel/VBox/EstablishButton
@onready var _close_button: Button = $Panel/VBox/CloseButton


func _ready() -> void:
	visible = false
	EventBus.sect_state_changed.connect(_refresh)
	_establish_button.pressed.connect(_on_establish_pressed)
	_upgrade_button.pressed.connect(_on_upgrade_pressed)
	_recruit_button.pressed.connect(_on_recruit_pressed)
	_close_button.pressed.connect(_toggle)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("sect_panel"):
		_toggle()


func _toggle() -> void:
	visible = not visible
	if visible:
		_refresh()


func _manager() -> Node:
	var arr := get_tree().get_nodes_in_group("sect_manager")
	return arr[0] if arr.size() > 0 else null


func _on_establish_pressed() -> void:
	var m := _manager()
	if m != null:
		m.establish_residence()


func _on_upgrade_pressed() -> void:
	var m := _manager()
	if m != null:
		m.start_construction("building_ju_ling_zhen")


func _on_recruit_pressed() -> void:
	var m := _manager()
	if m != null:
		m.recruit_disciple()


func _refresh() -> void:
	var m := _manager()
	if m == null:
		return
	if not m.has_residence:
		_status_label.text = "（尚未建立临时驻地）"
		_jueling_label.text = ""
		_disciples_label.text = ""
		_establish_button.visible = true
		_upgrade_button.visible = false
		_recruit_button.visible = false
		return
	_establish_button.visible = false
	_upgrade_button.visible = true
	_recruit_button.visible = true
	var level: int = m.get_building_level("building_ju_ling_zhen")
	_status_label.text = "临时驻地 · 黑风岭向阳坡"
	var constructing: bool = m.is_constructing()
	if level >= 5:
		_jueling_label.text = "聚灵阵：5 级（满级）"
		_upgrade_button.visible = false
	elif constructing:
		_jueling_label.text = "聚灵阵：升级中……（%d 级 → %d 级）" % [level, level + 1]
		_upgrade_button.disabled = true
	else:
		_jueling_label.text = "聚灵阵：%d 级（环境因子 %.1f）" % [level, m.get_environment_factor()]
		_upgrade_button.disabled = false
		_upgrade_button.text = "升级聚灵阵"
	var cap: int = m.get_disciple_cap()
	_disciples_label.text = "弟子（%d/%d）：\n" % [m.disciples.size(), cap]
	for d: Dictionary in m.disciples:
		_disciples_label.text += "· %s（%s，%s，潜力 %d 星）\n" % [d["name"], CultivationUtils.realm_display(d["realm_index"], d["realm_layer"]), d["personality"], d["potential"]]
	if m.disciples.is_empty():
		_disciples_label.text += "（尚无弟子）"
	_recruit_button.disabled = m.disciples.size() >= cap
	_recruit_button.text = "招募弟子（灵石30+灵草5）"
