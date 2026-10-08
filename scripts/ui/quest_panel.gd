## 任务日志面板（阶段7）：J 键开关——进行中（含目标进度）+ 已完成两区
## 数据拉取 QuestManager（UI 不挖 quest_states 内部结构）；任务三信号驱动刷新
## 对话打开时世界暂停，本面板默认 process_mode 随树暂停，天然防 J 键误触
extends Control

@onready var _active_label: Label = $Panel/VBox/ActiveLabel
@onready var _completed_label: Label = $Panel/VBox/CompletedLabel
@onready var _close_button: Button = $Panel/VBox/CloseButton


func _ready() -> void:
	visible = false
	EventBus.quest_accepted.connect(_on_quest_signal)
	EventBus.quest_completed.connect(_on_quest_signal)
	EventBus.quest_progress_changed.connect(_on_quest_signal)
	_close_button.pressed.connect(_toggle)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quest_log"):
		_toggle()


func _toggle() -> void:
	visible = not visible
	if visible:
		_refresh()


func _on_quest_signal(_quest_id: String) -> void:
	if visible:
		_refresh()


func _manager() -> Node:
	var arr := get_tree().get_nodes_in_group("quest_manager")
	return arr[0] if arr.size() > 0 else null


func _refresh() -> void:
	var m := _manager()
	if m == null:
		return
	var active: Array[String] = m.get_active_quests()
	var completed: Array[String] = m.get_completed_quests()
	_active_label.text = "进行中（%d）：\n" % active.size()
	if active.is_empty():
		_active_label.text += "（暂无进行中的任务）"
	for quest_id: String in active:
		var view: Dictionary = m.get_quest_view(quest_id)
		_active_label.text += "◆ %s\n" % String(view.get("display_name", quest_id))
		for obj: Dictionary in view["objectives"]:
			var mark := "✓" if int(obj["cur"]) >= int(obj["cap"]) else "○"
			_active_label.text += "　%s %s %s（%d/%d）\n" % [mark, obj["type"], obj["target_id"], obj["cur"], obj["cap"]]
	_completed_label.text = "已完成（%d）：\n" % completed.size()
	for quest_id: String in completed:
		var view: Dictionary = m.get_quest_view(quest_id)
		_completed_label.text += "· %s\n" % String(view.get("display_name", quest_id))
