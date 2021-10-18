
module Ondra_SPO186_core (

	input clk_50M, 			// 50MHz main clock
	input clk_sys,  			// 8MHz system clock 
	input reset,
	input [10:0] ps2_key,
	input [24:0] ps2_mouse,	
	output reg HSync,
	output reg VSync,	
	output HBlank,
	output VBlank,
	output pixel,
	output beeper,
	input [15:0] joy,			
	output reg LED_GREEN,
	output reg LED_YELLOW,	
	output reg RELAY,	 
	input RESERVA_IN,  		//rxd
	output reg RESERVA_OUT, // txd		
	input MGF_IN, 				// cassette line in (from ADC)
	input [1:0] ROMVersion
);


//---------------------------------------------- CPU ---------------------------------------------------------
//

reg [2:0] clk_div;
always @(posedge clk_sys)
	clk_div <= clk_div + 1'b1;

wire [15:0] A;
wire  [7:0] D;
wire  [7:0] DOut;
wire        M1_n;
wire        MREQ_n;
wire        IORQ_n;
wire        RD_n;
wire        WR_n;
wire        RFSH_n;
wire        BUSAK_n;
reg         BUSRQ_n;

wire io_wr_n = IORQ_n | WR_n;
wire io_rd_n = IORQ_n | RD_n;
wire mem_rd_n = MREQ_n | RD_n;
wire mem_wr_n = MREQ_n | WR_n;
wire NMI_n = 1;
wire INT_n = Vcnt_out1;


