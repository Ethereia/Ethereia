## 时间管理器：世界时间（年/月/日）推进
## 完整的月/季/年结算调度在阶段8实现（doc 07 循环、doc 19 Phase 8）
extends Node

const MONTHS_PER_YEAR := 12

var year := 1
var month := 1  # 1~12
var day := 1    # 行动计数占位，阶段8细化

func _ready() -> void:
	add_to_group("savable")

func advance_month(steps: int = 1) -> void:
	for i in steps:
		month += 1
		if month > MONTHS_PER_YEAR:
			month = 1
			year += 1
			EventBus.year_changed.emit(year)
	EventBus.month_changed.emit(year, month)

func get_season() -> int:
	return (month - 1) / 3 + 1  # 1春 2夏 3秋 4冬

func reset() -> void:
	year = 1
	month = 1
	day = 1

func get_save_state() -> Dictionary:
	return {"year": year, "month": month, "day": day}

func load_save_state(state: Dictionary) -> void:
	year = int(state.get("year", 1))
	month = int(state.get("month", 1))
	day = int(state.get("day", 1))
	EventBus.month_changed.emit(year, month)
