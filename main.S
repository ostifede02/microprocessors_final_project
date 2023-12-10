## intTest2.S: in-class example to demonstrate PIC interrupt basics
##     Basically same as portTest3.S but using change notification interrupts

    
    // Interrupt vector setup    
    .globl  __vector_dispatch_9    ## Port B change notification = vector #9
    .section .vector_9, code, keep
    .align 2
    .set nomips16
    .ent __vector_dispatch_9
__vector_dispatch_9:
    j  isrvector9	    ## Jump to actual ISR code, which is in text section
    nop
    .end __vector_dispatch_9
    .size __vector_dispatch_9, .-__vector_dispatch_9
    
    .text		## Text section contains code
    .set noreorder	## Disable instruction reordering
    .globl main		## Define main label as a global entity
    .ent main		##   and an entry point    
    
// Including xc.h allows use of SFR names, bit masks, etc.
#include <xc.h>
    
main:
    /***** CONFIGURATION: Switches ports *****/
    add	    t0, zero, zero
    ori	    t0, t0, _PORTB_RB9_MASK	    // R1_button
    ori	    t0, t0, _PORTB_RB8_MASK	    // P1_button
    ori	    t0, t0, _PORTB_RB14_MASK	    // S1_button
    ori	    t0, t0, _PORTB_RB2_MASK	    // R2_button
    ori	    t0, t0, _PORTB_RB1_MASK	    // P2_button
    ori	    t0, t0, _PORTB_RB0_MASK	    // S2_button
    
    sw	    t0, TRISB		    ## TRISB --> pins are inputs
    sw	    zero, ANSELB	    ## ANSELB = 0 --> all PORTB bits digital  
       
    
    /***** CONFIGURATION: LEDs ******/
    sw	    zero, TRISC		    ## TRISC = 0  --> all PORTC bits = output
    sw	    zero, ANSELC	    ## ANSELC = 0 --> all PORTC bits digital

    
    /***** CONFIGURATION: Switches interrupts *****/
    add	    t0, zero, zero
    lui	    t0, 0x0001			## Want INTCON bit 16 (VS<0>) = 1
					##   so vectors 8 bytes apart
    ori	    t0, t0, _INTCON_MVEC_MASK   ## Enable multivectored interrupt mode
    sw	    t0, INTCON
    
    li	    t0, _IPC2_CNBIP_MASK    ## Set change notification Port B interrupt priority level to 7
    sw	    t0, IPC2		    ## Implicitly sets subpriority level to 0
    
    li	    t0, _IEC0_CNBIE_MASK    ## Enable Port B change 
    sw	    t0, IEC0		    ##    notification interrupts

    
    add	    t0, zero, zero
    ori	    t0, t0, _PORTB_RB9_MASK	    // R1_button
    ori	    t0, t0, _PORTB_RB8_MASK	    // P1_button
    ori	    t0, t0, _PORTB_RB14_MASK	    // S1_button
    ori	    t0, t0, _PORTB_RB2_MASK	    // R2_button
    ori	    t0, t0, _PORTB_RB1_MASK	    // P2_button
    ori	    t0, t0, _PORTB_RB0_MASK	    // S2_button
    
    sw	    t0, CNEN1B
    sw	    zero, CNEN0B	    ## Will detect falling edges on these pins
    
    li	    t0, _CNCONB_ON_MASK		    ## Enables Port B change notification
    ori	    t0, t0, _CNCONB_CNSTYLE_MASK    ## Enables edge detection
    sw	    t0, CNCONB
    
    ei				    ## Set global interrupt enable
    /***** END CONFIGURATION *****/

    // button pressed flags
    add	    s1, zero, zero	// player 1
    add	    s2, zero, zero	// player 2
    
    // Main loop does nothing--interrupts detect button press, 
    //    handle LED toggling
mainloop:
    j	    mainloop
    nop
    
    .end main
    
    
    
/**********************************   UTILS   *********************************/    

    .global debounce_delay
    .ent debounce_delay
debounce_delay:
    li	    t7, 0x61A8		    ## Set delay counter to 0x61A8 = 25,000
				    ## Since loop body has 3 instructions,
				    ##   loop takes 25,000 * 3 = 75,000
				    ##   cycles
				    ## Remaining 3 instructions take 3 cycles
				    ##  ~75,000 cycles / 8 MHz clock ~ 0.009375 sec delay
