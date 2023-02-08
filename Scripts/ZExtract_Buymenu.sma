/*-*~()~*-*/
/*-*~(Require Semicolons)~*-*/
#pragma semicolon 1


/*-*~(Includes)~*-*/
#include <amxmodx>
#include <engine>
#include <hamsandwich>
#include <reapi>

#include <zextract_const>
#include <zextract_buymenu_const>
#include <zextract_zombie>

#include <amx_settings_api>


/*-*~(Enums)~*-*/
enum _: Fwds {
	FWD_BUYITEM,
	FWD_BUYAMMOITEM,
	FWD_BUYAMMO,
	FWD_BUYAMMO_POST,
	FWD_OPENCAT,
	FWD_OPENBUY
}


/*-*~(File Configs)~*-*/
new const szFilePath[ ] = "addons/amxmodx/configs/ZExtract/";
new const szFileName[ ] = "ZExtract_BuyItems.ini";


/*-*~(Buymenu)~*-*/
new const g_CategName[ CATEGORIES ][ ] = {
	"Pistols",
	"Shotguns",
	"Sub-Machines",
	"Sniper Rifles",
	"Assault Rifles",
	"Machineguns",
	"Equipment",
	"Knives"
};


/*-*~(Vars)~*-*/
new g_szMenuCodes[ ][ ] = {
	"\R", "\w", "\r", "\d", "\y"
};

new g_Forward[ Fwds ],

	// Sort, Item and Category Vars
	g_ItemData[ ItemRegisterData ],

	g_iCategItems[ CATEGORIES ],
	g_iSortedItemsCost[ CATEGORIES ][ SortDir ][ MAX_ITEMS_CATEGORY ],
	g_iSortedItemsName[ CATEGORIES ][ SortDir ][ MAX_ITEMS_CATEGORY ],

	g_iItems,

	// Message Id Holders
	msgBuyClose,
	msgStatusIcon;


/*-*~(Publics)~*-*/
public plugin_precache( )
{
	g_Forward[ FWD_BUYAMMOITEM ] = 		CreateMultiForward("ZEX_BuyAmmo_Item", 	ET_CONTINUE, FP_CELL);
	g_Forward[ FWD_BUYAMMO ] = 			CreateMultiForward("ZEX_BuyAmmo", 	 	ET_CONTINUE, FP_CELL, FP_CELL);
	g_Forward[ FWD_BUYAMMO_POST ] = 	CreateMultiForward("ZEX_BuyAmmo_Post", 	ET_IGNORE, FP_CELL, FP_CELL);
	g_Forward[ FWD_BUYITEM ] = 			CreateMultiForward("ZEX_BuyItem", 	 	ET_CONTINUE, FP_CELL, FP_CELL);
	g_Forward[ FWD_OPENBUY ] = 			CreateMultiForward("ZEX_OpenBuymenu",   ET_CONTINUE, FP_CELL);
	g_Forward[ FWD_OPENCAT ] = 			CreateMultiForward("ZEX_OpenCategory",  ET_CONTINUE, FP_CELL, FP_CELL);

	g_ItemData[ IRD_SystemName ] = 		ArrayCreate(20, 1);
	g_ItemData[ IRD_Name ] = 			ArrayCreate(30, 1);
	g_ItemData[ IRD_Cost ] = 			ArrayCreate(1, 1);
	g_ItemData[ IRD_AmmoCost ] =		ArrayCreate(1, 1);
	g_ItemData[ IRD_Category ] = 		ArrayCreate(1, 1);
	//g_ItemData[ IRD_Flags ] = 			ArrayCreate(1, 1);
}

public plugin_natives( )
{
	register_native("zex_register_item", 		"native_register_item");
	//register_native("zex_get_item_data",		"native_itemdata");
}

public plugin_init( )
{
	register_plugin("[ZEX] Buymenu", "v1.0", "DeclineD");
	
	register_clcmd("buy",				"cmdBuyOrig");

	register_clcmd("client_buy_open",	"cmdBuy");

	register_clcmd("buyammo1",			"cmdAmmo");
	register_clcmd("buyammo2",			"cmdAmmo");

	msgBuyClose = get_user_msgid("BuyClose");
	msgStatusIcon = get_user_msgid("StatusIcon");
}

public plugin_cfg( )
{
	InitSort( );
}

// Reseting player values
public client_putinserver(id)
{

}

// Setting the buy signal so the commands will be triggered
public client_PreThink(id)
{
	if(!is_user_alive(id))
		return;

	new iSignals = get_member(id, m_signals);

	if (!is_bit(iSignals, _:SIGNAL_BUY ))
	{
		message_begin(MSG_ONE, msgStatusIcon, _, id);
		write_byte(1);
		write_string("buyzone");
		write_byte(0);
		write_byte(160);
		write_byte(0);
		message_end();
	}
}

