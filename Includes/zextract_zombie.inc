#if defined _zextract_zombie_included
	#endinput
#endif
#define _zextract_zombie_included

#include <zextract_zombie_const>

forward ZEX_ToZombie(id, attacker);
forward ZEX_ToZombie_Post(id, attacker);

native zex_register_zombie(const Name[], const Model[], const ClawModel[], Hp, Gravity, Speed, Knockback, Sex: Gender, Jump, Flags, MenuAvailable:Menu_Available, const Dead_Sound1[], const Dead_Sound2[], const Hit_Sound1[], const Hit_Sound2[]);
native bool: zex_is_zombie(id);
native zex_set_zombie(id, bool: zombie = true, attacker = -1, bool: applyAttributes = true, bool: ignoreFlag = false);
native zex_get_zombie_class(id);
native zex_set_zombie_class(id, zombieClass, bool: ignoreFlag);
native zex_get_next_zombie_class(id);
native zex_set_next_zombie_class(id, zombieClass);
native zex_get_zombie_class_count();
native zex_get_zombie_class_info(zombieClass, any:...);