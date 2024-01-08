// Trace: asic/sram/rtl/sram_wrapper.sv:4:1
`default_nettype none
module sram_wrapper (
	soc_clk0,
	soc_csb0,
	soc_web0,
	soc_wmask0,
	soc_addr0,
	soc_din0,
	soc_dout0,
	soc_clk1,
	soc_csb1,
	soc_addr1,
	soc_dout1,
	clk0,
	csb0,
	web0,
	wmask0,
	addr0,
	din0,
	dout0,
	clk1,
	csb1,
	addr1,
	dout1
);
	// Trace: asic/sram/rtl/sram_wrapper.sv:7:15
	parameter NUM_WMASKS = 4;
	// Trace: asic/sram/rtl/sram_wrapper.sv:8:15
	parameter DATA_WIDTH = 32;
	// Trace: asic/sram/rtl/sram_wrapper.sv:9:15
	parameter ADDR_WIDTH = 11;
	// Trace: asic/sram/rtl/sram_wrapper.sv:10:15
	parameter ADDR_WIDTH_DEFAULT = 9;
	// Trace: asic/sram/rtl/sram_wrapper.sv:11:15
	parameter ADDR_UPPER_BITS = ADDR_WIDTH - ADDR_WIDTH_DEFAULT;
	// Trace: asic/sram/rtl/sram_wrapper.sv:12:15
	parameter NUM_INSTANCES = 2 ** ADDR_UPPER_BITS;
	// Trace: asic/sram/rtl/sram_wrapper.sv:18:5
	input soc_clk0;
	// Trace: asic/sram/rtl/sram_wrapper.sv:19:5
	input soc_csb0;
	// Trace: asic/sram/rtl/sram_wrapper.sv:20:5
	input soc_web0;
	// Trace: asic/sram/rtl/sram_wrapper.sv:21:5
	input [NUM_WMASKS - 1:0] soc_wmask0;
	// Trace: asic/sram/rtl/sram_wrapper.sv:22:5
	input [ADDR_WIDTH - 1:0] soc_addr0;
	// Trace: asic/sram/rtl/sram_wrapper.sv:23:5
	input [DATA_WIDTH - 1:0] soc_din0;
	// Trace: asic/sram/rtl/sram_wrapper.sv:24:5
	output wire [DATA_WIDTH - 1:0] soc_dout0;
	// Trace: asic/sram/rtl/sram_wrapper.sv:27:5
	input soc_clk1;
	// Trace: asic/sram/rtl/sram_wrapper.sv:28:5
	input soc_csb1;
	// Trace: asic/sram/rtl/sram_wrapper.sv:29:5
	input [ADDR_WIDTH - 1:0] soc_addr1;
	// Trace: asic/sram/rtl/sram_wrapper.sv:30:5
	output wire [DATA_WIDTH - 1:0] soc_dout1;
	// Trace: asic/sram/rtl/sram_wrapper.sv:35:5
	output wire [NUM_INSTANCES - 1:0] clk0;
	// Trace: asic/sram/rtl/sram_wrapper.sv:36:5
	output wire [NUM_INSTANCES - 1:0] csb0;
	// Trace: asic/sram/rtl/sram_wrapper.sv:37:5
	output wire [NUM_INSTANCES - 1:0] web0;
	// Trace: asic/sram/rtl/sram_wrapper.sv:38:5
	output wire [(NUM_INSTANCES * NUM_WMASKS) - 1:0] wmask0;
	// Trace: asic/sram/rtl/sram_wrapper.sv:39:5
	output wire [(NUM_INSTANCES * ADDR_WIDTH_DEFAULT) - 1:0] addr0;
	// Trace: asic/sram/rtl/sram_wrapper.sv:40:5
	output wire [(NUM_INSTANCES * DATA_WIDTH) - 1:0] din0;
	// Trace: asic/sram/rtl/sram_wrapper.sv:41:5
	input [(NUM_INSTANCES * DATA_WIDTH) - 1:0] dout0;
	// Trace: asic/sram/rtl/sram_wrapper.sv:44:5
	output wire [NUM_INSTANCES - 1:0] clk1;
	// Trace: asic/sram/rtl/sram_wrapper.sv:45:5
	output wire [NUM_INSTANCES - 1:0] csb1;
	// Trace: asic/sram/rtl/sram_wrapper.sv:46:5
	output wire [(NUM_INSTANCES * ADDR_WIDTH_DEFAULT) - 1:0] addr1;
	// Trace: asic/sram/rtl/sram_wrapper.sv:47:5
	input [(NUM_INSTANCES * DATA_WIDTH) - 1:0] dout1;
	// Trace: asic/sram/rtl/sram_wrapper.sv:52:5
	wire [ADDR_UPPER_BITS - 1:0] upper_addr_port0;
	// Trace: asic/sram/rtl/sram_wrapper.sv:53:5
	wire [ADDR_UPPER_BITS - 1:0] upper_addr_port1;
	// Trace: asic/sram/rtl/sram_wrapper.sv:55:5
	assign upper_addr_port0 = soc_addr0[ADDR_WIDTH - 1:ADDR_WIDTH_DEFAULT];
	// Trace: asic/sram/rtl/sram_wrapper.sv:56:5
	assign upper_addr_port1 = soc_addr1[ADDR_WIDTH - 1:ADDR_WIDTH_DEFAULT];
	// Trace: asic/sram/rtl/sram_wrapper.sv:59:5
	reg [ADDR_UPPER_BITS - 1:0] upper_addr_port0_d;
	// Trace: asic/sram/rtl/sram_wrapper.sv:60:5
	reg [ADDR_UPPER_BITS - 1:0] upper_addr_port1_d;
	// Trace: asic/sram/rtl/sram_wrapper.sv:62:5
	always @(posedge soc_clk0)
		// Trace: asic/sram/rtl/sram_wrapper.sv:63:9
		upper_addr_port0_d <= upper_addr_port0;
	// Trace: asic/sram/rtl/sram_wrapper.sv:66:5
	always @(posedge soc_clk1)
		// Trace: asic/sram/rtl/sram_wrapper.sv:67:9
		upper_addr_port1_d <= upper_addr_port1;
	// Trace: asic/sram/rtl/sram_wrapper.sv:71:5
	wire [NUM_INSTANCES - 1:0] enable_port0;
	// Trace: asic/sram/rtl/sram_wrapper.sv:72:5
	wire [NUM_INSTANCES - 1:0] enable_port1;
	// Trace: asic/sram/rtl/sram_wrapper.sv:74:5
	genvar i;
	generate
		for (i = 0; i < NUM_INSTANCES; i = i + 1) begin : genblk1
			// Trace: asic/sram/rtl/sram_wrapper.sv:79:13
			assign enable_port0[i] = upper_addr_port0 == i;
			// Trace: asic/sram/rtl/sram_wrapper.sv:80:13
			assign enable_port1[i] = upper_addr_port1 == i;
			// Trace: asic/sram/rtl/sram_wrapper.sv:82:13
			assign clk0[i] = soc_clk0;
			// Trace: asic/sram/rtl/sram_wrapper.sv:83:13
			assign csb0[i] = soc_csb0 || !enable_port0;
			// Trace: asic/sram/rtl/sram_wrapper.sv:84:13
			assign web0[i] = soc_web0;
			// Trace: asic/sram/rtl/sram_wrapper.sv:85:13
			assign wmask0[i * NUM_WMASKS+:NUM_WMASKS] = soc_wmask0;
			// Trace: asic/sram/rtl/sram_wrapper.sv:86:13
			assign addr0[i * ADDR_WIDTH_DEFAULT+:ADDR_WIDTH_DEFAULT] = soc_addr0;
			// Trace: asic/sram/rtl/sram_wrapper.sv:87:13
			assign din0[i * DATA_WIDTH+:DATA_WIDTH] = soc_din0;
			// Trace: asic/sram/rtl/sram_wrapper.sv:89:13
			assign clk1[i] = soc_clk1;
			// Trace: asic/sram/rtl/sram_wrapper.sv:90:13
			assign csb1[i] = soc_csb1 || !enable_port1;
			// Trace: asic/sram/rtl/sram_wrapper.sv:91:13
			assign addr1[i * ADDR_WIDTH_DEFAULT+:ADDR_WIDTH_DEFAULT] = soc_addr1;
		end
	endgenerate
	// Trace: asic/sram/rtl/sram_wrapper.sv:96:5
	assign soc_dout0 = dout0[upper_addr_port0_d * DATA_WIDTH+:DATA_WIDTH];
	// Trace: asic/sram/rtl/sram_wrapper.sv:97:5
	assign soc_dout1 = dout1[upper_addr_port1_d * DATA_WIDTH+:DATA_WIDTH];
endmodule