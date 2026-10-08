## 宗门管理器（阶段6）：临时驻地/建筑建造升级/月结结算/弟子管理 + sect_state 存档段
## Game 子节点（同 InventoryManager 模式）；资源走玩家背包（宗门仓库阶段 8 再拆）
## 工期粒度占位：day 无推进，按 ceil(days/10) 折算月；Phase 8 日历系统回改
## unlock_effects 效果数值在本类常量映射占位（doc 09 语义是解锁门槛）
class_name SectManager
extends Node

const JUELING_ID := "building_ju_ling_zhen"
const RESIDENCE_COST := 50          # 建立临时驻地灵石（占位）
const RECRUIT_COST_LINGSHI := 30    # 招募消耗（占位）
const RECRUIT_COST_LINGCAO := 5

var has_residence := false
var buildings: Dictionary = {}           # {building_id: {level, upgrading, end_year, end_month}}
var disciples: Array[Dictionary] = []    # 运行时生成弟子（序列化为字典数组）
var _maintenance_arrears := false        # 欠缴标记（当月环境失效惩罚）


func _ready() -> void:
	add_to_group("savable")
	add_to_group("sect_manager")
	EventBus.month_changed.connect(_on_month_changed)


## 建立临时驻地（垂直切片 Step 9）：扣灵石 50
func establish_residence() -> bool:
	if has_residence:
		return true
	var inv_m := _first_inventory()
	if inv_m == null or not inv_m.inventory.has_item("item_ling_shi", RESIDENCE_COST):
		print("[Sect] 灵石不足（需 %d），无法建立临时驻地" % RESIDENCE_COST)
		return false
	inv_m.inventory.remove_item("item_ling_shi", RESIDENCE_COST)
	has_residence = true
	print("[Sect] 临时驻地已建立（黑风岭向阳坡）")
	EventBus.sect_state_changed.emit()
	return true


## 建造/升级：校验 → 扣资源 → 写工期（月结到期结算）
func start_construction(building_id: String) -> bool:
	if not has_residence:
		print("[Sect] 需先建立临时驻地")
		return false
	if is_constructing():
		print("[Sect] 已有工程进行中")
		return false
	var data := DataManager.get_entry("buildings", building_id) as BuildingData
	if data == null:
		push_warning("[Sect] 建筑数据缺失 %s" % building_id)
		return false
	var current_level := get_building_level(building_id)
	if current_level >= data.max_level:
		print("[Sect] %s 已满级" % data.display_name)
		return false
	var prestige := int(data.prestige_requirement[current_level]) if current_level < data.prestige_requirement.size() else 0
	if prestige > 0:
		print("[Sect] 声望不足（需 %d），暂无法升级" % prestige)
		return false
	var inv_m := _first_inventory()
	if inv_m == null:
		return false
	var costs: Dictionary = data.upgrade_cost[current_level]
	for item_id: String in costs:
		if not inv_m.inventory.has_item(item_id, int(costs[item_id])):
			print("[Sect] 资源不足：%s ×%d" % [item_id, int(costs[item_id])])
			return false
	for item_id: String in costs:
		inv_m.inventory.remove_item(item_id, int(costs[item_id]))
	var days: int = data.upgrade_time_days[current_level]
	var months := ceili(days / 10.0)  # 工期折算月（占位）
	var tm := get_tree().get_first_node_in_group("time_manager")
	var end_year: int = TimeManager.year
	var end_month: int = TimeManager.month + months
	while end_month > 12:
		end_month -= 12
		end_year += 1
	buildings[building_id] = {"level": current_level, "upgrading": true, "end_year": end_year, "end_month": end_month}
	print("[Sect] %s 开工（%d→%d 级，工期约 %d 月）" % [data.display_name, current_level, current_level + 1, months])
	EventBus.sect_state_changed.emit()
	return true


func is_constructing() -> bool:
	for building_id: String in buildings:
		if bool(buildings[building_id].get("upgrading", false)):
			return true
	return false


func get_building_level(building_id: String) -> int:
	return int(buildings.get(building_id, {}).get("level", 0))


## 环境因子（CultivationManager 突破因子）：0.5 + 0.1×聚灵阵等级；无驻地/欠缴 0.5
func get_environment_factor() -> float:
	if not has_residence or _maintenance_arrears:
		return 0.5
	return 0.5 + 0.1 * get_building_level(JUELING_ID)


## 突破环境加成（聚灵阵 lv3 起）
func get_breakthrough_bonus() -> float:
	if not has_residence or _maintenance_arrears:
		return 0.0
	var level := get_building_level(JUELING_ID)
	return 0.0 if level < 3 else (level - 2) * 0.03


