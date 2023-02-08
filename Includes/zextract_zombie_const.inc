#if defined _zerzombie_included
	#endinput
#endif
#define _zerzombie_included

#define ZombieSaveFile "ZExtractZombies.ini"

enum ZombieRegisterData
{
	any: ZRD_SystemName,
	any: ZRD_Name,
	any: ZRD_Model,
	any: ZRD_ClawModel,
	any: ZRD_Health,
	any: ZRD_Gravity,
	any: ZRD_Speed,
	any: ZRD_Knockback,
	any: ZRD_JumpVelocity,
	any: ZRD_Gender,
	any: ZRD_DeadSound[2],
	any: ZRD_HitSound[2],
	any: ZRD_Flags,
	any: ZRD_MenuAvailable
}