# Lesson5 - Monitor

Quote from UVM user guide
>The monitor is responsible for extracting signal information from the bus and translating it into events,
structs, and status information. The monitor functionality should be limited to basic monitoring that is always required. This can include
protocol checking—which should be configurable so it can be enabled or disabled—and coverage
collection

 In this tutorial, we are not going to dive into coverage collectoin.

The testbench hierarchy:
- testbench
  - apb_if (apb interface)
  - DUT
  - uvm_test_top (apb_master_basetest)
    - apb_master_agent
        - apb_sequencer
        - apb_master_driver
        - apb_monitor
    - apb_base_sequence
    - apb_seqlib
        - apb_write
        - apb_read
        - apb_read_after_write


 ### `apb_monitor.sv`
 ```systemverilog
 class apb_monitor extends uvm_monitor;

   apb_vif apb_if;

   `uvm_component_utils(apb_monitor)

   function new(string name, uvm_component parent = null);
      super.new(name, parent);
   endfunction: new

   virtual function void build_phase(uvm_phase phase);
     // we should assign apb_if from the parent(agent) from now on,
     // but if not(this.apb_if is null), get it from uvm_config_db instead.
     if(this.apb_if == null) begin
        if (!uvm_config_db#(apb_vif)::get(this, "", "apb_if", apb_if)) begin
            `uvm_fatal(this.get_type_name(), "No virtual interface specified for this monitor instance")
        end
     end
   endfunction

   virtual task run_phase(uvm_phase phase);
      super.run_phase(phase);
      forever begin
         apb_data_item tr;
         
         // Wait for a SETUP cycle
         do begin
            @ (this.apb_if.clk);
         end
         while (this.apb_if.psel !== 1'b1 ||
                this.apb_if.penable !== 1'b0);

         tr = apb_data_item::type_id::create("tr");
         
         tr.cmd = (this.apb_if.pwrite) ? apb_data_item::WRITE : 
                                         apb_data_item::READ;
         tr.addr = this.apb_if.paddr;

         @ (this.apb_if.clk);
         if (this.apb_if.penable !== 1'b1) begin
            `uvm_error("APB", "APB protocol violation: SETUP cycle not followed by ENABLE cycle");
         end

         @(this.apb_if.pready);
         tr.data = (tr.cmd == apb_data_item::READ) ? this.apb_if.prdata :
                                                      this.apb_if.pwdata;
         this.trans_observed(tr);
      end
   endtask: run_phase

    virtual task trans_observed(apb_data_item tr);
      `uvm_info(this.get_type_name(), tr.convert2string(), UVM_MEDIUM)
   endtask

endclass: apb_monitor
 ```

 Because the driver and the monitor share same interface, the agent should get `apb_if` from the `uvm_config_db` and then assign the `apb_if` to it's children.

 ### `apb_master_agent.sv`
 ```systemverilog
 class apb_master_agent extends uvm_agent;

    ... ...
    apb_vif apb_if;
    apb_monitor apb_mon;

    virtual function void build_phase(uvm_phase phase);

        ... ...

        this.apb_mon = apb_monitor::type_id::create("apb_monitor", this);

        if (!uvm_config_db#(apb_vif)::get(this, "", "apb_if", apb_if)) begin
            `uvm_fatal("NOVIF", "No such virtual interface")
        end
        // here we assign apb_if to children
        this.apb_mon.apb_if = this.apb_if;
        this.apb_drv.apb_if = this.apb_if;
    endfunction

    ... ... 

endclass
 ```

We have to revise `apb_master_driver` as well.

 ### `apb_master_driver.sv`
 ```systemverilog
class apb_master_driver extends uvm_driver #(apb_data_item);

    ... ...
    
    virtual function void build_phase(uvm_phase phase);
        // if apb_if was not assigned from the parent, get it from uvm_config_db instead
        if(this.apb_if == null) begin
            if (!uvm_config_db#(apb_vif)::get(this, "", "apb_if", apb_if)) begin
                `uvm_fatal("NOVIF", "No such virtual interface")
            end
        end
    endfunction

    ... ...

endclass
```

We also modify the `tb.sv` to set `apb_if` to correct hierachy. Previously, we assign a wildcard(`*`) to instace name (laziness), but now we explicity assign `uvm_test_top.apb_mst_agent` to it.

>The topmost `uvm_test` will always be assigned the name `uvm_test_top`

### `tb.sv`

```systemverilog

... ...

module tb;

    ... ...

    initial begin: UVM
        // set apb_if0 object to UVM database, so driver could retrieve it from another scope.
        // the scope you assign to is equal to {context, '.', instance_name}
        uvm_config_db #(apb_vif)::set(
            null,  // context
            "uvm_test_top.apb_mst_agent",  // instance name(hierachy) relative to context
            "apb_if",  // key or field
            apb_if0  // value
        );
        // if context is null, then you shall specify full scope(hierachy) from the root(uvm_test)
        
        run_test();
    end

endmodule
```

 ## run test

```bash
[simulator] -f ../common.f apb_pkg.sv tb.sv +UVM_TESTNAME=apb_master_raw_test [other options]
```
