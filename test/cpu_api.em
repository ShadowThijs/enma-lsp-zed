// ============================================================================
// cpu_api.em — comprehensive exercise of every CPU API native and built-in
// ============================================================================
//
// Checklist — every function, every overload, every enum covered:
//
// ── CPU identification ───────────────────────────────────────────────────────
//   F  cpu_vendor()                                           -> string
//   F  cpu_brand()                                            -> string
//
// ── Timing ───────────────────────────────────────────────────────────────────
//   F  rdtsc()                                                -> int64
//   F  perf_time()                                            -> int64
//   F  perf_frequency()                                       -> int64
//   F  get_tickcount64()                                      -> int64
//
// ── Datetime helpers ─────────────────────────────────────────────────────────
//   F  now_millisecond()                                      -> int64  (0..999)
//   F  day_name(dow)                                          -> string (0..6)
//   F  month_name(month)                                      -> string (1..12)
//   F  hour12(hour24)                                         -> int64  (0..23 -> 1..12)
//   F  ampm(hour24)                                           -> string (0..23 -> "AM"/"PM")
//
// ── Bitcasts (reinterpret_cast<T>(val)) ──────────────────────────────────────
//   B  reinterpret_cast<uint32>(float32)
//   B  reinterpret_cast<float32>(uint32)
//   B  reinterpret_cast<uint64>(float64)
//   B  reinterpret_cast<float64>(uint64)
//   B  reinterpret_cast<uint32>(int32)   — same-size non-float pair
//   B  reinterpret_cast<int32>(uint32)   — roundtrip across signedness
//
// ── Thread priority ──────────────────────────────────────────────────────────
//   E  thread_priority { lowest, below_normal, normal, above_normal, highest }
//   F  set_thread_priority(thread_priority p)                  -> bool
//
// Legend: F=free function, M=method, T=type, E=enum, B=built-in operator
// ============================================================================

int64 g_pass = 0;
int64 g_fail = 0;
int64 g_skip = 0;

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

// ============================================================================
// 1. CPU identification: cpu_vendor, cpu_brand
// ============================================================================

void test_cpu_identification() {
    section("CPU identification");

    // cpu_vendor — CPUID leaf 0, returns e.g. "GenuineIntel" or "AuthenticAMD"
    string vendor = cpu_vendor();
    check("cpu_vendor returns non-empty string", vendor.length() > 0);
    check("cpu_vendor length is multiple of 4 (CPUID format)",
          vendor.length() > 0 && (vendor.length() % 4) == 0,
          "length = " + cast<string>(vendor.length()));

    // cpu_brand — CPUID leaves 0x80000002..4, e.g. "Intel(R) Core(TM) i9-..."
    // Brands are padded with trailing spaces up to 48 chars; trim non-empty check.
    string brand = cpu_brand();
    check("cpu_brand returns non-empty string", brand.length() > 0);
    print_console("  brand = '" + brand + "'");
}

// ============================================================================
// 2. Timing: rdtsc, perf_time, perf_frequency, get_tickcount64
// ============================================================================

void test_timing() {
    section("Timing");

    // rdtsc — raw cycle counter (not stable across cores or sleep)
    int64 tsc0 = rdtsc();
    int64 tsc1 = rdtsc();
    check("rdtsc returns non-zero", tsc0 != 0 || tsc1 != 0);
    check("rdtsc is monotonic (loose)", tsc1 >= tsc0,
          "t0=" + cast<string>(tsc0) + " t1=" + cast<string>(tsc1));

    // perf_time — QueryPerformanceCounter
    int64 pt0 = perf_time();
    int64 pt1 = perf_time();
    check("perf_time returns non-zero", pt0 != 0);
    check("perf_time is monotonic", pt1 >= pt0);

    // perf_frequency — ticks per second
    int64 freq = perf_frequency();
    check("perf_frequency > 0", freq > 0, "freq=" + cast<string>(freq));
    // Typical QPC frequency is 10 MHz+; a frequency < 1000 would be suspicious.
    // We don't assert a hard lower bound since it varies by hardware, but we
    // verify it looks reasonable.
    print_console("  perf_frequency = " + cast<string>(freq));

    // perf_time / perf_frequency together give sub-microsecond timestamps.
    float64 secs = cast<float64>(pt1 - pt0) / cast<float64>(freq);
    print_console("  elapsed (two consecutive calls) = " + cast<string>(secs) + " s");
    check("perf_time delta >= 0", pt1 - pt0 >= 0);

    // get_tickcount64 — ms since system boot (monotonic, 64-bit safe)
    int64 tc = get_tickcount64();
    check("get_tickcount64 > 0", tc > 0, "tc=" + cast<string>(tc));
    // Subsequent calls should be >= previous (but we can't guarantee for > 0
    // in a tight loop if the timer granularity is coarse; just verify monotonic-ish).
    int64 tc2 = get_tickcount64();
    check("get_tickcount64 is non-decreasing", tc2 >= tc,
          "tc=" + cast<string>(tc) + " tc2=" + cast<string>(tc2));
}

