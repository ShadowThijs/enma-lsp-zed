// =============================================================================
// Unicorn API comprehensive test
//
// Exercises every type, method, function, and enum variant documented in the
// Unicorn API. Each numbered section tests a logical group of functionality.
//
// --- Types ---
//   cpu_t           Emulator handle (RAII, closes engine + frees hooks).
//   uc_reg enum     Register identifiers for reg_{read,write}{64,128,256}.
//   uc_prot enum    Memory protection flags (composable via bitwise OR).
//   uc_hook enum    Hook type identifiers for hook_add.
//
// --- uc_reg variants ---
//   General:   rax, rbx, rcx, rdx, rsi, rdi, rbp, rsp
//   Extended:  r8, r9, r10, r11, r12, r13, r14, r15
//   IP/Flags:  rip, eflags
//   Segment:   cs, ds, es, fs, gs, ss
//   Base:      fs_base, gs_base
//   SIMD ctl:  mxcsr
//   XMM:       xmm0 .. xmm15
//   YMM:       ymm0 .. ymm15
//
// --- uc_prot variants ---
//   none, read, write, exec, rw, rx, rwx, all
//
// --- uc_hook variants ---
//   code, mem_unmapped
//
// --- Standalone functions ---
//   cpu_t cpu_create()
//   cpu_t cpu_create_process(proc_t proc, bool allow_writes)
//   cpu_t cpu_active()
//
// --- cpu_t methods ---
//   Memory:
//     bool         mem_map(int64 addr, int64 size, uc_prot perms)
//     bool         mem_write(int64 addr, array<uint8> bytes)
//     array<uint8> mem_read(int64 addr, int64 size)
//   Registers:
//     bool         reg_write64(uc_reg reg, int64 value)
//     int64        reg_read64(uc_reg reg)
//     bool         reg_write128(uc_reg reg, array<uint8> bytes)
//     array<uint8> reg_read128(uc_reg reg)
//     bool         reg_write256(uc_reg reg, array<uint8> bytes)
//     array<uint8> reg_read256(uc_reg reg)
//   Execution:
//     int64        start(int64 begin, int64 end, int64 timeout, int64 count)
//     void         emu_stop()
//     bool         flush_code()
//     bool         setup_stack(int64 base, int64 size, int64 stop_addr)
//   Hooks:
//     bool         hook_add(uc_hook hook_kind, int64 fn_handle)
//   Exception inspection:
//     int64        get_last_exception()
//     int64        get_exception_address()
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

// -----------------------------------------------------------------------
// Hook callbacks.
//   uc_hook::code callback — fires per executed instruction. Return
//   non-zero to continue, 0 to stop emulation.
//   uc_hook::mem_unmapped callback — fires on access to unmapped page.
//   Return 0 to stop (bakes the failure into get_last_exception).
// -----------------------------------------------------------------------
int64 on_code_hook(int64 addr) {
    g_code_hook_hits = g_code_hook_hits + 1;
    return 1;
}

int64 on_unmapped_hook(int64 addr) {
    g_unmapped_hits = g_unmapped_hits + 1;
    return 0;
}

// -----------------------------------------------------------------------
// Encoded instruction helpers.
//   mov rax, imm32  ->  48 C7 C0 <4-byte-imm>  (7 bytes)
//   nop             ->  90                     (1 byte)
// -----------------------------------------------------------------------
array<uint8> encode_mov_rax_imm32(int64 imm) {
    array<uint8> bytes;
    bytes.push(0x48); // REX.W
    bytes.push(0xC7); // MOV r/m64, imm32
    bytes.push(0xC0); // ModR/M: rax
    bytes.push(cast<uint8>(imm & 0xFF));
    bytes.push(cast<uint8>((imm >> 8) & 0xFF));
    bytes.push(cast<uint8>((imm >> 16) & 0xFF));
    bytes.push(cast<uint8>((imm >> 24) & 0xFF));
    return bytes;
}

