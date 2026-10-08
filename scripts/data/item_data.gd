class_name ItemData
extends Resource
## 物品数据表 Schema（doc 29 §2.4 v1.0 冻结）
## 资源四级体系见 doc 10；法宝使用 EquipmentData 子类（决议#6）

enum ItemType {
	RESOURCE_T1,      # 一级资源：木/石/铁/粮食
	RESOURCE_T2,      # 二级资源：灵草/灵矿/妖兽材料
	RESOURCE_T3,      # 三级资源：高阶灵材/天材地宝/古仙遗物
	RESOURCE_T4,      # 四级资源：道痕/仙源/冥契碎片
	PILL,             # 丹药
	MATERIAL,         # 炼制材料
	TREASURE,         # 法宝（实例用 EquipmentData）
	QUEST,            # 任务物品
	TECHNIQUE_PAGE,   # 功法残页
}

@export var id: String = ""                            # item_ 前缀
@export var display_name: String = ""
@export var item_type: ItemType = ItemType.MATERIAL
@export var grade: int = 0                             # 品质 0凡~7禁（与功法 Grade 对齐）
@export var stackable: bool = true
@export var base_value: int = 1                        # 基准灵石价（市场波动由阶段8经济系统修正）
@export var effects: Array[Dictionary] = []            # 使用效果（丹药等）[{stat, op, value, duration}]
@export var icon: String = ""                          # 图标路径（空=占位）
@export var description: String = ""
