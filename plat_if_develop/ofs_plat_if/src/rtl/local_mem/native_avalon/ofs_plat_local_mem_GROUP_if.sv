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

`include "ofs_plat_if.vh"

//
// Required: platforms with raw interface "local_mem" must provide an interface
// wrapper named "ofs_plat_local_mem_if". The wrapper must accept only one
// parameter, ENABLE_LOG, even if debug logging during simulation isn't
// implemented for the platform.
//
// The default parameter state must define a configuration that matches
// the hardware. A standard interface enables platform-independent AFUs.
//
interface ofs_plat_local_GROUP_mem_if
  #(
    parameter ENABLE_LOG = 0,
    parameter NUM_BANKS = `OFS_PLAT_PARAM_LOCAL_MEM_GROUP_NUM_BANKS,
    parameter WAIT_REQUEST_ALLOWANCE = 0
    );

    // A hack to work around compilers complaining of circular dependence
    // incorrectly when trying to make a new ofs_plat_local_mem_if from an
    // existing one's parameters.
    localparam NUM_BANKS_ = $bits(logic [NUM_BANKS:0]) - 1;

    ofs_plat_avalon_mem_if
      #(
        .LOG_CLASS(ENABLE_LOG ? ofs_plat_log_pkg::LOCAL_MEM : ofs_plat_log_pkg::NONE),
        .NUM_INSTANCES(NUM_BANKS),
        .ADDR_WIDTH(`OFS_PLAT_PARAM_LOCAL_MEM_GROUP_ADDR_WIDTH),
        .DATA_WIDTH(`OFS_PLAT_PARAM_LOCAL_MEM_GROUP_DATA_WIDTH),
        .BURST_CNT_WIDTH(`OFS_PLAT_PARAM_LOCAL_MEM_GROUP_BURST_CNT_WIDTH),
        .WAIT_REQUEST_ALLOWANCE(WAIT_REQUEST_ALLOWANCE)
        )
        banks[NUM_BANKS]();

endinterface // ofs_plat_local_mem_GROUP_if
