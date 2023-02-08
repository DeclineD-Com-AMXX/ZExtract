#if defined _zextract_const_included
	#endinput
#endif
#define _zextract_const_included

#define ZEXRet_Handled 80
#define ZEXRet_Supercede 81
#define ZEXRet_Continue 79

#define is_bit(%1,%0)		(%1 & (1<<%0))
#define set_bit(%1,%0) 		%1 |= (1<<%0)
#define remove_bit(%1,%0) 	%1 &= ~(1<<%0)