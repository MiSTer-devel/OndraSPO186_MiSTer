#ifndef UART_H
#define UART_H

#include "sys/types.h"

/* Hardware registers for a supporting UART to the ZPUFlex project. */

#define UARTBASE 0xFFFFFFC0
#define HW_UART(x) *(volatile unsigned int *)(UARTBASE+x)

#define REG_UART 0x0
#define REG_UART_RXINT 9
#define REG_UART_TXREADY 8


extern unsigned long uarttimeoutms;                // char read timeout in ms

#ifndef DISABLE_UART_TX
int putchar(int c);
int puts(const char *msg);
#else
#define putchar(x) (x)
#define puts(x)
#endif

#ifndef DISABLE_UART_RX
char getserial();
int getserialTO(char *ch);
#else
#define getserial 0
#endif

#endif

