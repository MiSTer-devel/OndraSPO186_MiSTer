//#include "stdarg.h"


#include "Common_Firmware/uart.h"
#include "Common_Firmware/spi.h"
#include "Common_Firmware/minfat.h"
//#include "fat.h"
//#include "small_printf.h"

#define FW_VERSION ((unsigned char)0x12)
#define SIGNALLEDBASE 0xFFFFFFA0
#define UARTSPEEDBASE 0xFFFFFFA4
#define ENTERKEYBASE  0xFFFFFFA8
                      
#define HW_SIGNALLED *(volatile unsigned int *)(SIGNALLEDBASE)
#define HW_UARTSPEED *(volatile unsigned int *)(UARTSPEEDBASE)
#define HW_ENTERKEYPRESSED *(volatile unsigned int *)(ENTERKEYBASE)

  
static unsigned char buf[512];
//static fileTYPE ft;
static unsigned char param[11];
static int i;
//static __uint32_t size; 
static unsigned long size; 
DIRENTRY *dirEntry;

int fileSearchMatch(const char *fn)
{
	
	return 1;
}
	
void SendFile(const char *fileName)
{
	fileTYPE ft;
	if(FileOpen(&ft, fileName))				
	{
		size = ft.size; 	
		do
		{
			FileReadSector(&ft, buf); 
			for (i=0; i < 512; i++)
			{
				if (size == 0)
					break;							
				putchar(buf[i]);
				size--;							
			}
			//ft.sector++;
			FileNextSector(&ft, 1);
		} while (size > 0);
	}
	else
		; //puts("Opening file error\n");	
	return;	
}	
	
void Wait(unsigned long ms)	
{
	unsigned long endTime = getmsCounter() + ms;	
	while(1)
	{
		if (getmsCounter() > endTime)
			return;		
	}
}
	
void LedErrorFlah(int flashesNr)
{
	int i;
	while (1)
	{
		for (i=0; i<flashesNr; i++)
		{
			HW_SIGNALLED = 1;	
			Wait(250);
			HW_SIGNALLED = 0;	
			Wait(250);		
		}
		Wait(1000);
	}
}
	
