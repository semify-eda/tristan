`default_nettype none

`timescale 1ns/1ps

module cv32e40x_soc
#(
    parameter SOC_ADDR_WIDTH    = 32,
    parameter INSTR_ADDR_WIDTH  = 12, // in words (+2)
    parameter RAM_ADDR_WIDTH    = 12, // in words (+2)
    parameter INSTR_RDATA_WIDTH = 32,
    parameter CLK_FREQ          = 50_000_000,
    parameter BAUDRATE          = 115200,
    parameter BOOT_ADDR         = 32'h02000000 //+ 24'h200000
)
(
    // Clock and reset
    input  wire clk_i,
    input  wire rst_ni,
        
    // Uart
    output logic ser_tx,
    input  wire ser_rx,
    
    // OBI interface for external modules
    output logic                        obi_req_o,
    input  wire                         obi_gnt_i,
    output logic [SOC_ADDR_WIDTH-1:0]   obi_addr_o,
    output logic                        obi_we_o,
    output logic [3 : 0]                obi_be_o,
    output logic [31 : 0]               obi_wdata_o,
    input  wire [31 : 0]                obi_rvalid,
    input  wire [31 : 0]                obi_rdata
);
    localparam RAM_MASK         = 4'h0;
    localparam SPI_FLASH_MASK   = 4'h2;
    localparam UART_MASK        = 4'hA;
    localparam I2C_MASK         = 4'hE;
    localparam PINMUX_MASK      = 4'hF;    
        
    // ----------------------------------
    //           DP BRAM
    // ----------------------------------
    
    logic [31:0] instr_rdata;
    logic [31:0] ram_rdata;
    
    
    // ----------------------------------
    //               UART
    // ----------------------------------
    
    logic select_uart_data;
    logic select_uart_busy;
   
    logic [31:0] uart_soc_rdata;
    logic [31:0] uart_soc_rdata_del;
    
    logic uart_busy;
    
    // Prevent metastability
    logic [3:0] ser_rx_ff;


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
    //           Communication Signals
    // ----------------------------------
    logic obi_com;              // indicates SoC is communicating with an external module through OBI
    
    assign obi_com = select_i2c | select_pinmux;
    assign obi_req_o    = soc_req;
    assign obi_addr_o   = soc_addr;
    assign obi_we_o     = soc_we;
    assign obi_be_o     = soc_be;
    assign obi_wdata_o  = soc_wdata;
    
    // ----------------------------------
    //            Grant Logic
    // ----------------------------------
    always_ff @(posedge clk_i, negedge rst_ni) begin
        if (!rst_ni) begin
            soc_gnt <= 1'b0;
        end else begin
            // If communicating with an external module, wait for the module to respond
            if(obi_com) begin
                soc_gnt <= obi_gnt_i;
            end else begin 
             // Grant if we have not already granted
              soc_gnt <= soc_req && !soc_gnt && !soc_rvalid;
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

    cv32e40x_top #(
        //.BOOT_ADDR(BOOT_ADDR) // set in module because of yosys
    )
    cv32e40x_top_inst
    (
      // Clock and reset
      .clk_i        (clk_i      ),
      .rst_ni       (rst_ni),

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
    logic select_uart;
    logic select_spiflash;
    logic select_i2c;
    logic select_pinmux;
    
    // Data select signals
    assign select_ram          = soc_addr[31:24] == RAM_MASK;
    assign select_spiflash     = soc_addr[31:24] == SPI_FLASH_MASK;
    assign select_uart         = soc_addr[31:24] == UART_MASK;
    assign select_i2c          = soc_addr[31:24] == I2C_MASK;
    assign select_pinmux       = soc_addr[31:24] == PINMUX_MASK;


    always_comb begin
        if (select_ram)
            soc_rdata = ram_rdata;
        else if (select_uart_data)
            soc_rdata = uart_soc_rdata_del;
        else if (select_uart_busy)
            soc_rdata = {{31{1'b0}}, uart_busy};
        else if (select_spiflash)
            soc_rdata = instr_rdata;
        else if (obi_com)
            soc_rdata = obi_rdata;
        else
            soc_rdata = 'x;
    end

    always_ff @(posedge clk_i, negedge rst_ni) begin
        if (!rst_ni) begin
            soc_rvalid <= 1'b0;
        end else begin
            if(obi_com) begin
                soc_rvalid <= obi_rvalid;                
            end else begin
                // Generally data is available one cycle after req
                soc_rvalid <= soc_gnt;
            end
        end
    end

    // ----------------------------------
    //           DP BRAM - Instr
    // ----------------------------------    
    sram_dualport #(
        .INITFILEEN     (1),
        .INITFILE       ("firmware/firmware.hex"),
        .DATAWIDTH      (SOC_ADDR_WIDTH),
        .ADDRWIDTH      (INSTR_ADDR_WIDTH),
        .BYTE_ENABLE    (1)
    ) instr_dualport_i (
        .clk      (clk_i),

        // 16kb
        // INSTR_ADDR_WIDTH is directly tied to the DATAWIDTH. Having an addr width of 12 does not mean that you address the
        // 12 LSB of the address, since if the data width is 32, then the 2 LSB are omitted, and you therefore must address 
        // bits 13 to 2, due to alignment since the 2 LSB correspond to (32/8) = 4 bytes.
        .addr_a   (soc_addr[INSTR_ADDR_WIDTH+1:2]), // TODO word aligned
      .we_a     (soc_gnt && select_spiflash && soc_we),
      .d_a      (soc_wdata),
      .q_a      (instr_rdata),

      .addr_b   ('0),
      .we_b     ('0),
      .d_b      ('0),
      .q_b      ()
    );

    // ----------------------------------
    //           DP BRAM - Data
    // ----------------------------------  
    sram_dualport #(
        .DATAWIDTH      (SOC_ADDR_WIDTH),
        .ADDRWIDTH      (RAM_ADDR_WIDTH),
        .BYTE_ENABLE (1)
    ) ram_dualport_i (
      .clk      (clk_i),

      .addr_a   (soc_addr[RAM_ADDR_WIDTH-1:2]),     // + 1    
      .we_a     (soc_gnt && select_ram && soc_we),
      .d_a      (soc_wdata),
      .q_a      (ram_rdata),

      .addr_b   ('0),
      .we_b     ('0),
      .d_b      ('0),
      .q_b      ()
    );
    
    
    // ----------------------------------
    //               UART
    // ----------------------------------
    assign select_uart_data = select_uart && soc_addr[15:0]  == 16'h0000;
    assign select_uart_busy = select_uart && soc_addr[15:0]  == 16'h0004;
   
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

endmodule