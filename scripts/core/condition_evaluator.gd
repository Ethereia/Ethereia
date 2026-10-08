## 条件求值器（阶段7）：统一处理 conditions/requirements 的 {key, op, value}
## 与 EffectResolver 平行的静态无状态类（职责分离：效果应用 vs 条件判定）
## key 命名空间：
##   player.realm_index / player.realm_layer ← CultivationManager
##   quest.<quest_id> → 三态字符串 "none"/"active"/"completed"
##   world.<flag> ← WorldManager 标志字典；特殊 key world.region = 当前区域 id
##   item.<item_id> ← InventoryManager 持有量
## op：>= / <= / == / !=；空 conditions 数组恒为 true
class_name ConditionEvaluator


## conditions 为空或非数组（旧占位空字典等）恒为 true
static func check(conditions: Variant, context: Node) -> bool:
	if not (conditions is Array):
		return true
	for condition: Dictionary in conditions:
		if not eval_one(condition, context):
			return false
	return true


static func eval_one(condition: Dictionary, context: Node) -> bool:
	var key := String(condition.get("key", ""))
	var op := String(condition.get("op", ""))
	var expected: Variant = condition.get("value", "")
	var actual: Variant = resolve_key(key, context)
	if actual == null:
		return false
	match op:
		">=":
			return _cmp_num(actual, expected) >= 0
		"<=":
			return _cmp_num(actual, expected) <= 0
		"==":
			return actual == expected
		"!=":
			return actual != expected
		_:
			push_warning("[ConditionEvaluator] 未知 op=%s（key=%s）" % [op, key])
			return false


## 按 key 前缀路由到对应系统；无法解析返回 null（判定为 false）
static func resolve_key(key: String, context: Node) -> Variant:
	if key.begins_with("player."):
		var field := key.trim_prefix("player.")
		var cm := _find(context, "cultivation_manager")
		if cm == null:
			return null
		match field:
			"realm_index":
				return cm.realm_index
			"realm_layer":
				return cm.realm_layer
			_:
				return null
	if key.begins_with("quest."):
		var quest_id := key.trim_prefix("quest.")
		var qm := _find(context, "quest_manager")
		if qm == null:
			return null
		return qm.quest_state_of(quest_id)
	if key.begins_with("world."):
		var flag := key.trim_prefix("world.")
		var wm := _find(context, "world_manager")
		if wm == null:
			return null
		if flag == "region":
			return wm.current_region_id
		return wm.get_world_flag(flag)
	if key.begins_with("item."):
		var item_id := key.trim_prefix("item.")
		var im := _find(context, "inventory_manager")
		if im == null:
			return null
		return im.inventory.get_count(item_id)
	return null


## 数值比较：两侧均可转 float 才比较，否则视为不等（返回一个不可能满足 >=/>=0 的哨兵）
static func _cmp_num(actual: Variant, expected: Variant) -> int:
	if not (actual is int or actual is float) or not (expected is int or expected is float):
		return -1
	var a := float(actual)
	var b := float(expected)
	if a < b:
		return -1
	if a > b:
		return 1
	return 0


static func _find(context: Node, group: String) -> Node:
	var nodes: Array = context.get_tree().get_nodes_in_group(group)
	return nodes[0] if nodes.size() > 0 else null
