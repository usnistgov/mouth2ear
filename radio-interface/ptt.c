/*
 * ptt.c
 *
 *  Created on: Sep 7, 2017
 *      Author: jmf6
 */

#include "ptt.h"
#include <msp430.h>

#define PTT_PIN     BIT2

void PTT_init(void){
    //setup PTT pin

    //set pin low
    P8OUT&=~PTT_PIN;
    //set pin as output
    P8DIR|= PTT_PIN;

    //Setup ptt tone pin

    //select timer function
    P2SEL|=BIT5;
    //set pin to output
    P2DIR|=BIT5;
}

void ptt_tone_stop(void){
    //stop and timer
    TA2CTL=TASSEL_1|ID_0;
    //set output low
    TA2CCTL2=0;
}

//period of PTT tone
#define PTT_TONE_PERIOD      80

void ptt_tone_start(void){
    //stop and setup timer
    TA2CTL=TASSEL_1|ID_0;
    //set period
    TA2CCR0=PTT_TONE_PERIOD;
    //set high time
    TA2CCR2=PTT_TONE_PERIOD/2;
    //setup output mode of timer
    TA2CCTL2=OUTMOD_7;
    //start and clear timer
    TA2CTL|=MC_1|TACLR;
}


void ptt_set(int action){
    //disable delay timer interrupt
    TA0CCTL0=0;
    //check action
    switch(action){
        case PTT_ON:
            //set pin high
            P8OUT|= PTT_PIN;
            //start ptt tone
            ptt_tone_start();
            break;
        case PTT_OFF:
            //set ptt pin low
            P8OUT&=~PTT_PIN;
            //stop ptt tone
            ptt_tone_stop();
            break;
        case PTT_TOGGLE:
            //toggle PTT pin
            P8OUT^= PTT_PIN;
            //check ptt status
            if(P8OUT&=PTT_PIN){
                //start ptt tone
                ptt_tone_start();
            }else{
                //stop ptt tone
                ptt_tone_stop();
            }
            break;
    }
}

//PTT on delay
static unsigned short ptt_delay=0;

float ptt_on_delay(float delay){
    //calculate delay in timer clocks
    delay=delay*(32768/32);
    //limit to timer maximum
    if(delay>65535){
        //set to maximum
        delay=65535;
    }
    //limit minimum to 1
    if(delay<1){
        //set to one
        delay=1;
    }
    //set ptt delay
    ptt_delay=delay;
    //setup TA0CCR0 to capture timer value
    TA0CCTL0=CM_3|CCIS_2|SCS|CAP|CCIE;
    //capture current timer value
    TA0CCTL0^=CCIS0;
    //return actual delay
    return ptt_delay/(float)(32768/32);
}

//get ptt status
int ptt_get(void){
    //get status from ptt pin
    return !!(P8OUT&=PTT_PIN);
}


// ============ TA0 CCR0 ISR ============
// This is used for button debouncing
#if defined(__TI_COMPILER_VERSION__) || (__IAR_SYSTEMS_ICC__)
#pragma vector=TIMER0_A0_VECTOR
__interrupt void PTT_timer_ISR (void)
#elif defined(__GNUC__) && (__MSP430__)
void __attribute__ ((interrupt(TIMER0_A0_VECTOR))) PTT_timer_ISR (void)
#else
#error Compiler not found!
#endif
{
    //check if timer is in capture mode
    if(TA0CCTL0&=CAP){
        //add delay to capture time
        TA0CCR0+=ptt_delay;
        //set to compare mode and enable interrupts
        TA0CCTL0=CCIE;
    }else{
        //disable timer interrupt
        TA0CCTL0=0;
        //turn on ptt
        ptt_set(PTT_ON);
    }
}

