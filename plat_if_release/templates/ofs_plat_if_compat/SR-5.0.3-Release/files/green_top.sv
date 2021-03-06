// ***************************************************************************
//
//        Copyright (C) 2008-2016 Intel Corporation All Rights Reserved.
//
// Module Name :        green top
// Project :            BDW + FPGA 
// Description :        This module instantiates CCI-P compliant AFU and 
//                      Debug modules remote signal Tap feature.
//                      User AFUs should be instantiated in ccip_std_afu.sv
//                      ----- DO NOT MODIFY THIS FILE -----
// ***************************************************************************

//
// platform_if.vh defines many required components, including both top-level
// SystemVerilog interfaces and the platform/AFU configuration parameters
// required to match the interfaces offered by the platform to the needs
// of the AFU. It is part of the platform database and imported using
// state generated by afu_platform_config.
//
// Most preprocessor variables used in this file come from this.
//
`include "platform_if.vh"
`include "ofs_plat_if.vh"

parameter CCIP_TXPORT_WIDTH = $bits(t_if_ccip_Tx);
parameter CCIP_RXPORT_WIDTH = $bits(t_if_ccip_Rx);
module green_top(
  // CCI-P Clocks and Resets
  input           logic             pClk,              // 400MHz - CCI-P clock domain. Primary interface clock
  input           logic             pClkDiv2,          // 200MHz - CCI-P clock domain.
  input           logic             pClkDiv4,          // 100MHz - CCI-P clock domain.
  input           logic             uClk_usr,          // User clock domain. Refer to clock programming guide  ** Currently provides fixed 272.78MHz clock **
  input           logic             uClk_usrDiv2,      // User clock domain. Half the programmed frequency  ** Currently provides fixed 136.37MHz clock **
  input           logic             pck_cp2af_softReset,      // CCI-P ACTIVE HIGH Soft Reset
  input           logic [1:0]       pck_cp2af_pwrState,       // CCI-P AFU Power State
  input           logic             pck_cp2af_error,          // CCI-P Protocol Error Detected

  // Interface structures
  output          logic [CCIP_TXPORT_WIDTH-1:0] bus_ccip_Tx,         // CCI-P TX port
  input           logic [CCIP_RXPORT_WIDTH-1:0] bus_ccip_Rx,         // CCI-P RX port
  
  // JTAG interface for PR region debug
  input           logic             sr2pr_tms,
  input           logic             sr2pr_tdi,             
  output          logic             pr2sr_tdo,             
  input           logic             sr2pr_tck             
);

  // ===========================================
  // Top-level AFU platform interface
  // ===========================================

  // OFS platform interface constructs a single interface object that
  // wraps all ports to the AFU.
  ofs_plat_if plat_ifc();

  // Clocks
  ofs_plat_std_clocks_gen_resets_from_active_high clocks
     (
      .pClk,
      .pClk_reset(pck_cp2af_softReset),
      .pClkDiv2,
      .pClkDiv4,
      .uClk_usr,
      .uClk_usrDiv2,
      .clocks(plat_ifc.clocks)
      );

  // Reset, etc.
  assign plat_ifc.softReset_n = plat_ifc.clocks.pClk.reset_n;
  assign plat_ifc.pwrState = pck_cp2af_pwrState;

  // Host CCI-P port
  assign plat_ifc.host_chan.ports[0].clk = plat_ifc.clocks.pClk.clk;
  assign plat_ifc.host_chan.ports[0].reset_n = plat_ifc.softReset_n;
  assign plat_ifc.host_chan.ports[0].instance_number = 0;
  assign plat_ifc.host_chan.ports[0].error = pck_cp2af_error;
  assign plat_ifc.host_chan.ports[0].sRx = bus_ccip_Rx;
  assign bus_ccip_Tx = plat_ifc.host_chan.ports[0].sTx;


  // ===========================================
  // AFU - Remote Debug JTAG IP instantiation
  // --- DO NOT MODIFY ----
  // ===========================================

`ifdef SIMULATION_MODE
  assign pr2sr_tdo = 0;

`else
  wire loopback;
  sld_virtual_jtag  (.tdi(loopback), .tdo(loopback));
  SCJIO 
  inst_SCJIO (
                .tms         (sr2pr_tms),         //        jtag.tms
                .tdi         (sr2pr_tdi),         //            .tdi
                .tdo         (pr2sr_tdo),         //            .tdo
                .tck         (sr2pr_tck)          //         tck.clk
  ); 
`endif 


  // ===========================================
  // OFS platform interface instantiation
  // ===========================================
  `PLATFORM_SHIM_MODULE_NAME `PLATFORM_SHIM_MODULE_NAME
   (
    .plat_ifc
    );

endmodule
