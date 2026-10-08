## 敌人（阶段3→4→7）：追击 + 技能优先级 + 状态 + Boss 狂暴 + 掉落
## 技能/元素/掉落全部数据驱动（CharacterData v1.1 敌人字段，ADR-008）；缺数据时降级为纯普攻
class_name Enemy
extends CharacterBody2D

enum State { IDLE, CHASE, ATTACK }

const BOSS_ID := "char_hei_feng_yao_lang_wang"

const LEASH_DIST := 320.0      # 离出生点超过此距离回 idle（脱战）
const ATTACK_RANGE := 52.0
const ATTACK_INTERVAL := 1.2   # 普攻间隔（秒）
const STUCK_TIME := 1.0        # 追击卡住判定时长
const ENRAGE_THRESHOLD := 0.5  # Boss 狂暴血线

var enemy_id := ""
var region_id := ""
var state := State.IDLE
var status := StatusContainer.new()  # 状态容器（灼烧/冻结/破甲/atk_buff）

var max_hp := 100.0
var current_hp := 100.0
var atk := 10.0
var defense := 5.0
var crit := 0.0
var accuracy := 0.85
var evasion := 0.05
var move_speed := 200.0

var _spawn_point := Vector2.ZERO
var _attack_cooldown := 0.0
var _skill_cooldowns: Dictionary = {}  # {skill_id: 剩余秒}
var _stuck_timer := 0.0
var _enraged := false  # Boss 狂暴一次性标记
var _skills: Array = []            # 数据驱动技能表（CharacterData.enemy_skills）
var _element := ""                 # 数据驱动元素（CharacterData.enemy_element）
var _drops: Array = []             # 数据驱动掉落表（CharacterData.drop_table）

@onready var _sense_area: Area2D = $SenseArea
@onready var _name_label: Label = $NameLabel


func setup(p_id: String, p_region_id: String) -> void:
	enemy_id = p_id
	region_id = p_region_id


func _ready() -> void:
	add_to_group("enemies")  # SkillExecutor AOE/玩家自动瞄准的查找入口
	_spawn_point = global_position
	var data := DataManager.get_entry("characters", enemy_id) as CharacterData
	if data != null:
		_name_label.text = data.display_name
		var bs: Dictionary = data.base_stats
		max_hp = float(bs.get("hp", 100.0))
		atk = float(bs.get("atk", 10.0))
		defense = float(bs.get("def", 5.0))
		crit = float(bs.get("crit", 0.0))
		accuracy = float(bs.get("accuracy", 0.85))
		evasion = float(bs.get("evasion", 0.05))
		move_speed = CultivationUtils.move_speed(float(bs.get("speed", 8.0)))
		current_hp = max_hp
		_skills = data.enemy_skills
		_element = data.enemy_element
		_drops = data.drop_table
	else:
		push_warning("Enemy: 缺少数据 %s，用内置占位数值" % enemy_id)
	_sense_area.body_entered.connect(_on_sense_body_entered)
	_sense_area.body_exited.connect(_on_sense_body_exited)


## 敌人元素：数据驱动（克制计算用）
func element_of() -> String:
	return _element


func _physics_process(delta: float) -> void:
	status.tick(delta, self)
	if status.is_frozen():
		velocity = Vector2.ZERO  # 冻结：禁移动/攻击，冷却照走
		return
	match state:
		State.IDLE:
			return
		State.CHASE:
			var player2: Node2D = _player_or_idle()
			if player2 == null:
				return
			_chase(player2, delta)
		State.ATTACK:
			var player3: Node2D = _player_or_idle()
			if player3 == null:
				return
			_attack(player3, delta)


func _player_or_idle() -> Node2D:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		_to_idle()
	return player


func _chase(player: Node2D, delta: float) -> void:
	var to_player := player.global_position - global_position
	# 脱战：目标出视距或自身离出生点过远
	if to_player.length() > _sense_range() or global_position.distance_to(_spawn_point) > LEASH_DIST:
		_to_idle()
		return
	# 攻击窗口 = 普攻距离与最近技能射程的较大者（远程怪可在远处开火）
	if to_player.length() <= _attack_window():
		state = State.ATTACK
		return
	var before := global_position
	velocity = to_player.normalized() * move_speed
	move_and_slide()
	_track_stuck(before, delta)


