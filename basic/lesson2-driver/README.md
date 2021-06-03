# Lesson2 - Driver

In this chapter, we gonna create a APB master driver to wiggle the signals on the APB interface.

The testbench hierarchy:

- testbench
  - uvm_test
    - apb_data_item (transaction)
    - apb_master_driver
  - apb_if (apb interface)
  - DUT

## Transaction

Before implement a driver, you should first implement the transaction base on design protocol.

### `apb_data_item.sv`

```systemverilog

   // `uvm_object_utils_begin(apb_rw)
   //   `uvm_field_int(addr, UVM_ALL_ON | UVM_NOPACK);
   //   `uvm_field_int(data, UVM_ALL_ON | UVM_NOPACK);
   //   `uvm_field_enum(kind_e,kind, UVM_ALL_ON | UVM_NOPACK);
   // `uvm_object_utils_end

class apb_data_item extends uvm_sequence_item;
    typedef enum bit {READ, WRITE} cmd_e;

    rand bit [11:0] addr;
    rand cmd_e cmd;
    rand logic [31:0] data;
    logic slverr;

    // register to uvm factory, so it could be created through uvm factory in the future
    `uvm_object_utils(apb_data_item)

    // note that always assign a default value to input "name"
    function new (string name = "apb_data_item");
        super.new(name);
    endfunction

    virtual function string convert2string();
        return $sformatf("cmd= %,s addr= %0h, data= %0h", cmd.name(), addr, data);
    endfunction

    // virtual function void do_copy(uvm_object other);
    //     // implement do copy for object.copy()
    //     apb_data_item _copy;
    //     super.do_copy(other);
    //     $cast(_copy, other);
    //     this.addr = _copy.addr;
    //     this.cmd = _copy.cmd;
    //     this.data = _copy.data;
    //     this.slverr = _copy.slverr; 
    // endfunction

    // virtual function void do_print(uvm_printer printer);
    //     super.do_print(printer);
    //     printer.print_string("addr", this.addr)
    //     printer.print_string("cmd", this.cmd.name())
    //     printer.print_string("data", this.data)
    // endfunction

    // virtual function bit do_compare(uvm_object other, uvm_comparer comparer);
    //     apb_data_item _copy;
    //     $cast(_copy, other);
    //     if(_copy.addr)
    //     return (
    //         super.do_compare(_copy, comparer)
    //         & this.addr == _copy.addr
    //         & this.data == _copy.data
    //     )

    // endfunction

endclass
```

## The driver

### `apb_master_driver.sv`

