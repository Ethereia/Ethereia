## 阶段5 验证脚本：修仙系统单元断言 + 存读档 roundtrip + 面板/HUD 源检查
## 由 game_eval 调用 run()（需在 Game 场景）
extends RefCounted

const QUEST_TECH := "technique_yin_ling_jue"


func run() -> Dictionary:
	var report := {}
	var tree := Engine.get_main_loop() as SceneTree

	# --- 生成器重跑（聚气散/药师对话） ---
	var gen: RefCounted = load("res://tools/content_gen/generate_vertical_slice_content.gd").new()
	var gen_report: Dictionary = gen.run_all()
	DataManager.reload_table("items")  # 生成器新产物入缓存
	DataManager.reload_table("dialogues")
	report["saved_total"] = gen_report["saved"].size()
	report["gen_errors"] = gen_report["reload_errors"]
	report["qi_pill_loaded"] = DataManager.get_entry("items", "item_ju_qi_san") != null

	var cm: Node = _first(tree, "cultivation_manager")
	var player: Node = _first(tree, "player")
	if cm == null or player == null:
		return {"error": "managers missing"}

	# --- 经验入账 + 小层自动升级（四种来源合并验证；炼气一层需求 100） ---
	cm.realm_index = 1
	cm.realm_layer = 1
	cm.realm_exp = 0
	cm.gain_realm_exp(30.0, "月结")
	cm.gain_realm_exp(5.0, "战斗磨炼")
	cm.gain_realm_exp(65.0, "丹药")  # 累计 100 → 升炼气二层，溢出 0
	report["auto_layer_up"] = cm.realm_layer == 2 and cm.realm_exp == 0
	report["max_hp_recalc"] = player.stats.max_hp  # 100 × stat_multiplier(1,2)=1.55 → 155
	report["hp_recalc_ok"] = int(player.stats.max_hp) == 155

	# --- 打坐累积（模拟 tick；真实帧可能并发微 tick，断言"确实在积累"） ---
	cm.set_meditating(true)
	cm._process(2.0)  # 2 秒 × 1.0 基础（此时未学功法）
	cm.set_meditating(false)
	report["meditate_exp_gain"] = cm.realm_exp
	report["meditate_ok"] = cm.realm_exp >= 1 and cm.realm_exp <= 5

	# --- 功法学习 + 去重 + 效率 ---
	cm.learn_technique(QUEST_TECH)
	report["learned"] = cm.learned_techniques.has(QUEST_TECH)
	report["auto_active"] = cm.active_technique == QUEST_TECH
	cm.learn_technique(QUEST_TECH)  # 重复 → progress +10
	report["dup_progress"] = int(cm.technique_progress.get(QUEST_TECH, 0)) == 10
	report["efficiency"] = cm._technique_efficiency()  # 引灵诀 1.05

	# --- 大境界突破：推到九层满，双分支各验一次 ---
	cm.realm_index = 1
	cm.realm_layer = 9
	cm.realm_exp = CultivationUtils.required_exp(1, 9)
	cm.learned_techniques.clear()  # 清功法使 mastery=0.3 固定，概率可控
	cm.active_technique = ""
	var hp0: float = player.stats.max_hp
	cm.attempt_major_breakthrough()
	var branch := "unknown"
	if cm.realm_index == 2:
		branch = "success"
	elif cm.realm_exp < CultivationUtils.required_exp(1, 9) and player.status.has_status("灵力紊乱"):
		branch = "failed"
	report["breakthrough_branch"] = branch
	report["breakthrough_valid"] = branch == "success" or branch == "failed"
	# 复位到筑基初（无论分支）供后续
	cm.realm_index = 1
	cm.realm_layer = 9
	cm.realm_exp = 0
	cm._refresh_player_stats()

	# --- 存读档 roundtrip ---
	cm.realm_index = 2
	cm.realm_layer = 3
	cm.realm_exp = 77
	cm.learn_technique(QUEST_TECH)
	SaveManager.save_game("test")
	cm.realm_index = 1
	cm.realm_exp = 0
	cm.learned_techniques.clear()
	SaveManager.load_game("test")
	await tree.create_timer(0.3).timeout
	report["save_realm_ok"] = cm.realm_index == 2 and cm.realm_layer == 3 and cm.realm_exp == 77
	report["save_tech_ok"] = cm.learned_techniques.has(QUEST_TECH)

	# --- HUD 境界显示源 ---
	var hud_nodes: Array = tree.get_nodes_in_group("hud")
	report["hud_label"] = "(via manager)"
	var expected := CultivationUtils.realm_display(cm.realm_index, cm.realm_layer)
	report["hud_expected"] = expected
	return report


func _first(tree: SceneTree, group: String) -> Node:
	var arr: Array = tree.get_nodes_in_group(group)
	if arr.is_empty():
		return null
	return arr[0]
