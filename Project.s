.global _start
_start:
	
	ldr r4, UART
	ldr r5, P_PORT
	ldr r6, LED_BASE
	ldr r7, TIMER
	ldr r8, KEY_START
	ldr r9, RES_START
	
@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@ START OF MAIN PROGRAM @@

	@ INITIALIZE TIMER
	ldr r0, =400000000 @ every two seconds
	str r0, [r7]
	
	@ INITIALIZE GPIO PORT
	ldr r0, =0x15 @ 0b10101
	str r0, [r5, #4]
	
	@ Set it to locked on startup
	mov r0, #1
	lsl r0, #4
	str r0, [r5] @ pin 4 in GPIO
	
	lsl r0, #5
	str r0, [r6] @ top LED
	
	@ INITIALIZE KEY
	ldr r1, =chars @ get array
	mov r2, #12 @ loop counter
	_loop:
	/* read next character from array, then
	increment array address */
	ldr r0, [r1], #4
	str r0, [r8], #4 @ write to address
	subs r2, #1 @ increment counter
	bne _loop
	
	@ INITIALIZE COUNTER
	mov r10, #0
	
	mov r2, #0
	
_main_loop:
	ldr r2, [r4] @ read from JTAG UART

	ands r1, r2, #0x8000 @ check if bit 15 is 1
	andne r2, #0xFF @ 0b11111111
	strne r2, [r9], #4
	addne r10, #1
	movne r2, #0

	cmp r10, #12
	blt _main_loop @ only continue once we receive all 12 bytes of data
	
	@ compare values
	bl _compare

	@ enable correct led and solenoid
	bl _set_state
	
	@ reset counter
	bl _reset
	
	b _main_loop
@@@ END OF MAIN PROGRAM @@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@
	
@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@ START OF SUBROUTINES @@@
_compare:
	push {r0, r1, r2, r3, lr}

	ldr r8, KEY_START
	ldr r9, RES_START
	mov r10, #0
	mov r2, #12 @ loop counter
	_cmploop:
	ldr r0, [r8], #4
	ldr r1, [r9], #4
	
	cmp r0, r1
	addeq r10, #1 @ if match, increment counter
	
	subs r2 , #1 @ increment loop counter
	bne _cmploop

	pop {r0 - r3, lr}

	bx lr
	
_set_state:
	push {r0, r1, r2, r3, lr}
	
	cmp r10, #12
	bleq _pass @ the keys match
	blne _fail @ no match

	@ start timer
	mov r0, #0b11
	str r0, [r7, #8]
	wait:
	ldr r3, [r7, #12]
	cmp r3, #0
	beq wait
	@ clear timeout flag
	str r3, [r7, #12]
	@ stop timer
	mov r0, #0
	str r0 , [r7, #8]
	
	@ turn off lights
	@ GPIO port
	ldr r0, [r5]
	mov r1, #1
	lsl r1, #4
	and r0, r1 @ set everything to 0 except for lock
	str r0, [r5]
	
	@ LEDs
	ldr r0, [r6]
	mov r1, #1
	lsl r1, #9
	and r0, r1
	str r0, [r6]
	
	pop {r0 - r3, lr}

	bx lr
	
_pass:
	push {r0, r1, r2, r3, lr}

	@ GPIO port
	ldr r0, [r5]
	mov r1, #1
	orr r0, r1 @ turn on light
	
	lsl r1, #4
	eor r0, r1 @ flip lock state
	
	str r0, [r5]

	@ LEDs
	ldr r0, [r6]
	mov r1, #1
	orr r0, r1
	
	lsl r1, #9
	eor r0, r1
	
	str r0, [r6]
	
	pop {r0 - r3, lr}

	bx lr
	
_fail:
	push {r0, r1, r2, r3, lr}

	@ GPIO port
	ldr r0, [r5]
	mov r1, #1
	lsl r1, #2
	orr r0, r1 @ turn on light
	str r0, [r5]

	@ LEDs
	ldr r0, [r6]
	mov r1, #1
	lsl r1, #4
	orr r0, r1
	str r0, [r6]
	
	pop {r0 - r3, lr}

	bx lr

_reset:
	@ reset everything
	mov r10, #0 @ reset counter
	ldr r8, KEY_START
	ldr r9, RES_START
	
	@ clear memory
	mov r0, #0
	mov r2, #12 @ loop counter
	_rst_loop:
	str r0, [r9], #4 @ write to address
	subs r2, #1 @ increment counter
	bne _rst_loop
	
	ldr r9, RES_START

	bx lr
@@@ END OF SUBROUTINES @@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@
	
@ labels for constants and addresses
LED_BASE:		.word	0xFF200000
TIMER:			.word	0xFFFEC600
P_PORT:			.word	0xFF200060
UART:			.word	0xFF201000
KEY_START:		.word	0x00001000
RES_START:		.word	0x00001030

.data
/* data structure for storing array
of characters */
chars:
.word 113 @ q in ASCII
.word 119 @ w
.word 101 @ e
.word 114 @ r
.word 97  @ a
.word 115 @ s
.word 100 @ d
.word 102 @ f
.word 122 @ z
.word 120 @ x
.word 99  @ c
.word 118 @ v
.text