## 训练靶子（Phase 2 临时）：验证自动普攻闭环用，无 AI 无移动
## 仅从 DataManager 读取敌人数值；Phase 3 敌人系统另建，本节点届时移除
extends StaticBody2D

const DUMMY_DATA_ID := "char_hei_feng_dao_fei"
const RESET_DELAY := 1.0  # 击破后重置间隔（秒），便于循环测试

var max_hp := 110.0
var current_hp := 110.0
var defense := 9.0

var _resetting := false

@onready var _hp_label: Label = $HPLabel


func _ready() -> void:
	var data := DataManager.get_entry("characters", DUMMY_DATA_ID) as CharacterData
	if data != null:
		max_hp = float(data.base_stats.get("hp", 110.0))
		defense = float(data.base_stats.get("def", 9.0))
		current_hp = max_hp
	else:
		push_warning("TrainingDummy: 缺少数据 %s，用内置占位数值" % DUMMY_DATA_ID)
	_refresh_label()


func take_damage(damage: int, _source: Variant = null) -> void:
	if _resetting:
		return
	current_hp = maxf(0.0, current_hp - damage)
	print("[TrainingDummy] 受到 %d 伤害，剩余 HP %.0f/%.0f" % [damage, current_hp, max_hp])
	if current_hp <= 0.0:
		_resetting = true
		modulate = Color(1.0, 1.0, 1.0, 0.3)
		get_tree().create_timer(RESET_DELAY).timeout.connect(_reset)
	_refresh_label()


func _reset() -> void:
	current_hp = max_hp
	_resetting = false
	modulate = Color.WHITE
	print("[TrainingDummy] 已重置满血")
	_refresh_label()


func _refresh_label() -> void:
	_hp_label.text = "靶子 HP %.0f/%.0f" % [current_hp, max_hp]