func _attack(player: Node2D, delta: float) -> void:
	var to_player := player.global_position - global_position
	if to_player.length() > _attack_window() * 1.4:
		state = State.CHASE
		return
	velocity = Vector2.ZERO
	_attack_cooldown -= delta
	for skill_id in _skill_cooldowns:
		_skill_cooldowns[skill_id] = maxf(0.0, float(_skill_cooldowns[skill_id]) - delta)
	# 技能优先（doc 08 §8：不是全部只普攻）；冷却未好则普攻填充
	if _try_cast_skill(player):
		return
	if _attack_cooldown <= 0.0:
		_attack_cooldown = ATTACK_INTERVAL
		if to_player.length() > ATTACK_RANGE:
			return  # 普攻距离外且技能全冷却：继续对峙
		var p_stats := (player as Player).stats
		if CombatFormula.basic_attack_hit(accuracy, p_stats.evasion):
			# 玩家被破甲（狼撕咬）→ 有效防御下降
			var final_def: float = p_stats.defense * player.status.defense_multiplier()
			var damage := CombatFormula.basic_attack_damage(atk * status.attack_multiplier(), final_def, crit)
			p_stats.take_damage(float(damage))
			print("[Enemy] %s 命中玩家，造成 %d 伤害" % [enemy_id, damage])
		else:
			print("[Enemy] %s 攻击未命中" % enemy_id)


## 技能决策：冷却好 + 距离达标 → 经 SkillExecutor 结算（伤害/状态/AOE）
func _try_cast_skill(player: Node2D) -> bool:
	for skill_id: String in _skills:
		if float(_skill_cooldowns.get(skill_id, 0.0)) > 0.0:
			continue
		var skill := DataManager.get_entry("skills", skill_id) as SkillData
		if skill == null:
			continue
		if player.global_position.distance_to(global_position) > skill.cast_range:
			continue
		# 嚎叫类自体技能距离恒定可放；其余以玩家为目标
		if SkillExecutor.cast(skill, self, player, self):
			_skill_cooldowns[skill_id] = skill.cooldown
			return true
	return false


func _attack_window() -> float:
	var window := ATTACK_RANGE
	for skill_id: String in _skills:
		var skill := DataManager.get_entry("skills", skill_id) as SkillData
		if skill != null and skill.power > 0.0:
			window = maxf(window, skill.cast_range)
	return window


func _track_stuck(before: Vector2, delta: float) -> void:
	# 卡住检测：期望移动但实际位移近零超时 → 放弃追击（占位，Phase 4 换导航）
	if global_position.distance_to(before) < move_speed * delta * 0.1:
		_stuck_timer += delta
		if _stuck_timer >= STUCK_TIME:
			_to_idle()
	else:
		_stuck_timer = 0.0


func _to_idle() -> void:
	state = State.IDLE
	velocity = Vector2.ZERO
	global_position = _spawn_point  # 占位：直接回出生点，Phase 4 做游荡


func _sense_range() -> float:
	var shape := _sense_area.get_node("CollisionShape2D").shape as CircleShape2D
	return shape.radius if shape != null else 200.0


func _on_sense_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and state == State.IDLE:
		state = State.CHASE


func _on_sense_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") and state == State.CHASE:
		# 视野丢失：超出 leash 判定交给 chase 分支处理，这里仅当远离时脱战
		if global_position.distance_to(_spawn_point) > LEASH_DIST:
			_to_idle()


## 玩家普攻入口（Player._find_nearest_attackable 识别 take_damage 方法）
func take_damage(damage: int, _source: Variant = null) -> void:
	if current_hp <= 0.0 or damage <= 0:
		return
	current_hp = maxf(0.0, current_hp - damage)
	print("[Enemy] %s 受到 %d 伤害，剩余 HP %.0f/%.0f" % [enemy_id, damage, current_hp, max_hp])
	if current_hp <= 0.0:
		_die()
		return
	# Boss 狂暴：50% 血线一次性触发（doc 08 §9 简化版，完整 3 阶段 Phase 9）
	if enemy_id == BOSS_ID and not _enraged and current_hp <= max_hp * ENRAGE_THRESHOLD:
		_enraged = true
		atk *= 1.4
		move_speed *= 1.3
		status.apply("atk_buff", 8.0, 0.5)
		print("[Enemy] %s 进入狂暴！" % enemy_id)


func _die() -> void:
	EventBus.enemy_died.emit(enemy_id, region_id)
	# 掉落生成涉及 add_child 物理体：若处于物理回调（如 AOE 链式击杀）需 deferred
	_spawn_drops.call_deferred()
	queue_free()


func _spawn_drops() -> void:
	var parent := get_parent()
	for drop: Dictionary in _drops:
		if randf() > float(drop.get("chance", 1.0)):
			continue
		var pickup := PICKUP_SCENE.instantiate()
		pickup.setup(String(drop["item_id"]), int(drop["count"]))
		pickup.global_position = global_position + Vector2(randf_range(-24, 24), randf_range(16, 40))
		parent.add_child(pickup)


const PICKUP_SCENE := preload("res://scenes/characters/Pickup.tscn")