debounce_loop:
    addi    t7, t7, -1		    ## Decrement counter
    bne	    t7, zero, debounce_loop	    ##  and continue doing that until we hit 0
    nop				    
    jr	    ra
    nop

    .end debounce_delay
    
    
    .global led_toggle_delay
    .ent led_toggle_delay
led_toggle_delay:
	li	    t7, 4000000	    ## delay 1.5 seconds
				    
led_toggle_loop:
    addi    t7, t7, -1		    ## Decrement counter
    bne	    t7, zero, led_toggle_loop	    ##  and continue doing that until we hit 0
    nop				    
    jr	    ra
    nop

    .end led_toggle_delay
    
/********************************   END UTILS   *******************************/    

    
    
    
/***********************************   ISR   **********************************/    
    
    
    
    // Handle Port B change interrupt--check switches and toggle appropriate LEDs
    .global isrvector9
    .ent isrvector9
isrvector9:
    jal	    debounce_delay
    nop
    
    j	    check_R1_button
    nop
    
check_R1_button:
    li	    t0, _PORTB_RB9_MASK
    
    // Check if button is pressed
    lw	    t8, CNFB
    and	    t9, t8, t0
    beq	    t9, zero, check_P1_button	    ## If bit 7 = 0, S1 wasn't pressed
    nop
    
    // S1 pressed--clear flag, then debounce and toggle if actually pressed
    sw	    t0, CNFBCLR		    ## Clear flag for S1
    jal	    debounce_delay	    ## Delay to debounce
    nop
    
    lw	    t1, PORTB		    
    and	    t1, t1, t0		    ## Is button still pressed?
    bne	    t1, zero, check_P1_button	    ## If not, leave LED alone and check S2
    nop

    /************ button pressed *************/

    li	    s1, 0b100000
    
    /********** END button pressed ***********/
    
    j	    check_R2_button
    nop
    
    
check_P1_button:
    li	    t0, _PORTB_RB8_MASK
    
    // Check if pressed
    lw	    t8, CNFB
    and	    t9, t8, t0
    beq	    t9, zero, check_S1_button	    ## If bit 7 = 0, S1 wasn't pressed
    nop
    
    // S1 pressed--clear flag, then debounce and toggle if actually pressed
    sw	    t0, CNFBCLR		    ## Clear flag for S1
    jal	    debounce_delay		    ## Delay to debounce
    nop
    
    lw	    t1, PORTB		    
    and	    t1, t1, t0		    ## Is button still pressed?
    bne	    t1, zero, check_S1_button	    ## If not, leave LED alone and check S2
    nop

    /************ button pressed *************/

    li	    s1, 0b10000

    /********** END button pressed ***********/
    
    j	    check_R2_button
    nop
    
    
check_S1_button:
    li	    t0, _PORTB_RB14_MASK

    // Check if pressed
    lw	    t8, CNFB
    and	    t9, t8, t0
    beq	    t9, zero, check_R2_button	    ## If bit 7 = 0, S1 wasn't pressed
    nop
    
    // S1 pressed--clear flag, then debounce and toggle if actually pressed
    sw	    t0, CNFBCLR		    ## Clear flag for S1
    jal	    debounce_delay		    ## Delay to debounce
    nop
    lw	    t1, PORTB		    
    and	    t1, t1, t0		    ## Is button still pressed?
    bne	    t1, zero, check_R2_button	    ## If not, leave LED alone and check S2
    nop

    /************ button pressed *************/

    li	    s1, 0b1000

    /********** END button pressed ***********/
    
    j	    check_R2_button
    nop
       
 
check_R2_button:
    li	    t0, _PORTB_RB2_MASK

    // Check if pressed
    lw	    t8, CNFB
    and	    t9, t8, t0
    beq	    t9, zero, check_P2_button	    ## If bit 7 = 0, S1 wasn't pressed
    nop
    
    // S1 pressed--clear flag, then debounce and toggle if actually pressed
    sw	    t0, CNFBCLR		    ## Clear flag for S1
    jal	    debounce_delay		    ## Delay to debounce
    nop
    lw	    t1, PORTB		    
    and	    t1, t1, t0		    ## Is button still pressed?
    bne	    t1, zero, check_P2_button	    ## If not, leave LED alone and check S2
    nop

    /************ button pressed *************/

    li	    s2, 0b100
    
    /********** END button pressed ***********/  
    
    j	    evaluate_result
    nop
    
    
