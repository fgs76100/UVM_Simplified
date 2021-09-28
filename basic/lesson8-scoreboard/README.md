# Lesson8 - Scoreboard

> A crucial element of a self-checking environment is the scoreboard. Typically, a scoreboard verifies the proper operation of your design at a functional level. The responsibility of a scoreboard varies greatly depending on the implementation

First, we need to add the TLM `uvm_analysis_port` to the monitor.
### `apb_monitor.sv`

 ```systemverilog
 class apb_monitor extends uvm_monitor;

    ...
    uvm_analysis_port#(apb_data_item) item_collected_port;

    virtual function void build_phase(uvm_phase phase);
        ...
        this.item_collected_port = new("item_collected_port", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);
        forever begin
            ... 
            this.item_collected_port.write(tr);
        end
    endtask: run_phase

    ...

endclass: apb_monitor
 ```

### `tb_scoreboard.sv`

```systemverilog

class tb_scoreboard extends uvm_scoreboard;

    uvm_analysis_imp#(apb_data_item, tb_scoreboard) item_collected_export;
    `uvm_component_utils(tb_scoreboard)

    int sbd_error = 0;

    protected int unsigned m_mem_expected[int unsigned];

    // constructor
    function new (string name, uvm_component parent);
        super.new(name, parent);
    endfunction : new

    // build_phase
    function void build_phase(uvm_phase phase);
        this.item_collected_export = new("item_collected_export", this);
    endfunction

    // write
    virtual function void write(apb_data_item tr);
        // not implemented yet
    endfunction : write

endclass : tb_scoreboard

```

In the example shown above, the scoreboard requires only one port to communicate with the
environment. Since the monitor in the environment have provided an analysis port `write()` interface via the TLM `uvm_analysis_port`, the scoreboard will provide the TLM `uvm_analysis_imp`


### `tb_env.sv`
Now, adding the scoreboard to the environment

```systemverilog
class tb_env extends uvm_env;

    `uvm_component_utils(tb_env)
    apb_config apb_conf;
    apb_env apb_mst_env;
    tb_scoreboard scoreboard;

    function new(string name, uvm_component parent=null);
        super.new(name, parent);
    endfunction: new

    virtual function void build_phase(uvm_phase phase);
        ...
        this.scoreboard = tb_scoreboard::type_id::create("scoreboard", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        // Connect monitor to scoreboard
        apb_mst_env.apb_mst_agent.apb_mon.item_collected_port.connect(
            scoreboard.item_collected_export
        );
    endfunction : connect_phase

endclass: tb_env
```

Implementing the write function to verify the degin at the function level.
### `tb_scoreboard.sv`

```systemverilog

class tb_scoreboard extends uvm_scoreboard;
    ...
    // implement the write function
    virtual function void write(apb_data_item tr);
    if (m_mem_expected.exists(tr.addr)) begin
        // access to existing address
        if(tr.cmd == apb_data_item::WRITE) begin
            m_mem_expected[tr.addr] = tr.data;
            `uvm_info(
                this.get_type_name(),
                $sformatf("override address(0x%0h) with data %0h", tr.addr, tr.data),
                UVM_MEDIUM
            )
        end
        if(tr.cmd == apb_data_item::READ) begin
            // verify the read data
            if(m_mem_expected[tr.addr] !== tr.data) begin
                `uvm_error(this.get_type_name(),
                    $sformatf("Read data mismatch: expecting: 0x%0h, got 0x%0h instead",
                        m_mem_expected[tr.addr],
                        tr.data
                    )
                )
            end
        end
    end
    else begin
        // access to empty address
        if(tr.cmd == apb_data_item::READ) begin
            `uvm_info(
                this.get_type_name(),
                $sformatf("Warning: read to unwritten address(0x%0h)", tr.addr),
                UVM_LOW
            )
        end
        m_mem_expected[tr.addr] = tr.data;
        `uvm_info(
            this.get_type_name(),
            $sformatf("update address(0x%0h) with data %0h", tr.addr, tr.data),
            UVM_MEDIUM
        )
    end
    endfunction : write

endclass : tb_scoreboard

```

Previously, in the lesson 4 - sequence, we check the correctness of function inside the sequence.
But with the implementation of the scoreboard, we don't need to do that anymore and creating a sequence is easier than before.

### `apb_seqlib.sv`

```systemverilog
class apb_read_burst extends apb_base_sequence;
    `uvm_object_utils(apb_read_burst)

    apb_read apb_read0;
    rand int unsigned burst;

    // note that always assign a default value to input "name" if using uvm_object
    function new (string name = "apb_read_burst");
        super.new(name);
    endfunction

    virtual task body();
        for(int i=0; i < this.burst; i+=1) begin: iter_seq
            `uvm_do_with(
                this.apb_read0,
                {
                    apb_read0.start_address == local::start_address;
                }
            )
            start_address += 4;
        end
    endtask
endclass

class apb_write_burst extends apb_base_sequence;
    `uvm_object_utils(apb_write_burst)

    apb_write apb_write0;
    rand int unsigned burst;

    // note that always assign a default value to input "name" if using uvm_object
    function new (string name = "apb_write_burst");
        super.new(name);
    endfunction

    virtual task body();
        for(int i=0; i < this.burst; i+=1) begin: iter_seq
            `uvm_do_with(
                this.apb_write0,
                {
                    apb_write0.start_address == local::start_address;
                }
            )
            start_address += 4;
        end
    endtask
endclass

class apb_war_burst extends apb_base_sequence;
    `uvm_object_utils(apb_war_burst)

    apb_read_burst apb_read_burst0;
    apb_write_burst apb_write_burst0;
    rand int unsigned burst;
    constraint burst_c { burst <= 64; burst >= 1;};
    constraint start_address_c { start_address == 'h100; };

    // note that always assign a default value to input "name" if using uvm_object
    function new (string name = "apb_war_burst");
        super.new(name);
    endfunction

    virtual task body();
        // because scoreboard will check the function behavior,
        // we don't have to compare write data and read data anymore
        `uvm_do_with(
            this.apb_write_burst0,
            {
                start_address == local::start_address;
                burst == local::burst;
            }
        )
        `uvm_do_with(
            this.apb_read_burst0,
            {
                start_address == local::start_address;
                burst == local::burst;
            }
        )
    endtask
endclass

```

## run test

```bash
[simulator] ... +UVM_TESTNAME=apb_master_basetest +APB_SEQNAME=apb_war_burst