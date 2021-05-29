# UVM Simplified Tutorial

## purpose

This tutorial is for the designer who wants to quickly build or want a quick understanding about a test environment with UVM framework.

## Concepts are not covered

- monitor
- scoreboard
- p_sequencer(user-defined sequencer), here we only use build-in one.

## prerequisite

Reader should have basic knowledge of following terms.

- Object Orient Programming(OOP)
- APB bus protocol
- familiar with systemverilog syntax, especially class and interface

## lessons

Here we gonna build a simple testbench with a APB slave and master.
A comprehensive test environment should look like as below hierarchies.
But, the monitor and scoreboard are not mandatory so that they not gonna covered in this tutorial

- testbench
  - DUT(device under test)
  - APB interface
  - UVM TEST
    - RAL(register abstraction layer)
    - UVM sequence
      - UVM sequence item
    - UVM ENV
      - ~~scoreboard~~
      - APB agent
        - driver
        - sequencer
        - ~~monitor~~

## Other learning materials

...
