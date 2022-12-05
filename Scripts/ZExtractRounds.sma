/* Require Semicolons */
#pragma semicolon 1

/* ~(Includes)~ */
#include <amxmodx>
#include <reapi>

#include <zextract_const>


/* ~(Debug)~ */
//#define DEBUG // Enables Debug


/* ~(Count Entity)~ */
#define StartCountdown set_entvar( CountdownEntity, var_nextthink, get_gametime() + 1.0 )

new const CountdownEntityClassname[] = "CountdownObject";
static CountdownEntity;


/* ~(Round)~ */
#define MaxRoundTime 540

#define PlayersAlive ( ( GetPlayers( TEAM_CT ) ) && ( GetPlayers( TEAM_TERRORIST ) ) )

new const RoundWinMessages[ WinType ][  ] = {
	"Restarting",
	"No One Won",
	"Humans Win",
	"Zombies Win"
};


/* ~(Cvars)~ */
#define CvarMaxValueLen CI_Value - CI_Name - CI_Id

enum cvarInfo
{
	CI_Id,
	CI_Name[ 50 ],
	CI_Value[ 50 ],
	Float: CI_flValue,
	CI_IntValue
};

enum _: plgCvars
{
	PCV_WFPDelay,
	PCV_WFPMin,
	PCV_Rounds,
	PCV_RoundStartDelay,
	PCV_RoundEndDelay
};

new iCvars[ plgCvars ][ cvarInfo ] = 
{
	{ 0, "ZExtract_WfpDelay", "3.0",  3.0, 3 },
	{ 0, "ZExtract_WfpMinPlayers", "2", 2.0, 2 },
	{ 0, "ZExtract_Rounds", "10", 10.0, 10 },
	{ 0, "ZExtract_RoundStartDelay", "15.0", 15.0, 15 },
	{ 0, "ZExtract_RoundEndDelay", "5.0", 5.0, 5 }
};


/* ~(Forwards)~ */
enum _:RoundForwards
{
	RFWD_RoundStart,
	RFWD_RoundEndPre,
	RFWD_RoundEnd,
	RFWD_RoundWFPEnd,
	RFWD_RoundStart2
};

new pForwards[ RoundForwards ];


/* ~(Variables)~ */
new 	   iMaxRoundTime,
		   iFreezeTime,
		   MaxRounds,
		   iRound,

	Float: flRoundStartTime,
	Float: flWFPTime,

	bool: bRoundStarted,
	bool: bRoundEnded,
	bool: bRoundTimeChanged,
	bool: bWFP,
	bool: bJustWFP,
	bool: bChangeMap,

	RsType: rRestart,

	cvarRestart[ 2 ],
	cvarRoundTime,
	cvarFreezeTime,

	imTextMsg,
	imRoundTimer;


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
		return false;

	if ( bRoundEnded )
	{
		#if defined DEBUG
		server_print( "Restart: Round Already Ending" );
		#endif
		return false;
	}

	new bool: Restarting;
	new bool: ServerRestart = (pcvar == cvarRestart[ 0 ]);

	new szValue[ 4 ];
	get_pcvar_string( pcvar, szValue, charsmax(szValue) );

	Restarting = ( IsFloat( szValue ) ? 
		( get_pcvar_float( pcvar ) > 0.0 ) : ( get_pcvar_num( pcvar ) > 0 ) );

	if ( Restarting )
	{
		#if defined DEBUG
		server_print( ServerRestart ? "Game Restart" : "Round Restart" );
		#endif
		rRestart = ServerRestart ? Rs_All : Rs_Round;

		OnRoundEnd( );

		set_pcvar_num( pcvar, 0 );

		return true;
	}

	return false;
}

CheckRoundEnd( Float: flGameTime )
{
	if ( CheckRestart( cvarRestart[ 1 ] ) || CheckRestart( cvarRestart[ 0 ] ) )
		return;

	if( bRoundEnded || !bRoundStarted )
	{
		#if defined DEBUG
		server_print( "CheckRoundEnd Stopped: bRoundEnd, !bRoundStart = %i %i", bRoundEnded, !bRoundStarted);
		#endif
		return;
	}

	static Float: TimePassed;
	TimePassed = ( flGameTime - flRoundStartTime );

	if ( ( 0.0 > ( float( iMaxRoundTime ) - TimePassed ) ) || !PlayersAlive )
		OnRoundEnd( );

	#if defined DEBUG
	server_print( "CheckRoundEnd Works: PlayersAlive: %i TimePassed: %i", PlayersAlive, ( 0.0 > ( float( iMaxRoundTime ) - TimePassed ) ));
	#endif
}

