# Board Vendors: Configuring a Release #

Like many OFS components, the Platform Interface Manager (PIM) and release tree are optional. The components serve as a template for portable AFU development across multiple platforms. For platform vendors, standardized release structures and APIs also makes a large number of tests available. Vendors building single-purpose systems may not benefit from the PIM and could choose to build without it.

A release tree holds databases that describe a platform's available devices, a Quartus project pre-configured as a generic template for building AFUs, and a collection of scripts for configuring, simulating and synthesizing AFUs. Most releases will instantiate AFUs in partially reconfigured regions of an FPGA, keeping the FIM in a fixed region, though PR is not a requirement. Templates for building fixed AFU/FIM pairs are supported as well.

AFU developers set the environment variable OPAE\_PLATFORM\_ROOT to the top of a release in order to build with it. Tools such as afu\_sim\_setup and afu\_synth\_setup from the OPAE SDK require, at a minimum, the following structure within a release:

```
bin/
  afu_synth                  <- Platform-specific script to synthesize an AFU with Quartus
hw/
  lib/
    build/                   <- The FIM and PIM RTL and Quartus project template
      platform/              <- Location of green_bs() and root of the PIM
        ofs_plat_if/         <- PIM sources, generated from ../../plat_if_develop
    fme-ifc-id.txt           <- The UUID of the FIM
    fme-platform-class.txt   <- The PIM's unique tag for the platform
    platform/
      platform_db/
        <platform>.json      <- The name must match the value in fme-platform-class.txt
```

## Platform Interface Classes ##

The portability of PIM interfaces relies on mapping physical ports to bus-independent abstract groups. Major PIM groups are:

### Host Channels ###

A host channel is a port offering DMA to host memory and, optionally, an MMIO space mastered by the AFU. Typical boards provide PCIe as the primary host channel, with the OPAE SDK and driver depending on PCIe MMIO to implement the CSRs used by OPAE to manage the FIM and AFU. Boards may have more than one host channel, often of different types. Both CXL and UPI are considered host channels.

### Local Memory ###

Local memory is off-chip storage, such as DDR or HBM, attached directly to the FPGA and not managed by the FIM as part of host memory.

### HSSI ###

HSSI ports are high speed serial interconnects, such as Ethernet.

### Other Classes ###

Board vendors may define non-standard classes. The PIM provides templates for writing new SystemVerilog interfaces and for writing device-specific tie-offs that are instantiated automatically by the PIM when a device is not used by an AFU.

## Native Interface Types ##

A physical interface exposed by the FIM to an AFU is called a *native type*. Every FIM interface declares a native type. This type defines the physical wires. The PIM may provide a collection of shims on top of the native type that map to one or more type abstractions offered to AFUs. This is the primary PIM portability mechanism. For example, the PIM can expose both native CCI-P and native AXI streams of PCIe TLPs. In both cases, AFUs instantiate a shim named *ofs\_plat\_host\_chan\_as\_avalon\_mem\_rdwr* as a wrapper around the native interface instance. The implementations are quite different and the PIM source tree has several implementations of *ofs\_plat\_host\_chan\_as\_avalon\_mem\_rdwr*. The PIM generation scripts pick the shims appropriate to a particular platform when generating a platform's ofs\_plat\_if tree.

The PIM may offer several shims on top of the same native type, thus offering different AFU interfaces to the same device. For example, an AFU may select either AXI memory, Avalon memory or CCI-P connections to the same FIM PCIe host channel.

## Defining a Platform Interface ##

The PIM is instantiated in a release tree from the following:

* An .ini file describing the platform
* A collection of [RTL interfaces and modules](../src)
* The [gen\_ofs\_plat\_if](../scripts/gen_ofs_plat_if) script

```sh
$ mkdir -p <release tree root>/hw/lib/build/platform/ofs_plat_if
$ gen_ofs_plat_if -c <.ini file path> -t <release tree root>/hw/lib/build/platform/ofs_plat_if
```

### Platform .ini Files ###

Each major section in a platform .ini file corresponds to one or more devices of the same type. Same-sized banks of local memory share a single .ini section, with the number of banks as a parameter in the section. The same is true of HSSI ports and, on some multi-PCIe systems, of host channels. All devices in a section must share the same properties. If there are two types of local memory on a board with different address or data widths, they must have their own local memory sections. Separate sections of the same type must be named with monotonically increasing numeric suffixes, e.g. *local\_memory.0* and *local\_memory.1*. The trailing *.0* is optional. *host\_channel.0* and *host\_channel* are equivalent.

Some sections are required in order to guarantee AFU portability across platforms:

