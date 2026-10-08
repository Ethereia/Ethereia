## 弟子生成器（阶段6）：随机生成弟子数据字典（运行时对象，不落 .tres）
## 生成规则占位：名字池组合/灵根主根+概率副根/性格池/潜力权重；Phase 8 数据表化
class_name DiscipleGenerator

const SURNAMES := ["林", "苏", "叶", "陈", "沈", "顾", "白", "秦"]
const GIVEN_NAMES := ["清越", "寒山", "止水", "凌霜", "云开", "听雨", "望舒", "既明", "长歌", "少阳"]
const PERSONALITIES := ["勤勉", "聪慧", "急躁", "沉稳", "好胜", "淡泊", "多疑", "赤诚"]
const POTENTIAL_WEIGHTS := [30, 30, 20, 15, 5]  # 1~5 星


static func generate() -> Dictionary:
	var name: String = SURNAMES[randi() % SURNAMES.size()] + GIVEN_NAMES[randi() % GIVEN_NAMES.size()]
	return {
		"name": name,
		"age": randi_range(16, 30),
		"realm_index": 0 if randf() < 0.5 else 1,  # 炼体或炼气
		"realm_layer": randi_range(1, 3),
		"spirit_roots": _gen_roots(),
		"personality": PERSONALITIES[randi() % PERSONALITIES.size()],
		"potential": _weighted_potential(),
	}


## 主根 5 基础元素（纯度 40~80），10% 换特殊元素，25% 概率带副根（20~50），≤3 条
static func _gen_roots() -> Dictionary:
	var roots := {}
	var main := CultivationConstants.BASIC_ELEMENTS[randi() % CultivationConstants.BASIC_ELEMENTS.size()]
	if randf() < 0.1:
		main = CultivationConstants.SPIRIT_ROOT_ELEMENTS[randi() % CultivationConstants.SPIRIT_ROOT_ELEMENTS.size()]
	roots[main] = randi_range(40, 80)
	if randf() < 0.25 and roots.size() < CultivationConstants.MAX_SPIRIT_ROOTS:
		var sub := CultivationConstants.SPIRIT_ROOT_ELEMENTS[randi() % CultivationConstants.SPIRIT_ROOT_ELEMENTS.size()]
		if not roots.has(sub):
			roots[sub] = randi_range(20, 50)
	return roots


static func _weighted_potential() -> int:
	var roll := randi() % 100
	var cumulative := 0
	for i in range(POTENTIAL_WEIGHTS.size()):
		cumulative += POTENTIAL_WEIGHTS[i]
		if roll < cumulative:
			return i + 1
	return 1
