## 修仙管理器（阶段5）：境界/经验/功法状态中枢 + 打坐 + 突破结算 + cultivation_state 存档段
## Game 子节点（同 InventoryManager 模式）；realm 运行时值归此管理（player_state 不存，避免双写）
## 突破 8 因子权重见 CultivationConstants.BREAKTHROUGH_WEIGHTS（冻结）；各因子归一化 0~1 加权
class_name CultivationManager
extends Node

var realm_index := 1
var realm_layer := 1
var realm_exp := 0
var learned_techniques: Array[String] = []
var active_technique := ""            # 运功功法 id（空 = 无功法）
var technique_progress: Dictionary = {}  # {technique_id: int}
var meditating := false

@onready var _player: Player = null


func _ready() -> void:
	add_to_group("savable")
	add_to_group("cultivation_manager")
	EventBus.month_changed.connect(_on_month_changed)
	EventBus.enemy_died.connect(_on_enemy_died)
	# 新档默认值来自玩家 CharacterData（懒取：Player 未必先 ready）


func _player_ref() -> Player:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Player
	return _player


func _process(delta: float) -> void:
	if not meditating:
		return
	var efficiency := _technique_efficiency()
	gain_realm_exp(CultivationUtils.MEDITATE_EXP_PER_SEC * efficiency, "打坐")
	# 运功完成度累积
	if not active_technique.is_empty():
		var tech := DataManager.get_entry("techniques", active_technique) as TechniqueData
		if tech != null:
			var cur := int(technique_progress.get(active_technique, 0))
			technique_progress[active_technique] = mini(int(tech.cultivation_progress_max), cur + 1) if randf() < CultivationUtils.TECHNIQUE_PROGRESS_PER_SEC else cur


func is_meditating() -> bool:
	return meditating


func set_meditating(value: bool) -> void:
	meditating = value
	EventBus.cultivation_state_changed.emit()


## 经验入账统一入口：灵力紊乱减半（占位效果）；满层自动升层，九层满停等手动突破
func gain_realm_exp(amount: float, source: String = "") -> void:
	if amount <= 0.0:
		return
	var player := _player_ref()
	if player != null and player.status.has_status("灵力紊乱"):
		amount *= 0.5
	realm_exp += int(round(amount))
	_auto_advance_layers()
	EventBus.cultivation_state_changed.emit()


## 小层自动推进：经验满即升层（溢出保留）；九层满不再自动（大境界突破需手动）
func _auto_advance_layers() -> void:
	var guard := 0
	while realm_layer < CultivationConstants.LAYERS_PER_REALM and realm_exp >= CultivationUtils.required_exp(realm_index, realm_layer):
		realm_exp -= CultivationUtils.required_exp(realm_index, realm_layer)
		realm_layer += 1
		_refresh_player_stats()
		print("[Cultivation] 小层突破：%s" % CultivationUtils.realm_display(realm_index, realm_layer))
		guard += 1
		if guard > 9:
			break


## 大境界突破（九层满 + 经验满可尝试）：8 因子概率结算（doc 03 §9）
func attempt_major_breakthrough() -> void:
	if realm_layer < CultivationConstants.LAYERS_PER_REALM:
		print("[Cultivation] 未达九层，无法大境界突破")
		return
	var need := CultivationUtils.required_exp(realm_index, realm_layer)
	if realm_exp < need:
		print("[Cultivation] 境界经验不足（%d/%d）" % [realm_exp, need])
		return
	var player := _player_ref()
	var score := 0.0
	for factor: String in CultivationUtils.BREAKTHROUGH_FACTORS:
		var value := _factor_value(factor)
		var weight := float(CultivationConstants.BREAKTHROUGH_WEIGHTS.get(factor, 0))
		score += value * weight
	# 功法突破修正（breakthrough_modifiers {factor: ±值}）
	var tech := _active_tech_resource()
	if tech != null:
		score += float(tech.breakthrough_modifiers.get("all", 0.0))
	var probability := clampf(score / 100.0, 0.05, 0.95)
	print("[Cultivation] 大境界突破概率 %.0f%%" % (probability * 100.0))
	if randf() < probability:
		realm_index += 1
		realm_layer = 1
		realm_exp = 0
		_refresh_player_stats()
		_try_tribulation()
		print("[Cultivation] 突破成功！当前 %s" % CultivationUtils.realm_display(realm_index, realm_layer))
		EventBus.realm_breakthrough_success.emit(realm_index)
	else:
		realm_exp = int(realm_exp * 0.7)
		if player != null:
			player.status.apply("灵力紊乱", 60.0, 1.0)  # 60 秒：经验获取减半（占位效果）
		print("[Cultivation] 突破失败，灵力紊乱……")
		EventBus.realm_breakthrough_failed.emit(realm_index)
	EventBus.cultivation_state_changed.emit()


