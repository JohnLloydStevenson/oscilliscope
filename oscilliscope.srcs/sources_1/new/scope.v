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

    output LCD_cs,
    output LCD_rst,
    output LCD_dcx,	//1 => data/cmd params, 0 => cmd
    output LCD_wrx,
    output [15:0] LCD_data,

	output ADC_cs,
	output ADC_clk,
	input ADC_do,
	output ADC_di
    );
	//clocks
	reg [8:0] clk;
	initial clk = 0;
	always @(posedge sysclk) begin
		clk <= clk+1;
	end
	wire lcd_clk;
	assign lcd_clk = clk[3];

	//inter-module signals
	wire [8:0] x;

	lcd_screen lcd (.clk(lcd_clk),
					.reset(reset),
					.cs(LCD_cs),
					.rst(LCD_rst),
					.dcx(LCD_dcx),
					.wrx(LCD_wrx),
					.Data(LCD_data),
					.x(x)
	);

endmodule

module adc_0832ccn(
	output clk,
	output cs,
	output DI,
	input do,

	//internal connections
	input [8:0] x,
	output [7:0] data
	);
endmodule

module lcd_screen(
	input clk,
	input reset,

    output reg cs,
    output rst,
    output reg dcx,	//1 => data/cmd params, 0 => cmd
    output reg wrx,
    output reg [15:0] Data,

	output [8:0] x
	//input [7:0] adc_data
    );
	//local parameters
	localparam BOOT = 0;
	localparam IDLE = 1;
	localparam SWRESET = 2;
	localparam SLPOUT = 3;
	localparam COLMOD = 4;
	localparam MADCTL = 5;
	localparam DISPON = 6;
	localparam SETCOL = 7;
	localparam SETROW = 8;
	localparam CMD = 9;
	localparam DATA = 10;
	localparam NOP = 11;
	localparam RESET = 12;

	localparam CMD_NOP = 16'h00;
	localparam CMD_SWRESET = 16'h01;
	localparam CMD_SLPOUT = 16'h11;
	localparam CMD_COLMOD = {16'h55, 16'h3a};	//16-bit RGB565
	localparam CMD_MADCTL = {16'h48, 16'h36};	//RGB order
	localparam CMD_DISPON = 16'h29;
	localparam CMD_SETCOL = {16'hdf, 16'h1, 16'h0, 16'h0, 16'h2a};	//0-480
	localparam CMD_SETROW = {16'h3f, 16'h1, 16'h0, 16'h0, 16'h2b};	//0-320
	localparam CMD_MEMWRITE = 16'h2c;

	localparam PIXEL_COUNT = 480*320;


	//mealy msf state register
	reg [3:0] state;
	reg [3:0] next_state;
	reg [20:0] state_counter;	//1 counter to rule them all
	reg [18:0] data_cursor;
	reg [7:0] adc_data;
	initial begin
		state = BOOT;
		next_state = BOOT;
		state_counter = 21'b0;
		data_cursor = 19'b0;
		adc_data = 8'b0;
	end

	//define x and y
	wire [8:0] y;
	assign x = (data_cursor/3) / 9'd320;
	assign y = (data_cursor) % 9'd320;


	//msf sequential block
	always @(posedge clk) begin
		if (reset)
			state <= RESET;
		else
			state <= next_state;	//update state

		//substate counters
		if (state == next_state)
			state_counter <= state_counter + 1;	//count how long we've been on this step
		else
			state_counter <= 0;

		//scan through the lcd data
		if (state == DATA)
			data_cursor <= data_cursor + 1;
		else
			data_cursor <= 16'b0;

		//increment dummy ADC data
		if (state == IDLE)
			adc_data <= adc_data - 1;
	end

	//msf combinational block
	always @(*) begin
		case (state)
			BOOT:
				if (state_counter == {17{1'b1}})
					next_state = SWRESET;
				else
					next_state = BOOT;
			SWRESET:
				if (state_counter == {14{1'b1}})
					next_state = SLPOUT;
				else
					next_state = SWRESET;
			SLPOUT:
				if (state_counter == {17{1'b1}})
					next_state = COLMOD;
				else
					next_state = SLPOUT;
			COLMOD:
				if (state_counter == 1)
					next_state = MADCTL;
				else
					next_state = COLMOD;
			MADCTL:
				if (state_counter == 1)
					next_state = DISPON;
				else
					next_state = MADCTL;
			DISPON:
				if (state_counter == {14{1'b1}})
					next_state = SETCOL;
				else
					next_state = DISPON;
			SETCOL:
				if (state_counter == 4)
					next_state = SETROW;
				else
					next_state = SETCOL;
			SETROW:
				if (state_counter == 4)
					next_state = IDLE;
				else
					next_state = SETROW;
			IDLE:
				next_state = CMD;
			CMD:
				next_state = DATA;
			DATA:
				if (state_counter < PIXEL_COUNT-1)
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


	//lcd signals
	always @(*) begin
		case (state)
			SWRESET:
				cs = state_counter < 2 ? 0 : 1;
			SLPOUT:
				cs = state_counter < 2 ? 0 : 1;
			COLMOD:
				cs = 0;
			MADCTL:
				cs = 0;
			DISPON:
				cs = state_counter < 2 ? 0 : 1;
			SETCOL:
				cs = 0;
			SETROW:
				cs = 0;
			CMD:
				cs = 0;
			DATA:
				cs = 0;
			default:
				cs = 1;
		endcase
	end

	always @(*) begin
		case (state)
			SWRESET:
				dcx = 0;
			SLPOUT:
				dcx = 0;
			COLMOD:
				dcx = 0;
			MADCTL:
				dcx = 0;
			DISPON:
				dcx = 0;
			SETCOL:
				dcx = 0;
			SETROW:
				dcx = 0;
			CMD:
				dcx = 0;
			NOP:
				dcx = 0;
			default:
				dcx = 1;
		endcase
	end

	always @(*) begin
		case (state)
			SWRESET:
				wrx = state_counter < 1 ? !clk : 1;
			SLPOUT:
				wrx = state_counter < 1 ? !clk : 1;
			COLMOD:
				wrx = !clk;
			MADCTL:
				wrx = !clk;
			DISPON:
				wrx = state_counter < 1 ? !clk : 1;
			SETCOL:
				wrx = !clk;
			SETROW:
				wrx = !clk;
			CMD:
				wrx = !clk;
			DATA:
				wrx = !clk;
			NOP:
				wrx = !clk;
			default:
				wrx = 1;
		endcase
	end

	assign rst = !(state == BOOT && state_counter < 19'b100000000000000);

	always @(*) begin
		case (state)
			SWRESET:
				Data = CMD_SWRESET;
			SLPOUT:
				Data = CMD_SLPOUT;
			COLMOD:
				Data = CMD_COLMOD[16*state_counter[1:0] +: 16];
			MADCTL:
				Data = CMD_MADCTL[16*state_counter[1:0] +: 16];
			DISPON:
				Data = CMD_DISPON;
			SETCOL:
				Data = CMD_SETCOL[16*state_counter[1:0] +: 16];
			SETROW:
				Data = CMD_SETROW[16*state_counter[1:0] +: 16];
			CMD:
				Data = CMD_MEMWRITE;
			DATA:
				Data = x < adc_data ? 16'hff : 16'b0;
			NOP:
				Data = CMD_NOP;
			default:
				Data = CMD_NOP;
		endcase
	end

endmodule