CheckWFP( )
{
	static PlayersOn; PlayersOn = get_playersnum( );
	static Float: flGameTime; flGameTime = get_gametime( );

	if ( !bWFP && PlayersOn >= iCvars[ PCV_WFPMin ][ CI_IntValue ] )
		return;

	if ( PlayersOn < iCvars[ PCV_WFPMin ][ CI_IntValue ] && !bWFP )
	{
		bWFP = true;
		bRoundEnded = true;
		StartCountdown;
	}

	if ( bWFP && PlayersOn >= iCvars[ PCV_WFPMin ][ CI_IntValue ] )
	{
		if ( flRoundStartTime > flWFPTime )
			flWFPTime = flGameTime;

		if ( flGameTime > flWFPTime + iCvars[ PCV_WFPDelay ][ CI_flValue ] )
		{
			bJustWFP = true;
			bWFP = false;
			rRestart = Rs_All;

			ExecuteForward( pForwards[ RFWD_RoundWFPEnd ], _ );

			OnRoundEnd( );
		}
	}

	#if defined DEBUG
	server_print( "WaitForPlayers: Players: %i, Required: %i, Waiting: %i, Passed Delay: %i, Delay: %.2f", PlayersOn, iCvars[ PCV_WFPMin ][ CI_IntValue ], bWFP, flGameTime > flWFPTime + iCvars[ PCV_WFPDelay ][ CI_flValue ], iCvars[ PCV_WFPDelay ][ CI_flValue ] );
	#endif
}

Count( Float: flGameTime )
{
	static Float: TimePassed;
	TimePassed = ( flGameTime - flRoundStartTime ) - 1.0;

	static Float: StartDelay;
	StartDelay = iCvars[ PCV_RoundStartDelay ][ CI_flValue ];

	if ( TimePassed >= StartDelay )
		OnRoundStart( );
	else
		PrintCenter( _, "Game Starting in %i..", floatround( StartDelay - TimePassed ) );
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
	pForwards[ RFWD_RoundEnd ] = CreateMultiForward( "ZER_RoundEnd", ET_CONTINUE, FP_CELL, FP_CELL, FP_CELL, FP_STRING, FP_STRING, FP_CELL );
	pForwards[ RFWD_RoundEndPre ] = CreateMultiForward( "ZER_RoundEnd_Pre", ET_STOP, FP_CELL, FP_CELL, FP_CELL, FP_STRING, FP_STRING, FP_CELL );
	pForwards[ RFWD_RoundStart ] = CreateMultiForward( "ZER_RoundStart", ET_CONTINUE );
	pForwards[ RFWD_RoundStart2 ] = CreateMultiForward( "ZER_RoundStart2", ET_CONTINUE );
	pForwards[ RFWD_RoundWFPEnd ] = CreateMultiForward( "ZER_WaitForPlayersEnd", ET_CONTINUE );
}

public plugin_natives( )
{
	register_native("zer_round_end", "native_end");
	register_native("zer_round_ended", "native_ended");
	register_native("zer_round_started", "native_started");
	register_native("zer_round_starting", "native_starting");
	register_native("zer_waiting_for_players", "native_wfp");
	register_native("zer_is_change_map", "native_is_cm");
	register_native("zer_can_change_map", "native_can_cm");
}

public plugin_cfg( )
{
	GetRoundTime( );
}


/* ~(Client Functions)~ */
public client_putinserver(id)
{
	CheckWFP( );
}

public client_disconnected(id, bool:drop, message[], maxlen)
{
	CheckWFP( );
}


/* ~(Public Functions)~ */
// [ Round ]
public RoundTime(pcvar, oldValue[], newValue[])
{
	bRoundTimeChanged = true;
}

public OnRoundStart( )
{
	ExecuteForward( pForwards[ RFWD_RoundStart2 ], _ );

	bRoundStarted = true;
}

public OnRoundStart2( )
{
	if ( iRound == MaxRounds )
	{
		ChangeMap( );
		return;
	}

	if ( !( rRestart > Rs_Not ) || !bWFP )
		++iRound;

	if ( bRoundTimeChanged )
		GetRoundTime( );

	if ( bJustWFP )
		bJustWFP = false;

	ExecuteForward( pForwards[ RFWD_RoundStart ], _ );

	rRestart = Rs_Not;
	bRoundEnded = false;
	bRoundStarted = false;

	flRoundStartTime = get_gametime( );

	StartCountdown;

	#if defined DEBUG
	server_print( "Server Round Started" );
	#endif
}

