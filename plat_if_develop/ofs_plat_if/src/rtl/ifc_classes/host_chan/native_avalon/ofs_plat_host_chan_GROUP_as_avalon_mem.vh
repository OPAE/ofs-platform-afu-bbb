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

`ifndef __OFS_PLAT_HOST_CHAN_@GROUP@_AS_AVALON_MEM__
`define __OFS_PLAT_HOST_CHAN_@GROUP@_AS_AVALON_MEM__

//
// Macros for setting parameters to Avalon interfaces.
//

// AFUs may set BURST_CNT_WIDTH to whatever works in the AFU. The PIM will
// transform bursts into legal platform requests.
`define HOST_CHAN_@GROUP@_AVALON_MEM_PARAMS \
    .ADDR_WIDTH(`OFS_PLAT_PARAM_HOST_CHAN_@GROUP@_ADDR_WIDTH), \
    .DATA_WIDTH(`OFS_PLAT_PARAM_HOST_CHAN_@GROUP@_DATA_WIDTH)

`define HOST_CHAN_@GROUP@_AVALON_MEM_RDWR_PARAMS \
    .ADDR_WIDTH(`OFS_PLAT_PARAM_HOST_CHAN_@GROUP@_ADDR_WIDTH), \
    .DATA_WIDTH(`OFS_PLAT_PARAM_HOST_CHAN_@GROUP@_DATA_WIDTH)

`endif // __OFS_PLAT_HOST_CHAN_@GROUP@_AS_AVALON_MEM__
