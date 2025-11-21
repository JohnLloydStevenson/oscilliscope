module tb;
reg sysclk;
reg reset;

	wire CS;
	wire RST;
	wire DCX;
	wire WRX;
	wire [15:0] Data;

	// instantiate your DUT
	scope my_scope (
			.sysclk(sysclk),
			.reset(reset),
			.LCD_cs(CS),
			.LCD_rst(RST),
			.LCD_dcx(DCX),
			.LCD_wrx(WRX),
			.LCD_data(Data)
			);

	// Clock generator (for reference)
	initial sysclk = 0;
	always #40 sysclk = ~sysclk;  // 50/4 MHz clock (period = 80 ns)

	// Stimulus: pulse wr high briefly
	initial begin
		#50;               // wait 50 ns
		reset = 1;
		#50;               // stay high for 50 ns
		reset = 0;
		// stay low forever
	end

	//wire [3:0] state;
	//assign state = tb.my_scope.lcd.state;

	//wire [20:0] counter;
	//assign counter = tb.my_scope.lcd.data_cursor;

	//wire clk;
	//assign clk = tb.my_scope.lcd_clk;

	//wire [8:0] x,y;
	//assign x = tb.my_scope.lcd.x;
	//assign y = tb.my_scope.lcd.y;


	wire clk, cs, dout, din, data;
	adc_0832ccn adc (.sysclk(sysclk),
					 .clk(clk),
					 .cs(cs),
					 .din(din),
					 .dout(dout),
					 .data(data)
			);

	wire [1:0] state;
	wire [2:0] state_counter;
	assign state = tb.adc.state;
	assign state_counter = tb.adc.state_counter;

	wire adc_clk;
	assign adc_clk = tb.my_scope.adc_clk;
endmodule

