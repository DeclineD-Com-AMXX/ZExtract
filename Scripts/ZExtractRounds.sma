/* Require Semicolons */
#pragma semicolon 1

/* ~(Includes)~ */
#include <amxmodx>
#include <hamsandwich>
#include <reapi>

#include <zextract_rounds_const>
#include <zextract_const>

/* ~(Count Entity)~ */ 
#define StartCountdown set_entvar( CountdownEntity, var_nextthink, get_gametime() + 1.0 )

new const CountdownEntityClassname[] = "CountdownObject";
static CountdownEntity;


/* ~(Round)~ */
#define MaxRoundTime 540
#define MaxRoundEndMessageLen 120
#define MaxRoundWinSoundLen 128

#define PlayersAlive ( ( GetPlayers( TEAM_CT ) ) && ( GetPlayers( TEAM_TERRORIST ) ) )

new const RoundWinMessages[ WinType ][ MaxRoundEndMessageLen + 1 ] = {
	"Restarting",
	"No One Won",
	"Humans Win",
	"Zombies Win"
};


/* ~(Cvars)~ */
#define CvarMaxNameLen 50
#define CvarMaxValueLen 50

enum cvarInfo {
	CI_Id,
	CI_Name[ CvarMaxNameLen + 1 ],
	CI_Value[ CvarMaxValueLen + 1 ],
	Float: CI_flValue,
	CI_IntValue
};

enum _: plgCvars {
	PCV_WFPDelay,
	PCV_WFPMin,
	PCV_Rounds,
	PCV_RoundStartDelay,
	PCV_RoundEndDelay
};

new iCvars[ plgCvars ][ cvarInfo ] = {
	{ 0, "ZExtract_WfpDelay", "3.0",  3.0, 3 },
	{ 0, "ZExtract_WfpMinPlayers", "2", 2.0, 2 },
	{ 0, "ZExtract_Rounds", "10", 10.0, 10 },
	{ 0, "ZExtract_RoundStartDelay", "15.0", 15.0, 15 },
	{ 0, "ZExtract_RoundEndDelay", "5.0", 5.0, 5 }
};


/* ~(Forwards)~ */
enum _:RoundForwards {
	RFWD_RoundStart,
	RFWD_RoundEndPre,
	RFWD_RoundEnd,
	RFWD_RoundWFPEnd,
	RFWD_RoundStart2,
	RFWD_RoundStart2_Post
};

new pForwards[ RoundForwards ];


/* ~(Variables)~ */
new iMaxRoundTime,
	iFreezeTime,
	MaxRounds,
	iRound,

	Float: flRoundStartTime,
	Float: flRoundEndTime,
	Float: flWFPTime,

	bool: bRoundStarted,
	bool: bRoundEnded,
	bool: bRoundTimeChanged,
	bool: bWFP,
	bool: bJustWFP,
	bool: bChangeMap,
	bool: bPlgCustom

	RsType: rRestart,

	cvarRestart[ 2 ],
	cvarRoundTime,
	cvarFreezeTime,

	imTextMsg,
	imRoundTimer,

	WinType: customRoundWin,
	Float: customEndDelay,
	RsType: customRestart,
	customWinMessage[ MaxRoundEndMessageLen + 1 ],
	customWinSound[ MaxRoundWinSoundLen + 1 ];


/* ~(Random Macros)~ */
#define IsFloat(%0) ( contain( %0, "." ) > -1 )


/* ~(Private Functions)~ */
RegisterCvars( )
{
	for ( new i = 0; i < plgCvars; ++i )
	{
		iCvars[ i ][ CI_Id ] = register_cvar( iCvars[ i ][ CI_Name ], iCvars[ i ][ CI_Value ] );
		bind_pcvar_string( iCvars[ i ][ CI_Id ], iCvars[ i ][ CI_Value ], CvarMaxValueLen );
		bind_pcvar_float( iCvars[ i ][ CI_Id ], iCvars[ i ][ CI_flValue ] );
		bind_pcvar_num( iCvars[ i ][ CI_Id ], iCvars[ i ][ CI_IntValue ] );
	}
}

