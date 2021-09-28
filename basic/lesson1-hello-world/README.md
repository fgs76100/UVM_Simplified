# Lesson1 - Hello World

## How to include UVM library

### Include implicitly

> use tool option to import uvm library will import vender-specific one.
> If you want keep consistency among tools, import explicitly instead.

#### verdi

```bash
verdi -ntb_opts uvm [other options]
```

#### vcs

```bash
vcs -ntb_opts uvm [other options]
```

#### xrun

```bash
xrun -uvm [other options]
```

> make sure you enable systemverilog syntax as well.

### Include explicitly

You could download the UVM library from [accellera](https://www.accellera.org/downloads/standards/uvm) and follow the readme.

Or you know exactly what library you want to use, just put following line in your `~/.cshrc.my`

```Tcsh
setenv UVM_HOME /path/to/uvm/library/src
```

## Your first hello-world test

The most simple environment is as follows:

- testbench
  - uvm_test
  - device under test(DUT)

Reader could find the tb.sv, apb_slave.sv and apb_if.sv in the common folder.

### `hello_word_test.sv`

```systemverilog
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
        wait($root.tb.rstn);  // wait the de-assertion of rstn

        `uvm_info(
            //         id           message      verbosity
            this.get_type_name(), "Hello World", UVM_MEDIUM
        )

        repeat(5) @(posedge $root.tb.clk200M);

        // must drop objection when task is done, otherwise this run phase will not be terminated
        phase.drop_objection(this);  
    endtask : run_phase

endclass
```

### `tb.sv`

```systemverilog

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

You can specify test case with hard-coded `run_test("hello_world_test")`, but for the best practice, we should always specify test name from the command line by `+UVM_TESTNAME=you_test_name`.

```bash
[simulator] [options] -f ../common/common.f tb.sv +UVM_TESTNAME=hello_world_test
```

### **outputs**

```text
UVM_INFO ... ... Running test hello world test...
UVM_INFO hello_world_test.sv ... uvm_test_top [hello_world_test] Hello World
UVM_INFO ... ... [TEST_DONE] 'run' run phase is ready to proceed to the 'extract' phase
```

## Takeaways

1. with systemverilog, user should always declare the unit of delay explicitly. For example: do `#2.5ns clk200M = ~clk200M;` **DON't** do `#2.5 clk200M = ~clk200M;`

2. use `$root` to unambiguously refer to a top-level instance. For example, `A.B.C` can mean the local `A.B.C` or the top-level `A.B.C`. `$root` allows explicit access to the top level.

3. Whenever extends a uvm class, you always register it to `uvm_factory` by invoking `` `uvm_component_utils(subclass)`` or `` `uvm_object_utils(subclass)``. If child class is a parameterize class, you should use `` `uvm_component_param_utils(subclass#(parameters)) `` or `` `uvm_object_param_utils(subclass#(parameters))``