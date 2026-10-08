## 任务管理器（阶段3最小版）：任务状态字典 + 监听 EventBus 推进目标
## 目标类型（doc 11 中文枚举）阶段3支持：到达/战斗/对话；其余类型忽略
## 完整任务系统（时限/收集/链式）Phase 7 正式化
class_name QuestManager
extends Node

var quest_states: Dictionary = {}  # {quest_id: {"status": "active"|"completed", "progress": {idx: count}}}


func _ready() -> void:
	add_to_group("savable")
	add_to_group("quest_manager")
	EventBus.region_entered.connect(_on_region_entered)
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.npc_interacted.connect(_on_npc_interacted)


## 幂等接取：重复接取忽略（对话选项可重复出现）
func accept_quest(quest_id: String) -> void:
	if quest_states.has(quest_id):
		print("[Quest] %s 已在状态 %s，忽略重复接取" % [quest_id, quest_states[quest_id]["status"]])
		return
	var data := DataManager.get_entry("quests", quest_id) as QuestData
	if data == null:
		push_warning("[Quest] 任务数据不存在 %s" % quest_id)
		return
	quest_states[quest_id] = {"status": "active", "progress": {}}
	print("[Quest] 接取任务：%s" % data.display_name)
	EventBus.quest_accepted.emit(quest_id)


## 回报完成：校验全部目标达成后才发放奖励（rewards 经 EffectResolver）
func complete_quest(quest_id: String) -> void:
	var qs: Dictionary = quest_states.get(quest_id, {})
	if qs.is_empty() or String(qs["status"]) != "active":
		print("[Quest] %s 不在进行中，无法回报" % quest_id)
		return
	if not _all_objectives_done(quest_id):
		print("[Quest] %s 目标尚未全部达成，无法回报" % quest_id)
		return
	qs["status"] = "completed"
	var data := DataManager.get_entry("quests", quest_id) as QuestData
	print("[Quest] 完成任务：%s，发放奖励" % (data.display_name if data else quest_id))
	EventBus.quest_completed.emit(quest_id)
	if data != null:
		EffectResolver.apply_all(data.rewards, self)


func is_active(quest_id: String) -> bool:
	var qs: Dictionary = quest_states.get(quest_id, {})
	return not qs.is_empty() and String(qs["status"]) == "active"


## 目标全达成判定（未知目标类型视为不达成）
func _all_objectives_done(quest_id: String) -> bool:
	var data := DataManager.get_entry("quests", quest_id) as QuestData
	if data == null:
		return false
	var progress: Dictionary = quest_states[quest_id]["progress"]
	for idx in range(data.objectives.size()):
		var obj: Dictionary = data.objectives[idx]
		if not _objective_supported(obj):
			return false
		if int(progress.get(idx, 0)) < int(obj.get("count", 1)):
			return false
	return true


func _objective_supported(obj: Dictionary) -> bool:
	return obj.get("type", "") in ["到达", "战斗", "对话"]


## 推进一个目标（幂等封顶 count）
func _advance(quest_id: String, obj: Dictionary, idx: int) -> void:
	var qs: Dictionary = quest_states[quest_id]
	var progress: Dictionary = qs["progress"]
	var cap := int(obj.get("count", 1))
	var now := int(progress.get(idx, 0))
	if now >= cap:
		return
	progress[idx] = now + 1
	print("[Quest] 目标推进 %s：%d/%d（%s %s）" % [quest_id, progress[idx], cap, obj["type"], obj["target_id"]])
	EventBus.quest_progress_changed.emit(quest_id)


# --- EventBus 推进源 ---

func _on_region_entered(region_id: String) -> void:
	for quest_id: String in quest_states:
		if not is_active(quest_id):
			continue
		var data := DataManager.get_entry("quests", quest_id) as QuestData
		if data == null:
			continue
		for idx in range(data.objectives.size()):
			var obj: Dictionary = data.objectives[idx]
			if obj.get("type", "") == "到达" and String(obj.get("target_id", "")) == region_id:
				_advance(quest_id, obj, idx)


func _on_enemy_died(enemy_id: String, _region_id: String) -> void:
	for quest_id: String in quest_states:
		if not is_active(quest_id):
			continue
		var data := DataManager.get_entry("quests", quest_id) as QuestData
		if data == null:
			continue
		for idx in range(data.objectives.size()):
			var obj: Dictionary = data.objectives[idx]
			if obj.get("type", "") == "战斗" and String(obj.get("target_id", "")) == enemy_id:
				_advance(quest_id, obj, idx)


## 「对话」目标语义 = 与目标 NPC 交谈过（交互即计数，回报对话点击时已满足）
func _on_npc_interacted(npc_id: String, _dialogue_id: String) -> void:
	for quest_id: String in quest_states:
		if not is_active(quest_id):
			continue
		var data := DataManager.get_entry("quests", quest_id) as QuestData
		if data == null:
			continue
		for idx in range(data.objectives.size()):
			var obj: Dictionary = data.objectives[idx]
			if obj.get("type", "") == "对话" and String(obj.get("target_id", "")) == npc_id:
				_advance(quest_id, obj, idx)


# --- 存档（quests 段） ---

func get_save_section() -> String:
	return "quests"


func get_save_state() -> Dictionary:
	return {"quest_states": quest_states.duplicate(true)}


func load_save_state(state: Dictionary) -> void:
	quest_states = state.get("quest_states", {})
