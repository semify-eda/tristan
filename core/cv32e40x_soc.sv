
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
    
    // TODO connect RAM from outside
);
    localparam RAM_MASK         = 4'h0;
    localparam SPI_FLASH_MASK   = 4'h2;
    localparam UART_MASK        = 4'hA;
    localparam BLINK_MASK       = 4'hF;

    // ----------------------------------
    //           CV32E40X Core
    // ----------------------------------
    
    logic cpu_instr_req;
    logic cpu_instr_gnt;
    logic cpu_instr_rvalid;
    logic [SOC_ADDR_WIDTH-1:0] cpu_instr_addr;
    logic [31: 0] cpu_instr_rdata;
    
    logic cpu_data_req;
    logic cpu_data_gnt;
    logic cpu_data_rvalid;
    logic [SOC_ADDR_WIDTH-1:0] cpu_data_addr;
    logic [3 : 0] cpu_data_be;
    logic         cpu_data_we;
    logic [31: 0] cpu_data_wdata;
    logic [31: 0] cpu_data_rdata;
    
    logic soc_req;
    logic soc_gnt;
    logic soc_rvalid;
    logic [SOC_ADDR_WIDTH-1:0] soc_addr;
    logic [3 : 0] soc_be;
    logic         soc_we;
    logic [31: 0] soc_wdata;
    logic [31: 0] soc_rdata;
    
    // ----------------------------------
    //            Grant Logic
    // ----------------------------------
    always_ff @(posedge clk_i, negedge rst_ni) begin
        if (!rst_ni) begin
            soc_gnt <= 1'b0;
        end else begin
            // Grant if we have not already granted
            soc_gnt <= soc_req && !soc_gnt && !soc_rvalid;
            
            // SPI Flash is not single-cycle
            if (select_spiflash) begin
                soc_gnt <= spi_flash_done && !soc_gnt && !soc_rvalid;
            end
        end
    end
    
    // ----------------------------------
    //            Arbiter
    // ----------------------------------
    typedef enum {
        GNT_NONE,
        GNT_DATA,
        GNT_INSTR
    } arbiter_t;

    arbiter_t cur_granted;
    
    always_ff @(posedge clk_i, negedge rst_ni) begin
        if (!rst_ni) begin
            cur_granted <= GNT_NONE;
        end else begin
            // Bus is free
            if (cur_granted == GNT_NONE) begin
                // Data has precedence
                if (cpu_instr_req)  cur_granted <= GNT_INSTR;
                if (cpu_data_req)   cur_granted <= GNT_DATA;
            end else begin
                // Free the bus
                if (soc_rvalid) begin
                    cur_granted <= GNT_NONE;
                end
            end
        end
    end
    
    always_comb begin
        // default values
        soc_req     = '0;
        soc_addr    = '0;
        soc_be      = '0;
        soc_we      = '0;
        soc_wdata   = '0;
        
        cpu_instr_gnt       = '0;
        cpu_instr_rvalid    = '0;
        cpu_instr_rdata     = '0;
        
        cpu_data_gnt        = '0;
        cpu_data_rvalid     = '0;
        cpu_data_rdata      = '0;

        if (cur_granted == GNT_INSTR) begin
            // don't request the next transaction before the arbiter has switched
            soc_req     = cpu_instr_req && !soc_rvalid;
            soc_addr    = cpu_instr_addr;
            
            cpu_instr_gnt       = soc_gnt;
            cpu_instr_rvalid    = soc_rvalid;
            cpu_instr_rdata     = soc_rdata;
        end
        if (cur_granted == GNT_DATA) begin
            // don't request the next transaction before the arbiter has switched
            soc_req     = cpu_data_req && !soc_rvalid;
            soc_addr    = cpu_data_addr;
            soc_be      = cpu_data_be;
            soc_we      = cpu_data_we;
            soc_wdata   = cpu_data_wdata;
            
            cpu_data_gnt        = soc_gnt;
            cpu_data_rvalid     = soc_rvalid;
            cpu_data_rdata      = soc_rdata;
        end
    end

    //assign soc_instr_gnt = soc_instr_req && !soc_req; // && spi_flash_done; // TODO quick hack
    //assign soc_gnt  = soc_req; // always grant on request

    cv32e40x_top #(
        //.BOOT_ADDR(BOOT_ADDR) // set in module because of yosys
    )
    cv32e40x_top_inst
    (
      // Clock and reset
      .clk_i        (clk_i      ),
      .rst_ni       (rst_ni     ),

      // Instruction memory interface
      .instr_req_o      (cpu_instr_req      ),
      .instr_gnt_i      (cpu_instr_gnt      ),
      .instr_rvalid_i   (cpu_instr_rvalid   ),
      .instr_addr_o     (cpu_instr_addr     ),
      .instr_rdata_i    (cpu_instr_rdata    ),

      // Data memory interface
      .data_req_o       (cpu_data_req       ),
      .data_gnt_i       (cpu_data_gnt       ), 
      .data_rvalid_i    (cpu_data_rvalid    ),
      .data_addr_o      (cpu_data_addr      ),
      .data_be_o        (cpu_data_be        ),
      .data_we_o        (cpu_data_we        ),
      .data_wdata_o     (cpu_data_wdata     ),
      .data_rdata_i     (cpu_data_rdata     ),

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
    
    logic select_ram;
    logic select_led;
    logic select_uart;
    logic select_spiflash;
    
    // Data select signals
    assign select_ram          = soc_addr[31:24]  == RAM_MASK;
    assign select_spiflash     = soc_addr[31:24]  == SPI_FLASH_MASK;
    assign select_uart         = soc_addr[31:24]  == UART_MASK;
    assign select_led          = soc_addr[31:24]  == BLINK_MASK;
    
    // TODO Problem: address can change after gnt, but rvalid/rdata depends on it
    // TODO don't delay for ram?
    always_comb begin
        if (select_ram)
            soc_rdata = ram_rdata;
        else if (select_led)
            soc_rdata = {{31{1'b0}}, led};
        else if (select_uart_data)
            soc_rdata = uart_soc_rdata_del;
        else if (select_uart_busy)
            soc_rdata = {{31{1'b0}}, uart_busy};
        else if (select_spiflash)
            soc_rdata = spi_flash_rdata;
        else
            soc_rdata = 'x;
    end

    always_ff @(posedge clk_i, negedge rst_ni) begin
        if (!rst_ni) begin
            soc_rvalid <= 1'b0;
        end else begin
            // Generally data is available one cycle after req
            soc_rvalid <= soc_gnt;
            
            // SPI Flash has latency, first gnt then rvalid
            if (select_spiflash) begin
                soc_rvalid <= spi_flash_done_delayed;
            end
        end
    end
    

    // ----------------------------------
    //              DP RAM
    // ----------------------------------
    
    // TODO remove instruction port from RAM?
    
    logic [31:0] ram_rdata;
    logic [INSTR_RDATA_WIDTH-1:0] ram_instr_rdata;
    
    // instantiate the ram
    dp_ram
        #(.ADDR_WIDTH (RAM_ADDR_WIDTH),
          .INSTR_RDATA_WIDTH(INSTR_RDATA_WIDTH))
    dp_ram_i
    (
        .clk_i     ( clk_i           ),

        .en_a_i    ( '0 ),
        .addr_a_i  ( '0  ),
        .wdata_a_i ( '0              ),	// Not writing so ignored
        .rdata_a_o (  ),
        .we_a_i    ( '0              ),
        .be_a_i    ( 4'b1111         ),	// Always want 32-bits

        .en_b_i    ( soc_gnt && select_ram ),
        .addr_b_i  ( soc_addr   ),
        .wdata_b_i ( soc_wdata  ),
        .rdata_b_o ( ram_rdata  ),
        .we_b_i    ( soc_we     ),
        .be_b_i    ( soc_be     )
    );
    
    // ----------------------------------
    //           Blink LED
    // ----------------------------------
     
    always_ff @(posedge clk_i, negedge rst_ni) begin
        if (!rst_ni) begin
            led <= 1'b1;
        end else begin
            if (soc_gnt && select_led && soc_we) begin
                led <= soc_wdata[0];
            end
        end
    end
    
    // ----------------------------------
    //               UART
    // ----------------------------------
    
    logic select_uart_data;
    logic select_uart_busy;
    
    assign select_uart_data = select_uart && soc_addr[15:0]  == 16'h0000;
    assign select_uart_busy = select_uart && soc_addr[15:0]  == 16'h0004;
    
    logic [31:0] uart_soc_rdata;
    logic [31:0] uart_soc_rdata_del;
    
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

        .reg_dat_we (soc_gnt && select_uart_data && soc_we),
        .reg_dat_re (soc_gnt && select_uart_data && !soc_we),
        .reg_dat_di (soc_wdata),
        .reg_dat_do (uart_soc_rdata),
        .reg_dat_wait (uart_busy)
    );
    
    always @(posedge clk_i) begin
        uart_soc_rdata_del <= uart_soc_rdata;
    end
    
    // ----------------------------------
    //           SPI Flash
    // ----------------------------------
    
    logic [31: 0] spi_flash_rdata;
    logic spi_flash_done;
	logic spi_flash_done_delayed;
    logic spi_flash_initialized;
    
`ifdef SYNTHESIS

    // TODO arbiter

    spi_flash spi_flash_inst (
        .clk,
        .reset      (!rst_ni),

        .addr_in    (soc_addr[15:0]),          // address of word # TODO increase
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
	
    always_ff @(posedge clk_i, negedge rst_ni) begin
        if (!rst_ni) begin
            spi_flash_done          <= 1'b0;
            spi_flash_done_delayed  <= 1'b0;
            spi_flash_initialized   <= 1'b1;
            counter                 <= '0;
            spi_flash_rdata         <= '0;
        end else begin
            spi_flash_done          <= 1'b0;
            counter                 <= '0;
            spi_flash_done_delayed  <= spi_flash_done;
            
	        if (select_spiflash && soc_req) begin
	            spi_flash_rdata <= {memory[(soc_addr[23:2]<<2) + 3], 
	                                memory[(soc_addr[23:2]<<2) + 2], 
	                                memory[(soc_addr[23:2]<<2) + 1], 
	                                memory[(soc_addr[23:2]<<2)]};
	            
	            counter <= counter + 1;
	            
	            if (counter > 100) begin
                    spi_flash_done <= 1'b1;
                    counter <= 1'b0;
                end
                
                // spi_flash_done <= !spi_flash_done; // TODO remove
            end
	    end
    end

`endif

endmodule
