## 垂直切片首批内容生成器（doc 27 Step 2-9 配套数据，阶段1 收尾）
## 运行方式：启动游戏后经 game_eval 调用 run_all()，产物为 data/ 下 .tres（引擎序列化）
## 说明：base_stats / 伤害类数值为占位初值，Phase 4 战斗系统落地后统一调整
## 可重复运行（覆盖保存，幂等）
extends RefCounted


func run_all() -> Dictionary:
	var all: Array[Resource] = []
	all.append_array(_gen_factions())
	all.append_array(_gen_regions())
	all.append_array(_gen_buildings())
	all.append_array(_gen_techniques())
	all.append_array(_gen_items())
	all.append_array(_gen_characters())
	all.append_array(_gen_quests())
	all.append_array(_gen_events())
	all.append_array(_gen_dialogues())
	all.append_array(_gen_skills())

	var report := {"saved": [], "reload_errors": []}
	for res: Resource in all:
		var path := _path_for(res.id)
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())  # 表目录缺失时兜底创建
		var err := ResourceSaver.save(res, path)
		report["saved"].append({"id": res.id, "path": path, "err": err})
	# 回读校验：文件存在且能加载为正确类型
	for res: Resource in all:
		var back: Resource = load(_path_for(res.id))
		if back == null or back.id != res.id:
			report["reload_errors"].append(res.id)
	return report


func _path_for(id: String) -> String:
	var table := ""
	if id.begins_with("char_"):
		table = "characters"
	elif id.begins_with("faction_"):
		table = "factions"
	elif id.begins_with("region_"):
		table = "regions"
	elif id.begins_with("building_"):
		table = "buildings"
	elif id.begins_with("technique_"):
		table = "techniques"
	elif id.begins_with("item_"):
		table = "items"
	elif id.begins_with("quest_"):
		table = "quests"
	elif id.begins_with("event_"):
		table = "events"
	elif id.begins_with("dlg_"):
		table = "dialogues"
	elif id.begins_with("skill_"):
		table = "skills"
	return "res://data/%s/%s.tres" % [table, id]


# ---------------------------------------------------------------- 势力（2）

func _gen_factions() -> Array[Resource]:
	var list: Array[Resource] = []

	var town := FactionData.new()
	town.id = "faction_qingshi_town"
	town.display_name = "青石镇"
	town.faction_type = FactionData.FactionType.CITY
	town.ideology = "安土重迁，凡人互助，在妖兽环伺的边地维持一方安居"
	town.relations = {
		"faction_hei_feng_dao": {"relation_score": -60, "trust": 0, "fear": 30, "trade": 0, "war_state": "敌对"},
	}
	town.territory = ["region_qingshi_town"]
	town.ai_profile = {"aggression": 10, "expansion": 5, "trade_preference": 70}
	town.description = "边地下州的一座凡人小镇，因镇口青石而得名。镇民以农耕和小宗灵草贸易为生。"
	list.append(town)

	var bandits := FactionData.new()
	bandits.id = "faction_hei_feng_dao"
	bandits.display_name = "黑风盗"
	bandits.faction_type = FactionData.FactionType.WILDERNESS
	bandits.ideology = "流寇结社，弱肉强食，交钱放行"
	bandits.relations = {
		"faction_qingshi_town": {"relation_score": -60, "trust": 0, "fear": 10, "trade": 20, "war_state": "敌对"},
	}
	bandits.territory = ["region_hei_feng_ling"]
	bandits.ai_profile = {"aggression": 80, "expansion": 30, "trade_preference": 10}
	bandits.description = "盘踞黑风岭的流匪，近来行踪诡秘，劫掠频率反常地高。"
	list.append(bandits)
	return list


# ---------------------------------------------------------------- 区域（2）

