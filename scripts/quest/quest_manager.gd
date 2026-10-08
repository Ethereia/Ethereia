## 任务管理器（阶段7 正式版）：状态字典 + 监听 EventBus 推进目标 + next_quests 链 + UI 查询接口
## 支持目标类型 6/10（doc 11 中文枚举）：到达/战斗/对话/收集/修炼/选择
##   - 到达/战斗/对话/选择：事件驱动计数推进（_advance）
##   - 收集：持有量快照（允许回落，_sync_collect_objectives）
##   - 修炼：境界/层数达标即置满（params.realm_index 必填，realm_layer 可选）
## 其余类型（建造/研究/时限/NPC状态）Phase 8/9 接入
class_name QuestManager
extends Node

const SUPPORTED_TYPES: Array[String] = ["到达", "战斗", "对话", "收集", "修炼", "选择"]

var quest_states: Dictionary = {}  # {quest_id: {"status": "active"|"completed", "progress": {idx: count}}}
var tracked_id := ""               # HUD 追踪任务（内存字段，不入档）
var _has_cultivation_obj := false  # 修炼目标早退缓存（打坐每秒发信号，防高频空转）


func _ready() -> void:
	add_to_group("savable")
	add_to_group("quest_manager")
	EventBus.region_entered.connect(_on_region_entered)
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.npc_interacted.connect(_on_npc_interacted)
	EventBus.item_added.connect(_on_item_changed)
	EventBus.item_removed.connect(_on_item_changed)
	EventBus.cultivation_state_changed.connect(_on_cultivation_state_changed)
	EventBus.dialogue_choice_made.connect(_on_dialogue_choice_made)


## 幂等接取：重复接取忽略（对话选项可重复出现）；requirements 不满足拒绝
func accept_quest(quest_id: String) -> void:
	if quest_states.has(quest_id):
		print("[Quest] %s 已在状态 %s，忽略重复接取" % [quest_id, quest_states[quest_id]["status"]])
		return
	var data := DataManager.get_entry("quests", quest_id) as QuestData
	if data == null:
		push_warning("[Quest] 任务数据不存在 %s" % quest_id)
		return
	if not data.requirements.is_empty() and not ConditionEvaluator.check(data.requirements, self):
		print("[Quest] %s 接取条件不满足，拒绝" % quest_id)
		return
	quest_states[quest_id] = {"status": "active", "progress": {}}
	if tracked_id.is_empty():
		tracked_id = quest_id
	_recalc_cultivation_cache()
	_sync_collect_objectives()
	print("[Quest] 接取任务：%s" % data.display_name)
	EventBus.quest_accepted.emit(quest_id)


## 回报完成：校验全部目标达成后才发放奖励（rewards 经 EffectResolver），随后链式接取 next_quests
func complete_quest(quest_id: String) -> void:
	var qs: Dictionary = quest_states.get(quest_id, {})
	if qs.is_empty() or String(qs["status"]) != "active":
		print("[Quest] %s 不在进行中，无法回报" % quest_id)
		return
	if not _all_objectives_done(quest_id):
		print("[Quest] %s 目标尚未全部达成，无法回报" % quest_id)
		return
	qs["status"] = "completed"
	if tracked_id == quest_id:
		tracked_id = ""
	var data := DataManager.get_entry("quests", quest_id) as QuestData
	print("[Quest] 完成任务：%s，发放奖励" % (data.display_name if data else quest_id))
	EventBus.quest_completed.emit(quest_id)
	if data != null:
		EffectResolver.apply_all(data.rewards, self)
		_chain_next_quests(data)


func is_active(quest_id: String) -> bool:
	var qs: Dictionary = quest_states.get(quest_id, {})
	return not qs.is_empty() and String(qs["status"]) == "active"


## 任务三态查询（ConditionEvaluator quest.<id> 用）："none"/"active"/"completed"
func quest_state_of(quest_id: String) -> String:
	var qs: Dictionary = quest_states.get(quest_id, {})
	if qs.is_empty():
		return "none"
	return String(qs["status"])


# --- UI 查询接口（UI 不挖 quest_states 内部结构） ---

func get_active_quests() -> Array[String]:
	var result: Array[String] = []
	for quest_id: String in quest_states:
		if is_active(quest_id):
			result.append(quest_id)
	return result


func get_completed_quests() -> Array[String]:
	var result: Array[String] = []
	for quest_id: String in quest_states:
		if String(quest_states[quest_id]["status"]) == "completed":
			result.append(quest_id)
	return result


