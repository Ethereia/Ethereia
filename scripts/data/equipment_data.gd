class_name EquipmentData
extends ItemData
## 法宝数据 Schema（doc 03 §8 / doc 29 §2.4 决议#6：ItemData 子类）
## 品阶/类型/主属性/固定词条/随机词条/契合度
## 实例化时 item_type 应设为 TREASURE、stackable 设为 false

@export var equip_slot: String = ""                    # 装备位：weapon/armor/accessory/treasure
@export var main_attribute: Dictionary = {}            # 主属性 {stat: value}
@export var fixed_affixes: Array[Dictionary] = []      # 固定词条 [{stat, op, value}]
@export var random_affix_pool: Array[String] = []      # 随机词条池（affix_id，阶段5实现抽取）
@export var attunement_max: int = 100                  # 契合度上限 0~100