func _gen_regions() -> Array[Resource]:
	var list: Array[Resource] = []

	var town := RegionData.new()
	town.id = "region_qingshi_town"
	town.display_name = "青石镇"
	town.terrain = "平原"
	town.level_range = Vector2i(1, 5)
	town.tags = ["城镇", "安全区", "农耕"]
	town.danger_level = 0
	town.resources = {}
	town.locations = [
		{"id": "loc_zhen_zhang_fu", "position": Vector2i(4, 3), "location_type": "官署", "level_range": Vector2i(1, 5), "terrain": "平原", "tags": ["建筑"], "resources": {}, "encounters": ["char_qin_bo_yuan"], "factions": ["faction_qingshi_town"], "quest_hooks": ["quest_diao_cha_hei_feng_ling"]},
		{"id": "loc_hui_chun_tang", "position": Vector2i(7, 4), "location_type": "店铺", "level_range": Vector2i(1, 5), "terrain": "平原", "tags": ["药铺"], "resources": {"item_hui_xue_san": 2}, "encounters": ["char_su_zhi"], "factions": ["faction_qingshi_town"], "quest_hooks": []},
		{"id": "loc_tie_jiang_pu", "position": Vector2i(5, 6), "location_type": "店铺", "level_range": Vector2i(1, 5), "terrain": "平原", "tags": ["铁匠铺"], "resources": {}, "encounters": ["char_tie_niu"], "factions": ["faction_qingshi_town"], "quest_hooks": []},
		{"id": "loc_zhen_kou", "position": Vector2i(2, 8), "location_type": "入口", "level_range": Vector2i(1, 5), "terrain": "平原", "tags": ["镇口"], "resources": {}, "encounters": ["char_a_ying"], "factions": ["faction_qingshi_town"], "quest_hooks": []},
	]
	town.factions_present = ["faction_qingshi_town"]
	town.ambient_bgm = ""
	town.map_layer_paths = {}
	list.append(town)

	var mountain := RegionData.new()
	mountain.id = "region_hei_feng_ling"
	mountain.display_name = "黑风岭"
	mountain.terrain = "山地"
	mountain.level_range = Vector2i(2, 6)
	mountain.tags = ["野外", "妖兽", "失踪传闻"]
	mountain.danger_level = 45
	mountain.resources = {"item_ling_cao": 3}
	mountain.locations = [
		{"id": "loc_hei_feng_xiao_jing", "position": Vector2i(3, 2), "location_type": "道路", "level_range": Vector2i(2, 4), "terrain": "山地", "tags": ["山道"], "resources": {"item_ling_cao": 1}, "encounters": ["char_ye_lang_yao", "char_hei_feng_dao_fei"], "factions": ["faction_hei_feng_dao"], "quest_hooks": []},
		{"id": "loc_yao_lang_chao_xue", "position": Vector2i(8, 6), "location_type": "巢穴", "level_range": Vector2i(3, 6), "terrain": "山地", "tags": ["妖兽"], "resources": {}, "encounters": ["char_ye_lang_yao", "char_hei_feng_yao_lang_wang"], "factions": [], "quest_hooks": ["quest_diao_cha_hei_feng_ling"]},
		{"id": "loc_fei_qi_kuang_keng", "position": Vector2i(6, 3), "location_type": "遗迹", "level_range": Vector2i(2, 5), "terrain": "山地", "tags": ["矿坑", "废弃"], "resources": {}, "encounters": ["char_hei_feng_dao_fei"], "factions": ["faction_hei_feng_dao"], "quest_hooks": []},
	]
	mountain.factions_present = ["faction_hei_feng_dao"]
	mountain.ambient_bgm = ""
	mountain.map_layer_paths = {}
	list.append(mountain)
	return list


# ---------------------------------------------------------------- 建筑（1）

func _gen_buildings() -> Array[Resource]:
	var list: Array[Resource] = []

	var b := BuildingData.new()
	b.id = "building_ju_ling_zhen"
	b.display_name = "聚灵阵"
	b.max_level = 5
	b.upgrade_cost = [
		{"item_ling_shi": 50, "item_ling_cao": 10},
		{"item_ling_shi": 120, "item_ling_cao": 25},
		{"item_ling_shi": 300, "item_ling_cao": 60},
		{"item_ling_shi": 800, "item_ling_cao": 150},
		{"item_ling_shi": 2000, "item_ling_cao": 400},
	]
	b.upgrade_time_days = [1, 2, 4, 7, 12]
	b.prestige_requirement = [0, 0, 10, 30, 60]
	b.prereq_building = {}
	b.production = {}
	b.upkeep = {"item_ling_shi": 1}
	b.unlock_effects = [
		{"effect": "cultivation_env_bonus", "level": 1},
		{"effect": "breakthrough_env_factor", "level": 3},
		{"effect": "extra_disciple_slot", "level": 5},
	]
	b.description = "汇聚天地灵气的阵法基座，是临时驻地的第一块基石。阵内修炼事半功倍，高阶阵盘还能辅助突破。"
	list.append(b)
	return list


# ---------------------------------------------------------------- 功法（1）

