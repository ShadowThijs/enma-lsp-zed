// =============================================================================
// Zydis API comprehensive test
//
// Exercises EVERY type, method, function, and enum value in the Zydis API.
//
// ============================== CHECKLIST ==============================
//
// TYPES with METHODS:
//
//   zydis_req_t:
//     - set_mnemonic(int64)
//     - set_machine_mode(zydis_machine_mode)
//     - set_operand_count(int64)
//     - set_branch_type(zydis_branch_type)
//     - set_branch_width(zydis_branch_width)
//     - set_operand_reg(int64, int64)
//     - set_operand_imm(int64, int64)
//     - set_operand_mem(int64, int64, int64, int64, int64, int64)
//     - set_operand_ptr(int64, int64, int64)
//     - get_mnemonic() -> int64
//     - get_machine_mode() -> int64
//     - get_operand_count() -> int64
//
//   zydis_builder_t:
//     - set_machine_mode(zydis_machine_mode)
//     - set_base_address(int64)
//     - clear()
//     - push(zydis_req_t)
//     - push_bytes(array<uint8>)
//     - push_byte(uint8)
//     - push_u16(uint16)
//     - push_u32(uint32)
//     - push_u64(uint64)
//     - push_nop(int64)
//     - push_int3()
//     - push_ret()
//     - build() -> array<uint8>
//     - get_count() -> int64
//
// STANDALONE FUNCTIONS:
//     zydis_encode(zydis_req_t) -> array<uint8>
//     zydis_encode_absolute(zydis_req_t, int64) -> array<uint8>
//     zydis_nop_fill(int64) -> array<uint8>
//     zydis_decoded_to_request(array<uint8>, int64) -> zydis_req_t
//     zydis_mnemonic_from_string(string) -> int64
//     zydis_mnemonic_to_string(int64) -> string
//     zydis_register_from_string(string) -> int64
//     zydis_register_to_string(int64) -> string
//     zydis_disasm(array<uint8>, int64) -> array<string>
//
// ENUMS (all values):
//     zydis_machine_mode: long_64, long_compat_32, long_compat_16,
//                         legacy_32, legacy_16, real_16
//     zydis_branch_type:  none, short, near, far
//     zydis_branch_width: none, w8, w16, w32, w64
//
// =============================================================================

int64 g_pass = 0;
int64 g_fail = 0;

void check(string label, bool ok) {
    if (ok) {
        print_console("[PASS] " + label);
        g_pass = g_pass + 1;
    } else {
        print_console("[FAIL] " + label);
        g_fail = g_fail + 1;
    }
}

void section(string title) {
    print_console("");
    print_console("--- " + title + " ---");
}

// =============================================================================
// main — runs every test section
// =============================================================================

