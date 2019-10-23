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

`ifndef __OFS_PLAT_AVALON_MEM_RDWR_IF_VH__
`define __OFS_PLAT_AVALON_MEM_RDWR_IF_VH__

//
// Macro for replicating properties of an ofs_plat_avalon_mem_rdwr_if when
// defininig another instance of the interface.
//
`define ofs_plat_avalon_mem_rdwr_if_replicate_params(AVALON_IF) \
    .ADDR_WIDTH(AVALON_IF.ADDR_WIDTH_), \
    .DATA_WIDTH(AVALON_IF.DATA_WIDTH_), \
    .BURST_CNT_WIDTH(AVALON_IF.BURST_CNT_WIDTH_)


//
// Utilities for operating on interface ofs_plat_avalon_mem_rdwr_if.
//
// Ideally, the macros here would instead be tasks in the interface intself.
// Unfortunately, tasks within an interface can't use the interface as a
// parameter type. You can't build a task in an interface that operates on an
// instance of interface object. Instead, we resort to these ugly macros.
// Macros allow modules to operate without knowing some of the minor interface
// fields.
//

`define ofs_plat_avalon_mem_rdwr_if_from_master_to_slave_comb(MEM_SLAVE, MEM_MASTER) \
    MEM_SLAVE.rd_read = MEM_MASTER.rd_read; \
    MEM_SLAVE.rd_burstcount = MEM_MASTER.rd_burstcount; \
    MEM_SLAVE.rd_byteenable = MEM_MASTER.rd_byteenable; \
    MEM_SLAVE.rd_address = MEM_MASTER.rd_address; \
    MEM_SLAVE.rd_request = MEM_MASTER.rd_request; \
    MEM_SLAVE.wr_burstcount = MEM_MASTER.wr_burstcount; \
    MEM_SLAVE.wr_writedata = MEM_MASTER.wr_writedata; \
    MEM_SLAVE.wr_address = MEM_MASTER.wr_address; \
    MEM_SLAVE.wr_request = MEM_MASTER.wr_request; \
    MEM_SLAVE.wr_write = MEM_MASTER.wr_write; \
    MEM_SLAVE.wr_byteenable = MEM_MASTER.wr_byteenable

`define ofs_plat_avalon_mem_rdwr_if_from_master_to_slave_ff(MEM_SLAVE, MEM_MASTER) \
    MEM_SLAVE.rd_read <= MEM_MASTER.rd_read; \
    MEM_SLAVE.rd_burstcount <= MEM_MASTER.rd_burstcount; \
    MEM_SLAVE.rd_byteenable <= MEM_MASTER.rd_byteenable; \
    MEM_SLAVE.rd_address <= MEM_MASTER.rd_address; \
    MEM_SLAVE.rd_request <= MEM_MASTER.rd_request; \
    MEM_SLAVE.wr_burstcount <= MEM_MASTER.wr_burstcount; \
    MEM_SLAVE.wr_writedata <= MEM_MASTER.wr_writedata; \
    MEM_SLAVE.wr_address <= MEM_MASTER.wr_address; \
    MEM_SLAVE.wr_request <= MEM_MASTER.wr_request; \
    MEM_SLAVE.wr_write <= MEM_MASTER.wr_write; \
    MEM_SLAVE.wr_byteenable <= MEM_MASTER.wr_byteenable


// Note these do not set clk, reset or instance_number since those
// fields may be handled specially.
`define ofs_plat_avalon_mem_rdwr_if_from_slave_to_master_comb(MEM_MASTER, MEM_SLAVE) \
    MEM_MASTER.rd_waitrequest = MEM_SLAVE.rd_waitrequest; \
    MEM_MASTER.rd_readdata = MEM_SLAVE.rd_readdata; \
    MEM_MASTER.rd_readdatavalid = MEM_SLAVE.rd_readdatavalid; \
    MEM_MASTER.rd_response = MEM_SLAVE.rd_response; \
    MEM_MASTER.wr_waitrequest = MEM_SLAVE.wr_waitrequest; \
    MEM_MASTER.wr_writeresponsevalid = MEM_SLAVE.wr_writeresponsevalid; \
    MEM_MASTER.wr_response = MEM_SLAVE.wr_response

