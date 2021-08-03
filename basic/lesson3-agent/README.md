# Lesson3 - agent

In this lesson, we are going to create a apb master agent, but without the monitor.

## Sequencer
First, we create an apb sequencer
### `apb_sequencer.sv`
```systemverilog
// here we just use build-in sequencer because there is no need to create a new class by ourself
typedef uvm_sequencer #(apb_data_item) apb_sequencer;
```

The quote from UVM user guide
> The only time it is necessary to extend the uvm_sequencer class is if you
need to add additional functionality, such as additional ports.

So in this lesson, we should just instantiate the UVM sequencer directly.

## Agent
Now we create an apb agent to wrap the driver and the sequencer and connect them via TLM. For more details about TLM, please check the UVM user guide.
### `apb_master_agent.sv`
```systemverilog
class apb_master_agent extends uvm_agent;

    `uvm_component_utils(apb_master_agent)
    apb_master_driver apb_drv;
    apb_sequencer apb_seqr;

    function new(string name, uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        if( this.get_is_active() ) begin
            this.apb_drv = apb_master_driver::type_id::create("apb_driver", this);
            this.apb_seqr = apb_sequencer::type_id::create("apb_seqr", this);
        end
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        if( this.get_is_active() ) begin
            // The driver and the sequencer are connected via TLM, 
            // with the driver’s seq_item_port connected to the sequencer’s seq_item_export
            this.apb_drv.seq_item_port.connect(this.apb_seqr.seq_item_export);
        end
    endfunction

endclass
```

## Driver
Here we will add more codes to the run phase task of apb driver so that apb driver could receive the date item from sequencer

### `apb_master_driver.sv`
```systemverilog
class apb_master_driver extends uvm_driver #(apb_data_item);

    ... ...

    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);

        this.apb_if.psel    <= '0;
        this.apb_if.penable <= '0;

        forever begin
            apb_data_item tr, rsp;
            // get the data item from sequencer
            seq_item_port.get_next_item(tr);  // get_next_item() is blocking.
            if(tr.cmd == apb_data_item::READ) 
                this.drive_read(tr, rsp);
            else
                this.drive_write(tr, rsp);

            seq_item_port.item_done();
            seq_item_port.put_response(rsp); // optionally puts response 
        end
    endtask

    ... ...

endclass
```

Let’s recap what happens in this code:
1. the driver uses `get_next_item()` to fetch the next data item.
2. After sending it to the DUT, the driver informs the sequencer that the item was processed using `item_done()`
3. optionally, driver could send the response to sequencer using `put_response()`


>put_response() is a blocking method, so the sequence must do a corresponding get_response(rsp).


## Sequences

a copypasta from UVM user guide
> Sequences are made up of several data items, which together form an interesting scenario or pattern of data.
Verification components can include a library of basic sequences (instead of single-data items), which test
writers can invoke. This approach enhances reuse of common stimulus patterns and reduces the length of
tests. In addition, a sequence can call upon other sequences, thereby creating more complex scenarios.

let's create a base sequence for reuse.

### `apb_base_sequence`

```systemverilog
class apb_base_sequence extends uvm_sequence #(apb_data_item);

    `uvm_object_utils(apb_base_sequence)
    rand bit [11:0] start_address;

    // note that always assign a default value to input "name"
    function new (string name = "apb_base_sequence");
        super.new(name);
        this.start_address = '0;
    endfunction

    // Raise in pre_body so the objection is only raised for root sequences.
    // There is no need to raise for sub-sequences since the root sequence
    // will encapsulate the sub-sequence. 
    virtual task pre_body();
      if (this.starting_phase!=null)
         this.starting_phase.raise_objection(this);
    endtask

    virtual function void set_start_address(bit [11:0] start_address);
        this.start_address = start_address;
    endfunction

    // The body() task is the actual logic of the sequence.
    virtual task body();
        this.req = apb_data_item::type_id::create("item");
        this.start_item(this.req);
        if(
            !this.req.randomize() with {
                addr == start_address;
            }
        )
            `uvm_error(this.get_type_name(), "randomization failed")

        this.finish_item(this.req);
        this.get_response(this.rsp);  // optional
        `uvm_info(this.get_type_name(), this.rsp.convert2string(), UVM_MEDIUM)
    endtask

    // Drop the objection in the post_body so the objection is removed when
    // the root sequence is complete. 
    virtual task post_body();
        if (starting_phase!=null)
            starting_phase.drop_objection(this);
    endtask

endclass
```

let's recap what happens in the `body` task, where you specify how the sequences to be executed

1. we create the data item `this.req` through UVM factory.
2. register the requeset using `start_item(this.req)`
3. randomize the data item
4. send the data item invoking `finish_item(this.req)`
5. optionally, use `get_reponse(this.rsp)` to get response from the driver.

## APB package

you shall always pack all dependencies together inside a package.
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
endpackage: apb_pkg
```

## Test
Now, create a test to execute the sequence on the sequencer using `apb_seq.start(apb_seqr)`
### `apb_master_basetest.sv`

```systemverilog
class apb_master_basetest extends uvm_test;
    // register "apb_master_basetest" to UVM factory
    `uvm_component_utils(apb_master_basetest)
    apb_master_agent apb_mst_agent;
    apb_base_sequence apb_seq;

    // constructor
    function new(string name = "apb_master_basetest", uvm_component parent=null);
        super.new(name, parent);
    endfunction : new

    virtual function void build_phase(uvm_phase phase);
        // instead of calling new() to create a new object, 
        // here we create a object through UVM factory by invoking class::type_id::create()
        this.apb_mst_agent = apb_master_agent::type_id::create("apb_mst_agent", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        // raise objection to avoid task be terminated abruptly
        phase.raise_objection(this);
        wait($root.tb.rstn);  // wait the de-assertion of rstn

        `uvm_info( this.get_type_name(), "do master driver test", UVM_MEDIUM)
        repeat(5) @(posedge $root.tb.clk200M);

        this.apb_seq = apb_base_sequence::type_id::create("apb_seq");
        this.apb_seq.set_start_address(12'h100);
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

module tb;

    ...

endmodule
```

## run test

```bash
[simulator] -f ../common.f apb_pkg.sv tb.sv +UVM_TESTNAME=apb_master_basetest [other options]
```