//
// Copyright (c) 2019, Intel Corporation
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// Redistributions of source code must retain the above copyright notice, this
// list of conditions and the following disclaimer.
//
// Redistributions in binary form must reproduce the above copyright notice,
// this list of conditions and the following disclaimer in the documentation
// and/or other materials provided with the distribution.
//
// Neither the name of the Intel Corporation nor the names of its contributors
// may be used to endorse or promote products derived from this software
// without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.

//
// Export a platform local_mem interface to an AFU as an Avalon memory.
//
// The "as Avalon" abstraction here allows an AFU to request the memory
// using a particular interface. The platform may offer multiple interfaces
// to the same underlying PR wires, instantiating protocol conversion
// shims as needed.
//

//
// This version of ofs_plat_local_mem_as_avalon_mem works on platforms
// where the native interface is already Avalon.
//

`include "ofs_plat_if.vh"

module ofs_plat_local_mem_GROUP_as_avalon_mem
  #(
    // When non-zero, add a clock crossing to move the AFU interface
    // to the passed in tgt_mem_afu_clk.
    parameter ADD_CLOCK_CROSSING = 0,

    // Add extra pipeline stages, typically for timing.
    parameter ADD_TIMING_REG_STAGES = 0
    )
   (
    // AFU clock for memory when a clock crossing is requested
    input  logic tgt_mem_afu_clk,

    // The ports are named "to_fiu" and "to_afu" despite the Avalon
    // to_slave/to_master naming because the PIM port naming is a
    // bus-independent abstraction. At top-level, PIM ports are
    // always to_fiu and to_afu.
    ofs_plat_avalon_mem_if.to_slave to_fiu,
    ofs_plat_avalon_mem_if.to_master_clk to_afu
    );

    // ====================================================================
    // While clocking and register stage insertion are logically
    // independent, considering them together leads to an important
    // optimization. The clock crossing FIFO has a large buffer that
    // can be used to turn the standard Avalon MM waitrequest signal into
    // an almost full protocol. The buffer stages become a simple
    // pipeline.
    //
    // When there is no clock crossing FIFO, all register stages must
    // honor the waitrequest protocol.
    // ====================================================================

    //
    // How many register stages should be inserted for timing?
    //
    function automatic int numTimingRegStages();
        // Were timing registers requested?
        int n_stages = ADD_TIMING_REG_STAGES;

        // Override the register request if a clock crossing is being
        // inserted here.
        if (ADD_CLOCK_CROSSING)
        begin
            // Use at least the recommended number of stages
            if (`OFS_PLAT_PARAM_LOCAL_MEM_SUGGESTED_TIMING_REG_STAGES > n_stages)
            begin
                n_stages = `OFS_PLAT_PARAM_LOCAL_MEM_SUGGESTED_TIMING_REG_STAGES;
            end
        end

        return n_stages;
    endfunction

    localparam NUM_TIMING_REG_STAGES = numTimingRegStages();

    ofs_plat_avalon_mem_if
      #(
        .ADDR_WIDTH(to_fiu.ADDR_WIDTH_),
        .DATA_WIDTH(to_fiu.DATA_WIDTH_),
        .BURST_CNT_WIDTH(to_fiu.BURST_CNT_WIDTH_)
        )
        afu_mem_if();

    generate
        if (ADD_CLOCK_CROSSING == 0)
        begin : nc
            //
            // No clock crossing, maybe register stages.
            //
            ofs_plat_avalon_mem_if_reg_slave_clk
              #(
                .N_REG_STAGES(NUM_TIMING_REG_STAGES)
                )
              mem_pipe
               (
                .mem_slave(to_fiu),
                .mem_master(afu_mem_if)
                );
        end
        else
        begin : ofs_plat_clock_crossing
            //
            // Cross to the specified clock.
            //
            ofs_plat_avalon_mem_if
              #(
                .ADDR_WIDTH(to_fiu.ADDR_WIDTH_),
                .DATA_WIDTH(to_fiu.DATA_WIDTH_),
                .BURST_CNT_WIDTH(to_fiu.BURST_CNT_WIDTH_)
                )
                mem_cross();

            assign mem_cross.clk = tgt_mem_afu_clk;
            assign mem_cross.instance_number = to_fiu.instance_number;

            // Synchronize a reset with the target clock
            ofs_plat_prim_clock_crossing_reset
             reset_cc
               (
                .clk_src(to_fiu.clk),
                .clk_dst(mem_cross.clk),
                .reset_in(to_fiu.reset),
                .reset_out(mem_cross.reset)
                );

            // We assume that a single waitrequest signal can propagate faster
            // than the entire bus, so limit the number of stages.
            localparam NUM_WAITREQUEST_STAGES =
                // If pipeline is 4 stages or fewer then use the pipeline depth.
                (NUM_TIMING_REG_STAGES <= 4 ? NUM_TIMING_REG_STAGES :
                    // Up to depth 16 pipelines, use 4 waitrequest stages.
                    // Beyond 16 stages, set the waitrequest depth to 1/4 the
                    // base pipeline depth.
                    (NUM_TIMING_REG_STAGES <= 16 ? 4 : (NUM_TIMING_REG_STAGES >> 2)));

            // A few extra stages to avoid off-by-one errors. There is plenty of
            // space in the FIFO, so this has no performance consequences.
            localparam NUM_EXTRA_STAGES = (NUM_TIMING_REG_STAGES != 0) ? 4 : 0;

            // Set the almost full threshold to satisfy the buffering pipeline depth
            // plus the depth of the waitrequest pipeline plus a little extra to
            // avoid having to worry about off-by-one errors.
            localparam NUM_ALMFULL_SLOTS = NUM_TIMING_REG_STAGES +
                                           NUM_WAITREQUEST_STAGES +
                                           NUM_EXTRA_STAGES;

            ofs_plat_avalon_mem_if_async_shim
              #(
                .COMMAND_ALMFULL_THRESHOLD(NUM_ALMFULL_SLOTS)
                )
              mem_async_shim
               (
                .mem_slave(to_fiu),
                .mem_master(mem_cross)
                );

            // Add requested register stages on the AFU side of the clock crossing.
            // In this case the register stages are a simple pipeline because
            // the clock crossing FIFO reserves space for these stages to drain
            // after waitrequest is asserted.
            ofs_plat_avalon_mem_if_reg_simple
              #(
                .N_REG_STAGES(NUM_TIMING_REG_STAGES),
                .N_WAITREQUEST_STAGES(NUM_WAITREQUEST_STAGES)
                )
              mem_pipe
               (
                .mem_slave(mem_cross),
                .mem_master(afu_mem_if)
                );

            assign afu_mem_if.clk = mem_cross.clk;
            assign afu_mem_if.reset = mem_cross.reset;
            // Debugging signal
            assign afu_mem_if.instance_number = mem_cross.instance_number;
        end
    endgenerate

    // Make the final connection to the to_afu instance, including passing the clock.
    ofs_plat_avalon_mem_if_connect_slave_clk conn_to_afu
       (
        .mem_slave(afu_mem_if),
        .mem_master(to_afu)
        );

endmodule // ofs_plat_local_mem_GROUP_as_avalon_mem