// Note the lack of waitrequest in the non-blocking assignment. The
// ready/enable protocol must be handled explicitly.
`define ofs_plat_avalon_mem_rdwr_if_from_slave_to_master_ff(MEM_MASTER, MEM_SLAVE) \
    MEM_MASTER.rd_waitrequest <= MEM_SLAVE.rd_waitrequest; \
    MEM_MASTER.rd_readdata <= MEM_SLAVE.rd_readdata; \
    MEM_MASTER.rd_readdatavalid <= MEM_SLAVE.rd_readdatavalid; \
    MEM_MASTER.rd_response <= MEM_SLAVE.rd_response; \
    MEM_MASTER.wr_waitrequest <= MEM_SLAVE.wr_waitrequest; \
    MEM_MASTER.wr_writeresponsevalid <= MEM_SLAVE.wr_writeresponsevalid; \
    MEM_MASTER.wr_response <= MEM_SLAVE.wr_response


//
// Initialization macros ought to just be tasks in the interface, but QuestSim
// treats tasks as active even if they are never invoked, leading to errors
// about multiple drivers.
//

`define ofs_plat_avalon_mem_rdwr_if_init_master_comb(MEM_MASTER) \
    MEM_SLAVE.rd_read = 1'b0; \
    MEM_SLAVE.rd_burstcount = '0; \
    MEM_SLAVE.rd_byteenable = '0; \
    MEM_SLAVE.rd_address = '0; \
    MEM_SLAVE.rd_request = '0; \
    MEM_SLAVE.wr_burstcount = '0; \
    MEM_SLAVE.wr_writedata = '0; \
    MEM_SLAVE.wr_address = '0; \
    MEM_SLAVE.wr_request = '0; \
    MEM_SLAVE.wr_write = 1'b0; \
    MEM_SLAVE.wr_byteenable = '0

`define ofs_plat_avalon_mem_rdwr_if_init_master_ff(MEM_MASTER) \
    MEM_SLAVE.rd_read <= 1'b0; \
    MEM_SLAVE.rd_burstcount <= '0; \
    MEM_SLAVE.rd_byteenable <= '0; \
    MEM_SLAVE.rd_address <= '0; \
    MEM_SLAVE.rd_request <= '0; \
    MEM_SLAVE.wr_burstcount <= '0; \
    MEM_SLAVE.wr_writedata <= '0; \
    MEM_SLAVE.wr_address <= '0; \
    MEM_SLAVE.wr_request <= '0; \
    MEM_SLAVE.wr_write <= 1'b0; \
    MEM_SLAVE.wr_byteenable <= '0

`define ofs_plat_avalon_mem_rdwr_if_init_slave_comb(MEM_SLAVE) \
    MEM_MASTER.rd_waitrequest = 1'b0; \
    MEM_MASTER.rd_readdata = '0; \
    MEM_MASTER.rd_readdatavalid = 1'b0; \
    MEM_MASTER.rd_response = '0; \
    MEM_MASTER.wr_waitrequest = 1'b0; \
    MEM_MASTER.wr_writeresponsevalid = 1'b0; \
    MEM_MASTER.wr_response = '0

`define ofs_plat_avalon_mem_rdwr_if_init_slave_ff(MEM_SLAVE) \
    MEM_MASTER.rd_waitrequest <= 1'b0; \
    MEM_MASTER.rd_readdata <= '0; \
    MEM_MASTER.rd_readdatavalid <= 1'b0; \
    MEM_MASTER.rd_response <= '0; \
    MEM_MASTER.wr_waitrequest <= 1'b0; \
    MEM_MASTER.wr_writeresponsevalid <= 1'b0; \
    MEM_MASTER.wr_response <= '0


`endif // __OFS_PLAT_AVALON_MEM_RDWR_IF_VH__
