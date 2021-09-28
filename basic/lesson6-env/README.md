# Lesson6 - Environment

>The environment class is the top container of reusable components. It instantiates and configures all of its
subcomponents. Most verification reuse occurs at the environment level where the user instantiates an
environment class and configures it and its agents for specific verification tasks

In is lesson, we gonna pretend there is another `apb_slave_agent` and we will use a `apb_config` to decide on apb_env will have master agent, a slave agent or both.

The testbench hierarchy:
- testbench
  - apb_if (apb interface)
  - DUT
  - uvm_test_top (apb_master_basetest)
    - tb_env
        - apb_mst_env
            - apb_master_agent
                - apb_sequencer
                - apb_master_driver
                - apb_monitor
    - apb_base_sequence
    - apb_seqlib
        - apb_write
        - apb_read
        - apb_read_after_write

### `apb_config.sv`
```systemverilog
class apb_config extends uvm_object;

   typedef enum bit {DISABLED=0, ENABLED=1} switch_e;

   `uvm_object_utils(apb_config)
   switch_e enable_mst = DISABLED;
   switch_e enable_slv = DISABLED;

  function new(string name="apb_config");
     super.new(name);
  endfunction

endclass
```

### `apb_env.sv`

```systemverilog

class apb_slave_agent extends uvm_agent;
    `uvm_component_utils(apb_slave_agent)
    function new(string name, uvm_component parent=null);
        super.new(name, parent);
    endfunction: new
endclass: apb_slave_agent

class apb_env extends uvm_env;

    `uvm_component_utils(apb_env)
    apb_master_agent apb_mst_agent;
    apb_slave_agent apb_slv_agent;
    apb_config apb_conf;

    function new(string name, uvm_component parent=null);
        super.new(name, parent);
    endfunction: new
    
    virtual function void build_phase(uvm_phase phase);
        if( apb_conf == null ) begin
            `uvm_fatal(this.get_type_name(), "apb_config was not specified")
        end

        if( apb_conf.enable_mst)
            this.apb_mst_agent = apb_master_agent::type_id::create("apb_master_agent", this);
        if( apb_conf.enable_slv)
            this.apb_slv_agent = apb_slave_agent::type_id::create("apb_slave_agent", this);

    endfunction: build_phase

endclass: apb_env
```

Meanwhile, we create another class `tb_env.sv` to represent the root of all enironments and agents.

### `tb_env.sv`

```systemverilog
class tb_env extends uvm_env;

    `uvm_component_utils(tb_env)
    apb_config apb_conf;
    apb_env apb_mst_env;

    function new(string name, uvm_component parent=null);
        super.new(name, parent);
    endfunction: new

    virtual function void build_phase(uvm_phase phase);
        this.apb_conf = new();
        this.apb_conf.enable_mst = apb_config::ENABLED;
        this.apb_mst_env = apb_env::type_id::create("apb_mst_env", this);
        this.apb_mst_env.apb_conf = apb_conf;
    endfunction

endclass: tb_env
```

In the `apb_master_basetest`, we now instantiate the `tb_env` instead of `apb_mastet_agent`.

### `apb_master_basetest.sv`

 ```systemverilog
class apb_master_basetest extends uvm_test;
    // register "apb_master_basetest" to UVM factory
    `uvm_component_utils(apb_master_basetest)
    
    tb_env tb;
    apb_base_sequence apb_seq;
    
    // constructor
    function new(string name = "apb_master_basetest", uvm_component parent=null);
        super.new(name, parent);
    endfunction : new

    virtual function void build_phase(uvm_phase phase);
        this.tb = tb_env::type_id::create("tb_env", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        // raise objection to avoid task be terminated abruptly
        phase.raise_objection(this);
        wait($root.tb.rstn);  // wait the de-assertion of rstn

        `uvm_info( this.get_type_name(), "do master driver test", UVM_MEDIUM)
        repeat(5) @(posedge $root.tb.clk200M);

        this.apb_seq = apb_base_sequence::type_id::create("apb_seq");
        this.apb_seq.set_start_address(12'h100);
        this.apb_seq.start(this.tb.apb_mst_env.apb_mst_agent.apb_seqr);  // blocking

        repeat(5) @(posedge $root.tb.clk200M);

        // must drop objection when task is done, otherwise this run phase will not be terminated
        phase.drop_objection(this);
    endtask : run_phase

endclass
```

Because we change the hierarchy of `apb_master_agent`, so we have to modify the instance name in the `tb.sv` as well.

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
            "uvm_test_top.tb.apb_mst_env.apb_mst_agent",  // instance name(hierachy) relative to context
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
[simulator] ... +UVM_TESTNAME=apb_master_raw_test [other options]
```
