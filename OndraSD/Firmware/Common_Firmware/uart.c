#include "uart.h"


unsigned long uarttimeoutms = 250;                // char read timeout in ms

#ifndef DISABLE_UART_TX
__inline int putchar(int c)
{
	while(!(HW_UART(REG_UART)&(1<<REG_UART_TXREADY)))
		;
	HW_UART(REG_UART)=c;
	return(c);
}

int puts(const char *msg)
{
	int result;
	while(*msg)
	{
		putchar(*msg++);
		++result;
	}
	return(result);
}
#endif

#ifndef DISABLE_UART_RX
char getserial()
{
	int r=0;
	while(!(r&(1<<REG_UART_RXINT)))
		r=HW_UART(REG_UART);
	return(r);
}

int getserialTO(char *ch)
{
	int r=0;
	unsigned long endTime = getmsCounter() + uarttimeoutms;
	
	while(!(r&(1<<REG_UART_RXINT)))
	{
		if (getmsCounter() > endTime)
			return(0);
		r=HW_UART(REG_UART);
	}
	*ch = (char)r;
	return(1);
}
#endif

