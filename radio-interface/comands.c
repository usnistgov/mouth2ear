/*
 * comands.c
 * Terminal command functions
 *
 *  Created on: Aug 25, 2017
 *      Author: jmf6
 */

#include "terminal.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include "hal.h"
#include "ptt.h"

#include "USBprintf.h"

int ptt_Cmd(int argc,char *argv[]){
    float delay;
    char *eptr;
    if(argc==0){
        //print out status
        printf("PTT status : %s\r\n",ptt_get()?"on":"off");
    }else{
        if(!strcmp("on",argv[1])){
            //check number of arguments
            if(argc>1){
                printf("Error : too many arguments\r\n");
                return 1;
            }
            // Turn on push to talk
            ptt_set(PTT_ON);
        }else if(!strcmp("off",argv[1])){
            //check number of arguments
            if(argc>1){
                printf("Error : too many arguments\r\n");
                return 1;
            }
            // Turn off push to talk
            ptt_set(PTT_OFF);
        }else if(!strcmp("delay",argv[1])){
            //check number of arguments
            if(argc>2){
                printf("Error : too many arguments\r\n");
                return 1;
            }
            //parse delay value
            delay=strtod(argv[2],&eptr);
            //check that some chars were parsed
            if(argv[2]==eptr){
                printf("Error : could not parse delay value \"%s\"\r\n",argv[2]);
                return 3;
            }
            //check that delay is greater than zero
            if(delay<0){
                printf("Error : delay of %f is not valid. Valid delays must be greater than zero\r\n",delay);
                return 4;
            }
            //start delay count down
            delay=ptt_on_delay(delay);
            //print out actual delay
            printf("PTT in %f sec\r\n",delay);
        }else{
            //error
            printf("Error : Unknown state \"%s\"\r\n",argv[1]);
            return 2;
        }
    }
    return 0;
}

int devtype_Cmd(int argc,char *argv[]){
    // Print device type, use a fixed version number for now
    printf("MCV radio interface v0.1\r\n");
    return 0;
}

const struct{
    int port,pin;
}leds[2]={{GPIO_PORT_P1,GPIO_PIN0},{GPIO_PORT_P4,GPIO_PIN7}};

int LED_Cmd(int argc,char *argv[]){
    int LED_num,LED_idx;
    if(argc<2){
        //too few arguments
        printf("Too few arguments\r\n");
        return 1;
    }
    //get LED number
    LED_num=atoi(argv[1]);
    if(LED_num<=0 || LED_num>2){
        //invalid LED number
        printf("Invalid LED number \"%s\"\r\n",argv[1]);
        return 1;
    }
    //subtract 1 to get index
    LED_idx=LED_num-1;
    //parse state
    if(!strcmp("on",argv[2])){
        GPIO_setOutputHighOnPin(leds[LED_idx].port,leds[LED_idx].pin);
    }else if(!strcmp("off",argv[2])){
        GPIO_setOutputLowOnPin(leds[LED_idx].port,leds[LED_idx].pin);
    }else{
        //invalid state
        printf("Error : invalid state \"%s\"\r\n",argv[2]);
        return 2;
    }
    return 0;
}

int closeout_Cmd(int argc,char *argv[]){
    int i;
    //turn off ptt
    ptt_set(PTT_OFF);
    //loop through all LED's
    for(i=0;i<sizeof(leds)/sizeof(leds[0]);i++){
        //turn off LED
        GPIO_setOutputLowOnPin(leds[i].port,leds[i].pin);
    }
    return 0;
}

float ADC_temp_scl,ADC_temp_offset;

void ADCinit(void){
    unsigned int cal_30c,cal_85c;
    //disable ADC
    ADC12CTL0&=~ADC12ENC;
    //setup REF for always on
    REFCTL0=REFMSTR|REFOUT|REFON;
    //setup ADC
    //NOTE : 8 clocks can be used for sample and hold time if only thermistor is used (5k ohm eq series resistance)
    ADC12CTL0=ADC12SHT1_6|ADC12SHT0_6|ADC12MSC|ADC12ON;
    ADC12CTL1=ADC12CSTARTADD_0|ADC12SHS_0|ADC12SHP|ADC12DIV_1|ADC12SSEL_0|ADC12CONSEQ_1;
    //disable output buffers on analog ports
    P6SEL|=BIT0|BIT1|BIT2|BIT3|BIT4|BIT5|BIT6;
    P7SEL|=BIT0;

    //read temperature reference points
    cal_30c=*((unsigned int *)0x1A1A);
    cal_85c=*((unsigned int *)0x1A1C);
    //generate calibration factors
    ADC_temp_scl=(85 - 30)/(float)(cal_85c - cal_30c);
    ADC_temp_offset=30-((float)cal_30c)*ADC_temp_scl;
}