// Send signal to plugins to get notified that the weapon needs a refill
public cmdAmmo(id)
{
	new g_iItem = -1;
	ExecuteForward(g_Forward[FWD_BUYAMMOITEM], g_iItem, id);

	if(g_iItem == -1)
		return;

	new g_iRet;
	ExecuteForward(g_Forward[FWD_BUYAMMO], g_iRet, id, g_iItem);

	if(g_iRet > ZEXRet_Continue)
		return;

	new iCost = ArrayGetCell(g_ItemData[IRD_Cost], g_iItem),
		iMoney = GetMoney(id);

	if(iMoney - iCost < 0)
		return;

	ExecuteForward(g_Forward[FWD_BUYAMMO_POST], _, id, g_iItem);

	if(iCost)
		SetMoney(id, GetMoney(id)-iCost);
}

// Close the original buymenu (VGUI ON)
public cmdBuyOrig(id)
{
	message_begin(MSG_ONE, msgBuyClose, _, id);
	message_end();

	client_print(id, print_console, "Opening the buymenu.");

	cmdBuy(id);

	//return PLUGIN_HANDLED;
}

// Open the custom BuyMenu
public cmdBuy(id)
{
	client_print(id, print_console, "Opening the buymenu.");

	if(zex_is_zombie(id))
	{
		client_print(id, print_console, "You cannot open the shop as a zombie.");
		return PLUGIN_HANDLED;
	}

	BuyMenu(id);

	//return PLUGIN_HANDLED;
}

public BuyHand(id, menu, item)
{
	if(item == MENU_EXIT)
	{
		menu_destroy(menu);
		return;
	}
	menu_destroy(menu);

	CategoryMenu(id, item);
}

public ItemCallback(id, menu, item)
{
	new szInfo[5];
	menu_item_getinfo(menu, item, .info = szInfo, .infolen = charsmax(szInfo));

	new iItem = str_to_num(szInfo);
	
	new iCost = ArrayGetCell(g_ItemData[IRD_Cost], iItem),
		iMoney = GetMoney(id);

	if(iMoney - iCost < 0)
		return ITEM_DISABLED;

	return ITEM_ENABLED;
}

public ItemHand(id, menu, item)
{
	if(item == MENU_EXIT)
	{
		menu_destroy(menu);
		return;
	}

	new szInfo[5];
	menu_item_getinfo(menu, item, .info = szInfo, .infolen = charsmax(szInfo));

	new iItem = str_to_num(szInfo),
		iCost = ArrayGetCell(g_ItemData[IRD_Cost], iItem),
		iMoney = GetMoney(id);

	menu_destroy(menu);

	new iRet;
	ExecuteForward(g_Forward[FWD_BUYITEM], iRet, id, iItem);

	if(iRet > ZEXRet_Continue)
		return;

	SetMoney(id, iMoney-iCost);
}

/*-*~(Private Functions)~*-*/
BuyMenu(id)
{
	new g_iRet;
	ExecuteForward(g_Forward[FWD_OPENBUY], g_iRet, id);

	if(g_iRet > ZEXRet_Continue)
		return;

	new szTemp[256];

	formatex(szTemp, charsmax(szTemp), "\yBuy Menu");
	new iMenu = menu_create(szTemp, "BuyHand");

	//new iCallback = menu_makecallback("BuyCallback");

	for(new i = 0; i < CATEGORIES; i++)
	{
		formatex(szTemp, charsmax(szTemp), "%s", g_CategName[i]);
		menu_additem(iMenu, szTemp);//, .callback = iCallback);
	}

	menu_display(id, iMenu);
}

CategoryMenu(id, category)
{
	new iRet;
	ExecuteForward(g_Forward[FWD_OPENCAT], iRet, id, category);

	if(iRet > ZEXRet_Continue)
		return;

	new szTemp[256];

	formatex(szTemp, charsmax(szTemp), "\yBuy %s", g_CategName[category]);
	new iMenu = menu_create(szTemp, "ItemHand");

	new iCallback = menu_makecallback("ItemCallback");
	new iItem, szName[30], iCost, iMoney;

	console_print(id, "[Buymenu] %d Items in %s", g_iCategItems[category], g_CategName[category]);

	for(new i = 0; i < g_iCategItems[category]; i++)
	{
		iItem = g_iSortedItemsCost[category][SRDir_Ascendent][i];
		iCost = ArrayGetCell(g_ItemData[IRD_Cost], iItem);
		iMoney = GetMoney(id);

		ArrayGetString(g_ItemData[IRD_Name], iItem, szName, charsmax(szName));

		console_print(id, "[Buymenu] Adding %s to the menu.", szName);

		if(iMoney - iCost < 0)
			formatex(szTemp, charsmax(szTemp), "\d%s \R\r%d", szName, iCost);
		else
			formatex(szTemp, charsmax(szTemp), "%s \R\y%d", szName, iCost);

		menu_additem(iMenu, szTemp, fmt("%d", iItem), .callback = iCallback);
	}

	console_print(id, "[Buymenu] Displaying %s menu.", g_CategName[category]);

	menu_display(id, iMenu);
}