func _gen_techniques() -> Array[Resource]:
	var list: Array[Resource] = []

	var t := TechniqueData.new()
	t.id = "technique_yin_ling_jue"
	t.display_name = "引灵诀"
	t.tech_type = TechniqueData.TechType.MAIN
	t.grade = TechniqueData.Grade.HUANG
	t.element_affinity = []
	t.attribute_tendency = {"m_atk": 0.10, "m_def": 0.10}
	t.cultivation_efficiency = 1.05
	t.spirit_root_requirement = {}
	t.active_skill_ids = []
	t.passive_effects = []
	t.breakthrough_modifiers = {"spirit_quality": 2}
	t.side_effects = ["灵力运转初见滞涩：修炼首月效率 -10%"]
	t.hidden_trait = "残篇互补"
	t.hidden_trait_condition = "集齐三张《引灵诀》残页（item_gong_fa_can_ye）拼合为完整篇，修炼效率提升至 1.2"
	t.cultivation_progress_max = 100
	t.description = "流传于下州乡野的引气入体法门。残卷遗失大半，却被历代抄录者添注了无数私货——反而意外适合根骨驳杂之人入门。"
	list.append(t)
	return list


# ---------------------------------------------------------------- 物品（4）

func _gen_items() -> Array[Resource]:
	var list: Array[Resource] = []

	var stone := ItemData.new()
	stone.id = "item_ling_shi"
	stone.display_name = "灵石"
	stone.item_type = ItemData.ItemType.RESOURCE_T2
	stone.grade = 1
	stone.stackable = true
	stone.base_value = 1
	stone.effects = []
	stone.description = "下界通用修行通货，蕴存稀薄灵气。"
	list.append(stone)

	var herb := ItemData.new()
	herb.id = "item_ling_cao"
	herb.display_name = "灵草"
	herb.item_type = ItemData.ItemType.RESOURCE_T2
	herb.grade = 1
	herb.stackable = true
	herb.base_value = 5
	herb.effects = []
	herb.description = "青石镇周边常见的药草，是炼制入门丹药的基础材料。"
	list.append(herb)

	var page := ItemData.new()
	page.id = "item_gong_fa_can_ye"
	page.display_name = "引灵诀残页"
	page.item_type = ItemData.ItemType.TECHNIQUE_PAGE
	page.grade = 1
	page.stackable = false
	page.base_value = 30
	page.effects = [{"stat": "technique", "op": "learn", "value": "technique_yin_ling_jue", "duration": 0}]
	page.description = "从黑风岭妖狼巢穴中寻得的残页。纸页泛黄，字迹却极新——像是有人一直在补写。"
	list.append(page)

	var pill := ItemData.new()
	pill.id = "item_hui_xue_san"
	pill.display_name = "回血散"
	pill.item_type = ItemData.ItemType.PILL
	pill.grade = 0
	pill.stackable = true
	pill.base_value = 8
	pill.effects = [{"stat": "hp", "op": "add", "value": 30, "duration": 0}]
	pill.description = "苏芷配制的伤药。入口微苦，药力温和。"
	list.append(pill)

	var qi_pill := ItemData.new()
	qi_pill.id = "item_ju_qi_san"
	qi_pill.display_name = "聚气散"
	qi_pill.item_type = ItemData.ItemType.PILL
	qi_pill.grade = 1
	qi_pill.stackable = true
	qi_pill.base_value = 25
	qi_pill.effects = [{"stat": "realm_exp", "op": "add", "value": 50, "duration": 0}]
	qi_pill.description = "苏芷以灵草粗炼的助修散剂，服下后灵气充盈，境界经验 +50。"
	list.append(qi_pill)
	return list


# ---------------------------------------------------------------- 角色（7：1 玩家 + 4 NPC + 2 敌人 + 1 Boss）

func _gen_characters() -> Array[Resource]:
	var list: Array[Resource] = []
	list.append(_make_player_default())
	list.append(_make_qin_bo_yuan())
	list.append(_make_su_zhi())
	list.append(_make_tie_niu())
	list.append(_make_a_ying())
	list.append(_make_ye_lang_yao())
	list.append(_make_hei_feng_dao_fei())
	list.append(_make_boss())
	return list


