## 区域场景基类（阶段3）：按 RegionData 生成实体（NPC/敌人/资源点）+ 占位地形 + 传送门
## 子类场景只需导出 region_id 与摆放 Portal；像素坐标 = location.position × TILE_SIZE
## 已死敌人/已采资源由 WorldManager 传入确定性 key 列表，重建时跳过/保持已采态
class_name RegionScene
extends Node2D

signal portal_entered(target_region: String, entry_location: String)

const TILE_SIZE := 64
const NPC_SCENE := preload("res://scenes/characters/Npc.tscn")
const ENEMY_SCENE := preload("res://scenes/characters/Enemy.tscn")
const RESOURCE_NODE_SCENE := preload("res://scenes/characters/ResourceNode.tscn")

@export var region_id := ""

var region_data: RegionData = null
var player_spawn := Vector2.ZERO  # 区域默认出生点（切区域/复活用）

@onready var _entities: Node2D = $Entities


## WorldManager 实例化后调用；dead_keys/harvested_keys 为确定性 key 集合
func setup(data: RegionData, dead_keys: Array, harvested_keys: Array) -> void:
	region_data = data
	_build_terrain_placeholder()
	var first := true
	for loc: Dictionary in data.locations:
		var pos := Vector2(Vector2i(loc["position"])) * TILE_SIZE
		if first:
			player_spawn = pos
			first = false
		_spawn_encounters(loc, pos, dead_keys)
		_spawn_resource_points(loc, pos, harvested_keys)
	_setup_portals()


func _build_terrain_placeholder() -> void:
	# 占位地形：区域底色 + 以各 location 为中心的浅色地标块（美术就绪后换 TileMap）
	var ground := Polygon2D.new()
	ground.name = "Ground"
	var map_size := Vector2(1600, 1200)
	ground.polygon = PackedVector2Array([Vector2.ZERO, Vector2(map_size.x, 0), map_size, Vector2(0, map_size.y)])
	ground.color = Color(0.32, 0.3, 0.28) if region_data.terrain == "山地" else Color(0.42, 0.46, 0.34)
	ground.z_index = -10
	add_child(ground)
	for loc: Dictionary in region_data.locations:
		var landmark := Polygon2D.new()
		landmark.polygon = PackedVector2Array([Vector2(-48, -48), Vector2(48, -48), Vector2(48, 48), Vector2(-48, 48)])
		landmark.color = Color(1, 1, 1, 0.08)
		landmark.position = Vector2(Vector2i(loc["position"])) * TILE_SIZE
		landmark.z_index = -9
		add_child(landmark)


func _spawn_encounters(loc: Dictionary, pos: Vector2, dead_keys: Array) -> void:
	for char_id: String in loc.get("encounters", []):
		var data := DataManager.get_entry("characters", char_id) as CharacterData
		if data == null:
			push_warning("[RegionScene] 缺少角色数据 %s，跳过" % char_id)
			continue
		var loc_id := String(loc["id"])
		var key := loc_id + "_" + char_id
		var spawn_pos := pos + Vector2(0, 48)
		if data.character_type == CharacterData.CharacterType.ENEMY:
			if key in dead_keys:
				continue  # 存档记录已死，不重建
			var enemy := ENEMY_SCENE.instantiate()
			enemy.setup(char_id, region_id)
			enemy.position = spawn_pos
			_entities.add_child(enemy)
		else:
			var npc := NPC_SCENE.instantiate()
			npc.setup(char_id, data.display_name)
			npc.position = spawn_pos
			_entities.add_child(npc)


func _spawn_resource_points(loc: Dictionary, pos: Vector2, harvested_keys: Array) -> void:
	# 占位语义：resources 值（丰度）即该地点资源点生成数
	var loc_id := String(loc["id"])
	var index := 0
	for item_id: String in loc.get("resources", {}):
		var amount := int(loc["resources"][item_id])
		for i in range(amount):
			var key := "%s_%s_%d" % [loc_id, item_id, index]
			var node := RESOURCE_NODE_SCENE.instantiate()
			node.setup(item_id, key, key in harvested_keys)
			node.position = pos + Vector2(56 + (index % 3) * 40, -40 + (index / 3) * 40)
			_entities.add_child(node)
			index += 1


func _setup_portals() -> void:
	for portal: Area2D in get_tree().get_nodes_in_group("portal"):
		if not is_ancestor_of(portal):
			continue
		portal.body_entered.connect(_on_portal_body_entered.bind(portal))
		portal.body_exited.connect(_on_portal_body_exited.bind(portal))


func _on_portal_body_entered(body: Node2D, portal: Area2D) -> void:
	if not body.is_in_group("player"):
		return
	if portal.is_queued_for_deletion() or not portal.is_armed():
		return
	portal.disarm()  # 防重入：切区域后由玩家离开门范围重新武装（或区域已 free）
	portal_entered.emit(String(portal.target_region), String(portal.entry_location))


func _on_portal_body_exited(body: Node2D, portal: Area2D) -> void:
	if body.is_in_group("player"):
		portal.rearm()
