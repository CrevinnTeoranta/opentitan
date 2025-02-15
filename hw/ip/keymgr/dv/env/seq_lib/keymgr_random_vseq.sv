// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Randomize sw control content: version, rom_ext_desc, salt, binding.
class keymgr_random_vseq extends keymgr_sideload_vseq;
  `uvm_object_utils(keymgr_random_vseq)
  `uvm_object_new

  rand bit is_key_version_err;

  constraint is_key_version_err_c {
    is_key_version_err == 0;
  }

  task write_random_sw_content();
    bit [TL_DW-1:0] key_version_val;
    bit [TL_DW-1:0] max_creator_key_ver_val;
    bit [TL_DW-1:0] max_owner_int_key_ver_val;
    bit [TL_DW-1:0] max_owner_key_ver_val;
    bit [TL_DW-1:0] max_key_ver_val;
    uvm_reg         csr_update_q[$];

    csr_random_n_add_to_q(ral.sw_binding_0, csr_update_q);
    csr_random_n_add_to_q(ral.sw_binding_1, csr_update_q);
    csr_random_n_add_to_q(ral.sw_binding_2, csr_update_q);
    csr_random_n_add_to_q(ral.sw_binding_3, csr_update_q);
    csr_random_n_add_to_q(ral.salt_0, csr_update_q);
    csr_random_n_add_to_q(ral.salt_1, csr_update_q);
    csr_random_n_add_to_q(ral.salt_2, csr_update_q);
    csr_random_n_add_to_q(ral.salt_3, csr_update_q);

    csr_random_n_add_to_q(ral.max_creator_key_ver, csr_update_q);
    csr_random_n_add_to_q(ral.max_owner_int_key_ver, csr_update_q);
    csr_random_n_add_to_q(ral.max_owner_key_ver, csr_update_q);

    csr_random_n_add_to_q(ral.max_creator_key_ver_en, csr_update_q);
    csr_random_n_add_to_q(ral.max_owner_int_key_ver_en, csr_update_q);
    csr_random_n_add_to_q(ral.max_owner_key_ver_en, csr_update_q);

    csr_update_q.shuffle();
    foreach (csr_update_q[i]) csr_update(csr_update_q[i]);

    max_creator_key_ver_val   = `gmv(ral.max_creator_key_ver);
    max_owner_int_key_ver_val = `gmv(ral.max_owner_int_key_ver);
    max_owner_key_ver_val     = `gmv(ral.max_owner_key_ver);
    max_key_ver_val = (current_state == keymgr_pkg::StCreatorRootKey)
        ? max_creator_key_ver_val : (current_state == keymgr_pkg::StOwnerIntKey)
        ? max_owner_int_key_ver_val : (current_state == keymgr_pkg::StOwnerKey)
        ? max_owner_key_ver_val : '1;
    `DV_CHECK_MEMBER_RANDOMIZE_FATAL(is_key_version_err)
    `DV_CHECK_STD_RANDOMIZE_WITH_FATAL(key_version_val,
                                       if (is_key_version_err) {
                                         max_key_ver_val != '1 -> key_version_val > max_key_ver_val;
                                       } else {
                                         key_version_val <= max_key_ver_val;
                                       })
    ral.key_version.set(key_version_val);
    csr_update(ral.key_version);
  endtask : write_random_sw_content

  task csr_random_n_add_to_q(uvm_reg csr, ref uvm_reg csr_q[$]);
    `DV_CHECK_RANDOMIZE_FATAL(csr)
    csr_q.push_back(csr);
  endtask

  virtual task keymgr_operations(bit advance_state = $urandom_range(0, 1),
                                 int num_gen_op    = $urandom_range(1, 4),
                                 bit clr_output    = $urandom_range(0, 1),
                                 bit wait_done     = 1);
    if ($urandom_range(0, 1)) begin
      `uvm_info(`gfn, "Write random SW content", UVM_MEDIUM)
      write_random_sw_content();
    end
    if ($urandom_range(0, 1)) begin
      `uvm_info(`gfn, "Drive random HW data", UVM_MEDIUM)
      cfg.keymgr_vif.drive_random_hw_input_data();
    end
    super.keymgr_operations(advance_state, num_gen_op, clr_output, wait_done);
  endtask : keymgr_operations

  // override body to add more randomization
  task body();
    keymgr_pkg::keymgr_working_state_e state;
    `uvm_info(`gfn, "Key manager seq start", UVM_HIGH)
    // Advance from StReset to last state StDisabled and advance one extra time,
    // then it should stay at StDisabled
    // In each state check SW/HW output
    repeat (state.num() + 1) begin
      keymgr_operations(.advance_state(1),
                        .num_gen_op($urandom_range(0, 5)),
                        .clr_output($urandom_range(0, 1)));
    end

  endtask : body

endclass : keymgr_random_vseq
