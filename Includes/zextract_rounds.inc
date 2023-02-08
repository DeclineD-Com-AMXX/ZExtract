/* Sublime AMXX Editor v3.0.0-beta */

#if defined _zextract_round_included
	#endinput
#endif
#define _zextract_rounds_included

#include <zextract_rounds_const>

forward ZEX_RoundEnd(Float:flDelay, WinType: reWin, RsType: rsRestart, const EndMessage[], const Sound[])
forward ZEX_RoundEnd_Pre(Float:flDelay, WinType: reWin, RsType: rsRestart, const EndMessage[], const Sound[])
forward ZEX_RoundStart()
forward ZEX_RoundStart2()
forward ZEX_RoundStart2_Post()
forward ZEX_WaitForPlayersEnd()

native zex_end_round(Float:flDelay, WinType: reWin, RsType: rsRestart, const EndMessage[], const EndSound[], bool: Trigger)
native bool: zex_round_ended()
native bool: zex_round_started()
native bool: zex_waiting_for_players()
native bool: zex_is_change_map()
native zex_can_change_map(bool: change)
native zex_set_round_end_info(RoundEndInfo: reiInfo, any:...)