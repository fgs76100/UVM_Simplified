interface apb_if (input clk);

    logic        rstn;
    logic [11:0] paddr;
    logic        psel;
    logic        penable;
    logic        pwrite;
    logic [31:0] pwdata;
    logic [31:0] prdata;
    logic        pready;
    logic        pslverr;

endinterface: apb_if