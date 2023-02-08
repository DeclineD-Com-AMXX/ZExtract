#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <engine>
#include <reapi>
#include <xs>

#include <amx_settings_api>

#include <zextract_const>

#include <zextract_class_const>
#include <zextract_zombie_const>

#include <zextract_human>

#define IsPlayer(%0) 		( (0 < %0 < 33) && is_user_connected( %0 ) )

#define TASK_TEAM 888423842

new g_bfZombie,
	g_iClass[33],
	g_iNClass[33],

	g_iZombieCount

new g_ClassData[ZombieRegisterData];

// Knockback
new KB_DAMAGE = 1
new KB_POWER = 1
new KB_CLASS = 1
new Float:KB_DUCKING = 0.25
new Float:KB_DISTANCE = 750.0

new Float:kb_weapon_power[] = 
{
	-1.0,	// ---
	1.2,	// P228
	-1.0,	// ---
	3.5,	// SCOUT
	-1.0,	// ---
	4.0,	// XM1014
	-1.0,	// ---
	1.3,	// MAC10
	2.5,	// AUG
	-1.0,	// ---
	1.2,	// ELITE
	1.0,	// FIVESEVEN
	1.2,	// UMP45
	2.25,	// SG550
	2.25,	// GALIL
	2.25,	// FAMAS
	1.1,	// USP
	1.0,	// GLOCK18
	2.5,	// AWP
	1.25,	// MP5NAVY
	2.25,	// M249
	4.0,	// M3
	2.5,	// M4A1
	1.2,	// TMP
	3.25,	// G3SG1
	-1.0,	// ---
	2.15,	// DEAGLE
	2.5,	// SG552
	3.0,	// AK47
	-1.0,	// ---
	1.0,	// P90
	-1.0 // ---
}

new const hurtDefaultSounds[][] = {
	"bhit_flesh-1", "bhit_flesh-2", "bhit_flesh-3", "bhit_helmet-1", "bhit_kevlar-1", "pl_pain2", "pl_pain4", "pl_pain5", "pl_pain6", "pl_pain7", "headshot1", "headshot2", "headshot3", "pl_fallpain1", "pl_fallpain2", "pl_fallpain3"
}

new const dieDefaultSounds[][] = {
	"die1", "die2", "die3", "death6", "pl_die1"
}

new g_DataKeys[ZombieRegisterData][] = {
	"", 
	"NAME",
	"MODEL",
	"CLAW",
	"HEALTH",
	"GRAVITY",
	"SPEED",
	"KNOCKBACK",
	"JUMP_POWER",
	"GENDER",
	"DEAD_SOUND1",
	"DEAD_SOUND2",
	"PAIN_SOUND1",
	"PAIN_SOUND2",
	"PLAYER_FLAGS",
	"MENU_AVAILABLE"
}

enum _: PlgForwards
{
	FWD_CLASS_CHANGE,
	FWD_CLASS_CHANGE_POST
}

new g_iForwards[PlgForwards];

new bool: g_bPrecache

new msgDeathMsg, msgScoreAttrib

public plugin_init()
{
	g_bPrecache = false

	if (!g_iZombieCount)
		set_fail_state("No zombie classes")

	register_plugin("ZExtract: Zombie Class", "-", "-")
	
	RegisterHamPlayer(Ham_Player_Jump,  "HamHook_Player_Jump"  		 )
	RegisterHamPlayer(Ham_Spawn, 		"HamHook_Spawn_Post", 		1)
	RegisterHamPlayer(Ham_TraceAttack, 	"HamHook_TraceAttack_Post", 1)

	RegisterHam(Ham_Use, "func_tank", "fw_UseStationary")
	RegisterHam(Ham_Use, "func_tankmortar", "fw_UseStationary")
	RegisterHam(Ham_Use, "func_tankrocket", "fw_UseStationary")
	RegisterHam(Ham_Use, "func_tanklaser", "fw_UseStationary")
	RegisterHam(Ham_Use, "func_tank", "fw_UseStationary_Post", 1)
	RegisterHam(Ham_Use, "func_tankmortar", "fw_UseStationary_Post", 1)
	RegisterHam(Ham_Use, "func_tankrocket", "fw_UseStationary_Post", 1)
	RegisterHam(Ham_Use, "func_tanklaser", "fw_UseStationary_Post", 1)
	RegisterHam(Ham_Touch, "weaponbox", "fw_TouchWeapon")
	RegisterHam(Ham_Touch, "armoury_entity", "fw_TouchWeapon")
	RegisterHam(Ham_Touch, "weapon_shield", "fw_TouchWeapon")

	RegisterHam(Ham_Item_Deploy, "weapon_knife", "HamHook_KnifeDeploy_Post", 1)

	RegisterHookChain(RG_CBasePlayer_SetClientUserInfoModel, "ReHook_Player_Model")

	register_forward(FM_EmitSound, "FmHook_EmitSound")

	register_clcmd("say /zombies", "cmdZombies")

	msgDeathMsg = 	 get_user_msgid("DeathMsg")
	msgScoreAttrib = get_user_msgid("ScoreAttrib")
}

