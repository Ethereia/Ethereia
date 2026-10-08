## 状态容器（阶段4）：玩家/敌人共用的负面/增益状态框架
## 宿主在 _physics_process 调 tick(delta, self)；冻结时宿主跳过移动/攻击（CD 照走）
## status_id 用中文名（灼烧/冻结/破甲/atk_buff），后续状态只加分支不改框架
## 灼烧为周期真伤：直扣宿主 current_hp（绕防御），不破坏 take_damage 调用链
class_name StatusContainer
extends RefCounted

const BURN_TICK_INTERVAL := 1.0

## 条目结构：{status_id, duration, power, _timer}（灼烧用 _timer 计 tick 周期）
var _entries: Array[Dictionary] = []


func apply(status_id: String, duration: float, power: float) -> void:
	for entry in _entries:
		if entry["status_id"] == status_id:
			entry["duration"] = maxf(float(entry["duration"]), duration)  # 刷新时长
			entry["power"] = maxf(float(entry["power"]), power)          # 取较大强度
			return
	_entries.append({"status_id": status_id, "duration": duration, "power": power, "_timer": 0.0})


func tick(delta: float, host: Node) -> void:
	var expired: Array[Dictionary] = []
	for entry: Dictionary in _entries:
		entry["duration"] = float(entry["duration"]) - delta
		if float(entry["duration"]) <= 0.0:
			expired.append(entry)
			continue
		match String(entry["status_id"]):
			"灼烧":
				entry["_timer"] = float(entry["_timer"]) + delta
				if float(entry["_timer"]) >= BURN_TICK_INTERVAL:
					entry["_timer"] = 0.0
					if "current_hp" in host and host.current_hp > 0.0:
						host.current_hp = maxf(0.0, host.current_hp - float(entry["power"]))
						print("[Status] %s 灼烧 %d 真伤" % [host.name, int(entry["power"])])
	for entry in expired:
		_entries.erase(entry)


func is_frozen() -> bool:
	return has_status("冻结")


## 破甲：防御乘 (1 - power)，多重破甲取最大
func defense_multiplier() -> float:
	return 1.0 - get_max_power("破甲")


## 攻击增益（Boss 嚎叫 atk_buff），多重取和（占位）
func attack_multiplier() -> float:
	var total := 1.0
	for entry: Dictionary in _entries:
		if entry["status_id"] == "atk_buff":
			total += float(entry["power"])
	return total


func has_status(status_id: String) -> bool:
	for entry: Dictionary in _entries:
		if entry["status_id"] == status_id:
			return true
	return false


func get_max_power(status_id: String) -> float:
	var best := 0.0
	for entry: Dictionary in _entries:
		if entry["status_id"] == status_id:
			best = maxf(best, float(entry["power"]))
	return best


func clear() -> void:
	_entries.clear()