bool: CheckRestart(pcvar)
{
	if ( rRestart > Rs_Not )
		return true;

	if ( bRoundEnded )
		return (rRestart > Rs_Not) ? true : false;

	new bool: Restarting;
	new bool: ServerRestart = (pcvar == cvarRestart[ 0 ]);

	new szValue[ 4 ];
	get_pcvar_string( pcvar, szValue, charsmax(szValue) );

	Restarting = ( IsFloat( szValue ) ? 
		( get_pcvar_float( pcvar ) > 0.0 ) : ( get_pcvar_num( pcvar ) > 0 ) );

	if ( Restarting )
	{
		rRestart = ServerRestart ? Rs_All : Rs_Round;

		return true;
	}

	return false;
}

CheckRoundEnd( Float: flGameTime )
{
	if ( CheckRestart( cvarRestart[ 0 ] ) )
	{
		OnRoundEnd( );
		set_pcvar_num( cvarRestart[ 0 ], 0 );

		return;
	}

	if ( CheckRestart( cvarRestart[ 1 ] ) )
	{
		OnRoundEnd( );
		set_pcvar_num( cvarRestart[ 1 ], 0 );

		return;
	}

	if( bRoundEnded || !bRoundStarted )
	{
		return;
	}

	static Float: TimePassed;
	TimePassed = ( flGameTime - flRoundStartTime );

	if ( ( 0.0 > ( float( iMaxRoundTime ) - TimePassed ) ) || !PlayersAlive )
	{
		if ( flRoundStartTime >= flRoundEndTime )
		{
			flRoundEndTime = flGameTime + 1.0;
		}
		else if ( flRoundEndTime < flGameTime )
		{
			OnRoundEnd( );
		}
	}
}

CheckWFP( )
{
	static PlayersOn; PlayersOn = get_playersnum( );
	static Float: flGameTime; flGameTime = get_gametime( );

	static MinPl; MinPl = GetCvarValue(PCV_WFPMin, true);

	if ( !bWFP && PlayersOn >= MinPl )
		return;

	if ( PlayersOn < MinPl && !bWFP )
	{
		bWFP = true;
		bRoundEnded = true;
		StartCountdown;
	}

	if ( bWFP && PlayersOn >= MinPl )
	{
		if ( flRoundStartTime > flWFPTime )
			flWFPTime = flGameTime;

		static Float: flWFPDelay; flWFPDelay = GetCvarFloatValue(PCV_WFPDelay, true);

		if ( flGameTime > flWFPTime + flWFPDelay )
		{
			bJustWFP = true;
			bWFP = false;
			rRestart = Rs_All;

			ExecuteForward( pForwards[ RFWD_RoundWFPEnd ], _ );

			OnRoundEnd( );
		}
	}
}

Count( Float: flGameTime )
{
	static Float: TimePassed;
	TimePassed = ( flGameTime - flRoundStartTime ) - 1.0;

	static Float: StartDelay;
	StartDelay = GetCvarFloatValue(PCV_RoundStartDelay, true);

	if ( TimePassed >= StartDelay )
		OnRoundStart( );
	else
		PrintCenter( 0, "Game Starting in %i..", floatround( StartDelay - TimePassed, floatround_ceil ) );
}


/* ~(plugin_* Functions)~ */
public plugin_init()
{
	// Register to AMXX PLugin's List
	register_plugin( "ZExtract: Rounds", "v1.0", "DeclineD" );

	// Handle "Round Start/End"
	register_event( "HLTV", "OnRoundStart2", "a", "1=0", "2=0" );

	RegisterHookChain( RG_RoundEnd, "OnRoundEnd2" );
	RegisterHookChain( RG_CSGameRules_OnRoundFreezeEnd, "ReHook_FreezeEnd" );

	// Handle "Map Change"
	RegisterHookChain( RG_CSGameRules_GoToIntermission, "ReHook_ChangeMap" );

	// Register plugin cvars
	RegisterCvars( );

	// Get Pointer of Game Cvars
	cvarRestart[ 0 ] = get_cvar_pointer( "sv_restart" );
	cvarRestart[ 1 ] = get_cvar_pointer( "sv_restartround" );
	cvarRoundTime = get_cvar_pointer( "mp_roundtime" );
	cvarFreezeTime = get_cvar_pointer( "mp_freezetime" );

	// Hooking cvar change
	hook_cvar_change(cvarRoundTime, "RoundTime");
	hook_cvar_change(cvarFreezeTime, "RoundTime");

	// Get Required MsgIds for the plugin
	imTextMsg = get_user_msgid( "TextMsg" );
	imRoundTimer = get_user_msgid( "RoundTime" );

	// Rounds
	MaxRounds = get_pcvar_num( iCvars[ PCV_Rounds ][ CI_Id ] );
	flRoundStartTime = get_gametime( );

	// Countdown Entity
	CountdownEntity = rg_create_entity( "info_target" );
	set_entvar( CountdownEntity, var_classname, CountdownEntityClassname );
	SetThink( CountdownEntity, "Countdown" );
}

