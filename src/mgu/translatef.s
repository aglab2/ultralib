/************************************************************************
 Copyright (C) 1998,1999 NINTENDO CO,Ltd,
 Copyright (C) 1998,1999 MONEGI CORPORATION,
	All Rights Reserved
This program is a trade secret of NINTENDO CO,Ltd and MONEGI Corp. 
and it is not to be reproduced, published, disclosed to others, copied,
adapted, distributed, or displayed without the prior authorization of 
NINTENDO CO,Ltd. and MONEGI Corp. Licensee agrees to attach or embed 
this Notice on all copies of the program, including partial copies or 
modified versions thereof.
*************************************************************************/
/************************************************************************
 $Date: 1999/06/16 09:15:41 $
 $Revision: 1.1 $
 $Author: doseki $
************************************************************************/
#include "asm.h"
#include "regdef.h"

/* 
 * void guTranslateF(float m[4][4], float x, float y, float z)
 * m:	a0
 * x:	a1
 * y:	a2
 * z:	a3		
 */
	.text
	.align	5
LEAF( guTranslateF )
	.set reorder

	li	t0,0x3f800000	/* t0 = 1.0 */
	
	sw	t0, 0(a0)
	sw	zero, 4(a0)	/* line 1 */
	sw	zero, 8(a0)
	sw	zero, 12(a0)

	sw	zero, 16(a0)	/* line 2 */
	sw	t0, 20(a0)
	sw	zero, 24(a0)
	sw	zero, 28(a0)

	sw	zero, 32(a0)	/* line 3 */
	sw	zero, 36(a0)
	sw	t0, 40(a0)
	sw	zero, 44(a0)

#if (_MIPS_SIM == _MIPS_SIM_ABI32)
	sw	a1, 48(a0)	/* line 4 */
	sw	a2, 52(a0)
	sw	a3, 56(a0)
#elif (_MIPS_SIM == _MIPS_SIM_ABI64 || _MIPS_SIM == _MIPS_SIM_NABI32)
	swc1	fa1, 48(a0)	/* line 4 */
	swc1	fa2, 52(a0)
	swc1	fa3, 56(a0)
#else // eabi
	swc1	fa0, 48(a0)	/* line 4 */
	swc1	fa1, 52(a0)
	swc1	fa2, 56(a0)
#endif 
	sw	t0, 60(a0)

	j	ra

	END( guTranslateF )

/* End of file */
