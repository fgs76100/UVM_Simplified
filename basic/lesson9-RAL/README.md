# Lesson9 - Register Abstraction Layer (RAL)

> The UVM register layer defines several base classes that abstract the read/write operations to registers and memories in a DUT.

It is recommended to generate the UVM register model using code generator. Unless you are going to build code generator by yourself, you don't have to dive into all of the details. Here we only go through how to use register model instead of building one.

The example of register block has following hierarchy
- CHIP_TOP (reg_blk)
    - APB_SLAVE (reg_blk)
        - APB_ISR (reg)
        - APB_CTRL0 (reg)
        - APB_CTRL1 (reg)

### `ral.sv`
```systemverilog
class APB_ISR extends uvm_reg;

    uvm_reg_field MASK;
    uvm_reg_field INTR;

    function new(string name = "APB_ISR");
        super.new(
            name,
            32,     // the total number of bits in this register
            UVM_NO_COVERAGE     // has coverage
        );
    endfunction

    virtual function void build();
        
        this.INTR = uvm_reg_field::type_id::create("INTR");
        this.MASK = uvm_reg_field::type_id::create("MASK");

        this.INTR.configure(
            this,   // parent
            8,      // size
            0,      // LSB position
            "RW",   // access
            0,      // volatile
            8'h0,   // reset value
            1,      // has reset (if false, reset value is ignored)
            0,      // can be randomized not or
            1       // is the only one to occupy a byte lane (individually_accessible)
        );
        this.MASK.configure(this, 8,  15, "RW",  0, 8'hFF, 1, 0, 1);
    endfunction

    `uvm_object_utils(APB_ISR)

endclass