public plugin_precache()
{
	g_bPrecache = true

	g_ClassData[ZRD_SystemName] = 		ArrayCreate(20,  1)
	g_ClassData[ZRD_Name] = 			ArrayCreate(30,  1)
	g_ClassData[ZRD_Model] = 	 		ArrayCreate(30,  1)
	g_ClassData[ZRD_ClawModel] =		ArrayCreate(128, 1)
	g_ClassData[ZRD_Health] = 	 		ArrayCreate(1,   1)
	g_ClassData[ZRD_Gravity] = 	 		ArrayCreate(1,   1)
	g_ClassData[ZRD_Speed] = 	 		ArrayCreate(1,   1)
	g_ClassData[ZRD_Knockback] =		ArrayCreate(1,   1)
	g_ClassData[ZRD_Gender] = 	 		ArrayCreate(1,   1)
	g_ClassData[ZRD_JumpVelocity] = 	ArrayCreate(1,   1)
	g_ClassData[ZRD_Flags] = 			ArrayCreate(1,   1)
	g_ClassData[ZRD_MenuAvailable] = 	ArrayCreate(1,   1)

	for(new i; i < 2; i++)
	{
		g_ClassData[ ZRD_DeadSound ][ i ] = 	ArrayCreate(128, 1)
		g_ClassData[ ZRD_HitSound ][ i ] = 		ArrayCreate(128, 1)
	}

	g_iForwards[FWD_CLASS_CHANGE] = 	 CreateMultiForward("ZEX_ToZombie", ET_STOP, FP_CELL, FP_CELL)
	g_iForwards[FWD_CLASS_CHANGE_POST] = CreateMultiForward("ZEX_ToZombie_Post", ET_IGNORE, FP_CELL, FP_CELL)
}

public plugin_natives()
{
	register_native("zex_register_zombie", 		 	"native_register"		 )
	register_native("zex_is_zombie",				"native_iszombie",		1)
	register_native("zex_set_zombie",			 	"native_setzombie", 	1)
	register_native("zex_get_zombie_class", 		"native_getclass", 		1)
	register_native("zex_set_zombie_class", 		"native_setclass", 		1)
	register_native("zex_get_next_zombie_class",  	"native_getnextclass", 	1)
	register_native("zex_set_next_zombie_class",	"native_setnextclass", 	1)
	register_native("zex_get_zombie_class_count", 	"native_classcount", 	1)
	register_native("zex_get_zombie_class_info",  	"native_classinfo"		 )
	register_native("zex_get_zombie_class_id",		"native_getclassid",	1)
}

public client_putinserver(id)
{
	g_iClass[id] = 0
	g_iNClass[id] = 0

	remove_bit(g_bfZombie, id)
}

public cmdZombies(id)
{
	new szText[256];

	formatex(szText, charsmax(szText), "\rZombie \yMenu")

	new menu = menu_create(szText, "zmHandler")
	new szName[20]

	new callback = menu_makecallback("zmenuCheck")

	for(new i = 0; i < g_iZombieCount; i++)
	{
		ArrayGetString(g_ClassData[ZRD_Name], i, szName, charsmax(szName))

		formatex(szText, charsmax(szText), "%s%s", ( ( i == g_iNClass[id] ) ? "\r" : ( CheckUserValidFlags(id, i) ? "\w" : "\d" ) ), szName)
		menu_additem(menu, szText, .callback = callback)
	}

	menu_display(id, menu)
}

