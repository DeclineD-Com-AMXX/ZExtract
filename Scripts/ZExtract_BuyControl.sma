#include <amxmodx>
#include <reapi>

new const buyCommands[][] = {
	"nighthawk",
	"deagle",
	"usp",
	"glock",
	"fiveseven",
	"elites",
	"p228",
	"p90",
	"ump45",
	"mp5",
	"tmp",
	"mac10",
	"m3",
	"autoshotgun",
	"m4a1",
	"ak47",
	"defender",
	"galil",
	"famas",
	"aug",
	"sg552",
	"awp",
	"scout",
	"d3aul",
	"krieg550",
	"m249",
	"vest",
	"vesthelm",
	"shield",
	"flash",
	"hegren",
	"sgren",
	"defuser",
	"nightvision",
	"cl_setautobuy", 
	"cl_autobuy",
	"cl_setrebuy",
	"cl_rebuy",
	"buyequip",
	"client_buy_open",
	"buy"
}

public plugin_init()
{
	register_plugin("[ZEX] Buy Control", "", "")

	RegisterHookChain(RG_BuyWeaponByWeaponID, "ReHook_BuyW")
	RegisterHookChain(RG_BuyGunAmmo, "ReHook_BuyA")
	
	for(new i; i < sizeof buyCommands; i++)
		register_clcmd(buyCommands[i], "BlockBuy")
}

public ReHook_BuyW(id, WeaponIdType:weaponID)
{
	SetHookChainReturn(ATYPE_INTEGER, 0)
	return HC_SUPERCEDE;
}

public ReHook_BuyA(id, weapon_entity, bool:blinkMoney)
{
	SetHookChainReturn(ATYPE_BOOL, false)
	return HC_SUPERCEDE;
}

public BlockBuy()
{
	return PLUGIN_HANDLED;
}