func _make_player_default() -> CharacterData:
	var c := CharacterData.new()
	c.id = "char_player_default"
	c.display_name = "无名修士"
	c.title = "初入江湖"
	c.character_type = CharacterData.CharacterType.PLAYER
	c.faction_id = ""
	c.realm_index = 1
	c.realm_layer = 1
	c.spirit_roots = {"木": 60}
	c.dao_heart = {"坚毅": 50, "慈悲": 50, "杀伐": 30, "求知": 50, "自由": 40, "执念": 40}
	c.base_stats = {"hp": 100, "mp": 50, "atk": 12, "def": 8, "m_atk": 10, "m_def": 8, "speed": 9, "crit": 0.05, "accuracy": 0.90, "evasion": 0.08}
	c.spirit_stats = {"灵根强度": 60, "神魂": 50, "因果": 50, "气运": 50}
	c.personality = "尚未定型（阶段2占位，捏人流程在垂直切片 Step 1 实现）"
	c.goal = "在青石镇立足"
	c.fear = "未知"
	c.interest = "变强"
	c.secret = ""
	c.relationships = {}
	return c


func _make_qin_bo_yuan() -> CharacterData:
	var c := CharacterData.new()
	c.id = "char_qin_bo_yuan"
	c.display_name = "秦伯远"
	c.title = "青石镇镇长"
	c.character_type = CharacterData.CharacterType.CORE_NPC
	c.faction_id = "faction_qingshi_town"
	c.realm_index = 0
	c.realm_layer = 9
	c.spirit_roots = {"土": 40}
	c.dao_heart = {"坚毅": 70, "慈悲": 65, "杀伐": 20, "求知": 30, "自由": 25, "执念": 55}
	c.base_stats = {"hp": 120, "mp": 20, "atk": 10, "def": 8, "m_atk": 5, "m_def": 6, "speed": 6, "crit": 0.03, "accuracy": 0.90, "evasion": 0.05}
	c.spirit_stats = {"灵根强度": 40, "神魂": 45, "因果": 50, "气运": 60}
	c.personality = "沉稳持重，说话慢而稳，遇事先算后果"
	c.goal = "让青石镇在乱世中存续下去"
	c.fear = "妖潮再来一次"
	c.interest = "商路与镇民的安稳"
	c.secret = "年轻时曾独自进过黑风岭深处，见过不该看的东西，从此再未提起"
	c.relationships = {"char_su_zhi": 45, "char_tie_niu": 35, "char_a_ying": -10}
	return c


func _make_su_zhi() -> CharacterData:
	var c := CharacterData.new()
	c.id = "char_su_zhi"
	c.display_name = "苏芷"
	c.title = "回春堂药师"
	c.character_type = CharacterData.CharacterType.CORE_NPC
	c.faction_id = "faction_qingshi_town"
	c.realm_index = 1
	c.realm_layer = 4
	c.spirit_roots = {"木": 65, "水": 30}
	c.dao_heart = {"坚毅": 50, "慈悲": 75, "杀伐": 10, "求知": 70, "自由": 35, "执念": 45}
	c.base_stats = {"hp": 90, "mp": 60, "atk": 6, "def": 5, "m_atk": 14, "m_def": 10, "speed": 7, "crit": 0.05, "accuracy": 0.88, "evasion": 0.08}
	c.spirit_stats = {"灵根强度": 65, "神魂": 55, "因果": 45, "气运": 50}
	c.personality = "温和好奇，见了没见过的药草就走不动路"
	c.goal = "编完《青石百草图鉴》"
	c.fear = "关键灵草绝种"
	c.interest = "稀有药材与失传丹方"
	c.secret = "她认得冥道功法的笔迹——那本该绝迹百年"
	c.relationships = {"char_qin_bo_yuan": 40, "char_tie_niu": 20, "char_a_ying": 5}
	return c


func _make_tie_niu() -> CharacterData:
	var c := CharacterData.new()
	c.id = "char_tie_niu"
	c.display_name = "铁牛"
	c.title = "镇口铁匠"
	c.character_type = CharacterData.CharacterType.CORE_NPC
	c.faction_id = "faction_qingshi_town"
	c.realm_index = 0
	c.realm_layer = 7
	c.spirit_roots = {"金": 55, "火": 35}
	c.dao_heart = {"坚毅": 75, "慈悲": 40, "杀伐": 45, "求知": 20, "自由": 30, "执念": 50}
	c.base_stats = {"hp": 150, "mp": 10, "atk": 16, "def": 12, "m_atk": 2, "m_def": 4, "speed": 6, "crit": 0.05, "accuracy": 0.85, "evasion": 0.04}
	c.spirit_stats = {"灵根强度": 55, "神魂": 40, "因果": 40, "气运": 45}
	c.personality = "豪爽直接，嗓门大，三句话不离打铁"
	c.goal = "打出一把能斩妖的刀"
	c.fear = "手艺失传，炉火熄灭"
	c.interest = "精铁、妖骨与好炭"
	c.secret = "他偷偷收着一块从妖狼尸体上取下的黑铁——那不是凡铁"
	c.relationships = {"char_qin_bo_yuan": 35, "char_su_zhi": 20}
	return c