// ============================================================================
// 3. Datetime helpers: now_millisecond, day_name, month_name, hour12, ampm
// ============================================================================

void test_datetime() {
    section("Datetime");

    // now_millisecond — 0..999
    int64 ms = now_millisecond();
    check("now_millisecond in [0, 999]", ms >= 0 && ms <= 999,
          "ms=" + cast<string>(ms));

    // day_name — 0..6 -> "Sunday".."Saturday"
    // Edge: 0 -> Sunday
    check("day_name(0) = 'Sunday'",  day_name(0) == "Sunday",
          "got '" + day_name(0) + "'");
    // Edge: 6 -> Saturday
    check("day_name(6) = 'Saturday'", day_name(6) == "Saturday",
          "got '" + day_name(6) + "'");
    // Mid: 3 -> Wednesday
    check("day_name(3) = 'Wednesday'", day_name(3) == "Wednesday",
          "got '" + day_name(3) + "'");

    // Out of range -> "Unknown"
    check("day_name(-1) = 'Unknown'",  day_name(-1)  == "Unknown", "");
    check("day_name(7) = 'Unknown'",   day_name(7)   == "Unknown", "");
    check("day_name(99) = 'Unknown'",  day_name(99)  == "Unknown", "");

    // month_name — 1..12 -> "January".."December"
    // Edge: 1 -> January
    check("month_name(1) = 'January'",   month_name(1)  == "January",
          "got '" + month_name(1) + "'");
    // Edge: 12 -> December
    check("month_name(12) = 'December'", month_name(12) == "December",
          "got '" + month_name(12) + "'");
    // Mid: 6 -> June
    check("month_name(6) = 'June'",      month_name(6)  == "June",
          "got '" + month_name(6) + "'");
    // Mid: 3 -> March
    check("month_name(3) = 'March'",     month_name(3)  == "March",
          "got '" + month_name(3) + "'");

    // Out of range -> "Unknown"
    check("month_name(0) = 'Unknown'",   month_name(0)  == "Unknown", "");
    check("month_name(13) = 'Unknown'",  month_name(13) == "Unknown", "");
    check("month_name(-5) = 'Unknown'",  month_name(-5) == "Unknown", "");

    // month_name to month_name roundtrip sanity — all 12 months
    check("month_name(2) = 'February'",  month_name(2)  == "February", "");
    check("month_name(4) = 'April'",     month_name(4)  == "April", "");
    check("month_name(5) = 'May'",       month_name(5)  == "May", "");
    check("month_name(7) = 'July'",      month_name(7)  == "July", "");
    check("month_name(8) = 'August'",    month_name(8)  == "August", "");
    check("month_name(9) = 'September'", month_name(9)  == "September", "");
    check("month_name(10) = 'October'",  month_name(10) == "October", "");
    check("month_name(11) = 'November'", month_name(11) == "November", "");

    // hour12 — 0..23 -> 1..12 (12-hour wall format)
    // Midnight: 0 -> 12
    check("hour12(0) = 12",  hour12(0)  == 12, "got " + cast<string>(hour12(0)));
    // Noon: 12 -> 12
    check("hour12(12) = 12", hour12(12) == 12, "got " + cast<string>(hour12(12)));
    // 1 AM: 1 -> 1
    check("hour12(1) = 1",   hour12(1)  == 1,  "got " + cast<string>(hour12(1)));
    // 1 PM: 13 -> 1
    check("hour12(13) = 1",  hour12(13) == 1,  "got " + cast<string>(hour12(13)));
    // 11 PM: 23 -> 11
    check("hour12(23) = 11", hour12(23) == 11, "got " + cast<string>(hour12(23)));
    // 11 AM: 11 -> 11
    check("hour12(11) = 11", hour12(11) == 11, "got " + cast<string>(hour12(11)));
    // 2 AM: 2 -> 2
    check("hour12(2) = 2",   hour12(2)  == 2,  "");
    // 2 PM: 14 -> 2
    check("hour12(14) = 2",  hour12(14) == 2,  "");

    // ampm — 0..23 -> "AM" / "PM"
    // Midnight
    check("ampm(0)  = 'AM'", ampm(0)  == "AM", "");
    // Before noon
    check("ampm(11) = 'AM'", ampm(11) == "AM", "");
    // Noon
    check("ampm(12) = 'PM'", ampm(12) == "PM", "");
    // After noon
    check("ampm(23) = 'PM'", ampm(23) == "PM", "");
    // 1 AM
    check("ampm(1)  = 'AM'", ampm(1)  == "AM", "");
    // 1 PM
    check("ampm(13) = 'PM'", ampm(13) == "PM", "");
    // Edge at boundary
    check("ampm(0)  = 'AM' != 'PM'", ampm(0)  != "PM", "");
    check("ampm(12) = 'PM' != 'AM'", ampm(12) != "AM", "");
}

