#if defined _zextract_buymenu_included
	#endinput
#endif
#define _zextract_buymenu_included

#include <zextract_buymenu_const>

forward ZEX_BuyAmmo_Item(id);
forward ZEX_BuyAmmo(id, item);
forward ZEX_BuyAmmo_Post(id, item);
forward ZEX_BuyItem(id, item);
forward ZEX_OpenBuymenu(id);
forward ZEX_OpenCategory(id, category);

native zex_register_item(const sysName[], const displayName[], cost, ammoCost, category);