public plugin_precache( )
{
	pForwards[ RFWD_RoundEnd ] = CreateMultiForward( "ZEX_RoundEnd", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL, FP_STRING, FP_STRING);
	pForwards[ RFWD_RoundEndPre ] = CreateMultiForward( "ZEX_RoundEnd_Pre", ET_CONTINUE, FP_CELL, FP_CELL, FP_CELL, FP_STRING, FP_STRING);
	pForwards[ RFWD_RoundStart ] = CreateMultiForward( "ZEX_RoundStart", ET_IGNORE );
	pForwards[ RFWD_RoundStart2 ] = CreateMultiForward( "ZEX_RoundStart2", ET_CONTINUE );
	pForwards[ RFWD_RoundStart2_Post ] = CreateMultiForward( "ZEX_RoundStart2_Post", ET_IGNORE );
	pForwards[ RFWD_RoundWFPEnd ] = CreateMultiForward( "ZEX_WaitForPlayersEnd", ET_IGNORE );
}

public plugin_natives( )
{
	register_native( "zex_end_round", "native_end" );
	register_native( "zex_round_ended", "native_ended" );
	register_native( "zex_round_started", "native_started" );
	register_native( "zex_waiting_for_players", "native_wfp" );
	register_native( "zex_is_change_map", "native_is_cm" );
	register_native( "zex_can_change_map", "native_can_cm" );
	register_native( "zex_set_round_end_info", "native_reinfo" );
}

public plugin_cfg( )
{
	GetRoundTime( );
}


/* ~(Client Functions)~ */
public client_putinserver( id )
{
	CheckWFP( );
}

public client_disconnected( id, bool:drop, message[], maxlen )
{
	CheckWFP( );
}


/* ~(Public Functions)~ */
// [ Round ]
public RoundTime( pcvar, oldValue[], newValue[] )
{
	bRoundTimeChanged = true;
}

public OnRoundStart( )
{
	new g_iRet;

	ExecuteForward( pForwards[ RFWD_RoundStart2 ], g_iRet );

	if ( g_iRet == ZEXRet_Handled )
		return;

	bRoundStarted = true;

	ExecuteForward( pForwards[ RFWD_RoundStart2_Post ], _ );
}

public OnRoundStart2( )
{
	if ( iRound == MaxRounds )
	{
		ChangeMap( );
		return;
	}

	if ( !( rRestart > Rs_Not ) || !bWFP )
	{
		++iRound;
	}

	if ( bRoundTimeChanged )
	{
		GetRoundTime( );
	}

	if ( bJustWFP )
	{
		bJustWFP = false;
	}

	rRestart = Rs_Not;
	bRoundEnded = false;
	bRoundStarted = false;

	customRoundWin = WIN_NONE;
	customRestart = Rs_Not;
	customEndDelay = 0.0;

	formatex(customWinSound, MaxRoundWinSoundLen, "");
	formatex(customWinMessage, MaxRoundEndMessageLen, "");

	flRoundStartTime = get_gametime( );

	StartCountdown;

	ExecuteForward( pForwards[ RFWD_RoundStart ], _ );
}