int analog_Cmd(int argc,char *argv[]){
    unsigned short raw[16];
    float scaled[16];
    int ch[16];
    int i;
    volatile unsigned char *memctl=&ADC12MCTL0;
    volatile unsigned int *res=&ADC12MEM0;

    //check the number of arguments
    if(argc<1){
        printf("Error : too few arguments\r\n");
        return 1;
    }
    if(argc>=16){
        printf("Error : too many arguments\r\n");
        return 2;
    }
    //disable ADC
    ADC12CTL0&=~ADC12ENC;
    //parse arguments
    for(i=0;i<argc;i++){
        if(argv[i+1][0]=='A'){
            //get channel number
            ch[i]=atoi(argv[i+1]+1);
            //check for valid chanel numbers
            if(ch[i]<0 || ch[i]>15){
                printf("Error : invalid channel number \"%s\" while parseing channel \"%s\"\r\n",argv[i+1]+1,argv[i+1]);
                return 3;
            }
            //set up memctl
            memctl[i]=ADC12SREF_0|ch[i];
        }else if(!strcmp(argv[i+1],"Tint")){
            ch[i]=-1;
            //set up memctl for temp diode using internal ref
            memctl[i]=ADC12SREF_1|ADC12INCH_10;
        }
    }
    //set end of sequence
    memctl[i]|=ADC12EOS;
    //enable ADC and start conversion
    ADC12CTL0|=ADC12ENC|ADC12SC;
    //wait while conversion is in progress
    while(ADC12CTL1&ADC12BUSY);
    //disable ADC
    ADC12CTL0&=~ADC12ENC;
    //get results
    for(i=0;i<argc;i++){
        raw[i]=res[i];
        if(ch[i]==-1){
            scaled[i]=ADC_temp_scl*raw[i]+ADC_temp_offset;
            printf("Tint = %.2f C\r\n",scaled[i]);
        }else{
            scaled[i]=3.3/((float)0xFFF)*raw[i];
            printf("A%i = %.4f V\r\n",ch[i],scaled[i]);
        }
    }
    return 0;
}


int temp_Cmd(int argc,char *argv[]){
    unsigned short raw[2];
    float Tint;
    //disable ADC
    ADC12CTL0&=~ADC12ENC;
    //set up memctl for temp diode using internal ref
    ADC12MCTL0=ADC12SREF_1|ADC12INCH_10;
    //read external thermistor voltage
    ADC12MCTL1=ADC12SREF_0|ADC12INCH_5|ADC12EOS;
    //enable ADC and start conversion
    ADC12CTL0|=ADC12ENC|ADC12SC;
    //wait while conversion is in progress
    while(ADC12CTL1&ADC12BUSY);
    //disable ADC
    ADC12CTL0&=~ADC12ENC;
    //get results
    raw[0]=ADC12MEM0;
    raw[1]=ADC12MEM1;
    //calculate internal temperature
    Tint=ADC_temp_scl*raw[0]+ADC_temp_offset;
    //print results
    printf("int = %f C\r\next = %u\r\n",Tint,raw[1]);
    return 0;
}

//table of commands with help
const CMD_SPEC cmd_tbl[]={{"help"," [command]\r\n\t""get a list of commands or help on a spesific command.",helpCmd},
                          {"ptt"," state\r\n\t""change the push to talk state of the radio",ptt_Cmd},
                          {"devtype","\r\n\t""get the device type string",devtype_Cmd},
                          {"LED","number state\r\n\t""set the LED status",LED_Cmd},
                          {"closeout","\r\n\tTurn off ptt and all LED's",closeout_Cmd},
                          {"analog","ch1 [ch2] ... [chn]\r\n\tRead analog values",analog_Cmd},
                          {"temp","\r\n\tRead temperature sensors",temp_Cmd},
                          //end of list
                          {NULL,NULL,NULL}};
