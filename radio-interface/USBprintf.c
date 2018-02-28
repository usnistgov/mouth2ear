/*
 * USBprintf.c
 *
 *  Created on: Aug 28, 2017
 *      Author: jmf6
 *
 *     This file implements a the backend functions to allow printf to work 
 *     over USB. The USB data is sent in the background so that other 
 *     processing can be done while data is sent. To prevent new data from 
 *     writing over older data, double buffering is used. 
 */

#include <stdio.h>
#include <string.h>
#include <stdint.h>

#include "USBprintf.h"

#include "USB_config/descriptors.h"
#include "USB_API/USB_Common/device.h"
#include "USB_API/USB_Common/usb.h"                 // USB-specific functions
#include "USB_API/USB_CDC_API/UsbCdc.h"
#include "USB_app/usbConstructs.h"

//Number of buffers to use. 2 is a good number as sending function will block if a send is in progress
#define NUM_USB_BUFFERS     2
//Number of bytes in send buffer. The size only matters if fputs gets called as putc and putchar both send the char that they receive immediately.
#define USB_BUFF_SIZE       64

//current buffer index to use. This switches every time data is sent
static short current_buf=0;

//data for buffers
static char buffers[NUM_USB_BUFFERS][USB_BUFF_SIZE];

//macro to switch which buffer is the curernt one
#define nextBuffer()        (current_buf=((++current_buf>=NUM_USB_BUFFERS)?0:current_buf))

int fputc(int _c, register FILE *_fp){
    //set buffer
    buffers[current_buf][0]=_c;
    //send char
    USBCDC_sendDataInBackground((uint8_t*)buffers[current_buf],1,CDC0_INTFNUM,0);
    //switch buffers
    nextBuffer();
    return((unsigned char)_c);
}

int putc(int _c, register FILE *_fp){
    //set buffer
    buffers[current_buf][0]=_c;
    //send char
    USBCDC_sendDataInBackground((uint8_t*)buffers[current_buf],1,CDC0_INTFNUM,0);
    //switch buffers
    nextBuffer();
    return((unsigned char)_c);
}

int putchar(int _x){
    //set buffer
    buffers[current_buf][0]=_x;
    //send char
    USBCDC_sendDataInBackground((uint8_t*)buffers[current_buf],1,CDC0_INTFNUM,0);
    //switch buffers
    nextBuffer();
    return((unsigned char)_x);
}

int fputs(const char *_ptr, register FILE *_fp)
{
  char *dptr=buffers[current_buf];
  int i,len;

  //loop while terminator not found
  for(i=0,len=0;*_ptr;i++,len++){
      //check if buffer is full
      if(i>=USB_BUFF_SIZE){
          //send data
          USBCDC_sendDataInBackground((uint8_t*)buffers[current_buf],USB_BUFF_SIZE,CDC0_INTFNUM,0);
          //reset count
          i=0;
          //switch buffers
          nextBuffer();
          //reset pointer
          dptr=buffers[current_buf];
      }
      //copy char
      *dptr++=*_ptr++;
  }

  //check if there is data to send
  if(i>0){
      USBCDC_sendDataInBackground((uint8_t*)buffers[current_buf],i,CDC0_INTFNUM,0);
      //switch buffers
      nextBuffer();
  }

  return len;
}