CompareStrings( const a[], const b[], const SortDir: dir )
{
	new k = 0;

	new maxLen = min( strlen( a ), strlen( b ) );

	while ( ( a[ k ] == b[ k ] || a[ k ] == 0 || b[ k ] == 0 ) && k < maxLen - 1 )
	{
		k++;
	}

	if ( a[ k ] == b[ k ] )
	{
		if ( strlen( a ) > strlen( b ) )
			return ( dir == SRDir_Ascendent ? 1 : -1 );

		else if ( strlen( a ) < strlen( b ) )
			return ( dir == SRDir_Ascendent ? -1 : 1 );
	}
	else {
		if ( is_ascii_symbol( a[ k ] ) )
		{
			if ( is_ascii_number( b[ k ] ) || is_ascii_letter( b[ k ] ) )
				return 1;
		}
		else if ( is_ascii_number( a[ k ] ) )
		{
			if ( is_ascii_symbol( b[ k ] ) )
				return -1;

			if ( is_ascii_letter( b[ k ] ) )
				return 1;
		}
		else if ( is_ascii_letter( a[ k ] ) )
		{
			if ( is_ascii_number( b[ k ] ) || is_ascii_symbol( b[ k ] ) )
				return -1;
		}

		if ( dir == SRDir_Ascendent )
			return ( a[ k ] > b[ k ] ? 1 : -1 );
		else
			return ( a[ k ] < b[ k ] ? -1 : 1 );
	}

	return 0;
}

SortItemArray( const Sort: mtd, const SortDir: dir, const Category, array[ ] )
{
	server_print("[Buymenu] items in array to sort for category %s", g_CategName[Category]);

	for(new h = 0; h < g_iCategItems[Category]; h++)
		server_print("[Buymenu] %i", array[h]);

	if(g_iCategItems[Category] <= 1)
	{
		server_print("[Buymenu] Not enough items to sort.");
		return;
	}

	new i, j, d;

	if ( mtd == Sort_Name )
	{
		new szName[ 30 ], szName2[ 30 ];

		for ( i = 0; i < g_iCategItems[Category]; i++ )
		{
			ArrayGetString( g_ItemData[ IRD_Name ], array[ i ], szName2, charsmax( szName2 ) );

			for ( d = 0; d < sizeof g_szMenuCodes; d++ )
			{
				if ( contain( szName, g_szMenuCodes[ d ] ) )
					replace_all( szName, charsmax( szName ), g_szMenuCodes[ d ], "");
			}

			for ( j = i+1; j < g_iCategItems[Category]; j++ )
			{
				ArrayGetString( g_ItemData[ IRD_Name ], array[ j ], szName2, charsmax( szName2 ) );

				for ( d = 0; d < sizeof g_szMenuCodes; d++ )
				{
					if ( contain( szName2, g_szMenuCodes[ d ] ) )
						replace_all( szName2, charsmax( szName2 ), g_szMenuCodes[ d ], "");
				}

				if ( CompareStrings( szName2, szName, dir ) > 0 )
	            {
	               inverse_values( array[ i ], array[ j ] );
	            }
			}
		}
	}
	else if ( mtd == Sort_Cost )
	{
		server_print("[Buymenu] Sorting by Cost:");
		new iCost[ 2 ];
		new szSysName[2][20];

		for ( i = 0; i < g_iCategItems[Category]; i++)
		{
			for ( j = i+1; j < g_iCategItems[Category]; j++ )
			{
				iCost[ 0 ] = ArrayGetCell( g_ItemData[ IRD_Cost ], array[ i ] );
				iCost[ 1 ] = ArrayGetCell( g_ItemData[ IRD_Cost ], array[ j ] );

				ArrayGetString( g_ItemData[ IRD_SystemName ], array[i], szSysName[0], charsmax(szSysName[]) );
				ArrayGetString( g_ItemData[ IRD_SystemName ], array[i], szSysName[1], charsmax(szSysName[]) );

				server_print("[Buymenu] %s vs %s", szSysName[0], szSysName[1]);

				if ( ( iCost[ 0 ] > iCost[ 1 ] && dir == SRDir_Ascendent ) ||
					( iCost[ 0 ] < iCost[ 1 ] && dir == SRDir_Descendent ) )
				{
					inverse_values( array[ i ], array[ j ] );
				}

				server_print("[Buymenu] Next: ^n^n");
			}
		}
	}
}

