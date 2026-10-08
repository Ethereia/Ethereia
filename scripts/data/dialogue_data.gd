class_name DialogueData
extends Resource
## 对话数据表 Schema（doc 11 节点结构 / doc 29 §2.10 v1.0 冻结）
## node 结构：{node_id, speaker_id, text, emotion, conditions, choices: [{text, effects, next}], next}
## choices.text 支持占位符；effects 为统一效果格式 {target, key, op, value}
## next 指向 node_id，空字符串 = 对话结束

@export var id: String = ""                            # dlg_ 前缀（决议#4）
@export var nodes: Array[Dictionary] = []              # 节点列表，entry 由 entry_node_id 指定
@export var entry_node_id: String = ""                 # 入口节点
