/*
 * USBprintf.h
 *
 *  Created on: Aug 28, 2017
 *      Author: jmf6
 */

#ifndef USBPRINTF_H_
#define USBPRINTF_H_

#include <stdio.h>

//redifine standard library functions

int putc(int _c, register FILE *_fp);
int fputc(int _c, register FILE *_fp);
int putchar(int _x);
int fputs(const char *_ptr, register FILE *_fp);



#endif /* USBPRINTF_H_ */
