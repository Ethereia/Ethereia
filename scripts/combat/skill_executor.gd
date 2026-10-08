## 技能执行器（阶段4）：SkillData → 运行时结算的统一入口，纯静态
## 职责：资源校验（mp）→ 按类型分发（SINGLE/CONTROL/AOE/DEFENSE）→ 伤害走 CombatFormula.skill_damage → 状态走 StatusContainer.apply
## 宿主（host）= 施法者节点；目标（target）= 敌我节点（自动瞄准/选中）
## 调用方负责冷却（PlayerSkillController / enemy.gd 冷却表），本类不管 CD
class_name SkillExecutor


## 施放入口。返回 false = 资源不足/数据缺失（调用方不进入冷却）
static func cast(skill: SkillData, caster: Node, target: Node2D, host: Node) -> bool:
	if skill == null:
		return false
	# 法术技能耗蓝（决议#2 成本模型；近战技能 stamina 由 Phase 5 接入）
	if skill.mp_cost > 0:
		var stats: Variant = caster.get("stats")
		if stats == null or not stats.spend_mp(float(skill.mp_cost)):
			return false

	var atk_power := _scaling_power(skill, caster)
	var atk_element := _caster_element(caster)
	var def_element := _target_element(target)

	match skill.skill_type:
		SkillData.SkillType.SINGLE:
			_cast_damage_skill(skill, caster, target, host, atk_power, atk_element, def_element)
		SkillData.SkillType.CONTROL:
			_cast_damage_skill(skill, caster, target, host, atk_power, atk_element, def_element)
		SkillData.SkillType.AOE:
			_cast_aoe_skill(skill, caster, host, atk_power, atk_element)
		SkillData.SkillType.DEFENSE:
			_cast_support_skill(skill, caster, host)
		_:
			push_warning("[SkillExecutor] 未支持的技能类型 %s（Phase 5+ 扩展）" % skill.id)
			return false
	return true


## 伤害/控制类：即时单体结算（灵气弹由调用方改为投射物命中时调 take_damage）
static func _cast_damage_skill(skill: SkillData, caster: Node, target: Node2D, _host: Node, atk_power: float, atk_element: String, def_element: String) -> void:
	if target == null:
		return
	var damage := CombatFormula.skill_damage(skill.power, atk_power, atk_element, def_element, _target_defense(target), _target_crit(caster))
	if target.has_method("take_damage"):
		target.take_damage(damage, caster)
	_apply_statuses(skill, target)
	print("[Skill] %s 命中 %s，造成 %d 伤害" % [skill.display_name, target.name, damage])


## AOE：玩家施放 → 半径内全部敌人；敌人施放 → 仅结算玩家（不误伤友军）
static func _cast_aoe_skill(skill: SkillData, caster: Node, host: Node, atk_power: float, atk_element: String) -> void:
	var caster_pos: Vector2 = caster.global_position
	var victims: Array[Node2D] = []
	if caster.is_in_group("enemies"):
		var player := host.get_tree().get_first_node_in_group("player") as Node2D
		if player != null and player.global_position.distance_to(caster_pos) <= skill.aoe_radius:
			victims.append(player)
	else:
		for node in host.get_tree().get_nodes_in_group("enemies"):
			var node2d := node as Node2D
			if node2d != null and node2d.global_position.distance_to(caster_pos) <= skill.aoe_radius:
				victims.append(node2d)
	for victim: Node2D in victims:
		var damage := CombatFormula.skill_damage(skill.power, atk_power, atk_element, _target_element(victim), _target_defense(victim), _target_crit(caster))
		if victim.has_method("take_damage"):
			victim.take_damage(damage, caster)
		_apply_statuses(skill, victim)
		print("[Skill] %s(AOE) 命中 %s，造成 %d 伤害" % [skill.display_name, victim.name, damage])


## 支援类：回春=heal(power)；嚎叫=status_effects 里的 atk_buff 施于自身
static func _cast_support_skill(skill: SkillData, caster: Node, host: Node) -> void:
	var stats: Variant = caster.get("stats")
	if skill.power > 0.0 and stats != null:
		stats.heal(skill.power)
		print("[Skill] %s 恢复 %d 气血" % [skill.display_name, int(skill.power)])
	_apply_statuses(skill, caster)


## 施加技能附带状态（chance 判定 + 宿主 StatusContainer）
static func _apply_statuses(skill: SkillData, victim: Node) -> void:
	if not "status" in victim:
		return
	for effect: Dictionary in skill.status_effects:
		if randf() > float(effect.get("chance", 1.0)):
			continue
		victim.status.apply(String(effect["status_id"]), float(effect.get("duration", 3.0)), float(effect.get("power", 1.0)))


## scaling_stats：取施法者第一缩放属性（m_atk/atk），空则 1.0
static func _scaling_power(skill: SkillData, caster: Node) -> float:
	if skill.scaling_stats.is_empty():
		return 1.0
	var stats: Variant = caster.get("stats")
	if stats == null:
		return 1.0
	var stat_name := String(skill.scaling_stats[0])
	return float(stats.get(stat_name)) if stat_name in stats else 1.0


## 施法者元素：玩家取主灵根第一键；敌人由 ENEMY_ELEMENT 映射（enemy.gd 提供 element_of）
static func _caster_element(caster: Node) -> String:
	if caster.has_method("element_of"):
		return String(caster.element_of())
	var roots: Variant = caster.get("spirit_roots")
	if roots != null and roots is Dictionary and roots.size() > 0:
		return String(roots.keys()[0])
	return ""


static func _target_element(target: Node) -> String:
	if target.has_method("element_of"):
		return String(target.element_of())
	return ""


static func _target_defense(target: Node) -> float:
	var base := float(target.get("defense")) if "defense" in target else 0.0
	# 目标被破甲 → 有效防御下降
	if "status" in target:
		base *= target.status.defense_multiplier()
	return base


static func _target_crit(caster: Node) -> float:
	return float(caster.get("crit")) if "crit" in caster else 0.0
