// =============================================================================
// CPU API smoke test
//
// Exercises every native registered by enma_cpu_api.cpp:
//   - cpu_vendor / cpu_brand
//   - rdtsc / perf_time / perf_frequency / get_tickcount64
//   - now_millisecond / day_name / month_name / hour12 / ampm
//   - reinterpret_cast<uint32/float32/uint64/float64> for bit-pattern conversions
//   - set_thread_priority(thread_priority)
//
// Single-shot routine launched from main(); main returns 1 to keep the script
// loaded so the routine can fire on its own thread. Sidebar section + menu
// for hot-reload exercising of GUI cleanup paths.
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

    print_console("=== cpu API smoke test ===");

    // -----------------------------------------------------------------------
    // CPU identification
    // -----------------------------------------------------------------------
    section("cpu identification");

    string vendor = cpu_vendor();
    check("cpu_vendor() length() in 0..32", vendor.length() > 0 && vendor.length() < 32);
    print_console("  vendor = '" + vendor + "'");

    string brand = cpu_brand();
    check("cpu_brand() length() > 0", brand.length() > 0);
    check("cpu_brand() length() <= 48", brand.length() <= 48);
    print_console("  brand = '" + brand + "'");

    // -----------------------------------------------------------------------
    // Timing
    // -----------------------------------------------------------------------
    section("timing");

    int64 c0 = rdtsc();
    int64 c1 = rdtsc();
    check("rdtsc() returns non-zero", c0 != 0);
    check("rdtsc() second sample >= first (monotonic on same core)", c1 >= c0);

    int64 t0 = perf_time();
    int64 t1 = perf_time();
    check("perf_time() returns non-zero", t0 != 0);
    check("perf_time() second sample >= first", t1 >= t0);

    int64 freq = perf_frequency();
    check("perf_frequency() > 0", freq > 0);
    check("perf_frequency() typically >= 1_000_000 (1 MHz)", freq >= 1000000);

    int64 tick = get_tickcount64();
    int64 tick2 = get_tickcount64();
    check("get_tickcount64() > 0", tick > 0);
    check("get_tickcount64() second sample >= first", tick2 >= tick);

    // -----------------------------------------------------------------------
    // Datetime helpers
    // -----------------------------------------------------------------------
    section("datetime helpers");

    int64 ms = now_millisecond();
    check("now_millisecond() in 0..999", ms >= 0 && ms < 1000);

    string sun = day_name(0);
    string sat = day_name(6);
    string bogus_day = day_name(7);
    string neg_day = day_name(-1);
    check("day_name(0) == 'Sunday'", sun == "Sunday");
    check("day_name(6) == 'Saturday'", sat == "Saturday");
    check("day_name(7) == 'Unknown'", bogus_day == "Unknown");
    check("day_name(-1) == 'Unknown'", neg_day == "Unknown");

    string jan = month_name(1);
    string dec = month_name(12);
    string bogus_mo = month_name(0);
    string bogus_mo2 = month_name(13);
    check("month_name(1) == 'January'", jan == "January");
    check("month_name(12) == 'December'", dec == "December");
    check("month_name(0) == 'Unknown'", bogus_mo == "Unknown");
    check("month_name(13) == 'Unknown'", bogus_mo2 == "Unknown");

    check("hour12(0) == 12 (midnight)",  hour12(0)  == 12);
    check("hour12(1) == 1",               hour12(1)  == 1);
    check("hour12(11) == 11",             hour12(11) == 11);
    check("hour12(12) == 12 (noon)",      hour12(12) == 12);
    check("hour12(13) == 1 (1 PM)",       hour12(13) == 1);
    check("hour12(23) == 11 (11 PM)",     hour12(23) == 11);

    check("ampm(0)  == 'AM'",  ampm(0)  == "AM");
    check("ampm(11) == 'AM'",  ampm(11) == "AM");
    check("ampm(12) == 'PM'",  ampm(12) == "PM");
    check("ampm(23) == 'PM'",  ampm(23) == "PM");

    // -----------------------------------------------------------------------
    // Bitcasts — round-trip + known IEEE-754 values
    // -----------------------------------------------------------------------
    section("bitcasts (float<->int) via reinterpret_cast<>");

    // 1.0f IEEE-754 = 0x3F800000
    uint32 one_f32_bits = reinterpret_cast<uint32>(1.0f);
    check("reinterpret_cast<uint32>(1.0f) == 0x3F800000", one_f32_bits == 0x3F800000);

    float32 round_f32 = reinterpret_cast<float32>(0x3F800000);
    check("reinterpret_cast<float32>(0x3F800000) == 1.0f", round_f32 == 1.0f);

    // -0.0f = 0x80000000. We round-trip via the API itself rather than
    // writing -0.0f as a literal: enma's parser folds `-0.0f` to plain 0.0f,
    // so the literal path tests the parser, not the bitcast. This path is
    // a clean test of the cast: int -> float -> int round-trip preserves the
    // sign bit.
    float32 neg_zero      = reinterpret_cast<float32>(0x80000000);
    uint32  neg_zero_bits = reinterpret_cast<uint32>(neg_zero);
    check("0x80000000 -> f32 -> u32 round-trips (-0.0f sign bit preserved)",
          neg_zero_bits == 0x80000000);

    // 1.0 (double) IEEE-754 = 0x3FF0000000000000
    uint64 one_f64_bits = reinterpret_cast<uint64>(1.0);
    check("reinterpret_cast<uint64>(1.0) == 0x3FF0000000000000", one_f64_bits == 0x3FF0000000000000);

    float64 round_f64 = reinterpret_cast<float64>(0x3FF0000000000000);
    check("reinterpret_cast<float64>(0x3FF0000000000000) == 1.0", round_f64 == 1.0);

    // Round-trip through f32 → u32 → f32 preserves the bit pattern of a
    // representable value. 3.14159 is not exactly representable, but the
    // round-trip is exact at the bit level.
    float32 pi32      = 3.14159f;
    uint32  pi32_bits = reinterpret_cast<uint32>(pi32);
    float32 pi32_back = reinterpret_cast<float32>(pi32_bits);
    check("f32 round-trip preserves bits", reinterpret_cast<uint32>(pi32_back) == pi32_bits);

    float64 e64      = 2.718281828459045;
    uint64  e64_bits = reinterpret_cast<uint64>(e64);
    float64 e64_back = reinterpret_cast<float64>(e64_bits);
    check("f64 round-trip preserves bits", reinterpret_cast<uint64>(e64_back) == e64_bits);

    // -----------------------------------------------------------------------
    // Thread priority — exercise every enum value; assert SetThreadPriority
    // accepted each. We don't try to read priority back since that requires
    // GetThreadPriority which isn't exposed.
    // -----------------------------------------------------------------------
    section("thread priority");

    bool ok_norm = set_thread_priority(thread_priority::normal);
    check("set_thread_priority(normal) succeeds", ok_norm);

    bool ok_low = set_thread_priority(thread_priority::below_normal);
    check("set_thread_priority(below_normal) succeeds", ok_low);

    bool ok_high = set_thread_priority(thread_priority::above_normal);
    check("set_thread_priority(above_normal) succeeds", ok_high);

    bool ok_lowest = set_thread_priority(thread_priority::lowest);
    check("set_thread_priority(lowest) succeeds", ok_lowest);

    bool ok_highest = set_thread_priority(thread_priority::highest);
    check("set_thread_priority(highest) succeeds", ok_highest);

    // Restore to normal so we don't leave the routine thread on highest.
    set_thread_priority(thread_priority::normal);

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
    print_console("[test_cpu_api] launching test routine + sidebar menu");

    g_section = create_sidebar_section("cpu test", "");
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