// ============================================================================
// 4. Bitcasts: reinterpret_cast<T>(val) for same-size pairs
// ============================================================================

void test_bitcasts() {
    section("Bitcasts (reinterpret_cast)");

    // float32 <-> uint32 roundtrip on known bit patterns
    float32 f32_pi = cast<float32>(3.14159265f);
    uint32  u32_bits = reinterpret_cast<uint32>(f32_pi);
    float32 f32_back = reinterpret_cast<float32>(u32_bits);
    check("f32 roundtrip via reinterpret_cast", f32_back == f32_pi,
          "original=" + cast<string>(f32_pi));

    // float64 <-> uint64 roundtrip on known bit patterns
    float64 f64_e = 2.718281828459045;
    uint64  u64_bits = reinterpret_cast<uint64>(f64_e);
    float64 f64_back = reinterpret_cast<float64>(u64_bits);
    check("f64 roundtrip via reinterpret_cast", f64_back == f64_e, "");

    // Known bit pattern: 1.5f is 0x3FC00000 in IEEE 754
    uint32 u_1_5 = reinterpret_cast<uint32>(cast<float32>(1.5f));
    check("reinterpret_cast<uint32>(1.5f) = 0x3FC00000",
          u_1_5 == 0x3FC00000u, "");

    // Roundtrip the other way: 0x3FC00000u -> float32 == 1.5
    float32 f_from_bits = reinterpret_cast<float32>(0x3FC00000u);
    check("reinterpret_cast<float32>(0x3FC00000u) = 1.5",
          approx_eq(cast<float64>(f_from_bits), 1.5, 0.000001),
          "got " + cast<string>(f_from_bits));

    // Extract sign bit from -3.14f via reinterpret_cast<uint32> >> 31
    uint32 sign_bits = reinterpret_cast<uint32>(cast<float32>(-3.14f));
    uint32 sign = sign_bits >> 31;
    check("sign bit of negative float32 is 1",
          sign == 1,
          "sign=" + cast<string>(sign));

    // Positive float has sign bit 0
    uint32 pos_sign_bits = reinterpret_cast<uint32>(cast<float32>(3.14f));
    uint32 pos_sign = pos_sign_bits >> 31;
    check("sign bit of positive float32 is 0",
          pos_sign == 0,
          "sign=" + cast<string>(pos_sign));

    // Zero bit patterns
    check("reinterpret_cast<uint32>(0.0f) = 0",
          reinterpret_cast<uint32>(cast<float32>(0.0f)) == 0, "");
    check("reinterpret_cast<uint64>(0.0) = 0",
          reinterpret_cast<uint64>(0.0) == 0, "");

    // Same-size non-float pairs: int32 <-> uint32 roundtrip
    uint32 u32_val = 0xDEADBEEFu;
    int32  i32_val = reinterpret_cast<int32>(u32_val);
    uint32 u32_back = reinterpret_cast<uint32>(i32_val);
    check("int32 <-> uint32 reinterpret roundtrip",
          u32_back == u32_val, "");

    // Narrow int to wider int: int8 -> uint32 via cast (no reinterpret needed).
    // Enma keeps narrow ints zero/sign-extended in 64-bit slots, so cast is free.
    int8 small = cast<int8>(-1);
    int64 ext = cast<int64>(small);
    check("cast<int64>(int8(-1)) = -1 (sign extension)", ext == -1,
          "got " + cast<string>(ext));

    // uint8 -> uint32 zero-extends
    uint8  u8val = cast<uint8>(0xFF);
    uint64 u64ext = cast<uint64>(u8val);
    check("cast<uint64>(uint8(0xFF)) = 255 (zero extension)", u64ext == 255,
          "got " + cast<string>(u64ext));
}

