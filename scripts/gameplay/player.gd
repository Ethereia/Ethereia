## 玩家节点（Phase 2）：移动 + 自动普攻 + 接管 player_state 存档段
## 职责边界：物理/输入编排在此；纯数值在 PlayerStats；伤害公式在 CombatFormula
class_name Player
extends CharacterBody2D

const PLAYER_DATA_ID := "char_player_default"  # 捉人流程落地后由存档角色 id 替代

var stats := PlayerStats.new()
var status := StatusContainer.new()  # 状态容器（灼烧/冻结/破甲等）

@onready var _attack_range: Area2D = $AttackRange
@onready var _attack_timer: Timer = $AttackTimer
@onready var _interact_range: Area2D = $InteractRange
@onready var _skill_controller: Node = $SkillController


func _ready() -> void:
	add_to_group("player")
	add_to_group("savable")  # 接管 game.gd 遗留的 player_state 段
	var data := DataManager.get_entry("characters", PLAYER_DATA_ID) as CharacterData
	if data == null:
		push_error("Player: 缺少玩家角色数据 %s" % PLAYER_DATA_ID)
	else:
		stats.setup(data)
	_attack_timer.timeout.connect(_on_attack_tick)
	# HUD 可能晚于本节点 ready：初始化完成后补发一次属性信号供其拉取
	EventBus.player_stats_changed.emit()


## 玩家元素：主灵根第一键（SkillExecutor 克制计算用）
func element_of() -> String:
	if stats.data != null and not stats.data.spirit_roots.is_empty():
		return String(stats.data.spirit_roots.keys()[0])
	return ""


func _physics_process(delta: float) -> void:
	status.tick(delta, self)
	# 打坐中禁移（查管理器组，不持引用）
	var managers := get_tree().get_nodes_in_group("cultivation_manager")
	if managers.size() > 0 and bool(managers[0].get("meditating")):
		velocity = Vector2.ZERO
		return
	if status.is_frozen():
		velocity = Vector2.ZERO  # 冻结：禁移动（攻击 CD 照走，普攻 tick 不在物理帧）
		return
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = dir * CultivationUtils.move_speed(stats.base_speed)
	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_try_interact()


## E 交互：取交互范围内最近的可交互体（Npc/ResourceNode 统一 interact() 接口）
func _try_interact() -> void:
	var nearest: Node2D = null
	var nearest_dist := INF
	for body in _interact_range.get_overlapping_bodies():
		if body == self or not body.has_method("interact"):
			continue
		var dist := global_position.distance_to(body.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = body
	if nearest != null:
		nearest.interact()


## 自动普攻（doc 08 §1）：攻击间隔到点 → 取攻击范围内最近可攻击目标 → 走公式
func _on_attack_tick() -> void:
	var target := _find_nearest_attackable()
	if target == null:
		return
	var target_def := float(target.get("defense")) if "defense" in target else 0.0
	if not CombatFormula.basic_attack_hit(stats.accuracy, stats.evasion):
		print("[Player] 普攻未命中 %s" % target.name)
		return
	var damage := CombatFormula.basic_attack_damage(stats.atk, target_def, stats.crit)
	target.take_damage(damage, self)


func _find_nearest_attackable() -> Node2D:
	var nearest: Node2D = null
	var nearest_dist := INF
	for body in _attack_range.get_overlapping_bodies():
		if body == self or not body.has_method("take_damage"):
			continue
		var dist := global_position.distance_to(body.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = body
	return nearest


# --- 存档（doc 16：只存状态，静态定义由 DataManager 按 id 重建） ---

func get_save_section() -> String:
	return "player_state"


func get_save_state() -> Dictionary:
	return {
		"char_id": PLAYER_DATA_ID,
		"hp": stats.current_hp,
		"mp": stats.current_mp,
		"pos_x": global_position.x,
		"pos_y": global_position.y,
		"current_region": _current_region_id(),
	}


func load_save_state(state: Dictionary) -> void:
	# 用 .get() 带缺省：容忍旧档未知键（如 v1→v2 迁移残留的 skeleton_marker）
	stats.current_hp = float(state.get("hp", stats.max_hp))
	stats.current_mp = float(state.get("mp", stats.max_mp))
	global_position = Vector2(float(state.get("pos_x", 0.0)), float(state.get("pos_y", 0.0)))
	get_tree().paused = false  # 读档强制解除暂停
	EventBus.player_stats_changed.emit()


## 当前区域 id 由 WorldManager 维护（避免 Player 反向持有世界引用）
func _current_region_id() -> String:
	var managers := get_tree().get_nodes_in_group("world_manager")
	return String(managers[0].current_region_id) if managers.size() > 0 else ""