* **[define]** — A list of preprocessor macros that the PIM will export into all builds. At least one macro should uniquely identify the platform. Others may be used to identify features, used by AFUs for conditional compilation.
* **[clocks]** — The frequency of the primary pClk.
* **[host\_chan]** — Typical platforms will have at least one host channel port. By convention, host\_chan.0, port 0 is mapped to the primary MMIO-based CSR space used by OPAE when probing AFUs.

Sections typically represent vectors of ports or banks, all of the same type. The values *num\_ports* and *num\_banks* within a section cause gen\_ofs\_plat\_if to name vectors as *ports* or *banks*.

All properties in a platform's .ini file are exported as preprocessor macros in the generated PIM in:

```
$OPAE_PLATFORM_ROOT/hw/lib/build/platform/ofs_plat_if/rtl/ofs_plat_if_top_config.vh
```

The naming convention is a straight mapping of sections and properties to macros, e.g.:

```SystemVerilog
`define OFS_PLAT_PARAM_LOCAL_MEM_NUM_BANKS 2
`define OFS_PLAT_PARAM_LOCAL_MEM_ADDR_WIDTH 27
`define OFS_PLAT_PARAM_LOCAL_MEM_DATA_WIDTH 512
`define OFS_PLAT_PARAM_LOCAL_MEM_BURST_CNT_WIDTH 7
```

### Defaults ###

Within a section, some properties are mandatory. For example, local memories must define address and data widths. The [defaults.ini](../../../plat_if_develop/ofs_plat_if/src/config/defaults.ini) file holds the required values for all standard section classes. It also documents the semantics of each property. Sections in defaults.ini may be universal across all native interfaces, such as **[host\_chan]** for all host channels, or specific to a particular native interface, e.g. **[host\_chan.native\_avalon]**.

Platform-specific .ini files may override properties from defaults.ini and may add new properties. All properties are written to the generated ofs\_plat\_if\_top\_config.vh.

The defaults.ini has a section for each OFS PIM standard class:

* **[clocks]** — Top-level clocks, typically pClk, pClkDiv2, pClkDiv4, uClk\_usr and uClk\_usrDiv2.
* **[host\_chan]** — Connections to host memory (e.g. PCIe or CXL) and/or MMIO slaves, with a host as master.
* **[local\_mem]** — Local memory, connected to the FPGA directly outside of the host's coherence domains.
* **[hssi]** — Ethernet ports.

### Multiple Instances of a Class ###

Complex platforms may have multiple devices that are similar, but not identical. A board could have a PCIe host channel and a collection of CXL ports. These can be represented as multiple sections in an .ini file, the primary port with MMIO named **[host\_chan]** and the secondary group named **[host\_chan.1]**. As noted earlier, **[host\_chan]** and **[host\_chan.0]** are synonymous. The pair of channels, **[host\_chan]** and **[host\_chan.1]**, are logically separate. In addition to having different address or data widths, they may even have different native types.

The PIM tree has some emulated test platforms as examples. [d5005\_pac\_ias\_v2\_0\_1\_em\_hc1cx2a.ini](../src/config/emulation/d5005_pac_ias_v2_0_1_em_hc1cx2a.ini) describes a FIM with two host channel groups, with group one using native CCI-P and group two using a pair of native Avalon memory interfaces.

### Platform-Specific Classes ###

Platforms may extend the PIM with new interface classes by specifying a non-standard section name. The same dot notation applies for multiple variations of the same class. The PIM provides generic templates as starting points for adding non-standard native interfaces. They will be copied to the generated *ofs\_plat\_if* and must be completed by platform implementers. The source templates are in [ifc\_classes/generic\_templates](../../../plat_if_develop/ofs_plat_if/src/rtl/ifc_classes/generic_templates/), one for collections of ports and another for collections of banks.

A platform-specific section in the .ini file takes the form:

```.ini
[power_ctrl]
template_class=generic_templates
native_class=ports
num_ports=1
req_width=8
rsp_width=16
```

