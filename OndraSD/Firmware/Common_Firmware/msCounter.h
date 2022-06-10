#ifndef MSCOUNTER_H
#define MSCOUNTER_H

/* Hardware registers for a supporting miliseconds counter to the ZPUFlex project. */

#define MSCOUNTERBASE 0xFFFFFFC8
#define HW_MSCOUNTER(x) *(volatile unsigned long *)(MSCOUNTERBASE+x)
 
unsigned long getmsCounter();


#endif
