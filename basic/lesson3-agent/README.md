### `apb_master_driver.sv`

```systemverilog
typedef virtual apb_if apb_vif;

class apb_master_driver extends uvm_driver #(apb_data_item);

    `uvm_component_utils(apb_master_driver)
  
    apb_vif apb_if;

    function new(string name,uvm_component parent = null);
        super.new(name,parent);
    endfunction
    
    virtual function void build_phase(uvm_phase phase);
        if (!uvm_config_db#(apb_vif)::get(this, "", "apb_if", apb_if)) begin
            `uvm_fatal("NOVIF", "No such virtual interface")
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);

        this.apb_if.psel    <= '0;
        this.apb_if.penable <= '0;

        forever begin
            apb_data_item tr, rsp;
            seq_item_port.get_next_item(tr);
            rsp = new tr;  // do shallow copy
            if(tr.cmd == apb_data_item::READ) 
                this.drive_read(tr, rsp);
            else
                this.drive_write(tr, rsp);

            seq_item_port.item_done(tr);
            seq_item_port.put(rsp); // optionally puts response 
        end
    endtask

    virtual task drive_read(const ref apb_data_item tr, const ref apb_data_item rsp);
        this.apb_if.psel <= 1;
        this.apb_if.paddr <= tr.addr;
        this.apb_if.pwrite <= 0;
        @(posedge this.apb_if.clk);
        this.apb_if.penable <= 1;

        @(posedge this.apb_if.pready);
        @(posedge this.apb_if.clk);
        rsp.slverr = this.apb_if.pslverr;
        rsp.data = this.apb_if.prdata;
        this.apb_if.penable <= 0;
        this.apb_if.psel <= 0;

    endtask
    virtual task drive_write(const ref apb_data_item tr, const ref apb_data_item rsp);
        this.apb_if.psel <= 1;
        this.apb_if.paddr <= tr.addr;
        this.apb_if.pwrite <= 1;
        @(posedge this.apb_if.clk);
        this.apb_if.penable <= 1;
        this.apb_if.pwdata <= tr.data;

        @(posedge this.apb_if.pready);
        @(posedge this.apb_if.clk);
        rsp.slverr = this.apb_if.pslverr;
        this.apb_if.penable <= 0;
        this.apb_if.psel <= 0;
    endtask
endclass
```