and generates an implementation in the target named *ofs\_plat\_if/rtl/ifc\_classes/power\_ctrl/*. Platform implementers must then follow the comments in the files within *power\_ctrl/* to complete the code. The properties within [power\_ctrl] are all written to *ofs\_plat\_if\_top\_config.vh*.

Collections of banks are indicated by replacing *num\_ports* with *num\_banks*.

## PIM Implementation ##

The gen\_ofs\_plat\_if script, which composes a platform-specific PIM given an .ini file, uses the [ofs\_plat\_if/src/rtl/](../src/rtl/) tree as a template. The script copies sources into the target ofs\_plat\_if tree within a release, generates some top-level wrapper files and emits rules that import the generated tree for simulation or synthesis.

Some directories within the rtl tree are imported unchanged:

* **base\_ifcs** — A collection of generic interface definitions (e.g. Avalon and AXI) and helper modules (e.g. clock crossing and pipeline stage insertion).
* **compat** — Compatibility wrapper for the original implementation of the PIM, originally found in the OPAE SDK. Unlike the OFS PIM, to which an AFU connects using SystemVerilog, the original PIM specified an AFU's requirement using JSON and Python. The new PIM remains backward compatible with the original implementation.
* **utils** — Primitive shims, such as FIFOs, memories, and reorder buffers.

### Templates ###

The core sources for PIM interfaces are in the [ofs\_plat\_if/src/rtl/ifc\_classes/](../src/rtl/ifc_classes/) tree. The tree is organized by top-level PIM classes (host\_chan, local\_mem, etc.) and, below those, by native interfaces. The PIM generator script copies only the top-level class and native interface pairs specified by a platform-specific .ini file. Multiple native interfaces under a given top-level class are, from an AFU's perspective, functionally equivalent mappings to the same module names and semantics. This selection of the proper, platform-specific, shim is the core PIM mechanism for achieving AFU portability.

Another key to portability is a shim naming convention. All shims are named:

```
module ofs_plat_<top-level class instance>_as_<interface type>()
```

For example:

```
module ofs_plat_host_chan_as_avalon_mem_rdwr()
module ofs_plat_host_chan_as_ccip()
```

Both modules connect to the same physical device. It is up to the AFU to select an implementation from the available options.

When multiple instances of a top-level class are present, e.g. when banks with different widths of local memory are available, a *group* tag is added to the top-level class instance. The raw top-level class name is always used for group 0. Special naming for groups begins with group 1, e.g.:

```
module ofs_plat_host_chan_as_avalon_mem_rdwr()
module ofs_plat_host_chan_as_ccip()

module ofs_plat_host_chan_g1_as_avalon_mem_rdwr()
module ofs_plat_host_chan_g1_as_ccip()
```

The implementation of a shim is independent of platform-specific group numbering. As a platform developer, it would be tedious to replicate equivalent sources that differ only by group name. The gen\_ofs\_plat\_if script treats source files as templates, with replacement rules:

* Files names containing *\_GROUP\_* are renamed with the group number. *local\_mem\_GROUP\_cfg\_pkg.sv* becomes *local\_mem\_g1\_cfg\_pkg.sv*. The tag is eliminated for group 0: *local\_mem\_cfg\_pkg.sv*.
* There are also substitution rules for the contents of files with names containing *\_GROUP\_*. The pattern *@GROUP@* becomes *G1* and *@group@* becomes *g1*. The pattern is simply eliminated for group 0.
* *\_CLASS\_* in file names and *@CLASS@* or *@class@* inside these files are replaced with the interface class name — the name of the section in the .ini file.
* Comments of the form *//=* are eliminated. This makes it possible to have a comment in a template file about the template itself that is not replicated to the platform's release.

All of the PIM's interface shims apply these templates. For a simple example, see the generic template that is copied when an .ini file specifies *template_class=generic\_templates* and *native\_class=ports*: [ofs\_plat\_CLASS\_GROUP\_fiu\_if.sv](../src/rtl/ifc_classes/generic_templates/ports/ofs_plat_CLASS_GROUP_fiu_if.sv).

### Top-Level Templates ###

The top-level [rtl directory](../src/rtl/) holds files that become the root of a release's PIM. Files with names containing *.template* are copied with *.template* and the contents processed as follows:

When the keyword *@OFS\_PLAT\_IF\_TEMPLATE@* is encountered, gen\_ofs\_plat\_if loops through the region beginning and ending with the keyword, replicating the text for each of the platform's interface groups. Inside these regions, the following patterns are substituted:

* *@class@* is replaced with the interface major class, such as *host\_chan* or *local\_memory*.
* *@group@* is replaced with the group name within a class. It is eliminated for group 0.
* *@noun@* is replaced with the collection name for a class, typically *ports* or *banks*.
* *@CONFIG_DEFS@* (uppercase only) is replaced with all preprocessor macros associated with a class's properties. This is primarily used in [ofs\_plat\_if\_top\_config.template.vh](../src/rtl/ofs_plat_if_top_config.template.vh) to generate ofs\_plat\_if\_top\_config.vh.

The case of the pattern determines the case of the substitution.

