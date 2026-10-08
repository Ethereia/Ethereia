## 战斗公式（doc 08 §4）：数值计算唯一入口，禁止把公式散落进战斗脚本
## 纯静态类：无状态、无副作用，可独立断言测试
## 注意：暴击倍率/防御常数/命中下限均为占位初值，Phase 4 战斗系统落地后统一调参
class_name CombatFormula


## 基础普攻命中判定：命中率 - 闪避率，下限 5%（保证不出现绝对不可能命中的死局）
static func basic_attack_hit(accuracy: float, evasion: float) -> bool:
	return randf() < clampf(accuracy - evasion, 0.05, 1.0)


## 基础普攻伤害（doc 08 §4 骨架的普攻特化）：
## raw = skill_power(普攻基准) * attacker_power(atk)
##       * element_multiplier(普攻无元素 = 1.0) * critical_multiplier
## final = raw * defense_multiplier(def/(def+100)) * state_multiplier(无状态 = 1.0)
static func basic_attack_damage(atk: float, def: float, crit: float) -> int:
	var raw := BASIC_ATTACK_POWER * atk
	var critical_multiplier := CRIT_MULTIPLIER if randf() < crit else 1.0
	var final := raw * critical_multiplier * (1.0 - defense_multiplier(def))
	return maxi(1, int(round(final)))  # 伤害至少 1，避免高防完全免疫


## 五行克制倍率（doc 08 §5，CultivationConstants.ELEMENT_BEATS 键克值）：
## 克制 1.3 / 被克 0.75 / 同属性或任一方为空或特殊属性（不参与基础五行环）→ 1.0
static func element_multiplier(atk_element: String, def_element: String) -> float:
	if atk_element.is_empty() or def_element.is_empty():
		return 1.0
	if not CultivationConstants.BASIC_ELEMENTS.has(atk_element) or not CultivationConstants.BASIC_ELEMENTS.has(def_element):
		return 1.0
	if CultivationConstants.ELEMENT_BEATS.get(atk_element, "") == def_element:
		return ELEMENT_ADVANTAGE
	if CultivationConstants.ELEMENT_BEATS.get(def_element, "") == atk_element:
		return ELEMENT_DISADVANTAGE
	return 1.0


## 技能伤害（doc 08 §4 完整链）：
## raw = skill_power * attacker_power(取 scaling 属性值，由调用方传入)
##       * element_multiplier * critical_multiplier
## final = raw * defense_multiplier * state_multiplier(status_mult，破甲等)
static func skill_damage(power: float, attacker_power: float, atk_element: String, def_element: String, def: float, crit: float, status_mult: float = 1.0) -> int:
	var raw := power * attacker_power
	var critical_multiplier := CRIT_MULTIPLIER if randf() < crit else 1.0
	var final := raw * element_multiplier(atk_element, def_element) * critical_multiplier * status_mult * (1.0 - defense_multiplier(def))
	return maxi(1, int(round(final)))


static func defense_multiplier(def: float) -> float:
	return def / (def + DEFENSE_CONSTANT)


# --- 占位常数（2026-10-08 首次调平；Phase 4 战斗系统再校准） ---
## 调平目标 TTK（炼气一层玩家 150HP / def12 vs 黑风岭敌人）：
##   玩家→野狼妖 4 刀(~4s)、玩家→黑风盗匪 6 刀(~6s)
##   野狼妖→玩家 11 刀(~13s)、盗匪→玩家 9 刀(~11s)：单刀占同级 HP 约 9-11%
##   双敌围攻时玩家约 5s 倒地——需走位拉开，丹药/复活有意义
const BASIC_ATTACK_POWER := 1.2
const CRIT_MULTIPLIER := 1.5
const DEFENSE_CONSTANT := 100.0
const ELEMENT_ADVANTAGE := 1.3
const ELEMENT_DISADVANTAGE := 0.75
