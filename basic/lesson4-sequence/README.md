# Lesson4 - Sequences

In previous lesson, we develop a simple apb sequence. Now, in this lesson, we are going to extend it to create more sequences. The `apb_seqlib.sv` gonna contain all of available sequences.

The testbench hierarchy:
- testbench
  - apb_if (apb interface)
  - DUT
  - uvm_test_top (apb_master_basetest)
    - apb_master_agent
        - apb_sequencer
        - apb_master_driver
    - apb_base_sequence
    - apb_seqlib
        - apb_write
        - apb_read
        - apb_read_after_write


## `apb_seqlib.sv`

Here we create a single write sequence.

```systemverilog
class apb_write extends apb_base_sequence;
    `uvm_object_utils(apb_write)

    // note that always assign a default value to input "name" if using uvm_object
    function new (string name = "apb_write");
        super.new(name);
    endfunction

    virtual task body();
        this.req = apb_data_item::type_id::create("apb_data_item");
        this.start_item(this.req);

        if(
            !this.req.randomize() with {
                cmd == apb_data_item::WRITE;
                addr == local::start_address;
            }
        ) 
            `uvm_error(this.get_type_name(), "randomize failed")

        this.finish_item(this.req);
        this.get_response(this.rsp);
        this.check_resp();
    endtask
endclass
```

Here we create a single read sequence with UVM macro.

```systemverilog
class apb_read extends apb_base_sequence;
    `uvm_object_utils(apb_read)

    // note that always assign a default value to input "name" if using uvm_object
    function new (string name = "apb_read");
        super.new(name);
    endfunction

    virtual task body();
        // you can use uvm macro instead of writing all repetitive codes
        `uvm_do_with(
            this.req,
            {
                cmd == apb_data_item::READ;
                addr == local::start_address;
            }
        )
        /* 
        the preceding marco do following things:

        req = apb_data_item::type_id::create("apb_data_item");
        this.start_item(req);
        if(
            !req.randomize() with {
                cmd == apb_data_item::READ;
                addr == start_address;
            }
        ) 
            `uvm_warning(this.get_type_name(), "randomize failed with ...")
        this.finish_item(req);
        */

        this.get_response(this.rsp);
        this.check_resp();
    endtask
endclass
```
Now, we combine both write and read sequence above into a read-after-write sequence.

```systemverilog
class apb_read_after_write extends apb_base_sequence;
    `uvm_object_utils(apb_read_after_write)

    apb_write apb_write0;
    apb_read apb_read0;
    rand int unsigned iter;
    constraint iter_c { iter <= 64; iter >= 1;};
    constraint start_address_c { start_address == 'h100; };

    // note that always assign a default value to input "name" if using uvm_object
    function new (string name = "apb_read_after_write");
        super.new(name);
    endfunction

    virtual task body();
        `uvm_info(
            this.get_type_name(), 
            $sformatf(
                "start %0d iteration from address = %0h", 
                this.iter, 
                this.start_address
            ), 
            UVM_LOW
        )

        for(int i=0; i < this.iter; i+=1) begin: iter_seq
            `uvm_do_with(
                this.apb_write0,
                {
                    apb_write0.start_address == local::start_address;
                }
            )
            `uvm_do_with(
                this.apb_read0,
                {
                    apb_read0.start_address == local::start_address;
                }
            )
            if( this.apb_read0.rsp.data !== this.apb_write0.req.data) begin
                `uvm_error(
                    this.get_type_name(), 
                    $sformatf(
                        "expecting data = 0x%0h, got 0x%0h instead", 
                        this.apb_write0.req.data, 
                        this.apb_read0.rsp.data
                    )
                )
            end
            start_address += 4;
        end: iter_seq

    endtask
endclass
```

Because sequences are reusable, you should put it in the package along with other reusable components
### `apb_pkg.sv`
```systemverilog
package apb_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    `include "apb_data_item.sv"
    `include "apb_master_driver.sv"
    `include "apb_sequencer.sv"
    `include "apb_master_agent.sv"
    `include "apb_base_sequence.sv"
    `include "apb_seqlib.sv" // here
endpackage: apb_pkg
```

## `testlib.sv`

```systemverilog
class apb_master_raw_test extends apb_master_basetest;
    // register "apb_master_basetest" to UVM factory
    `uvm_component_utils(apb_master_raw_test)
    apb_read_after_write apb_seq;

    // constructor
    function new(string name = "apb_master_raw_test", uvm_component parent=null);
        super.new(name, parent);
    endfunction : new

    virtual task run_phase(uvm_phase phase);
        // raise objection to avoid task be terminated abruptly
        phase.raise_objection(this);
        wait($root.tb.rstn);  // wait the de-assertion of rstn

        `uvm_info( this.get_type_name(), "do master driver test", UVM_MEDIUM)
        repeat(5) @(posedge $root.tb.clk200M);

        this.apb_seq = apb_read_after_write::type_id::create("apb_seq");
        if(!this.apb_seq.randomize()) `uvm_error(this.get_type_name(), "randomize faile...")
        this.apb_seq.start(this.apb_mst_agent.apb_seqr);  // blocking

        repeat(5) @(posedge $root.tb.clk200M);

        // must drop objection when task is done, otherwise this run phase will not be terminated
        phase.drop_objection(this);
    endtask : run_phase

endclass
```


### `tb.sv`

```systemverilog

import uvm_pkg::*;
import apb_pkg::*;  // import your package

`include "uvm_macros.svh"
`include "apb_master_basetest.sv"  // include the test
`include "testlib.sv"  // include the test

module tb;

    ... ...

endmodule
```

## run test

```bash
[simulator] -f ../common.f apb_pkg.sv tb.sv +UVM_TESTNAME=apb_master_raw_test [other options]
```