public zmHandler(id, menu, item)
{
	g_iNClass[id] = item
	menu_destroy(menu)
}

public zmenuCheck(id, menu, item)
{
	if(!CheckUserValidFlags(id, item) || g_iNClass[id] == item)
		return ITEM_DISABLED;

	return ITEM_ENABLED;
}

public fw_UseStationary(entity, caller, activator, use_type)
{
	if (use_type == 2 && is_user_connected(caller) && is_bit(g_bfZombie, caller))
		return HAM_SUPERCEDE
	
	return HAM_IGNORED
}

public fw_UseStationary_Post(entity, caller, activator, use_type)
{
	if(use_type == 0 && is_user_connected(caller) && is_bit(g_bfZombie, caller))
	{
		// Reset Claws
		static Claw2[128]
		ArrayGetString(g_ClassData[ZRD_ClawModel], g_iClass[caller], Claw2, charsmax(Claw2))
			
		set_pev(caller, pev_viewmodel2, Claw2)
		set_pev(caller, pev_weaponmodel2, "")	
	}
}

public fw_TouchWeapon(weapon, id)
{
	if(!is_user_connected(id))
		return HAM_IGNORED

	if(is_bit(g_bfZombie, id))
		return HAM_SUPERCEDE
	
	return HAM_IGNORED
}

public FmHook_EmitSound(entity, channel, const sample[], Float:vol, Float:att, flags, pitch)
{
	if(!IsPlayer(entity))
	{
		return FMRES_IGNORED;
	}

	if(is_bit(g_bfZombie, entity))
	{
		return FMRES_IGNORED;
	}

	new text[100]
	for(new i = 0; i < sizeof hurtDefaultSounds; i++)
	{
		if(i < sizeof dieDefaultSounds)
		{
			formatex(text, charsmax(text), "player/%s.wav", dieDefaultSounds[i])
			if(equal(sample, text))
			{
				new szSound[128];
				ArrayGetString(g_ClassData[ZRD_DeadSound][random_num(0, 1)], g_iClass[entity], szSound, charsmax(szSound))

				emit_sound(entity, channel, szSound, vol, att, flags, pitch)
				return FMRES_SUPERCEDE;
			}
		}

		formatex(text, charsmax(text), "player/%s.wav", hurtDefaultSounds[i])
		if(equal(sample, text))
		{
			new szSound[128];
			ArrayGetString(g_ClassData[ZRD_HitSound][random_num(0, 1)], g_iClass[entity], szSound, charsmax(szSound))

			emit_sound(entity, channel, szSound, vol, att, flags, pitch)
			return FMRES_SUPERCEDE;
		}
	}
	
	return FMRES_IGNORED;
}

public HamHook_TraceAttack_Post(victim, attacker, Float:damage, Float:direction[3], tracehandle, damagebits)
{
	if((victim == attacker) || (damagebits & DMG_GRENADE) || !IsPlayer(attacker) || !IsPlayer(victim)
		|| !is_bit(g_bfZombie, victim) || !zex_is_human(attacker))
	{
		return;
	}

	new Float:velo[3], Float:flOrigin[3], Float:flOrigin2[3], gun, iActiveItem
	get_entvar(victim, var_velocity, velo)

	get_entvar(victim, var_origin, flOrigin)
	get_entvar(attacker, var_origin, flOrigin2)

	if(KB_DISTANCE <= get_distance_f(flOrigin, flOrigin2))
		return;

	iActiveItem = get_member(attacker, m_pActiveItem)
	gun = rg_get_iteminfo(iActiveItem, ItemInfo_iId)

	xs_vec_add(velo, direction, direction)

	if(KB_DAMAGE)
	{
		direction[0] += damage
		direction[1] += damage
		direction[2] += damage
	}

	if(KB_POWER)
		xs_vec_mul_scalar(direction, kb_weapon_power[gun], direction)

	if(KB_CLASS)
		xs_vec_mul_scalar(direction, ArrayGetCell(g_ClassData[ZRD_Knockback], g_iClass[victim])/100.0, direction)

	new duck = (get_entvar(victim, var_flags) & (FL_ONGROUND | FL_DUCKING))

	if(duck)
		xs_vec_mul_scalar(direction, KB_DUCKING, direction)
	
	set_entvar(victim, var_velocity, direction)
}