The keyword *@OFS\_PLAT\_IF\_TEMPLATE@* skips sections with no ports or banks, such as *[clocks]*. To apply the template to all sections, use the keyword *@OFS\_PLAT\_IF\_TEMPLATE\_ALL@*.

With these rules, a template such as [ofs\_plat\_if\_tie\_off\_unused.template.sv](../src/rtl/ofs_plat_if_tie_off_unused.template.sv):

```
module ofs_plat_if_tie_off_unused
  #(
    // Masks are bit masks, with bit 0 corresponding to port/bank zero.
    // Set a bit in the mask when a port is IN USE by the design.
    // This way, the AFU does not need to know about every available
    // device. By default, devices are tied off.
    @OFS_PLAT_IF_TEMPLATE@
    parameter bit [31:0] @CLASS@@GROUP@_IN_USE_MASK = 0,
    @OFS_PLAT_IF_TEMPLATE@

    // Emit debugging messages in simulation for tie-offs?
    parameter QUIET = 0
    )
   (
    ofs_plat_if plat_ifc
    );

    genvar i;
    @OFS_PLAT_IF_TEMPLATE@
    //==
    //== Tie-offs for top-level interface classes will be emitted here, using
    //== the template between instances of @OFS_PLAT_IF_TEMPLATE@ for each class
    //== and group number.
    //==

    generate
        for (i = 0; i < plat_ifc.@class@@group@.NUM_@NOUN@; i = i + 1)
        begin : tie_@class@@group@
            if (~@CLASS@@GROUP@_IN_USE_MASK[i])
            begin : m
                ofs_plat_@class@@group@_fiu_if_tie_off tie_off(plat_ifc.@class@@group@.@noun@[i]);

                // synthesis translate_off
                initial
                begin
                    if (QUIET == 0) $display("%m: Tied off plat_ifc.@class@@group@.@noun@[%0d]", i);
                end
                // synthesis translate_on
            end
        end
    endgenerate
    @OFS_PLAT_IF_TEMPLATE@

endmodule // ofs_plat_if_tie_off_unused
```

can become the platform-specific ofs\_plat\_if\_tie\_off\_unused.sv:

```SystemVerilog
module ofs_plat_if_tie_off_unused
  #(
    // Masks are bit masks, with bit 0 corresponding to port/bank zero.
    // Set a bit in the mask when a port is IN USE by the design.
    // This way, the AFU does not need to know about every available
    // device. By default, devices are tied off.
    parameter bit [31:0] HOST_CHAN_IN_USE_MASK = 0,
    parameter bit [31:0] LOCAL_MEM_IN_USE_MASK = 0,
    parameter bit [31:0] HSSI_IN_USE_MASK = 0,

    // Emit debugging messages in simulation for tie-offs?
    parameter QUIET = 0
    )
   (
    ofs_plat_if plat_ifc
    );

    genvar i;

    generate
        for (i = 0; i < plat_ifc.host_chan.NUM_PORTS; i = i + 1)
        begin : tie_host_chan
            if (~HOST_CHAN_IN_USE_MASK[i])
            begin : m
                ofs_plat_host_chan_fiu_if_tie_off tie_off(plat_ifc.host_chan.ports[i]);

                // synthesis translate_off
                initial
                begin
                    if (QUIET == 0) $display("%m: Tied off plat_ifc.host_chan.ports[%0d]", i);
                end
                // synthesis translate_on
            end
        end
    endgenerate

    generate
        for (i = 0; i < plat_ifc.local_mem.NUM_BANKS; i = i + 1)
        begin : tie_local_mem
            if (~LOCAL_MEM_IN_USE_MASK[i])
            begin : m
                ofs_plat_local_mem_fiu_if_tie_off tie_off(plat_ifc.local_mem.banks[i]);

                // synthesis translate_off
                initial
                begin
                    if (QUIET == 0) $display("%m: Tied off plat_ifc.local_mem.banks[%0d]", i);
                end
                // synthesis translate_on
            end
        end
    endgenerate

    generate
        for (i = 0; i < plat_ifc.hssi.NUM_PORTS; i = i + 1)
        begin : tie_hssi
            if (~HSSI_IN_USE_MASK[i])
            begin : m
                ofs_plat_hssi_fiu_if_tie_off tie_off(plat_ifc.hssi.ports[i]);

                // synthesis translate_off
                initial
                begin
                    if (QUIET == 0) $display("%m: Tied off plat_ifc.hssi.ports[%0d]", i);
                end
                // synthesis translate_on
            end
        end
    endgenerate

endmodule // ofs_plat_if_tie_off_unused
```