public OnRoundEnd( )
{
	if ( bWFP )
		return;

	new WinType: RoundWin = WIN_DRAW,
		WinStatus: GameWin = WINSTATUS_DRAW,
		ScenarioEventEndRound: WinEvent = ROUND_END_DRAW,
		WinSound[ MaxRoundWinSoundLen + 1 ],
		EndMsg[ MaxRoundEndMessageLen + 1 ],
		Float: flEndDelay = GetCvarFloatValue( PCV_RoundEndDelay, true );

	new bool: bSameEvent;

	if ( rRestart > Rs_Not )
	{
		RoundWin = WIN_RESTART;
		GameWin = WINSTATUS_NONE;
		WinEvent = ROUND_GAME_RESTART;

		if ( rRestart == Rs_All )
		{
			flEndDelay = GetCvarFloatValue( cvarRestart[ 0 ] );
		}
		else if ( rRestart == Rs_Round )
		{
			flEndDelay = GetCvarFloatValue( cvarRestart[ 1 ] );
		}
	}
	else if ( GetPlayers( TEAM_CT ) == 0 )
	{
		RoundWin = WIN_ZOMBIE;
		GameWin = WINSTATUS_TERRORISTS;
		WinEvent = ROUND_TERRORISTS_WIN;
	}
	else if ( GetPlayers( TEAM_TERRORIST ) == 0 )
	{
		RoundWin = WIN_HUMAN;
		GameWin = WINSTATUS_CTS;
		WinEvent = ROUND_CTS_WIN;
	}

	copy(EndMsg, charsmax(EndMsg), RoundWinMessages[ RoundWin ]);

	new g_iRet;

	ExecuteForward( pForwards[RFWD_RoundEndPre], g_iRet, flEndDelay, RoundWin, rRestart, RoundWinMessages[ RoundWin ], "" );

	if ( g_iRet > ZEXRet_Continue )
		return;

	if ( g_iRet == ZEXRet_Supercede )
	{
		if ( customRoundWin != WIN_NONE )
		{
			if( RoundWin == customRoundWin )
				bSameEvent = true;
			else
				RoundWin = customRoundWin;

			switch( RoundWin )
			{
				case WIN_RESTART:
				{
					rRestart = customRestart;

					if ( rRestart == Rs_Not )
					{
						RoundWin = WIN_NONE;
						GameWin = WINSTATUS_NONE;
						WinEvent = ROUND_NONE;
					}
				}

				case WIN_DRAW:
				{
					if ( !bSameEvent )
					{
						RoundWin = WIN_DRAW;
						GameWin = WINSTATUS_DRAW;
						WinEvent = ROUND_END_DRAW;
					}
				}

				case WIN_HUMAN:
				{
					if ( !bSameEvent )
					{
						RoundWin = WIN_HUMAN;
						GameWin = WINSTATUS_CTS;
						WinEvent = ROUND_CTS_WIN;
					}
				}

				case WIN_ZOMBIE:
				{
					if ( !bSameEvent )
					{
						RoundWin = WIN_ZOMBIE;
						GameWin = WINSTATUS_TERRORISTS;
						WinEvent = ROUND_TERRORISTS_WIN;
					}
				}
			}
		}

		if ( strlen( customWinSound ) > 1 )
			copy( WinSound, MaxRoundWinSoundLen, customWinSound );

		if ( strlen( customWinMessage ) > 1 )
			copy( EndMsg, MaxRoundEndMessageLen, customWinMessage );

		if ( customEndDelay != 0.0 )
		{
			flEndDelay = customEndDelay;
		}
	}

	client_cmd( 0, "spk %s", WinSound );

	bRoundEnded = true;

	rg_round_end( flEndDelay, GameWin, WinEvent, EndMsg, "" );

	ExecuteForward( pForwards[RFWD_RoundEnd], _, flEndDelay, RoundWin, rRestart, EndMsg, WinSound );
}

public OnRoundEnd2( WinStatus: status, ScenarioEventEndRound: event, Float: tmDelay )
{
	if ( !bRoundEnded )
	{
		CheckRoundEnd( get_gametime( ) );
	}

	SetHookChainReturn(ATYPE_BOOL, false);
	return HC_SUPERCEDE;
}

public Countdown( pCountdown )
{
	static Float: flGameTime; flGameTime = get_gametime();
	new Float: flDelay;

	if ( bJustWFP )
		return;

	
	if ( bWFP )
	{
		CheckWFP( );
		flDelay = 1.0;
	}

	if ( !( rRestart > Rs_Not ) )
	{
		if ( ( !bRoundStarted && !bRoundEnded ) )
		{
			Count( flGameTime );
			flDelay = 1.0;
		}
		else if ( !bRoundEnded )
		{
			CheckRoundEnd( flGameTime );
			flDelay = 0.001;
		}
	}

	set_entvar( pCountdown, var_nextthink, flGameTime + flDelay );
}

// [ Checks ]


/* ~(RG_CSGameRules_*)~ */
public ReHook_ChangeMap( )
{
	if ( !bChangeMap )
	{
		return HC_SUPERCEDE;
	}

	return HC_CONTINUE;
}

public ReHook_FreezeEnd( )
{
	SetRoundTimer( iMaxRoundTime - iFreezeTime );
}


