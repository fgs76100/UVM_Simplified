# UVM Framework

## Typical Verification Component Environment Overview

![verification_env](https://user-images.githubusercontent.com/31207745/120579309-e0591500-c459-11eb-9828-936be8bb6361.png)

## Verification Component Overview

The following subsections describe UVM components.

### Data item (Transaction)

```
Data items represent the input to the device under test (DUT). Examples include networking packets, bus
transactions, and instructions. The fields and attributes of a data item are derived from the data item’s
specification. Data items can be represented by a sequence that contains a list of sequence items.
```

### Driver (BFM)

```
A driver is an active entity that emulates logic that drives the DUT. 
A typical driver repeatedly receives a data item and drives it to the DUT by sampling and driving the DUT signals.
```

### Sequencer

```
A sequencer is stimulus generator that controls the data items that are provided to the driver for
execution and it also optionally can return the response from the DUT through the driver.
```

### Monitor

```
A monitor is a passive entity that samples DUT signals but does not drive them. Monitors collect coverage
information and perform protocol checking.
```

### Agent

```
An agent is an abstract container that encapsulate a driver, sequencer and monitor.
```

### Environment

```
The environment (env) is the top-level component of the verification component. It contains one or more
agents, as well as other components such as a bus monitor. The env contains configuration properties that
enable you to customize the topology and behavior and make it reusable.
```

### Test

```
A test defines the test scenario for the testbench specified in the test. The test class enables
configuration of the testbench and verification components, 
as well as provides data and sequence generation and inline constraints.
```

> Test is not reusable because it rely on a specific environment structure.

### Configuration

```
UVM provide a class call uvm_config_db to allow different scoped components can share a common pool of configurations. 
For example, user can set a value on the top module and then retrieve that value at another hierarchy.
```

## UVM facilities

### UVM factory

```
UVM factory a built-in central factory that allows controlling object allocation 
in the entire environment or for specific objects and modifying stimulus data items 
as well as infrastructure components (for example, a driver).
```

### Transaction-Level Modeling (TLM)

```
UVM provides a set of transaction-level communication interfaces and channels that you can use to connect
components at the transaction level.
```
