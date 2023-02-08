#include <amxmodx>
#include <hamsandwich>
#include <reapi>

#include <zextract>

#define IsPlayer(%0) ( (0 < %0 < 33) && is_user_connected( %0 ) )

#define TASK_CHANGE 10124

#define ZOMBIE_SPREAD 0.4

new bitLastInfections

public plugin_init()
{
	register_plugin("[ZEX] Normal Infection", "v0.0", "DeclineD")
	
	RegisterHam(Ham_TakeDamage, "player", "HamHook_TakeDamage"	 )
	RegisterHam(Ham_Spawn, 		"player", "HamHook_Spawn_Post", 1)
}

public HamHook_Spawn_Post(iId)
{
	if(!IsPlayer(iId))
		return;

	if(!is_user_alive(iId))
		return;

	set_task(0.1, "class", TASK_CHANGE+iId)
}

public class(iId)
{
	iId -= TASK_CHANGE

	if(zex_round_started() && !zex_round_ended())
		zex_set_zombie(iId)
	else
		zex_set_human(iId)
}

public ZEX_RoundStart2()
{
	new players[MAX_PLAYERS], num
	get_players(players, num, "a")
	
	new spread = floatround(num * ZOMBIE_SPREAD)

	for(new i = 0; i < num; i++)
	{
		if(num == spread)
			break;

		if(is_bit(bitLastInfections, players[i]))
		{
			remove_bit(bitLastInfections, players[i])
			players[i] = players[num--]
		}
	}

	new zombies, rand

	while(zombies < spread)
	{
		rand = random_num(0, num - 1)

		set_bit(bitLastInfections, players[rand])
		zex_set_zombie(players[rand])

		players[rand] = players[num--]
		zombies++
	}
}

public HamHook_TakeDamage(pVictim, pInflictor, pAttacker, Float:flDamage, bitDmg)
{
	if( (bitDmg == DMG_GRENADE) || (pVictim == pAttacker) || zex_is_human(pAttacker) || zex_is_zombie(pVictim) || zex_round_ended()
		|| !zex_round_started() || !IsPlayer(pAttacker) )
	{
		return HAM_IGNORED;
	}

	new Float:iArmor = get_entvar(pVictim, var_armorvalue)

	if( iArmor < 1.0 )
	{
		zex_set_zombie(pVictim, .attacker = pAttacker)
	}
	else
	{
		if( iArmor - flDamage <= 1.0 )
			set_entvar( pVictim, var_armorvalue, 0.0 )
		else
			set_entvar( pVictim, var_armorvalue, iArmor-flDamage )
	}

	set_member(pVictim, m_flVelocityModifier, 0.5)

	return HAM_SUPERCEDE;
}