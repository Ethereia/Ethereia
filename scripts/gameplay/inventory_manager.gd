## 背包管理器（阶段3）：背包唯一持有点 + 接管存档 inventory 段
## 挂在 Game 下常驻（非 autoload：单场景游戏不需要跨场景单例）
class_name InventoryManager
extends Node

var inventory := Inventory.new()


func _ready() -> void:
	add_to_group("savable")
	add_to_group("inventory_manager")  # EffectResolver / Pickup / ResourceNode 经此组查背包


func get_save_section() -> String:
	return "inventory"


func get_save_state() -> Dictionary:
	return {"items": inventory.items.duplicate(true)}


func load_save_state(state: Dictionary) -> void:
	var saved: Dictionary = state.get("items", {})
	inventory.items.clear()
	for item_id: String in saved:
		inventory.items[item_id] = int(saved[item_id])
	EventBus.item_added.emit("", 0)  # 广播刷新（批量）
