/* Sublime AMXX Editor v3.0.0-beta */

#if defined _zextract_const_included
	#endinput
#endif
#define _zextract_const_included

/* ~(Restart)~ */
enum RsType
{
	Rs_Not,
	Rs_Round,
	Rs_All
}

enum WinType
{
	WIN_NONE = -1,
	WIN_RESTART,
	WIN_DRAW,
	WIN_HUMAN,
	WIN_ZOMBIE
}