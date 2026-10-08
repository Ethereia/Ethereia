## 对话 UI（阶段3 最小版 → 阶段7 正式化）：DialogueData/EventData 驱动的对话框
## 链路：npc_interacted → 加载对话表 → 渲染节点树；打开时暂停世界（WHEN_PAUSED 模式下按钮仍可用）
## 阶段7 新增：节点 conditions 跳过 / 选项 requirements 置灰 / dialogue_choice_made 信号 / show_event 事件弹窗
class_name DialogueUI
extends Control

var is_open := false
var _npc_id := ""
var _source_id := ""  # 选项信号源 id：dlg_<char_id> 或 event_<id>（任务「选择」目标匹配用）
var _data: DialogueData = null

@onready var _speaker_label: Label = $Panel/VBox/SpeakerLabel
@onready var _text_label: Label = $Panel/VBox/TextLabel
@onready var _choices_box: VBoxContainer = $Panel/VBox/ChoicesBox


func _ready() -> void:
	add_to_group("dialogue_ui")
	visible = false
	EventBus.npc_interacted.connect(_on_npc_interacted)


## 系统提示（复用对话框）：Boss 剧情节点等无 NPC 场景
func show_notice(text: String) -> void:
	if is_open:
		return
	var fake := DialogueData.new()
	fake.entry_node_id = "n0"
	fake.nodes = [{"node_id": "n0", "speaker_id": "", "text": text, "emotion": "", "conditions": {}, "choices": [], "next": ""}]
	_npc_id = ""
	_source_id = ""
	_data = fake
	_open(fake.nodes[0])


## 事件弹窗（阶段7）：EventData → 临时 DialogueData，选择即终（next 留空）
func show_event(event: EventData) -> void:
	if is_open:
		return
	var fake := DialogueData.new()
	fake.entry_node_id = "n0"
	var speaker_id := ""
	if not event.involved_npcs.is_empty():
		speaker_id = event.involved_npcs[0]
	fake.nodes = [{
		"node_id": "n0",
		"speaker_id": speaker_id,
		"text": event.description,
		"emotion": "",
		"conditions": {},
		"choices": event.choices,
		"next": "",
	}]
	_npc_id = ""
	_source_id = event.id
	_data = fake
	_open(fake.nodes[0])


func _on_npc_interacted(npc_id: String, dialogue_id: String) -> void:
	if is_open:
		return
	_data = DataManager.get_entry("dialogues", dialogue_id) as DialogueData
	_npc_id = npc_id
	_source_id = _data.id if _data != null else ""
	if _data == null:
		# 无对话表：占位静态提示（保证任意 NPC 可交互不报错）
		_show_fallback(npc_id)
		return
	_open(_find_node(_data.entry_node_id))


func _show_fallback(npc_id: String) -> void:
	var data := DataManager.get_entry("characters", npc_id) as CharacterData
	var fake := DialogueData.new()
	fake.entry_node_id = "n0"
	fake.nodes = [{"node_id": "n0", "speaker_id": npc_id, "text": "（%s暂时没有什么想说的。）" % (data.display_name if data else npc_id), "emotion": "", "conditions": {}, "choices": [], "next": ""}]
	_data = fake
	_open(fake.nodes[0])


func _open(node: Dictionary) -> void:
	is_open = true
	visible = true
	get_tree().paused = true  # 冻结世界；本节点 WHEN_PAUSED，按钮仍可点击
	_render_with_conditions(node)


## 渲染入口：条件不满足的节点沿 next 链跳过（防环上限 16，链尽头即结束）
func _render_with_conditions(node: Dictionary) -> void:
	var guard := 0
	while not node.is_empty() and not ConditionEvaluator.check(node.get("conditions", []), self):
		var next_id := String(node.get("next", ""))
		if next_id.is_empty():
			_close()
			return
		node = _find_node(next_id)
		guard += 1
		if guard > 16:
			push_warning("[DialogueUI] 条件链超长/疑似环，强制结束对话")
			_close()
			return
	if node.is_empty():
		_close()
		return
	_render_node(node)


func _find_node(node_id: String) -> Dictionary:
	for node: Dictionary in _data.nodes:
		if String(node["node_id"]) == node_id:
			return node
	push_warning("[DialogueUI] 对话节点未找到 %s，结束对话" % node_id)
	return {}


func _render_node(node: Dictionary) -> void:
	_clear_choices()
	var speaker_id := String(node.get("speaker_id", _npc_id))
	var speaker_name := "???"
	if not speaker_id.is_empty():
		var speaker := DataManager.get_entry("characters", speaker_id) as CharacterData
		speaker_name = speaker.display_name if speaker != null else speaker_id
	_speaker_label.text = speaker_name
	_text_label.text = String(node.get("text", ""))
	var choices: Array = node.get("choices", [])
	var next := String(node.get("next", ""))
	if choices.is_empty():
		_add_choice_button("继续", {"text": "继续", "effects": [], "next": next}, -1)
	else:
		for i in range(choices.size()):
			var choice: Dictionary = choices[i]
			_add_choice_button(String(choice.get("text", "……")), choice, i)


func _add_choice_button(text: String, choice: Dictionary, choice_index: int) -> void:
	var btn := Button.new()
	btn.text = text
	# 选项门槛判定（doc 11 §5 requirements）：置灰可见不隐藏
	var requirements: Variant = choice.get("requirements", [])
	if requirements is Array and not (requirements as Array).is_empty():
		if not ConditionEvaluator.check(requirements, self):
			btn.disabled = true
			btn.text = text + "（%s）" % String(choice.get("hint", "条件未满足"))
	btn.pressed.connect(_on_choice_pressed.bind(choice, choice_index))
	_choices_box.add_child(btn)


func _on_choice_pressed(choice: Dictionary, choice_index: int) -> void:
	EffectResolver.apply_all(choice.get("effects", []), self)
	# 隐藏效果最小落地（Phase 7）：剧情 flag 类（world set）随选择立即生效；延迟型结果留 Phase 8
	EffectResolver.apply_all(choice.get("hidden_effects", []), self)
	if choice_index >= 0:
		EventBus.dialogue_choice_made.emit(_source_id, choice_index)  # 任务「选择」目标推进源
	var next := String(choice.get("next", ""))
	if next.is_empty():
		_close()
	else:
		var node := _find_node(next)
		if node.is_empty():
			_close()
		else:
			_render_with_conditions(node)


func _close() -> void:
	is_open = false
	visible = false
	get_tree().paused = false
	EventBus.dialogue_finished.emit(_npc_id)


func _clear_choices() -> void:
	for child in _choices_box.get_children():
		child.queue_free()
