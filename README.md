# UVM Simplified Tutorial

## Purpose

This tutorial is for the designer who wants to quickly build or want a quick understanding about a test environment with UVM framework.

## Prerequisites

Reader should have basic knowledge of following terms.

- Object Orient Programming (OOP)
- APB bus protocol
- familiar with systemverilog syntax, especially class and interface

## Concepts are not covered

- p_sequencer(user-defined sequencer), here we only use built-in one.
- ...

## The tutorial

Here we gonna build a simple testbench with an APB slave (DUT).
A comprehensive test environment hierarchies should look like below.

- testbench
  - DUT(device under test)
  - APB interface
  - UVM DATABASE CONFIG
  - UVM TEST
    - RAL(register abstraction layer)
    - UVM sequence
      - UVM sequence item
    - UVM ENV
      - scoreboard
      - APB agent
        - driver
        - sequencer
        - monitor

## Futher reading

...
