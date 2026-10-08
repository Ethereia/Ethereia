class_name CultivationConstants
## 修仙数值骨架常量（doc 29 §1，v1.0 已冻结）
## 纯常量集合，静态访问，不实例化、不入树

## 10 大境界（索引 0~9），DLC 预留：仙君/仙王/古仙/天道境
const REALMS: Array[String] = ["炼体", "炼气", "筑基", "金丹", "元婴", "化神", "炼虚", "合体", "渡劫", "真仙"]

## 每境界小层数
const LAYERS_PER_REALM := 9

## 12 种灵根：5 基础五行 + 7 特殊
const SPIRIT_ROOT_ELEMENTS: Array[String] = ["金", "木", "水", "火", "土", "雷", "冰", "风", "光", "暗", "混沌", "冥"]

## 参与五行克制环的基础元素（特殊属性不参与，doc 08）
const BASIC_ELEMENTS: Array[String] = ["金", "木", "水", "火", "土"]

## 五行克制：键克制值（金→木→土→水→火→金）
const ELEMENT_BEATS: Dictionary = {"金": "木", "木": "土", "土": "水", "水": "火", "火": "金"}

## 道心 6 维
const DAO_HEART_DIMENSIONS: Array[String] = ["坚毅", "慈悲", "杀伐", "求知", "自由", "执念"]

## 天劫 5 类（元婴起触发）
const TRIBULATION_TYPES: Array[String] = ["雷劫", "心魔劫", "因果劫", "冥火劫", "时序劫"]
const TRIBULATION_START_REALM := 4  # 元婴

## 负面状态 7 种
const NEGATIVE_STATES: Array[String] = ["心魔", "灵力紊乱", "走火入魔", "业火", "道心裂痕", "冥契侵蚀", "灵根污染"]

## 突破 8 因子权重（合计 100，doc 29 §1 评审冻结）
const BREAKTHROUGH_WEIGHTS: Dictionary = {
	"realm_exp": 30,        # 境界经验
	"spirit_quality": 15,   # 灵力质量
	"root_affinity": 15,    # 灵根适配
	"dao_heart": 10,        # 道心
	"technique_mastery": 10,# 功法完成度
	"materials": 10,        # 突破材料
	"environment": 5,       # 环境（聚灵阵/秘境/灵脉）
	"random": 5,            # 随机因素
}

## 灵根纯度范围
const PURITY_MIN := 0
const PURITY_MAX := 100

## 道心单维范围
const DAO_HEART_MIN := 0
const DAO_HEART_MAX := 100

## 灵根数量上限：主 1 + 副 2（doc 29 决议 #5）
const MAX_SPIRIT_ROOTS := 3