## 面板视图：{display_name, description, objectives: [{type, target_id, cur, cap}]}
func get_quest_view(quest_id: String) -> Dictionary:
	var data := DataManager.get_entry("quests", quest_id) as QuestData
	if data == null:
		return {}
	var progress: Dictionary = quest_states.get(quest_id, {}).get("progress", {})
	var objectives: Array = []
	for idx in range(data.objectives.size()):
		var obj: Dictionary = data.objectives[idx]
		var target_disp := _display_name_of(String(obj.get("target_id", "")))
		if obj.get("type", "") == "修炼":
			# 修炼目标无 target_id：显示 params 指定的境界
			var params: Dictionary = obj.get("params", {})
			target_disp = CultivationUtils.realm_display(int(params.get("realm_index", 1)), int(params.get("realm_layer", 1)))
		objectives.append({
			"type": String(obj.get("type", "")),
			"target_id": target_disp,
			"cur": int(progress.get(idx, 0)),
			"cap": int(obj.get("count", 1)),
		})
	return {"display_name": data.display_name, "description": data.description, "objectives": objectives}


## HUD 追踪提示：首个未达成目标，如 "击杀 野狼妖（1/2）"；全部达成返回 "可回报"
func next_objective_hint(quest_id: String) -> String:
	var view := get_quest_view(quest_id)
	if view.is_empty():
		return ""
	for obj: Dictionary in view["objectives"]:
		if int(obj["cur"]) < int(obj["cap"]):
			return "%s %s（%d/%d）" % [obj["type"], obj["target_id"], obj["cur"], obj["cap"]]
	return "可回报"


## 目标 target_id → 显示名（按 ID 前缀路由到对应表，避免跨表探测产生未命中告警）
## 注意 Resource.get(property) 只接受 1 参（无默认值重载），空值回落 target_id
func _display_name_of(target_id: String) -> String:
	if target_id.is_empty():
		return ""
	var table := ""
	if target_id.begins_with("char_"):
		table = "characters"
	elif target_id.begins_with("region_"):
		table = "regions"
	elif target_id.begins_with("item_"):
		table = "items"
	if table.is_empty():
		return target_id
	var entry: Variant = DataManager.get_entry(table, target_id)
	if entry != null:
		var display: Variant = entry.get("display_name")
		if display != null and not String(display).is_empty():
			return String(display)
	return target_id


## next_quests 链式接取：requirements 满足才自动接（完成 → 回镇对话承接的体验）
func _chain_next_quests(data: QuestData) -> void:
	for next_id: String in data.next_quests:
		var next := DataManager.get_entry("quests", next_id) as QuestData
		if next == null:
			push_warning("[Quest] 后续任务数据不存在 %s" % next_id)
			continue
		if not next.requirements.is_empty() and not ConditionEvaluator.check(next.requirements, self):
			print("[Quest] 后续任务 %s 接取条件不满足，未自动接取" % next_id)
			continue
		accept_quest(next_id)


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
	return obj.get("type", "") in SUPPORTED_TYPES


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


## 快照式设置进度（收集/修炼）：变化才写，避免高频信号刷屏
func _set_progress(quest_id: String, idx: int, value: int) -> void:
	var qs: Dictionary = quest_states[quest_id]
	var progress: Dictionary = qs["progress"]
	var now := int(progress.get(idx, 0))
	if now == value:
		return
	progress[idx] = value
	var data := DataManager.get_entry("quests", quest_id) as QuestData
	var cap := int(data.objectives[idx].get("count", 1)) if data != null and idx < data.objectives.size() else value
	print("[Quest] 目标快照 %s：%d/%d" % [quest_id, value, cap])
	EventBus.quest_progress_changed.emit(quest_id)


## 统一目标遍历：filter(obj) 命中则推进（事件驱动型目标共用）
func _advance_matching(filter: Callable) -> void:
	for quest_id: String in quest_states:
		if not is_active(quest_id):
			continue
		var data := DataManager.get_entry("quests", quest_id) as QuestData
		if data == null:
			continue
		for idx in range(data.objectives.size()):
			var obj: Dictionary = data.objectives[idx]
			if filter.call(obj):
				_advance(quest_id, obj, idx)


# --- EventBus 推进源 ---

func _on_region_entered(region_id: String) -> void:
	_advance_matching(func(obj): return obj.get("type", "") == "到达" and String(obj.get("target_id", "")) == region_id)


