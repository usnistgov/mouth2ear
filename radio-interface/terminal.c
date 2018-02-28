/*
 * terminal.c
 *
 *  Created on: Aug 24, 2017
 *      Author: Jesse Frey
 */

#include "terminal.h"
#include <stdlib.h>        //needed for NULL and size_t
#include <string.h>
#include <stdio.h>
#include <ctype.h>

//used to break up a string into arguments for parsing
//*argv[] is a vector for the arguments and contains pointers to each argument
//*dst is a buffer that needs to be big enough to hold all the arguments
//returns the argument count
unsigned short make_args(char *argv[],const char *src,char *dst){
    unsigned short argc=0;
    argv[0]=dst;
    for(;;){
        while(isspace(*src))src++;
        //copy non space characters to dst
        while(!isspace(*src) && *src)
            *dst++=*src++;
        //terminate string bit
        *dst++=0;
        //at the end of src?
        if(*src==0)break;
        argc++;
        argv[argc]=dst;
    }
    //don't count null strings
    if(*argv[argc]==0)argc--;
    return argc;
}

//print a list of all commands
int helpCmd(int argc,char **argv){
  int i,rt=0;
  if(argc!=0){
    //arguments given, print help for given command
    //loop through all commands
    for(i=0;cmd_tbl[i].name!=NULL;i++){
      //look for a match
      if(!strcmp(cmd_tbl[i].name,argv[1])){
        //match found, print help and exit
        printf("%s %s\r\n",cmd_tbl[i].name,cmd_tbl[i].helpStr);
        return 0;
      }
    }
    //no match found print error
    printf("Error : command \'%s\' not found\r\n",argv[1]);
    //fall through and print a list of commands and return -1 for error
    rt=-1;
  }
  //print a list of commands
  printf("Possible Commands:\r\n");
  for(i=0;cmd_tbl[i].name!=NULL;i++){
    printf("\t%s\r\n",cmd_tbl[i].name);
  }
  return rt;
}

//execute a command
int doCmd(const char *cs){
  //buffers for args and arg vector
  //NOTE: this limits the maximum # of arguments
  //      and total length of all arguments
  char args[50];
  char *argv[10];
  unsigned short argc;
  int i;
  //split string into arguments
  argc=make_args(argv,cs,args);
  //search for command
  for(i=0;cmd_tbl[i].name!=NULL;i++){
    //look for a match
    if(!strcmp(cmd_tbl[i].name,argv[0])){
      //match found, run command and return
      return cmd_tbl[i].cmd(argc,argv);
    }
  }
  //unknown command, print help message
  printf("unknown command \'%s\'\r\n",argv[0]);
  helpCmd(NULL,0);
  //unknown command, return error
  return 1;
}


void terminal_proc_char(char c,TERM_DAT *data){
    //process received character
    switch(c){
        case '\r':
        case '\n':
            //return key run command
            if(data->cIdx==0){
                //if nothing entered, ring bell
                putchar(0x07);
                break;
            }else{
                //run command from buffer
                data->linebuf[data->cIdx]=0;    //terminate command string
                data->cIdx=0;         //reset the command index
            }
            //send carriage return and new line
            printf("\r\n");
            //run command
            doCmd(data->linebuf);
            //print prompt char
            putchar('>');
            return;
        case '\x7f':
        case '\b':
            //backspace
            if(data->cIdx==0)return;
            //backup and write over char
            printf("\b \b");
            //decrement command index
            data->cIdx--;
            return;
        case '\t':
            //ignore tab character
            return;
    }
    //check for control char
    if(!iscntrl(c) && data->cIdx<(sizeof(data->linebuf)/sizeof(data->linebuf[0]) - 1)){
      //echo character
      putchar(c);
      //put character in command buffer
      data->linebuf[data->cIdx++]=c;
    }
}

//initialize terminal structure
void terminal_init(TERM_DAT *data){
    //clear string
    data->linebuf[0]='\0';
    data->cIdx=0;
}


//process a block of characters for the terminal
void terminal_proc_block(const char *inbuf,size_t num,TERM_DAT *data){
    int i;
    for(i=0;i<num;i++){
        //process one char at a time
        terminal_proc_char(inbuf[i],data);
    }
}


