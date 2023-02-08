#if defined _zextract_human_included
	#endinput
#endif
#define _zextract_human_included

#include <zextract_human_const>

forward ZEX_ToHuman(id)
forward ZEX_ToHuman_Post(id)

native zex_register_human(const Name[], const model[], Hp, Gravity, Speed, Sex: Gender, Jump, Flags, MenuAvailable:Menu_Available)
native bool: zex_is_human(id)
native zex_set_human(id, bool: human = true, bool: applyAttributes = true, bool: ignoreFlag = false)
native zex_get_human_class(id)
native zex_set_human_class(id, humanClass, bool: ignoreFlag)
native zex_get_next_human_class(id)
native zex_set_next_human_class(id, humanClass)
native zex_get_human_class_count()
native zex_get_human_class_info(humanClass, any:...)