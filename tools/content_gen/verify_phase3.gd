## 阶段3 端到端验证脚本：接任务→切区域→战斗掉落→采集→回报→存读档回归
## 由 game_eval 调用 run()；内部无 lambda、无全局类名引用，防 debugger break
extends RefCounted

const QUEST_ID := "quest_diao_cha_hei_feng_ling"


func run() -> Dictionary:
	var report := {}
	var tree := Engine.get_main_loop() as SceneTree
	if tree.current_scene == null or tree.current_scene.name != "Game":
		return {"error": "not in Game scene"}
	var player: Node2D = _first(tree, "player")
	var wm: Node = _first(tree, "world_manager")
	var qm: Node = _first(tree, "quest_manager")
	var inv_m: Node = _first(tree, "inventory_manager")
	if player == null or wm == null or qm == null or inv_m == null:
		return {"error": "managers missing"}

	# --- A. 接任务 ---
	var mayor: Node = _find_npc(wm.get_child(0), "char_qin_bo_yuan")
	if mayor == null:
		return {"error": "mayor missing"}
	mayor.interact()
	var dlg: Node = _first(tree, "dialogue_ui")
	dlg._on_choice_pressed({"text": "a", "effects": [{"target": "quest", "key": QUEST_ID, "op": "accept"}], "next": "n1"})
	dlg._on_choice_pressed({"text": "c", "effects": [], "next": ""})
	report["quest_accepted"] = qm.is_active(QUEST_ID)

	# --- B. 传送门切区域 ---
	player.stats.revive(1.0)
	player.global_position = Vector2(256, 512)
	await tree.create_timer(0.9).timeout
	report["region_after_portal"] = wm.current_region_id

	# --- C. 清怪 ---
	var region2: Node = wm.get_child(0)
	var wolves := 0
	var bandits := 0
	for i in range(8):
		var enemy: Node = _find_enemy(region2)
		if enemy == null:
			break
		if enemy.enemy_id == "char_ye_lang_yao":
			wolves += 1
		else:
			bandits += 1
		enemy.take_damage(9999)
	report["wolves_killed"] = wolves
	report["bandits_killed"] = bandits

	# --- D. 采集 + 掉落拾取 ---
	var inv = inv_m.inventory
	var herb0: int = int(inv.items.get("item_ling_cao", 0))
	var rnode: Node = _find_resource(region2)
	if rnode != null:
		rnode.interact()
	_collect_pickups(region2, player)
	await tree.create_timer(0.5).timeout
	report["herb_gained"] = int(inv.items.get("item_ling_cao", 0)) - herb0
	var qs: Dictionary = qm.quest_states.get(QUEST_ID, {})
	report["objectives_progress"] = qs.get("progress", {})

	# --- E. 回镇回报（奖励发放） ---
	player.global_position = Vector2(448, 128)
	await tree.create_timer(0.9).timeout
	report["region_back"] = wm.current_region_id
	var mayor2: Node = _find_npc(wm.get_child(0), "char_qin_bo_yuan")
	if mayor2 == null:
		report["report_error"] = "mayor missing"
		return report
	player.global_position = mayor2.global_position + Vector2(0, 40)
	mayor2.interact()
	var dlg2: Node = _first(tree, "dialogue_ui")
	var stones_before: int = int(inv.items.get("item_ling_shi", 0))
	dlg2._on_choice_pressed({"text": "r", "effects": [{"target": "quest", "key": QUEST_ID, "op": "report"}], "next": "n2"})
	dlg2._on_choice_pressed({"text": "c", "effects": [], "next": ""})
	report["quest_completed"] = qm.quest_states.has(QUEST_ID) and not qm.is_active(QUEST_ID)
	report["stones_gain"] = int(inv.items.get("item_ling_shi", 0)) - stones_before
	report["pills_gain"] = int(inv.items.get("item_hui_xue_san", 0))

	# --- F. 存读档回归 ---
	player.stats.take_damage(11.0)
	var hp_saved: float = player.stats.current_hp
	var pos_saved: Vector2 = player.global_position
	SaveManager.save_game("test")
	player.stats.take_damage(20.0)
	player.global_position = Vector2(0, 0)
	SaveManager.load_game("test")
	await tree.create_timer(0.3).timeout
	report["save_hp_ok"] = absf(player.stats.current_hp - hp_saved) < 0.01
	report["save_pos_ok"] = player.global_position.distance_to(pos_saved) < 2.0
	report["save_region_ok"] = wm.current_region_id == "region_qingshi_town"
	report["save_quest_ok"] = qm.quest_states.has(QUEST_ID) and not qm.is_active(QUEST_ID)
	return report


func _first(tree: SceneTree, group: String) -> Node:
	var arr: Array = tree.get_nodes_in_group(group)
	if arr.is_empty():
		return null
	return arr[0]


func _find_npc(region: Node, npc_id: String) -> Node:
	for c in region.get_node("Entities").get_children():
		if "npc_id" in c and c.npc_id == npc_id:
			return c
	return null


func _find_enemy(region: Node) -> Node:
	for c in region.get_node("Entities").get_children():
		if c is CharacterBody2D and "enemy_id" in c and c.current_hp > 0:
			return c
	return null


func _find_resource(region: Node) -> Node:
	for c in region.get_node("Entities").get_children():
		if c is StaticBody2D and "node_key" in c and not c.harvested:
			return c
	return null


func _collect_pickups(region: Node, player: Node2D) -> void:
	for c in region.get_node("Entities").get_children():
		if c is Area2D and "item_id" in c:
			c.global_position = player.global_position
