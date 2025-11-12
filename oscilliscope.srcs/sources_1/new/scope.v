`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/10/2025 10:49:46 PM
// Design Name: 
// Module Name: scope
// Project Name: 
	// Target Devices: 
	// Tool Versions: 
	// Description: 
	// 
	// Dependencies: 
	// 
	// Revision:
	// Revision 0.01 - File Created
	// Additional Comments:
	// 
	//////////////////////////////////////////////////////////////////////////////////

module scope(
	input sysclk,
	input reset,

    output reg LCD_CS,
    output LCD_RST,
    output reg LCD_DCX,	//1 => data/cmd params, 0 => cmd
    output LCD_WRX,
    output reg [15:0] LCD_Data
    );
	//local parameters
	localparam BOOT = 0;
	localparam IDLE = 1;
	localparam SWRESET = 2;
	localparam SLPOUT = 3;
	localparam CMD = 4;
	localparam DATA = 5;
	localparam NOP = 6;
	localparam RESET = 7;

	localparam CMD_NOP = 16'h0000;
	localparam CMD_SWRESET = 16'h0001;
	localparam CMD_SLPOUT = 16'h0011;
	localparam CMD_MEMWRITE = 16'h002c;

	//clocks
	reg [8:0] clk;
	initial clk = 0;
	always @(posedge sysclk) begin
		clk <= clk+1;
	end
	wire lcd_clk;
	assign lcd_clk = clk[6];

	//mealy msf state register
	reg [3:0] state;
	reg [3:0] next_state;
	reg [5:0] boot_counter;
	reg [5:0] swreset_counter;
	reg [5:0] slpout_counter;
	reg [17:0] data_counter;
	initial begin
		state = BOOT;
		next_state = BOOT;
		boot_counter = 6'b0;
		swreset_counter = 6'b0;
		slpout_counter = 6'b0;
		data_counter = 18'b0;
	end

	//msf sequential block
	always @(posedge lcd_clk) begin
		if (reset)
			state <= RESET;
		else
			state <= next_state;
	end

	//msf combinational block
	always @(*) begin
		case (state)
			BOOT:
				if (boot_counter == {6{1'b1}})
					next_state = SWRESET;
				else
					next_state = BOOT;
			SWRESET:
				if (swreset_counter == {6{1'b1}})
					next_state = SLPOUT;
				else
					next_state = SWRESET;
			SLPOUT:
				if (slpout_counter == {6{1'b1}})
					next_state = IDLE;
				else
					next_state = SLPOUT;
			IDLE:
				next_state = CMD;
			CMD:
				next_state = DATA;
			DATA:
				if (data_counter < 480*320)
					next_state = DATA;
				else
					next_state = NOP;
			NOP:
				next_state = IDLE;
			RESET:
				next_state = SWRESET;
			default:
				next_state = IDLE;
		endcase
	end

	//substate counters
	always @(posedge lcd_clk) begin
		if (state == BOOT)
			boot_counter <= boot_counter + 1;
	end

	always @(posedge lcd_clk) begin
		if (state == DATA)
			data_counter <= data_counter + 1;
		else
			data_counter <= 0;
	end

	always @(posedge lcd_clk) begin
		if (state == SWRESET)
			swreset_counter <= swreset_counter + 1;
		else
			swreset_counter <= 0;
	end

	always @(posedge lcd_clk) begin
		if (state == SLPOUT)
			slpout_counter <= slpout_counter + 1;
		else
			slpout_counter <= 0;
	end

	//lcd signals
	always @(*) begin
		case (state)
			BOOT:
				LCD_CS = 1;
			IDLE:
				LCD_CS = 1;
			SWRESET:
				LCD_CS = 1;
			default:
				LCD_CS = 0;
		endcase
	end
	always @(*) begin
		case (state)
			SWRESET:
				LCD_DCX = 0;
			SLPOUT:
				LCD_DCX = 0;
			CMD:
				LCD_DCX = 0;
			NOP:
				LCD_DCX = 0;
			default:
				LCD_DCX = 1;
		endcase
	end
	assign LCD_WRX = !LCD_CS && !lcd_clk;
	assign LCD_RST = !(state == BOOT && boot_counter < 6'b010000);

	always @(*) begin
		case (state)
			SWRESET:
				LCD_Data = CMD_SWRESET;
			SLPOUT:
				LCD_Data = CMD_SLPOUT;
			CMD:
				LCD_Data = CMD_MEMWRITE;
			DATA:
				LCD_Data = data_counter[17:1];
			NOP:
				LCD_Data = CMD_NOP;
			default:
				LCD_Data = CMD_NOP;
		endcase
	end

endmodule
