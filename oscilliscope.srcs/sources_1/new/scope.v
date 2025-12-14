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
	input enc_a,
	input enc_b,
	input enc_sw,

    output LCD_cs,
    output LCD_rst,
    output LCD_dcx,	//1 => data/cmd params, 0 => cmd
    output LCD_wrx,
    output [15:0] LCD_data,

	output ADC_cs,
	output ADC_clk,
	input ADC_dout,
	output ADC_din
    );
	localparam COLS = 9'd480;	//these params are duplicates between modules because global modules doesn't work :/
	localparam ROWS = 9'd160;
	localparam PIXEL_COUNT = 19'd230400;	//COLS*ROWS*3/2?

	//clocks
	reg [11:0] clk;
	initial clk = 0;
	always @(posedge sysclk) begin
		clk <= clk+1;
	end
	wire enc_clk, lcd_clk, adc_clk;
	assign enc_clk = clk[11];
	assign lcd_clk = clk[3];
	assign adc_clk = clk[4];

	//inter-module signals
	wire [8:0] x;
	wire [7:0] adc_data1, adc_data2;
	reg [7:0] adc_data1_buff1, adc_data1_buff2, adc_data2_buff1, adc_data2_buff2;
	initial adc_data1_buff2 = 0;
	always @(posedge enc_clk) begin
		adc_data1_buff1 <= adc_data1;
		adc_data1_buff2 <= adc_data1_buff1;
		adc_data2_buff1 <= adc_data2;
		adc_data2_buff2 <= adc_data2_buff1;
	end

	//encoder debouncing
	reg [7:0] pos1, pos2;
	reg channel;
	reg enc_a_buff1, enc_a_buff2, enc_b_buff1, enc_b_buff2, enc_sw_buff1, enc_sw_buff2;
	wire a, b, sw;
	initial pos1 = 8'd1;
	initial pos2 = 8'd1;
	initial channel = 1'b1;
	always @(posedge enc_clk) begin
		enc_a_buff1 <= enc_a;
		enc_a_buff2 <= enc_a_buff1;
		enc_b_buff1 <= enc_b;
		enc_b_buff2 <= enc_b_buff1;
		enc_sw_buff1 <= enc_sw;
		enc_sw_buff2 <= enc_sw_buff1;
	end
	assign a = enc_a_buff1 && enc_a_buff2;
	assign b = enc_b_buff1 && enc_b_buff2;
	assign sw = !enc_sw_buff1 && enc_sw_buff2;

	//encoder increments y offset
	always @(posedge b) begin
		if (channel)
			if (a)
				pos1 <= (pos1-1) % ROWS;
			else
				pos1 <= (pos1+1) % ROWS;
		else
			if (a)
				pos2 <= (pos2-1) % ROWS;
			else
				pos2 <= (pos2+1) % ROWS;
	end
	always @(posedge sw) begin
		channel <= !channel;
	end

	//Async FIFO for CDC
	/*
	fifo_generator_0 fifo ( .rst(),
							.wr_clk(),
							.rd_clk(),
							.din(),
							.dout(),
							.wr_en(),
							.rd_en()
	);
	*/

	adc_0832ccn adc (.sysclk(adc_clk),
					 .clk(ADC_clk),
					 .cs(ADC_cs),
					 .din(ADC_din),
					 .dout(ADC_dout),
					 .data1(adc_data1),
					 .data2(adc_data2)
	);

	wire [7:0] sum_data1, sum_data2;
	assign sum_data1 = adc_data1_buff2 + pos1;
	assign sum_data2 = adc_data2_buff2 + pos2;
	lcd_screen lcd (.clk(lcd_clk),
					.reset(reset),
					.cs(LCD_cs),
					.rst(LCD_rst),
					.dcx(LCD_dcx),
					.wrx(LCD_wrx),
					.Data(LCD_data),
					.x(x),
					.adc_data1(sum_data1),
					.adc_data2(sum_data2),
					.channel(channel)
	);

endmodule