InitSort( )
{
	new szSysName[20], iCount;
	for ( new i = 0; i < CATEGORIES; i++ )
	{
		iCount = 0;

		for ( new z = 0; z < g_iItems; z++ )
		{
			if ( ArrayGetCell( g_ItemData[ IRD_Category ], z ) != i )
				continue;

			if ( iCount == g_iCategItems[ i ] )
				break;

			ArrayGetString( g_ItemData[ IRD_SystemName ], z, szSysName, charsmax(szSysName) );

			server_print("[Buymenu] %s is part of %s (Id: %i | Count: %i)", szSysName, g_CategName[i], z, iCount);

			g_iSortedItemsCost[ i ][ SRDir_Ascendent ][ iCount ] = z;
			g_iSortedItemsName[ i ][ SRDir_Ascendent ][ iCount ] = z;
			g_iSortedItemsCost[ i ][ SRDir_Descendent ][ iCount ] = z;
			g_iSortedItemsName[ i ][ SRDir_Descendent ][ iCount ] = z;

			iCount++;
		}

		SortItemArray( Sort_Cost, SRDir_Ascendent, i, g_iSortedItemsCost[ i ][ SRDir_Ascendent ] );
		SortItemArray( Sort_Name, SRDir_Ascendent, i, g_iSortedItemsName[ i ][ SRDir_Ascendent ] );
		SortItemArray( Sort_Cost, SRDir_Descendent, i, g_iSortedItemsCost[ i ][ SRDir_Descendent ] );
		SortItemArray( Sort_Name, SRDir_Descendent, i, g_iSortedItemsName[ i ][ SRDir_Descendent ] );
	}

	for ( new i = 0; i < CATEGORIES; i++ )
	{
		for ( new z = 0; z < g_iCategItems[i]; z++ )
		{
			ArrayGetString( g_ItemData[ IRD_SystemName ], g_iSortedItemsCost[i][SRDir_Ascendent][z], szSysName, charsmax(szSysName) );

			server_print("[Buymenu] Category %s by Cost: %i. %s", g_CategName[i], z, szSysName);
		}
	}
}

/*-*~(Natives)~*-*/
public native_register_item( plgId, paramNum )
{
	if ( paramNum < 5 )
	{
		return -1;
	}

	new szSys[ 20 ];
	get_string( 1, szSys, charsmax( szSys ) );

	strtolower( szSys );

	for ( new i = 0; i < g_iItems; i++ )
	{
		new szSys2[ 20 ];
		ArrayGetString( g_ItemData[ IRD_SystemName ], i, szSys2, charsmax( szSys2 ) );

		strtolower( szSys2 );

		if ( equal( szSys2, szSys ) )
		{
			server_print("[Buymenu] Item already in buymenu: %s", szSys);
			return -1;
		}
	}

	new szName[ 30 ], iCat;
	get_string( 2, szName, charsmax( szName ) );

	iCat = get_param( 5 );

	ArrayPushString( g_ItemData[ IRD_SystemName ], szSys );
	ArrayPushString( g_ItemData[ IRD_Name ], szName );
	ArrayPushCell( g_ItemData[ IRD_Cost ], get_param( 3 ) );
	ArrayPushCell( g_ItemData[ IRD_AmmoCost ], get_param( 4 ) );
	ArrayPushCell( g_ItemData[ IRD_Category ], iCat );
	//ArrayPushCell( g_ItemData[ IRD_Flags ], get_param( 6 ) );

	g_iItems++;
	g_iCategItems[ iCat ]++;

	server_print("[Buymenu] New Item: %s (Sys: %s | Id: %i | Category Item Count: %i)", szName, szSys, g_iItems-1, g_iCategItems[iCat]);

	return g_iItems - 1;
}

/*-*~(Stocks)~*-*/
stock inverse_values( &x, &y )
{
	new z = x;
	x = y;
	y = z;
}

stock bool: is_ascii_letter( ch )
{
	return ( !is_ascii_symbol( ch ) && !is_ascii_number( ch ) );
}

stock bool: is_ascii_number( ch )
{
	return ( 48 <= ch <=  57 );
}

stock bool: is_ascii_symbol( ch )
{
	return ( ( 33 <= ch <= 47 ) || ( 58 <= ch <= 64 ) || ( 91 <= ch <=  96 ) ||
		( 123 <= ch <= 126 ) || ( ch == 247 ) || ( 174 <= ch <=  191 ) ||
		( 161 <= ch <=  172 ) || ( 130 <= ch <=  137 ) || ( ch == 139 ) || ( 145 <= ch <=  155 ) );
}