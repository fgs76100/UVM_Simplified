module apb_slave (
    input        clk,
    input        rstn,
    input [11:0] paddr,
    input        psel,
    input        penable,
    input        pwrite,
    input [31:0] pwdata,

    output logic [31:0] prdata,
    output logic pready,
    output logic pslverr
);

    logic [31:0] reg000, reg008, reg018;
    logic reg000_en, reg008_en, reg_018_en;
    logic reg000_wen, reg008_wen, reg_018_wen;
    logic reg000_ren, reg008_ren, reg_018_ren;
    logic slv_selected, decode_err;
    logic [31:0] prdata_nxt;
    logic pslverr_nxt;
    logic [ 7:0] intr_src;  // interrupt source
    logic [ 7:0] intr_msk;  // interrupt mask
    logic [ 7:0] tx_ctrl;
    logic [ 7:0] rx_ctrl;
    logic [15:0] rx_data;
    logic [15:0] tx_data;

    slv_selected = psel & penable;
    always_comb begin : DECODE
        reg000_en = 0;
        reg008_en = 0;
        reg018_en = 0;
        decode_err = 0;
        case (paddr)
            12'h000: reg000_en = 1;
            12'h008: reg008_en = 1;
            12'h018: reg018_en = 1;
            default: decode_err = 1;
        endcase
    end

    assign reg000_ren = reg000_en & slv_selected;
    assign reg008_ren = reg008_en & slv_selected;
    assign reg018_ren = reg018_en & slv_selected;

    assign reg000_wen = reg000_en & pwrtie & slv_selected;
    assign reg008_wen = reg008_en & pwrtie & slv_selected;
    assign reg018_wen = reg018_en & pwrtie & slv_selected;

    always @(posedge clk or negedge rstn) begin
        if(~rstn) begin
            intr_msk <= '1;
            intr_src <= '0;
        end 
        else if(reg000_wen) begin
            intr_msk <= pwdata[23:15];
            intr_src <= pwdata[7:0];
        end
    end

    always @(posedge clk or negedge rstn) begin
        if(~rstn) begin
            tx_ctrl <= '0;
            tx_data <= '0;
        end
        else if (reg018_wen) begin
            tx_ctrl <= pwdata[31:24];
            tx_data <= pwdata[15:0];
        end
    end

    always @(posedge clk or negedge rstn) begin
        if(~rstn) begin
            rx_ctrl <= '0;
            rx_data <= '0;
        end
        else if (reg018_wen) begin
            rx_ctrl <= pwdata[31:24];
            rx_data <= pwdata[15:0];
        end
    end

    always_ff @( posedge clk or negedge rstn ) begin
        if(~rstn) begin
            pready <= '0;
            pslverr <= '0;
            prdata <= '0;
        end
        else if(slv_selected) begin
            pready <= slv_selected;
            pslverr <= decode_err;
            prdata <= prdata_nxt;
        end
    end

    always_comb begin : RDATA
        case (paddr)
            12'h0: prdata_nxt = { 8'h0, intr_msk, 8'h0, intr_src};
            12'h8: prdata_nxt = {tx_ctrl, 8'h0, tx_data};
            12'h18: prdata_nxt = {rx_ctrl, 8'h0, rx_data};
            default: prdata_nxt = prdata;
        endcase
    end
    
endmodule