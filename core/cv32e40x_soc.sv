
module cv32e40x_soc
 #(
     parameter SOC_ADDR_WIDTH    =  32,
               RAM_ADDR_WIDTH    =  14,
               INSTR_RDATA_WIDTH = 128,
               CLK_FREQ          = 25_000_000,
               BAUDRATE          = 115200,
               BOOT_ADDR         = 32'h02000000 + 24'h200000
  )
(
    // Clock and reset
    input  logic clk_i,
    input  logic rst_ni,
    
    // Blinky
    output logic led,
    
    // Uart
    output ser_tx,
    input  ser_rx,
    
    // SPI signals
    output sck,
    output sdo,
    input  sdi,
    output cs
    
    // TODO move RAM outside
);
    localparam RAM_MASK         = 4'h0;
    localparam SPI_FLASH_MASK   = 4'h2;
    localparam UART_MASK        = 4'hA;
    localparam BLINK_MASK       = 4'hF;

    logic soc_instr_req;
    logic soc_instr_gnt;
    logic soc_instr_rvalid;
    logic [SOC_ADDR_WIDTH-1:0] soc_instr_addr;
    logic [31: 0] soc_instr_rdata;
    
    logic soc_data_req;
    logic soc_data_gnt;
    logic soc_data_rvalid;
    logic [SOC_ADDR_WIDTH-1:0] soc_data_addr;
    logic [3 : 0] soc_data_be;
    logic         soc_data_we;
    logic [31: 0] soc_data_wdata;
    logic [31: 0] soc_data_rdata;

    // ----------------------------------
    //           CV32E40X Core
    // ----------------------------------

    assign soc_instr_gnt = soc_instr_req;// && spi_flash_done; // TODO quick hack
    assign soc_data_gnt  = soc_data_req; // always grant on request


    cv32e40x_top #(
        //.BOOT_ADDR(BOOT_ADDR) // set in module because of yosys
    )
    cv32e40x_top_inst
    (
      // Clock and reset
      .clk_i        (clk_i      ),
      .rst_ni       (rst_ni     ),

      // Instruction memory interface
      .instr_req_o      (soc_instr_req      ),
      .instr_gnt_i      (soc_instr_gnt      ),
      .instr_rvalid_i   (soc_instr_rvalid   ),
      .instr_addr_o     (soc_instr_addr     ),
      .instr_rdata_i    (soc_instr_rdata    ),

      // Data memory interface
      .data_req_o       (soc_data_req       ),
      .data_gnt_i       (soc_data_gnt       ), 
      .data_rvalid_i    (soc_data_rvalid    ),
      .data_addr_o      (soc_data_addr      ),
      .data_be_o        (soc_data_be        ),
      .data_we_o        (soc_data_we        ),
      .data_wdata_o     (soc_data_wdata     ),
      .data_rdata_i     (soc_data_rdata     ),

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
    
    logic select_instr_ram;
    logic select_data_ram;
    logic select_data_led;
    logic select_data_uart;
    logic select_data_spiflash;
    logic select_instr_spiflash;

    // TODO Update firmware
    
    // Data select signals
    assign select_data_ram          = soc_data_addr[31:24]  == RAM_MASK;
    assign select_data_spiflash     = soc_data_addr[31:24]  == SPI_FLASH_MASK;
    assign select_data_uart         = soc_data_addr[31:24]  == UART_MASK;
    assign select_data_led          = soc_data_addr[31:24]  == BLINK_MASK;
    
    // Instruction select signals
    assign select_instr_ram         = soc_instr_addr[31:24] == RAM_MASK;
    assign select_instr_spiflash    = soc_instr_addr[31:24] == SPI_FLASH_MASK;
    
    always_comb begin
        if (select_data_ram)
            soc_data_rdata = ram_data_rdata;
        else if (select_data_led)
            soc_data_rdata = {{31{1'b0}}, led};
        else if (select_data_uart_data)
            soc_data_rdata = uart_soc_data_rdata_del;
        else if (select_data_uart_busy)
            soc_data_rdata = {{31{1'b0}}, uart_busy};
        else if (select_data_spiflash)
            soc_data_rdata = spi_flash_rdata;
        else
            soc_data_rdata = 'x;
    end
    
    always_comb begin
        if (select_instr_ram)
            soc_instr_rdata = ram_instr_rdata;
        else if (select_instr_spiflash)
            soc_instr_rdata = spi_flash_rdata;
        else
            soc_instr_rdata = 'x;
    end

    always_ff @(posedge clk_i, negedge rst_ni) begin
        if (!rst_ni) begin
            soc_instr_rvalid <= 1'b0;
            soc_data_rvalid <= 1'b0;
        end else begin
            // Generally data is available one cycle after req
            soc_instr_rvalid <= soc_instr_req;
            soc_data_rvalid <= soc_data_req;
            
            // SPI Flash has latency
            if (select_instr_spiflash) begin
                soc_instr_rvalid <= spi_flash_done;
            end
            if (select_data_spiflash) begin
                soc_data_rvalid <= spi_flash_done;
            end
        end
    end
    

    // ----------------------------------
    //              DP RAM
    // ----------------------------------
    
    // TODO remove instruction port from RAM?
    
    logic [31:0] ram_data_rdata;
    logic [INSTR_RDATA_WIDTH-1:0] ram_instr_rdata;
    
    // instantiate the ram
    dp_ram
        #(.ADDR_WIDTH (RAM_ADDR_WIDTH),
          .INSTR_RDATA_WIDTH(INSTR_RDATA_WIDTH))
    dp_ram_i
    (
        .clk_i     ( clk_i           ),

        .en_a_i    ( soc_instr_req & select_instr_ram ),
        .addr_a_i  ( soc_instr_addr  ),
        .wdata_a_i ( '0              ),	// Not writing so ignored
        .rdata_a_o ( ram_instr_rdata ),
        .we_a_i    ( '0              ),
        .be_a_i    ( 4'b1111         ),	// Always want 32-bits

        .en_b_i    ( soc_data_req & select_data_ram ),
        .addr_b_i  ( soc_data_addr   ),
        .wdata_b_i ( soc_data_wdata  ),
        .rdata_b_o ( ram_data_rdata  ),
        .we_b_i    ( soc_data_we     ),
        .be_b_i    ( soc_data_be     )
    );
    
    // ----------------------------------
    //           Blink LED
    // ----------------------------------
     
    always_ff @(posedge clk_i, negedge rst_ni) begin
        if (!rst_ni) begin
            led <= 1'b1;
        end else begin
            if (soc_data_req && select_data_led && soc_data_we) begin
                led <= soc_data_wdata[0];
            end
        end
    end
    
    // ----------------------------------
    //               UART
    // ----------------------------------
    
    logic select_data_uart_data;
    logic select_data_uart_busy;
    
    assign select_data_uart_data = select_data_uart && soc_data_addr[15:0]  == 16'h0000;
    assign select_data_uart_busy = select_data_uart && soc_data_addr[15:0]  == 16'h0004;
    
    logic [31:0] uart_soc_data_rdata;
    logic [31:0] uart_soc_data_rdata_del;
    
    logic uart_busy;
    
    // Prevent metastability
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

        .reg_div_we ('0),
        .reg_div_di ('0),
        .reg_div_do (),

        .reg_dat_we (soc_data_req && select_data_uart_data && soc_data_we),
        .reg_dat_re (soc_data_req && select_data_uart_data && !soc_data_we),
        .reg_dat_di (soc_data_wdata),
        .reg_dat_do (uart_soc_data_rdata),
        .reg_dat_wait (uart_busy)
    );
    
    always @(posedge clk_i) begin
        uart_soc_data_rdata_del <= uart_soc_data_rdata;
    end
    
    // ----------------------------------
    //           SPI Flash
    // ----------------------------------
    
    logic [31: 0] spi_flash_rdata;
    logic spi_flash_done;
    logic spi_flash_initialized;
    
`ifdef SYNTHESIS

    // TODO arbiter

    spi_flash spi_flash_inst (
        .clk,
        .reset      (!rst_ni),

        .addr_in    (soc_data_addr[15:0]),          // address of word # TODO increase
        .data_out   (spi_flash_rdata),              // received word
        .strobe     (select_data_spiflash && mem_rstrb),    // start transmission
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
    
    localparam INIT_F = "core/firmware/firmware.hex";
    localparam OFFSET = 24'h200000;
    
	// 16 MB (128Mb) Flash
	reg [7:0] memory [0:16*1024*1024-1];
	initial begin
		$readmemh(INIT_F, memory, OFFSET);
	end
	
	logic [7:0] counter;
	
	// Arbitrate access, data has precedence
    logic [SOC_ADDR_WIDTH-1:0] spi_addr;
    logic spi_req;
    
    always_comb begin
        spi_addr = '0;
        spi_req  = '0;
    
        if (select_data_spiflash && soc_data_req) begin
            spi_addr = soc_data_addr;
            spi_req = soc_data_req;
        end
        
        if (select_instr_spiflash && soc_instr_req) begin
            spi_addr = soc_instr_addr;
            spi_req = soc_instr_req;
        end
    end
	
    always_ff @(posedge clk_i, negedge rst_ni) begin
        if (!rst_ni) begin
            spi_flash_done <= 1'b0;
            spi_flash_initialized = 1'b1;
            counter <= '0;
            spi_flash_rdata <= '0;
        end else begin
            spi_flash_done <= 1'b0;
            counter <= '0;
	        if (spi_req) begin
	            spi_flash_rdata <= {memory[(spi_addr[23:2]<<2) + 3], 
	                                memory[(spi_addr[23:2]<<2) + 2], 
	                                memory[(spi_addr[23:2]<<2) + 1], 
	                                memory[(spi_addr[23:2]<<2)]};
	            
	            counter <= counter + 1;
	            
	            if (counter > 100) begin
                    spi_flash_done <= 1'b1;
                    counter <= 1'b0;
                end
            end
	    end
    end

`endif

endmodule