```systemverilog
typedef virtual apb_if apb_vif;

class apb_master_driver extends uvm_driver #(apb_data_item);

    // register this class to UVM factory so that we can create object through UVM factory.
    `uvm_component_utils(apb_master_driver)
  
    apb_vif apb_if;

    function new(string name,uvm_component parent = null);
        super.new(name,parent);
    endfunction
    
    virtual function void build_phase(uvm_phase phase);
        // get interface object from database which should be set at testbench level
        //                    type         cxt  hier  key     value
        if (!uvm_config_db#(apb_vif)::get(this, "", "apb_if", apb_if)) begin
            `uvm_fatal("NOVIF", "No such virtual interface")
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);
        // drive initial value on psel and penable
        this.apb_if.psel    <= '0;
        this.apb_if.penable <= '0;
    endtask

    virtual task drive_read(const ref apb_data_item tr, const ref apb_data_item rsp);
        this.apb_if.psel <= 1;
        this.apb_if.paddr <= tr.addr;
        this.apb_if.pwrite <= 0;
        @(posedge this.apb_if.clk);
        this.apb_if.penable <= 1;

        @(posedge this.apb_if.pready);
        @(posedge this.apb_if.clk);
        rsp.slverr <= this.apb_if.pslverr;
        rsp.data <= this.apb_if.prdata;
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
        rsp.slverr <= this.apb_if.pslverr;
        this.apb_if.penable <= 0;
        this.apb_if.psel <= 0;
    endtask
endclass
```

### `apb_pkg.sv`

> Your should always pack whole dependency together inside a package.

```systemverilog
package apb_pkg;
    import uvm_pkg::*;

    class apb_data_item extends uvm_sequence_item;
        ...
    endclass

    class apb_master_driver extends uvm_driver #(apb_data_item);
        ...
    endclass

    // or use include instead
    // `include "apb_data_item.sv"
    // `include "apb_master_driver.sv"

endpackage
```

### `tb.sv`

```systemverilog
`include "uvm_macros.svh"
import uvm_pkg::*;
import apb_pkg::*;

module tb;

    ...

    apb_if apb_if0 (...);  // instantiate the interface, which should set to UVM database later.

    ...

    initial begin: UVM
        // set apb_if0 object to UVM database, so driver could retrieve it from another hierarchy.
        uvm_config_db #(apb_vif)::set(null, "*", "apb_if", apb_if0);
        run_test();
    end

endmodule
```

### `apb_mst_driver_test.sv`

In this test, we create 5 write transactions from apb_data_item and then send them to DUT through the driver.

```systemverilog
class apb_mst_driver_test extends uvm_test;
    // register "apb_mst_driver_test" to UVM factory
    `uvm_component_utils(apb_mst_driver_test)
    apb_master_driver apb_mst_driver;

    // constructor
    function new(string name = "apb_mst_driver_test", uvm_component parent=null);
        super.new(name,parent);
    endfunction : new

    virtual function void build_phase(uvm_phase phase);
        // instead of calling new() to create a new object, 
        // here we create a object through UVM factory by invoking class::type_id::create()
        this.apb_mst_driver = apb_master_driver::type_id::create("apb_mst_driver", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        logic [11:0] start_address;

        // raise objection to avoid task be terminated abruptly
        phase.raise_objection(this);
        wait($root.tb.rstn);  // wait the assertion of rstn

        `uvm_info( this.get_type_name(), "do master driver test", UVM_MEDIUM)
        repeat(5) @(posedge this.apb_mst_driver.apb_if.clk);

        start_address = 12'h100;
        // create write transactions
        repeat(5) begin
            apb_data_item apb_tr, apb_rsp;

            apb_tr = apb_data_item::type_id::create("apb_tr");
            if(
                !apb_tr.randomize() with {
                    addr == start_address;
                    cmd == apb_data_item::WRITE;
                }
            )
                `uvm_error(this.get_type_name(), "randomization failed")

            apb_rsp = new apb_tr;  // do shallow copy
            this.apb_mst_driver.drive_write(apb_tr, apb_rsp); // got write response
            `uvm_info(this.get_type_name(), apb_rsp.convert2string(), UVM_MEDIUM)

            start_address += 'h4;

        end

        repeat(5) @(posedge $root.tb.clk200M);

        // must drop objection when task is done, otherwise this run phase will not be terminated
        phase.drop_objection(this);  
    endtask : run_phase

endclass
```

## run test

> File order matters

```bash
[simulator] apb_pkg.sv tb.sv apb_mst_driver_test.sv +UVM_TESTNAME=apb_mst_driver_test [other options]
```

## outputs

```
UVM_INFO ... [apb_mst_driver_test] cmd= WRITE, addr= 100, data= xxxxxxxx
UVM_INFO ... [apb_mst_driver_test] cmd= WRITE, addr= 104, data= xxxxxxxx
UVM_INFO ... [apb_mst_driver_test] cmd= WRITE, addr= 108, data= xxxxxxxx
UVM_INFO ... [apb_mst_driver_test] cmd= WRITE, addr= 10c, data= xxxxxxxx
UVM_INFO ... [apb_mst_driver_test] cmd= WRITE, addr= 110, data= xxxxxxxx
```