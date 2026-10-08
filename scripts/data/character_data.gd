class_name CharacterData
extends Resource
## 角色数据表 Schema（doc 29 §2.1 v1.0 冻结）
## 玩家/核心NPC/NPC/敌人/弟子共用一张表，character_type 区分

enum CharacterType { PLAYER, CORE_NPC, NPC, ENEMY, DISCIPLE }

@export var id: String = ""                            # char_ 前缀，永不因改名变更
@export var display_name: String = ""                  # 显示名
@export var title: String = ""                         # 称号
@export var character_type: CharacterType = CharacterType.NPC
@export var faction_id: String = ""                    # 所属势力（faction_id）
@export var realm_index: int = 0                       # 大境界索引 0~9 → CultivationConstants.REALMS
@export var realm_layer: int = 1                       # 小层 1~9
@export var spirit_roots: Dictionary = {}              # {元素: 纯度0~100}，主1+副0~2（决议#5）
@export var dao_heart: Dictionary = {}                 # {维度: 0~100}，6 维见 CultivationConstants
@export var base_stats: Dictionary = {}                # 战斗10项: hp/mp/atk/def/m_atk/m_def/speed/crit/accuracy/evasion
@export var spirit_stats: Dictionary = {}              # 修仙4项: 灵根强度/神魂/因果/气运
@export var personality: String = ""                   # 性格（doc 05 NPC 五要素）
@export var goal: String = ""                          # 个人目标
@export var fear: String = ""                          # 恐惧
@export var interest: String = ""                      # 利益诉求
@export var secret: String = ""                        # 秘密（剧情钩子）
@export var relationships: Dictionary = {}             # {char_id: 好感 -100~100}
@export var portrait: String = ""                      # 半身立绘路径（空=占位）
@export var avatar: String = ""                        # 头像路径（空=占位）
@export var sprite_path: String = ""                   # 战斗 Sprite 路径（空=占位）

# --- v1.1 敌人战斗字段（doc 29 v1.1 / ADR-008：Phase 7 敌人数据表化，非敌人角色留空默认） ---
@export var enemy_skills: Array[String] = []           # 技能 id 列表（冷却制优先施放，缺省仅普攻）
@export var enemy_element: String = ""                 # 元素（五行克制计算用）
@export var drop_table: Array[Dictionary] = []         # 掉落 [{item_id, count, chance}]
