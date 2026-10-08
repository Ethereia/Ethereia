## 阶段4 验证脚本：公式/状态单元断言 + 技能数据装载 + Boss 实战链
## 由 game_eval 调用；run() = 单元部分，run_boss() = Boss 实战（需在 Game 场景黑风岭）
extends RefCounted

const BOSS_ID := "char_hei_feng_yao_lang_wang"


## 单元断言：克制/技能伤害/状态框架/数据装载（含生成器重跑）
func run() -> Dictionary:
	var report := {}

	# --- 生成器重跑（skills/Boss 入库） ---
	var gen: RefCounted = load("res://tools/content_gen/generate_vertical_slice_content.gd").new()
	var gen_report: Dictionary = gen.run_all()
	report["saved_total"] = gen_report["saved"].size()
	report["gen_errors"] = gen_report["reload_errors"]

	# --- 五行克制三分支 ---
	report["elem_adv"] = CombatFormula.element_multiplier("金", "木")      # 1.3
	report["elem_dis"] = CombatFormula.element_multiplier("木", "金")      # 0.75
	report["elem_special"] = CombatFormula.element_multiplier("风", "木")  # 1.0
	report["elem_same"] = CombatFormula.element_multiplier("木", "木")     # 1.0
	report["elem_ok"] = report["elem_adv"] == 1.3 and report["elem_dis"] == 0.75 and report["elem_special"] == 1.0 and report["elem_same"] == 1.0

	# --- skill_damage 边界 ---
	var dmg := CombatFormula.skill_damage(25.0, 10.0, "木", "风", 10.0, 0.0)
	var dmg_high_def := CombatFormula.skill_damage(25.0, 10.0, "", "", 10000.0, 0.0)
	report["skill_dmg_sample"] = dmg
	report["skill_dmg_floor_ok"] = dmg_high_def >= 1

	# --- 状态框架（生命周期断言；灼烧伤害结算由实战日志覆盖） ---
	var sc := StatusContainer.new()
	var dummy := Node.new()  # 灼烧分支需 "current_hp" in host，此处只验证生命周期
	sc.apply("灼烧", 0.4, 5.0)
	sc.tick(0.5, dummy)
	report["burn_expire_ok"] = not sc.has_status("灼烧")

	sc.apply("冻结", 0.5, 1.0)
	report["frozen_ok"] = sc.is_frozen()
	sc.tick(0.6, dummy)
	report["frozen_expire_ok"] = not sc.is_frozen()

	sc.apply("破甲", 5.0, 0.3)
	report["armor_break_ok"] = sc.defense_multiplier() == 0.7

	sc.apply("atk_buff", 8.0, 0.5)
	report["atk_buff_ok"] = sc.attack_multiplier() == 1.5
	dummy.free()

	# --- 8 技能 + Boss 装载 ---
	var skill_ids := ["skill_ling_qi_dan", "skill_qing_teng_chan", "skill_hui_chun_shu", "skill_lang_feng_ren", "skill_lang_si_ya", "skill_dao_fei_dao", "skill_boss_pu_ji", "skill_boss_hao_jiao"]
	var missing := []
	for id in skill_ids:
		if DataManager.get_entry("skills", String(id)) == null:
			missing.append(id)
	report["skills_missing"] = missing
	var boss: Resource = DataManager.get_entry("characters", BOSS_ID)
	report["boss_loaded"] = boss != null
	report["boss_hp"] = float(boss.base_stats.get("hp", 0)) if boss != null else 0.0
	return report


## Boss 实战链：冻结→灵气弹→狂暴→击杀→冥门提示+world_state 标记
func run_boss() -> Dictionary:
	var report := {}
	var tree := Engine.get_main_loop() as SceneTree
	var wm := _first(tree, "world_manager")
	var player: Node2D = _first(tree, "player")
	if wm == null or player == null:
		return {"error": "not in game"}
	# 切到黑风岭（若不在）
	if wm.current_region_id != "region_hei_feng_ling":
		player.global_position = Vector2(256, 512)
		await tree.create_timer(1.0).timeout
	# 找 Boss
	var boss: Node = null
	for c in wm.get_child(0).get_node("Entities").get_children():
		if "enemy_id" in c and c.enemy_id == BOSS_ID and c.current_hp > 0:
			boss = c
			break
	if boss == null:
		return {"error": "boss not found"}
	player.stats.revive(1.0)
	player.global_position = boss.global_position + Vector2(0, -80)
	await tree.create_timer(0.3).timeout

	# 1) 青藤缠冻结
	var teng := DataManager.get_entry("skills", "skill_qing_teng_chan") as SkillData
	SkillExecutor.cast(teng, player, boss, player)
	report["boss_frozen"] = boss.status.is_frozen()

	# 2) 灵气弹伤害（直接结算验证克制：木 vs 风 = 1.0）
	var dan := DataManager.get_entry("skills", "skill_ling_qi_dan") as SkillData
	var hp_before: float = boss.current_hp
	SkillExecutor.cast(dan, player, boss, player)
	report["ling_qi_dan_damage"] = int(hp_before - boss.current_hp)

	# 3) 打到 50% 触发狂暴
	boss.take_damage(int(boss.current_hp - boss.max_hp * 0.4))
	report["boss_enraged"] = boss._enraged and boss.atk > float(DataManager.get_entry("characters", BOSS_ID).base_stats.get("atk", 0))

	# 4) 击杀 → 冥门标记
	await tree.create_timer(0.2).timeout
	boss.take_damage(9999)
	await tree.create_timer(2.0).timeout
	report["world_marked"] = bool(wm._regions_state.get("boss_yao_lang_wang_killed", false))
	var dlg_nodes: Array = tree.get_nodes_in_group("dialogue_ui")
	report["notice_shown"] = dlg_nodes.size() > 0 and dlg_nodes[0].is_open
	return report


func _first(tree: SceneTree, group: String) -> Node:
	var arr: Array = tree.get_nodes_in_group(group)
	if arr.is_empty():
		return null
	return arr[0]
