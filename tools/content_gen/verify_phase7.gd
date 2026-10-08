## 阶段7 验证脚本：条件求值器/任务目标扩展/任务链/事件触发器/道心效果/敌人表化 断言链（需在 Game 场景）
extends RefCounted

const QUEST_1 := "quest_diao_cha_hei_feng_ling"
const QUEST_2 := "quest_hei_feng_shen_ru"
const QUEST_3 := "quest_yao_lang_wang_tao_fa"
const EVENT_MAIN := "event_shao_nv_zhi_wen"


func run() -> Dictionary:
	var report := {}
	var tree := Engine.get_main_loop() as SceneTree
	var qm: Node = _first(tree, "quest_manager")
	var cm: Node = _first(tree, "cultivation_manager")
	var im: Node = _first(tree, "inventory_manager")
	var wm: Node = _first(tree, "world_manager")
	var em: Node = _first(tree, "event_manager")
	var ui: Node = _first(tree, "dialogue_ui")
	var inv = im.inventory if im != null else null
	report["env_ok"] = qm != null and cm != null and im != null and wm != null and em != null and ui != null and inv != null
	if not bool(report["env_ok"]):
		return report

	# 快照 + 抑制少女之问自动触发（链测试完成 q1 时 quest_completed 信号会引发事件检查）
	var states_snapshot: Dictionary = qm.quest_states.duplicate(true)
	em.cooldowns[EVENT_MAIN] = 99999

	# --- A. ConditionEvaluator ---
	report["ce_realm"] = ConditionEvaluator.check([{"key": "player.realm_index", "op": ">=", "value": 1}, {"key": "player.realm_layer", "op": "<=", "value": 9}], qm)
	report["ce_neq"] = ConditionEvaluator.eval_one({"key": "player.realm_index", "op": "!=", "value": 9}, qm)
	report["ce_item"] = ConditionEvaluator.check([{"key": "item.item_ling_cao", "op": ">=", "value": 0}], qm)
	wm.set_world_flag("test_flag7", 42)
	report["ce_world"] = ConditionEvaluator.eval_one({"key": "world.test_flag7", "op": "==", "value": 42}, qm)
	report["ce_region"] = ConditionEvaluator.eval_one({"key": "world.region", "op": "==", "value": wm.current_region_id}, qm)
	wm._regions_state.erase("test_flag7")
	# quest 三态：none / active / completed
	report["ce_q_none"] = ConditionEvaluator.eval_one({"key": "quest.%s" % QUEST_1, "op": "==", "value": "none"}, qm)
	qm.quest_states[QUEST_1] = {"status": "active", "progress": {}}
	report["ce_q_active"] = ConditionEvaluator.eval_one({"key": "quest.%s" % QUEST_1, "op": "==", "value": "active"}, qm)
	qm.quest_states[QUEST_1]["status"] = "completed"
	report["ce_q_completed"] = ConditionEvaluator.eval_one({"key": "quest.%s" % QUEST_1, "op": "==", "value": "completed"}, qm)
	qm.quest_states.erase(QUEST_1)

	# --- B. 合成任务：收集快照 / 修炼达标 / 选择限定 ---
	var q_c := QuestData.new()
	q_c.id = "quest_test_collect"
	q_c.display_name = "测试收集"
	q_c.objectives = [{"type": "收集", "target_id": "item_yao_lang_ya", "count": 3, "params": {}}]
	DataManager.get_table("quests")["quest_test_collect"] = q_c
	qm.accept_quest("quest_test_collect")
	inv.add_item("item_yao_lang_ya", 3)
	report["collect_add"] = int(qm.quest_states["quest_test_collect"]["progress"].get(0, 0)) == 3
	inv.remove_item("item_yao_lang_ya", 1)
	report["collect_fall"] = int(qm.quest_states["quest_test_collect"]["progress"].get(0, 0)) == 2  # 快照回落

	var q_m := QuestData.new()
	q_m.id = "quest_test_cult"
	q_m.display_name = "测试修炼"
	q_m.objectives = [{"type": "修炼", "target_id": "", "count": 1, "params": {"realm_index": 1, "realm_layer": 1}}]
	DataManager.get_table("quests")["quest_test_cult"] = q_m
	qm.accept_quest("quest_test_cult")  # 当前炼气一层：接取即达标
	EventBus.cultivation_state_changed.emit()
	report["cult_reach"] = int(qm.quest_states["quest_test_cult"]["progress"].get(0, 0)) == 1

	var q_s := QuestData.new()
	q_s.id = "quest_test_choice"
	q_s.display_name = "测试选择"
	q_s.objectives = [{"type": "选择", "target_id": EVENT_MAIN, "count": 1, "params": {"choice_index": 0}}]
	DataManager.get_table("quests")["quest_test_choice"] = q_s
	qm.accept_quest("quest_test_choice")
	EventBus.dialogue_choice_made.emit(EVENT_MAIN, 1)
	report["choice_filtered"] = int(qm.quest_states["quest_test_choice"]["progress"].get(0, 0)) == 0
	EventBus.dialogue_choice_made.emit(EVENT_MAIN, 0)
	report["choice_hit"] = int(qm.quest_states["quest_test_choice"]["progress"].get(0, 0)) == 1
	# 清理合成任务（先清状态再清缓存）
	for tid: String in ["quest_test_collect", "quest_test_cult", "quest_test_choice"]:
		qm.quest_states.erase(tid)
		DataManager.get_table("quests").erase(tid)

	# --- C. requirements 门槛 + next_quests 链 ---
	var q_req := QuestData.new()
	q_req.id = "quest_test_req"
	q_req.display_name = "测试门槛"
	q_req.requirements = [{"key": "player.realm_index", "op": ">=", "value": 5}]  # 炼气一层 → 拒绝
	DataManager.get_table("quests")["quest_test_req"] = q_req
	qm.accept_quest("quest_test_req")
	report["req_reject"] = qm.quest_state_of("quest_test_req") == "none"
	q_req.requirements = [{"key": "player.realm_index", "op": ">=", "value": 1}]
	qm.accept_quest("quest_test_req")
	report["req_accept"] = qm.quest_state_of("quest_test_req") == "active"
	qm.quest_states.erase("quest_test_req")
	DataManager.get_table("quests").erase("quest_test_req")

	qm.accept_quest(QUEST_1)
	qm.quest_states[QUEST_1]["progress"] = {0: 1, 1: 2, 2: 1}  # 整数键：与 _advance 写入的 progress[idx] 一致
	qm.complete_quest(QUEST_1)
	report["chain_q2"] = qm.quest_state_of(QUEST_2) == "active"  # 自动接取
	qm.quest_states[QUEST_2]["progress"] = {0: 3, 1: 1, 2: 1}
	qm.complete_quest(QUEST_2)
	report["chain_q3"] = qm.quest_state_of(QUEST_3) == "active"
	qm.quest_states.erase(QUEST_1)
	qm.quest_states.erase(QUEST_2)
	qm.quest_states.erase(QUEST_3)
	qm.tracked_id = ""

	# --- D. 事件：触发 / 一次性 / 冷却 / show_event UI / 道心与flag ---
	em.fired.clear()
	em.cooldowns.erase(EVENT_MAIN)
	qm.quest_states[QUEST_1] = {"status": "completed", "progress": {}}
	em._check_events()
	report["event_fired"] = em.fired.has(EVENT_MAIN)
	var fired_count: int = em.fired.size()
	em._check_events()
	report["event_once"] = em.fired.size() == fired_count  # 一次性不重触
	await tree.process_frame
	await tree.process_frame
	report["event_ui_open"] = bool(ui.is_open)
	var dao_before: int = cm.get_dao_heart("求知")
	var ev: EventData = DataManager.get_entry("events", EVENT_MAIN)
	ui._on_choice_pressed(ev.choices[2], 2)  # 「我不知道……」：求知+5 + flag a_ying_answer
	report["dao_heart_add"] = cm.get_dao_heart("求知") == dao_before + 5
	report["world_flag_set"] = wm.get_world_flag("a_ying_answer") == "curious"
	report["event_ui_closed"] = not bool(ui.is_open)
	# 冷却事件：注入 45 天冷却 → 两次月结（-30×2）后可再触发
	qm.quest_states.erase(QUEST_1)  # 少女之问条件失效，避免本段重触发
	var ev_cd := EventData.new()
	ev_cd.id = "event_test_cd"
	ev_cd.cooldown_days = 45
	DataManager.get_table("events")["event_test_cd"] = ev_cd
	em.cooldowns.erase(EVENT_MAIN)
	em.fired.clear()
	em._check_events()
	# 冷却型触发不进 fired：_trigger 对 cooldown_days>0 只重置冷却
	report["cd_started"] = em.cooldowns.has("event_test_cd") and int(em.cooldowns["event_test_cd"]) == 45 and not em.fired.has("event_test_cd")
	em._on_month_changed(1, 2)
	report["cd_hold"] = em.cooldowns.has("event_test_cd") and int(em.cooldowns["event_test_cd"]) == 15
	em._on_month_changed(1, 3)
	# 过冷却：擦除后重触发 → 冷却重置回 45（45→15→45 证明完整周期）
	report["cd_expire"] = em.cooldowns.has("event_test_cd") and int(em.cooldowns["event_test_cd"]) == 45
	DataManager.get_table("events").erase("event_test_cd")
	em.fired.clear()
	em.cooldowns.clear()
	await tree.process_frame  # event_test_cd 的 deferred 弹窗落地后关闭，防游戏滞留暂停态
	await tree.process_frame
	if bool(ui.is_open):
		ui._close()

	# --- E. 存档归一化（旧结构缺字段不崩） ---
	qm.quest_states = {"t_a": {}, "t_b": {"status": "completed"}}
	qm.load_save_state({"quest_states": {"t_a": {}, "t_b": {"status": "completed"}}})
	report["save_norm"] = qm.quest_state_of("t_a") == "active" and qm.quest_state_of("t_b") == "completed" and qm.quest_states["t_a"]["progress"] is Dictionary
	qm.quest_states = states_snapshot
	qm.tracked_id = ""

	# --- F. 敌人表化（CharacterData v1.1 字段 vs 旧常量） ---
	var wolf: CharacterData = DataManager.get_entry("characters", "char_ye_lang_yao")
	var bandit: CharacterData = DataManager.get_entry("characters", "char_hei_feng_dao_fei")
	var boss: CharacterData = DataManager.get_entry("characters", "char_hei_feng_yao_lang_wang")
	report["wolf_skills"] = wolf != null and wolf.enemy_skills == ["skill_lang_feng_ren", "skill_lang_si_ya"] and wolf.enemy_element == "风"
	report["bandit_data"] = bandit != null and bandit.enemy_skills == ["skill_dao_fei_dao"] and bandit.enemy_element == "金"
	report["boss_data"] = boss != null and boss.enemy_skills == ["skill_boss_pu_ji", "skill_boss_hao_jiao"] and boss.enemy_element == "风"
	var has_fang := false
	if wolf != null:
		for d: Dictionary in wolf.drop_table:
			if String(d.get("item_id")) == "item_yao_lang_ya" and absf(float(d.get("chance", 0.0)) - 0.6) < 0.001:
				has_fang = true
	report["wolf_drops"] = wolf != null and wolf.drop_table.size() == 4 and has_fang
	report["new_item_file"] = FileAccess.file_exists("res://data/items/item_yao_lang_ya.tres") and FileAccess.file_exists("res://data/quests/%s.tres" % QUEST_2) and FileAccess.file_exists("res://data/quests/%s.tres" % QUEST_3)
	return report


func _first(tree: SceneTree, group: String) -> Node:
	var arr: Array = tree.get_nodes_in_group(group)
	if arr.is_empty():
		return null
	return arr[0]