check_P2_button:
    li	    t0, _PORTB_RB1_MASK
    
    // Check if pressed
    lw	    t8, CNFB
    and	    t9, t8, t0
    beq	    t9, zero, check_S2_button	    ## If bit 7 = 0, S1 wasn't pressed
    nop
    
    // S1 pressed--clear flag, then debounce and toggle if actually pressed
    sw	    t0, CNFBCLR		    ## Clear flag for S1
    jal	    debounce_delay		    ## Delay to debounce
    nop
    lw	    t1, PORTB		    
    and	    t1, t1, t0		    ## Is button still pressed?
    bne	    t1, zero, check_S2_button	    ## If not, leave LED alone and check S2
    nop

    /************ button pressed *************/

    li	    s2, 0b10

    /********** END button pressed ***********/
    
    j	    evaluate_result
    nop
    
    
check_S2_button:
    li	    t0, _PORTB_RB0_MASK
    
    // Check if pressed
    lw	    t8, CNFB
    and	    t9, t8, t0
    beq	    t9, zero, evaluate_result	    ## If bit 7 = 0, S1 wasn't pressed
    nop
    
    // S1 pressed--clear flag, then debounce and toggle if actually pressed
    sw	    t0, CNFBCLR		    ## Clear flag for S1
    jal	    debounce_delay		    ## Delay to debounce
    nop
    lw	    t1, PORTB		    
    and	    t1, t1, t0		    ## Is button still pressed?
    bne	    t1, zero, evaluate_result	    ## If not, leave LED alone and check S2
    nop

    /************ button pressed *************/

    li	    s2, 0b1
    
    /********** END button pressed ***********/
    
    j	    evaluate_result
    nop

evaluate_result:
    or	    t0, s1, s2
    
    // case RED won
    li	    t1, 33
    beq	    t0, t1, red_won
    nop
    
    li	    t1, 20
    beq	    t0, t1, red_won
    nop
    
    li	    t1, 10
    beq	    t0, t1, red_won
    nop
    
    // case GREEN won
    li	    t1, 34
    beq	    t0, t1, green_won
    nop
    
    li	    t1, 17
    beq	    t0, t1, green_won
    nop
    
    li	    t1, 12
    beq	    t0, t1, green_won
    nop    
    
    // case draw
    li	    t1, 36
    beq	    t0, t1, draw
    nop
    
    li	    t1, 18
    beq	    t0, t1, draw
    nop
    
    li	    t1, 9
    beq	    t0, t1, draw
    nop
    
    // default
    j	    interrupt_check_done
    nop
    

red_won:
    // toggle LED red
    li	    t0, _PORTC_RC1_MASK
    sw	    t0, LATCSET
    
    // reset button pressed flags
    add	    s1, zero, zero
    add	    s2, zero, zero    
    
    // delay
    jal	    led_toggle_delay
    nop
    
    j	    interrupt_check_done
    nop

    
green_won:
    // toggle LED green
    li	    t0, _PORTC_RC2_MASK
    sw	    t0, LATCSET
    
    // reset button pressed flags
    add	    s1, zero, zero
    add	    s2, zero, zero
    
    // delay
    jal	    led_toggle_delay
    nop
    
    j	    interrupt_check_done
    nop
    
  
draw:
    // toggle red and green LEDs
    li	    t0, _PORTC_RC2_MASK
    ori	    t0, t0, _PORTC_RC1_MASK
    sw	    t0, LATCSET
    
    // reset button pressed flags
    add	    s1, zero, zero
    add	    s2, zero, zero
    
    // delay
    jal	    led_toggle_delay
    nop
    
    j	    interrupt_check_done
    nop
    
    
interrupt_check_done:
    li	    t0, _IFS0_CNBIF_MASK    ## Clear Port B change notification flag
    sw	    t0, IFS0CLR		    ##    in IFS0
    
    // turn LEDs off
    li	    t0, _PORTC_RC2_MASK
    ori	    t0, t0, _PORTC_RC1_MASK
    sw	    t0, LATCCLR
    
    
    eret		    ## Return from interrupt
    
    .end isrvector9