func _make_a_ying() -> CharacterData:
	var c := CharacterData.new()
	c.id = "char_a_ying"
	c.display_name = "阿萤"
	c.title = "外地来的少女"
	c.character_type = CharacterData.CharacterType.CORE_NPC
	c.faction_id = ""
	c.realm_index = 1
	c.realm_layer = 1
	c.spirit_roots = {"冥": 70}
	c.dao_heart = {"坚毅": 40, "慈悲": 30, "杀伐": 15, "求知": 85, "自由": 60, "执念": 90}
	c.base_stats = {"hp": 70, "mp": 80, "atk": 4, "def": 4, "m_atk": 18, "m_def": 14, "speed": 10, "crit": 0.08, "accuracy": 0.92, "evasion": 0.15}
	c.spirit_stats = {"灵根强度": 70, "神魂": 90, "因果": 85, "气运": 30}
	c.personality = "疏离寡言，语出惊人，眼睛总像在看别处"
	c.goal = "找到'记得死者的人'"
	c.fear = "被遗忘"
	c.interest = "会说真话的人"
	c.secret = "她反复梦见青石镇地底的一道门"
	c.relationships = {}
	return c


func _make_ye_lang_yao() -> CharacterData:
	var c := CharacterData.new()
	c.id = "char_ye_lang_yao"
	c.display_name = "野狼妖"
	c.title = "黑风岭妖兽"
	c.character_type = CharacterData.CharacterType.ENEMY
	c.faction_id = ""
	c.realm_index = 0
	c.realm_layer = 3
	c.spirit_roots = {"风": 50}
	c.dao_heart = {}
	c.base_stats = {"hp": 85, "mp": 0, "atk": 13, "def": 6, "m_atk": 0, "m_def": 3, "speed": 14, "crit": 0.08, "accuracy": 0.85, "evasion": 0.18}
	c.spirit_stats = {"灵根强度": 50, "神魂": 20, "因果": 0, "气运": 10}
	c.personality = "凶戾嗜血"
	c.goal = "捕猎"
	c.fear = "更强的狼王"
	c.interest = "血肉"
	c.secret = "眼中偶尔闪过不属于野兽的幽绿光芒"
	c.relationships = {}
	return c


func _make_hei_feng_dao_fei() -> CharacterData:
	var c := CharacterData.new()
	c.id = "char_hei_feng_dao_fei"
	c.display_name = "黑风盗匪"
	c.title = "黑风岭流匪"
	c.character_type = CharacterData.CharacterType.ENEMY
	c.faction_id = "faction_hei_feng_dao"
	c.realm_index = 0
	c.realm_layer = 5
	c.spirit_roots = {"金": 45}
	c.dao_heart = {"坚毅": 30, "慈悲": 5, "杀伐": 60, "求知": 15, "自由": 55, "执念": 35}
	c.base_stats = {"hp": 110, "mp": 15, "atk": 15, "def": 9, "m_atk": 3, "m_def": 5, "speed": 9, "crit": 0.06, "accuracy": 0.86, "evasion": 0.10}
	c.spirit_stats = {"灵根强度": 45, "神魂": 35, "因果": 30, "气运": 25}
	c.personality = "贪婪狠辣"
	c.goal = "劫够灵石后金盆洗手"
	c.fear = "官府缉拿与岭中妖狼"
	c.interest = "财物"
	c.secret = "他们劫的不只是货——上头有人专门收妖兽尸体"
	c.relationships = {}
	return c


# ---------------------------------------------------------------- 任务（1）

