// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
module tb;
  // dep packages
  import uvm_pkg::*;
  import dv_utils_pkg::*;
  import otp_ctrl_env_pkg::*;
  import otp_ctrl_test_pkg::*;
  import otp_ctrl_reg_pkg::*;
  import lc_ctrl_pkg::*;

  // macro includes
  `include "uvm_macros.svh"
  `include "dv_macros.svh"

  wire clk, rst_n;
  wire devmode;
  wire lc_ctrl_pkg::lc_tx_e lc_dft_en, lc_escalate_en, lc_check_byp_en;
  wire lc_ctrl_pkg::lc_tx_e lc_creator_seed_sw_rw_en, lc_seed_hw_rd_en;
  wire [OtpPwrIfWidth-1:0] pwr_otp;
  wire otp_ctrl_pkg::flash_otp_key_req_t flash_req;
  wire otp_ctrl_pkg::flash_otp_key_rsp_t flash_rsp;
  wire otp_ctrl_pkg::otbn_otp_key_req_t  otbn_req;
  wire otp_ctrl_pkg::otbn_otp_key_rsp_t  otbn_rsp;
  wire otp_ctrl_pkg::sram_otp_key_req_t[NumSramKeyReqSlots-1:0] sram_req;
  wire otp_ctrl_pkg::sram_otp_key_rsp_t[NumSramKeyReqSlots-1:0] sram_rsp;

  wire [NUM_MAX_INTERRUPTS-1:0] interrupts;
  wire intr_otp_operation_done, intr_otp_error;

  //TODO: use push-pull agent once support
  wire otp_ctrl_pkg::otp_ast_req_t        ast_req;

  // interfaces
  clk_rst_if clk_rst_if(.clk(clk), .rst_n(rst_n));
  pins_if #(NUM_MAX_INTERRUPTS) intr_if(interrupts);
  pins_if #(1) devmode_if(devmode);

  // lc_otp interfaces
  push_pull_if #(.HostDataWidth(LC_PROG_DATA_SIZE), .DeviceDataWidth(1))
                 lc_prog_if(.clk(clk), .rst_n(rst_n));
  push_pull_if #(.HostDataWidth(lc_ctrl_pkg::LcTokenWidth)) lc_token_if(.clk(clk), .rst_n(rst_n));

  push_pull_if #(.DeviceDataWidth(SRAM_DATA_SIZE))
                 sram_if[NumSramKeyReqSlots](.clk(clk), .rst_n(rst_n));
  push_pull_if #(.DeviceDataWidth(OTBN_DATA_SIZE)) otbn_if(.clk(clk), .rst_n(rst_n));
  push_pull_if #(.DeviceDataWidth(FLASH_DATA_SIZE)) flash_addr_if(.clk(clk), .rst_n(rst_n));
  push_pull_if #(.DeviceDataWidth(FLASH_DATA_SIZE)) flash_data_if(.clk(clk), .rst_n(rst_n));
  push_pull_if #(.DeviceDataWidth(cip_base_pkg::EDN_DATA_WIDTH)) edn_if(.clk(clk), .rst_n(rst_n));

  pins_if #(OtpPwrIfWidth) pwr_otp_if(pwr_otp);
  // TODO: use standard req/rsp agent
  pins_if #(4) lc_creator_seed_sw_rw_en_if(lc_creator_seed_sw_rw_en);
  pins_if #(4) lc_seed_hw_rd_en_if(lc_seed_hw_rd_en);
  pins_if #(4) lc_dft_en_if(lc_dft_en);
  pins_if #(4) lc_escalate_en_if(lc_escalate_en);
  pins_if #(4) lc_check_byp_en_if(lc_check_byp_en);

  tl_if tl_if(.clk(clk), .rst_n(rst_n));

  otp_ctrl_output_data_if otp_ctrl_output_data_if();

  `DV_ALERT_IF_CONNECT

  // dut
  otp_ctrl dut (
    .clk_i                      (clk        ),
    .rst_ni                     (rst_n      ),
    // edn
    // TODO: consider connecting this to a different clock.
    .clk_edn_i                  (clk        ),
    .rst_edn_ni                 (rst_n      ),
    .edn_o                      (edn_if.req ),
    .edn_i                      ({edn_if.ack, edn_if.d_data}),

    .tl_i                       (tl_if.h2d  ),
    .tl_o                       (tl_if.d2h  ),
    // interrupt
    .intr_otp_operation_done_o  (intr_otp_operation_done),
    .intr_otp_error_o           (intr_otp_error),
    // alert
    .alert_rx_i                 (alert_rx   ),
    .alert_tx_o                 (alert_tx   ),
    // ast
    .otp_ast_pwr_seq_o          (ast_req),
    .otp_ast_pwr_seq_h_i        ('0),
    // pwrmgr
    .pwr_otp_i                  (pwr_otp[OtpPwrInitReq]),
    .pwr_otp_o                  (pwr_otp[OtpPwrDoneRsp:OtpPwrIdleRsp]),
    // lc
    .lc_otp_program_i           ({lc_prog_if.req, lc_prog_if.h_data}),
    .lc_otp_program_o           ({lc_prog_if.d_data, lc_prog_if.ack}),
    .lc_otp_token_i             ({lc_token_if.req, lc_token_if.h_data}),
    .lc_otp_token_o             ({lc_token_if.ack, lc_token_if.d_data}),
    .lc_creator_seed_sw_rw_en_i (lc_creator_seed_sw_rw_en),
    .lc_seed_hw_rd_en_i         (lc_seed_hw_rd_en),
    .lc_dft_en_i                (lc_dft_en),
    .lc_escalate_en_i           (lc_escalate_en),
    .lc_check_byp_en_i          (lc_check_byp_en),
    .otp_lc_data_o              (otp_ctrl_output_data_if.lc_data),
    // keymgr
    .otp_keymgr_key_o           (otp_ctrl_output_data_if.keymgr_key),
    // flash
    .flash_otp_key_i            (flash_req),
    .flash_otp_key_o            (flash_rsp),
    // sram
    .sram_otp_key_i             (sram_req),
    .sram_otp_key_o             (sram_rsp),
    // otbn
    .otbn_otp_key_i             (otbn_req),
    .otbn_otp_key_o             (otbn_rsp),

    .otp_hw_cfg_o               (otp_ctrl_output_data_if.otp_hw_cfg)
  );

  for (genvar i = 0; i < NumSramKeyReqSlots; i++) begin : gen_sram_pull_if
    assign sram_req[i]       = sram_if[i].req;
    assign sram_if[i].ack    = sram_rsp[i].ack;
    assign sram_if[i].d_data = {sram_rsp[i].key, sram_rsp[i].nonce, sram_rsp[i].seed_valid};
    initial begin
      uvm_config_db#(virtual push_pull_if#(.DeviceDataWidth(SRAM_DATA_SIZE)))::set(null,
                     $sformatf("*env.m_sram_pull_agent[%0d]*", i), "vif", sram_if[i]);
    end
  end
  assign otbn_req       = otbn_if.req;
  assign otbn_if.ack    = otbn_rsp.ack;
  assign otbn_if.d_data = {otbn_rsp.key, otbn_rsp.nonce, otbn_rsp.seed_valid};

  assign flash_req            = {flash_data_if.req, flash_addr_if.req};
  assign flash_data_if.ack    = flash_rsp.data_ack;
  assign flash_addr_if.ack    = flash_rsp.addr_ack;
  assign flash_data_if.d_data = {flash_rsp.key, flash_rsp.seed_valid};
  assign flash_addr_if.d_data = {flash_rsp.key, flash_rsp.seed_valid};

  // bind mem_bkdr_if
  `define OTP_CTRL_MEM_HIER \
      dut.u_otp.gen_generic.u_impl_generic.u_prim_ram_1p_adv.u_mem.gen_generic.u_impl_generic

  assign interrupts[OtpOperationDone] = intr_otp_operation_done;
  assign interrupts[OtpErr]           = intr_otp_error;

  bind `OTP_CTRL_MEM_HIER mem_bkdr_if mem_bkdr_if();

  initial begin
    // drive clk and rst_n from clk_if
    clk_rst_if.set_active();
    uvm_config_db#(virtual clk_rst_if)::set(null, "*.env", "clk_rst_vif", clk_rst_if);
    uvm_config_db#(virtual tl_if)::set(null, "*.env.m_tl_agent*", "vif", tl_if);
    uvm_config_db#(virtual push_pull_if#(.DeviceDataWidth(OTBN_DATA_SIZE)))::set(null,
                   "*env.m_otbn_pull_agent*", "vif", otbn_if);
    uvm_config_db#(virtual push_pull_if#(.DeviceDataWidth(FLASH_DATA_SIZE)))::set(null,
                   "*env.m_flash_data_pull_agent*", "vif", flash_data_if);
    uvm_config_db#(virtual push_pull_if#(.DeviceDataWidth(FLASH_DATA_SIZE)))::set(null,
                   "*env.m_flash_addr_pull_agent*", "vif", flash_addr_if);
    uvm_config_db#(virtual push_pull_if#(.DeviceDataWidth(cip_base_pkg::EDN_DATA_WIDTH)))::
                   set(null, "*env.m_edn_pull_agent*", "vif", edn_if);
    uvm_config_db#(virtual push_pull_if#(.HostDataWidth(LC_PROG_DATA_SIZE), .DeviceDataWidth(1)))::
                   set(null, "*env.m_lc_prog_pull_agent*", "vif", lc_prog_if);
    uvm_config_db#(virtual push_pull_if#(.HostDataWidth(lc_ctrl_pkg::LcTokenWidth)))::
                   set(null, "*env.m_lc_token_pull_agent*", "vif", lc_token_if);

    uvm_config_db#(intr_vif)::set(null, "*.env", "intr_vif", intr_if);
    uvm_config_db#(pwr_otp_vif)::set(null, "*.env", "pwr_otp_vif", pwr_otp_if);
    uvm_config_db#(devmode_vif)::set(null, "*.env", "devmode_vif", devmode_if);
    uvm_config_db#(lc_creator_seed_sw_rw_en_vif)::set(null, "*.env", "lc_creator_seed_sw_rw_en_vif",
                                                      lc_creator_seed_sw_rw_en_if);
    uvm_config_db#(lc_seed_hw_rd_en_vif)::set(null, "*.env", "lc_seed_hw_rd_en_vif",
                                              lc_seed_hw_rd_en_if);
    uvm_config_db#(lc_dft_en_vif)::set(null, "*.env", "lc_dft_en_vif", lc_dft_en_if);
    uvm_config_db#(lc_escalate_en_vif)::set(null, "*.env", "lc_escalate_en_vif", lc_escalate_en_if);
    uvm_config_db#(lc_check_byp_en_vif)::set(null, "*.env", "lc_check_byp_en_vif",
                                             lc_check_byp_en_if);
    uvm_config_db#(mem_bkdr_vif)::set(null, "*.env", "mem_bkdr_vif",
                                      `OTP_CTRL_MEM_HIER.mem_bkdr_if);

    uvm_config_db#(virtual otp_ctrl_output_data_if)::set(null, "*.env", "otp_ctrl_output_data_vif",
                                                 otp_ctrl_output_data_if);
    $timeformat(-12, 0, " ps", 12);
    run_test();
  end

  `undef OTP_CTRL_MEM_HIER
endmodule
