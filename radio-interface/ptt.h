/*
 * ptt.h
 *
 *  Created on: Sep 7, 2017
 *      Author: jmf6
 */

#ifndef PTT_H_
#define PTT_H_

enum PTT_ACTION {PTT_ON,PTT_OFF,PTT_TOGGLE};

void PTT_init(void);

void ptt_set(int action);

float ptt_on_delay(float delay);

int ptt_get(void);


#endif /* PTT_H_ */