// ============================================================================
// 5. Thread priority: set_thread_priority with all enum values
// ============================================================================

void test_thread_priority() {
    section("Thread priority");

    // thread_priority enum values — exercise every variant.
    // set_thread_priority adjusts the calling thread. We call all five values
    // in sequence, ending with normal so we leave things clean.

    bool ok_lo = set_thread_priority(thread_priority::lowest);
    check("set_thread_priority(lowest)", ok_lo, "");

    bool ok_bn = set_thread_priority(thread_priority::below_normal);
    check("set_thread_priority(below_normal)", ok_bn, "");

    bool ok_no = set_thread_priority(thread_priority::normal);
    check("set_thread_priority(normal)", ok_no, "");

    bool ok_an = set_thread_priority(thread_priority::above_normal);
    check("set_thread_priority(above_normal)", ok_an, "");

    bool ok_hi = set_thread_priority(thread_priority::highest);
    check("set_thread_priority(highest)", ok_hi, "");

    // Restore to normal for cleanliness.
    bool ok_final = set_thread_priority(thread_priority::normal);
    check("set_thread_priority restores normal", ok_final, "");

    // Verify enum values are distinct via cast to int64.
    int64 e_lo  = cast<int64>(thread_priority::lowest);
    int64 e_bn  = cast<int64>(thread_priority::below_normal);
    int64 e_no  = cast<int64>(thread_priority::normal);
    int64 e_an  = cast<int64>(thread_priority::above_normal);
    int64 e_hi  = cast<int64>(thread_priority::highest);

    check("thread_priority values are distinct",
          e_lo != e_bn && e_bn != e_no && e_no != e_an && e_an != e_hi &&
          e_lo != e_no && e_lo != e_an && e_lo != e_hi &&
          e_bn != e_an && e_bn != e_hi && e_no != e_hi, "");

    // Sanity: normal is typically 0 or some known ordering.
    print_console("  lowest       = " + cast<string>(e_lo));
    print_console("  below_normal = " + cast<string>(e_bn));
    print_console("  normal       = " + cast<string>(e_no));
    print_console("  above_normal = " + cast<string>(e_an));
    print_console("  highest      = " + cast<string>(e_hi));
}

// ============================================================================
// main — run every test group
// ============================================================================

int32 main() {
    print_console("=== cpu_api.em: comprehensive CPU API test ===");

    test_cpu_identification();
    test_timing();
    test_datetime();
    test_bitcasts();
    test_thread_priority();

    // Print summary
    int64 total = g_pass + g_fail + g_skip;
    print_console("");
    print_console("=== summary ===");
    print_console("  total: " + cast<string>(total));
    print_console("  pass:  " + cast<string>(g_pass));
    print_console("  fail:  " + cast<string>(g_fail));
    print_console("  skip:  " + cast<string>(g_skip));
    if (g_fail == 0) {
        print_console("ALL GREEN");
    } else {
        print_console("FAILURES PRESENT — see FAIL lines above");
    }
    return cast<int32>(g_fail == 0 ? 1 : 0);
}
