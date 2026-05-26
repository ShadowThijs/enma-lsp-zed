// =============================================================================
// Atomic addon — comprehensive smoke test
//
// Exercises every type, method, and standalone function from the Atomic API:
//
// TYPES:
//   - atomic_int32(init) -> atomic_int32
//   - atomic_int64(init) -> atomic_int64
//
// METHODS (identical on both widths, 11 each = 22 method calls):
//   load()         -> int64    current value
//   store(int64 v) -> void     set value
//   exchange(int64 v)          returns OLD value
//   compare_exchange(int64 exp, int64 des)   returns bool (true if swapped)
//   add(int64 v)               returns OLD value
//   sub(int64 v)               returns OLD value
//   bit_and(int64 v)           returns OLD value
//   bit_or(int64 v)            returns OLD value
//   bit_xor(int64 v)           returns OLD value
//   inc()                      returns NEW value
//   dec()                      returns NEW value
//
// STANDALONE FUNCTIONS:
//   memory_barrier()           seq_cst fence
//   read_barrier()             acquire fence
//   write_barrier()            release fence
//
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
        g_pass = g_pass + 1;
        print_console("  [PASS] " + label);
    } else {
        g_fail = g_fail + 1;
        print_console("  [FAIL] " + label);
    }
}

void section(string name) {
    print_console("");
    print_console("--- " + name + " ---");
}

