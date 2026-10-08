## 修仙数值工具（doc 03 / doc 29 §1）：境界换算与成长曲线，纯静态无状态
## 数值均为占位曲线，Phase 5 修仙系统落地后统一调参
class_name CultivationUtils


## 境界→属性成长倍率（占位线性）：大境界主导 + 小层微调
## 例：炼体一层 1.0 → 真仙九层 5.4；实际曲线待 Phase 5 结合突破系统设计
static func stat_multiplier(realm_index: int, realm_layer: int) -> float:
	return 1.0 + realm_index * 0.5 + (realm_layer - 1) * 0.05


## 战斗速度（base_stats.speed，无量纲）→ 移动像素速度
## CharacterData Schema 已冻结不能加 move_speed 字段，由系数换算（占位 30 px/点）
static func move_speed(base_speed: float) -> float:
	return base_speed * 30.0


## 境界显示名：炼气一层 / 筑基三层……
static func realm_display(realm_index: int, realm_layer: int) -> String:
	var index := clampi(realm_index, 0, CultivationConstants.REALMS.size() - 1)
	var layer := clampi(realm_layer, 1, CultivationConstants.LAYERS_PER_REALM)
	var cn_layers := ["一", "二", "三", "四", "五", "六", "七", "八", "九"]
	return CultivationConstants.REALMS[index] + cn_layers[layer - 1] + "层"
