# Lesson1 - Hello World

## 1. How to include UVM library

> make sure you enable systemverilog syntax as well.

### include implicitly

> use tool option to import uvm library will import vender-specific one.
> If you want keep consistency among tools, import explicitly instead.

#### **`verdi`**

```bash
verdi -ntb_opts uvm [other options]
```

#### vcs

```bash
vcs -ntb_opts uvm [other options];  # compile
```

#### xrun

```bash
xrun -uvm [other options]
```

### include explicitly

put following line at your `~/.cshrc.my`

```Tcsh
setenv UVM_HOME /path/to/uvm/library
```

## 2. Your First Hello-World test

The most simple environment is as follows:

- uvm_test_top(the root)
  - uvm_test
  - device under test(DUT)

>In the UVM framework, the top-level instance(the root) is always `uvm_test_top` or you could get the root instance by using `uvm_root::get()`

Reader could find the examples in the common folder

### **`hello_word_test.sv`**

```verilog
class hello_world_test extends uvm_test;
    // register "hello_world_test" to UVM factory
    `uvm_component_utils(hello_world_test)

    // constructor
    function new(string name = "hello_world_test", uvm_component parent=null);
        super.new(name,parent);
    endfunction : new

    task run_phase(uvm_phase phase);
        // raise objection to avoid task be terminated abruptly
        phase.raise_objection(this);
        wait($root.tb.rstn);  // wait the assertion of rstn

        `uvm_info(
            //         id           message      verbosity
            this.get_type_name(), "Hello World", UVM_MEDIUM
        )

        repeat(5) @(posedge $root.tb.clk200M);

        // must drop objection when task is done, otherwise the whole test will not be terminated
        phase.drop_objection(this);  
    endtask : run_phase

endclass
```

### **`tb.sv`**

```verilog

import uvm_pkg::*;

`include "uvm_marcos.svh"
`include "hello_world_test.sv"  // remember to include the the test

module tb;
    logic clk200M;
    logic rstn;

    initial begin: CLK_GENERATOR
        clk200M = 0;
        forever begin
            #2.5ns clk200M = ~clk200M;
        end
    end

    initial begin: RST_SEQ
        rstn = 0;   
        repeat(10) @(posedge clk200M);
        rstn = 1;
    end

    ...

    initial begin: UVM

        ...

        run_test();
    end
endmodule
```

### **run the test**

```bash
[simulator] [options] +UVM_TESTNAME=hello_world_test
```

### **outputs**

```text
UVM_INFO ... ... Running test hello world test...
UVM_INFO hello_world_test.sv ... uvm_test_top [hello_world_test] Hello World
UVM_INFO ... ... [TEST_DONE] 'run' run phase is ready to proceed to the 'extract' phase
```
