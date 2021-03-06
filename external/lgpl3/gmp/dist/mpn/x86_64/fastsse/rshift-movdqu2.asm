dnl  AMD64 mpn_rshift optimised for CPUs with fast SSE including fast movdqu.

dnl  Contributed to the GNU project by Torbjorn Granlund.

dnl  Copyright 2010, 2011, 2012 Free Software Foundation, Inc.

dnl  This file is part of the GNU MP Library.

dnl  The GNU MP Library is free software; you can redistribute it and/or modify
dnl  it under the terms of the GNU Lesser General Public License as published
dnl  by the Free Software Foundation; either version 3 of the License, or (at
dnl  your option) any later version.

dnl  The GNU MP Library is distributed in the hope that it will be useful, but
dnl  WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
dnl  or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
dnl  License for more details.

dnl  You should have received a copy of the GNU Lesser General Public License
dnl  along with the GNU MP Library.  If not, see http://www.gnu.org/licenses/.

include(`../config.m4')


C	     cycles/limb     cycles/limb     cycles/limb    good
C              aligned	      unaligned	      best seen	   for cpu?
C AMD K8,K9	 3		 3		 2.35	  no, use shl/shr
C AMD K10	 1.5-1.8	 1.5-1.8	 1.33	  yes
C AMD bd1	 1.7-1.9	 1.7-1.9	 1.33	  yes
C AMD bobcat	 3.17		 3.17			  yes, bad for n < 20
C Intel P4	 4.67		 4.67		 2.7	  no, slow movdqu
C Intel core2	 2.15		 2.15		 1.25	  no, use shld/shrd
C Intel NHM	 1.66		 1.66		 1.25	  no, use shld/shrd
C Intel SBR	 1.3		 1.3		 1.25	  yes, bad for n = 4-6
C Intel atom	11.7		11.7		 4.5	  no
C VIA nano	 5.7		 5.95		 2.0	  no, slow movdqu

C We try to do as many aligned 16-byte operations as possible.  The top-most
C and bottom-most writes might need 8-byte operations.
C
C This variant rely on fast load movdqu, and uses it even for aligned operands,
C in order to avoid the need for two separate loops.
C
C TODO
C  * Could 2-limb wind-down code be simplified?
C  * Improve basecase code, using shld/shrd for SBR, discrete integer shifts
C    for other affected CPUs.

C INPUT PARAMETERS
define(`rp',  `%rdi')
define(`ap',  `%rsi')
define(`n',   `%rdx')
define(`cnt', `%rcx')

ASM_START()
	TEXT
	ALIGN(64)
PROLOGUE(mpn_rshift)
	FUNC_ENTRY(4)
	movd	R32(%rcx), %xmm4
	mov	$64, R32(%rax)
	sub	R32(%rcx), R32(%rax)
	movd	R32(%rax), %xmm5

	neg	R32(%rcx)
	mov	(ap), %rax
	shl	R8(%rcx), %rax

	cmp	$3, n
	jle	L(bc)

	bt	$3, R32(rp)
	jnc	L(rp_aligned)

C Do one initial limb in order to make rp aligned
	movq	(ap), %xmm0
	movq	8(ap), %xmm1
	psrlq	%xmm4, %xmm0
	psllq	%xmm5, %xmm1
	por	%xmm1, %xmm0
	movq	%xmm0, (rp)
	lea	8(ap), ap
	lea	8(rp), rp
	dec	n

L(rp_aligned):
	lea	1(n), %r8d
	lea	(ap,n,8), ap
	lea	(rp,n,8), rp
	neg	n

	and	$6, R32(%r8)
	jz	L(bu0)
	cmp	$4, R32(%r8)
	jz	L(bu4)
	jc	L(bu2)
L(bu6):	add	$4, n
	jmp	L(i56)
L(bu0):	add	$6, n
	jmp	L(i70)
L(bu4):	add	$2, n
	jmp	L(i34)
L(bu2):	add	$8, n
	jge	L(end)

	ALIGN(16)
L(top):	movdqu	-64(ap,n,8), %xmm1
	movdqu	-56(ap,n,8), %xmm0
	psllq	%xmm5, %xmm0
	psrlq	%xmm4, %xmm1
	por	%xmm1, %xmm0
	movdqa	%xmm0, -64(rp,n,8)
L(i70):
	movdqu	-48(ap,n,8), %xmm1
	movdqu	-40(ap,n,8), %xmm0
	psllq	%xmm5, %xmm0
	psrlq	%xmm4, %xmm1
	por	%xmm1, %xmm0
	movdqa	%xmm0, -48(rp,n,8)
L(i56):
	movdqu	-32(ap,n,8), %xmm1
	movdqu	-24(ap,n,8), %xmm0
	psllq	%xmm5, %xmm0
	psrlq	%xmm4, %xmm1
	por	%xmm1, %xmm0
	movdqa	%xmm0, -32(rp,n,8)
L(i34):
	movdqu	-16(ap,n,8), %xmm1
	movdqu	-8(ap,n,8), %xmm0
	psllq	%xmm5, %xmm0
	psrlq	%xmm4, %xmm1
	por	%xmm1, %xmm0
	movdqa	%xmm0, -16(rp,n,8)
	add	$8, n
	jl	L(top)

L(end):	bt	$0, R32(n)
	jc	L(e1)

	movdqu	-16(ap), %xmm1
	movq	-8(ap), %xmm0
	psrlq	%xmm4, %xmm1
	psllq	%xmm5, %xmm0
	por	%xmm1, %xmm0
	movdqa	%xmm0, -16(rp)
	FUNC_EXIT()
	ret

L(e1):	movq	-8(ap), %xmm0
	psrlq	%xmm4, %xmm0
	movq	%xmm0, -8(rp)
	FUNC_EXIT()
	ret

C Basecase
	ALIGN(16)
L(bc):	dec	R32(n)
	jnz	1f
	movq	(ap), %xmm0
	psrlq	%xmm4, %xmm0
	movq	%xmm0, (rp)
	FUNC_EXIT()
	ret

1:	movq	(ap), %xmm1
	movq	8(ap), %xmm0
	psrlq	%xmm4, %xmm1
	psllq	%xmm5, %xmm0
	por	%xmm1, %xmm0
	movq	%xmm0, (rp)
	dec	R32(n)
	jnz	1f
	movq	8(ap), %xmm0
	psrlq	%xmm4, %xmm0
	movq	%xmm0, 8(rp)
	FUNC_EXIT()
	ret

1:	movq	8(ap), %xmm1
	movq	16(ap), %xmm0
	psrlq	%xmm4, %xmm1
	psllq	%xmm5, %xmm0
	por	%xmm1, %xmm0
	movq	%xmm0,	8(rp)
	movq	16(ap), %xmm0
	psrlq	%xmm4, %xmm0
	movq	%xmm0, 16(rp)
	FUNC_EXIT()
	ret
EPILOGUE()
