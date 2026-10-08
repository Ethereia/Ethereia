## 战斗公式（doc 08 §4）：数值计算唯一入口，禁止把公式散落进战斗脚本
## 纯静态类：无状态、无副作用，可独立断言测试
## 注意：暴击倍率/防御常数/命中下限均为占位初值，Phase 4 战斗系统落地后统一调参
class_name CombatFormula


## 基础普攻命中判定：命中率 - 闪避率，下限 5%（保证不出现绝对不可能命中的死局）
static func basic_attack_hit(accuracy: float, evasion: float) -> bool:
	return randf() < clampf(accuracy - evasion, 0.05, 1.0)


## 基础普攻伤害（doc 08 §4 骨架的普攻特化）：
## raw = skill_power(普攻基准 10，占位) * attacker_power(atk)
##       * element_multiplier(普攻无元素 = 1.0) * critical_multiplier
## final = raw * defense_multiplier(def/(def+100)) * state_multiplier(无状态 = 1.0)
static func basic_attack_damage(atk: float, def: float, crit: float) -> int:
	var raw := BASIC_ATTACK_POWER * atk
	var critical_multiplier := CRIT_MULTIPLIER if randf() < crit else 1.0
	var defense_multiplier := def / (def + DEFENSE_CONSTANT)
	var final := raw * critical_multiplier * (1.0 - defense_multiplier)
	return maxi(1, int(round(final)))  # 伤害至少 1，避免高防完全免疫


# --- 占位常数（Phase 4 调参集中在此） ---
const BASIC_ATTACK_POWER := 10.0
const CRIT_MULTIPLIER := 1.5
const DEFENSE_CONSTANT := 100.0