void test_routine(int64 data) {
    if (g_done == 1) return;
    g_done = 1;

    print_console("=== Atomic API Tests ===");

    // =========================================================================
    // SECTION: atomic_int32 construction + basic ops
    // =========================================================================
    section("atomic_int32 - construction");

    atomic_int32 a32 = atomic_int32(42);
    check("a32 initial load == 42", a32.load() == 42);

    section("atomic_int32 - store / load");

    a32.store(100);
    check("a32 after store(100), load == 100", a32.load() == 100);

    section("atomic_int32 - exchange");

    int64 old32 = a32.exchange(200);
    check("a32 exchange(200) returns old == 100", old32 == 100);
    check("a32 after exchange, load == 200", a32.load() == 200);

    section("atomic_int32 - compare_exchange (success)");

    bool cas_ok32 = a32.compare_exchange(200, 300);
    check("a32 compare_exchange(200, 300) succeeds", cas_ok32 == true);
    check("a32 after CAS success, load == 300", a32.load() == 300);

    section("atomic_int32 - compare_exchange (failure)");

    bool cas_fail32 = a32.compare_exchange(999, 400);
    check("a32 compare_exchange(999, 400) fails", cas_fail32 == false);
    check("a32 after CAS failure, load still == 300", a32.load() == 300);

    section("atomic_int32 - add / sub (return old)");

    int64 add_old32 = a32.add(50);
    check("a32 add(50) returns old == 300", add_old32 == 300);
    check("a32 after add(50), load == 350", a32.load() == 350);

    int64 sub_old32 = a32.sub(30);
    check("a32 sub(30) returns old == 350", sub_old32 == 350);
    check("a32 after sub(30), load == 320", a32.load() == 320);

    section("atomic_int32 - bit_and / bit_or / bit_xor (return old)");

    a32.store(0xFF);
    int64 and_old32 = a32.bit_and(0xF0);
    check("a32 bit_and(0xF0) returns old == 0xFF", and_old32 == 0xFF);
    check("a32 after bit_and, load == 0xF0", a32.load() == 0xF0);

    a32.store(0x0F);
    int64 or_old32 = a32.bit_or(0xF0);
    check("a32 bit_or(0xF0) returns old == 0x0F", or_old32 == 0x0F);
    check("a32 after bit_or, load == 0xFF", a32.load() == 0xFF);

    a32.store(0xFF);
    int64 xor_old32 = a32.bit_xor(0x0F);
    check("a32 bit_xor(0x0F) returns old == 0xFF", xor_old32 == 0xFF);
    check("a32 after bit_xor, load == 0xF0", a32.load() == 0xF0);

    section("atomic_int32 - inc / dec (return new)");

    a32.store(10);
    int64 inc_val32 = a32.inc();
    check("a32 inc() returns new == 11", inc_val32 == 11);
    check("a32 after inc, load == 11", a32.load() == 11);

    int64 dec_val32 = a32.dec();
    check("a32 dec() returns new == 10", dec_val32 == 10);
    check("a32 after dec, load == 10", a32.load() == 10);

    // =========================================================================
    // SECTION: atomic_int64 construction + basic ops
    // =========================================================================
    section("atomic_int64 - construction");

    atomic_int64 a64 = atomic_int64(-1);
    check("a64 initial load == -1", a64.load() == -1);

    section("atomic_int64 - store / load");

    a64.store(9223372036854775807);
    check("a64 after store(INT64_MAX), load == INT64_MAX", a64.load() == 9223372036854775807);

    section("atomic_int64 - exchange");

    int64 old64 = a64.exchange(100);
    check("a64 exchange(100) returns old == INT64_MAX", old64 == 9223372036854775807);
    check("a64 after exchange, load == 100", a64.load() == 100);

    section("atomic_int64 - compare_exchange (success)");

    bool cas_ok64 = a64.compare_exchange(100, 200);
    check("a64 compare_exchange(100, 200) succeeds", cas_ok64 == true);
    check("a64 after CAS success, load == 200", a64.load() == 200);

    section("atomic_int64 - compare_exchange (failure)");

    bool cas_fail64 = a64.compare_exchange(999, 300);
    check("a64 compare_exchange(999, 300) fails", cas_fail64 == false);
    check("a64 after CAS failure, load still == 200", a64.load() == 200);

    section("atomic_int64 - add / sub (return old)");

    int64 add_old64 = a64.add(25);
    check("a64 add(25) returns old == 200", add_old64 == 200);
    check("a64 after add(25), load == 225", a64.load() == 225);

    int64 sub_old64 = a64.sub(15);
    check("a64 sub(15) returns old == 225", sub_old64 == 225);
    check("a64 after sub(15), load == 210", a64.load() == 210);

    section("atomic_int64 - bit_and / bit_or / bit_xor (return old)");

    a64.store(0xFFFF);
    int64 and_old64 = a64.bit_and(0xFF00);
    check("a64 bit_and(0xFF00) returns old == 0xFFFF", and_old64 == 0xFFFF);
    check("a64 after bit_and, load == 0xFF00", a64.load() == 0xFF00);

    a64.store(0x00FF);
    int64 or_old64 = a64.bit_or(0xFF00);
    check("a64 bit_or(0xFF00) returns old == 0x00FF", or_old64 == 0x00FF);
    check("a64 after bit_or, load == 0xFFFF", a64.load() == 0xFFFF);

    a64.store(0xFFFF);
    int64 xor_old64 = a64.bit_xor(0x00FF);
    check("a64 bit_xor(0x00FF) returns old == 0xFFFF", xor_old64 == 0xFFFF);
    check("a64 after bit_xor, load == 0xFF00", a64.load() == 0xFF00);

    section("atomic_int64 - inc / dec (return new)");

    a64.store(0);
    int64 inc_val64 = a64.inc();
    check("a64 inc() returns new == 1", inc_val64 == 1);
    check("a64 after inc, load == 1", a64.load() == 1);

    int64 dec_val64 = a64.dec();
    check("a64 dec() returns new == 0", dec_val64 == 0);
    check("a64 after dec, load == 0", a64.load() == 0);

    // =========================================================================
    // SECTION: Standalone barrier functions
    // =========================================================================
    section("Standalone barrier functions");

    // memory_barrier: seq_cst fence, no return value, just call it
    memory_barrier();

    // read_barrier: acquire fence
    read_barrier();

    // write_barrier: release fence
    write_barrier();

    // Verify we didn't crash — a store after barriers should still work
    a32.store(1);
    check("a32 load == 1 after barriers", a32.load() == 1);

    // =========================================================================
    // SECTION: Concurrent-style usage (CAS loop pattern from docs)
    // =========================================================================
    section("CAS loop pattern (docs example)");

    atomic_int64 cas_atomic = atomic_int64(10);

    int64 expected = cas_atomic.load();
    bool swapped = cas_atomic.compare_exchange(expected, expected * 2);
    check("CAS loop: compare_exchange(10, 20) succeeds", swapped == true);
    check("CAS loop: load == 20 after CAS", cas_atomic.load() == 20);

    // Failed CAS attempt that retries
    int64 cur = cas_atomic.load();  // 20
    bool second_swap = cas_atomic.compare_exchange(cur, cur * 2);
    check("CAS loop: compare_exchange(20, 40) succeeds", second_swap == true);
    check("CAS loop: load == 40 after second CAS", cas_atomic.load() == 40);

    // =========================================================================
    // SECTION: Counter pattern (docs example approximation)
    // =========================================================================
    section("Counter pattern");

    atomic_int64 counter = atomic_int64(0);

    // Simulate sequential counter work
    int64 ct_old;
    ct_old = counter.add(1);
    check("counter add(1) returns old == 0", ct_old == 0);
    check("counter load == 1", counter.load() == 1);

    ct_old = counter.add(10);
    check("counter add(10) returns old == 1", ct_old == 1);
    check("counter load == 11", counter.load() == 11);

    // =========================================================================
    // SECTION: Scope drop / re-creation
    // =========================================================================
    section("Multiple atomic_int32 instances");

    atomic_int32 alpha = atomic_int32(1);
    atomic_int32 beta  = atomic_int32(2);
    atomic_int32 gamma = atomic_int32(3);

    alpha.store(10);
    beta.store(20);
    gamma.store(30);

    check("multi a32: alpha == 10", alpha.load() == 10);
    check("multi a32: beta  == 20", beta.load() == 20);
    check("multi a32: gamma == 30", gamma.load() == 30);

    section("Multiple atomic_int64 instances");

    atomic_int64 x = atomic_int64(100);
    atomic_int64 y = atomic_int64(200);
    atomic_int64 z = atomic_int64(300);

    check("multi a64: x == 100", x.load() == 100);
    check("multi a64: y == 200", y.load() == 200);
    check("multi a64: z == 300", z.load() == 300);

    // Cross-talk test: modify one, check others unchanged
    x.store(999);
    check("multi a64: x == 999 after store", x.load() == 999);
    check("multi a64: y unchanged == 200", y.load() == 200);
    check("multi a64: z unchanged == 300", z.load() == 300);

    // =========================================================================
    // SECTION: Store-zero / load boundary
    // =========================================================================
    section("Edge cases: zero, negative, wrapping");

    atomic_int64 edge = atomic_int64(0);
    check("edge initial load == 0", edge.load() == 0);

    // store and load negative
    edge.store(-1);
    check("edge after store(-1), load == -1", edge.load() == -1);

    // exchange with zero
    int64 edge_old = edge.exchange(0);
    check("edge exchange(0) returns old == -1", edge_old == -1);
    check("edge after exchange, load == 0", edge.load() == 0);

    // inc from 0
    check("edge inc() == 1", edge.inc() == 1);
    // dec back to 0
    check("edge dec() == 0", edge.dec() == 0);

    // =========================================================================
    // Summary
    // =========================================================================
    print_console("");
    print_console("===========================================");
    print_console("  PASS: " + cast<string>(g_pass));
    print_console("  FAIL: " + cast<string>(g_fail));
    print_console("===========================================");

    unregister_routine(g_handle);
}

void on_menu_run_again(int64 data) {
    print_console("[menu] 'Run again' clicked - resetting + re-firing routine");
    g_done = 0;
    g_pass = 0;
    g_fail = 0;
}

void on_menu_log_summary(int64 data) {
    print_console("[menu] summary so far: PASS=" + cast<string>(g_pass) +
                  "  FAIL=" + cast<string>(g_fail));
}

int32 main() {
    print_console("[test_atomic] launching test routine + sidebar menu");

    g_section = create_sidebar_section("Atomic test", "");
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
