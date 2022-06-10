#include "msCounter.h"


unsigned long getmsCounter()
{
	return(HW_MSCOUNTER(0));
}