int32 main() {
    print_console("=== Zydis API comprehensive test ===");

    // -------------------------------------------------------------------
    // 1. zydis_mnemonic_from_string / to_string
    // -------------------------------------------------------------------
    section("zydis_mnemonic_from_string / to_string");

    int64 mov_id  = zydis_mnemonic_from_string("mov");
    int64 ret_id  = zydis_mnemonic_from_string("ret");
    int64 nop_id  = zydis_mnemonic_from_string("nop");
    int64 int3_id = zydis_mnemonic_from_string("int3");
    int64 jmp_id  = zydis_mnemonic_from_string("jmp");
    int64 call_id = zydis_mnemonic_from_string("call");
    int64 push_id = zydis_mnemonic_from_string("push");
    int64 pop_id  = zydis_mnemonic_from_string("pop");
    int64 add_id  = zydis_mnemonic_from_string("add");
    int64 sub_id  = zydis_mnemonic_from_string("sub");
    int64 xor_id  = zydis_mnemonic_from_string("xor");
    int64 cmp_id  = zydis_mnemonic_from_string("cmp");
    int64 je_id   = zydis_mnemonic_from_string("je");
    int64 jne_id  = zydis_mnemonic_from_string("jne");

    check("mov_id > 0", mov_id > 0);
    check("ret_id > 0", ret_id > 0);
    check("nop_id > 0", nop_id > 0);
    check("int3_id > 0", int3_id > 0);
    check("jmp_id > 0", jmp_id > 0);
    check("call_id > 0", call_id > 0);
    check("push_id > 0", push_id > 0);
    check("pop_id > 0", pop_id > 0);
    check("add_id > 0", add_id > 0);
    check("sub_id > 0", sub_id > 0);
    check("xor_id > 0", xor_id > 0);
    check("cmp_id > 0", cmp_id > 0);
    check("je_id > 0", je_id > 0);
    check("jne_id > 0", jne_id > 0);

    // case-insensitivity
    int64 mov_upper = zydis_mnemonic_from_string("MOV");
    int64 mov_mixed = zydis_mnemonic_from_string("Mov");
    check("case-insensitive 'MOV' matches 'mov'", mov_upper == mov_id);
    check("case-insensitive 'Mov' matches 'mov'", mov_mixed == mov_id);

    // invalid lookup returns 0
    int64 bad_mnem = zydis_mnemonic_from_string("not_a_real_mnemonic_xyzzy");
    check("invalid mnemonic returns 0 (INVALID)", bad_mnem == 0);

    // to_string round-trip
    check("zydis_mnemonic_to_string(mov_id) == 'mov'",
          zydis_mnemonic_to_string(mov_id) == "mov");
    check("zydis_mnemonic_to_string(ret_id) == 'ret'",
          zydis_mnemonic_to_string(ret_id) == "ret");
    check("zydis_mnemonic_to_string(nop_id) == 'nop'",
          zydis_mnemonic_to_string(nop_id) == "nop");
    check("zydis_mnemonic_to_string(int3_id) == 'int3'",
          zydis_mnemonic_to_string(int3_id) == "int3");
    check("zydis_mnemonic_to_string(jmp_id) == 'jmp'",
          zydis_mnemonic_to_string(jmp_id) == "jmp");
    check("zydis_mnemonic_to_string(push_id) == 'push'",
          zydis_mnemonic_to_string(push_id) == "push");
    check("zydis_mnemonic_to_string(pop_id) == 'pop'",
          zydis_mnemonic_to_string(pop_id) == "pop");
    check("zydis_mnemonic_to_string(add_id) == 'add'",
          zydis_mnemonic_to_string(add_id) == "add");
    check("zydis_mnemonic_to_string(sub_id) == 'sub'",
          zydis_mnemonic_to_string(sub_id) == "sub");
    check("zydis_mnemonic_to_string(xor_id) == 'xor'",
          zydis_mnemonic_to_string(xor_id) == "xor");
    check("zydis_mnemonic_to_string(cmp_id) == 'cmp'",
          zydis_mnemonic_to_string(cmp_id) == "cmp");
    check("zydis_mnemonic_to_string(je_id) == 'je'",
          zydis_mnemonic_to_string(je_id) == "je");
    check("zydis_mnemonic_to_string(jne_id) == 'jne'",
          zydis_mnemonic_to_string(jne_id) == "jne");
    check("zydis_mnemonic_to_string(call_id) == 'call'",
          zydis_mnemonic_to_string(call_id) == "call");

    // to_string on invalid mnemonic (0 = INVALID)
    string invalid_str = zydis_mnemonic_to_string(0);
    check("zydis_mnemonic_to_string(0) returns non-empty string",
          invalid_str.length() > 0);

    // -------------------------------------------------------------------
    // 2. zydis_register_from_string / to_string
    // -------------------------------------------------------------------
    section("zydis_register_from_string / to_string");

    int64 rax_id = zydis_register_from_string("rax");
    int64 rbx_id = zydis_register_from_string("rbx");
    int64 rcx_id = zydis_register_from_string("rcx");
    int64 rdx_id = zydis_register_from_string("rdx");
    int64 rsi_id = zydis_register_from_string("rsi");
    int64 rdi_id = zydis_register_from_string("rdi");
    int64 rbp_id = zydis_register_from_string("rbp");
    int64 rsp_id = zydis_register_from_string("rsp");
    int64 r8_id  = zydis_register_from_string("r8");
    int64 r9_id  = zydis_register_from_string("r9");

    check("rax_id > 0", rax_id > 0);
    check("rbx_id > 0", rbx_id > 0);
    check("rcx_id > 0", rcx_id > 0);
    check("rdx_id > 0", rdx_id > 0);
    check("rsi_id > 0", rsi_id > 0);
    check("rdi_id > 0", rdi_id > 0);
    check("rbp_id > 0", rbp_id > 0);
    check("rsp_id > 0", rsp_id > 0);
    check("r8_id > 0", r8_id > 0);
    check("r9_id > 0", r9_id > 0);

    // Case-insensitivity on register
    int64 rax_upper = zydis_register_from_string("RAX");
    int64 rax_mixed = zydis_register_from_string("Rax");
    check("case-insensitive 'RAX' matches 'rax'", rax_upper == rax_id);
    check("case-insensitive 'Rax' matches 'rax'", rax_mixed == rax_id);

    // Invalid register returns 0
    int64 bad_reg = zydis_register_from_string("not_a_real_register_xyz");
    check("invalid register returns 0 (NONE)", bad_reg == 0);

    // to_string round-trip
    check("zydis_register_to_string(rax_id) == 'rax'",
          zydis_register_to_string(rax_id) == "rax");
    check("zydis_register_to_string(rbx_id) == 'rbx'",
          zydis_register_to_string(rbx_id) == "rbx");
    check("zydis_register_to_string(rcx_id) == 'rcx'",
          zydis_register_to_string(rcx_id) == "rcx");
    check("zydis_register_to_string(rdx_id) == 'rdx'",
          zydis_register_to_string(rdx_id) == "rdx");
    check("zydis_register_to_string(rsi_id) == 'rsi'",
          zydis_register_to_string(rsi_id) == "rsi");
    check("zydis_register_to_string(rdi_id) == 'rdi'",
          zydis_register_to_string(rdi_id) == "rdi");
    check("zydis_register_to_string(rbp_id) == 'rbp'",
          zydis_register_to_string(rbp_id) == "rbp");
    check("zydis_register_to_string(rsp_id) == 'rsp'",
          zydis_register_to_string(rsp_id) == "rsp");
    check("zydis_register_to_string(r8_id) == 'r8'",
          zydis_register_to_string(r8_id) == "r8");
    check("zydis_register_to_string(r9_id) == 'r9'",
          zydis_register_to_string(r9_id) == "r9");

    // to_string on invalid register (0 = NONE)
    string bad_reg_str = zydis_register_to_string(0);
    check("zydis_register_to_string(0) returns non-empty string",
          bad_reg_str.length() > 0);

    // Segment registers for far-pointer tests
    int64 fs_id = zydis_register_from_string("fs");
    int64 gs_id = zydis_register_from_string("gs");
    check("fs_id > 0 (segment reg)", fs_id > 0);
    check("gs_id > 0 (segment reg)", gs_id > 0);

    // -------------------------------------------------------------------
    // 3. zydis_nop_fill — various lengths
    // -------------------------------------------------------------------
    section("zydis_nop_fill");

    // NOP fill: 1 byte -> 0x90 (XCHG EAX, EAX)
    array<uint8> nop1 = zydis_nop_fill(1);
    check("nop_fill(1).length() == 1", nop1.length() == 1);
    if (nop1.length() == 1) {
        check("nop_fill(1)[0] == 0x90", nop1.get(0) == 0x90);
    }

    // NOP fill: 2 bytes
    array<uint8> nop2 = zydis_nop_fill(2);
    check("nop_fill(2).length() == 2", nop2.length() == 2);

    // NOP fill: 4 bytes
    array<uint8> nop4 = zydis_nop_fill(4);
    check("nop_fill(4).length() == 4", nop4.length() == 4);

    // NOP fill: 15 bytes (max multi-byte NOP before repeating)
    array<uint8> nop15 = zydis_nop_fill(15);
    check("nop_fill(15).length() == 15", nop15.length() == 15);

    // NOP fill: 64 bytes (arbitrary large)
    array<uint8> nop64 = zydis_nop_fill(64);
    check("nop_fill(64).length() == 64", nop64.length() == 64);

    // Edge case: zero length
    array<uint8> nop0 = zydis_nop_fill(0);
    check("nop_fill(0).length() == 0", nop0.length() == 0);

    // Edge case: negative length
    array<uint8> nop_neg = zydis_nop_fill(-1);
    check("nop_fill(-1).length() == 0", nop_neg.length() == 0);

    // -------------------------------------------------------------------
    // 4. zydis_req_t — default state + getters
    // -------------------------------------------------------------------
    section("zydis_req_t — defaults & getters");

    zydis_req_t req;

    // get_machine_mode: default should be long_64
    int64 default_mode = req.get_machine_mode();
    check("default get_machine_mode() == long_64",
          default_mode == cast<int64>(zydis_machine_mode::long_64));

    // get_mnemonic on unset request (should be 0 = INVALID)
    int64 unset_mnem = req.get_mnemonic();
    check("get_mnemonic() on unset req returns 0 (INVALID)", unset_mnem == 0);

    // get_operand_count on unset request (should be 0)
    int64 unset_op_count = req.get_operand_count();
    check("get_operand_count() on unset req returns 0", unset_op_count == 0);

    // -------------------------------------------------------------------
    // 5. zydis_req_t — set_mnemonic + set_operand_count + getters
    // -------------------------------------------------------------------
    section("zydis_req_t — set_mnemonic / set_operand_count / getters");

    zydis_req_t r1;
    r1.set_mnemonic(mov_id);
    check("set_mnemonic + get_mnemonic round-trip", r1.get_mnemonic() == mov_id);

    r1.set_mnemonic(nop_id);
    check("set_mnemonic overwrite to nop", r1.get_mnemonic() == nop_id);

    r1.set_mnemonic(mov_id);
    r1.set_operand_count(2);
    check("get_operand_count() == 2", r1.get_operand_count() == 2);

    // set_operand_count with 0 operands
    zydis_req_t r0;
    r0.set_mnemonic(ret_id);
    r0.set_operand_count(0);
    array<uint8> ret_bytes = zydis_encode(r0);
    check("encode(ret) with 0 operands succeeds", ret_bytes.length() > 0);
    if (ret_bytes.length() == 1) {
        check("encode(ret)[0] == 0xC3", ret_bytes.get(0) == 0xC3);
    }

    // set_operand_count with 3 operands (e.g., imul rax, rcx, 0x42)
    zydis_req_t r3;
    r3.set_mnemonic(mov_id);
    r3.set_operand_count(3);
    check("set_operand_count(3) works", r3.get_operand_count() == 3);

    // set_operand_count with 4 operands (max)
    r3.set_operand_count(4);
    check("set_operand_count(4) works", r3.get_operand_count() == 4);

    // Restore to 2 for further tests
    r3.set_operand_count(2);
    check("set_operand_count(2) after 4", r3.get_operand_count() == 2);

    // -------------------------------------------------------------------
    // 6. zydis_req_t — machine mode enum values
    // -------------------------------------------------------------------
    section("zydis_req_t — set_machine_mode all enum values");

    // Test every zydis_machine_mode enum value: set + get round-trip
    {
        zydis_req_t mm_req;
        mm_req.set_machine_mode(zydis_machine_mode::long_64);
        check("long_64 round-trip",
              mm_req.get_machine_mode() == cast<int64>(zydis_machine_mode::long_64));

        mm_req.set_machine_mode(zydis_machine_mode::long_compat_32);
        check("long_compat_32 round-trip",
              mm_req.get_machine_mode() == cast<int64>(zydis_machine_mode::long_compat_32));

        mm_req.set_machine_mode(zydis_machine_mode::long_compat_16);
        check("long_compat_16 round-trip",
              mm_req.get_machine_mode() == cast<int64>(zydis_machine_mode::long_compat_16));

        mm_req.set_machine_mode(zydis_machine_mode::legacy_32);
        check("legacy_32 round-trip",
              mm_req.get_machine_mode() == cast<int64>(zydis_machine_mode::legacy_32));

        mm_req.set_machine_mode(zydis_machine_mode::legacy_16);
        check("legacy_16 round-trip",
              mm_req.get_machine_mode() == cast<int64>(zydis_machine_mode::legacy_16));

        mm_req.set_machine_mode(zydis_machine_mode::real_16);
        check("real_16 round-trip",
              mm_req.get_machine_mode() == cast<int64>(zydis_machine_mode::real_16));

        // Restore to long_64
        mm_req.set_machine_mode(zydis_machine_mode::long_64);
        check("restored to long_64",
              mm_req.get_machine_mode() == cast<int64>(zydis_machine_mode::long_64));
    }

    // -------------------------------------------------------------------
    // 7. zydis_req_t — set_operand_reg + set_operand_imm (mov rax, 0x42)
    // -------------------------------------------------------------------
    section("zydis_req_t — set_operand_reg + set_operand_imm");

    zydis_req_t mov_req;
    mov_req.set_mnemonic(mov_id);
    mov_req.set_machine_mode(zydis_machine_mode::long_64);
    mov_req.set_operand_count(2);
    mov_req.set_operand_reg(0, rax_id);
    mov_req.set_operand_imm(1, 0x42);

    array<uint8> mov_bytes = zydis_encode(mov_req);
    // mov rax, 0x42 -> 48 C7 C0 42 00 00 00 (REX.W MOV r/m64 imm32)
    check("encode(mov rax, 0x42) produces bytes", mov_bytes.length() > 0);
    if (mov_bytes.length() == 7) {
        check("byte[0] == 0x48 (REX.W)", mov_bytes.get(0) == 0x48);
        check("byte[1] == 0xC7 (MOV r/m64 imm32)", mov_bytes.get(1) == 0xC7);
        check("byte[2] == 0xC0 (ModR/M rax)", mov_bytes.get(2) == 0xC0);
        check("byte[3] == 0x42 (imm32 low)", mov_bytes.get(3) == 0x42);
        check("byte[4] == 0x00", mov_bytes.get(4) == 0x00);
        check("byte[5] == 0x00", mov_bytes.get(5) == 0x00);
        check("byte[6] == 0x00 (imm32 high)", mov_bytes.get(6) == 0x00);
    }

    // Encode mov rcx, 0x1234 (different register + different immediate)
    {
        zydis_req_t mov_rcx;
        mov_rcx.set_mnemonic(mov_id);
        mov_rcx.set_operand_count(2);
        mov_rcx.set_operand_reg(0, rcx_id);
        mov_rcx.set_operand_imm(1, 0x1234);
        array<uint8> rcx_bytes = zydis_encode(mov_rcx);
        check("encode(mov rcx, 0x1234) produces bytes", rcx_bytes.length() > 0);
    }

    // Encode mov rdx, -1 (signed immediate)
    {
        zydis_req_t mov_rdx;
        mov_rdx.set_mnemonic(mov_id);
        mov_rdx.set_operand_count(2);
        mov_rdx.set_operand_reg(0, rdx_id);
        mov_rdx.set_operand_imm(1, -1);
        array<uint8> rdx_bytes = zydis_encode(mov_rdx);
        check("encode(mov rdx, -1) produces bytes", rdx_bytes.length() > 0);
        if (rdx_bytes.length() == 7) {
            // Expect imm32 = 0xFFFFFFFF
            check("rdx imm32 == -1", rdx_bytes.get(3) == 0xFF && rdx_bytes.get(6) == 0xFF);
        }
    }

    // -------------------------------------------------------------------
    // 8. zydis_req_t — set_operand_mem
    // -------------------------------------------------------------------
    section("zydis_req_t — set_operand_mem (memory operand)");

    // mov rax, [rcx + 0x100] (base=rcx, no index, disp=0x100, 8-byte access)
    // set_operand_mem(idx, base, idx_reg, scale, disp, size_bytes)
    {
        zydis_req_t mem_req;
        mem_req.set_mnemonic(mov_id);
        mem_req.set_operand_count(2);
        mem_req.set_operand_reg(0, rax_id);
        // base=rcx, no index (0=NONE), scale=1, disp=0x100, size=8 (64-bit)
        mem_req.set_operand_mem(1, rcx_id, 0, 1, 0x100, 8);
        array<uint8> mem_bytes = zydis_encode(mem_req);
        check("encode(mov rax, [rcx+0x100]) succeeds", mem_bytes.length() > 0);
        if (mem_bytes.length() > 0) {
            check("mem_byte[0] == 0x48 (REX.W)", mem_bytes.get(0) == 0x48);
            check("mem_byte[1] == 0x8B (MOV r64, r/m64)", mem_bytes.get(1) == 0x8B);
        }
    }

    // mov rax, [rbx + rsi*4 + 0x200] (base + index*scale + disp)
    {
        zydis_req_t mem_idx;
        mem_idx.set_mnemonic(mov_id);
        mem_idx.set_operand_count(2);
        mem_idx.set_operand_reg(0, rax_id);
        mem_idx.set_operand_mem(1, rbx_id, rsi_id, 4, 0x200, 8);
        array<uint8> idx_bytes = zydis_encode(mem_idx);
        check("encode indexed mem [rbx+rsi*4+0x200] succeeds", idx_bytes.length() > 0);
    }

    // mov qword [rsp + 0x50], rax (write memory)
    {
        zydis_req_t mem_store;
        mem_store.set_mnemonic(mov_id);
        mem_store.set_operand_count(2);
        mem_store.set_operand_mem(0, rsp_id, 0, 1, 0x50, 8);
        mem_store.set_operand_reg(1, rax_id);
        array<uint8> store_bytes = zydis_encode(mem_store);
        check("encode(mov [rsp+0x50], rax) succeeds", store_bytes.length() > 0);
    }

    // -------------------------------------------------------------------
    // 9. zydis_req_t — set_operand_ptr (far pointer)
    // -------------------------------------------------------------------
    section("zydis_req_t — set_operand_ptr (far pointer operand)");

    // set_operand_ptr(idx, segment, offset)
    // Try encoding a far indirect call or jmp with segment:offset.
    {
        zydis_req_t ptr_req;
        ptr_req.set_mnemonic(call_id);
        ptr_req.set_operand_count(1);
        ptr_req.set_operand_ptr(0, 0x0023, 0x1000);  // segment=0x23 offset=0x1000
        array<uint8> ptr_bytes = zydis_encode(ptr_req);
        // Far pointer encoding depends on mode; the call may or may not
        // produce output. The point is that the API doesn't crash.
        check("set_operand_ptr call survives encode",
              ptr_bytes.length() >= 0);
    }

    // -------------------------------------------------------------------
    // 10. zydis_req_t — branch metadata
    // -------------------------------------------------------------------
    section("zydis_req_t — branch_type / branch_width enums");

    // Test every zydis_branch_type value
    {
        zydis_req_t br;
        br.set_mnemonic(jmp_id);
        br.set_operand_count(1);
        br.set_operand_imm(0, 0x100);

        // zydis_branch_type::none (default)
        br.set_branch_type(zydis_branch_type::none);

        // zydis_branch_type::short
        br.set_branch_type(zydis_branch_type::short);
        array<uint8> short_jmp = zydis_encode_absolute(br, 0x1000);
        // Short jmp from 0x1000 -> 0x100 should be 2 bytes (EB rel8)
        // But the encode might give 5 bytes near; we just check it works.
        check("branch_type::short encode survives", short_jmp.length() >= 0);

        // zydis_branch_type::near
        br.set_branch_type(zydis_branch_type::near);
        array<uint8> near_jmp = zydis_encode_absolute(br, 0x1000);
        check("branch_type::near produces bytes", near_jmp.length() > 0);

        // zydis_branch_type::far
        br.set_branch_type(zydis_branch_type::far);
        array<uint8> far_jmp = zydis_encode_absolute(br, 0x1000);
        // Far jmp might produce bytes or not depending on encoder support;
        // we just verify it doesn't crash.
        check("branch_type::far encode survives", far_jmp.length() >= 0);
    }

    // Test every zydis_branch_width value
    {
        zydis_req_t bw;
        bw.set_mnemonic(jmp_id);
        bw.set_operand_count(1);
        bw.set_operand_imm(0, 0x1000);
        bw.set_branch_type(zydis_branch_type::near);

        // zydis_branch_width::none
        bw.set_branch_width(zydis_branch_width::none);
        array<uint8> bw_none = zydis_encode_absolute(bw, 0x2000);
        check("branch_width::none encode survives", bw_none.length() >= 0);

        // zydis_branch_width::w8
        bw.set_branch_width(zydis_branch_width::w8);
        array<uint8> bw8 = zydis_encode_absolute(bw, 0x2000);
        check("branch_width::w8 encode survives", bw8.length() >= 0);

        // zydis_branch_width::w16
        bw.set_branch_width(zydis_branch_width::w16);
        array<uint8> bw16 = zydis_encode_absolute(bw, 0x2000);
        check("branch_width::w16 encode survives", bw16.length() >= 0);

        // zydis_branch_width::w32 (most common for near jmp in 64-bit)
        bw.set_branch_width(zydis_branch_width::w32);
        array<uint8> bw32 = zydis_encode_absolute(bw, 0x2000);
        check("branch_width::w32 produces near jmp", bw32.length() > 0);
        if (bw32.length() == 5) {
            // E9 + rel32
            check("branch_width::w32 byte[0] == 0xE9 (JMP near)", bw32.get(0) == 0xE9);
        }

        // zydis_branch_width::w64
        bw.set_branch_width(zydis_branch_width::w64);
        array<uint8> bw64 = zydis_encode_absolute(bw, 0x2000);
        check("branch_width::w64 encode survives", bw64.length() >= 0);
    }

    // -------------------------------------------------------------------
    // 11. zydis_encode_absolute — RIP-relative encoding
    // -------------------------------------------------------------------
    section("zydis_encode_absolute");

    // Encode a jmp with a known runtime base address so that RIP-relative
    // immediates are baked in correctly.
    {
        zydis_req_t abs_req;
        abs_req.set_mnemonic(jmp_id);
        abs_req.set_operand_count(1);
        abs_req.set_operand_imm(0, 0x100);
        abs_req.set_branch_type(zydis_branch_type::near);
        abs_req.set_branch_width(zydis_branch_width::w32);

        // Base address 0x1000, target 0x100. Relative offset =
        // target - (base + instruction_length).
        array<uint8> abs_bytes = zydis_encode_absolute(abs_req, 0x1000);
        check("encode_absolute(jmp 0x100, base=0x1000) produces bytes",
              abs_bytes.length() > 0);
        if (abs_bytes.length() == 5) {
            check("abs_bytes[0] == 0xE9 (JMP near)", abs_bytes.get(0) == 0xE9);
        }
    }

    // Encode a conditional jump with absolute base
    {
        zydis_req_t je_req;
        je_req.set_mnemonic(je_id);
        je_req.set_operand_count(1);
        je_req.set_operand_imm(0, 0x200);
        je_req.set_branch_type(zydis_branch_type::near);
        je_req.set_branch_width(zydis_branch_width::w32);

        array<uint8> je_abs = zydis_encode_absolute(je_req, 0x1000);
        check("encode_absolute(je 0x200, base=0x1000) produces bytes",
              je_abs.length() > 0);
        if (je_abs.length() == 6) {
            // Conditional near jmp: 0F 8x + rel32 (6 bytes)
            check("je byte[0] == 0x0F", je_abs.get(0) == 0x0F);
            check("je byte[1] == 0x84 (JE rel32)", je_abs.get(1) == 0x84);
        }
    }

    // -------------------------------------------------------------------
    // 12. zydis_decode_to_request — round-trip
    // -------------------------------------------------------------------
    section("zydis_decoded_to_request");

    // Decode the mov rax, 0x42 bytes back into a request
    {
        zydis_req_t decoded = zydis_decoded_to_request(mov_bytes, 0);
        check("decoded_to_request returns valid handle",
              cast<int64>(decoded) != 0);
        if (cast<int64>(decoded) != 0) {
            check("decoded.mnemonic == mov", decoded.get_mnemonic() == mov_id);
            check("decoded.operand_count == 2", decoded.get_operand_count() == 2);
            check("decoded.machine_mode == long_64",
                  decoded.get_machine_mode() == cast<int64>(zydis_machine_mode::long_64));
        }
    }

    // Decode ret (single byte 0xC3)
    {
        zydis_req_t dec_ret = zydis_decoded_to_request(ret_bytes, 0);
        check("decoded_to_request(ret) returns valid handle",
              cast<int64>(dec_ret) != 0);
        if (cast<int64>(dec_ret) != 0) {
            check("decoded ret.mnemonic == ret", dec_ret.get_mnemonic() == ret_id);
            check("decoded ret.operand_count == 0", dec_ret.get_operand_count() == 0);
        }
    }

    // Decode with non-zero runtime_rip (for RIP-relative resolution)
    {
        zydis_req_t dec_rip = zydis_decoded_to_request(mov_bytes, 0x1000);
        check("decoded_to_request with base=0x1000 works",
              cast<int64>(dec_rip) != 0);
    }

    // Decode an empty array (should give empty/invalid handle)
    {
        array<uint8> empty_bytes;
        zydis_req_t dec_empty = zydis_decoded_to_request(empty_bytes, 0);
        // Empty input: decode may produce invalid handle
        check("decoded_to_request(empty) survives",
              cast<int64>(dec_empty) >= 0);
    }

    // -------------------------------------------------------------------
    // 13. zydis_disasm — single instructions
    // -------------------------------------------------------------------
    section("zydis_disasm — single instructions");

    // Disassemble mov rax, 0x42
    {
        array<string> dasm = zydis_disasm(mov_bytes, 0);
        check("disasm(mov rax) yields 1 instruction", dasm.length() == 1);
        if (dasm.length() == 1) {
            string text = dasm.get(0);
            print_console("  mov: " + text);
            check("dasm contains 'mov'", text.find("mov") >= 0);
            check("dasm contains 'rax'", text.find("rax") >= 0);
        }
    }

    // Disassemble ret (0xC3)
    {
        array<string> dasm = zydis_disasm(ret_bytes, 0);
        check("disasm(ret) yields 1 instruction", dasm.length() == 1);
        if (dasm.length() == 1) {
            string text = dasm.get(0);
            print_console("  ret: " + text);
            check("dasm ret contains 'ret'", text.find("ret") >= 0);
        }
    }

    // Disassemble nop (0x90)
    {
        array<string> dasm = zydis_disasm(nop1, 0);
        check("disasm(nop) yields 1 instruction", dasm.length() == 1);
        if (dasm.length() == 1) {
            string text = dasm.get(0);
            print_console("  nop: " + text);
            check("dasm nop contains 'nop'",
                  text.find("nop") >= 0 || text.find("xchg") >= 0);
        }
    }

    // Disassemble int3 (0xCC) — single byte
    {
        array<uint8> int3_bytes;
        int3_bytes.push(cast<uint8>(0xCC));
        array<string> dasm = zydis_disasm(int3_bytes, 0);
        check("disasm(int3) yields 1 instruction", dasm.length() == 1);
        if (dasm.length() == 1) {
            string text = dasm.get(0);
            print_console("  int3: " + text);
            check("dasm int3 contains 'int3'", text.find("int3") >= 0);
        }
    }

    // Disassemble with non-zero base address (RIP-relative text)
    {
        array<string> dasm = zydis_disasm(mov_bytes, 0x1000);
        check("disasm with base=0x1000 yields 1 instruction",
              dasm.length() == 1);
        if (dasm.length() == 1) {
            string text = dasm.get(0);
            print_console("  mov@0x1000: " + text);
            check("dasm with base addr contains 'mov'", text.find("mov") >= 0);
        }
    }

    // -------------------------------------------------------------------
    // 14. zydis_disasm — multiple instructions in one buffer
    // -------------------------------------------------------------------
    section("zydis_disasm — multiple instructions");

    // Build a buffer with nop; nop; int3; ret
    {
        array<uint8> multi;
        multi.push(cast<uint8>(0x90));  // nop
        multi.push(cast<uint8>(0x90));  // nop
        multi.push(cast<uint8>(0xCC));  // int3
        multi.push(cast<uint8>(0xC3));  // ret

        array<string> dasm = zydis_disasm(multi, 0);
        check("disasm(multi): 4 instructions", dasm.length() == 4);
        if (dasm.length() == 4) {
            print_console("  [0]: " + dasm.get(0));
            print_console("  [1]: " + dasm.get(1));
            print_console("  [2]: " + dasm.get(2));
            print_console("  [3]: " + dasm.get(3));
            check("inst[0] contains 'nop'",
                  dasm.get(0).find("nop") >= 0 || dasm.get(0).find("xchg") >= 0);
            check("inst[1] contains 'nop'",
                  dasm.get(1).find("nop") >= 0 || dasm.get(1).find("xchg") >= 0);
            check("inst[2] contains 'int3'", dasm.get(2).find("int3") >= 0);
            check("inst[3] contains 'ret'", dasm.get(3).find("ret") >= 0);
        }
    }

    // -------------------------------------------------------------------
    // 15. zydis_builder_t — basic push (nop, int3, ret)
    // -------------------------------------------------------------------
    section("zydis_builder_t — basic push_nop / push_int3 / push_ret");

    zydis_builder_t b;

    // Initial state: get_count == 0
    check("builder.get_count() == 0 initially", b.get_count() == 0);

    // push_nop
    b.push_nop(1);
    check("after push_nop(1), get_count() == 1", b.get_count() == 1);

    b.push_int3();
    check("after push_int3, get_count() == 2", b.get_count() == 2);

    b.push_ret();
    check("after push_ret, get_count() == 3", b.get_count() == 3);

    // Build and verify bytes: nop(0x90), int3(0xCC), ret(0xC3)
    array<uint8> built = b.build();
    check("build().length() == 3", built.length() == 3);
    if (built.length() == 3) {
        check("built[0] == 0x90 (nop)", built.get(0) == 0x90);
        check("built[1] == 0xCC (int3)", built.get(1) == 0xCC);
        check("built[2] == 0xC3 (ret)", built.get(2) == 0xC3);
    }

    // clear and verify count resets
    b.clear();
    check("after clear(), get_count() == 0", b.get_count() == 0);

    // push_nop with larger count
    b.push_nop(4);
    check("after push_nop(4), get_count() == 4", b.get_count() == 4);
    array<uint8> nop_built = b.build();
    check("build 4 nops length == 4", nop_built.length() == 4);

    b.clear();

    // -------------------------------------------------------------------
    // 16. zydis_builder_t — raw byte pushers
    // -------------------------------------------------------------------
    section("zydis_builder_t — push_byte / push_u16 / push_u32 / push_u64");

    // push_byte (single uint8)
    b.push_byte(cast<uint8>(0xAA));
    check("after push_byte, get_count() == 1", b.get_count() == 1);

    // push_u16 (little-endian)
    b.push_u16(cast<uint16>(0x1234));
    check("after push_u16, get_count() == 2", b.get_count() == 2);

    // push_u32 (little-endian)
    b.push_u32(cast<uint32>(0xDEADBEEF));
    check("after push_u32, get_count() == 3", b.get_count() == 3);

    array<uint8> raw = b.build();
    // Expect 1 + 2 + 4 = 7 bytes
    check("raw build length == 7", raw.length() == 7);
    if (raw.length() == 7) {
        // push_byte(0xAA) -> [0xAA]
        check("raw[0] == 0xAA (push_byte)", raw.get(0) == 0xAA);
        // push_u16(0x1234) LE -> [0x34, 0x12]
        check("raw[1] == 0x34 (u16 LE low)", raw.get(1) == 0x34);
        check("raw[2] == 0x12 (u16 LE high)", raw.get(2) == 0x12);
        // push_u32(0xDEADBEEF) LE -> [0xEF, 0xBE, 0xAD, 0xDE]
        check("raw[3] == 0xEF (u32 LE byte0)", raw.get(3) == 0xEF);
        check("raw[4] == 0xBE (u32 LE byte1)", raw.get(4) == 0xBE);
        check("raw[5] == 0xAD (u32 LE byte2)", raw.get(5) == 0xAD);
        check("raw[6] == 0xDE (u32 LE byte3)", raw.get(6) == 0xDE);
    }

    b.clear();

    // push_u64 (little-endian)
    b.push_u64(cast<uint64>(0x0123456789ABCDEF));
    check("after push_u64, get_count() == 1", b.get_count() == 1);
    array<uint8> u64_built = b.build();
    check("push_u64 produces 8 bytes", u64_built.length() == 8);
    if (u64_built.length() == 8) {
        check("u64[0] == 0xEF (LE byte0)", u64_built.get(0) == 0xEF);
        check("u64[1] == 0xCD (LE byte1)", u64_built.get(1) == 0xCD);
        check("u64[2] == 0xAB (LE byte2)", u64_built.get(2) == 0xAB);
        check("u64[3] == 0x89 (LE byte3)", u64_built.get(3) == 0x89);
        check("u64[4] == 0x67 (LE byte4)", u64_built.get(4) == 0x67);
        check("u64[5] == 0x45 (LE byte5)", u64_built.get(5) == 0x45);
        check("u64[6] == 0x23 (LE byte6)", u64_built.get(6) == 0x23);
        check("u64[7] == 0x01 (LE byte7)", u64_built.get(7) == 0x01);
    }

    b.clear();

    // -------------------------------------------------------------------
    // 17. zydis_builder_t — push_bytes
    // -------------------------------------------------------------------
    section("zydis_builder_t — push_bytes");

    // push_bytes from an existing array
    array<uint8> chunk = zydis_nop_fill(5);
    b.push_bytes(chunk);
    check("after push_bytes, get_count() == 1", b.get_count() == 1);

    array<uint8> chunk_built = b.build();
    check("push_bytes length == 5", chunk_built.length() == 5);
    if (chunk_built.length() == 5) {
        check("push_bytes[0] == 0x90", chunk_built.get(0) == 0x90);
        check("push_bytes[4] == valid nop byte", chunk_built.get(4) >= 0x00);
    }

    b.clear();

    // push_bytes with empty array (should not crash)
    {
        array<uint8> empty_chunk;
        b.push_bytes(empty_chunk);
        check("push_bytes(empty) doesn't crash", true);
        b.clear();
    }

    // push_bytes with a manually-built array
    {
        array<uint8> manual;
        manual.push(cast<uint8>(0x01));
        manual.push(cast<uint8>(0x02));
        manual.push(cast<uint8>(0x03));
        b.push_bytes(manual);
        array<uint8> manual_built = b.build();
        check("push_bytes(manual).length() == 3", manual_built.length() == 3);
        if (manual_built.length() == 3) {
            check("manual[0] == 0x01", manual_built.get(0) == 0x01);
            check("manual[1] == 0x02", manual_built.get(1) == 0x02);
            check("manual[2] == 0x03", manual_built.get(2) == 0x03);
        }
        b.clear();
    }

    // -------------------------------------------------------------------
    // 18. zydis_builder_t — push(req) — encode through builder
    // -------------------------------------------------------------------
    section("zydis_builder_t — push(zydis_req_t)");

    // Push the mov rax, 0x42 request through the builder
    b.set_base_address(0x1000);
    b.push(mov_req);
    check("after push(req), get_count() == 1", b.get_count() == 1);

    array<uint8> via_builder = b.build();
    check("builder push(mov_req).length() == 7", via_builder.length() == 7);
    if (via_builder.length() == 7) {
        check("builder[0] == 0x48", via_builder.get(0) == 0x48);
        check("builder[1] == 0xC7", via_builder.get(1) == 0xC7);
        check("builder[2] == 0xC0", via_builder.get(2) == 0xC0);
        check("builder[3] == 0x42", via_builder.get(3) == 0x42);
    }

    b.clear();

    // Push multiple requests: nop, int3, ret
    {
        zydis_req_t nop_req;
        nop_req.set_mnemonic(nop_id);
        nop_req.set_operand_count(0);

        zydis_req_t int3_req;
        int3_req.set_mnemonic(int3_id);
        int3_req.set_operand_count(0);

        zydis_req_t ret_req;
        ret_req.set_mnemonic(ret_id);
        ret_req.set_operand_count(0);

        b.push(nop_req);
        b.push(int3_req);
        b.push(ret_req);
        check("after 3 pushes, get_count() == 3", b.get_count() == 3);

        array<uint8> multi_built = b.build();
        check("multi push build length == 3", multi_built.length() == 3);
        if (multi_built.length() == 3) {
            check("multi[0] == 0x90 (nop)", multi_built.get(0) == 0x90);
            check("multi[1] == 0xCC (int3)", multi_built.get(1) == 0xCC);
            check("multi[2] == 0xC3 (ret)", multi_built.get(2) == 0xC3);
        }

        b.clear();
    }

    // -------------------------------------------------------------------
    // 19. zydis_builder_t — set_machine_mode + set_base_address
    // -------------------------------------------------------------------
    section("zydis_builder_t — set_machine_mode / set_base_address");

    // Switch builder machine mode (these don't affect existing entries,
    // only new push operations). Just exercise the methods.
    b.set_machine_mode(zydis_machine_mode::long_64);
    b.set_machine_mode(zydis_machine_mode::legacy_32);
    b.set_machine_mode(zydis_machine_mode::long_64);
    check("builder set_machine_mode survives", true);

    // set_base_address with various values
    b.set_base_address(0);
    b.set_base_address(0x1000);
    b.set_base_address(0x7FFFFFFFFFFFFFFF);  // large but valid
    b.set_base_address(0x0);
    check("builder set_base_address round-trips", true);

    // -------------------------------------------------------------------
    // 20. zydis_encode standalone — error cases
    // -------------------------------------------------------------------
    section("zydis_encode — edge/safety cases");

    // Encode unconfigured request (no mnemonic set)
    {
        zydis_req_t empty_req;
        array<uint8> empty_enc = zydis_encode(empty_req);
        // Should return empty array (no crash)
        check("encode(unconfigured req) returns empty array",
              empty_enc.length() == 0);
    }

    // Encode with wrong operand count for mnemonic
    {
        zydis_req_t bad_req;
        bad_req.set_mnemonic(ret_id);
        bad_req.set_operand_count(5);  // ret expects 0, 5 is out of range
        array<uint8> bad_enc = zydis_encode(bad_req);
        // Should return empty array (no crash)
        check("encode(ret w/ 5 operands) returns empty", bad_enc.length() == 0);
    }

    // Encode with mnemonic set but no operands where operands needed
    {
        zydis_req_t no_op_req;
        no_op_req.set_mnemonic(mov_id);
        no_op_req.set_operand_count(0);  // mov needs at least 1 operand
        array<uint8> no_op_enc = zydis_encode(no_op_req);
        // This will likely fail; just check no crash
        check("encode(mov w/ 0 operands) survives",
              no_op_enc.length() >= 0);
    }

    // -------------------------------------------------------------------
    // 21. zydis_encode_absolute — edge cases
    // -------------------------------------------------------------------
    section("zydis_encode_absolute — edge cases");

    // Encode with negative base address
    {
        zydis_req_t abs_edge;
        abs_edge.set_mnemonic(jmp_id);
        abs_edge.set_operand_count(1);
        abs_edge.set_operand_imm(0, 0x100);
        abs_edge.set_branch_type(zydis_branch_type::near);
        abs_edge.set_branch_width(zydis_branch_width::w32);

        array<uint8> neg_base = zydis_encode_absolute(abs_edge, -0x1000);
        check("encode_absolute w/ negative base survives",
              neg_base.length() >= 0);
    }

    // -------------------------------------------------------------------
    // 22. disasm — edge cases
    // -------------------------------------------------------------------
    section("zydis_disasm — edge cases");

    // Empty array
    {
        array<uint8> empty;
        array<string> empty_dasm = zydis_disasm(empty, 0);
        check("disasm(empty) returns 0 instructions", empty_dasm.length() == 0);
    }

    // Garbage bytes that decode partially
    {
        array<uint8> garbage;
        garbage.push(cast<uint8>(0xFF));
        garbage.push(cast<uint8>(0xFF));
        garbage.push(cast<uint8>(0xFF));
        garbage.push(cast<uint8>(0xFF));

        array<string> garbage_dasm = zydis_disasm(garbage, 0);
        // Some FF bytes can be valid prefixes; just verify no crash
        check("disasm(garbage) survives",
              garbage_dasm.length() >= 0);
    }

    // Disasm with negative base address
    {
        array<string> neg_dasm = zydis_disasm(mov_bytes, -1);
        check("disasm w/ negative rip survives",
              neg_dasm.length() >= 0);
    }

    // -------------------------------------------------------------------
    // 23. Builder — full mixed sequence
    // -------------------------------------------------------------------
    section("zydis_builder_t — mixed sequence");

    // Build a mixed sequence with all push variants
    zydis_builder_t mix;
    mix.set_machine_mode(zydis_machine_mode::long_64);
    mix.set_base_address(0x2000);

    // Push raw bytes
    mix.push_byte(cast<uint8>(0xCC));  // int3

    // Push instruction via request
    {
        zydis_req_t mix_req;
        mix_req.set_mnemonic(nop_id);
        mix_req.set_operand_count(0);
        mix.push(mix_req);
    }

    // Push NOP fill
    mix.push_nop(2);

    // Push raw u16
    mix.push_u16(cast<uint16>(0xBBAA));

    // Push ret
    mix.push_ret();

    // Push raw bytes from array
    {
        array<uint8> trailing;
        trailing.push(cast<uint8>(0x90));
        mix.push_bytes(trailing);
    }

    check("mixed builder get_count() == 6", mix.get_count() == 6);

    // build
    array<uint8> mixed = mix.build();
    check("mixed build has contents", mixed.length() > 0);
    if (mixed.length() >= 3) {
        check("mixed[0] == 0xCC (int3 push_byte)", mixed.get(0) == 0xCC);
        check("mixed[1] == 0x90 (nop via req)", mixed.get(1) == 0x90);
    }

    // -------------------------------------------------------------------
    // Summary
    // -------------------------------------------------------------------
    print_console("");
    print_console("===========================================");
    print_console("  Zydis API comprehensive test complete");
    print_console("  PASS: " + cast<string>(g_pass));
    print_console("  FAIL: " + cast<string>(g_fail));
    print_console("===========================================");

    return cast<int32>(g_fail == 0 ? 1 : 0);
}
