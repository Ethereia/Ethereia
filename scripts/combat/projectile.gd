## 投射物（阶段4）：灵气弹等远程技能载体，直线飞行，命中/超时自毁
## 命中即 set_deferred 禁碰撞再 queue_free（防同帧双计）
extends Area2D

const LIFETIME := 2.0

var skill_id := ""
var damage := 0
var direction := Vector2.RIGHT
var speed := 400.0
var source: Node = null
var statuses: Array = []  # 命中附带状态 [{status_id, chance, duration, power}]

var _life := LIFETIME
var _hit_done := false


func setup(p_skill_id: String, p_damage: int, p_direction: Vector2, p_source: Node, p_statuses: Array) -> void:
	skill_id = p_skill_id
	damage = p_damage
	direction = p_direction.normalized()
	source = p_source
	statuses = p_statuses


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	_life -= delta
	if _life <= 0.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if _hit_done or not body.is_in_group("enemies"):
		return
	_hit_done = true
	if body.has_method("take_damage"):
		body.take_damage(damage, source)
		print("[Projectile] %s 命中 %s，造成 %d 伤害" % [skill_id, body.name, damage])
	if "status" in body:
		for effect: Dictionary in statuses:
			if randf() > float(effect.get("chance", 1.0)):
				continue
			body.status.apply(String(effect["status_id"]), float(effect.get("duration", 3.0)), float(effect.get("power", 1.0)))
	$CollisionShape2D.set_deferred("disabled", true)
	queue_free()
