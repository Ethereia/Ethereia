## 玩家技能控制器（阶段4）：槽位/冷却/施法入口，挂 Player 子节点
## skill_1=灵气弹（投射物）、skill_2=青藤缠（控制）、skill_3=回春术（自疗）
## 法术走 mp；自动瞄准最近敌人，无目标时灵气弹按面朝方向、其余不施放
extends Node

const SKILL_SLOTS := {
	1: "skill_ling_qi_dan",
	2: "skill_qing_teng_chan",
	3: "skill_hui_chun_shu",
}
const PROJECTILE_SKILL := "skill_ling_qi_dan"
const PROJECTILE_SCENE := preload("res://scenes/combat/Projectile.tscn")

var _cooldowns: Dictionary = {}  # {skill_id: 剩余秒}

@onready var _player: Player = get_parent()


func _process(delta: float) -> void:
	for skill_id in _cooldowns:
		_cooldowns[skill_id] = maxf(0.0, float(_cooldowns[skill_id]) - delta)


func _unhandled_input(event: InputEvent) -> void:
	for slot: int in SKILL_SLOTS:
		if event.is_action_pressed("skill_%d" % slot):
			try_cast(slot)


## 施法：校验 CD/技能数据/目标 → 结算 → 进入冷却
func try_cast(slot: int) -> bool:
	var skill_id: String = SKILL_SLOTS.get(slot, "")
	if skill_id.is_empty() or float(_cooldowns.get(skill_id, 0.0)) > 0.0:
		return false
	var skill := DataManager.get_entry("skills", skill_id) as SkillData
	if skill == null:
		push_warning("[SkillCtl] 技能数据缺失 %s" % skill_id)
		return false

	var target := _find_nearest_enemy(skill.cast_range)
	if skill.id == PROJECTILE_SKILL:
		if not _fire_projectile(skill, target):
			return false
	else:
		var need_target: bool = skill.skill_type != SkillData.SkillType.DEFENSE
		if need_target and target == null:
			return false
		if not SkillExecutor.cast(skill, _player, target, _player):
			return false

	_cooldowns[skill_id] = skill.cooldown
	return true


## 灵气弹：发射投射物（伤害发射时按目标预计算，含克制）
func _fire_projectile(skill: SkillData, target: Node2D) -> bool:
	if not _player.stats.spend_mp(float(skill.mp_cost)):
		return false
	var direction := Vector2.RIGHT
	var damage := 0
	if target != null:
		direction = (target.global_position - _player.global_position).normalized()
		var atk_power: float = skill.power if skill.scaling_stats.is_empty() else float(_player.stats.get(String(skill.scaling_stats[0])))
		var def_element: String = String(target.element_of()) if target.has_method("element_of") else ""
		damage = CombatFormula.skill_damage(skill.power, atk_power, skill.element, def_element, _target_def(target), _player.stats.crit)
	else:
		# 无目标：朝最后移动方向发射（伤害按无元素/无防御估算，仅视觉占位）
		return false
	var projectile := PROJECTILE_SCENE.instantiate()
	projectile.setup(skill.id, damage, direction, _player, skill.status_effects)
	projectile.global_position = _player.global_position + direction * 24.0
	_player.get_parent().add_child(projectile)
	return true


func _target_def(target: Node2D) -> float:
	return float(target.get("defense")) if "defense" in target else 0.0


func _find_nearest_enemy(max_range: float) -> Node2D:
	var nearest: Node2D = null
	var nearest_dist := max_range
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node2D
		if enemy == null or not enemy.has_method("take_damage"):
			continue
		var dist: float = enemy.global_position.distance_to(_player.global_position)
		if dist <= nearest_dist:
			nearest_dist = dist
			nearest = enemy
	return nearest


## HUD 数据源：剩余冷却比例 0~1（1=刚施放）
func get_cd_ratio(slot: int) -> float:
	var skill_id: String = SKILL_SLOTS.get(slot, "")
	if skill_id.is_empty():
		return 0.0
	var skill := DataManager.get_entry("skills", skill_id) as SkillData
	if skill == null:
		return 0.0
	return clampf(float(_cooldowns.get(skill_id, 0.0)) / skill.cooldown, 0.0, 1.0)


func get_remaining(slot: int) -> float:
	return float(_cooldowns.get(SKILL_SLOTS.get(slot, ""), 0.0))
