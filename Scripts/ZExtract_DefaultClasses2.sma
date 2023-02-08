#include <amxmodx>
#include <zextract>

public plugin_init()
{
	register_plugin("idk", "idk", "idk")
}

public plugin_precache()
{
	zex_register_human("Greg", "terror", 100, 700, 260, Sex_Male, 300, 0, MenuAvail_All)
	zex_register_zombie("Gian", "urban", "models/v_knife.mdl",  500, 700, 240, 100, Sex_Male, 270, 0, MenuAvail_All, "die1", "die2", "pl_pain5", "pl_pain6")
}