/* ~(Natives)~ */
// Float: flDelay = 5.0, WinType: Win = WIN_NONE, RsType: Restart = Rs_None, endMsg, endSound, trigger
public native_end( plgId, paramnum )
{
	if ( paramnum < 6 )
	{
		log_error( AMX_ERR_NATIVE, "[ZEX] Not Enough Params." );
		return;
	}

	new Float: flEndDelay = get_param_f( 1 ),
		WinType: reWin = WinType: get_param( 2 ),
		RsType: reRestartType = RsType: get_param( 3 ),
		WinStatus: reWinStatus = WINSTATUS_NONE,
		ScenarioEventEndRound: reScenarioEvent = ROUND_NONE,
		endMsg[ MaxRoundEndMessageLen + 1 ],
		endSound[ MaxRoundWinSoundLen + 1 ],
		bool: trigger = bool: get_param( 6 );

	if ( reWin > WinType - WinType: 1 )
	{
		log_error( AMX_ERR_NATIVE, "zer_round_end: win argument 2 is unrecognized" );
		return;
	}

	get_string( 4, endMsg, charsmax( endMsg ) );
	get_string( 5, endSound, charsmax( endSound ) );

	if ( equal( endMsg, "default" ) )
		copy( endMsg, charsmax( endMsg ), reWin >= WinType: 0 ? RoundWinMessages[ reWin ] : "" );

	if ( equal( endSound, "default" ) )
		copy( endSound, charsmax( endSound ), reWin >= WinType: 0 ? "" : "" );

	switch ( reWin )
	{
		case WIN_NONE:
		{
			reWinStatus = WINSTATUS_NONE;
			reScenarioEvent = ROUND_NONE;
		}

		case WIN_RESTART:
		{
			reWinStatus = WINSTATUS_NONE;
			reScenarioEvent = ROUND_GAME_RESTART;
		}

		case WIN_ZOMBIE:
		{
			reWinStatus = WINSTATUS_TERRORISTS;
			reScenarioEvent = ROUND_TERRORISTS_WIN;
		}

		case WIN_HUMAN:
		{
			reWinStatus = WINSTATUS_CTS;
			reScenarioEvent = ROUND_CTS_WIN;
		}

		case WIN_DRAW:
		{
			reWinStatus = WINSTATUS_DRAW;
			reScenarioEvent = ROUND_END_DRAW;
		}
	}

	if ( trigger )
	{
		new g_iRet;

		new bool: bSameEvent;

		ExecuteForward( pForwards[RFWD_RoundEndPre], g_iRet, flEndDelay, reWin, reRestartType, endMsg, endSound );

		if ( g_iRet > ZEXRet_Continue )
			return;

		if ( g_iRet == ZEXRet_Supercede )
		{
			if ( customRoundWin != WIN_NONE )
			{
				if( reWin == customRoundWin )
					bSameEvent = true;
				else
					reWin = customRoundWin;

				switch( reWin )
				{
					case WIN_RESTART:
					{
						reRestartType = customRestart;

						if ( rRestart == Rs_Not )
						{
							reWin = WIN_NONE;
							reWinStatus = WINSTATUS_NONE;
							reScenarioEvent = ROUND_NONE;
						}
					}

					case WIN_DRAW:
					{
						if ( !bSameEvent )
						{
							reWin = WIN_DRAW;
							reWinStatus = WINSTATUS_DRAW;
							reScenarioEvent = ROUND_END_DRAW;
						}
					}

					case WIN_HUMAN:
					{
						if ( !bSameEvent )
						{
							reWin = WIN_HUMAN;
							reWinStatus = WINSTATUS_CTS;
							reScenarioEvent = ROUND_CTS_WIN;
						}
					}

					case WIN_ZOMBIE:
					{
						if ( !bSameEvent )
						{
							reWin = WIN_ZOMBIE;
							reWinStatus = WINSTATUS_TERRORISTS;
							reScenarioEvent = ROUND_TERRORISTS_WIN;
						}
					}
				}
			}

			if ( strlen( customWinSound ) > 1 )
				copy( endSound, MaxRoundWinSoundLen, customWinSound );

			if ( strlen( customWinMessage ) > 1 )
				copy( endMsg, MaxRoundEndMessageLen, customWinMessage );

			if ( customEndDelay != 0.0 )
			{
				flEndDelay = customEndDelay;
			}
		}
	}

	client_cmd( 0, "spk %s", endSound );

	bRoundEnded = true;

	rg_round_end( flEndDelay, reWinStatus, reScenarioEvent, endMsg, "" );

	ExecuteForward( pForwards[RFWD_RoundEnd], _, flEndDelay, reWin, reRestartType, endMsg, endSound );
}