public HamHook_Player_Jump(id)
{
	if(!IsPlayer(id))
	{
		return HAM_IGNORED;
	}

	if(!is_bit(g_bfZombie, id))
	{
		return HAM_IGNORED;
	}

	new oldButtons = get_entvar(id, var_oldbuttons)
	new Button = get_entvar(id, var_button)

	if((oldButtons & IN_JUMP) || !(get_entvar(id, var_flags) & FL_ONGROUND))
	{
		return HAM_IGNORED;
	}

	oldButtons |= IN_JUMP
	Button &= ~IN_JUMP

	set_entvar(id, var_oldbuttons, oldButtons)
	set_entvar(id, var_button, Button)

	new Float: flVelocity[3];
	get_entvar(id, var_velocity, flVelocity)

	flVelocity[2] = float(ArrayGetCell(g_ClassData[ZRD_JumpVelocity], g_iClass[id]))

	set_entvar(id, var_velocity, flVelocity)

	return HAM_SUPERCEDE;
}

public HamHook_Spawn_Post(id)
{
	if(!is_user_alive(id))
		return;

	if(!is_bit(g_bfZombie, id))
		return;

	SetClassAttribs(id, true)
}

public HamHook_KnifeDeploy_Post(item)
{
	static iId; iId = get_member(item, m_pPlayer)

	if(!IsPlayer(iId))
	{
		return;
	}

	if(is_bit(g_bfZombie, iId))
	{
		return;
	}

	new szClawModel[128];
	ArrayGetString(g_ClassData[ZRD_ClawModel], g_iClass[iId], szClawModel, charsmax(szClawModel))

	set_entvar(iId, var_viewmodel, szClawModel)
	set_entvar(iId, var_weaponmodel, "")
}

public ReHook_Player_Model(id, infobuffer[], szNewModel[])
{
	if(!is_bit(g_bfZombie, id))
		return HC_CONTINUE;

	new szModel[32];
	ArrayGetString(g_ClassData[ZRD_Model], g_iClass[id], szModel, charsmax(szModel))

	SetHookChainArg(3, ATYPE_STRING, szModel, charsmax(szModel))
	return HC_CONTINUE;
}

public native_getclassid(sysname[])
{
	for(new i = 0; i < g_iZombieCount; i++)
	{
		new g_iName[20]
		ArrayGetString(g_ClassData[ZRD_SystemName], i, g_iName, charsmax(g_iName))

		if(equali(g_iName, sysname))
			return i;
	}

	return -1;
}

public native_iszombie(id)
{
	return is_bit(g_bfZombie, id)
}

public native_getclass(id)
{
	if(!IsPlayer(id))
	{
		return 0;
	}

	return g_iClass[id];
}

public native_getnextclass(id)
{
	if(!IsPlayer(id))
	{
		return 0;
	}

	return g_iNClass[id];
}

public native_setnextclass(id, class)
{
	if(!IsPlayer(id))
		return 0;

	if(0 < class < g_iZombieCount)
	{
		log_error(AMX_ERR_NATIVE, "Unrecognizable zombie class")
		return 0;
	}

	g_iNClass[id] = class

	return 1;
}

public native_setclass(id, class, bool: ignoreFlag)
{
	if(!native_setnextclass(id, class))
		return 0;

	if(!is_bit(g_bfZombie, id))
		return 0;

	ChangeClass(id, .setZombie = bool: is_bit(g_bfZombie, id), .ignoreFlag = ignoreFlag, .reset = false)

	return 1;
}

public native_setzombie(id, bool: zombie, attacker, bool: applyAttributes, bool: ignoreFlag)
{
	if(!IsPlayer(id))
	{
		return;
	}

	ChangeClass(id, attacker, zombie, applyAttributes, ignoreFlag);
}

public native_classcount()
{
	return g_iZombieCount;
}