func _gen_quests() -> Array[Resource]:
	var list: Array[Resource] = []

	var q := QuestData.new()
	q.id = "quest_diao_cha_hei_feng_ling"
	q.display_name = "调查黑风岭失踪事件"
	q.description = "青石镇接连有人在黑风岭失踪。镇长秦伯远请你进入黑风岭查明真相，击退作乱的妖兽，并回报调查结果。"
	q.giver = "char_qin_bo_yuan"
	q.requirements = []
	q.objectives = [
		{"type": "到达", "target_id": "region_hei_feng_ling", "count": 1, "params": {}},
		{"type": "战斗", "target_id": "char_ye_lang_yao", "count": 2, "params": {}},
		{"type": "对话", "target_id": "char_qin_bo_yuan", "count": 1, "params": {"topic": "回报调查结果"}},
	]
	q.rewards = [
		{"target": "player", "key": "item:item_ling_shi", "op": "add", "value": 20},
		{"target": "player", "key": "item:item_hui_xue_san", "op": "add", "value": 2},
		{"target": "faction:faction_qingshi_town", "key": "relation", "op": "add", "value": 10},
	]
	q.failure_conditions = []
	q.consequences = [
		{"target": "faction:faction_qingshi_town", "key": "relation", "op": "add", "value": -5},
	]
	q.next_quests = []
	list.append(q)
	return list


# ---------------------------------------------------------------- 事件（1）

func _gen_events() -> Array[Resource]:
	var list: Array[Resource] = []

	var e := EventData.new()
	e.id = "event_shao_nv_zhi_wen"
	e.title = "少女之问"
	e.description = "夜色渐深，阿萤忽然转头问你：「你相信死者会记得生前吗？」她的眼睛在月光下亮得不像话。"
	e.priority = 10
	e.cooldown_days = 0  # 一次性剧情事件：已触发标记由阶段7事件管理器保证
	e.trigger = EventData.Trigger.STATE_CONDITION
	e.conditions = [
		{"key": "player.realm_layer", "op": ">=", "value": 2},
	]
	e.choices = [
		{
			"text": "「相信。逝者只是换了一种方式活着。」",
			"effects": [{"target": "player", "key": "dao_heart.执念", "op": "add", "value": 5}],
			"delayed_effects": [{"target": "char:char_a_ying", "key": "relationship", "op": "add", "value": 10}],
			"hidden_effects": [],
			"requirements": [],
			"hint": "",
		},
		{
			"text": "「不信。人死如灯灭。」",
			"effects": [{"target": "player", "key": "dao_heart.杀伐", "op": "add", "value": 5}],
			"delayed_effects": [{"target": "char:char_a_ying", "key": "relationship", "op": "add", "value": -5}],
			"hidden_effects": [],
			"requirements": [],
			"hint": "",
		},
		{
			"text": "「我不知道……但我想知道。」",
			"effects": [{"target": "player", "key": "dao_heart.求知", "op": "add", "value": 5}],
			"delayed_effects": [{"target": "char:char_a_ying", "key": "relationship", "op": "add", "value": 5}],
			"hidden_effects": [{"target": "world", "key": "flag:a_ying_answer", "op": "set", "value": "curious"}],
			"requirements": [],
			"hint": "",
		},
	]
	e.effects = []
	e.involved_npcs = ["char_a_ying"]
	e.involved_factions = []
	list.append(e)
	return list


# ---------------------------------------------------------------- 对话（4，阶段3）
## 对话 id 约定 dlg_<char_id>；节点结构见 DialogueData Schema（doc 29 §2.10）
## choices.effects 走统一效果格式；接取/回报任务对应 op accept/report

func _gen_dialogues() -> Array[Resource]:
	var list: Array[Resource] = []
	list.append(_make_dlg_qin_bo_yuan())
	list.append(_make_dlg_su_zhi())
	list.append(_make_dlg_tie_niu())
	list.append(_make_dlg_a_ying())
	return list


func _make_dlg_qin_bo_yuan() -> DialogueData:
	var d := DialogueData.new()
	d.id = "dlg_char_qin_bo_yuan"
	d.entry_node_id = "n0"
	d.nodes = [
		{"node_id": "n0", "speaker_id": "char_qin_bo_yuan", "text": "接连有人在黑风岭失踪，镇民人心惶惶……你既是修士，可愿帮老夫一探？", "emotion": "忧虑", "conditions": {}, "choices": [
			{"text": "愿效劳。", "effects": [{"target": "quest", "key": "quest_diao_cha_hei_feng_ling", "op": "accept"}], "next": "n1"},
			{"text": "我已查明真相。", "effects": [{"target": "quest", "key": "quest_diao_cha_hei_feng_ling", "op": "report"}], "next": "n2"},
			{"text": "容我考虑。", "effects": [], "next": "n3"},
		], "next": ""},
		{"node_id": "n1", "speaker_id": "char_qin_bo_yuan", "text": "好！老夫代全镇谢过。岭中妖兽凶戾，务必小心。", "emotion": "郑重", "conditions": {}, "choices": [], "next": ""},
		{"node_id": "n2", "speaker_id": "char_qin_bo_yuan", "text": "……竟有此事？妖狼异常、地下冥气……老夫明白了。这点谢礼请务必收下。", "emotion": "释然", "conditions": {}, "choices": [], "next": ""},
		{"node_id": "n3", "speaker_id": "char_qin_bo_yuan", "text": "老夫等你的消息。", "emotion": "平静", "conditions": {}, "choices": [], "next": ""},
	]
	return d


