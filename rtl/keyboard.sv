
// Keyboard for Ondra SPO 186


module keyboard (
		input        reset,
		input        clk,
	
		input [10:0] ps2_key,			
		input  [3:0] column,
		output [4:0] row,      
		output kbd_nmi,
		output reg kbd_hardreset
);
	
wire pressed = ps2_key[9];
wire input_strobe = ps2_key[10];
wire extended = ps2_key[8];
wire [7:0] code = ps2_key[7:0];	
reg [4:0]keys[14:0];
wire shift;
reg shiftL;
reg shiftR;
reg shiftExtra; // used when I need use shift to map extra PC key
assign shift = shiftExtra & (shiftL & shiftR);
 
reg ctrlR;
reg ctrlL;
wire ctrl;

assign ctrl = ctrlR & ctrlL;

reg altR;
reg altL;
wire alt;

assign alt = altR & altL;
 

assign row = { keys[column][0],
					keys[column][2],
					keys[column][4],
					keys[column][1],
					keys[column][3] };
	

reg old_stb;
reg old_reset = 0;
reg [8:0] kbd_nmi_clk = 8'h00;

assign kbd_nmi = (kbd_nmi_clk == 8'h00);

initial begin   
   kbd_hardreset <= 1;
end

always @(posedge clk) 
begin
	    
	old_stb <= input_strobe;
	old_reset <= reset;
	
   if (~(kbd_nmi_clk == 8'h00))
      kbd_nmi_clk <= kbd_nmi_clk - 8'd1;
      
	if(~old_reset & reset)
	begin
		keys[00] <= 5'b11111;
		keys[01] <= 5'b11111;
		keys[02] <= 5'b11111;
		keys[03] <= 5'b11111;
		keys[04] <= 5'b11111;
		keys[05] <= 5'b11111;
		keys[06] <= 5'b11111;
		keys[07] <= 5'b11111;
		keys[08] <= 5'b11111;
		keys[09] <= 5'b11111;
		keys[10] <= 5'b11111;
		keys[11] <= 5'b11111;
		keys[12] <= 5'b11111;
		keys[13] <= 5'b11111;
		keys[14] <= 5'b11111;
		
		shiftL <= 1;
		shiftR <= 1;
		shiftExtra <= 1;
		ctrlR <= 1;
		ctrlL <= 1;
		altR <= 1;
		altL <= 1;
		kbd_nmi_clk <= 8'h00;
		kbd_hardreset <= 1;
      kbd_nmi_clk <= 8'hFF;
	end
		
	keys[02][0] <= alt; // (key 31) CHARS-SPECIAL CHARS TOGGLE
	keys[07][0] <= ctrl; // (key 30) CTRL
	keys[04][0] <= shift;
		
		
	if(old_stb != input_strobe) 
	begin		
		if (extended) 
		begin
			/* Extended keys */
			case(code)
//				8'h7d : keys[05][0] <= ~pressed; // (R)CL = PageUp (E07D)
//				8'h70 : keys[12][1] <= ~pressed; // INS (e070)	
//				8'h7a : keys[14][1] <= ~pressed; // CLR = PageDown (E07A)		
				
				8'h6b : keys[08][1] <= ~pressed; // (key 34) <--- = ARROW_LEFT
				8'h74 : keys[08][0] <= ~pressed; // (key 36) ---> = ARROW_RIGHT
				8'h75 : keys[07][4] <= ~pressed; // (key 29) ARROW_UP
				8'h72 : keys[08][4] <= ~pressed; // (key 35) ARROW_DOWN		
				
							
				8'h5a : keys[05][0] <= ~pressed; // (key 20) ENTER NUMPAD	


						
				//8'h76 : stop <= ~pressed; //  STOP = ESC		
				//8'h58 : if (~pressed) capsLock <= ~capsLock ; //  toggle Caps Lock
						
				8'h14 : ctrlR <= ~pressed; // Ctrl (right)
				8'h11 : altR <= ~pressed;  // Alt (right)	


				8'h71 : if (~(ctrl | alt) | ~kbd_nmi) // CTRL + ALT + Delete
					kbd_nmi_clk <= 8'h0F;
			endcase	
		end
		else
		begin

			case(code)       
				8'h14 : ctrlL <= ~pressed; // Ctrl (left)
				8'h11 : altL <= ~pressed;  // Alt (left)	
								
				8'h66 : if (~(ctrl | alt) | ~kbd_hardreset) // CTRL + ALT + Backspace
					kbd_hardreset <= ~pressed;	
					
				// column 0 = pin 1
				8'h15 : keys[00][0] <= ~pressed; // (key 01) Q 1 !
				8'h24 : keys[00][1] <= ~pressed; // (key 03) E 3 #
				8'h2c : keys[00][2] <= ~pressed; // (key 05) T 5 %				
				8'h2d : keys[00][3] <= ~pressed; // (key 04) R 4 $
				8'h1d : keys[00][4] <= ~pressed; // (key 02) W 2 "

				// column 1 = pin 2
				8'h1c : keys[01][0] <= ~pressed; // (key 11) A -
				8'h23 : keys[01][1] <= ~pressed; // (key 13) D =
				8'h34 : keys[01][2] <= ~pressed; // (key 15) G _	
				8'h2b : keys[01][3] <= ~pressed; // (key 14) F arrow up character
				8'h1b : keys[01][4] <= ~pressed; // (key 12) S +

				// column 2 = pin 3
			//xxxxx	8'h00 : keys[02][0] <= ~pressed; // (key 21) SHIFT
			
				8'h59: shiftR <= ~pressed; // right shift
				8'h12: shiftL <= ~pressed; // Left shift	
				8'h22 : keys[02][1] <= ~pressed; // (key 23) X /
				8'h2a : keys[02][2] <= ~pressed; // (key 25) V ;
				8'h21 : keys[02][3] <= ~pressed; // (key 24) C :
				8'h1a : keys[02][4] <= ~pressed; // (key 22) Z *

				// column 3 = pin 4
				8'h29 : keys[03][3] <= ~pressed; // (key 37) SPACE
				
				// column 4 = pin 5
				// 8'h00 : keys[04][0] <= ~pressed; // (key 31) SHIFT 
				8'h0D : keys[04][1] <= ~pressed; // (key 33) TAB = CHARS-NUMBERS TOGGLE (0-9)
				8'h58 : keys[04][4] <= ~pressed; // (key 32) Caps Lock = Czech diacritic chars-ASCII TOGGLE (ČS)

				// column 5 = pin 11
				// 8'h00 : keys[05][0] <= ~pressed; // (key 36) ARROW_RIGHT
				// 8'h00 : keys[05][1] <= ~pressed; // (key 34) ARROW_LEFT
				// 8'h00 : keys[05][4] <= ~pressed; // (key 35) ARROW_DOWN
			endcase
			
			case(code)       				
				// column 6 = pin 12
				// SPACE
														
				// column 7 = pin 13
				// 8'h00 : keys[07][0] <= ~pressed; // (key 30) CTRL
				8'h3a : keys[07][1] <= ~pressed; // (key 28) M .
				8'h32 : keys[07][2] <= ~pressed; // (key 26) B ? 	
				8'h31 : keys[07][3] <= ~pressed; // (key 27) N ,
				// 8'h00 : keys[07][4] <= ~pressed; // (key 29) ARROW_UP
				
				// column 8 = pin 14
				8'h5a : keys[05][0] <= ~pressed; // (key 20) ENTER
				8'h42 : keys[05][1] <= ~pressed; // (key 18) K [
				8'h33 : keys[05][2] <= ~pressed; // (key 16) H <	
				8'h3b : keys[05][3] <= ~pressed; // (key 17) J >
				8'h4b : keys[05][4] <= ~pressed; // (key 19) L ]
				
				// column 9 = pin 15
				8'h4d : keys[06][0] <= ~pressed; // (key 10) P 0 @
				8'h43 : keys[06][1] <= ~pressed; // (key 08) I 8 (
				8'h35 : keys[06][2] <= ~pressed; // (key 06) Y 6 &	
				8'h3c : keys[06][3] <= ~pressed; // (key 07) U 7 '
				8'h44 : keys[06][4] <= ~pressed; // (key 09) O 9 ) 
			endcase
	
		end
	end	
end 
 
 
 
			
endmodule //keyboard			