public native_reinfo( plgId, paramnum )
{
	if ( paramnum < 2 )
	{
		log_error( AMX_ERR_NATIVE, "[ZEX] Not Enough Params." );
		return;
	}

	new RoundEndInfo: reiType = RoundEndInfo: get_param( 1 );

	switch( reiType )
	{
		case REI_Delay: {
			customEndDelay = get_param_f( 2 );
		}

		case REI_Win: {
			customRoundWin = WinType: get_param( 2 );
		}

		case REI_Restart: {
			customRestart = RsType: get_param( 2 );
		}

		case REI_Message: {
			get_string( 2, customWinMessage, MaxRoundEndMessageLen );
		}

		case REI_Sound: {
			get_string( 2, customWinSound, MaxRoundWinSoundLen );
		}
	}
}

public native_ended( )
{
	return bRoundEnded;
}

public native_started( )
{
	return bRoundStarted;
}

public native_wfp( )
{
	return bWFP;
}

public native_is_cm( )
{
	return bChangeMap;
}

public native_can_cm( plgId, paramnum )
{
	if ( paramnum < 1 )
	{
		log_error( AMX_ERR_NATIVE, "[ZEX] Not Enough Params." );
		return;
	}

	new iValue = get_param( 1 );

	bChangeMap = bool: iValue;
}


/* ~(Stock Functions)~ */
stock GetRoundTime( )
{
	new iRTime = GetCvarValue( cvarRoundTime, .flMul = 60.0 );
	new iFTime = GetCvarValue( cvarFreezeTime );

	if ( iRTime > MaxRoundTime )
	{
		iRTime = MaxRoundTime;
	}

	iMaxRoundTime = iRTime + iFTime;
	iFreezeTime = iFTime;

	return iRTime + iFTime;
}

stock SetRoundTimer( Value )
{
	message_begin( MSG_BROADCAST, imRoundTimer );
	write_short( Value );
	message_end( );
}

stock GetPlayers( TeamName: Team )
{
	new ct, t;

	rg_initialize_player_counts( t, ct );

	switch( Team )
	{
		case TEAM_CT: return ct;
		case TEAM_TERRORIST: return t;
		default: return 0;
	}

	return 0;
}

stock ChangeMap( )
{
	bChangeMap = true;

	new strMap[ 40 ];
	get_cvar_string( "amx_nextmap", strMap, charsmax( strMap ) );

	if(!strlen(strMap))
	{
		copy(strMap, charsmax(strMap), "de_dust");
	}

	server_cmd( "changelevel %s", strMap );
}

stock PrintCenter( id = 0, const msg[ ] = "", any:... )
{
	new szMsg[ 150 ];
	vformat( szMsg, charsmax( szMsg ), msg, 3 );

	message_begin( ( id == 0 ? MSG_BROADCAST : MSG_ONE_UNRELIABLE ), imTextMsg, _, id );
	write_byte( 4 );
	write_string( szMsg );
	message_end( );

	//server_print( szMsg );
}

stock Float: GetCvarFloatValue( pcvar, bool: inPlCvar = false, Float: flMul = 1.0 )
{
	if( inPlCvar )
	{
		new Float: flValue = ( IsFloat( iCvars[ pcvar ][ CI_Value ] ) ? iCvars[ pcvar ][ CI_flValue ] : float( iCvars[ pcvar ][ CI_IntValue ] ) ) * flMul;

		return flValue;
	}

	new szValue[ 1024 ];
	get_pcvar_string( pcvar, szValue, charsmax( szValue ) );

	new Float: flValue = ( IsFloat( szValue ) ? get_pcvar_float( pcvar ) : float( get_pcvar_num( pcvar ) ) ) * flMul;

	return flValue;
}

stock GetCvarValue( pcvar, bool: inPlCvar = false, Float: flMul = 1.0, floatround_method: fr_meth = floatround_round )
{
	return floatround( GetCvarFloatValue( pcvar, inPlCvar, flMul ), fr_meth );
}