# Driver

## `apb_seqlib.sv`

### `apb_base_sequence`

```systemverilog
class apb_base_sequence extends uvm_sequence #(apb_data_item);

    `uvm_object_utils(apb_base_sequence)
    rand bit [15:0] start_address;

    // note that always assign a default value to input "name"
    function new (string name = "apb_base_sequence");
        super.new(name);
    endfunction

    // Raise in pre_body so the objection is only raised for root sequences.
    // There is no need to raise for sub-sequences since the root sequence
    // will encapsulate the sub-sequence. 
    virtual task pre_body();
      if (this.starting_phase!=null)
         this.starting_phase.raise_objection(this);
    endtask

    virtual task body();
        this.start_item(this.req);  // Call start_item() to create the item via the UVM factory.

        if(!this.randomize()) `uvm_error(this.get_type_name(), "randomize failed")

        this.finish_item(this.req);
    endtask

    // Drop the objection in the post_body so the objection is removed when
    // the root sequence is complete. 
    virtual task post_body();
        // here we check is there a slave error
        this.get_response(this.rsp);
        if(this.rsp.slverr !== 0)
            `uvm_error(this.get_type_name(), "APB slave error")

        if (starting_phase!=null)
            starting_phase.drop_objection(this);
    endtask

endclass
```

### `apb_write`

```systemverilog
class apb_write extends apb_base_sequence;
    `uvm_object_utils(apb_write)

    // note that always assign a default value to input "name"
    function new (string name = "apb_write");
        super.new(name);
    endfunction

    virtual task body();
        // this.req = apb_data_item::type_id::create("apb_data_item");
        this.start_item(this.req);

        if(
            !this.req.randomize() with {
                this.req.cmd == apb_data_item::WRITE;
                this.req.addr == start_address;
            }
        ) 
            `uvm_error(this.get_type_name(), "randomize failed")

        this.finish_item(this.req);
    endtask
endclass
```

### `apb_read`

```systemverilog
class apb_read extends apb_base_sequence;
    `uvm_object_utils(apb_write)

    // note that always assign a default value to input "name"
    function new (string name = "apb_write");
        super.new(name);
    endfunction

    virtual task body();
        // you can use uvm macro instead of writing all repetitive codes
        `uvm_do_with(
            this.req,
            {
                this.req.cmd == apb_data_item::READ;
                this.req.addr == start_address;
            }
        )
        /* the preceding marco do following things: */

        // this.start_item(this.req);
        // if(
        //     !this.req.randomize() with {
        //         this.req.cmd == apb_data_item::READ;
        //         this.req.addr == start_address;
        //     }
        // ) 
        //     `uvm_warning(this.get_type_name(), "randomize failed with ...")
        // this.finish_item(this.req);
    endtask
endclass
```
