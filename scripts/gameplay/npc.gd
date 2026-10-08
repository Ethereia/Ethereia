## 世界 NPC（阶段3）：站场展示 + 可交互对话入口
## 交互链路：玩家按 E → Player 调 interact() → emit npc_interacted → DialogueUI 接管
class_name Npc
extends StaticBody2D

var npc_id := ""
var display_name := ""

@onready var _name_label: Label = $NameLabel
@onready var _hint_label: Label = $InteractHint
@onready var _sense_area: Area2D = $SenseArea


func setup(p_id: String, p_name: String) -> void:
	npc_id = p_id
	display_name = p_name


func _ready() -> void:
	_name_label.text = display_name
	_hint_label.visible = false
	_sense_area.body_entered.connect(_on_body_entered)
	_sense_area.body_exited.connect(_on_body_exited)


## 统一交互接口（与 ResourceNode 一致，Player 按可交互体最近的调这里）
func interact() -> void:
	# 对话 id 约定 dlg_<char_id>（CharacterData Schema 冻结不能加字段，Phase 7 数据表化）
	EventBus.npc_interacted.emit(npc_id, "dlg_" + npc_id)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_hint_label.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_hint_label.visible = false
