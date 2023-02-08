#if defined _zex_buymenu_const_included
	#endinput
#endif
#define _zex_buymenu_const_included

#define GetMoney(%0) get_member(%0, m_iAccount)
#define SetMoney(%0,%1) set_member(%0, m_iAccount, %1)

#define MAX_ITEMS_CATEGORY 60

enum ItemRegisterData
{
	any: IRD_SystemName,
	any: IRD_Name,
	any: IRD_Cost,
	any: IRD_AmmoCost,
	any: IRD_Category,
	//any: IRD_Flags
}

enum _:CATEGORIES
{
	CATEG_PISTOl,
	CATEG_SHOTGUN,
	CATEG_SUBMACHINE,
	CATEG_SNIPER,
	CATEG_ASSAULT,
	CATEG_MACHINES,
	CATEG_EQUIPMENT,
	CATEG_KNIFE
}

enum Sort
{
	Sort_Name,
	Sort_Cost
}

enum SortDir
{
	SRDir_Ascendent,
	SRDir_Descendent
}