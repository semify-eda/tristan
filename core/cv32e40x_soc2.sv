
module cv32e40x_soc
 #(
     parameter SOC_ADDR_WIDTH    =  24,
               RAM_ADDR_WIDTH    =  14,
               INSTR_RDATA_WIDTH = 128,  // width of read_data on instruction bus
               CLK_FREQ          = 25_000_000,
               BAUDRATE          = 115200,
               BOOT_ADDR         = 'h0//'h80
  )
(
    // Clock and reset
    input  logic clk_i,
    input  logic rst_ni,
    output logic led,
    output ser_tx,
    input  ser_rx
);
    localparam RAM_MASK         = 4'h0;
    localparam SPI_FLASH_MASK   = 4'h1;
    localparam UART_MASK        = 4'hA;
    localparam BLINK_MASK       = 4'hF;

    logic ram_instr_req;
    logic [SOC_ADDR_WIDTH-1:0] ram_instr_addr;
    logic [INSTR_RDATA_WIDTH-1:0] ram_instr_rdata;
    
    logic ram_data_req;
    logic [SOC_ADDR_WIDTH-1:0] ram_data_addr;
    logic [31:0] ram_data_wdata;
    logic [31:0] ram_data_rdata;
    logic [31:0] data_rdata;
    logic ram_data_we;
    logic [3:0] ram_data_be;     

    logic instr_rvalid;
    logic data_rvalid;

    // ----------------------------------
    //           CV32E40X Core
    // ----------------------------------

    cv32e40x_top /*#(
        .BOOT_ADDR(BOOT_ADDR)
    )*/ // BOOT_ADDR is 'h80
    cv32e40x_top_inst
    (
      // Clock and reset
      .clk_i        (clk_i      ),
      .rst_ni       (rst_ni     ),

      // Instruction memory interface
      .instr_req_o      (ram_instr_req),
      .instr_gnt_i      (ram_instr_req), // always grant on request
      .instr_rvalid_i   (instr_rvalid),
      .instr_addr_o     (ram_instr_addr),
      .instr_rdata_i    (ram_instr_rdata),

      // Data memory interface
      .data_req_o       (ram_data_req),
      .data_gnt_i       (ram_data_req), // always grant on request
      .data_rvalid_i    (data_rvalid),
      .data_addr_o      (ram_data_addr),
      .data_be_o        (ram_data_be),
      .data_we_o        (ram_data_we),
      .data_wdata_o     (ram_data_wdata),
      .data_rdata_i     (data_rdata),

      // Cycle count
      .mcycle_o         (),

      // Debug interface
      .debug_req_i      (1'b0),

      // CPU control signals
      .fetch_enable_i   (1'b1),
      .core_sleep_o     ()
    );
    
    // ----------------------------------
    //            Multiplexer
    // ----------------------------------
    
    logic dp_ram_select_instr;
    logic dp_ram_select_data;
    logic select_led;
    logic select_uart;
    logic select_spi_flash;

    // TODO Update firmware
    assign dp_ram_select_instr  = ram_instr_addr[23:20] == RAM_MASK;
    assign dp_ram_select_data   = ram_data_addr[23:20]  == RAM_MASK;
    assign select_spi_flash     = ram_data_addr[23:20]  == SPI_FLASH_MASK; // TODO data and instr
    assign select_uart_data     = ram_data_addr[23:20]  == UART_MASK;
    assign select_led           = ram_data_addr[23:20]  == BLINK_MASK;
    
    always_comb begin
        if (dp_ram_select_data)
            data_rdata = ram_data_rdata;
        else if (select_led)
            data_rdata = {{31{1'b0}}, led};
        else if (select_uart_data)
            data_rdata = uart_data_rdata_del;
        else if (select_uart_busy)
            data_rdata = {{31{1'b0}}, uart_busy};
        else if (select_spi_flash)
            data_rdata = spi_flash_rdata;
        else
        
            data_rdata = 'x;
    end

    always_ff @(posedge clk_i, negedge rst_ni) begin
        if (!rst_ni) begin
            instr_rvalid <= 1'b0;
            data_rvalid <= 1'b0;
        end else begin
            // TODO spi_flash_done
        
            instr_rvalid <= ram_instr_req;
            data_rvalid <= ram_data_req;
        end
    end
    

    // ----------------------------------
    //              DP RAM
    // ----------------------------------
    
    // instantiate the ram
    dp_ram
        #(.ADDR_WIDTH (RAM_ADDR_WIDTH),
          .INSTR_RDATA_WIDTH(INSTR_RDATA_WIDTH))
    dp_ram_i
    (
        .clk_i     ( clk_i           ),

        .en_a_i    ( ram_instr_req & dp_ram_select_instr ),
        .addr_a_i  ( ram_instr_addr  ),
        .wdata_a_i ( '0              ),	// Not writing so ignored
        .rdata_a_o ( ram_instr_rdata ),
        .we_a_i    ( '0              ),
        .be_a_i    ( 4'b1111         ),	// Always want 32-bits

        .en_b_i    ( ram_data_req & dp_ram_select_data ),
        .addr_b_i  ( ram_data_addr   ),
        .wdata_b_i ( ram_data_wdata  ),
        .rdata_b_o ( ram_data_rdata  ),
        .we_b_i    ( ram_data_we     ),
        .be_b_i    ( ram_data_be     )
    );
    
    // ----------------------------------
    //           Blink LED
    // ----------------------------------
     
    always_ff @(posedge clk_i, negedge rst_ni) begin
        if (!rst_ni) begin
            led <= 1'b1;
        end else begin
            if (ram_data_req && select_led && ram_data_we) begin
                led <= ram_data_wdata[0];
            end
        end
    end
    
    // ----------------------------------
    //               UART
    // ----------------------------------
    
    logic select_uart_data;
    logic select_uart_busy;
    
    assign select_uart_data = select_uart && ram_data_addr[15:0]  == 16'h0000;
    assign select_uart_busy = select_uart && ram_data_addr[15:0]  == 16'h0004;
    
    logic [31:0] uart_data_rdata;
    logic [31:0] uart_data_rdata_del;
    
    logic uart_busy;
    
    // Remove metastability
    logic [3:0] ser_rx_ff;
    
    always @(posedge clk_i) begin
        ser_rx_ff <= {ser_rx_ff[2:0], ser_rx};
    end
    
    simpleuart #(
        .DEFAULT_DIV(CLK_FREQ / BAUDRATE)
    ) simpleuart_inst (
        .clk    (clk_i),
        .resetn(rst_ni),

        .ser_tx (ser_tx),
        .ser_rx (ser_rx_ff[3]),

        .reg_div_we (1'b0),
        .reg_div_di ('0),
        .reg_div_do (),

        .reg_dat_we (ram_data_req && select_uart_data && ram_data_we),
        .reg_dat_re (ram_data_req && select_uart_data && !ram_data_we),
        .reg_dat_di (ram_data_wdata),
        .reg_dat_do (uart_data_rdata),
        .reg_dat_wait (uart_busy)
    );
    
    always @(posedge clk_i) begin
        uart_data_rdata_del <= uart_data_rdata;
    end
    
    // ----------------------------------
    //           SPI Flash
    // ----------------------------------
    
    logic [DATA_WIDTH-1:0] spi_flash_rdata;
    logic spi_flash_done;
    logic spi_flash_initialized;
    
    `ifdef SYNTHESIS
    spi_flash spi_flash_inst (
        .clk,
        .reset,

        .addr_in    (ram_data_addr[15:0]),          // address of word # TODO increase
        .data_out   (spi_flash_rdata),              // received word
        .strobe     (select_spi_flash && mem_rstrb),    // start transmission
        .done       (spi_flash_done),               // pulse, transmission done
        .initialized(spi_flash_initialized),        // initial cmds sent

        // SPI signals
        .sck,
        .sdo,
        .sdi,
        .cs
    );
    
`else
    // TODO SPI Flash does not want to simulate correctly
    //      use this as a workaround
    
    localparam INIT_F = "firmware/firmware.hex";
    localparam OFFSET = 24'h200000;
    
	// 16 MB (128Mb) Flash
	reg [7:0] memory [0:16*1024*1024-1];
	initial begin
		$readmemh(INIT_F, memory, OFFSET);
	end
	
	logic [7:0] counter;
	
    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            spi_flash_done <= 1'b0;
            spi_flash_initialized = 1'b1;
            counter <= '0;
        end else begin
            spi_flash_done <= 1'b0;
            counter <= '0;
	        if (soc_spi_flash_sel && mem_rstrb) begin
	            spi_flash_rdata <= {memory[(mem_addr[23:2]<<2) + 3], memory[(mem_addr[23:2]<<2) + 2], memory[(mem_addr[23:2]<<2) + 1], memory[(mem_addr[23:2]<<2)]};
	            
	            counter <= counter +1;
	            
	            if (counter > 100)
                spi_flash_done <= 1'b1;
            end
	    end
    end

`endif

endmodule
