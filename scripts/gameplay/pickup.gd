## 掉落拾取物（阶段3）：Area2D，玩家触碰自动进背包后消失
extends Area2D

var item_id := ""
var count := 1

@onready var _label: Label = $Label


func setup(p_item_id: String, p_count: int) -> void:
	item_id = p_item_id
	count = p_count


func _ready() -> void:
	var data := DataManager.get_entry("items", item_id) as ItemData
	_label.text = "%s×%d" % [data.display_name if data else item_id, count]
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	var managers := get_tree().get_nodes_in_group("inventory_manager")
	if managers.is_empty():
		push_warning("[Pickup] InventoryManager 不在场景树，掉落物保留")
		return
	managers[0].inventory.add_item(item_id, count)
	print("[Pickup] 拾取 %s×%d" % [item_id, count])
	queue_free()