## 8 因子归一化（各 0~1）
func _factor_value(factor: String) -> float:
	var player := _player_ref()
	var tech := _active_tech_resource()
	match factor:
		"realm_exp":
			return minf(1.0, float(realm_exp) / float(CultivationUtils.required_exp(realm_index, realm_layer)))
		"spirit_quality":
			return _main_root_purity(player) / 100.0
		"root_affinity":
			if tech == null or tech.spirit_root_requirement.is_empty():
				return 0.5  # 无功法占位
			var purity := _main_root_purity(player)
			var need: float = float(tech.spirit_root_requirement.values()[0])
			return clampf(purity / maxf(need, 1.0), 0.0, 1.0)
		"dao_heart":
			if player == null or player.stats.data == null or player.stats.data.dao_heart.is_empty():
				return 0.5
			var total := 0.0
			for v: int in player.stats.data.dao_heart.values():
				total += v
			return total / (100.0 * player.stats.data.dao_heart.size())
		"technique_mastery":
			if tech == null:
				return 0.3  # 无功法占位
			return float(technique_progress.get(active_technique, 0)) / float(tech.cultivation_progress_max)
		"materials":
			return 0.5  # 占位：突破材料阶段 6/7 接入
		"environment":
			return 0.5  # 占位：聚灵阵等环境加成阶段 6 接入
		"random":
			return randf()
	return 0.0


func _main_root_purity(player: Player) -> float:
	if player == null or player.stats.data == null or player.stats.data.spirit_roots.is_empty():
		return 50.0
	return float(player.stats.data.spirit_roots.values()[0])


func _active_tech_resource() -> TechniqueData:
	if active_technique.is_empty():
		return null
	return DataManager.get_entry("techniques", active_technique) as TechniqueData


func _technique_efficiency() -> float:
	var tech := _active_tech_resource()
	return tech.cultivation_efficiency if tech != null else 1.0


## 境界变化后重算玩家属性（max 类按倍率，current 按比例保持）
func _refresh_player_stats() -> void:
	var player := _player_ref()
	if player != null:
		player.stats.refresh_by_realm(realm_index, realm_layer, _active_tech_resource())


## 功法学习（残页/药师对话效果入口）：去重，重复学转完成度 +10
func learn_technique(technique_id: String) -> void:
	if learned_techniques.has(technique_id):
		technique_progress[technique_id] = int(technique_progress.get(technique_id, 0)) + 10
		print("[Cultivation] 参悟已有功法：%s 完成度 +10" % technique_id)
	else:
		learned_techniques.append(technique_id)
		if active_technique.is_empty():
			set_active_technique(technique_id)  # 首部功法自动运功
		print("[Cultivation] 习得功法：%s" % technique_id)
	EventBus.cultivation_state_changed.emit()


func set_active_technique(technique_id: String) -> void:
	if not learned_techniques.has(technique_id):
		return
	active_technique = technique_id
	_refresh_player_stats()  # attribute_tendency 变化
	print("[Cultivation] 运功切换：%s" % technique_id)
	EventBus.cultivation_state_changed.emit()


## 天劫占位（doc 03 §10：元婴起触发；阶段 7+ 实现）
func _try_tribulation() -> void:
	if realm_index >= CultivationConstants.TRIBULATION_START_REALM:
		print("[Cultivation] 天劫将至……（阶段 7+ 实现，本次放行）")


# --- 事件入账 ---

func _on_month_changed(_year: int, _month: int) -> void:
	gain_realm_exp(CultivationUtils.MONTHLY_EXP, "月结")


func _on_enemy_died(_enemy_id: String, _region_id: String) -> void:
	gain_realm_exp(CultivationUtils.KILL_EXP, "战斗磨炼")


# --- 存档（cultivation_state 段） ---

func get_save_section() -> String:
	return "cultivation_state"


func get_save_state() -> Dictionary:
	return {
		"realm_index": realm_index,
		"realm_layer": realm_layer,
		"realm_exp": realm_exp,
		"learned_techniques": learned_techniques,
		"active_technique": active_technique,
		"technique_progress": technique_progress,
		"meditating": meditating,
	}


func load_save_state(state: Dictionary) -> void:
	# 用 .get() 带缺省：容忍旧档空段/未知键
	realm_index = int(state.get("realm_index", 1))
	realm_layer = int(state.get("realm_layer", 1))
	realm_exp = int(state.get("realm_exp", 0))
	var learned: Array = state.get("learned_techniques", [])
	learned_techniques.clear()
	for id: String in learned:
		learned_techniques.append(id)
	active_technique = String(state.get("active_technique", ""))
	technique_progress = state.get("technique_progress", {})
	meditating = bool(state.get("meditating", false))
	_refresh_player_stats()  # 主动重算（savable 应用顺序不定，此处兜底）
	EventBus.cultivation_state_changed.emit()