int main(int argc, char **argv)
{	
	int keepSendingLoader = 1;
	int ignoreFirstChange2Root = 1;
	// Initializing SD card
	spi_init();
	// Hunting for partition
	FindDrive();
	ChangeDirectoryByName("ONDRA      \0");	
	
	uarttimeoutms = 500; // 0.5sec
	
	while (1)
	{
		char c;
		if (!getserialTO(&c))
		{					
			if ((HW_ENTERKEYPRESSED & 0x01) & keepSendingLoader)
			{	
				keepSendingLoader = 0;
				Wait(1000);		
				SendFile("__LOADERBIN");				
			}
			continue;
		}
		
		switch (toupper(c))
		{
			
			/// A	 Alter settings
			/// 0, 1	 zmena prenosovej r??chlosti (0-9600, 1-57600)
			case 'A':
				param[0] = getserial();				
				//HW_UARTSPEED = (unsigned int)(param[0] != '0');
				HW_UARTSPEED = (unsigned int)(param[0] != 0);
				break;
				
			///  C	 Change directory
			/// dirname[8+3]	 zmena adres??ra, parameter je n??zov adres??ra (11 znakov)
			case 'C':				
				for (i=0; i<11; i++)
					param[i] = getserial();
				param[11] = 0;
				if (compare((const char*)param, "/          ", 11) == 0)
				{
					if (ignoreFirstChange2Root)
						ignoreFirstChange2Root = 0; // don't change to root when Ondra FM loaded
					else
						ChangeDirectory(0);
				}
				else
					ChangeDirectoryByName(param);			
				break;			
				
			/// D    	 Dir	 -	 v??pis aktu??lneho adres??ra (adres??re a s??bory BIN a TAP)
			/* 	System... m????e by?? SystemVolumeInformation, adres??r, ktor?? vytv??ra
				Windows a je skryt??. Alebo nejak?? in?? syst??mov?? adres??r.
				OndraFM odo??le pr??kaz "D" a potom ??ak?? na d??ta, ktor?? musia ma?? 13
				bajtov (11 bajtov n??zov, 1 bajt atrib??t a 0x00 ako odde??ova??), 0xFF
				ukon??uje d??tov?? tok. V pr??pade poruchy na linke program jednoducho
				zamrzne (nie je tam ??iadny time-out). Maxim??lny po??et z??znamov je 48,
				ostatn?? FM ignoruje.Ondra n??zvy uklad?? do RAM, zarovnan?? na 16 bajtov.
			*/
			case 'D':
				dirEntry = NextDirEntry(1, &fileSearchMatch);
				do
				{
					if (dirEntry->Attributes & ATTR_DIRECTORY)
					{	
						if (compare((const char*)dirEntry->Name, ".          ", 11) != 0)
						{
							for (i=0; i<11; i++)
								putchar(dirEntry->Name[i]);	
							putchar('Q');
							putchar(0);
						}
					}
					else if (!(dirEntry->Attributes & (ATTR_VOLUME | ATTR_DIRECTORY)))
					{
						if ((compare((const char*)dirEntry->Extension, "BIN", 3) == 0) ||
							(compare((const char*)dirEntry->Extension, "TAP", 3) == 0))
						{					
							for (i=0; i<11; i++)							
								putchar(dirEntry->Name[i]);
							putchar('q');
							putchar(0);
						}
					}						
				} while (dirEntry = NextDirEntry(0, &fileSearchMatch));
				putchar(0xFF);
				break;				
				
			/// E	 Echo	 znak	 vr??ti znak, ktor?? bol zadan?? ako parameter
 			case 'E':
				param[0] = getserial();
				putchar(param[0]);
				break;
				
			/// F	 Get File
			/// filename[8+3]	 odvysiela s??bor, parameter je n??zov s??boru (11 znakov)
			case 'F':								
				for (i=0; i<11; i++)
					param[i] = getserial();
				param[11] = 0;			
				Wait(1000);
				SendFile(param);			
				break;			
			
			/// I	 Illuminate	 0, 1 - ovl??danie LED
			case 'I':
				param[0] = getserial();
				//HW_SIGNALLED = (unsigned int)(param[0] != '0');
				HW_SIGNALLED = (unsigned int)(param[0] != 0);
				break;
				
			/// K	 Version - vr??ti ????slo verzie firmv??ru ako jeden bajt
			case 'K':				
				putchar(FW_VERSION);
				break;
				
			/// L	 Start Loader	 -	 za??ne vysiela?? s??bor zav??dza??a
			case 'L':				
				keepSendingLoader = 1;
				break;
			
			/// M	 Message	 -	 informa??n?? spr??va
			case 'M':				
				puts("\n\rOndraSD interface (2.2) + RTC\n\rM1 (c) 2015, 2016\n\rhttps://sites.google.com/site/ondraspo186\n\r");
				putchar(0);
				break;
				
			/// N	 No Loader	 -	 zastav?? vysielanie zav??dza??a
			case 'N':
				keepSendingLoader = 0;
				break;
				
			/// P	 Ping	 -	 vr??ti znak *, sl????i na zistenie pripojenia modulu
			case 'P':				
				putchar('+');
				break;
				
			/// X	 Reset	 -	 reset modulu
			case 'X':
				// no action
				break;
 
			/// S	 Set time - 7b date/time - Nastavenie RTC (pozri datasheet k DS1307)
 			case 'S':
				// no action
				break;
				
			/// T	 Date and time - Odo??le 7 bajtov s aktu??lnym d??tumom a ??asom
 			case 'T':
				// no action		
				Wait(100);
				putchar(0x02); // osc b??????, 32 secs
				putchar(0x47); // 47 min
				putchar(0x11); // 24 hour mode, 11 hod
				putchar(0x02); // druhy den (pondeli?)
				putchar(0x03); // dden 31
				putchar(0x08); // mesic 8
				putchar(0x09); // rok 98
				
				break;
				
			/*
				Pri ????tan??/z??pise  RAW bloku z karty/na kartu:

				????tanie bloku
				O: "R" + 4 bajty adresa
				M: 0xFE (ACK) + 512 bajtov blok d??t (FE je start data token z SD karty)

				z??pis bloku
				O: "I1" (LED)
				O: "W" + 4 bajty adresa sektoru
				M: 0x00 (ACK adresy)
				O: 512 bajtov blok d??t
				M: 0x00 (modifikovan?? n??vratov?? hodnota z SD karty, 0x00 je ??spe??n??
				z??pis, v??etko in?? je chyba)
				O: "I0" (vypne LED)

				n??vratov?? hodnota z SD pri z??pise
				xxx0010x - data accepted
				druh?? bit sa neguje, a X sa nuluj??, tak??e pri ??spe??nom z??pise je
				modifikovan?? hodnota 0x00
			*/
				
			/// R	 Read Block
			///	4b ADDR
			/// vy????ta 512 bajtov (+1b ACK hne?? na ??vod) dan??ho bloku z SD karty
 			case 'R':
				// no action
				break;
				
			/// W	 Write Block
			/// 4b + 512b	 zap????e 512 bajtov ako blok na SD kartu, vr??ti 1b ACK
			case 'W':
				// no action
				break;
				
			default:
				// no action
				break;
		}
		
	}

	return(0);
}