func _make_dlg_su_zhi() -> DialogueData:
	var d := DialogueData.new()
	d.id = "dlg_char_su_zhi"
	d.entry_node_id = "n0"
	d.nodes = [
		{"node_id": "n0", "speaker_id": "char_su_zhi", "text": "欢迎光临回春堂。最近灵草收成不好，我正想再去岭里采些……", "emotion": "温和", "conditions": {}, "choices": [
			{"text": "需要帮忙吗？", "effects": [], "next": "n1"},
			{"text": "请她辨认功法残页。", "effects": [{"target": "player", "key": "technique", "op": "learn", "value": "technique_yin_ling_jue"}], "next": "n3"},
			{"text": "告辞。", "effects": [], "next": "n2"},
		], "next": ""},
		{"node_id": "n1", "speaker_id": "char_su_zhi", "text": "你有心啦。对了——若在岭里见到奇怪的残页，带来给我看看。我最近在研究一些……很古老的笔迹。", "emotion": "好奇", "conditions": {}, "choices": [], "next": ""},
		{"node_id": "n2", "speaker_id": "char_su_zhi", "text": "慢走。", "emotion": "温和", "conditions": {}, "choices": [], "next": ""},
		{"node_id": "n3", "speaker_id": "char_su_zhi", "text": "……这笔迹！《引灵诀》——我果然没猜错。拿去好生参悟，此功法与你根骨相合。", "emotion": "震惊", "conditions": {}, "choices": [], "next": ""},
	]
	return d


func _make_dlg_tie_niu() -> DialogueData:
	var d := DialogueData.new()
	d.id = "dlg_char_tie_niu"
	d.entry_node_id = "n0"
	d.nodes = [
		{"node_id": "n0", "speaker_id": "char_tie_niu", "text": "嘿，新面孔！想打铁还是听故事？都行——反正炉子一刻不能停！", "emotion": "爽朗", "conditions": {}, "choices": [
			{"text": "聊聊黑风岭。", "effects": [], "next": "n1"},
			{"text": "告辞。", "effects": [], "next": "n2"},
		], "next": ""},
		{"node_id": "n1", "speaker_id": "char_tie_niu", "text": "那帮流寇最近邪门得很！前几日我在岭边捡到块黑铁——嗨，说不上来，反正不是凡铁。你要去岭里，帮我盯着点那帮狼！", "emotion": "激动", "conditions": {}, "choices": [], "next": ""},
		{"node_id": "n2", "speaker_id": "char_tie_niu", "text": "走好嘞！", "emotion": "爽朗", "conditions": {}, "choices": [], "next": ""},
	]
	return d


func _make_dlg_a_ying() -> DialogueData:
	var d := DialogueData.new()
	d.id = "dlg_char_a_ying"
	d.entry_node_id = "n0"
	d.nodes = [
		{"node_id": "n0", "speaker_id": "char_a_ying", "text": "……你也是来问「为什么」的吗？", "emotion": "疏离", "conditions": {}, "choices": [
			{"text": "你相信死者会记得生前吗？", "effects": [], "next": "n1"},
			{"text": "告辞。", "effects": [], "next": "n2"},
		], "next": ""},
		{"node_id": "n1", "speaker_id": "char_a_ying", "text": "……问得好。也许记得的人不是死者——而是还在看着的我们。", "emotion": "认真", "conditions": {}, "choices": [], "next": ""},
		{"node_id": "n2", "speaker_id": "char_a_ying", "text": "嗯。", "emotion": "疏离", "conditions": {}, "choices": [], "next": ""},
	]
	return d


# ---------------------------------------------------------------- 技能（8，阶段4）
## SkillData 字段见 doc 29 §2.3；status_effects 的 status_id 用中文状态名（灼烧/冻结/破甲/atk_buff）

