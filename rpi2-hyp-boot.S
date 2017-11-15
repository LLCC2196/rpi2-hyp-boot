
#define HYP_MODE        0x1a
#define T_BIT           0x20
#define F_BIT           0x40
#define I_BIT           0x80
#define A_BIT           0x100

.arch_extension sec
.arch_extension virt

.section .init
.globl _start

_start:
	b jmp_loader
	.word 0
	adr pc, _secure_monitor
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0


_secure_monitor:
	mrc	p15, 0, r1, c1, c1, 0		@ read SCR
	bic	r1, r1, #0x4e			@ clear IRQ, FIQ, EA, nET bits
	orr	r1, r1, #0x31			@ enable NS, AW, FW bits
	orr	r1, r1, #0x100			@ allow HVC instruction

	mcr	p15, 0, r1, c1, c1, 0		@ write SCR (with NS bit set)

        mov     r0, #(F_BIT | I_BIT | A_BIT)    @ Set A, I and F
        orr     r0, r0, #HYP_MODE               @ Slot target mode in
        msr     spsr_cxfs, r0                   @ Set full SPSR

	@ Reset CNTVOFF to 0 before leaving monitor mode
	mov	r0, #0
	mcrr	p15, 4, r0, r0, c14		@ Reset CNTVOFF to zero
1:
	movs	pc, lr				@ return to non-secure SVC

jmp_loader:
@ Check which proc we are and run proc 0 only

	mrc p15, 0, r0, c1, c0, 0 @ Read System Control Register
	orr r0, r0, #(1<<2)       @ cache enable
	orr r0, r0, #(1<<12)      @ icache enable
	mcr p15, 0, r0, c1, c0, 0 @ Write System Control Register

	mrc p15, 0, r0, c1, c0, 1 @ Read Auxiliary Control Register
	orr r0, r0, #(1<<6)       @ SMP
	mcr p15, 0, r0, c1, c0, 1 @ Write Auxiliary Control Register

	mov r0, #1
	mcr p15, 0, r0, c14, c3, 1 @ CNTV_CTL (enable=1, imask=0)

@ set to non-sec
	movw	r1, #0x3fff
	movt	r1, #0x0006
	mcr	p15, 0, r1, c1, c1, 2		@ NSACR = all copros to non-sec
@ timer frequency
	ldr	r1, =19200000
	mcr	p15, 0, r1, c14, c0, 0		@ write CNTFRQ

	adr	r1, _start
	mcr	p15, 0, r1, c12, c0, 1		@ set MVBAR to secure vectors
	mrc	p15, 0, ip, c12, c0, 0		@ save secure copy of VBAR

	isb
	smc	#0				@ call into MONITOR mode

	mcr	p15, 0, ip, c12, c0, 0		@ write non-secure copy of VBAR

	mov	r4, #0x8000
	mrc     p15, 0, r0, c0, c0, 5
	ubfx    r0, r0, #0, #2
	cmp     r0, #0
	beq     9f

	cmp     r0, #0xff
	bge	10f

	ldr	r5, =0x4000008C		@ mbox
	ldr	r3, =0x00000000		@ magic
	str	r3, [r5, r0, lsl #4]

	ldr	r5, =0x400000CC		@ mbox
1:
	ldr	r4, [r5, r0, lsl #4]
	cmp	r4, r3
	beq	1b
9:
	mov	r0, #0
	ldr	r1, =3138		@ BCM2708 machine id
	ldr	r2, =0x100		@ ATAGS
	bx	r4
10:
	wfi
	b	10b

