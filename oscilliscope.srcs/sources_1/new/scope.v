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
    output reg LCD_WRX,
    output reg [15:0] LCD_Data
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
	localparam CMD_COLMOD = 16'h3a;
	localparam CMD_MADCTL = 16'h36;
	localparam CMD_DISPON = 16'h29;
	localparam CMD_SETCOL = 16'h2a;
	localparam CMD_SETROW = 16'h2b;
	localparam CMD_MEMWRITE = 16'h2c;

	localparam DATA_COLMOD = 16'h55;	//16-bit RGB565
	localparam DATA_MADCTL = 16'h48;	//for RGB order
	localparam [63:0] DATA_SETCOL = {16'h0, 16'h0, 16'h1, 16'he0};	//0-480
	localparam [63:0] DATA_SETROW = {16'h0, 16'h0, 16'h1, 16'h40};	//0-320

	localparam PIXEL_COUNT = 480*320;


	//clocks
	reg [8:0] clk;
	initial clk = 0;
	always @(posedge sysclk) begin
		clk <= clk+1;
	end
	wire lcd_clk;
	assign lcd_clk = clk[3];


	//mealy msf state register
	reg [3:0] state;
	reg [3:0] next_state;
	reg [18:0] boot_counter;
	reg [15:0] swreset_counter;
	reg [18:0] slpout_counter;
	reg [15:0] dispon_counter;
	reg [17:0] data_counter;
	reg [20:0] state_counter;	//1 counter to rule them all
	initial begin
		state = BOOT;
		next_state = BOOT;
		boot_counter = 19'b0;
		swreset_counter = 16'b0;
		slpout_counter = 19'b0;
		data_counter = 18'b0;
		state_counter = 21'b0;
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
				if (boot_counter == {17{1'b1}})
					next_state = SWRESET;
				else
					next_state = BOOT;
			SWRESET:
				if (swreset_counter == {14{1'b1}})
					next_state = SLPOUT;
				else
					next_state = SWRESET;
			SLPOUT:
				if (slpout_counter == {17{1'b1}})
					next_state = IDLE;
				else
					next_state = SLPOUT;
			IDLE:
				next_state = CMD;
			CMD:
				next_state = DATA;
			DATA:
				if (data_counter < PIXEL_COUNT)
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
			SWRESET:
				LCD_CS = swreset_counter < 2 ? 0 : 1;
			SLPOUT:
				LCD_CS = slpout_counter < 2 ? 0 : 1;
			CMD:
				LCD_CS = 0;
			DATA:
				LCD_CS = data_counter < PIXEL_COUNT ? 0 : 1;
			default:
				LCD_CS = 1;
		endcase
	end

	always @(*) begin
		case (state)
			SWRESET:
				LCD_DCX = 0;
			SLPOUT:
				LCD_DCX = 0;
			COLMOD:
				LCD_DCX = 0;
			MADCTL:
				LCD_DCX = 0;
			DISPON:
				LCD_DCX = 0;
			SETCOL:
				LCD_DCX = 0;
			SETROW:
				LCD_DCX = 0;
			CMD:
				LCD_DCX = 0;
			NOP:
				LCD_DCX = 0;
			default:
				LCD_DCX = 1;
		endcase
	end

	always @(*) begin
		case (state)
			SWRESET:
				LCD_WRX = swreset_counter < 1 ? !lcd_clk : 1;
			SLPOUT:
				LCD_WRX = slpout_counter < 1 ? !lcd_clk : 1;
			COLMOD:
				LCD_WRX = !lcd_clk;
			MADCTL:
				LCD_WRX = !lcd_clk;
			DISPON:
				LCD_WRX = dispon_counter < 1 ? !lcd_clk : 1;
			SETCOL:
				LCD_WRX = !lcd_clk;
			SETROW:
				LCD_WRX = !lcd_clk;
			CMD:
				LCD_WRX = !lcd_clk;
			DATA:
				LCD_WRX = !lcd_clk;
			NOP:
				LCD_WRX = !lcd_clk;
			default:
				LCD_WRX = 1;
		endcase
	end

	assign LCD_RST = !(state == BOOT && boot_counter < 19'b100000000000000);

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