public native_classinfo(plgId, paramnum)
{
	new zombieClass = get_param(1)

	if(0 < zombieClass < g_iZombieCount)
	{
		log_error(AMX_ERR_NATIVE, "Unrecognizable zombie class")
		return 0;
	}

	new ZombieRegisterData: infoData = ZombieRegisterData: get_param(2)

	if(0 < _:infoData < _:ZombieRegisterData)
	{
		log_error(AMX_ERR_NATIVE, "Unrecognizable ZombieRegisterData")
		return 0;
	}

	new type, Array:infoArray

	switch(infoData)
	{
		case ZRD_Name:
		{
			if(paramnum < 4)
				return 0;

			type = 1
			infoArray = g_ClassData[ZRD_Name]
		}

		case ZRD_SystemName:
		{
			if(paramnum < 4)
				return 0;

			type = 1
			infoArray = g_ClassData[ZRD_SystemName]
		}

		case ZRD_Model:
		{
			if(paramnum < 4)
				return 0;

			type = 1
			infoArray = g_ClassData[ZRD_Model]
		}

		case ZRD_ClawModel:
		{
			if(paramnum < 4)
			 	return 0;

			type = 1
			infoArray = g_ClassData[ZRD_ClawModel]
		}

		case ZRD_DeadSound:
		{
			if(paramnum < 5)
				return 0;

			type = 2
			infoArray = g_ClassData[ZRD_DeadSound][get_param(3)]
		}

		case ZRD_HitSound:
		{
			if(paramnum < 5)
				return 0;

			type = 2
			infoArray = g_ClassData[ZRD_HitSound][get_param(3)]
		}

		default:
		{
			type = 0
			infoArray = Array: g_ClassData[infoData]
		}
	}

	if(type == 0)
	{
		return ArrayGetCell(infoArray, zombieClass);
	}
	else if(type == 1)
	{
		new szStr[MAX_STRING_LENGTH];
		ArrayGetString(infoArray, zombieClass, szStr, charsmax(szStr))

		new len = get_param(4)

		set_string(3, szStr, len)
		return 1;
	}
	else if(type == 2)
	{
		new szStr[MAX_STRING_LENGTH];
		ArrayGetString(infoArray, zombieClass, szStr, charsmax(szStr))

		new len = get_param(5)

		set_string(4, szStr, len)
		return 1;
	}

	return 0;
}

