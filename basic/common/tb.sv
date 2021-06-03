
// ** import uvm package **
import uvm_pkg::*;
// import apb_pkg::*;

`include "uvm_macros.svh"

module tb;

    logic clk200M;
    logic rstn;

    initial begin: CLK_GENERATOR
        clk200M = 0;
        forever begin
            #2.5ns clk200M = ~clk200M;
        end
    end

    initial begin: RST_SEQ
        rstn = 0;   
        repeat(10) @(posedge clk200M);
        rstn = 1;
    end

    // create apb interface
    apb_if apb_if0( .clk(clk200M), .rstn(rstn) );

    // create DUT
    apb_slave dut(
        .clk        (clk200M),
        .rstn       (rstn),
        .paddr      (apb_if0.paddr),
        .psel       (apb_if0.psel),
        .penable    (apb_if0.penable),
        .pwrite     (apb_if0.pwrite),
        .pwdata     (apb_if0.pwdata),
        .prdata     (apb_if0.prdata),
        .pready     (apb_if0.pready),
        .pslverr    (apb_if0.pslverr)
    );

    initial begin: UVM
        // everything written here were imported from UVM package.
        uvm_config_db #(virtual apb_if)::set(null, "*", "apb_if", apb_if0);
        run_test();
    end
    
endmodule