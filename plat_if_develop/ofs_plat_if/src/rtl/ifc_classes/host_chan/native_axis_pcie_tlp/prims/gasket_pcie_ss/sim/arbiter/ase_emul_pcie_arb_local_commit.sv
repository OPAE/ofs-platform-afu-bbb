// Copyright 2020 Intel Corporation.
//
// THIS SOFTWARE MAY CONTAIN PREPRODUCTION CODE AND IS PROVIDED BY THE
// COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED
// WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
// MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
// BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
// WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
// OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
// EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// Description
//-----------------------------------------------------------------------------
//
// Monitor the sink->source stream. When a write request is detected, emit
// a completion without data on the commit stream.
//
// These locally generated commits are used along with the dual (A/B) PF/VF
// MUX tree. Commits are forwarded to AFUs so they can track the point at
// which the relative order of the A and B streams is guaranteed.
//
// The tag, length and metadata extension fields are looped back from
// each write request into the generated completion.
//
// Responses are also generated for DM encoded interrupt requests.
// Bit 0 of TC will always be set to one for a generated interrupt
// completion and 0 for a normal write completion. The interrupt vector_num
// is returned in metadata_l of the generated completion.
//
//-----------------------------------------------------------------------------

module ase_emul_pcie_arb_local_commit #(
   parameter TDATA_WIDTH = ofs_pcie_ss_cfg_pkg::TDATA_WIDTH,
   parameter TUSER_WIDTH = ofs_pcie_ss_cfg_pkg::TUSER_WIDTH
)(
   input  wire clk,
   input  wire rst_n,

   pcie_ss_axis_if.sink   sink,
   pcie_ss_axis_if.source source,
   pcie_ss_axis_if.source commit
);

   import pcie_ss_hdr_pkg::*;

   pcie_ss_axis_if commit_in(clk, rst_n);
   logic sink_sop;
   logic rx_pending, rx_ready;

   wire commit_in_ready = (commit_in.tready || !rx_pending);

   assign sink.tready = source.tready && commit_in_ready;
   assign source.tvalid = sink.tvalid && commit_in_ready;
   assign source.tdata = sink.tdata;
   assign source.tkeep = sink.tkeep;
   assign source.tlast = sink.tlast;
   assign source.tuser_vendor = sink.tuser_vendor;

   // TX data, viewed as either PU or DM headers
   PCIe_ReqHdr_t   tx_req_dm_hdr;
   PCIe_PUReqHdr_t tx_req_pu_hdr;
   PCIe_IntrHdr_t  tx_req_dm_intr;
   assign tx_req_dm_hdr = PCIe_ReqHdr_t'(sink.tdata);
   assign tx_req_pu_hdr = PCIe_PUReqHdr_t'(sink.tdata);
   assign tx_req_dm_intr = PCIe_IntrHdr_t'(sink.tdata);

   // Valid/ready bits are checked separately
   wire tx_is_dm = func_hdr_is_dm_mode(sink.tuser_vendor);
   wire tx_is_wr_req = func_is_mwr_req(tx_req_dm_hdr.fmt_type);
   wire tx_is_intr_req = tx_is_dm && func_is_interrupt_req(tx_req_dm_hdr.fmt_type);
   wire tx_needs_cpl = sink_sop && (tx_is_wr_req || tx_is_intr_req);

   PCIe_CplHdr_t   rx_cmp_dm_hdr;
   PCIe_PUCplHdr_t rx_cmp_pu_hdr;
   PCIe_CplHdr_t   rx_cmp_dm_intr;

   // Generate local completion, mostly returning a copy of the input fields
   always_comb begin
      // Completion (without data) in DM mode, to match a DM write
      rx_cmp_dm_hdr = '0;
      rx_cmp_dm_hdr.fmt_type   = ReqHdr_FmtType_e'({ '0, PCIE_FMTTYPE_CPL });
      rx_cmp_dm_hdr.metadata_l = tx_req_dm_hdr.metadata_l;
      rx_cmp_dm_hdr.metadata_h = tx_req_dm_hdr.metadata_h;
      rx_cmp_dm_hdr.vf_active  = tx_req_dm_hdr.vf_active;
      rx_cmp_dm_hdr.vf_num     = tx_req_dm_hdr.vf_num;
      rx_cmp_dm_hdr.pf_num     = tx_req_dm_hdr.pf_num;
      rx_cmp_dm_hdr.length_h   = tx_req_dm_hdr.length_h;
      rx_cmp_dm_hdr.length_m   = tx_req_dm_hdr.length_m;
      rx_cmp_dm_hdr.length_l   = tx_req_dm_hdr.length_l;
      rx_cmp_dm_hdr.tag        = { tx_req_dm_hdr.tag_h, tx_req_dm_hdr.tag_m, tx_req_dm_hdr.tag_l };
      rx_cmp_dm_hdr.FC         = 1'b1;

      // Completion (without data) in PU mode, to match a PU write
      rx_cmp_pu_hdr = '0;
      rx_cmp_pu_hdr.fmt_type   = ReqHdr_FmtType_e'({ '0, PCIE_FMTTYPE_CPL });
      rx_cmp_pu_hdr.metadata_l = tx_req_pu_hdr.metadata_l;
      rx_cmp_pu_hdr.metadata_h = tx_req_pu_hdr.metadata_h;
      rx_cmp_pu_hdr.req_id     = tx_req_pu_hdr.req_id;
      rx_cmp_pu_hdr.vf_active  = tx_req_pu_hdr.vf_active;
      rx_cmp_pu_hdr.vf_num     = tx_req_pu_hdr.vf_num;
      rx_cmp_pu_hdr.pf_num     = tx_req_pu_hdr.pf_num;
      rx_cmp_pu_hdr.length     = tx_req_pu_hdr.length;
      rx_cmp_pu_hdr.byte_count = tx_req_pu_hdr.length << 2;
      rx_cmp_pu_hdr.tag_h      = tx_req_pu_hdr.tag_h;
      rx_cmp_pu_hdr.tag_m      = tx_req_pu_hdr.tag_m;
      rx_cmp_pu_hdr.tag_l      = tx_req_pu_hdr.tag_l;

      // Completion (without data) in DM mode, to match a DM interrupt request
      rx_cmp_dm_intr = '0;
      rx_cmp_dm_intr.fmt_type   = ReqHdr_FmtType_e'({ '0, PCIE_FMTTYPE_CPL });
      rx_cmp_dm_intr.metadata_l = { '0, tx_req_dm_intr.vector_num };
      rx_cmp_dm_intr.vf_active  = tx_req_dm_intr.vf_active;
      rx_cmp_dm_intr.vf_num     = tx_req_dm_intr.vf_num;
      rx_cmp_dm_intr.pf_num     = tx_req_dm_intr.pf_num;
      rx_cmp_dm_intr.FC         = 1'b1;
      rx_cmp_dm_intr.TC[0]      = 1'b1;  // TC[0] set to 1 indicates interrupt
   end

   always_ff @(posedge clk)
   begin
      if (commit_in.tvalid && commit_in.tready) begin
         rx_pending <= 1'b0;
         rx_ready <= 1'b0;
      end

      if (sink.tvalid && sink.tready) begin
         sink_sop <= sink.tlast;

         if (tx_needs_cpl) begin
            rx_pending <= 1'b1;
            if (tx_is_wr_req)
               commit_in.tdata <= { '0, (tx_is_dm ? rx_cmp_dm_hdr : rx_cmp_pu_hdr) };
            else
               commit_in.tdata <= { '0, rx_cmp_dm_intr };
            commit_in.tuser_vendor <= sink.tuser_vendor;
         end
         if (sink.tlast && (tx_needs_cpl || rx_pending)) begin
            rx_ready <= 1'b1;
         end
      end

      if (!rst_n) begin
         rx_pending <= 1'b0;
         rx_ready <= 1'b0;
         sink_sop <= 1'b1;
      end
   end

   assign commit_in.tvalid = rx_pending && rx_ready;
   assign commit_in.tkeep = { '0, {($bits(PCIe_CplHdr_t)/8){1'b1}} };
   assign commit_in.tlast = 1'b1;

   ase_emul_pcie_ss_axis_pipeline #(
      .TDATA_WIDTH(TDATA_WIDTH),
      .TUSER_WIDTH(TUSER_WIDTH)
   ) commit_skid (
      .clk,
      .rst_n,
      .axis_s(commit_in),
      .axis_m(commit)
   );

endmodule // pcie_arb_local_commit
