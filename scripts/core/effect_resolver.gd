## 效果分发器（阶段3）：统一处理 effects/rewards/choices 的 {target, key, op, value}
## 约定（doc 29 冻结格式的运行时解释，Phase 7 正式化时迁移到效果规则表）：
##   target="player" + key="item:<item_id>" → 背包增减
##   target="quest"  + key=<quest_id>       → 任务接取(op:"accept")/完成回报(op:"report")
##   target="faction:..."/"char:..."/其他   → 阶段5/8 落地，先忽略并日志
## 纯静态无状态；context 由调用方传 self（用于查场景树组），调用方保证数据合法性
class_name EffectResolver


static func apply(effect: Dictionary, context: Node) -> void:
	apply_all([effect], context)


static func apply_all(effects: Array, context: Node) -> void:
	for effect: Dictionary in effects:
		_apply_one(effect, context)


static func _apply_one(effect: Dictionary, context: Node) -> void:
	var target := String(effect.get("target", ""))
	var key := String(effect.get("key", ""))
	var op := String(effect.get("op", ""))
	var value: Variant = effect.get("value", 0)

	match target:
		"player":
			_apply_player(key, op, value, context)
		"quest":
			_apply_quest(key, op, context)
		_:
			# char:/faction:/world/dao_heart.* 等：对应系统落地前忽略
			print("[EffectResolver] 忽略未支持效果（对应系统落地前占位）：%s %s %s" % [target, key, op])


static func _apply_player(key: String, op: String, value: Variant, context: Node) -> void:
	var managers: Array = context.get_tree().get_nodes_in_group("inventory_manager")
	match key:
		"hp":
			var player := _first_player(context)
			if player != null:
				if op == "add":
					player.stats.heal(float(value))
				else:
					player.stats.take_damage(float(value))
			return
		"mp":
			var player2 := _first_player(context)
			if player2 != null:
				player2.stats.restore_mp(float(value))
			return
		"realm_exp":
			var cm := _find_cultivation_manager(context)
			if cm != null:
				cm.gain_realm_exp(float(value), "丹药")
			else:
				push_warning("[EffectResolver] CultivationManager 不在场景树")
			return
		"technique":
			var cm2 := _find_cultivation_manager(context)
			if cm2 != null and op == "learn":
				cm2.learn_technique(String(value))
			return
	if not key.begins_with("item:"):
		push_warning("[EffectResolver] 未支持的 player 效果 key=%s（Phase 4/5 扩展）" % key)
		return
	var item_id := key.trim_prefix("item:")
	if managers.is_empty():
		push_warning("[EffectResolver] InventoryManager 不在场景树")
		return
	match op:
		"add":
			managers[0].inventory.add_item(item_id, int(value))
		"remove":
			managers[0].inventory.remove_item(item_id, int(value))
		_:
			push_warning("[EffectResolver] 未知物品 op=%s" % op)


static func _first_player(context: Node) -> Node:
	var players: Array = context.get_tree().get_nodes_in_group("player")
	return players[0] if players.size() > 0 else null


static func _find_cultivation_manager(context: Node) -> Node:
	var arr: Array = context.get_tree().get_nodes_in_group("cultivation_manager")
	return arr[0] if arr.size() > 0 else null


static func _apply_quest(quest_id: String, op: String, context: Node) -> void:
	var manager := _find_by_group("quest_manager", context)
	if manager == null:
		push_warning("[EffectResolver] QuestManager 不在场景树")
		return
	match op:
		"accept":
			manager.accept_quest(quest_id)
		"report":
			manager.complete_quest(quest_id)
		_:
			push_warning("[EffectResolver] 未知任务 op=%s" % op)


static func _find_by_group(group: String, context: Node) -> Node:
	var nodes: Array = context.get_tree().get_nodes_in_group(group)
	if nodes.is_empty():
		return null
	return nodes[0]
