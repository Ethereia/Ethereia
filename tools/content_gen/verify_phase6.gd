## 阶段6 验证脚本：驻地/建造升级/月结/弟子/存档 断言链（需在 Game 场景）
extends RefCounted

const JUELING_ID := "building_ju_ling_zhen"


func run() -> Dictionary:
	var report := {}
	var tree := Engine.get_main_loop() as SceneTree
	var sm: Node = _first(tree, "sect_manager")
	var inv_m: Node = _first(tree, "inventory_manager")
	var cm: Node = _first(tree, "cultivation_manager")
	if sm == null or inv_m == null or cm == null:
		return {"error": "managers missing"}
	var inv = inv_m.inventory

	# 复位状态
	sm.has_residence = false
	sm.buildings = {}
	sm.disciples.clear()
	inv.add_item("item_ling_shi", 300)
	inv.add_item("item_ling_cao", 50)
	report["start_lingshi"] = inv.get_count("item_ling_shi")

	# 1) 建立驻地：扣灵石 50
	sm.establish_residence()
	report["residence_ok"] = sm.has_residence and inv.get_count("item_ling_shi") == report["start_lingshi"] - 50

	# 2) 招募至上限 1，再招被拒
	var r1: bool = sm.recruit_disciple()
	var r2: bool = sm.recruit_disciple()  # 超 cap=1 拒绝
	report["recruit_first_ok"] = r1 and sm.disciples.size() == 1
	report["recruit_cap_reject"] = not r2 and sm.disciples.size() == 1

	# 3) 聚灵阵 1→2 级：扣料 + 工期中不可再建
	inv.add_item("item_ling_shi", 500)
	inv.add_item("item_ling_cao", 100)
	var lingshi_before: int = inv.get_count("item_ling_shi")
	var cao_before: int = inv.get_count("item_ling_cao")
	var up1: bool = sm.start_construction(JUELING_ID)
	var b: Dictionary = sm.buildings.get(JUELING_ID, {})
	var cost_spent: Dictionary = DataManager.get_entry("buildings", JUELING_ID).upgrade_cost[0]
	report["upgrade_started"] = up1 and bool(b.get("upgrading", false))
	report["cost_deducted"] = inv.get_count("item_ling_shi") == lingshi_before - int(cost_spent.get("item_ling_shi", 0)) and inv.get_count("item_ling_cao") == cao_before - int(cost_spent.get("item_ling_cao", 0))
	report["no_double_build"] = not sm.start_construction(JUELING_ID)

	# 4) 推进月份至工期到期：升级结算 + upkeep 扣灵石
	var level_before: int = int(b["level"])
	var months_needed: int = 1
	for i in range(months_needed):
		TimeManager.advance_month()
	report["upgrade_completed"] = int(b["level"]) == level_before + 1 and not bool(b["upgrading"])
	report["upkeep_deducted"] = inv.get_count("item_ling_shi") == lingshi_before - int(cost_spent.get("item_ling_shi", 0)) - 1  # lv1 upkeep 1

	# 5) 环境因子随等级变化
	report["env_factor_lv1"] = sm.get_environment_factor()  # 0.6
	report["env_ok"] = absf(float(sm.get_environment_factor()) - 0.6) < 0.01

	# 6) 欠缴不崩：清空灵石过月
	inv.remove_item("item_ling_shi", inv.get_count("item_ling_shi"))
	TimeManager.advance_month()
	report["arrears_no_crash"] = true
	report["arrears_flag"] = bool(sm._maintenance_arrears)
	report["env_factor_arrears"] = sm.get_environment_factor()  # 回 0.5

	# 7) 存读档 roundtrip
	sm.buildings[JUELING_ID] = {"level": 3, "upgrading": false, "end_year": 0, "end_month": 0}
	SaveManager.save_game("test")
	sm.buildings.clear()
	sm.has_residence = false
	SaveManager.load_game("test")
	await tree.create_timer(0.3).timeout
	report["save_residence_ok"] = sm.has_residence
	report["save_level_ok"] = sm.get_building_level(JUELING_ID) == 3
	report["env_after_save"] = sm.get_environment_factor()  # lv3 → 0.8
	return report


func _first(tree: SceneTree, group: String) -> Node:
	var arr: Array = tree.get_nodes_in_group(group)
	if arr.is_empty():
		return null
	return arr[0]
