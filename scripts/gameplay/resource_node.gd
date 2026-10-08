## 资源点（阶段3）：灵草等可采集物，E 采集 → 背包 → 隐藏一段时间后刷新（不持久化，占位）
## node_key 为确定性键（loc_id_item_id），world_state 记已采状态（由 WorldManager 维护）
extends StaticBody2D

const RESPAWN_SECONDS := 60.0

var item_id := ""
var node_key := ""
var harvested := false

@onready var _visual: Polygon2D = $Visual
@onready var _label: Label = $Label
@onready var _shape: CollisionShape2D = $CollisionShape2D


func setup(p_item_id: String, p_node_key: String, p_start_harvested: bool) -> void:
	item_id = p_item_id
	node_key = p_node_key
	harvested = p_start_harvested


func _ready() -> void:
	var data := DataManager.get_entry("items", item_id) as ItemData
	_label.text = data.display_name if data else item_id
	if harvested:
		_set_hidden(true)


## 统一交互接口（与 Npc 一致）
func interact() -> void:
	if harvested:
		return
	harvested = true
	var managers := get_tree().get_nodes_in_group("inventory_manager")
	if managers.is_empty():
		push_warning("[ResourceNode] InventoryManager 不在场景树")
		return
	managers[0].inventory.add_item(item_id, 1)
	print("[ResourceNode] 采集 %s（%s）" % [item_id, node_key])
	_set_hidden(true)
	get_tree().create_timer(RESPAWN_SECONDS).timeout.connect(_respawn)


func _respawn() -> void:
	harvested = false
	_set_hidden(false)
	print("[ResourceNode] %s 已刷新" % node_key)


func _set_hidden(hidden_state: bool) -> void:
	_visual.visible = not hidden_state
	_label.visible = not hidden_state
	_shape.set_deferred("disabled", hidden_state)
