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
// Generate TLP reads for AFU read requests.
//

`include "ofs_plat_if.vh"

module ofs_plat_host_chan_@group@_gen_rd_tlps
  #(
    // Does the platform allow more than one read request in a single TLP vector?
    parameter ALLOW_DUAL_RD_REQS = 0
    )
   (
    input  logic clk,
    input  logic reset_n,

    // Track read requests from AFU (t_gen_tx_afu_rd_req)
    ofs_plat_axi_stream_if.to_source afu_rd_req,

    // Output read request TLP stream
    ofs_plat_axi_stream_if.to_sink tx_rd_tlps,

    // Input completion TLP stream. It is generally ok to pass the raw
    // stream here. The code here will look only at completion packets.
    ofs_plat_axi_stream_if.to_source rx_cpl_tlps,

    // Read responses to AFU (t_gen_tx_afu_rd_rsp)
    ofs_plat_axi_stream_if.to_sink afu_rd_rsp,

    // Dataless write fence completions are received by the read pipeline
    // The tag value is forwarded to the write pipeline, which will
    // generate the AFU response. The tag is released for reuse in the
    // read pipeline below. (t_dma_rd_tag)
    ofs_plat_axi_stream_if.to_sink wr_fence_cpl,

    // Are CPLD tags still available? If not, reads will block until a
    // response arrives. This port exists for tuning of read/write
    // arbitration. It is not required for correct functioning.
    output logic tlp_cpld_tag_available,

    output logic error
    );

    import ofs_plat_host_chan_@group@_pcie_tlp_pkg::*;
    import ofs_plat_host_chan_@group@_gen_tlps_pkg::*;
    import ofs_plat_pcie_tlp_hdr_pkg::*;

    assign error = 1'b0;

    // ====================================================================
    //
    //  Store requests in a FIFO before arbitration.
    //
    // ====================================================================

    t_gen_tx_afu_rd_req rd_req;
    logic rd_req_deq;
    logic rd_req_notEmpty;

    // Pre-compute OR of high address bits, needed for choosing either
    // MRd32 or MRd64. PCIe doesn't allow MRd64 when the address fits
    // in 32 bits.
    logic rd_req_is_addr64;
    logic afu_rd_req_is_addr64;
    assign afu_rd_req_is_addr64 = |(afu_rd_req.t.data.addr[63:32]);

    ofs_plat_prim_fifo2
      #(
        .N_DATA_BITS(1 + $bits(t_gen_tx_afu_rd_req))
        )
      afu_req_fifo
       (
        .clk,
        .reset_n,

        .enq_data({ afu_rd_req_is_addr64, afu_rd_req.t.data }),
        .enq_en(afu_rd_req.tvalid && afu_rd_req.tready),
        .notFull(afu_rd_req.tready),

        .first({ rd_req_is_addr64, rd_req }),
        .deq_en(rd_req_deq),
        .notEmpty(rd_req_notEmpty)
        );


    // ====================================================================
    //
    //  Maintain a UID space for tagging PCIe read requests and write
    //  fences.
    //
    // ====================================================================

    logic req_tlp_tag_ready;
    t_dma_rd_tag req_tlp_tag;

    logic free_tlp_tag;
    t_dma_rd_tag free_tlp_tag_value;

    ofs_plat_prim_uid
      #(
        .N_ENTRIES(MAX_OUTSTANDING_DMA_RD_REQS),
        // Reserve the low MAX_OUTSTANDING_DMA_WR_FENCES slots for write fences
        .N_RESERVED(MAX_OUTSTANDING_DMA_WR_FENCES)
        )
      tags
       (
        .clk,
        .reset_n,

        // New tag needed when either the write fence tag stream is ready
        // (the stream holds a couple of entries) or a read request was
        // processed.
        .alloc(rd_req_deq),
        .alloc_ready(req_tlp_tag_ready),
        .alloc_uid(req_tlp_tag),

        .free(free_tlp_tag),
        .free_uid(free_tlp_tag_value)
        );

    always_ff @(posedge clk)
    begin
        tlp_cpld_tag_available <= req_tlp_tag_ready;
    end


    // ====================================================================
    //
    //  Record request details, indexed by PCIe request tags.
    //
    // ====================================================================

    typedef struct packed {
        // AFU's original tag, returned with the read response
        logic [AFU_TAG_WIDTH-1 : 0] afu_tag;
        // Number of lines in the entire transaction
        t_tlp_payload_line_count line_count;
    } t_pcie_rd_meta;

    t_pcie_rd_meta new_rd_req_meta;
    always_comb
    begin
        new_rd_req_meta.afu_tag = rd_req.tag;
        new_rd_req_meta.line_count = rd_req.line_count;
    end

    t_dma_rd_tag rd_rsp_tlp_tag;
    t_pcie_rd_meta rd_rsp_meta;

    ofs_plat_prim_lutram
      #(
        .N_ENTRIES(MAX_OUTSTANDING_DMA_RD_REQS),
        .N_DATA_BITS($bits(t_pcie_rd_meta))
        )
      rd_meta
       (
        .clk,
        .reset_n,

        .wen(rd_req_deq),
        .waddr(req_tlp_tag),
        .wdata(new_rd_req_meta),

        .raddr(rd_rsp_tlp_tag),
        .rdata(rd_rsp_meta)
        );


    // ====================================================================
    //
    //  Map AFU read request to TLP
    //
    // ====================================================================

    assign rd_req_deq = rd_req_notEmpty &&
                        req_tlp_tag_ready &&
                        (tx_rd_tlps.tready || !tx_rd_tlps.tvalid);
    assign tx_rd_tlps.t.data = '0;
    assign tx_rd_tlps.t.keep = '0;

    t_ofs_plat_pcie_hdr tlp_mem_hdr;
    always_comb
    begin
        tlp_mem_hdr = '0;

        tlp_mem_hdr.fmttype = rd_req_is_addr64 ? OFS_PLAT_PCIE_FMTTYPE_MEM_READ64 :
                                                 OFS_PLAT_PCIE_FMTTYPE_MEM_READ32;
        tlp_mem_hdr.length = lineCountToDwordLen(rd_req.line_count);
        tlp_mem_hdr.u.mem_req.addr = rd_req.addr;
        tlp_mem_hdr.u.mem_req.tag = { '0, req_tlp_tag };
        tlp_mem_hdr.u.mem_req.last_be = 4'b1111;
        tlp_mem_hdr.u.mem_req.first_be = 4'b1111;
    end

    always_ff @(posedge clk)
    begin
        if (tx_rd_tlps.tready || !tx_rd_tlps.tvalid)
        begin
            tx_rd_tlps.tvalid <= rd_req_notEmpty && req_tlp_tag_ready;

            tx_rd_tlps.t.user <= '0;
            tx_rd_tlps.t.last <= 1'b1;

            tx_rd_tlps.t.user[0].sop <= rd_req_notEmpty;
            tx_rd_tlps.t.user[0].eop <= rd_req_notEmpty;

            tx_rd_tlps.t.user[0].hdr <= tlp_mem_hdr;
        end

        if (!reset_n)
        begin
            tx_rd_tlps.tvalid <= 1'b0;
        end
    end


    // ====================================================================
    //
    //  Process completions (read responses)
    //
    // ====================================================================

    t_ofs_plat_pcie_hdr tlp_cpl_hdr;
    assign tlp_cpl_hdr = rx_cpl_tlps.t.user[0].hdr;
    assign rd_rsp_tlp_tag = t_dma_rd_tag'(tlp_cpl_hdr.u.cpl.tag);

    assign rx_cpl_tlps.tready = (!afu_rd_rsp.tvalid || afu_rd_rsp.tready) &&
                                wr_fence_cpl.tready;

    // Write fence completions are forwarded to the write pipeline
    logic rsp_is_wr_fence;
    assign rsp_is_wr_fence = (rd_rsp_tlp_tag < t_dma_rd_tag'(MAX_OUTSTANDING_DMA_WR_FENCES));

    always_comb
    begin
        wr_fence_cpl.tvalid =
            rx_cpl_tlps.tready && rx_cpl_tlps.tvalid &&
            rx_cpl_tlps.t.user[0].sop &&
            ofs_plat_pcie_func_is_completion(tlp_cpl_hdr.fmttype) &&
            rsp_is_wr_fence;
        wr_fence_cpl.t.data = rd_rsp_tlp_tag;
    end

    // Record header details for handling multi-beat responses
    logic afu_rd_rsp_active, reg_afu_rd_rsp_active;
    logic afu_rd_rsp_is_last, reg_afu_rd_rsp_is_last;
    logic [AFU_TAG_WIDTH-1 : 0] afu_rd_rsp_tag, reg_afu_rd_rsp_tag;
    t_tlp_payload_line_idx afu_rd_rsp_line_idx, reg_afu_rd_rsp_line_idx;
    t_dma_rd_tag reg_afu_rd_rsp_tlp_tag;

    // Figure out details of a response flit. The computed state is valid
    // both in the SOP cycle and subsequent beats.
    always_comb
    begin
        if (rx_cpl_tlps.t.user[0].sop)
        begin
            // Starting a new response -- completion with data?
            afu_rd_rsp_active =
                ofs_plat_pcie_func_is_completion(tlp_cpl_hdr.fmttype) &&
                ofs_plat_pcie_func_has_data(tlp_cpl_hdr.fmttype) &&
                !rsp_is_wr_fence;

            // The last response packet if the remaining bytes matches the length
            // of this packet. This still is not necessarily the last beat. Check EOP
            // for the last beat.
            afu_rd_rsp_is_last = (tlp_cpl_hdr.u.cpl.byte_count[11:2] == tlp_cpl_hdr.length);
            afu_rd_rsp_tag = rd_rsp_meta.afu_tag;
            // byte_count is the number of bytes still remaining. We can use it
            // to compute the line index relative to the entire repsonse, even
            // if the response is broken into multiple packets.
            afu_rd_rsp_line_idx = rd_rsp_meta.line_count -
                                  dwordLenToLineCount(tlp_cpl_hdr.u.cpl.byte_count[11:2]);
        end
        else
        begin
            // Continuing a response?
            afu_rd_rsp_active = reg_afu_rd_rsp_active;
            afu_rd_rsp_is_last = reg_afu_rd_rsp_is_last;
            afu_rd_rsp_tag = reg_afu_rd_rsp_tag;
            afu_rd_rsp_line_idx = reg_afu_rd_rsp_line_idx + 1;
        end

        if (!rx_cpl_tlps.tvalid)
        begin
            // Nothing this cycle (may still be in the middle of a mult-cycle response)
            afu_rd_rsp_active = 1'b0;
        end
    end

    logic rx_cpl_tlps_eop;
    assign rx_cpl_tlps_eop = ofs_plat_pcie_func_is_eop(rx_cpl_tlps.t.user);

    // Record SOP state for subsequent flits
    always_ff @(posedge clk)
    begin
        if (rx_cpl_tlps.tready && rx_cpl_tlps.tvalid)
        begin
            reg_afu_rd_rsp_active <= afu_rd_rsp_active && !rx_cpl_tlps_eop;
            reg_afu_rd_rsp_is_last <= afu_rd_rsp_is_last;
            reg_afu_rd_rsp_tag <= afu_rd_rsp_tag;
            reg_afu_rd_rsp_line_idx <= afu_rd_rsp_line_idx;

            if (rx_cpl_tlps.t.user[0].sop)
            begin
                reg_afu_rd_rsp_tlp_tag <= rd_rsp_tlp_tag;
            end
        end

        if (!reset_n)
        begin
            reg_afu_rd_rsp_active <= 1'b0;
        end
    end

    // Send responses to the AFU
    always_ff @(posedge clk)
    begin
        if (rx_cpl_tlps.tready)
        begin
            afu_rd_rsp.tvalid <= afu_rd_rsp_active;
            afu_rd_rsp.t.data.tag <= afu_rd_rsp_tag;
            afu_rd_rsp.t.data.line_idx <= afu_rd_rsp_line_idx;
            afu_rd_rsp.t.data.last <= afu_rd_rsp_is_last && rx_cpl_tlps_eop;
            afu_rd_rsp.t.data.payload <= { '0, rx_cpl_tlps.t.data };
        end

        if (!reset_n)
        begin
            afu_rd_rsp.tvalid <= 1'b0;
        end
    end

    // Release TLP tags when transactions complete
    assign free_tlp_tag = afu_rd_rsp.tvalid && afu_rd_rsp.tready && afu_rd_rsp.t.data.last;
    assign free_tlp_tag_value = reg_afu_rd_rsp_tlp_tag;

    // synthesis translate_off
    always_ff @(negedge clk)
    begin
        if (reset_n)
        begin
            if (rx_cpl_tlps.tvalid && rx_cpl_tlps.t.user[0].sop)
            begin
                assert(!reg_afu_rd_rsp_active) else
                  $fatal(2, " ** ERROR ** %m: SOP in the middle of an active read completion!");
            end

            if (rx_cpl_tlps.tready && rx_cpl_tlps.tvalid && rx_cpl_tlps.t.user[0].sop &&
                ofs_plat_pcie_func_is_completion(tlp_cpl_hdr.fmttype) &&
                !rsp_is_wr_fence)
            begin
                assert(ofs_plat_pcie_func_has_data(tlp_cpl_hdr.fmttype)) else
                    $fatal(2, " ** ERROR ** %m: Completion WITHOUT data for read (tag 0x%x)", rd_rsp_tlp_tag);
            end
        end
    end
    // synthesis translate_on

endmodule // ofs_plat_host_chan_@group@_gen_rd_tlps
