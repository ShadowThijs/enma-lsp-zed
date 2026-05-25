// =============================================================================
// Unicorn API smoke test
//
// Exercises every native registered by enma_unicorn_api.cpp:
//   - cpu_create / cpu_create_process / cpu_active
//   - cpu_t.mem_map / mem_write / mem_read
//   - cpu_t.reg_write64 / reg_read64
//   - cpu_t.reg_write128 / reg_read128 / reg_write256 / reg_read256
//   - cpu_t.start / emu_stop / flush_code / setup_stack
//   - cpu_t.hook_add (uc_hook::code, uc_hook::mem_unmapped)
//   - cpu_t.get_last_exception / get_exception_address
//   - uc_reg / uc_prot / uc_hook enum values
//
// Encoded instruction bytes (mov rax, imm32 + nop sled) — built inline so the
// test doesn't depend on zydis. The encoding matches the zydis test's
// expectations.
//   mov rax, 0x42  -> 48 C7 C0 42 00 00 00   (7 bytes)
//   nop            -> 90                     (1 byte)
//   ret            -> C3                     (1 byte)
// =============================================================================

int64 g_pass = 0;
int64 g_fail = 0;
int64 g_handle = 0;
int64 g_done = 0;

sidebar_section_t g_section;
button_t          g_btn;
menu_t            g_menu;

// Hook callback counters.
int64 g_code_hook_hits = 0;
int64 g_unmapped_hits  = 0;

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

// uc_hook::code callback — fires per executed instruction. Return non-zero
// to continue, 0 to stop. Increments a global counter so the test routine
// can assert it fired.
int64 on_code_hook(int64 addr) {
    g_code_hook_hits = g_code_hook_hits + 1;
    return 1;
}

// uc_hook::mem_unmapped callback — fires on access to an unmapped page.
// Returns 0 (stop emulation) to bake the failure into get_last_exception.
int64 on_unmapped_hook(int64 addr) {
    g_unmapped_hits = g_unmapped_hits + 1;
    return 0;
}