## 弟子上限：基础 1 + 聚灵阵 lv5 额外 1（unlock_effects extra_disciple_slot 映射）
func get_disciple_cap() -> int:
	return 1 + (1 if get_building_level(JUELING_ID) >= 5 else 0)


## 招募弟子（随机生成）：上限与资源校验
func recruit_disciple() -> bool:
	if not has_residence:
		print("[Sect] 需先建立临时驻地")
		return false
	if disciples.size() >= get_disciple_cap():
		print("[Sect] 弟子已满（%d/%d），需提升聚灵阵等级" % [disciples.size(), get_disciple_cap()])
		return false
	var inv_m := _first_inventory()
	if inv_m == null or not inv_m.inventory.has_item("item_ling_shi", RECRUIT_COST_LINGSHI) or not inv_m.inventory.has_item("item_ling_cao", RECRUIT_COST_LINGCAO):
		print("[Sect] 招募资源不足（灵石×%d + 灵草×%d）" % [RECRUIT_COST_LINGSHI, RECRUIT_COST_LINGCAO])
		return false
	inv_m.inventory.remove_item("item_ling_shi", RECRUIT_COST_LINGSHI)
	inv_m.inventory.remove_item("item_ling_cao", RECRUIT_COST_LINGCAO)
	disciples.append(DiscipleGenerator.generate())
	var d: Dictionary = disciples[-1]
	print("[Sect] 招募弟子：%s（%s，潜力 %d 星）" % [d["name"], CultivationUtils.realm_display(d["realm_index"], d["realm_layer"]), d["potential"]])
	EventBus.sect_state_changed.emit()
	return true


## 月结：工期结算 → upkeep → 弟子挂机修炼
func _on_month_changed(year: int, month: int) -> void:
	if not has_residence:
		return
	# 1) 工期到期
	for building_id: String in buildings:
		var b: Dictionary = buildings[building_id]
		if bool(b.get("upgrading", false)) and int(b["end_year"]) == year and int(b["end_month"]) == month:
			b["level"] = int(b["level"]) + 1
			b["upgrading"] = false
			var data := DataManager.get_entry("buildings", building_id) as BuildingData
			print("[Sect] %s 建成（%d 级）" % [data.display_name if data else building_id, b["level"]])
	# 2) upkeep：灵石 × 等级；不足当月环境失效
	var inv_m := _first_inventory()
	var upkeep := get_building_level(JUELING_ID) * int(_jueling_upkeep())
	if upkeep > 0 and inv_m != null:
		if inv_m.inventory.has_item("item_ling_shi", upkeep):
			inv_m.inventory.remove_item("item_ling_shi", upkeep)
			_maintenance_arrears = false
			print("[Sect] 月度维护：灵石 ×%d" % upkeep)
		else:
			_maintenance_arrears = true
			print("[Sect] 灵石不足，聚灵阵维护欠缴——环境加成失效！")
	else:
		_maintenance_arrears = false
	# 3) 弟子挂机修炼
	for d: Dictionary in disciples:
		if randf() < 0.3 + d["potential"] * 0.05:
			if d["realm_layer"] < CultivationConstants.LAYERS_PER_REALM:
				d["realm_layer"] = int(d["realm_layer"]) + 1
				print("[Sect] 弟子 %s 修为精进（%s）" % [d["name"], CultivationUtils.realm_display(d["realm_index"], d["realm_layer"])])
			elif randf() < 0.5:
				d["realm_index"] = mini(int(d["realm_index"]) + 1, CultivationConstants.REALMS.size() - 1)
				d["realm_layer"] = 1
				print("[Sect] 弟子 %s 突破至 %s！" % [d["name"], CultivationUtils.realm_display(d["realm_index"], d["realm_layer"])])
	EventBus.sect_state_changed.emit()


func _jueling_upkeep() -> int:
	var data := DataManager.get_entry("buildings", JUELING_ID) as BuildingData
	return int(data.upkeep.get("item_ling_shi", 1)) if data != null else 1


func _first_inventory() -> Node:
	var arr: Array = get_tree().get_nodes_in_group("inventory_manager")
	return arr[0] if arr.size() > 0 else null


# --- 存档（sect_state 段） ---

func get_save_section() -> String:
	return "sect_state"


func get_save_state() -> Dictionary:
	return {
		"has_residence": has_residence,
		"buildings": buildings.duplicate(true),
		"disciples": disciples.duplicate(true),
		"maintenance_arrears": _maintenance_arrears,
	}


func load_save_state(state: Dictionary) -> void:
	has_residence = bool(state.get("has_residence", false))
	buildings = state.get("buildings", {})
	disciples.clear()
	var saved: Array = state.get("disciples", [])
	for d: Dictionary in saved:
		disciples.append(d)
	_maintenance_arrears = bool(state.get("maintenance_arrears", false))
	EventBus.sect_state_changed.emit()