func _on_enemy_died(enemy_id: String, _region_id: String) -> void:
	_advance_matching(func(obj): return obj.get("type", "") == "战斗" and String(obj.get("target_id", "")) == enemy_id)


## 「对话」目标语义 = 与目标 NPC 交谈过（交互即计数，回报对话点击时已满足）
func _on_npc_interacted(npc_id: String, _dialogue_id: String) -> void:
	_advance_matching(func(obj): return obj.get("type", "") == "对话" and String(obj.get("target_id", "")) == npc_id)


## 「选择」目标：target_id = 对话/事件源 id，params.choice_index 可限定具体选项
func _on_dialogue_choice_made(source_id: String, choice_index: int) -> void:
	_advance_matching(func(obj): return _match_choice(obj, source_id, choice_index))


func _match_choice(obj: Dictionary, source_id: String, choice_index: int) -> bool:
	if obj.get("type", "") != "选择" or String(obj.get("target_id", "")) != source_id:
		return false
	var params: Dictionary = obj.get("params", {})
	if params.has("choice_index") and int(params.get("choice_index")) != choice_index:
		return false
	return true


## 「收集」目标：持有量快照（增删都触发，允许回落）
func _on_item_changed(_item_id: String, _count: int) -> void:
	_sync_collect_objectives()


## 「修炼」目标：境界/层数达标即置满（早退缓存防打坐高频空转）
func _on_cultivation_state_changed() -> void:
	if not _has_cultivation_obj:
		return
	var cm := _find_group("cultivation_manager")
	if cm == null:
		return
	for quest_id: String in quest_states:
		if not is_active(quest_id):
			continue
		var data := DataManager.get_entry("quests", quest_id) as QuestData
		if data == null:
			continue
		for idx in range(data.objectives.size()):
			var obj: Dictionary = data.objectives[idx]
			if obj.get("type", "") != "修炼":
				continue
			if _cultivation_reached(obj.get("params", {}), cm):
				_set_progress(quest_id, idx, int(obj.get("count", 1)))


func _cultivation_reached(params: Dictionary, cm: Node) -> bool:
	if cm.realm_index < int(params.get("realm_index", 99)):
		return false
	if params.has("realm_layer") and cm.realm_layer < int(params.get("realm_layer", 0)):
		return false
	return true


## 收集目标快照重算（接取/读档/背包变化三处调用）
func _sync_collect_objectives() -> void:
	var im := _find_group("inventory_manager")
	var inv: Inventory = im.inventory if im != null else null
	for quest_id: String in quest_states:
		if not is_active(quest_id):
			continue
		var data := DataManager.get_entry("quests", quest_id) as QuestData
		if data == null:
			continue
		for idx in range(data.objectives.size()):
			var obj: Dictionary = data.objectives[idx]
			if obj.get("type", "") != "收集":
				continue
			var cap := int(obj.get("count", 1))
			var held := inv.get_count(String(obj.get("target_id", ""))) if inv != null else 0
			_set_progress(quest_id, idx, mini(held, cap))


## 修炼目标缓存重算（接取/读档两处调用）
func _recalc_cultivation_cache() -> void:
	_has_cultivation_obj = false
	for quest_id: String in quest_states:
		if not is_active(quest_id):
			continue
		var data := DataManager.get_entry("quests", quest_id) as QuestData
		if data == null:
			continue
		for obj: Dictionary in data.objectives:
			if obj.get("type", "") == "修炼":
				_has_cultivation_obj = true
				return


func _find_group(group: String) -> Node:
	var nodes: Array = get_tree().get_nodes_in_group(group)
	return nodes[0] if nodes.size() > 0 else null


# --- 存档（quests 段） ---

func get_save_section() -> String:
	return "quests"


func get_save_state() -> Dictionary:
	return {"quest_states": quest_states.duplicate(true)}


func load_save_state(state: Dictionary) -> void:
	# 归一化：容忍旧档缺字段（status/progress 补默认），SAVE_VERSION 不升
	var saved: Dictionary = state.get("quest_states", {})
	quest_states.clear()
	for quest_id: String in saved:
		var qs: Dictionary = saved[quest_id]
		quest_states[quest_id] = {
			"status": String(qs.get("status", "active")),
			"progress": qs.get("progress", {}),
		}
	_recalc_cultivation_cache()
	_sync_collect_objectives()  # 背包段应用顺序不定，此处兜底（背包广播也会再触发一次）