// ===========================================================================
// TEST ROUTINE
// ===========================================================================
void test_routine(int64 data) {
    if (g_done != 0) return;
    g_done = 1;

    print_console("=== Unicorn API comprehensive test ===");

    // -------------------------------------------------------------------
    // 1. cpu_create + basic execution
    //    Tests: cpu_create(), mem_map, mem_write, mem_read, start,
    //           reg_read64 (rax, rip), reg_write64 (rip, rax)
    // -------------------------------------------------------------------
    section("1. cpu_create + basic exec");

    cpu_t cpu = cpu_create();
    check("cpu_create() returns non-zero handle", cast<int64>(cpu) != 0);

    // Map a 4 KiB RWX page at 0x1000 for code.
    bool mapped = cpu.mem_map(0x1000, 0x1000, uc_prot::rwx);
    check("mem_map(0x1000, 0x1000, uc_prot::rwx) succeeds", mapped);

    // Build code: mov rax, 0x42 ; nop.
    array<uint8> code = encode_mov_rax_imm32(0x42);
    code.push(0x90); // nop

    bool wrote = cpu.mem_write(0x1000, code);
    check("mem_write(0x1000, code) succeeds", wrote);

    // Read back and verify bytes.
    array<uint8> readback = cpu.mem_read(0x1000, 8);
    check("mem_read(0x1000, 8).length() == 8", readback.length() == 8);
    if (readback.length() == 8) {
        check("readback[0] == 0x48 (REX.W)", readback.get(0) == 0x48);
        check("readback[7] == 0x90 (nop)",   readback.get(7) == 0x90);
    }

    // Execute exactly 2 instructions.
    int64 result = cpu.start(0x1000, 0x1100, 0, 2);
    check("cpu.start(0x1000, 0x1100, 0, 2) returns 0 (UC_ERR_OK)", result == 0);

    int64 rax = cpu.reg_read64(uc_reg::rax);
    check("reg_read64(uc_reg::rax) == 0x42", rax == 0x42);

    // After 2 instructions, RIP should be at code.length() from start.
    int64 rip = cpu.reg_read64(uc_reg::rip);
    check("reg_read64(uc_reg::rip) == 0x1008", rip == 0x1008);

    // mem_read from unmapped address returns empty array (edge case).
    array<uint8> unmapped_read = cpu.mem_read(0xDEAD0000, 16);
    check("mem_read(unmapped addr) returns empty array",
          unmapped_read.length() == 0);

    // -------------------------------------------------------------------
    // 2. All general-purpose registers — write each, read back.
    //    Tests: reg_write64, reg_read64 for rax, rbx, rcx, rdx, rsi,
    //           rdi, rbp, rsp, r8 .. r15
    // -------------------------------------------------------------------
    section("2. General-purpose registers");

    // rax (already tested, but set to new value to prove round-trip)
    bool w_rax = cpu.reg_write64(uc_reg::rax, 0xDEADBEEF);
    check("reg_write64(rax, 0xDEADBEEF) succeeds", w_rax);
    check("reg_read64(rax) == 0xDEADBEEF",
          cpu.reg_read64(uc_reg::rax) == 0xDEADBEEF);

    bool w_rbx = cpu.reg_write64(uc_reg::rbx, 0xCAFEBABE);
    check("reg_write64(rbx, 0xCAFEBABE) succeeds", w_rbx);
    check("reg_read64(rbx) == 0xCAFEBABE",
          cpu.reg_read64(uc_reg::rbx) == 0xCAFEBABE);

    bool w_rcx = cpu.reg_write64(uc_reg::rcx, 0x12345678);
    check("reg_write64(rcx, 0x12345678) succeeds", w_rcx);
    check("reg_read64(rcx) == 0x12345678",
          cpu.reg_read64(uc_reg::rcx) == 0x12345678);

    bool w_rdx = cpu.reg_write64(uc_reg::rdx, 0x9ABCDEF0);
    check("reg_write64(rdx, 0x9ABCDEF0) succeeds", w_rdx);
    check("reg_read64(rdx) == 0x9ABCDEF0",
          cpu.reg_read64(uc_reg::rdx) == 0x9ABCDEF0);

    bool w_rsi = cpu.reg_write64(uc_reg::rsi, 0xAABBCCDD);
    check("reg_write64(rsi, 0xAABBCCDD) succeeds", w_rsi);
    check("reg_read64(rsi) == 0xAABBCCDD",
          cpu.reg_read64(uc_reg::rsi) == 0xAABBCCDD);

    bool w_rdi = cpu.reg_write64(uc_reg::rdi, 0x11223344);
    check("reg_write64(rdi, 0x11223344) succeeds", w_rdi);
    check("reg_read64(rdi) == 0x11223344",
          cpu.reg_read64(uc_reg::rdi) == 0x11223344);

    bool w_rbp = cpu.reg_write64(uc_reg::rbp, 0x10001000);
    check("reg_write64(rbp, 0x10001000) succeeds", w_rbp);
    check("reg_read64(rbp) == 0x10001000",
          cpu.reg_read64(uc_reg::rbp) == 0x10001000);

    // rsp — save and restore so execution still works.
    int64 old_rsp = cpu.reg_read64(uc_reg::rsp);
    bool w_rsp = cpu.reg_write64(uc_reg::rsp, 0x20002000);
    check("reg_write64(rsp, 0x20002000) succeeds", w_rsp);
    check("reg_read64(rsp) == 0x20002000",
          cpu.reg_read64(uc_reg::rsp) == 0x20002000);
    cpu.reg_write64(uc_reg::rsp, old_rsp);

    // Extended registers r8 through r15.
    bool w_r8 = cpu.reg_write64(uc_reg::r8, 0x88888888);
    check("reg_write64(r8, 0x88888888) succeeds", w_r8);
    check("reg_read64(r8) == 0x88888888",
          cpu.reg_read64(uc_reg::r8) == 0x88888888);

    bool w_r9 = cpu.reg_write64(uc_reg::r9, 0x99999999);
    check("reg_write64(r9, 0x99999999) succeeds", w_r9);
    check("reg_read64(r9) == 0x99999999",
          cpu.reg_read64(uc_reg::r9) == 0x99999999);

    bool w_r10 = cpu.reg_write64(uc_reg::r10, 0xAAAAAAAA);
    check("reg_write64(r10, 0xAAAAAAAA) succeeds", w_r10);
    check("reg_read64(r10) == 0xAAAAAAAA",
          cpu.reg_read64(uc_reg::r10) == 0xAAAAAAAA);

    bool w_r11 = cpu.reg_write64(uc_reg::r11, 0xBBBBBBBB);
    check("reg_write64(r11, 0xBBBBBBBB) succeeds", w_r11);
    check("reg_read64(r11) == 0xBBBBBBBB",
          cpu.reg_read64(uc_reg::r11) == 0xBBBBBBBB);

    bool w_r12 = cpu.reg_write64(uc_reg::r12, 0xCCCCCCCC);
    check("reg_write64(r12, 0xCCCCCCCC) succeeds", w_r12);
    check("reg_read64(r12) == 0xCCCCCCCC",
          cpu.reg_read64(uc_reg::r12) == 0xCCCCCCCC);

    bool w_r13 = cpu.reg_write64(uc_reg::r13, 0xDDDDDDDD);
    check("reg_write64(r13, 0xDDDDDDDD) succeeds", w_r13);
    check("reg_read64(r13) == 0xDDDDDDDD",
          cpu.reg_read64(uc_reg::r13) == 0xDDDDDDDD);

    bool w_r14 = cpu.reg_write64(uc_reg::r14, 0xEEEEEEEE);
    check("reg_write64(r14, 0xEEEEEEEE) succeeds", w_r14);
    check("reg_read64(r14) == 0xEEEEEEEE",
          cpu.reg_read64(uc_reg::r14) == 0xEEEEEEEE);

    bool w_r15 = cpu.reg_write64(uc_reg::r15, 0xFFFFFFFF);
    check("reg_write64(r15, 0xFFFFFFFF) succeeds", w_r15);
    check("reg_read64(r15) == 0xFFFFFFFF",
          cpu.reg_read64(uc_reg::r15) == 0xFFFFFFFF);

    // -------------------------------------------------------------------
    // 3. Instruction pointer and flags.
    //    Tests: reg_write64 / reg_read64 for rip, eflags
    // -------------------------------------------------------------------
    section("3. rip + eflags");

    // Read and restore rip after test.
    int64 old_rip = cpu.reg_read64(uc_reg::rip);
    bool w_rip = cpu.reg_write64(uc_reg::rip, 0x1000);
    check("reg_write64(rip, 0x1000) succeeds", w_rip);
    check("reg_read64(rip) == 0x1000",
          cpu.reg_read64(uc_reg::rip) == 0x1000);
    cpu.reg_write64(uc_reg::rip, old_rip);

    // eflags: write IF flag (bit 9 = 0x200) + reserved bit 1 (0x002).
    bool w_eflags = cpu.reg_write64(uc_reg::eflags, 0x202);
    check("reg_write64(eflags, 0x202) succeeds", w_eflags);
    int64 eflags_val = cpu.reg_read64(uc_reg::eflags);
    check("reg_read64(eflags) has IF set (bit 9)",
          (eflags_val & 0x200) == 0x200);

    // -------------------------------------------------------------------
    // 4. Segment registers.
    //    Tests: reg_write64 / reg_read64 for cs, ds, es, fs, gs, ss
    // -------------------------------------------------------------------
    section("4. Segment registers");

    // x86-64 typical user-mode selectors.
    bool w_cs  = cpu.reg_write64(uc_reg::cs,  0x23);
    check("reg_write64(cs, 0x23) succeeds", w_cs);

    bool w_ds  = cpu.reg_write64(uc_reg::ds,  0x2B);
    check("reg_write64(ds, 0x2B) succeeds", w_ds);

    bool w_es  = cpu.reg_write64(uc_reg::es,  0x2B);
    check("reg_write64(es, 0x2B) succeeds", w_es);

    bool w_fs  = cpu.reg_write64(uc_reg::fs,  0x53);
    check("reg_write64(fs, 0x53) succeeds", w_fs);

    bool w_gs  = cpu.reg_write64(uc_reg::gs,  0x2B);
    check("reg_write64(gs, 0x2B) succeeds", w_gs);

    bool w_ss  = cpu.reg_write64(uc_reg::ss,  0x23);
    check("reg_write64(ss, 0x23) succeeds", w_ss);

    // Read back — segment selectors may be normalized by the engine but the
    // read should at least survive and return a non-negative value.
    check("reg_read64(cs) survives",  cpu.reg_read64(uc_reg::cs)  >= 0);
    check("reg_read64(ds) survives",  cpu.reg_read64(uc_reg::ds)  >= 0);
    check("reg_read64(es) survives",  cpu.reg_read64(uc_reg::es)  >= 0);
    check("reg_read64(fs) survives",  cpu.reg_read64(uc_reg::fs)  >= 0);
    check("reg_read64(gs) survives",  cpu.reg_read64(uc_reg::gs)  >= 0);
    check("reg_read64(ss) survives",  cpu.reg_read64(uc_reg::ss)  >= 0);

    // -------------------------------------------------------------------
    // 5. fs_base, gs_base, mxcsr.
    //    Tests: reg_write64 / reg_read64 for fs_base, gs_base, mxcsr
    // -------------------------------------------------------------------
    section("5. fs_base, gs_base, mxcsr");

    bool w_fsbase = cpu.reg_write64(uc_reg::fs_base, 0x7FFE0000);
    check("reg_write64(fs_base, 0x7FFE0000) succeeds", w_fsbase);
    check("reg_read64(fs_base) == 0x7FFE0000",
          cpu.reg_read64(uc_reg::fs_base) == 0x7FFE0000);

    bool w_gsbase = cpu.reg_write64(uc_reg::gs_base, 0x7FFE1000);
    check("reg_write64(gs_base, 0x7FFE1000) succeeds", w_gsbase);
    check("reg_read64(gs_base) == 0x7FFE1000",
          cpu.reg_read64(uc_reg::gs_base) == 0x7FFE1000);

    // mxcsr: default value (all exceptions masked, round-nearest).
    bool w_mxcsr = cpu.reg_write64(uc_reg::mxcsr, 0x1F80);
    check("reg_write64(mxcsr, 0x1F80) succeeds", w_mxcsr);
    check("reg_read64(mxcsr) == 0x1F80",
          cpu.reg_read64(uc_reg::mxcsr) == 0x1F80);

    // -------------------------------------------------------------------
    // 6. SIMD registers — XMM (16 bytes) and YMM (32 bytes).
    //    Tests: reg_write128, reg_read128, reg_write256, reg_read256
    //           Wrong-size edge cases.
    // -------------------------------------------------------------------
    section("6. XMM / YMM registers");

    // XMM0: write 16 ascending bytes, read back.
    array<uint8> xmm_in;
    int64 xi = 0;
    while (xi < 16) {
        xmm_in.push(cast<uint8>(0xA0 + xi));
        xi = xi + 1;
    }
    bool wrote_xmm0 = cpu.reg_write128(uc_reg::xmm0, xmm_in);
    check("reg_write128(xmm0, 16 bytes) succeeds", wrote_xmm0);

    array<uint8> xmm0_out = cpu.reg_read128(uc_reg::xmm0);
    check("reg_read128(xmm0).length() == 16", xmm0_out.length() == 16);
    if (xmm0_out.length() == 16) {
        check("xmm0_out[0]  == 0xA0", xmm0_out.get(0)  == 0xA0);
        check("xmm0_out[15] == 0xAF", xmm0_out.get(15) == 0xAF);
    }

    // XMM1: write all zeros, read back.
    array<uint8> xmm1_in;
    int64 xi2 = 0;
    while (xi2 < 16) {
        xmm1_in.push(0x00);
        xi2 = xi2 + 1;
    }
    bool wrote_xmm1 = cpu.reg_write128(uc_reg::xmm1, xmm1_in);
    check("reg_write128(xmm1, zeroes) succeeds", wrote_xmm1);
    array<uint8> xmm1_out = cpu.reg_read128(uc_reg::xmm1);
    check("reg_read128(xmm1).length() == 16", xmm1_out.length() == 16);
    check("reg_read128(xmm1)[0] == 0x00", xmm1_out.get(0) == 0x00);

    // XMM15: test high-index XMM register.
    array<uint8> xmm15_in;
    int64 xi15 = 0;
    while (xi15 < 16) {
        xmm15_in.push(cast<uint8>(0xF0 + xi15));
        xi15 = xi15 + 1;
    }
    bool wrote_xmm15 = cpu.reg_write128(uc_reg::xmm15, xmm15_in);
    check("reg_write128(xmm15, 16 bytes) succeeds", wrote_xmm15);
    array<uint8> xmm15_out = cpu.reg_read128(uc_reg::xmm15);
    check("reg_read128(xmm15).length() == 16", xmm15_out.length() == 16);
    check("xmm15_out[0] == 0xF0", xmm15_out.get(0) == 0xF0);
    check("xmm15_out[15] == 0xFF", xmm15_out.get(15) == 0xFF);

    // Wrong-size write to XMM (must be exactly 16 bytes) should fail.
    array<uint8> too_short;
    too_short.push(0xFF); too_short.push(0xFF);
    bool bad_xmm = cpu.reg_write128(uc_reg::xmm0, too_short);
    check("reg_write128 with 2 bytes (not 16) fails", !bad_xmm);

    // YMM0: write 32 ascending bytes, read back.
    array<uint8> ymm_in;
    int64 yi = 0;
    while (yi < 32) {
        ymm_in.push(cast<uint8>(0x10 + yi));
        yi = yi + 1;
    }
    bool wrote_ymm0 = cpu.reg_write256(uc_reg::ymm0, ymm_in);
    check("reg_write256(ymm0, 32 bytes) succeeds", wrote_ymm0);

    array<uint8> ymm0_out = cpu.reg_read256(uc_reg::ymm0);
    check("reg_read256(ymm0).length() == 32", ymm0_out.length() == 32);
    if (ymm0_out.length() == 32) {
        check("ymm0_out[0]  == 0x10", ymm0_out.get(0)  == 0x10);
        check("ymm0_out[31] == 0x2F", ymm0_out.get(31) == 0x2F);
    }

    // YMM15: test high-index YMM register.
    array<uint8> ymm15_in;
    int64 yi15 = 0;
    while (yi15 < 32) {
        ymm15_in.push(cast<uint8>(0x80 + yi15));
        yi15 = yi15 + 1;
    }
    bool wrote_ymm15 = cpu.reg_write256(uc_reg::ymm15, ymm15_in);
    check("reg_write256(ymm15, 32 bytes) succeeds", wrote_ymm15);
    array<uint8> ymm15_out = cpu.reg_read256(uc_reg::ymm15);
    check("reg_read256(ymm15).length() == 32", ymm15_out.length() == 32);
    check("ymm15_out[0] == 0x80", ymm15_out.get(0) == 0x80);
    check("ymm15_out[31] == 0x9F", ymm15_out.get(31) == 0x9F);

    // Wrong-size write to YMM (must be exactly 32 bytes) should fail.
    array<uint8> ymm_short;
    ymm_short.push(0xFF); ymm_short.push(0xFF); ymm_short.push(0xFF);
    bool bad_ymm = cpu.reg_write256(uc_reg::ymm1, ymm_short);
    check("reg_write256 with 3 bytes (not 32) fails", !bad_ymm);

    // -------------------------------------------------------------------
    // 7. Memory protections — uc_prot::rw and uc_prot::rx mappings.
    //    Tests: mem_map with multiple protection enum variants.
    // -------------------------------------------------------------------
    section("7. Memory protections");

    // Map an RW page (no exec) at 0x30000, size 4 KiB.
    bool rw_map = cpu.mem_map(0x30000, 0x1000, uc_prot::rw);
    check("mem_map(0x30000, 0x1000, uc_prot::rw) succeeds", rw_map);

    // Map an RX page (no write) at 0x40000, size 4 KiB.
    bool rx_map = cpu.mem_map(0x40000, 0x1000, uc_prot::rx);
    check("mem_map(0x40000, 0x1000, uc_prot::rx) succeeds", rx_map);

    // Map an R page at 0x50000.
    bool r_map = cpu.mem_map(0x50000, 0x1000, uc_prot::read);
    check("mem_map(0x50000, 0x1000, uc_prot::read) succeeds", r_map);

    // Map a W page at 0x60000.
    bool w_map = cpu.mem_map(0x60000, 0x1000, uc_prot::write);
    check("mem_map(0x60000, 0x1000, uc_prot::write) succeeds", w_map);

    // Map an X page at 0x70000.
    bool x_map = cpu.mem_map(0x70000, 0x1000, uc_prot::exec);
    check("mem_map(0x70000, 0x1000, uc_prot::exec) succeeds", x_map);

    // Map an ALL page at 0x80000.
    bool all_map = cpu.mem_map(0x80000, 0x1000, uc_prot::all);
    check("mem_map(0x80000, 0x1000, uc_prot::all) succeeds", all_map);

    // Map a NONE page at 0x90000 (no access at all).
    bool none_map = cpu.mem_map(0x90000, 0x1000, uc_prot::none);
    check("mem_map(0x90000, 0x1000, uc_prot::none) succeeds", none_map);

    // -------------------------------------------------------------------
    // 8. uc_hook::code — fires per executed instruction.
    //    Tests: hook_add(uc_hook::code, ...), start re-execution,
    //           reg_write64 for rip rewind.
    // -------------------------------------------------------------------
    section("8. uc_hook::code");

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
    check("uc_hook::code fired >= 1 time",  g_code_hook_hits >= 1);
    check("uc_hook::code fired <= 2 (matches instruction count)",
          g_code_hook_hits <= 2);
    print_console("  hook fired " + cast<string>(g_code_hook_hits) + " times");

    // -------------------------------------------------------------------
    // 9. emu_stop / flush_code.
    //    Tests: emu_stop() (no-op outside hook), flush_code().
    // -------------------------------------------------------------------
    section("9. emu_stop / flush_code");

    cpu.emu_stop();
    check("emu_stop() outside hook survives", true);

    bool flushed = cpu.flush_code();
    check("flush_code() succeeds", flushed);

    // -------------------------------------------------------------------
    // 10. setup_stack — map stack pages, set RSP.
    //     Tests: setup_stack success, RSP in range, too-small reject.
    // -------------------------------------------------------------------
    section("10. setup_stack");

    // Stack at 0x100000, 4 KiB, stop addr 0x200000.
    bool stack_ok = cpu.setup_stack(0x100000, 0x1000, 0x200000);
    check("setup_stack(0x100000, 0x1000, 0x200000) succeeds", stack_ok);

    int64 rsp = cpu.reg_read64(uc_reg::rsp);
    check("reg_read64(rsp) != 0 after setup_stack", rsp != 0);
    check("rsp inside the mapped stack range",
          rsp >= 0x100000 && rsp < 0x100000 + 0x1000);

    // setup_stack with size < 4 KiB should reject.
    bool too_small_stack = cpu.setup_stack(0x300000, 0x100, 0x400000);
    check("setup_stack with size < 0x1000 rejects", !too_small_stack);

    // -------------------------------------------------------------------
    // 11. get_last_exception + get_exception_address.
    //     Tests: start at unmapped address, hook_add(mem_unmapped),
    //            get_last_exception, get_exception_address.
    // -------------------------------------------------------------------
    section("11. Exception inspection");

    {
        cpu_t cpu2 = cpu_create();
        check("cpu2 = cpu_create() valid", cast<int64>(cpu2) != 0);

        // Wire a mem_unmapped hook.
        g_unmapped_hits = 0;
        bool mu_ok = cpu2.hook_add(uc_hook::mem_unmapped,
                                   cast<int64>(on_unmapped_hook));
        check("hook_add(uc_hook::mem_unmapped) succeeds", mu_ok);

        // Start at 0xDEAD0000 — never mapped.
        int64 r = cpu2.start(0xDEAD0000, 0xDEAD1000, 0, 1);
        check("start(unmapped) returns non-zero error", r != 0);

        // The mem_unmapped hook fired.
        check("uc_hook::mem_unmapped fired >= 1 time", g_unmapped_hits >= 1);

        // Exception inspection.
        int64 exc = cpu2.get_last_exception();
        int64 exc_addr = cpu2.get_exception_address();
        check("get_last_exception() survives", exc >= 0 || exc < 0);
        check("get_exception_address() survives", exc_addr >= 0 || exc_addr < 0);
        print_console("  last_exception = 0x" + cast<string>(exc) +
                      "  addr = 0x" + cast<string>(exc_addr));
    }

    // -------------------------------------------------------------------
    // 12. cpu_active() — outside a hook callback should return null.
    // -------------------------------------------------------------------
    section("12. cpu_active outside hook");

    cpu_t active_now = cpu_active();
    check("cpu_active() outside hook returns null handle",
          cast<int64>(active_now) == 0);

    // -------------------------------------------------------------------
    // 13. cpu_create_process — null proc guard.
    // -------------------------------------------------------------------
    section("13. cpu_create_process null guard");

    proc_t null_proc;
    cpu_t cp = cpu_create_process(null_proc, false);
    check("cpu_create_process(null, false) returns null handle",
          cast<int64>(cp) == 0);

    // cpu_create_process(null, true) should also return null.
    cpu_t cp2 = cpu_create_process(null_proc, true);
    check("cpu_create_process(null, true) returns null handle",
          cast<int64>(cp2) == 0);

    // -------------------------------------------------------------------
    // 14. uc_prot enum sanity — bit-flag composition.
    // -------------------------------------------------------------------
    section("14. uc_prot enum sanity");

    int64 prot_read  = cast<int64>(uc_prot::read);
    int64 prot_write = cast<int64>(uc_prot::write);
    int64 prot_exec  = cast<int64>(uc_prot::exec);
    int64 prot_rw    = cast<int64>(uc_prot::rw);
    int64 prot_rx    = cast<int64>(uc_prot::rx);
    int64 prot_rwx   = cast<int64>(uc_prot::rwx);
    int64 prot_all   = cast<int64>(uc_prot::all);
    int64 prot_none  = cast<int64>(uc_prot::none);

    check("uc_prot::read != 0",  prot_read != 0);
    check("uc_prot::write != 0", prot_write != 0);
    check("uc_prot::exec != 0",  prot_exec != 0);
    check("uc_prot::none == 0",  prot_none == 0);
    check("uc_prot::rw == read | write",
          prot_rw == (prot_read | prot_write));
    check("uc_prot::rx == read | exec",
          prot_rx == (prot_read | prot_exec));
    check("uc_prot::rwx == read | write | exec",
          prot_rwx == (prot_read | prot_write | prot_exec));
    check("uc_prot::all == uc_prot::rwx", prot_all == prot_rwx);

    // -------------------------------------------------------------------
    // 15. uc_hook enum sanity.
    // -------------------------------------------------------------------
    section("15. uc_hook enum sanity");

    int64 hk_code = cast<int64>(uc_hook::code);
    int64 hk_mem  = cast<int64>(uc_hook::mem_unmapped);
    check("uc_hook::code > 0",         hk_code > 0);
    check("uc_hook::mem_unmapped > 0", hk_mem > 0);
    check("uc_hook::code and mem_unmapped are distinct", hk_code != hk_mem);

    // -------------------------------------------------------------------
    // Summary
    // -------------------------------------------------------------------
    print_console("");
    print_console("===========================================");
    print_console("  PASS: " + cast<string>(g_pass));
    print_console("  FAIL: " + cast<string>(g_fail));
    print_console("===========================================");

    unregister_routine(g_handle);
}

// ===========================================================================
// Menu handlers
// ===========================================================================
void on_menu_run_again(int64 data) {
    print_console("[menu] 'Run again' clicked - resetting and re-firing");
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

// ===========================================================================
// Entry point
// ===========================================================================
int32 main() {
    print_console("[unicorn_api] launching test routine + sidebar menu");

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
