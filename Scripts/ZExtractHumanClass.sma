#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <engine>
#include <reapi>

#include <amx_settings_api>

#include <zextract_class_const>
#include <zextract_human_const>

#include <zextract_zombie>

#define IsPlayer(%0) 		( (0 < %0 < 33) && is_user_connected( %0 ) )

#define is_bit(%1,%0)		(%1 & (1<<%0))
#define set_bit(%1,%0) 		%1 |= (1<<%0)
#define remove_bit(%1,%0) 	%1 &= ~(1<<%0)

#define TASK_TEAM 22312421

new g_bfHuman,
	g_iClass[33],
	g_iNClass[33],

	g_iHumanCount

new g_ClassData[HumanRegisterData];

new g_DataKeys[HumanRegisterData][] = {
	"", 
	"NAME",
	"MODEL",
	"HEALTH",
	"GRAVITY",
	"SPEED",
	"JUMP_POWER",
	"GENDER",
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

public plugin_init()
{
	g_bPrecache = false

	if (!g_iHumanCount)
		set_fail_state("No human classes")

	register_plugin("ZExtract: Human Class", "-", "-")
	
	//RegisterHamPlayer(Ham_Player_Jump,  "HamHook_Player_Jump")
	RegisterHookChain(RG_CBasePlayer_Jump, "ReHook_Player_Jump")
	RegisterHamPlayer(Ham_Spawn, 		"HamHook_Spawn_Post", 1)

	RegisterHookChain(RG_CBasePlayer_SetClientUserInfoModel, "ReHook_Player_Model")

	register_clcmd("say /humans", "cmdHumans")
}

public plugin_precache()
{
	g_bPrecache = true

	g_ClassData[HRD_SystemName] = 		ArrayCreate(20, 1)
	g_ClassData[HRD_Name] = 			ArrayCreate(20, 1)
	g_ClassData[HRD_Model] = 	 		ArrayCreate(32, 1)
	g_ClassData[HRD_Health] = 	 		ArrayCreate(1,  1)
	g_ClassData[HRD_Gravity] = 	 		ArrayCreate(1,  1)
	g_ClassData[HRD_Speed] = 	 		ArrayCreate(1,  1)
	g_ClassData[HRD_Gender] = 	 		ArrayCreate(1,  1)
	g_ClassData[HRD_JumpVelocity] = 	ArrayCreate(1,  1)
	g_ClassData[HRD_Flags] = 			ArrayCreate(1,  1)
	g_ClassData[HRD_MenuAvailable] = 	ArrayCreate(1,  1)

	g_iForwards[FWD_CLASS_CHANGE] = 	 CreateMultiForward("ZEX_ToHuman", ET_STOP, FP_CELL)
	g_iForwards[FWD_CLASS_CHANGE_POST] = CreateMultiForward("ZEX_ToHuman_Post", ET_IGNORE, FP_CELL)
}

public plugin_natives()
{
	register_native("zex_register_human", 		 "native_register")
	register_native("zex_is_human",				 "native_ishuman", 1)
	register_native("zex_set_human",			 "native_sethuman", 1)
	register_native("zex_get_human_class", 		 "native_getclass", 1)
	register_native("zex_set_human_class", 		 "native_setclass", 1)
	register_native("zex_get_next_human_class",  "native_getnextclass", 1)
	register_native("zex_set_next_human_class",	 "native_setnextclass", 1)
	register_native("zex_get_human_class_count", "native_classcount", 1)
	register_native("zex_get_human_class_info",  "native_classinfo")
}

public client_putinserver(id)
{
	g_iClass[id] = 0
	g_iNClass[id] = 0

	remove_bit(g_bfHuman, id)
}

public ReHook_Player_Jump(id)
{
	if(!is_bit(g_bfHuman, id))
	{
		return HC_CONTINUE;
	}

	new oldButtons = get_entvar(id, var_oldbuttons)
	new Button = get_entvar(id, var_button)

	if((oldButtons & IN_JUMP) || !(get_entvar(id, var_flags) & FL_ONGROUND))
	{
		return HC_CONTINUE;
	}

	oldButtons |= IN_JUMP
	Button &= ~IN_JUMP

	set_entvar(id, var_oldbuttons, oldButtons)
	set_entvar(id, var_button, Button)

	new Float: flVelocity[3];
	get_entvar(id, var_velocity, flVelocity)

	flVelocity[2] = float(ArrayGetCell(g_ClassData[HRD_JumpVelocity], g_iClass[id]))

	set_entvar(id, var_velocity, flVelocity)

	return HC_SUPERCEDE;
}

public cmdHumans(id)
{
	new szText[256];

	formatex(szText, charsmax(szText), "\rHuman \yMenu")

	new menu = menu_create(szText, "hmHandler")
	new szName[20]

	new callback = menu_makecallback("hmenuCheck")

	for(new i = 0; i < g_iHumanCount; i++)
	{
		ArrayGetString(g_ClassData[HRD_Name], i, szName, charsmax(szName))

		formatex(szText, charsmax(szText), "%s%s", ( ( i == g_iNClass[id] ) ? "\r" : ( CheckUserValidFlags(id, i) ? "\w" : "\d" ) ), szName)
		menu_additem(menu, szText, .callback = callback)
	}

	menu_display(id, menu)
}

public hmHandler(id, menu, item)
{
	g_iNClass[id] = item
	
	menu_destroy(menu)
}

public hmenuCheck(id, menu, item)
{
	if(!CheckUserValidFlags(id, item) || g_iNClass[id] == item)
		return ITEM_DISABLED;

	return ITEM_ENABLED;
}

public HamHook_Spawn_Post(id)
{
	if(!is_user_alive(id))
		return;

	if(!is_bit(g_bfHuman, id))
		return;

	SetClassAttribs(id, true)
}

public ReHook_Player_Model(id, infobuffer[], szNewModel[])
{
	if(!is_bit(g_bfHuman, id))
		return HC_CONTINUE;

	new szModel[32];
	ArrayGetString(g_ClassData[HRD_Model], g_iClass[id], szModel, charsmax(szModel))

	SetHookChainArg(3, ATYPE_STRING, szModel, charsmax(szModel))
	return HC_CONTINUE;
}

public native_ishuman(id)
{
	return is_bit(g_bfHuman, id)
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
	if(0 < class < g_iHumanCount)
	{
		log_error(AMX_ERR_NATIVE, "Unrecognizable human class")
		return 0;
	}

	g_iNClass[id] = class

	return 1;
}

public native_setclass(id, class, bool: ignoreFlag)
{
	if(!IsPlayer(id))
	{
		return 0;
	}

	if(!is_bit(g_bfHuman, id))
		return 0;

	if(0 < class < g_iHumanCount)
	{
		log_error(AMX_ERR_NATIVE, "Unrecognizable human class")
		return 0;
	}

	g_iNClass[id] = class

	ChangeClass(id, bool: is_bit(g_bfHuman, id), .ignoreFlag = ignoreFlag, .reset = false)

	return 1;
}

public native_sethuman(id, bool: human, bool: applyAttributes, bool: ignoreFlag)
{
	if(!IsPlayer(id))
	{
		return;
	}

	ChangeClass(id, human, applyAttributes, ignoreFlag);
}

public native_classcount()
{
	return g_iHumanCount;
}

public native_classinfo(plgId, paramnum)
{
	new humanClass = get_param(1)

	if(0 < humanClass < g_iHumanCount)
	{
		log_error(AMX_ERR_NATIVE, "Unrecognizable human class")
		return 0;
	}

	new HumanRegisterData: infoData = HumanRegisterData: get_param(2)

	if(0 < _:infoData < _:HumanRegisterData)
	{
		log_error(AMX_ERR_NATIVE, "Unrecognizable HumanRegisterData")
		return 0;
	}

	new type, Array:infoArray

	switch(infoData)
	{
		case HRD_Name:
		{
			if(paramnum < 4)
				return 0;

			type = 1
			infoArray = g_ClassData[HRD_Name]
		}

		case HRD_SystemName:
		{
			if(paramnum < 4)
				return 0;

			type = 1
			infoArray = g_ClassData[HRD_SystemName]
		}

		case HRD_Model:
		{
			if(paramnum < 4)
				return 0;

			type = 1
			infoArray = g_ClassData[HRD_Model]
		}

		default:
		{
			type = 0
			infoArray = Array: g_ClassData[infoData]
		}
	}

	if(type == 0)
	{
		return ArrayGetCell(infoArray, humanClass);
	}
	else if(type == 1)
	{
		new szStr[MAX_STRING_LENGTH];
		ArrayGetString(infoArray, humanClass, szStr, charsmax(szStr))

		new len = get_param(4)

		set_string(3, szStr, len)
		return 1;
	}

	return 0;
}

public native_register(plgId, paramnum)
{
	if(paramnum < _:HumanRegisterData - 1)
	{
		log_error(AMX_ERR_NATIVE, "Not enough params. (Required %i)", HumanRegisterData);
		return -1;
	}

	if(!g_bPrecache)
	{
		log_error(AMX_ERR_NATIVE, "Cannot precache resources. Canceling register process.");
		return -1;
	}
	
// name, model, hp, gravity, speed, gender, jump, flags, menu_available, dead_sound1, dead_sound2, hit_sound1, hit_sound2
	new szName[20],
		szName2[20],
		szModel[32],
		iHp = 			get_param(3),
		iGravity =  	get_param(4),
		iSpeed = 		get_param(5),
		Sex: iGender = 	Sex:get_param(6),
		iJump = 		get_param(7),
		iFlags = 		get_param(8),
		iMAvailable = 	get_param(9);

	get_string(1, szName, charsmax(szName));
	get_string(2, szModel, charsmax(szModel));

	copy(szName2, charsmax(szName2), szName);

	ArrayPushString(g_ClassData[HRD_SystemName], szName)

	if(!amx_load_setting_string(HumanSaveFile, szName, g_DataKeys[HRD_Name], szName2, charsmax(szName2)))
	{
		amx_save_setting_string(HumanSaveFile, szName, g_DataKeys[HRD_Name], szName);
	}

	ArrayPushString(g_ClassData[HRD_Name], szName2);

	if(!amx_load_setting_string(HumanSaveFile, szName, g_DataKeys[HRD_Model], szModel, charsmax(szModel)))
	{
		amx_save_setting_string(HumanSaveFile, szName, g_DataKeys[HRD_Model], szModel);
	}

	ArrayPushString(g_ClassData[HRD_Model], szModel);

	new szPathModel[128];
	formatex(szPathModel, charsmax(szPathModel), "models/player/%s/%s.mdl", szModel, szModel)

	precache_model(szPathModel)

	if(!amx_load_setting_int(HumanSaveFile, szName, g_DataKeys[HRD_Health], iHp))
	{
		amx_save_setting_int(HumanSaveFile, szName, g_DataKeys[HRD_Health], iHp);
	}

	ArrayPushCell(g_ClassData[HRD_Health], iHp);

	if(!amx_load_setting_int(HumanSaveFile, szName, g_DataKeys[HRD_Gravity], iGravity))
	{
		amx_save_setting_int(HumanSaveFile, szName, g_DataKeys[HRD_Gravity], iGravity);
	}

	ArrayPushCell(g_ClassData[HRD_Gravity], iGravity);

	if(!amx_load_setting_int(HumanSaveFile, szName, g_DataKeys[HRD_Speed], iSpeed))
	{
		amx_save_setting_int(HumanSaveFile, szName, g_DataKeys[HRD_Speed], iSpeed);
	}

	ArrayPushCell(g_ClassData[HRD_Speed], iSpeed);

	if(!amx_load_setting_int(HumanSaveFile, szName, g_DataKeys[HRD_JumpVelocity], iJump))
	{
		amx_save_setting_int(HumanSaveFile, szName, g_DataKeys[HRD_JumpVelocity], iJump);
	}

	ArrayPushCell(g_ClassData[HRD_JumpVelocity], iJump);

	new szGender[7];
	GetGender(iGender, szGender, charsmax(szGender))

	if(!amx_load_setting_string(HumanSaveFile, szName, g_DataKeys[HRD_Gender], szGender, charsmax(szGender)))
	{
		amx_save_setting_string(HumanSaveFile, szName, g_DataKeys[HRD_Gender], szGender);
	}

	iGender = ReadGender(szGender)

	ArrayPushCell(g_ClassData[HRD_Gender], iGender);

	new szFlags[26];
	get_flags(iFlags, szFlags, charsmax(szFlags));

	if(!amx_load_setting_string(HumanSaveFile, szName, g_DataKeys[HRD_Flags], szFlags, charsmax(szFlags)))
	{
		amx_save_setting_string(HumanSaveFile, szName, g_DataKeys[HRD_Flags], szFlags);
	}

	iFlags = read_flags(szFlags);

	ArrayPushCell(g_ClassData[HRD_Flags], iFlags);

	if(!amx_load_setting_int(HumanSaveFile, szName, g_DataKeys[HRD_MenuAvailable], iMAvailable))
	{
		amx_save_setting_int(HumanSaveFile, szName, g_DataKeys[HRD_MenuAvailable], iMAvailable);
	}

	ArrayPushCell(g_ClassData[HRD_MenuAvailable], iMAvailable);

	g_iHumanCount++;
	return g_iHumanCount - 1;
}

stock ChangeClass(id, bool: setHuman = true, bool: applyAttributes = true, bool: ignoreFlag = false, bool: call = true, bool: reset = true)
{
	if(!setHuman)
	{
		remove_bit(g_bfHuman, id)
		return;
	}

	if(!IsPlayer(id))
	{
		return;
	}

	if(call)
	{
		ExecuteForward(g_iForwards[FWD_CLASS_CHANGE], _, id)
	}

	set_bit(g_bfHuman, id)
	zex_set_zombie(id, false)
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

	if(call)
	{
		ExecuteForward(g_iForwards[FWD_CLASS_CHANGE_POST], _, id)
	}
}

public setTeam(iId)
{
	iId -= TASK_TEAM;

	if ( zex_is_zombie(iId) )
		return;

	rg_set_user_team(iId, TEAM_CT);
}

stock SetClassAttribs(id, bool: reset)
{
	if(!is_bit(g_bfHuman, id))
		return;

	if(!is_user_alive(id))
		return

	new class = g_iClass[id];

	new hp = 		ArrayGetCell(g_ClassData[HRD_Health], 	class),
		gravity = 	ArrayGetCell(g_ClassData[HRD_Gravity], 	class),
		speed = 	ArrayGetCell(g_ClassData[HRD_Speed], 	class),
		model[30];

	ArrayGetString(g_ClassData[HRD_Model], class, model, charsmax(model));

	rg_set_user_model(id, model, true);

	if(reset)
		set_entvar(id, var_health, 	float(hp));

	set_entvar(id, var_speed, 	float(speed));
	set_entvar(id, var_gravity, float(gravity)/800.0);
}

stock RandomValidClass(id)
{
	new classes[99];
	new newCount;

	for(new i = 0; i < g_iHumanCount; i++)
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
	return (get_user_flags(id) & ArrayGetCell( g_ClassData[HRD_Flags], class));
}