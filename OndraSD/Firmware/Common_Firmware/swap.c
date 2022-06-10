unsigned int ConvBBBB_LE(unsigned int i)
{
	unsigned int result=(i>>24)&0xff;
	result|=(i>>8)&0xff00;
	result|=(i<<8)&0xff0000;
	result|=(i<<24)&0xff000000;
	return(result);
}

unsigned int ConvBB_LE(unsigned int i)
{
	unsigned short result=(i>>8)&0xff;
	result|=(i<<8)&0xff00;
	return(result);
}

unsigned long ConvWW_LE(unsigned long i)
{
	unsigned int result=(i>>16)&0xffff;
	result|=(i<<16)&0xffff0000;
	return(result);
}