public native_register(plgId, paramnum)
{
	if(paramnum < _:ZombieRegisterData - 1)
	{
		log_error(AMX_ERR_NATIVE, "Not enough params.");
		return -1;
	}

	if(!g_bPrecache)
	{
		log_error(AMX_ERR_NATIVE, "Cannot precache resources. Canceling register process.");
		return -1;
	}
// name, model, hp, gravity, speed, gender, jump, flags, menu_available, dead_sound1, dead_sound2, hit_sound1, hit_sound2
	new szName[20],
		szName2[30],
		szModel[30],
		szClawModel[128],
		iHp = 			get_param(5),
		iGravity =  	get_param(6),
		iSpeed = 		get_param(7),
		iKnockback = 	get_param(8),
		Sex: iGender = 	Sex:get_param(9),
		iJump = 		get_param(10),
		iFlags = 		get_param(11),
		iMAvailable = 	get_param(12),
		szDeadSound[2][60],
		szHitSound[2][60];

	get_string(1, szName,				charsmax(szName))
	get_string(2, szName2, 				charsmax(szName2));
	get_string(3, szModel, 				charsmax(szModel));
	get_string(4, szClawModel,			charsmax(szClawModel));

	get_string(13, szDeadSound[0],	charsmax(szDeadSound[]));
	get_string(14, szDeadSound[1],	charsmax(szDeadSound[]));
	get_string(15, szHitSound[0],	charsmax(szHitSound[]));
	get_string(16, szHitSound[1],	charsmax(szHitSound[]));
	

	//copy(szName2, charsmax(szName2), szName);

	ArrayPushString(g_ClassData[ZRD_SystemName], szName)

	if(!amx_load_setting_string(ZombieSaveFile, szName, g_DataKeys[ZRD_Name], szName2, charsmax(szName2)))
	{
		amx_save_setting_string(ZombieSaveFile, szName, g_DataKeys[ZRD_Name], szName);
	}

	ArrayPushString(g_ClassData[ZRD_Name], szName2);

	if(!amx_load_setting_string(ZombieSaveFile, szName, g_DataKeys[ZRD_Model], szModel, charsmax(szModel)))
	{
		amx_save_setting_string(ZombieSaveFile, szName, g_DataKeys[ZRD_Model], szModel);
	}

	new szModel2[128]
	formatex(szModel2, charsmax(szModel2), "models/player/%s/%s.mdl", szModel, szModel)

	precache_model(szModel2)

	ArrayPushString(g_ClassData[ZRD_Model], szModel);

	if(!amx_load_setting_string(ZombieSaveFile, szName, g_DataKeys[ZRD_ClawModel], szClawModel, charsmax(szClawModel)))
	{
		amx_save_setting_string(ZombieSaveFile, szName, g_DataKeys[ZRD_ClawModel], szClawModel);
	}

	precache_model(szClawModel)

	ArrayPushString(g_ClassData[ZRD_ClawModel], szClawModel);

	if(!amx_load_setting_int(ZombieSaveFile, szName, g_DataKeys[ZRD_Health], iHp))
	{
		amx_save_setting_int(ZombieSaveFile, szName, g_DataKeys[ZRD_Health], iHp);
	}

	ArrayPushCell(g_ClassData[ZRD_Health], iHp);

	if(!amx_load_setting_int(ZombieSaveFile, szName, g_DataKeys[ZRD_Gravity], iGravity))
	{
		amx_save_setting_int(ZombieSaveFile, szName, g_DataKeys[ZRD_Gravity], iGravity);
	}

	ArrayPushCell(g_ClassData[ZRD_Gravity], iGravity);

	if(!amx_load_setting_int(ZombieSaveFile, szName, g_DataKeys[ZRD_Speed], iSpeed))
	{
		amx_save_setting_int(ZombieSaveFile, szName, g_DataKeys[ZRD_Speed], iSpeed);
	}

	ArrayPushCell(g_ClassData[ZRD_Speed], iSpeed);

	if(!amx_load_setting_int(ZombieSaveFile, szName, g_DataKeys[ZRD_Knockback], iKnockback))
	{
		amx_save_setting_int(ZombieSaveFile, szName, g_DataKeys[ZRD_Knockback], iKnockback);
	}

	ArrayPushCell(g_ClassData[ZRD_Knockback], iKnockback);

	if(!amx_load_setting_int(ZombieSaveFile, szName, g_DataKeys[ZRD_JumpVelocity], iJump))
	{
		amx_save_setting_int(ZombieSaveFile, szName, g_DataKeys[ZRD_JumpVelocity], iJump);
	}

	ArrayPushCell(g_ClassData[ZRD_JumpVelocity], iJump);

	new szGender[7];
	GetGender(iGender, szGender, charsmax(szGender))

	if(!amx_load_setting_string(ZombieSaveFile, szName, g_DataKeys[ZRD_Gender], szGender, charsmax(szGender)))
	{
		amx_save_setting_string(ZombieSaveFile, szName, g_DataKeys[ZRD_Gender], szGender);
	}

	iGender = ReadGender(szGender)

	ArrayPushCell(g_ClassData[ZRD_Gender], iGender);

	for(new i = 0; i < 2; i++)
	{
		if(!amx_load_setting_string(ZombieSaveFile, szName, g_DataKeys[ZRD_DeadSound+ZombieRegisterData:i], szDeadSound[i], charsmax(szDeadSound[])))
		{
			amx_save_setting_string(ZombieSaveFile, szName, g_DataKeys[ZRD_DeadSound+ZombieRegisterData:i], szDeadSound[i]);
		}

		precache_sound(szDeadSound[i])

		ArrayPushString(g_ClassData[ZRD_DeadSound][i], szDeadSound[i]);

		if(!amx_load_setting_string(ZombieSaveFile, szName, g_DataKeys[ZRD_HitSound+ZombieRegisterData:i], szHitSound[i], charsmax(szHitSound[])))
		{
			amx_save_setting_string(ZombieSaveFile, szName, g_DataKeys[ZRD_HitSound+ZombieRegisterData:i], szHitSound[i]);
		}

		precache_sound(szHitSound[i])

		ArrayPushString(g_ClassData[ZRD_HitSound][i], szHitSound[i]);
	}

	new szFlags[26];
	get_flags(iFlags, szFlags, charsmax(szFlags));

	if(!amx_load_setting_string(ZombieSaveFile, szName, g_DataKeys[ZRD_Flags], szFlags, charsmax(szFlags)))
	{
		amx_save_setting_string(ZombieSaveFile, szName, g_DataKeys[ZRD_Flags], szFlags);
	}

	iFlags = read_flags(szFlags);

	ArrayPushCell(g_ClassData[ZRD_Flags], iFlags);

	if(!amx_load_setting_int(ZombieSaveFile, szName, g_DataKeys[ZRD_MenuAvailable], iMAvailable))
	{
		amx_save_setting_int(ZombieSaveFile, szName, g_DataKeys[ZRD_MenuAvailable], iMAvailable);
	}

	ArrayPushCell(g_ClassData[ZRD_MenuAvailable], iMAvailable);

	g_iZombieCount++;
	return g_iZombieCount - 1;
}

