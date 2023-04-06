interface if_rmem ();
  
  logic start;
  logic done;
  logic [31:0] rdata;
  logic [31:0] addr;  

  
  modport read_mod (//input addr, addr not needed for now addr is alway soure register 0
                    // assigned in coprog.sv:61
                    output rdata,
                    input  start,
                    output done);

  modport read_coproc (//output addr,
                     input  rdata,
                     output start,
                     input  done);

  




endinterface
