## 玩家属性容器（Phase 2）：纯数值状态，不发信号以外的副作用
## 从 CharacterData 装载（doc 29 Schema v1.0），境界成长倍率经 CultivationUtils 换算
## 数值变化统一 emit EventBus.player_stats_changed（无参信号，监听方主动拉取）
class_name PlayerStats
extends RefCounted

var data: CharacterData = null

var max_hp := 100.0
var current_hp := 100.0
var max_mp := 50.0
var current_mp := 50.0
var max_stamina := 100.0  # 体力运行时占位（Schema 冻结无此键）：普攻/近战技能资源，Phase 5 接入
var current_stamina := 100.0

var atk := 10.0
var defense := 5.0
var m_atk := 5.0
var m_def := 5.0
var base_speed := 8.0
var crit := 0.05
var accuracy := 0.9
var evasion := 0.05

var _dead := false  # player_died 只发一次


## 从角色数据装载；base_stats 是 Dictionary 无编译期检查，缺键用占位缺省兜底
## 境界倍率只作用于数值类属性（hp/mp/攻防），百分比类（暴击/命中/闪避）不乘
func setup(p_data: CharacterData) -> void:
	data = p_data
	var bs: Dictionary = p_data.base_stats
	var mult := CultivationUtils.stat_multiplier(p_data.realm_index, p_data.realm_layer)
	max_hp = float(bs.get("hp", 100.0)) * mult
	max_mp = float(bs.get("mp", 50.0)) * mult
	atk = float(bs.get("atk", 10.0)) * mult
	defense = float(bs.get("def", 5.0)) * mult
	m_atk = float(bs.get("m_atk", 5.0)) * mult
	m_def = float(bs.get("m_def", 5.0)) * mult
	base_speed = float(bs.get("speed", 8.0))
	crit = float(bs.get("crit", 0.05))
	accuracy = float(bs.get("accuracy", 0.9))
	evasion = float(bs.get("evasion", 0.05))
	current_hp = max_hp
	current_mp = max_mp
	max_stamina = 100.0
	current_stamina = 100.0
	_dead = false


## 境界/运功变化后重算（阶段5）：max 类按新倍率，current 按原比例保持，应用功法属性倾向
## 由 CultivationManager 调用（realm 运行时值归管理器所有）
func refresh_by_realm(realm_index: int, realm_layer: int, technique: TechniqueData) -> void:
	if data == null:
		return
	var hp_ratio := current_hp / max_hp if max_hp > 0.0 else 1.0
	var mp_ratio := current_mp / max_mp if max_mp > 0.0 else 1.0
	var mult := CultivationUtils.stat_multiplier(realm_index, realm_layer)
	var bs: Dictionary = data.base_stats
	max_hp = float(bs.get("hp", 100.0)) * mult
	max_mp = float(bs.get("mp", 50.0)) * mult
	atk = float(bs.get("atk", 10.0)) * mult
	defense = float(bs.get("def", 5.0)) * mult
	m_atk = float(bs.get("m_atk", 5.0)) * mult
	m_def = float(bs.get("m_def", 5.0)) * mult
	# 功法属性倾向（attribute_tendency {stat: 百分比加成}）
	if technique != null:
		for stat: String in technique.attribute_tendency:
			var bonus: float = float(technique.attribute_tendency[stat])
			match stat:
				"atk": atk *= 1.0 + bonus
				"def": defense *= 1.0 + bonus
				"m_atk": m_atk *= 1.0 + bonus
				"m_def": m_def *= 1.0 + bonus
				"hp": max_hp *= 1.0 + bonus
				"mp": max_mp *= 1.0 + bonus
	current_hp = clampf(hp_ratio * max_hp, 1.0, max_hp)
	current_mp = clampf(mp_ratio * max_mp, 0.0, max_mp)
	_dead = current_hp <= 0.0
	EventBus.player_stats_changed.emit()


func take_damage(amount: float) -> void:
	if _dead or amount <= 0.0:
		return
	current_hp = maxf(0.0, current_hp - amount)
	EventBus.player_stats_changed.emit()
	if current_hp <= 0.0:
		_dead = true
		EventBus.player_died.emit()


func heal(amount: float) -> void:
	if _dead or amount <= 0.0:
		return
	current_hp = minf(max_hp, current_hp + amount)
	EventBus.player_stats_changed.emit()


## 灵力消耗：不足时返回 false 且不扣除
func spend_mp(amount: float) -> bool:
	if _dead or amount < 0.0 or current_mp < amount:
		return false
	current_mp -= amount
	EventBus.player_stats_changed.emit()
	return true


func restore_mp(amount: float) -> void:
	current_mp = minf(max_mp, current_mp + maxf(0.0, amount))
	EventBus.player_stats_changed.emit()


## 复活（阶段3占位：按比例回血 + 清除死亡标记；阶段5 修仙死亡惩罚另做）
func revive(health_ratio: float = 0.5) -> void:
	_dead = false
	current_hp = maxf(1.0, max_hp * clampf(health_ratio, 0.0, 1.0))
	EventBus.player_stats_changed.emit()
