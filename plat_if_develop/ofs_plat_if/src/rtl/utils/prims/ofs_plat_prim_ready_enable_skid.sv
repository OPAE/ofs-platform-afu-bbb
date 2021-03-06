//
// Copyright (c) 2020, Intel Corporation
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
// Generic ready/enable pipeline stage. This implementation shares the same
// interface as the systolic version (ofs_plat_prim_ready_enable_reg), but
// internally adds a FIFO. This adds a register between ready_from_dst and
// ready_to_src, thus breaking control flow into shorter and simpler logic
// at the expense of area.
//

module ofs_plat_prim_ready_enable_skid
  #(
    parameter N_DATA_BITS = 32
    )
   (
    input  logic clk,
    input  logic reset_n,

    input  logic enable_from_src,
    input  logic [N_DATA_BITS-1 : 0] data_from_src,
    output logic ready_to_src,

    output logic enable_to_dst,
    output logic [N_DATA_BITS-1 : 0] data_to_dst,
    input  logic ready_from_dst
    );

    //
    // Using the FIFO2 here generates logic that is essentially equivalent
    // to the Quartus Avalon bridge's management of the request bus.
    //
    ofs_plat_prim_fifo2
      #(
        .N_DATA_BITS(N_DATA_BITS)
        )
      f
       (
        .clk,
        .reset_n,

        .enq_data(data_from_src),
        .enq_en(enable_from_src && ready_to_src),
        .notFull(ready_to_src),

        .first(data_to_dst),
        .deq_en(enable_to_dst && ready_from_dst),
        .notEmpty(enable_to_dst)
        );

endmodule // ofs_plat_prim_ready_enable_skid