func _gen_skills() -> Array[Resource]:
	var list: Array[Resource] = []
	list.append(_make_skill("skill_ling_qi_dan", "灵气弹", SkillData.SkillType.SINGLE, "木", 25.0, 10, 2.0, 260.0, 0.0, [], "凝聚木行灵气射出，命中造成单体伤害。", ["m_atk"]))
	list.append(_make_skill("skill_qing_teng_chan", "青藤缠", SkillData.SkillType.CONTROL, "木", 0.0, 12, 8.0, 200.0, 0.0, [{"status_id": "冻结", "chance": 1.0, "duration": 2.0, "power": 1.0}], "召出青藤缠住敌人双足，使其定身 2 秒。", []))
	list.append(_make_skill("skill_hui_chun_shu", "回春术", SkillData.SkillType.DEFENSE, "", 30.0, 15, 10.0, 0.0, 0.0, [], "木行生气流转周身，恢复自身气血。", []))
	list.append(_make_skill("skill_lang_feng_ren", "风刃", SkillData.SkillType.SINGLE, "风", 14.0, 0, 3.0, 280.0, 0.0, [], "妖狼啸出的一道风刃。", []))
	list.append(_make_skill("skill_lang_si_ya", "撕咬", SkillData.SkillType.SINGLE, "风", 16.0, 0, 4.0, 60.0, 0.0, [{"status_id": "破甲", "chance": 0.4, "duration": 5.0, "power": 0.3}], "凶狠的撕咬，可能撕裂防御。", []))
	list.append(_make_skill("skill_dao_fei_dao", "飞刀", SkillData.SkillType.SINGLE, "金", 18.0, 0, 3.0, 300.0, 0.0, [], "盗匪掷出的淬毒飞刀。", []))
	list.append(_make_skill("skill_boss_pu_ji", "扑击", SkillData.SkillType.AOE, "风", 22.0, 0, 5.0, 120.0, 90.0, [], "妖狼王腾空扑击，掀起狂风席卷四周。", []))
	list.append(_make_skill("skill_boss_hao_jiao", "嚎叫", SkillData.SkillType.DEFENSE, "", 0.0, 0, 12.0, 0.0, 0.0, [{"status_id": "atk_buff", "chance": 1.0, "duration": 8.0, "power": 0.5}], "狼王仰天长嚎，凶性大发。", []))
	return list


func _make_skill(id: String, display_name: String, type: int, element: String, power: float, mp: int, cd: float, range_px: float, aoe: float, statuses: Array, desc: String, scaling: Array) -> SkillData:
	var s := SkillData.new()
	s.id = id
	s.display_name = display_name
	s.skill_type = type
	s.element = element
	s.power = power
	s.mp_cost = mp
	s.cooldown = cd
	s.cast_range = range_px
	s.aoe_radius = aoe
	var typed_statuses: Array[Dictionary] = []
	typed_statuses.assign(statuses)  # 动态传参退化为 Array，assign 逐元素类型化（源码禁 Array[T](x) 构造）
	var typed_scaling: Array[String] = []
	typed_scaling.assign(scaling)
	s.status_effects = typed_statuses
	s.scaling_stats = typed_scaling
	s.description = desc
	return s


# ---------------------------------------------------------------- Boss（1，阶段4）

func _make_boss() -> CharacterData:
	var c := CharacterData.new()
	c.id = "char_hei_feng_yao_lang_wang"
	c.display_name = "黑风妖狼王"
	c.title = "黑风岭之主"
	c.character_type = CharacterData.CharacterType.ENEMY
	c.faction_id = ""
	c.realm_index = 1
	c.realm_layer = 9  # 炼气九层巅峰（垂直切片 Step 11 Boss）
	c.spirit_roots = {"风": 80}
	c.dao_heart = {}
	c.base_stats = {"hp": 500, "mp": 50, "atk": 20, "def": 10, "m_atk": 8, "m_def": 6, "speed": 11, "crit": 0.08, "accuracy": 0.9, "evasion": 0.1}
	c.spirit_stats = {"灵根强度": 80, "神魂": 45, "因果": 20, "气运": 15}
	c.personality = "凶暴狡诈，统治黑风岭多年"
	c.goal = "吞尽岭中灵气，化形为妖"
	c.fear = "岭下那道门的气息"
	c.interest = "血食"
	c.secret = "它腹下有一道黑色印记——与冥门的气息同源"
	c.relationships = {}
	return c
