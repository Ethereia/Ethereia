## 敌人（阶段3）：视野追击 + 攻击间隔 + 掉落拾取，直线追击无导航（Phase 4 完善）
## 受击接口 take_damage 与 Player 普攻闭环衔接；死亡掉落表为代码占位（Phase 7 数据表化）
class_name Enemy
extends CharacterBody2D

enum State { IDLE, CHASE, ATTACK }

## 掉落表占位：{enemy_id: [{item_id, count, chance}]}
const DROP_TABLE := {
	"char_ye_lang_yao": [
		{"item_id": "item_ling_shi", "count": 2, "chance": 1.0},
		{"item_id": "item_ling_cao", "count": 1, "chance": 0.5},
		{"item_id": "item_gong_fa_can_ye", "count": 1, "chance": 0.15},
	],
	"char_hei_feng_dao_fei": [
		{"item_id": "item_ling_shi", "count": 5, "chance": 1.0},
	],
}

const LEASH_DIST := 320.0      # 离出生点超过此距离回 idle（脱战）
const ATTACK_RANGE := 52.0
const ATTACK_INTERVAL := 1.2   # 攻击间隔（秒，占位）
const STUCK_TIME := 1.0        # 追击卡住判定时长

var enemy_id := ""
var region_id := ""
var state := State.IDLE

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
var _stuck_timer := 0.0

@onready var _sense_area: Area2D = $SenseArea
@onready var _name_label: Label = $NameLabel


func setup(p_id: String, p_region_id: String) -> void:
	enemy_id = p_id
	region_id = p_region_id


func _ready() -> void:
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
	else:
		push_warning("Enemy: 缺少数据 %s，用内置占位数值" % enemy_id)
	_sense_area.body_entered.connect(_on_sense_body_entered)
	_sense_area.body_exited.connect(_on_sense_body_exited)


func _physics_process(delta: float) -> void:
	if state == State.IDLE:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		_to_idle()
		return
	match state:
		State.CHASE:
			_chase(player, delta)
		State.ATTACK:
			_attack(player, delta)


func _chase(player: Node2D, delta: float) -> void:
	var to_player := player.global_position - global_position
	# 脱战：目标出视距或自身离出生点过远
	if to_player.length() > _sense_range() or global_position.distance_to(_spawn_point) > LEASH_DIST:
		_to_idle()
		return
	if to_player.length() <= ATTACK_RANGE:
		state = State.ATTACK
		return
	var before := global_position
	velocity = to_player.normalized() * move_speed
	move_and_slide()
	_track_stuck(before, delta)


func _attack(player: Node2D, delta: float) -> void:
	var to_player := player.global_position - global_position
	if to_player.length() > ATTACK_RANGE * 1.4:
		state = State.CHASE
		return
	velocity = Vector2.ZERO
	_attack_cooldown -= delta
	if _attack_cooldown <= 0.0:
		_attack_cooldown = ATTACK_INTERVAL
		var p_stats := (player as Player).stats
		if CombatFormula.basic_attack_hit(accuracy, p_stats.evasion):
			var damage := CombatFormula.basic_attack_damage(atk, p_stats.defense, crit)
			p_stats.take_damage(float(damage))
			print("[Enemy] %s 命中玩家，造成 %d 伤害" % [enemy_id, damage])
		else:
			print("[Enemy] %s 攻击未命中" % enemy_id)


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
	if current_hp <= 0.0:
		return
	current_hp = maxf(0.0, current_hp - damage)
	print("[Enemy] %s 受到 %d 伤害，剩余 HP %.0f/%.0f" % [enemy_id, damage, current_hp, max_hp])
	if current_hp <= 0.0:
		_die()


func _die() -> void:
	EventBus.enemy_died.emit(enemy_id, region_id)
	_spawn_drops()
	queue_free()


func _spawn_drops() -> void:
	var table: Array = DROP_TABLE.get(enemy_id, [])
	var parent := get_parent()
	for drop: Dictionary in table:
		if randf() > float(drop.get("chance", 1.0)):
			continue
		var pickup := PICKUP_SCENE.instantiate()
		pickup.setup(String(drop["item_id"]), int(drop["count"]))
		pickup.global_position = global_position + Vector2(randf_range(-24, 24), randf_range(16, 40))
		parent.add_child(pickup)


const PICKUP_SCENE := preload("res://scenes/characters/Pickup.tscn")
