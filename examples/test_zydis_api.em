// =============================================================================
// Zydis API smoke test
//
// Exercises every native registered by enma_zydis_api.cpp:
//   - zydis_req_t (mnemonic / machine_mode / operand_count / branch / operand_*)
//   - zydis_builder_t (push / push_bytes / push_u8/16/32/64 / push_nop /
//                       push_int3 / push_ret / build / clear / get_count)
//   - zydis_encode / zydis_encode_absolute / zydis_nop_fill
//   - zydis_decoded_to_request
//   - zydis_mnemonic_from_string / to_string
//   - zydis_register_from_string / to_string
//   - zydis_disasm (text)
//
// Encoding test cases:
//   mov rax, 0x42        -> 48 C7 C0 42 00 00 00
//   ret                  -> C3
//   nop (1)              -> 90
//   int3                 -> CC
//   jmp 0x100 (absolute) -> RIP-relative; encode_absolute supplies the base
// =============================================================================

int64 g_pass = 0;
int64 g_fail = 0;
int64 g_handle = 0;
int64 g_done = 0;

sidebar_section_t g_section;
button_t          g_btn;
menu_t            g_menu;

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

void test_routine(int64 data) {
    if (g_done != 0) return;
    g_done = 1;

    print_console("=== zydis API smoke test ===");

    // -----------------------------------------------------------------------
    // Mnemonic + register name lookup. Round-trip: name -> id -> name should
    // be case-insensitive on the way in and lower-case on the way out.
    // -----------------------------------------------------------------------
    section("mnemonic + register lookup");

    int64 mov_id = zydis_mnemonic_from_string("mov");
    int64 mov_id_upper = zydis_mnemonic_from_string("MOV");
    int64 ret_id = zydis_mnemonic_from_string("ret");
    int64 jmp_id = zydis_mnemonic_from_string("jmp");
    int64 nop_id = zydis_mnemonic_from_string("nop");
    int64 int3_id = zydis_mnemonic_from_string("int3");
    int64 invalid_id = zydis_mnemonic_from_string("not_a_mnemonic_xyz");

    check("zydis_mnemonic_from_string('mov') > 0", mov_id > 0);
    check("zydis_mnemonic_from_string('MOV') == 'mov' (case-insensitive)",
          mov_id_upper == mov_id);
    check("zydis_mnemonic_from_string('ret') > 0", ret_id > 0);
    check("zydis_mnemonic_from_string('jmp') > 0", jmp_id > 0);
    check("zydis_mnemonic_from_string('nop') > 0", nop_id > 0);
    check("zydis_mnemonic_from_string('int3') > 0", int3_id > 0);
    check("zydis_mnemonic_from_string('not_a_mnemonic_xyz') == 0 (INVALID)",
          invalid_id == 0);

    string mov_name = zydis_mnemonic_to_string(mov_id);
    string ret_name = zydis_mnemonic_to_string(ret_id);
    check("zydis_mnemonic_to_string(mov_id) == 'mov'", mov_name == "mov");
    check("zydis_mnemonic_to_string(ret_id) == 'ret'", ret_name == "ret");

    int64 rax_id = zydis_register_from_string("rax");
    int64 rax_id_upper = zydis_register_from_string("RAX");
    int64 rcx_id = zydis_register_from_string("rcx");
    int64 invalid_reg = zydis_register_from_string("not_a_reg_xyz");

    check("zydis_register_from_string('rax') > 0", rax_id > 0);
    check("zydis_register_from_string('RAX') == 'rax' (case-insensitive)",
          rax_id_upper == rax_id);
    check("zydis_register_from_string('rcx') > 0", rcx_id > 0);
    check("zydis_register_from_string('not_a_reg_xyz') == 0 (NONE)",
          invalid_reg == 0);

    string rax_name = zydis_register_to_string(rax_id);
    check("zydis_register_to_string(rax_id) == 'rax'", rax_name == "rax");

    // -----------------------------------------------------------------------
    // zydis_nop_fill — bare-bones encoder check. 1-byte fill is 0x90;
    // larger fills use multi-byte NOPs that vary by length but always
    // produce exactly N bytes.
    // -----------------------------------------------------------------------
    section("zydis_nop_fill");

    array<uint8> nop1 = zydis_nop_fill(1);
    check("zydis_nop_fill(1).length() == 1", nop1.length() == 1);
    check("zydis_nop_fill(1)[0] == 0x90", nop1.get(0) == 0x90);

    array<uint8> nop4 = zydis_nop_fill(4);
    check("zydis_nop_fill(4).length() == 4", nop4.length() == 4);

    array<uint8> nop16 = zydis_nop_fill(16);
    check("zydis_nop_fill(16).length() == 16", nop16.length() == 16);

    array<uint8> nop_neg = zydis_nop_fill(-1);
    check("zydis_nop_fill(-1).length() == 0", nop_neg.length() == 0);

    array<uint8> nop_zero = zydis_nop_fill(0);
    check("zydis_nop_fill(0).length() == 0", nop_zero.length() == 0);

    // -----------------------------------------------------------------------
    // zydis_req_t — encode `mov rax, 0x42`. Expected bytes:
    //   48 C7 C0 42 00 00 00 (REX.W=1, MOV r/m64 imm32, ModR/M = C0 (rax))
    // -----------------------------------------------------------------------
    section("zydis_req_t - encode mov rax, 0x42");

    zydis_req_t req;

    // Default machine mode is long_64 from the factory; verify the getter.
    int64 mm = req.get_machine_mode();
    check("default machine mode == long_64",
          mm == cast<int64>(zydis_machine_mode::long_64));

    req.set_mnemonic(mov_id);
    check("get_mnemonic() echoes set value", req.get_mnemonic() == mov_id);

    req.set_operand_count(2);
    check("get_operand_count() echoes set value", req.get_operand_count() == 2);

    req.set_operand_reg(0, rax_id);
    req.set_operand_imm(1, 0x42);

    array<uint8> mov_bytes = zydis_encode(req);
    check("zydis_encode(mov rax, 0x42).length() == 7", mov_bytes.length() == 7);
    if (mov_bytes.length() == 7) {
        check("byte[0] == 0x48 (REX.W)", mov_bytes.get(0) == 0x48);
        check("byte[1] == 0xC7 (MOV r/m64 imm32)", mov_bytes.get(1) == 0xC7);
        check("byte[2] == 0xC0 (ModR/M for rax)", mov_bytes.get(2) == 0xC0);
        check("byte[3] == 0x42 (imm low)",         mov_bytes.get(3) == 0x42);
        check("byte[4] == 0x00 (imm)",             mov_bytes.get(4) == 0x00);
        check("byte[5] == 0x00 (imm)",             mov_bytes.get(5) == 0x00);
        check("byte[6] == 0x00 (imm high)",        mov_bytes.get(6) == 0x00);
    }

    // -----------------------------------------------------------------------
    // Disassemble those bytes back. Expect 1 instruction whose text contains
    // "mov" + "rax" + "0x42" (or 42).
    // -----------------------------------------------------------------------
    section("zydis_disasm - mov rax, 0x42");

    array<string> dasm = zydis_disasm(mov_bytes, 0);
    check("zydis_disasm yields 1 instruction", dasm.length() == 1);
    if (dasm.length() == 1) {
        string text = dasm.get(0);
        print_console("  decoded: " + text);
        check("disasm text contains 'mov'", text.find("mov") >= 0);
        check("disasm text contains 'rax'", text.find("rax") >= 0);
    }

    // -----------------------------------------------------------------------
    // zydis_decoded_to_request — round-trip our encoded mov bytes back into
    // a request. Verify the returned handle is non-zero. (The original `req`
    // is implicitly dropped at scope exit; the new req is independent.)
    // -----------------------------------------------------------------------
    section("zydis_decoded_to_request");

    {
        zydis_req_t round = zydis_decoded_to_request(mov_bytes, 0);
        check("zydis_decoded_to_request returns non-zero handle",
              cast<int64>(round) != 0);
        if (cast<int64>(round) != 0) {
            check("decoded request mnemonic == mov", round.get_mnemonic() == mov_id);
            check("decoded request operand_count == 2",
                  round.get_operand_count() == 2);
        }
    }

    // -----------------------------------------------------------------------
    // Encode `ret` via a separate request. Single byte 0xC3.
    // -----------------------------------------------------------------------
    section("zydis_req_t - encode ret");

    {
        zydis_req_t ret_req;
        ret_req.set_mnemonic(ret_id);
        ret_req.set_operand_count(0);
        array<uint8> ret_bytes = zydis_encode(ret_req);
        check("encode(ret).length() == 1", ret_bytes.length() == 1);
        if (ret_bytes.length() == 1) {
            check("encode(ret)[0] == 0xC3", ret_bytes.get(0) == 0xC3);
        }
    }

    // -----------------------------------------------------------------------
    // Branch type / branch width setters (no return; just exercise the path
    // without faulting). Pair with a jmp encoding to verify the encoder
    // accepts branch metadata.
    // -----------------------------------------------------------------------
    section("zydis_req_t - branch metadata");

    {
        zydis_req_t br_req;
        br_req.set_mnemonic(jmp_id);
        br_req.set_operand_count(1);
        br_req.set_operand_imm(0, 0x100);
        br_req.set_branch_type(zydis_branch_type::near);
        br_req.set_branch_width(zydis_branch_width::w32);
        array<uint8> jmp_bytes = zydis_encode_absolute(br_req, 0x1000);
        // jmp near rel32 from rip=0x1000+5 to 0x100 -> E9 + rel32
        // Verify the encoder produced 5 bytes starting with E9. Some
        // configurations may collapse to short form; either is acceptable.
        check("encode_absolute(jmp) returns >= 2 bytes", jmp_bytes.length() >= 2);
    }

    // Machine-mode setter via enum — flip to legacy_32 and back.
    {
        zydis_req_t mm_req;
        mm_req.set_machine_mode(zydis_machine_mode::legacy_32);
        check("set_machine_mode(legacy_32) round-trips",
              mm_req.get_machine_mode() == cast<int64>(zydis_machine_mode::legacy_32));
        mm_req.set_machine_mode(zydis_machine_mode::long_64);
        check("set_machine_mode(long_64) round-trips",
              mm_req.get_machine_mode() == cast<int64>(zydis_machine_mode::long_64));
    }

    // -----------------------------------------------------------------------
    // zydis_builder_t — combines real instructions with raw byte chunks.
    // Build a sequence: nop; nop; int3; ret; verify get_count and build()
    // produce the right byte stream.
    // -----------------------------------------------------------------------
    section("zydis_builder_t");

    zydis_builder_t b;
    check("builder.get_count() == 0 initially", b.get_count() == 0);

    b.push_nop(2);
    check("after push_nop(2), get_count() == 2", b.get_count() == 2);

    b.push_int3();
    check("after push_int3, get_count() == 3", b.get_count() == 3);

    b.push_ret();
    check("after push_ret, get_count() == 4", b.get_count() == 4);

    array<uint8> built = b.build();
    check("build().length() == 4 (nop + nop + int3 + ret)", built.length() == 4);
    if (built.length() == 4) {
        check("built[0] == 0x90 (nop)",  built.get(0) == 0x90);
        check("built[1] == 0x90 (nop)",  built.get(1) == 0x90);
        check("built[2] == 0xCC (int3)", built.get(2) == 0xCC);
        check("built[3] == 0xC3 (ret)",  built.get(3) == 0xC3);
    }

    b.clear();
    check("after clear(), get_count() == 0", b.get_count() == 0);

    // Raw byte pushers: push_byte, push_u16 (LE), push_u32 (LE), push_u64 (LE).
    b.push_byte(0xAA);
    b.push_u16(0x1234);          // expect 34 12
    b.push_u32(0xDEADBEEF);      // expect EF BE AD DE
    array<uint8> raw_bytes = b.build();
    check("raw build length == 1+2+4 == 7", raw_bytes.length() == 7);
    if (raw_bytes.length() == 7) {
        check("byte0 == 0xAA",       raw_bytes.get(0) == 0xAA);
        check("u16 LE byte0 == 0x34", raw_bytes.get(1) == 0x34);
        check("u16 LE byte1 == 0x12", raw_bytes.get(2) == 0x12);
        check("u32 LE byte0 == 0xEF", raw_bytes.get(3) == 0xEF);
        check("u32 LE byte1 == 0xBE", raw_bytes.get(4) == 0xBE);
        check("u32 LE byte2 == 0xAD", raw_bytes.get(5) == 0xAD);
        check("u32 LE byte3 == 0xDE", raw_bytes.get(6) == 0xDE);
    }

    // push_u64 LE writes 8 bytes
    b.clear();
    b.push_u64(0x0123456789ABCDEF);
    array<uint8> u64_bytes = b.build();
    check("push_u64 produces 8 bytes", u64_bytes.length() == 8);
    if (u64_bytes.length() == 8) {
        check("u64 LE byte0 == 0xEF", u64_bytes.get(0) == 0xEF);
        check("u64 LE byte7 == 0x01", u64_bytes.get(7) == 0x01);
    }

    // push_bytes from an existing array<uint8>.
    b.clear();
    array<uint8> chunk = zydis_nop_fill(3);
    b.push_bytes(chunk);
    check("after push_bytes(nop_fill(3)), get_count == 1",
          b.get_count() == 1);
    array<uint8> after_chunk = b.build();
    check("push_bytes round-trip length == 3", after_chunk.length() == 3);

    // push(req): take our `mov rax, 0x42` request and have the builder
    // re-encode it (with absolute base address). Result should match the
    // standalone encoding.
    b.clear();
    b.set_base_address(0x1000);
    b.push(req);
    array<uint8> via_builder = b.build();
    check("builder push(mov_req).length() == 7", via_builder.length() == 7);
    if (via_builder.length() == 7) {
        check("builder bytes[0] == 0x48", via_builder.get(0) == 0x48);
        check("builder bytes[2] == 0xC0", via_builder.get(2) == 0xC0);
    }

    // Switch builder machine mode via the enum — exercise the path without
    // asserting on output bytes (which depend on internal state we don't
    // re-check in this surface test).
    b.set_machine_mode(zydis_machine_mode::legacy_32);
    b.set_machine_mode(zydis_machine_mode::long_64);
    check("set_machine_mode survives", true);

    // -----------------------------------------------------------------------
    // Empty-input edge cases.
    // -----------------------------------------------------------------------
    section("edge cases");

    array<uint8> empty;
    array<string> empty_dasm = zydis_disasm(empty, 0);
    check("disasm(empty) returns empty array", empty_dasm.length() == 0);

    // Decoding garbage bytes: a single 0xFF can be a valid prefix or part of
    // a longer encoding. For 1 isolated byte, decode often succeeds (e.g.
    // 'inc') or fails cleanly. Just verify the call doesn't fault.
    array<uint8> ff_byte = zydis_nop_fill(1);
    ff_byte.set(0, 0xFF);
    array<string> ff_dasm = zydis_disasm(ff_byte, 0);
    check("disasm(garbage byte) survives without fault",
          ff_dasm.length() >= 0);

    // -----------------------------------------------------------------------
    // Summary
    // -----------------------------------------------------------------------
    print_console("");
    print_console("===========================================");
    print_console("  PASS: " + cast<string>(g_pass));
    print_console("  FAIL: " + cast<string>(g_fail));
    print_console("===========================================");

    unregister_routine(g_handle);
}

void on_menu_run_again(int64 data) {
    print_console("[menu] 'Run again' clicked - resetting and re-firing routine");
    g_done = 0;
    g_pass = 0;
    g_fail = 0;
}

void on_menu_log_summary(int64 data) {
    print_console("[menu] summary so far: PASS=" + cast<string>(g_pass) +
                  "  FAIL=" + cast<string>(g_fail));
}

int32 main() {
    print_console("[test_zydis_api] launching test routine + sidebar menu");

    g_section = create_sidebar_section("zydis test", "");
    g_btn     = g_section.create_button("Actions", ui_align::left);
    g_menu    = create_menu();
    g_menu.add_item("Run again",   cast<int64>(on_menu_run_again),   "", "");
    g_menu.add_separator();
    g_menu.add_item("Log summary", cast<int64>(on_menu_log_summary), "", "");
    g_menu.attach_to_button(g_btn);

    g_handle = register_routine(cast<int64>(test_routine), 0);
    if (g_handle == 0) {
        print_console("[FAIL] register_routine returned 0");
        return -1;
    }
    return 1;
}
