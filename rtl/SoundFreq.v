
module SoundFreq #(parameter [17:0] FREQ)
(
	input clk_50M,
	input soundOff,	
	output reg freq 
);

reg [17:0] freqCounter;
			
always @(posedge soundOff or posedge clk_50M)
begin
	if (soundOff)
		freq <= 1'b0;
	else 
	begin
		if (freqCounter == 18'd1)
			freq <= 1'b1;
		if (freqCounter == 18'd10_638) // 0.212500 ms
			freq <= 1'b0;
		if (freqCounter == 50_000_000 / FREQ)
		begin
			freqCounter <= 18'd0;
			freq <= 1'b0;
		end
		else
			freqCounter <= freqCounter + 18'd1;
	end
end			
			
			
endmodule // SoundFreq			