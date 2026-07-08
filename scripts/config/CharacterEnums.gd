extends RefCounted
## 全局枚举：角色战斗相关枚举，所有使用脚本需本地const _CE := preload(...)
## 避免class_name全局注册带来的文件扫描顺序依赖
## V0.3a-A6 新增（原有枚举值不动，O03 冻结旧值）

enum BaseState {
	IDLE = 0,
	RUN = 1,
	JUMP = 2,
	DOUBLEJUMP = 3,
	DASH = 4,
	ATTACK1 = 5,
	ATTACK2 = 6,
	ATTACK3 = 7,
	BLOCK = 8,
	HURT = 9,
	DEAD = 10
}

enum CharacterKind {
	INVALID = 0,
	PLAYER = 1,
	COMPANION = 2,
	ENEMY = 3
}

# ---------- V0.3a 新增枚举（旧枚举不做任何修改） ----------
enum Layer {
	PLAYER = 1,
	ENEMY = 2,
	PROJECTILE_PLAYER = 4,
	PROJECTILE_ENEMY = 8,
	PICKUP = 16,
	WALL = 32,
	FLOOR = 64,
	TRIGGER = 128
}

enum DamageType {
	PHYSICAL = 0,
	ARROW = 1,
	FALL = 2,
	FIRE = 3,
	POISON = 4
}

enum PickupKind {
	NONE = 0,
	GOLD = 1,
	POTION_HP = 2,
	POTION_STAMINA = 3,
	WEAPON = 4,
	SHIELD = 5,
	QUEST = 6
}

enum WeaponFlag {
	NONE = 0,
	BREAK_SHIELD = 1,
	THROWS_PROJECTILE = 2,
	ALLY_HEAL = 4,
	COMBO_3_STEP = 8
}

enum Facing {
	LEFT = -1,
	RIGHT = 1
}