public OnRoundEnd( )
{
	if ( bWFP )
		return;

	#if defined DEBUG
	server_print( "Server Round Ending" );
	#endif

	//static Float: TimePassed;
	//TimePassed = ( get_gametime() - flRoundStartTime + 1.0 );

	bRoundEnded = true;

	new WinType: RoundWin = WIN_DRAW, WinStatus: GameWin = WINSTATUS_DRAW, ScenarioEventEndRound: WinEvent = ROUND_END_DRAW;

	if ( rRestart > Rs_Not )
	{
		RoundWin = WIN_RESTART;
		GameWin = WINSTATUS_NONE;
		WinEvent = ROUND_GAME_RESTART;

		set_pcvar_num( cvarRestart[ 0 ], 0 );
		set_pcvar_num( cvarRestart[ 1 ], 0 );
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

	rg_round_end(iCvars[ PCV_RoundEndDelay ][ CI_flValue ], GameWin, WinEvent, RoundWinMessages[ RoundWin ], "");
}

public OnRoundEnd2( WinStatus: status, ScenarioEventEndRound: event, Float: tmDelay )
{
	if ( !bRoundEnded )
		CheckRoundEnd( get_gametime( ) );

	SetHookChainReturn(ATYPE_BOOL, false);
	return HC_SUPERCEDE;
}

public Countdown( pCountdown )
{
	static Float: flGameTime; flGameTime = get_gametime();

	if ( ( !bRoundStarted && !bRoundEnded || !bWFP ) && !bJustWFP )
	{
		if ( bWFP )
			CheckWFP( );
		
		if ( !( rRestart > Rs_Not ) )
			Count( flGameTime );

		set_entvar( pCountdown, var_nextthink, flGameTime + 1.0 );
	}

	#if defined DEBUG
	server_print( "Countdown: ( !bRoundStarted && !bRoundEnded || !bWFP ), !bJustWFP = %i, %i  ", ( !bRoundStarted && !bRoundEnded || !bWFP ), !bJustWFP );
	#endif
}

// [ Checks ]


/* ~(RG_CSGameRules_*)~ */
public ReHook_ChangeMap( )
{
	if ( !bChangeMap )
		return HC_SUPERCEDE;

	return HC_CONTINUE;
}

public ReHook_FreezeEnd( )
{
	SetRoundTimer( iMaxRoundTime - iFreezeTime );
}



/* ~(Natives)~ */
// Float: flDelay = 5.0, WinType: Win = WIN_NONE, RsType: Restart, 
public native_end(plgId, paramnum)
{
	if ( paramnum < 6 )
		return;

	new Float: flDelay = get_param_f( 1 ),
		WinType: reWin = WinType: get_param( 2 ),
		RsType: reRestartType = RsType: get_param( 3 ),
		WinStatus: reWinStatus = WINSTATUS_NONE,
		ScenarioEventEndRound: reScenarioEvent = ROUND_NONE,
		endMsg[ 20 ],
		endSound[ 20 ],
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

	new endMsgHandle = PrepareArray( endMsg, charsmax( endMsg ) ),
		endSoundHandle = PrepareArray( endSound, charsmax( endSound ) );

	if ( trigger )
	{
		ExecuteForward( pForwards[ RFWD_RoundEndPre ], _, flDelay, reWin, endMsgHandle, endSoundHandle );

		if ( reWin == WIN_RESTART )
			rRestart = reRestartType;
	}

	bRoundEnded = true;

	rg_round_end( flDelay, reWinStatus, reScenarioEvent, endMsg, endSound);

	if ( trigger )
		ExecuteForward( pForwards[ RFWD_RoundEnd ], _, flDelay, reWin, endMsgHandle, endSoundHandle );
}

public native_ended(plgId, paramnum)
{
	return bRoundEnded;
}

public native_started(plgId, paramnum)
{
	return bRoundStarted;
}

public native_starting(plgId, paramnum)
{
	return ( !bRoundEnded && !bRoundStarted );
}

public native_wfp(plgId, paramnum)
{
	return bWFP;
}

public native_is_cm(plgId, paramnum)
{
	return bChangeMap;
}

public native_can_cm(plgId, paramnum)
{
	if ( paramnum < 1 )
		return;

	new iValue = get_param( 1 );

	bChangeMap = bool: iValue;
}


/* ~(Stock Functions)~ */
stock GetRoundTime( )
{
	new rTime[5], fTime[5];
	get_pcvar_string(cvarRoundTime, rTime, charsmax(rTime));
	get_pcvar_string(cvarFreezeTime, fTime, charsmax(fTime));

	new iRTime = floatround( ( IsFloat( rTime ) ? str_to_float( rTime ) : float( str_to_num( rTime ) ) ) * 60.0 );
	new iFTime = ( IsFloat( fTime ) ? floatround( str_to_float( fTime ) ) : str_to_num( fTime ) );

	if ( iRTime > MaxRoundTime )
		iRTime = MaxRoundTime;

	iMaxRoundTime = iRTime + iFTime;
	iFreezeTime = iFTime;

	#if defined DEBUG
	server_print( "Round time is %i and Round freezetime is %i", iMaxRoundTime, iFreezeTime );
	#endif

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

	server_print( szMsg );
}