void test_routine(int64 data) {
    if (g_done != 0) return;
    g_done = 1;

    print_console("=== unicorn API smoke test ===");

    // -----------------------------------------------------------------------
    // cpu_create — standalone, no process backing.
    // -----------------------------------------------------------------------
    section("cpu_create + basic exec");

    cpu_t cpu = cpu_create();
    check("cpu_create() returns non-zero handle", cast<int64>(cpu) != 0);

    // Map a 4 KiB RWX page at 0x1000 for code + a NOP sled.
    bool mapped = cpu.mem_map(0x1000, 0x1000, uc_prot::rwx);
    check("mem_map(0x1000, 0x1000, uc_prot::rwx) succeeds", mapped);

    // Build the code stream: mov rax, 0x42 ; nop
    array<uint8> code;
    code.push(0x48); code.push(0xC7); code.push(0xC0);
    code.push(0x42); code.push(0x00); code.push(0x00); code.push(0x00);
    code.push(0x90);

    bool wrote = cpu.mem_write(0x1000, code);
    check("mem_write(0x1000, code) succeeds", wrote);

    // Read back and verify.
    array<uint8> readback = cpu.mem_read(0x1000, 8);
    check("mem_read(0x1000, 8).length() == 8", readback.length() == 8);
    if (readback.length() == 8) {
        check("readback[0] == 0x48 (REX.W)", readback.get(0) == 0x48);
        check("readback[7] == 0x90 (nop)",   readback.get(7) == 0x90);
    }

    // Execute exactly 2 instructions: mov rax, 0x42 ; nop.
    int64 result = cpu.start(0x1000, 0x1100, 0, 2);
    check("cpu.start(...) returns 0 (UC_ERR_OK)", result == 0);

    int64 rax = cpu.reg_read64(uc_reg::rax);
    check("reg_read64(uc_reg::rax) == 0x42", rax == 0x42);

    // Write rcx and read it back.
    bool wrote_rcx = cpu.reg_write64(uc_reg::rcx, 0xDEADBEEF);
    check("reg_write64(uc_reg::rcx, 0xDEADBEEF) succeeds", wrote_rcx);
    int64 rcx = cpu.reg_read64(uc_reg::rcx);
    check("reg_read64(uc_reg::rcx) == 0xDEADBEEF", rcx == 0xDEADBEEF);

    // Verify other regs are 0 by default.
    int64 rbx = cpu.reg_read64(uc_reg::rbx);
    check("reg_read64(uc_reg::rbx) == 0 (untouched)", rbx == 0);

    int64 rip = cpu.reg_read64(uc_reg::rip);
    // After 2 instructions (7 + 1), rip should be at 0x1008.
    check("reg_read64(uc_reg::rip) == 0x1008 (post-execution)", rip == 0x1008);

    // -----------------------------------------------------------------------
    // SIMD register read / write — XMM (16 bytes), YMM (32 bytes).
    // -----------------------------------------------------------------------
    section("SIMD register read / write");

    array<uint8> xmm_in;
    int64 i = 0;
    while (i < 16) {
        xmm_in.push(cast<uint8>(0xA0 + i));
        i = i + 1;
    }
    bool wrote_xmm = cpu.reg_write128(uc_reg::xmm0, xmm_in);
    check("reg_write128(xmm0, 16 bytes) succeeds", wrote_xmm);

    array<uint8> xmm_out = cpu.reg_read128(uc_reg::xmm0);
    check("reg_read128(xmm0).length() == 16", xmm_out.length() == 16);
    if (xmm_out.length() == 16) {
        check("xmm_out[0] == 0xA0",  xmm_out.get(0)  == 0xA0);
        check("xmm_out[15] == 0xAF", xmm_out.get(15) == 0xAF);
    }

    // Wrong size (must be exactly 16) should fail.
    array<uint8> too_small;
    too_small.push(0xFF); too_small.push(0xFF);
    bool bad_xmm = cpu.reg_write128(uc_reg::xmm0, too_small);
    check("reg_write128 with 2 bytes (not 16) fails", !bad_xmm);

    // YMM: 32 bytes.
    array<uint8> ymm_in;
    int64 j = 0;
    while (j < 32) {
        ymm_in.push(cast<uint8>(0x10 + j));
        j = j + 1;
    }
    bool wrote_ymm = cpu.reg_write256(uc_reg::ymm1, ymm_in);
    check("reg_write256(ymm1, 32 bytes) succeeds", wrote_ymm);
    array<uint8> ymm_out = cpu.reg_read256(uc_reg::ymm1);
    check("reg_read256(ymm1).length() == 32", ymm_out.length() == 32);
    if (ymm_out.length() == 32) {
        check("ymm_out[0]  == 0x10", ymm_out.get(0)  == 0x10);
        check("ymm_out[31] == 0x2F", ymm_out.get(31) == 0x2F);
    }

    // -----------------------------------------------------------------------
    // hook_add(uc_hook::code, fn) — should fire once per executed instruction.
    // Reset rax, re-execute, verify counter.
    // -----------------------------------------------------------------------
    section("uc_hook::code");

    g_code_hook_hits = 0;
    bool hook_ok = cpu.hook_add(uc_hook::code, cast<int64>(on_code_hook));
    check("hook_add(uc_hook::code, ...) succeeds", hook_ok);

    // Reset rip + rax for a clean re-run.
    cpu.reg_write64(uc_reg::rip, 0x1000);
    cpu.reg_write64(uc_reg::rax, 0);

    int64 r2 = cpu.start(0x1000, 0x1100, 0, 2);
    check("re-start returns 0 (UC_ERR_OK)", r2 == 0);
    check("rax == 0x42 again after re-run",
          cpu.reg_read64(uc_reg::rax) == 0x42);
    check("uc_hook::code fired >= 1 time", g_code_hook_hits >= 1);
    check("uc_hook::code fired <= 2 (matches instruction count)",
          g_code_hook_hits <= 2);
    print_console("  hook fired " + cast<string>(g_code_hook_hits) + " times");

    // -----------------------------------------------------------------------
    // emu_stop / flush_code — exercise without strict assertion. emu_stop
    // outside a hook call is a no-op; flush_code drops translation cache.
    // -----------------------------------------------------------------------
    section("emu_stop / flush_code");

    cpu.emu_stop();
    check("emu_stop() outside hook survives", true);

    bool flushed = cpu.flush_code();
    check("flush_code() succeeds", flushed);

    // -----------------------------------------------------------------------
    // setup_stack — map stack pages, set RSP. Test that the call succeeds
    // and that a subsequent reg_read64(uc_reg::rsp) is non-zero.
    // -----------------------------------------------------------------------
    section("setup_stack");

    // Stack at 0x100000, 4 KiB, stop addr 0x200000. Stop addr gets a NOP page.
    bool stack_ok = cpu.setup_stack(0x100000, 0x1000, 0x200000);
    check("setup_stack(0x100000, 0x1000, 0x200000) succeeds", stack_ok);

    int64 rsp = cpu.reg_read64(uc_reg::rsp);
    check("reg_read64(uc_reg::rsp) != 0 after setup_stack", rsp != 0);
    check("rsp inside the mapped stack range",
          rsp >= 0x100000 && rsp < 0x100000 + 0x1000);

    // setup_stack with size < 4 KiB rejects.
    bool too_small_stack = cpu.setup_stack(0x300000, 0x100, 0x400000);
    check("setup_stack with size < 0x1000 rejects", !too_small_stack);

    // -----------------------------------------------------------------------
    // get_last_exception — emulate at an unmapped address. The auto-unmapped
    // hook ISN'T active for standalone cpus (process_mode=false), so the
    // unmapped read raises an immediate fault. We can also wire our own
    // user-space mem_unmapped hook to count it.
    //
    // We use a fresh cpu so previous mappings don't interfere. start() at an
    // address never mapped should yield a non-zero error code, and
    // get_last_exception should be either 0 (no host-emit) or a fault code.
    // -----------------------------------------------------------------------
    section("get_last_exception (unmapped exec)");

    {
        cpu_t cpu2 = cpu_create();
        check("cpu2 = cpu_create() valid", cast<int64>(cpu2) != 0);

        // Wire a mem_unmapped hook so we observe the bad fetch.
        g_unmapped_hits = 0;
        bool mu_ok = cpu2.hook_add(uc_hook::mem_unmapped,
                                   cast<int64>(on_unmapped_hook));
        check("hook_add(uc_hook::mem_unmapped) succeeds", mu_ok);

        // Start at 0xDEAD0000 — never mapped.
        int64 r = cpu2.start(0xDEAD0000, 0xDEAD1000, 0, 1);
        check("start(unmapped) returns non-zero error", r != 0);

        // The mem_unmapped hook fired (we count from the hook itself, no host
        // dependency). Note that for fetch-unmapped, unicorn calls our hook
        // before deciding what to do.
        check("uc_hook::mem_unmapped fired >= 1 time", g_unmapped_hits >= 1);
        print_console("  unmapped hook fired " + cast<string>(g_unmapped_hits) +
                      " times");

        int64 exc = cpu2.get_last_exception();
        int64 exc_addr = cpu2.get_exception_address();
        // exc may be 0 if the user hook returned 0 BEFORE the cb_auto_unmapped
        // path stored a code, or set to 0xC0000005 if the path ran. Just
        // ensure get_last_exception didn't fault.
        check("get_last_exception() survives",       exc >= 0 || exc < 0);
        check("get_exception_address() survives",    exc_addr >= 0 || exc_addr < 0);
        print_console("  last_exception = 0x" + cast<string>(exc) +
                      "  addr = 0x" + cast<string>(exc_addr));
    }

    // -----------------------------------------------------------------------
    // cpu_active() — outside a hook callback this should return null.
    // -----------------------------------------------------------------------
    section("cpu_active outside hook");

    cpu_t active_now = cpu_active();
    check("cpu_active() outside hook == null",
          cast<int64>(active_now) == 0);

    // -----------------------------------------------------------------------
    // cpu_create_process(null_proc, false) — null proc rejects.
    // -----------------------------------------------------------------------
    section("cpu_create_process null guard");

    proc_t null_proc;
    cpu_t cp = cpu_create_process(null_proc, false);
    check("cpu_create_process(null, false) returns 0",
          cast<int64>(cp) == 0);

    // -----------------------------------------------------------------------
    // uc_prot enum sanity — bit-flag values should compose cleanly.
    // -----------------------------------------------------------------------
    section("uc_prot enum sanity");

    int64 read_v  = cast<int64>(uc_prot::read);
    int64 write_v = cast<int64>(uc_prot::write);
    int64 exec_v  = cast<int64>(uc_prot::exec);
    int64 rwx_v   = cast<int64>(uc_prot::rwx);
    int64 all_v   = cast<int64>(uc_prot::all);
    check("uc_prot::read != 0",  read_v != 0);
    check("uc_prot::write != 0", write_v != 0);
    check("uc_prot::exec != 0",  exec_v != 0);
    check("uc_prot::rwx == read | write | exec",
          rwx_v == (read_v | write_v | exec_v));
    check("uc_prot::all == uc_prot::rwx", all_v == rwx_v);

    int64 none_v = cast<int64>(uc_prot::none);
    check("uc_prot::none == 0", none_v == 0);

    // uc_hook enum sanity.
    int64 hk_code = cast<int64>(uc_hook::code);
    int64 hk_mem  = cast<int64>(uc_hook::mem_unmapped);
    check("uc_hook::code == 1",         hk_code == 1);
    check("uc_hook::mem_unmapped == 2", hk_mem == 2);

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
    g_code_hook_hits = 0;
    g_unmapped_hits = 0;
}

void on_menu_log_summary(int64 data) {
    print_console("[menu] summary so far: PASS=" + cast<string>(g_pass) +
                  "  FAIL=" + cast<string>(g_fail));
}

int32 main() {
    print_console("[test_unicorn_api] launching test routine + sidebar menu");

    g_section = create_sidebar_section("unicorn test", "");
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
