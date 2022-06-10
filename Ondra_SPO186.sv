//============================================================================
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [45:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	output  [7:0] VIDEO_ARX,
	output  [7:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

///////// Default values for ports not used in this core /////////

//assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {UART_RTS, UART_DTR} = 0;

//assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;  

assign VGA_SL = 0;
assign VGA_F1 = 0;

assign AUDIO_S = 0;
assign AUDIO_MIX = 3;

wire LED_GREEN;
wire LED_YELLOW;
wire LED_RED;

assign LED_POWER = { 1'b1, LED_GREEN };	
assign LED_USER = LED_RED;
assign LED_DISK = { 1'b1, LED_YELLOW };	
assign BUTTONS = 0;


//////////////////////////////////////////////////////////////////

assign VIDEO_ARX = 8'd4;
assign VIDEO_ARY = 8'd3; 

`include "build_id.v" 
localparam CONF_STR = {
	"Ondra_SPO186;;",	
	"-;",	
	"O56,ROM,ViLi,Tesla v5,Test ROM;",				
	"O7,ADC line pass through,On,Off;",
	"-;",	
	"R0,Reset Ondra;",	
	"J,Fire 1;",
	"V,v",`BUILD_DATE 
};

wire forced_scandoubler = 1;
wire  [1:0] buttons;
wire [31:0] status;
wire [10:0] ps2_key;

wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_data;
wire        ioctl_download;
wire  [7:0] ioctl_index;

wire [15:0] joy;
// RTC MSM6242B layout
(* keep *) wire [64:0] RTC;
	
	
hps_io #(.STRLEN($size(CONF_STR)>>3)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.conf_str(CONF_STR),
	.forced_scandoubler(forced_scandoubler),

	.buttons(buttons),
	.status(status),
	.ps2_key(ps2_key),
	.joystick_0(joy),
	.RTC(RTC),

	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_data),
	.ioctl_download(ioctl_download),
	.ioctl_index(ioctl_index)  
);



///////////////////////   CLOCKS   ///////////////////////////////

wire locked;
wire clk_sys; // 8MHz clock

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_sys),
	.locked(locked)
);

wire reset = RESET | status[0] | buttons[1];

//////////////////////////////////////////////////////////////////

//-------------------------------------------------------------------------------
//  Cassette audio in 
//
  
wire tape_adc, tape_adc_act;
ltc2308_tape ltc2308_tape
(
	.clk(CLK_50M),
	.ADC_BUS(ADC_BUS),
	.dout(tape_adc),
	.active(tape_adc_act)
);  

//-------------------------------------------------------------------------------
// Ondra MELODIK - sn76489_audio
//
wire [7:0] Parallel_Data_OUT;	
wire NON_STB;

//wire [13:0] mix_audio_o;
//
//sn76489_audio #(.MIN_PERIOD_CNT_G(17)) sn76489_audio
//(  .clk_i(clk_sys),          //System clock
//   .en_clk_psg_i(clk_snen), //PSG clock enable
//   .ce_n_i(0),              //chip enable, active low
//   .wr_n_i(NON_STB),        // write enable, active low
//   .reset_n_i(reset_n),
//   .data_i(Parallel_Data_OUT),
//   .mix_audio_o(mix_audio_o)
//);


//------------------------------------------------------------
//-- Keyboard controls
//------------------------------------------------------------
reg kbd_reset = 0;
reg kbd_ROM_change = 0;
reg kbd_scandoublerOverride = 0;
reg old_stb = 0;    
reg kbd_enter = 0;

wire pressed = ps2_key[9];
wire input_strobe = ps2_key[10];
wire extended = ps2_key[8];
wire [7:0] scancode = ps2_key[7:0];	

always @(posedge clk_sys) 
begin
	old_stb <= input_strobe;
   if ((old_stb != input_strobe) & (~extended))
	begin		
      case(scancode)
//         8'h03: kbd_reset <= pressed;         // F5 = RESET
//         8'h0A: if (pressed)                  // F8 = scandoubler Override
//            kbd_scandoublerOverride <= ~kbd_scandoublerOverride;            
//         8'h01: kbd_ROM_change <= pressed;    // F9 =  change ROM & reset!
         8'h5a : kbd_enter <= pressed; // ENTER         
      endcase	
   end
end	
      
		
//-------------------------------------------------------------------------------
//  Ondra SD
//

wire OndraSD_signal_led;
wire OndraSD_rxd;
wire OndraSD_txd;

OndraSD #(.sysclk_frequency(50000000)) OndraSD // 50MHz
(
   .clk(CLK_50M),
   .reset_in(~reset),
   .enter_key(kbd_enter),
   .signal_led(OndraSD_signal_led),
   // SPI signals
   .spi_miso(SD_MISO),
   .spi_mosi(SD_MOSI),
   .spi_clk(SD_SCK),
   .spi_cs(SD_CS),
   

   // UART
   .rxd(OndraSD_rxd),
   .txd(OndraSD_txd)
); 
 
assign LED_RED = ~SD_CS;

 
	

//-------------------------------------------------------------------------------
//
//

//-------------------------------------------------------------------------------

wire HSync;
wire VSync;
wire HBlank;
wire VBlank;
wire pixel;
wire beeper;
wire TXD;


Ondra_SPO186_core Ondra_SPO186_core
(
	.clk_50M(CLK_50M),
	.clk_sys(clk_sys),
	.reset(reset),	
	.ps2_key(ps2_key),
	.HSync(HSync),
	.VSync(VSync),	
	.HBlank(HBlank),
	.VBlank(VBlank),
	.pixel(pixel),
	.beeper(beeper),
	.LED_GREEN(LED_GREEN),
	.LED_YELLOW(LED_YELLOW),
	//.RELAY(LED_RED), // red led will indicate RELAY activity
	.joy(joy),
	.RESERVA_IN(OndraSD_txd), //rxd
	.RESERVA_OUT(OndraSD_rxd), // txd
	.MGF_IN(tape_adc),
	.ROMVersion(status[6:5]),
	.Parallel_Data_OUT(Parallel_Data_OUT),	
   .NON_STB(NON_STB)	
);


//assign USER_OUT[1:0] = {TXD, 1'b1};

assign AUDIO_L = (beeper ? 16'h0FFF : 16'h00) | 
					  (~status[7] & tape_adc ? 16'h07F0 : 16'h00);
assign AUDIO_R = (beeper ? 16'h0FFF : 16'h00) | 
					  (~status[7] & tape_adc ? 16'h07F0 : 16'h00);
assign CLK_VIDEO = clk_sys;
assign CE_PIXEL = 1;
assign VGA_R = pixel ? 8'hFF : 8'h00;
assign VGA_G = pixel ? 8'hFF : 8'h00;
assign VGA_B = pixel ? 8'hFF : 8'h00;
assign VGA_HS = HSync;
assign VGA_VS = VSync;
assign VGA_DE = ~(HBlank | VBlank);


endmodule