stock ChangeClass(id, iAttacker = -1, bool: setZombie = true, bool: applyAttributes = true, bool: ignoreFlag = false, bool: call = true, bool: reset = true)
{
	if(!setZombie)
	{
		remove_bit(g_bfZombie, id)
		return;
	}

	if(!IsPlayer(id))
	{
		return;
	}

	if(call)
	{
		ExecuteForward(g_iForwards[FWD_CLASS_CHANGE], _, id, iAttacker)
	}

	set_bit(g_bfZombie, id)
	zex_set_human(id, false)
	set_task(0.1, "setTeam", TASK_TEAM+id)

	if(g_iNClass[id] != g_iClass[id])
	{
		g_iClass[id] = g_iNClass[id];
	}

	if(!ignoreFlag)
	{
		if(!CheckUserValidFlags(id, g_iClass[id]))
		{
			g_iClass[id] = g_iNClass[id] = RandomValidClass(id);
		}
	}

	if(applyAttributes)
	{
		SetClassAttribs(id, reset);
	}

	if(iAttacker > -1)
	{
		DeathMsg(id, iAttacker)
	}

	if(call)
	{
		ExecuteForward(g_iForwards[FWD_CLASS_CHANGE_POST], _, id, iAttacker)
	}
}

public setTeam(iId)
{
	iId -= TASK_TEAM;

	if ( zex_is_human(iId) )
		return;

	rg_set_user_team(iId, TEAM_TERRORIST);
}

stock SetClassAttribs(id, bool: reset)
{
	if(!is_bit(g_bfZombie, id))
		return;

	if(!is_user_alive(id))
		return;

	new class = g_iClass[id];

	new hp = 		ArrayGetCell(g_ClassData[ZRD_Health], class),
		gravity = 	ArrayGetCell(g_ClassData[ZRD_Gravity], class),
		speed = 	ArrayGetCell(g_ClassData[ZRD_Speed], class),
		model[30];

	rg_remove_all_items(id)

	rg_give_item(id, "weapon_knife")

	ArrayGetString(g_ClassData[ZRD_Model], class, model, charsmax(model));

	rg_set_user_model(id, model, true);

	if(reset)
		set_entvar(id, var_health, 	float(hp));

	set_entvar(id, var_speed, 	float(speed));
	set_entvar(id, var_gravity, float(gravity)/800.0);
}

stock DeathMsg(id, attacker)
{	
	message_begin(MSG_BROADCAST, msgDeathMsg)
	write_byte(attacker)
	write_byte(id)
	write_byte(0)
	write_string("knife")
	message_end()
	
	message_begin(MSG_BROADCAST, msgScoreAttrib)
	write_byte(id)
	write_byte(0)
	message_end()
}

stock RandomValidClass(id)
{
	new classes[99];
	new newCount;

	for(new i = 0; i < g_iZombieCount; i++)
	{
		if(CheckUserValidFlags(id, i))
		{
			classes[ (newCount++) - 1 ] = i;
		}
	}

	new rand = random_num(0, newCount)

	return classes[(rand < 0 ? 0 : rand)];
}

stock Sex: ReadGender(const string[])
{
	if(equal(string, "FEMALE"))
		return Sex_Female;
	
	return Sex_Male;
}

stock GetGender(Sex: Gender, string[], maxlen)
{
	if(Gender == Sex_Female)
		copy(string, maxlen, "FEMALE")
	else
		copy(string, maxlen, "MALE")
}

stock CheckUserValidFlags(id, class)
{
	return (get_user_flags(id) & ArrayGetCell( g_ClassData[ZRD_Flags], class));
}