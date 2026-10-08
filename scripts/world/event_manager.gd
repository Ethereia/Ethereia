## 事件管理器（阶段7 最小触发器）：STATE_CONDITION 事件的条件轮询 + 冷却 + choices 即时效果
## 触发源：month_changed（月结折算冷却）+ world_state_changed + region_entered + dialogue_finished/quest_completed（UI 释放后补查）
## MANUAL/SCHEDULED 触发与延迟/隐藏结果 Phase 8（世界模拟主线）接入，此处直接跳过
## 事件状态（fired/cooldowns）持久化到独立 events 段（doc 29 v1.1）
class_name EventManager
extends Node

const DAYS_PER_MONTH := 30

var fired: Array[String] = []   # 已触发的一次性事件 id（cooldown_days==0 视一次性）
var cooldowns: Dictionary = {}  # {event_id: 剩余天数}


func _ready() -> void:
	add_to_group("savable")
	add_to_group("event_manager")
	EventBus.month_changed.connect(_on_month_changed)
	EventBus.world_state_changed.connect(_on_world_state_changed)
	EventBus.region_entered.connect(_on_region_entered)
	EventBus.dialogue_finished.connect(_on_ui_released)
	EventBus.quest_completed.connect(_on_ui_released)


func _on_month_changed(_year: int, _month: int) -> void:
	# 冷却按整月折算（-30 天，月结驱动的粗粒度占位，doc 24 ADR 登记）
	for event_id: String in cooldowns.keys():
		cooldowns[event_id] = int(cooldowns[event_id]) - DAYS_PER_MONTH
		if int(cooldowns[event_id]) <= 0:
			cooldowns.erase(event_id)
	_check_events()


func _on_world_state_changed(_key: String, _value: Variant) -> void:
	_check_events()


func _on_region_entered(_region_id: String) -> void:
	_check_events()


## 对话关闭/任务完成后的补查：剧情链（回报→完成→事件）发生在对话打开期间，_check_events 当时会让路
func _on_ui_released(_arg: Variant = null) -> void:
	_check_events()


## 条件轮询：全部满足且不在冷却/未触发过中取 priority 最高者弹窗
func _check_events() -> void:
	var ui := _first_dialogue_ui()
	if ui == null or ui.is_open:
		return  # 对话占用中，本轮放弃（UI 释放信号会补查）
	var table: Dictionary = DataManager.get_table("events")
	var best: EventData = null
	for event_id: String in table:
		var event := table[event_id] as EventData
		if event == null or event.trigger != EventData.Trigger.STATE_CONDITION:
			continue
		if fired.has(event.id) or cooldowns.has(event.id):
			continue
		if not ConditionEvaluator.check(event.conditions, self):
			continue
		if best == null or event.priority > best.priority:
			best = event
	if best != null:
		_trigger(best)


func _trigger(event: EventData) -> void:
	if event.cooldown_days <= 0:
		fired.append(event.id)
	else:
		cooldowns[event.id] = event.cooldown_days
	print("[Event] 触发事件：%s" % (event.title if not event.title.is_empty() else event.id))
	# 无选项事件的直接效果就地生效（choices 事件的效果由选项点击分发）
	if event.choices.is_empty():
		EffectResolver.apply_all(event.effects, self)
	call_deferred("_deferred_show_event", event.id)


func _deferred_show_event(event_id: String) -> void:
	var ui := _first_dialogue_ui()
	if ui == null or ui.is_open:
		return
	var event := DataManager.get_entry("events", event_id) as EventData
	if event != null:
		ui.show_event(event)


func _first_dialogue_ui() -> DialogueUI:
	var nodes: Array = get_tree().get_nodes_in_group("dialogue_ui")
	return nodes[0] if nodes.size() > 0 else null


# --- 存档（events 段，doc 29 v1.1 新增第 12 段） ---

func get_save_section() -> String:
	return "events"


func get_save_state() -> Dictionary:
	return {"fired": fired.duplicate(), "cooldowns": cooldowns.duplicate()}


func load_save_state(state: Dictionary) -> void:
	# 旧档缺 events 段 → 空默认（一次性事件会重新可触发，可接受）
	fired.clear()
	for id: String in state.get("fired", []):
		fired.append(id)
	cooldowns = state.get("cooldowns", {}).duplicate()