class APB_CTRL extends uvm_reg;

    uvm_reg_field CTRL;
    uvm_reg_field DATA;

    function new(string name = "APB_CTRL");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        
        this.DATA = uvm_reg_field::type_id::create("DATA");
        this.CTRL = uvm_reg_field::type_id::create("CTRL");

        this.DATA.configure(this, 16,  0, "RW",  0, 16'h0, 1, 0, 0);
        this.CTRL.configure(this, 8,  24, "RW",  0,  8'h0, 1, 0, 1);
    endfunction

    `uvm_object_utils(APB_CTRL)

endclass

class APB_SLAVE_REG_BLK extends uvm_reg_block;
    APB_ISR ISR;
    APB_CTRL CTRL0;
    APB_CTRL CTRL1;

    `uvm_object_utils(APB_SLAVE_REG_BLK)

    function new(string name = "APB_SLAVE_REG_BLK");
        super.new(
            name,
            UVM_NO_COVERAGE
        );
    endfunction

    virtual function void build();
        // create
        this.ISR = APB_ISR::type_id::create("ISR");
        this.CTRL0 = APB_CTRL::type_id::create("CTRL0");
        this.CTRL1 = APB_CTRL::type_id::create("CTRL1");

        // configure
        this.ISR.configure(
            this,   // the parent if using uvm_reg_block
            null,   // the parent if using uvm_ref_file
            ""      // HDL path
        );
        this.CTRL0.configure(this, null, "");
        this.CTRL1.configure(this, null, "");

        // build
        this.ISR.build();
        this.CTRL0.build();
        this.CTRL1.build();


        // define default map
        this.default_map = create_map(
            "default_map",      // name
            'h0,                // base address
            4,                  // byte-width of the bus
            UVM_LITTLE_ENDIAN,  // endian
            0                   // whether consecutive addresses refer 
                                // are 1 byte apart (TRUE) or n_bytes apart (FALSE)
        );
        //                       reg         offset
        this.default_map.add_reg(this.ISR,   'h0);
        this.default_map.add_reg(this.CTRL0, 'h8);
        this.default_map.add_reg(this.CTRL1, 'h18);
    endfunction

endclass

class CHIP_TOP_REG_BLK extends uvm_reg_block;
    APB_SLAVE_REG_BLK APB_SLAVE;
    `uvm_object_utils(CHIP_TOP_REG_BLK)

    function new(string name = "CHIP_TOP_REG_BLK");
        super.new( name, UVM_NO_COVERAGE );
    endfunction

    virtual function void build();
        this.default_map = create_map("default_map", 0, 4, UVM_LITTLE_ENDIAN, 0);

        this.APB_SLAVE = APB_SLAVE_REG_BLK::type_id::create("APB_SLAVE");
        this.APB_SLAVE.configure(
            this,   // parent, must be uvm_reg_block
            ""      // HDL path
        );
        this.APB_SLAVE.build();
        this.default_map.add_submap(
            this.APB_SLAVE.default_map,  // child map
            'h0     // offset or base address
        );
    endfunction
endclass
```

## How to Integrat a Register Model

First, we need to create a adapter for converting one protocal to another.

### `reg2apb_adapter.sv`

```systemverilog
class reg2apb_adapter extends uvm_reg_adapter;

    `uvm_object_utils(reg2apb_adapter)

    function new(string name="reg2apb_adapter");
        super.new(name);
        // this.supports_byte_enables = 0;
        // this.provides_responses = 1;
    endfunction

    virtual function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);
        apb_DATA_item apb = apb_DATA_item::type_id::create("apb_DATA_item");
        apb.cmd = (rw.kind == UVM_READ) ? apb_DATA_item::READ : apb_DATA_item::WRITE;
        apb.addr = rw.addr;
        apb.data = rw.data;
        return apb;
    endfunction

    virtual function void bus2reg(uvm_sequence_item bus_item, ref uvm_reg_bus_op rw);
        apb_DATA_item apb;
        if (!$cast(apb, bus_item)) begin
            `uvm_fatal("NOT_APB_TYPE", "Provided bus_item is not of the correct type")
        end
        rw.status = UVM_IS_OK;
        rw.kind = apb.cmd == apb_DATA_item::READ ? UVM_READ : UVM_WRITE;
        rw.addr = apb.addr;
        rw.data = apb.data;
    endfunction
endclass
```

### Integrating Bus Sequencers

There 3 methods to do this:
1. directly on a bus sequencer, if there is only one bus interface providing access to the DUT registers.
2. as a virtual sequence, if there are one or more bus interfaces providing access to the DUT registers.
3. as a register sequence running on a generic, bus-independent sequencer, which is layered on top of a downstream bus sequencer.

Here only demonstrate method 1. For other approachs, you should look up section of the UVM user guide at 5.9.2

### `tb_env.sv`

```systemverilog
class tb_env extends uvm_env;
    ...
    CHIP_TOP_REG_BLK regmodel;

    virtual function void build_phase(uvm_phase phase);
        ...

        regmodel = CHIP_TOP_REG_BLK::type_id::create("regmodel");
        regmodel.build();
        regmodel.lock_model();
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        reg2apb_adapter reg2apb = reg2apb_adapter::type_id::create(
            "reg2apb_adapter"
        );

        ...

        // connect the adapter to apb sequencer
        regmodel.default_map.set_sequencer(
            this.apb_mst_env.apb_mst_agent.apb_seqr, reg2apb
        );
        regmodel.default_map.set_auto_predict(1);
    endfunction

endclass: tb_env
```

## Mirroring

The register model maintains two state of register value at the same time:
1. mirrored value
2. desired value

### mirrored value

The mirrored value is what the register model thinks the current value of registers is inside the DUT. The mirrored value is not guaranteed to be correct because the DUT could internally modifies the content of the register.

### desired value

The desired value is what user modifies the value of register field using `uvm_reg_field::set()` or `uvm_reg_field::get()` but without actual writing to the DUT. User could use `uvm_reg::update()` to write the desired value to the DUT (update the mirrored value as well). 
> When the mirrored value is updated, the desired value is updated as well.

Before creating a sequence, user should know how to use `Access API` to get the current value of a register or field and modify it.

## Access API

The following sections are copied from UVM user guide.

### read / write
The normal access API are the `read()` and `write()` methods. When using the front-door (path=BFM), one or more physical transactions is executed on the DUT to read or write the register. The mirrored value is then updated to reflect the expected value in the DUT register after the observed transactions.

### peek / poke
Using the `peek()` and `poke()` methods reads or writes directly to the register respectively, which bypasses the physical interface. The mirrored value is then updated to reflect the actual sampled or deposited value in the register after the observed transactions.

### get / set
Using the `get()` and `set()` methods reads or writes directly to the desired mirrored value respectively, without accessing the DUT. The desired value can subsequently be uploaded into the DUT using the update() method.

### update
Using the `update()` method invokes the `write()` method if the desired value (previously modified
using set() or randomize()) is different from the mirrored value. The mirrored value is then updated to reflect the expected value in the register after the executed transactions.

### mirror
Using the `mirror()` method invokes the `read()` method to update the mirrored value based on the
readback value. `mirror()` can also compare the readback value with the current mirrored value before updating it.


## The Sequence

Now, we can create a sequence using `uvm_reg_sequence`

### `reg_apb_seqlib.sv`

```systemverilog
class reg_apb_seq extends uvm_reg_sequence;
    CHIP_TOP_REG_BLK model;

    `uvm_object_utils(reg_apb_seq)

    function new(string name = "reg_apb_seq");
        super.new(name);
    endfunction: new

    virtual task body();
        uvm_status_e status;
        uvm_reg_DATA_t data;
        if(this.model == null) begin
            `uvm_fatal(this.get_type_name(), "No register model was specified")
        end
        this.model.APB_SLAVE.CTRL0.CTRL.set('h12);
        this.model.APB_SLAVE.CTRL0.DATA.set('hbeef);
        this.model.APB_SLAVE.CTRL0.update(status);

        this.model.APB_SLAVE.CTRL1.CTRL.set('h13);
        this.model.APB_SLAVE.CTRL1.DATA.set('hdead);
        this.model.APB_SLAVE.CTRL1.update(status);

        this.model.APB_SLAVE.CTRL0.read(status, data);
        this.model.APB_SLAVE.CTRL1.read(status, data);
    endtask
endclass 
```

### `apb_testlib.sv`

```systemverilog
class apb_master_reg_test extends apb_master_basetest;
    `uvm_component_utils(apb_master_reg_test)
    
    // constructor
    function new(string name = "apb_master_reg_test", uvm_component parent=null);
        super.new(name, parent);
    endfunction : new

    virtual task run_phase(uvm_phase phase);
        reg_apb_seq reg_seq;
        phase.raise_objection(this);

        reg_seq = reg_apb_seq::type_id::create("reg_seq");
        reg_seq.model = this.tb.regmodel;
        reg_seq.start(null);

        #100ns;
        phase.drop_objection(this);
    endtask

endclass
```

 ## run test

```bash
[simulator] ... +UVM_TESTNAME=apb_master_reg_test