T80se #(.Mode(0), .T2Write(0), .IOWait(0)) cpu
(
	.RESET_n(~reset),
	.CLK_n(~clk_div[1]), // 8MHz / 4 = 2MHz
	.CLKEN(1),
	.WAIT_n(1'b1),
	.INT_n(INT_n),
	.NMI_n(NMI_n),
	.BUSRQ_n(BUSRQ_n),
	.M1_n(M1_n),
	.MREQ_n(MREQ_n),
	.IORQ_n(IORQ_n),
	.RD_n(RD_n),
	.WR_n(WR_n),
	.RFSH_n(RFSH_n),
	.BUSAK_n(BUSAK_n),
	.A(A),
	.DO(DOut),
	.DI(D)
);


assign D = ((ROM1_en | ROM0_en) & ~mem_rd_n) ? data_EPROM_out : 
				(RAM_en & ~mem_rd_n) 				? data_RAM_out : 
				(KBD_Port_en & ~mem_rd_n)			? { MGF_IN, RESERVA_IN, BUSY, row_KJ } : 				
				8'h00;

//------------------------------- Address decoder PROM 74188 ------------------------------------------------
//  
// 

wire latch_control_clk = (io_wr_n | A[3]);
reg videoOff_n;// = D0; = dma enable - nastaveni na 0 zakaze video => BusRQ nanastavi na 1
reg ROM_en; 	// = ~D1 = ROM window enable
reg port_en; 	// = ~D2 = port window enable
reg MGF_out; 	// D3
reg [1:0] A_VHCnt; // Address bits 15 & 14

always @(posedge latch_control_clk or posedge reset)
begin
	if (reset)
	begin
		videoOff_n <= 1'b0;
		ROM_en <= 1'b1;
		port_en <= 1'b0;
		MGF_out <= 1'b0;
		A_VHCnt <= 2'b00;		
	end
	else
	begin
		videoOff_n <= DOut[0];
		ROM_en <= ~DOut[1];
		port_en <= DOut[2];
		MGF_out <= DOut[3];
		A_VHCnt <= DOut[5:4];				
	end
end


wire ROM0_en = BUSAK_n & ROM_en & (A[15:13] == 3'b000); 
wire ROM1_en = BUSAK_n & ROM_en & (A[15:13] == 3'b001);
wire KBD_Port_en = BUSAK_n & port_en & (A[15:13] == 3'b111); 	//  keyboard + JOY + MGF_IN + rxd PORT_n 
wire RAM_en = ~BUSAK_n | (~ROM0_en & ~ROM1_en & ~KBD_Port_en); // read RAM if ROMx and Port is not enabled
wire [1:0] A_RAM_HI = ~BUSAK_n ? 2'b11 : A[15:14];


//----------------------------------------- VIDEO ------------------------------------------------
//
// great page explaining Ondra's video: https://sites.google.com/site/ondraspo186/5-grafika/5-1-ako-to-funguje
// 

wire Hcnt_out0; // H Counter0, MODE 2,  8 bits, Control Word: 14h, Init Value: 40h=64, doba trvania mikroriadku
wire Hcnt_out1; // H Counter1	 MODE 5, 16 bits, Control Word: 7Ah, Init Value: 2Fh,0=47 52/***, začiatok H-SYNC 
wire Hcnt_out2; // H Counter2	 MODE 1, 16 bits, Control Word: B2h, Init Value: 29h,0=41 51/***, počet znakov ****
wire Vcnt_out0; // V Counter0	 MODE 1,	 8 bits, Control Word: 12h (09h), Init Value: ?,255, počet viditeľných mikroriadkov (max. 255)
wire Vcnt_out1; // V Counter1	 MODE 5, 16 bits, Control Word: 7Ah (3Dh), Init Value: 10h(08h),1h(80h)=272 284/***, začiatok V-SYNC
wire Vcnt_out2; // V Counter2	 MODE 2, 16 bits, Control Word: B4h (5Ah), Init Value: 38h(1Ch),1h(80h)=312, počet všetkých mikroriadkov 
wire [15:0] A_VideoRAM;

wire Hcnt_clk = clk_div[2];
wire VHcnt_RD_n = ~(~BUSAK_n & (clk_div[1] | clk_div[2]));
wire VHcnt_WR_n = (IORQ_n | RD_n);


// D33
k580vi53 H_Counter_8253 ( 
	.clk_sys(clk_sys), 
	.reset(reset),
	.addr(A_VHCnt),
	.din(A[15:8]),
	.dout(A_VideoRAM[15:8]),
	.wr(~VHcnt_WR_n),
	.rd(~VHcnt_RD_n),
	.clk_timer( { Hcnt_clk, Hcnt_clk, Hcnt_clk } ),
	.gate( { Hcnt_out0, Hcnt_out0, 1'b1 } ),
	.out( { Hcnt_out2, Hcnt_out1, Hcnt_out0 } )
);
  
  
// D34  
k580vi53 V_Counter_8253 ( 
	.clk_sys(clk_sys), 
	.reset(reset),
	.addr(A_VHCnt),
	.din( { A[6:0], A[7] } ),
	.dout( { A_VideoRAM[6:0] , A_VideoRAM[7] } ),	
	.wr(~VHcnt_WR_n),
	.rd(~VHcnt_RD_n),
	.clk_timer( { Hcnt_out1, Hcnt_out1, Hcnt_out1 } ),
	.gate( { 1'b1, Vcnt_out2, Vcnt_out2 } ),
	.out( { Vcnt_out2, Vcnt_out1, Vcnt_out0 } )
);
  

reg [7:0] pixel_Data;
wire pixel_Data_Load = ~(BUSAK_n | ~(clk_div[0] & clk_div[1] & clk_div[2]));
wire CLR_pixel_Data = (Vcnt_out0 | Hcnt_out2);
assign pixel = pixel_Data[7] & ~CLR_pixel_Data;

always @(posedge clk_sys)
begin
	if (pixel_Data_Load)
		pixel_Data <= data_VRAM_out;
	else 	
		pixel_Data <= { pixel_Data[6:0], 1'b0 };
end
  
  
assign HBlank = Hcnt_out2;
assign VBlank = Vcnt_out0;
 

reg Vcnt_out0_last;
reg Vcnt_out2_last; 
reg VSync_last;
 
always @(posedge clk_sys)
begin

	if (~videoOff_n | ~VSync)
		BUSRQ_n <= 1;		
	else if ((Vcnt_out2) & (Vcnt_out2 == ~Vcnt_out2_last)) // UP
		BUSRQ_n <= 0;
	else if ((Vcnt_out0) & (Vcnt_out0 == ~Vcnt_out0_last)) //  DOWN	
		BUSRQ_n <= 1;

	Vcnt_out0_last <= Vcnt_out0;
	Vcnt_out2_last <= Vcnt_out2;		
end

  

// generator HSync   D35A, R59, C37
// Perioda 64.0417us = 16kHz, log1 58,3750us, log0 zbytek 5,6667us (= 176kHz)  - log 0 vyvolána pos edge HOut1
reg [17:0] HPulse;

always @(negedge Hcnt_out1 or posedge clk_50M)
begin
	if (~Hcnt_out1)
	begin
		HPulse <= 50_000_000 / 176_469;
		HSync <= 1'b0;
	end
	else if (HPulse == 18'h0)
		HSync <= 1'b1;
	else
		HPulse <= HPulse - 18'd1;
end


// generator VSync D35B, R58, C39
// perioda 19.9757083ms = 50Hz, log1 19.8383333ms, log0 0,137375ms = 137.375us (= 7.3kHz) 
// log 0 vyvolana pos edge V OUT 1
reg [17:0] VPulse;

always @(negedge Vcnt_out1 or posedge clk_50M)
begin
	if (~Vcnt_out1)
	begin
		VPulse <= 50_000_000 / 7_279;
		VSync <= 1'b0;
	end
	else if (VPulse == 18'h0)
		VSync <= 1'b1;
	else
		VPulse <= VPulse - 18'd1;
end
	
	
//---------------------------------- KEYBOARD + JOY + SERIAL & PARALLEL PORT ---------------------------------------------	
//
//


(* keep *) wire BUSY;
reg NON_STB;
// wire RESERVA_IN;  //rxd
// reg RESERVA_OUT; // txd
reg [2:0] SND;
// wire MGF_IN; // magneťák vstup dat do Ondry


//---------------------  Joystick ---------------------------------
// 							    Trigger, Down,   Up,      Left,    Right
wire [4:0] row_Joystick = { ~joy[4], ~joy[2], ~joy[3], ~joy[1], ~joy[0] };
wire clk_LED_SND_RELE = (io_wr_n | A[0]); // portA0
wire [4:0] row_KJ = (A[3:0] == 4'b1001) ? row_Joystick : row_Keyboard;

 
//--------------------- keyboard  ---------------------------------
wire [4:0] row_Keyboard;
 
keyboard keyboard (
	.reset(reset), 
	.clk(clk_sys), 
	.ps2_key(ps2_key), 
	.row(row_Keyboard), 
	.column(A[3:0])
);


//--------------------- parallel data out -------------------------
wire clk_Parallel_port = (io_wr_n | A[1]); // port A1
reg [7:0] Parallel_Data_OUT;
always @(posedge clk_Parallel_port)
	Parallel_Data_OUT <= DOut;

// LEDs + NON_STB + RESERVA_OUT (txd) + SND + RELAY
always @(posedge clk_LED_SND_RELE or posedge reset)
begin
	if (reset)
	begin
		LED_GREEN <= 0;  
		LED_YELLOW <= 0;
		RESERVA_OUT <= 0;
		NON_STB <= 0;
		RELAY <= 0;  
		SND <= 3'b000;	
	end
	else begin
		LED_GREEN <= DOut[0];		
		LED_YELLOW <= DOut[1];
		RESERVA_OUT <= DOut[2];
		NON_STB <= DOut[3];
		RELAY <= DOut[4];
		SND <= DOut[7:5];	
	end
end
   

	
//--------------------- Sound ---------------------------------------
wire freq_384;		// 384.3567 Hz
wire freq_606;		// 606.2353 Hz
wire freq_827;		// 826.617 Hz
wire freq_1_366;	// 1.365654 kHz
wire freq_1_508;	// 1.508296 kHz
wire freq_1_615;	// 1.614857 kHz
wire freq_1_753; 	// 1.752848 kHz

SoundFreq #(.FREQ(18'd384))  Sfreq_384   (.clk_50M(clk_50M), .soundOff(soundOff), .freq(freq_384));
SoundFreq #(.FREQ(18'd606))  Sfreq_606   (.clk_50M(clk_50M), .soundOff(soundOff), .freq(freq_606));
SoundFreq #(.FREQ(18'd827))  Sfreq_827   (.clk_50M(clk_50M), .soundOff(soundOff), .freq(freq_827));
SoundFreq #(.FREQ(18'd1366)) Sfreq_1_366 (.clk_50M(clk_50M), .soundOff(soundOff), .freq(freq_1_366));
SoundFreq #(.FREQ(18'd1508)) Sfreq_1_508 (.clk_50M(clk_50M), .soundOff(soundOff), .freq(freq_1_508));
SoundFreq #(.FREQ(18'd1615)) Sfreq_1_615 (.clk_50M(clk_50M), .soundOff(soundOff), .freq(freq_1_615));
SoundFreq #(.FREQ(18'd1753)) Sfreq_1_753 (.clk_50M(clk_50M), .soundOff(soundOff), .freq(freq_1_753));

wire soundOff = (SND == 3'b000);
assign beeper = (SND == 3'b000) ? 1'b0 :
					 (SND == 3'b001) ? freq_384 :
					 (SND == 3'b010) ? freq_606 :
					 (SND == 3'b011) ? freq_827 :
					 (SND == 3'b100) ? freq_1_366 :
					 (SND == 3'b101) ? freq_1_508 :
					 (SND == 3'b110) ? freq_1_615 :
					 (SND == 3'b111) ? freq_1_753 : 1'b0;


 
//-------------------------------------- EPROM ----------------------------------------------------------------------
// 2x2764 (2x8kb) or 2x2716 (2x2kb)


// if 2x2716 EPROM chip used
wire [12:0] EPROM_Addr = { 1'b0, ROM1_en, A[10:0] };

// if 2x2764 EPROM chip used
//wire [12:0] EPROM_Addr = { ROM1_en, A[11:0] };


wire [7:0] data_EPROM0_out;
wire [7:0] data_EPROM1_out;
wire [7:0] data_EPROM2_out;
wire [7:0] data_EPROM_out = ROMVersion == 2'b00 ? data_EPROM0_out : 
                            ROMVersion == 2'b01 ? data_EPROM1_out : 
                            ROMVersion == 2'b10 ? data_EPROM2_out : data_EPROM0_out;
 
dpram #(.ADDRWIDTH(13), .MEM_INIT_FILE("./ROM/OndraViLi_v27.mif")) myEPPROM0
(
	.clock(clk_sys),
	.address_a(EPROM_Addr),	
	.wren_a(0),
	.q_a(data_EPROM0_out)
);


dpram #(.ADDRWIDTH(13), .MEM_INIT_FILE("./ROM/Ondra_TESLA_V5.mif")) myEPPROM1
(
	.clock(clk_sys),
	.address_a(EPROM_Addr),	
	.wren_a(0),
	.q_a(data_EPROM1_out)
);


dpram #(.ADDRWIDTH(13), .MEM_INIT_FILE("./ROM/Ondra_test.mif")) myEPPROM2
(
	.clock(clk_sys),
	.address_a(EPROM_Addr),	
	.wren_a(0),
	.q_a(data_EPROM2_out)
);


		
//-------------------------------------- RAM ----------------------------------------------------------------------
// 64kb

wire [7:0] data_RAM_out;
wire [7:0] data_VRAM_out;
wire [15:0] RAM_Addr = { A_RAM_HI, A[13:0] };

dpram #(.ADDRWIDTH(16)) myRam
(
	.clock(clk_sys),
	.address_a(RAM_Addr),
	.data_a(DOut),
	.wren_a(RAM_en & ~mem_wr_n), 
	.q_a(data_RAM_out),	

	
	.address_b({2'b11, A_VideoRAM[13:0]}),	
	.wren_b(0),
	.q_b(data_VRAM_out)
);

// VideoRAM organization
// ---------------------------
// FFFF FEFF FDFF   ...   D8FF     // 0xFF - 0xD8 = 0x27 = 39 ..... 39 * 8 = 312 pixels per row
// FF7F FE7F FD7F   ...   D87F
// FFFE FEFE FDFE   ...   D8FE
//  ...
//  ...
// FF02 FE02 FD02   ...   D802
// FF81 FE81 FD81   ...   D881
// FF01 FE01 FD01   ...   D801
// FF80 FE80 FD80   ...   D880

	
endmodule // Ondra_SPO186_core