module adc_0832ccn(
	input sysclk,
	output clk,
	output cs,	//active low
	output din,
	input dout,

	//internal connections
	output reg [7:0] data1,
	output reg [7:0] data2
	);

	localparam IDLE = 2'd0;
	localparam START = 2'd1;
	localparam READ = 2'd2;
	localparam RESET = 2'd3;

	reg [1:0] state, next_state;
	reg [2:0] state_counter;
	initial state = IDLE;
	initial state_counter = 3'b0;

	always @(posedge sysclk) begin
		state <= next_state;

		if (state == next_state)
			state_counter = state_counter+1;
		else
			state_counter = 0;
	end

	//state transition logic
	always @(*) begin
		case (state)
			IDLE:
				next_state = START;
			START:
				next_state = state_counter < 4-1 ? START : READ;	//3 bits plus one waiting cycle
			READ:
				next_state = state_counter < 8-1 ? READ : RESET;
			RESET:
				next_state = state_counter < 1-1 ? RESET : IDLE;
		endcase
	end

	reg mux;
	initial mux = 1'b0;
	wire [3:0] cmd_start = {1'b0, mux, 1'b1, 1'b1};	//dummy bit, mux address, single-ended mode, start bit

	assign cs = state == IDLE;
	assign clk = state != IDLE ? !sysclk : 1'b0;
	assign din = state == START ? cmd_start[state_counter] : 1'b0;

	//sequential logic for storing bits
	reg [7:0] data_buff1, data_buff2;
	always @(posedge clk) begin
		if (state == READ) begin
			if (mux)
				data_buff1[7-state_counter] <= dout;
			else
				data_buff2[7-state_counter] <= dout;
		end

		if (state == RESET) begin
			if (mux)
				data1 <= data_buff1;
			else
				data2 <= data_buff2;

			mux <= !mux;
		end
	end

endmodule

module lcd_screen(
	input clk,
	input reset,

    output reg cs,
    output rst,
    output reg dcx,	//1 => data/cmd params, 0 => cmd
    output reg wrx,
    output reg [15:0] Data,

	output [8:0] x,
	input [7:0] adc_data1,
	input [7:0] adc_data2,
	input channel
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
	//localparam CMD_MADCTL = {16'h48, 16'h36};	//RGB order
	localparam CMD_MADCTL = {16'h20, 16'h36};	//RGB order
	localparam CMD_DISPON = 16'h29;
	localparam CMD_SETCOL = {16'hdf, 16'h1, 16'h0, 16'h0, 16'h2a};	//0-479
	localparam CMD_SETROW = {16'h3f, 16'h1, 16'h0, 16'h0, 16'h2b};	//0-319
	localparam CMD_MEMWRITE = 16'h2c;

	localparam COLS = 9'd480;
	localparam ROWS = 9'd160;
	localparam PIXEL_COUNT = 19'd230400;	//COLS*ROWS*3/2?


	//mealy fsm state register
	reg [3:0] state;
	reg [3:0] next_state;
	reg [20:0] state_counter;	//1 counter to rule them all
	reg [18:0] data_cursor;
	reg [8:0] dummy_data;
	initial begin
		state = BOOT;
		next_state = BOOT;
		state_counter = 21'b0;
		data_cursor = 19'b0;
		dummy_data = 9'b0;
	end

	//define x and y
	wire [8:0] y;
	assign x = (data_cursor/3) / ROWS;
	assign y = (data_cursor/3) % ROWS;
	wire red, green, blue;
	assign green = data_cursor % 3 == 0;
	assign blue = data_cursor % 3 == 1;
	assign red = data_cursor % 3 == 2;


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

		//increment dummy data register
		if (state == NOP)
			dummy_data <= (dummy_data+1) % ROWS;
		else if (state == RESET)
			dummy_data <= 9'd0;
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
				begin
					if (y == {adc_data1, 1'b0})
						Data = red ? 16'h00f0 : 16'h0;
					else if (y == {adc_data2, 1'b0})
						Data = green ? 16'h00f0 : 16'h0;
					else if (x%20 == 0)
						Data = blue ? 16'h00f0 : 16'h0;
					else if (y%10 == 0)
						Data = blue ? 16'h00f0 : 16'h0;
					else
						Data = 16'h0;
				end
			NOP:
				Data = CMD_NOP;
			default:
				Data = CMD_NOP;
		endcase
	end

endmodule
