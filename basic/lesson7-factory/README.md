# Factory

Previously, in the lesson4, we created a sub class `apb_master_raw_test.sv` from the base class `apb_master_basetest.sv` for just replacing `apb_base_sequence` with `apb_read_after_write`. We only want to make a tiny change, but we almost re-write whole base class. Here is where `uvm_facotry` comes in handy.

From the beginning of lesson, we register every component to `uvm_factory` using `` `uvm_component_utils`` or `` `uvm_object_utils``. Also, we create every component from the `uvm_factory` using `object_type::type_id::create(...)`. Becuase `uvm_factory` controls the creation of the object, we can override any reference to a specific object or a object type using `object_type::type_id::set_type_override` or `object_type::type_id::set_inst_override`

Here we will override the `apb_base_sequence` as a example. First, we should modify the `apb_master_basetest.sv` to make it more generic.

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
        if(!this.apb_seq.randomize()) `uvm_error(this.get_type_name(), "randomize faile...")
        this.apb_seq.start(this.tb.apb_mst_env.apb_mst_agent.apb_seqr);  // blocking

        repeat(5) @(posedge $root.tb.clk200M);

        // must drop objection when task is done, otherwise this run phase will not be terminated
        phase.drop_objection(this);
    endtask : run_phase

endclass
```

Here we override the type of apb_base_sequence using `set_type_override`.

```systemverilog
class apb_master_raw_test1 extends apb_master_basetest;
    // register "apb_master_basetest" to UVM factory
    `uvm_component_utils(apb_master_raw_test)

    // constructor
    function new(string name = "apb_master_raw_test1", uvm_component parent=null);
        super.new(name, parent);
    endfunction : new

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // affect all of creations of apb_base_sequence
        apb_base_sequence::type_id::set_type_override(apb_read_after_write::get_type());
    endfunction

endclass
```

If you only want to override a specific instance, you could use `set_inst_override` instead.
> Note that you can get the scope of a instance using instance.get_full_name()

```systemverilog
class apb_master_raw_test2 extends apb_master_basetest;

    ... 

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // or you only want to affect a specific instance
        apb_base_sequence::type_id::set_inst_override(
            apb_read_after_write::get_type(),  // type
            "apb_seq"  // the scope where the instance is declared
        );
    endfunction

endclass
```

Or even further, we can specify which type to override from the command line interface using `uvm_cmdline_processor` and `uvm_factory` without extending `apb_master_basetest`

 ```systemverilog
class apb_master_basetest extends uvm_test;

    ... ...
    uvm_cmdline_processor clp;
    uvm_factory factory;

    virtual function void build_phase(uvm_phase phase);
        string apb_seq_name;

        ... ...
        
        this.clp = uvm_cmdline_processor::get_inst();
        if(this.clp.get_arg_value("+APB_SEQNAME=", apb_seq_name)) begin
            this.factory = uvm_factory::get();
            
            apb_base_sequence::type_id::set_type_override(
                this.factory.find_by_name(apb_seq_name)
            );
            // or you can use the method "set_type_override_by_name" in the uvm_factory instead
            // this.factory.set_type_override_by_name("apb_base_sequence", apb_seq_name)

            // or only affect a specify instance using set_inst_override_by_name
            // this.factory.set_inst_override_by_name(
            //    "apb_base_sequence", apb_seq_name, "apb_seq"
            // )

        end
    endfunction

    ... ...

endclass
```

Now, we can specify the sequence from the command line interface by `+APB_SEQNAME=apb_read_after_write`

 ## run test

```bash
[simulator] ... +UVM_TESTNAME=apb_master_basetest +APB_SEQNAME=apb_read_after_write
```

There is another way to run the sequence by assigning the sequence to the default sequecne of the sequencer


 ```systemverilog
class apb_master_seqr_basetest extends uvm_test;
    `uvm_component_utils(apb_master_seqr_basetest)
    tb_env tb;
    // constructor
    function new(string name = "apb_master_seqr_basetest", uvm_component parent=null);
        super.new(name, parent);
    endfunction : new

    virtual function void build_phase(uvm_phase phase);
        this.tb = tb_env::type_id::create("tb_env", this);
    endfunction

endclass

class apb_master_seqr_raw_test extends apb_master_seqr_basetest;
    `uvm_component_utils(apb_master_seqr_raw_test)
    // constructor
    function new(string name = "apb_master_seqr_raw_test", uvm_component parent=null);
        super.new(name, parent);
    endfunction : new

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        uvm_config_db#(uvm_object_wrapper)::set(
            this,
            "tb_env.apb_mst_env.apb_mst_agent.apb_seqr.run_phase", 
            "default_sequence",
            apb_read_after_write::type_id::get()
        );
    endfunction

endclass
```

 ## run test

```bash
[simulator] ... +UVM_TESTNAME=apb_master_seqr_raw_test