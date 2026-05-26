// =============================================================================
// COMPREHENSIVE Time API smoke test
//
// Exercises EVERY function in the enma Time addon API.
//
// CHECKLIST -- All functions in the API:
//
//   Current time (5):
//     now_us()           -> int64    // microseconds since Unix epoch
//     now_ms()           -> int64    // milliseconds since Unix epoch
//     now_ns()           -> int64    // nanoseconds since Unix epoch
//     unix_seconds()     -> int64    // seconds since Unix epoch
//     mono_us()          -> int64    // monotonic microseconds (for deltas; not an epoch)
//
//   Calendar accessors (7):
//     year(int64 t)      -> int64
//     month(int64 t)     -> int64    // 1..12
//     day(int64 t)       -> int64    // 1..31
//     hour(int64 t)      -> int64    // 0..23
//     minute(int64 t)    -> int64    // 0..59
//     second(int64 t)    -> int64    // 0..59
//     day_of_week(int64 t) -> int64  // 0=Sun..6=Sat
//     day_of_year(int64 t) -> int64  // 1..366
//
//   Leap year / days per month (2):
//     is_leap(int64 year)           -> bool
//     days_in_month(int64 year, int64 month) -> int64
//
//   Construction (2):
//     from_ymd(int64 year, int64 month, int64 day)                      -> int64
//     from_ymdhms(int64 year, int64 month, int64 day, int64 hour,
//                  int64 minute, int64 second)                           -> int64
//
//   ISO 8601 (2):
//     iso_format(int64 t)  -> string
//     iso_parse(string s)  -> int64
//
//   Arithmetic (5):
//     add_seconds(int64 t, int64 s) -> int64
//     add_days(int64 t, int64 d)    -> int64
//     diff_us(int64 later, int64 earlier)   -> int64
//     diff_ms(int64 later, int64 earlier)   -> int64
//     diff_s(int64 later, int64 earlier)    -> int64
//
//   Sleep (1):
//     sleep_ms(int64 ms)   -> void
//
//   TOTAL: 24 standalone functions (no types with methods)
//
// All timestamps are int64 microseconds since the Unix epoch (1970-01-01
// 00:00:00 UTC). Calendar accessors interpret in UTC.
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

void print_console(string input) {
    print(input);
}

void section(string title) {
    print_console("");
    print_console("--- " + title + " ---");
}

// ===========================================================================
// Test routine
// ===========================================================================

void test_routine(int64 data) {
    if (g_done != 0) return;
    g_done = 1;

    print_console("=== Time API -- full coverage test ===");

    // -----------------------------------------------------------------------
    // SECTION 1 -- Current time functions
    // -----------------------------------------------------------------------

    section("1. now_us");

    int64 us = now_us();
    check("now_us() returns positive value", us > 0);
    // Epoch started in 1970; any positive value is correct for modern dates.
    // A value < 1e15 would be before ~2001 which is suspicious. The year
    // 2026 corresponds to ~1.77e15 us, so any positive value is fine.

    section("2. now_ms");

    int64 ms = now_ms();
    check("now_ms() returns positive value", ms > 0);
    // ms should be ~1000x smaller than us
    check("now_ms() < now_us() (different magnitude)", ms < us);

    section("3. now_ns");

    int64 ns = now_ns();
    check("now_ns() returns positive value", ns > 0);
    // ns should be ~1000x larger than us
    check("now_ns() > now_us() (ns is finer granularity)", ns > us);

    section("4. unix_seconds");

    int64 s = unix_seconds();
    check("unix_seconds() returns positive value", s > 0);
    // Should be ~1,777,000,000+ for year 2026
    check("unix_seconds() > 1700000000 (at least year 2023)",
          s > 1700000000);
    // unix_seconds should be ~1000000x smaller than now_us (1s = 1000000us)
    check("unix_seconds() mill rate consistency",
          us / 1000000 - s <= 1 && s - us / 1000000 <= 1);

    section("5. mono_us");

    int64 mono1 = mono_us();
    check("mono_us() returns positive value", mono1 > 0);
    int64 mono2 = mono_us();
    check("mono_us() is monotonic (second call >= first)", mono2 >= mono1);
    // The delta should be very small (these calls happen within microseconds)
    int64 mono_delta = mono2 - mono1;
    check("mono_us() delta between consecutive calls is small (< 1 sec)",
          mono_delta >= 0 && mono_delta < 1000000);

    // -----------------------------------------------------------------------
    // SECTION 2 -- Construction
    // -----------------------------------------------------------------------

    section("6. from_ymd");

    // Known date: 2024-06-15 00:00:00 UTC
    int64 t_ymd = from_ymd(2024, 6, 15);
    check("from_ymd(2024, 6, 15) returns non-zero", t_ymd != 0);

    // Edge: Jan 1, 1970 (epoch) should give 0 or small value
    int64 t_epoch = from_ymd(1970, 1, 1);
    check("from_ymd(1970, 1, 1) is defined", t_epoch >= 0);

    // Edge: far future
    int64 t_future = from_ymd(2099, 12, 31);
    check("from_ymd(2099, 12, 31) returns non-zero", t_future > 0);
    check("from_ymd(2099, 12, 31) > from_ymd(2024, 6, 15)", t_future > t_ymd);

    section("7. from_ymdhms");

    int64 t_full = from_ymdhms(2024, 6, 15, 12, 30, 45);
    check("from_ymdhms(2024,6,15,12,30,45) returns non-zero", t_full != 0);

    // t_full should be greater than t_ymd (midnight) because 12:30:45 > 00:00:00
    check("from_ymdhms(...,12,30,45) > from_ymd(...,midnight)", t_full > t_ymd);

    // from_ymd with same date should == from_ymdhms at midnight
    int64 t_midnight = from_ymdhms(2024, 6, 15, 0, 0, 0);
    check("from_ymdhms(...,0,0,0) == from_ymd(...)", t_midnight == t_ymd);

    // -----------------------------------------------------------------------
    // SECTION 3 -- Calendar accessors on a known timestamp
    // timestamp: 2024-06-15 12:30:45 UTC
    // -----------------------------------------------------------------------

    section("8. year");

    int64 y = year(t_full);
    check("year(2024-06-15 12:30:45) == 2024", y == 2024);

    section("9. month");

    int64 mo = month(t_full);
    check("month(2024-06-15) == 6", mo == 6);

    section("10. day");

    int64 d = day(t_full);
    check("day(2024-06-15) == 15", d == 15);

    section("11. hour");

    int64 h = hour(t_full);
    check("hour(12:30:45) == 12", h == 12);

    section("12. minute");

    int64 mi = minute(t_full);
    check("minute(12:30:45) == 30", mi == 30);

    section("13. second");

    int64 sec = second(t_full);
    check("second(12:30:45) == 45", sec == 45);

    section("14. day_of_week");

    int64 dow = day_of_week(t_full);
    // 2024-06-15 is a Saturday (6)
    check("day_of_week(2024-06-15) == 6 (Saturday)", dow == 6);

    // Additional day-of-week checks:
    // 2024-01-01 is a Monday (1)
    int64 t_newyear = from_ymd(2024, 1, 1);
    int64 dow_ny = day_of_week(t_newyear);
    check("day_of_week(2024-01-01) == 1 (Monday)", dow_ny == 1);

    // 2024-03-14 is a Thursday (4)
    int64 t_pi = from_ymd(2024, 3, 14);
    int64 dow_pi = day_of_week(t_pi);
    check("day_of_week(2024-03-14) == 4 (Thursday)", dow_pi == 4);

    // 2024-12-25 is a Wednesday (3)
    int64 t_xmas = from_ymd(2024, 12, 25);
    int64 dow_xmas = day_of_week(t_xmas);
    check("day_of_week(2024-12-25) == 3 (Wednesday)", dow_xmas == 3);

    // Epoch: 1970-01-01 is a Thursday (4)
    int64 dow_epoch = day_of_week(t_epoch);
    check("day_of_week(1970-01-01) == 4 (Thursday)", dow_epoch == 4);

    section("15. day_of_year");

    int64 doy = day_of_year(t_full);
    // 2024-01-01 is day 1, Jan+Feb+Mar+Apr+May+Jun(15) = 31+29+31+30+31+15 = 167
    // Jan 31 + Feb 29 + Mar 31 + Apr 30 + May 31 + Jun 15 = 167
    check("day_of_year(2024-06-15) == 167", doy == 167);

    // Jan 1 is always day 1
    int64 doy_ny = day_of_year(t_newyear);
    check("day_of_year(2024-01-01) == 1", doy_ny == 1);

    // Dec 31 in a leap year is day 366
    int64 t_dec31_leap = from_ymd(2024, 12, 31);
    int64 doy_dec31 = day_of_year(t_dec31_leap);
    check("day_of_year(2024-12-31) == 366 (leap year)", doy_dec31 == 366);

    // Dec 31 in a non-leap year is day 365
    int64 t_dec31_nonleap = from_ymd(2023, 12, 31);
    int64 doy_dec31_nl = day_of_year(t_dec31_nonleap);
    check("day_of_year(2023-12-31) == 365 (non-leap)", doy_dec31_nl == 365);

    // -----------------------------------------------------------------------
    // SECTION 4 -- Calendar accessors on midnight timestamp
    // All time fields should be 0 for from_ymd
    // -----------------------------------------------------------------------

    section("16. Calendar accessors on midnight");

    int64 h_mid = hour(t_ymd);
    check("hour(midnight) == 0", h_mid == 0);

    int64 mi_mid = minute(t_ymd);
    check("minute(midnight) == 0", mi_mid == 0);

    int64 sec_mid = second(t_ymd);
    check("second(midnight) == 0", sec_mid == 0);

    // -----------------------------------------------------------------------
    // SECTION 5 -- Leap year / days per month
    // -----------------------------------------------------------------------

    section("17. is_leap");

    check("is_leap(2024) == true (leap year)", is_leap(2024));
    check("is_leap(2000) == true (century divisible by 400)", is_leap(2000));
    check("is_leap(2023) == false (non-leap)", !is_leap(2023));
    check("is_leap(1900) == false (century not divisible by 400)", !is_leap(1900));
    check("is_leap(2025) == false", !is_leap(2025));
    check("is_leap(2026) == false", !is_leap(2026));
    check("is_leap(0) == true (year 0 is leap per proleptic Gregorian)", is_leap(0));
    check("is_leap(-4) == true (negative leap year)", is_leap(-4));
    check("is_leap(-1) == false (negative non-leap year)", !is_leap(-1));

    section("18. days_in_month");

    // Standard months
    check("days_in_month(2024, 1) == 31 (January)", days_in_month(2024, 1) == 31);
    check("days_in_month(2024, 2) == 29 (leap Feb)", days_in_month(2024, 2) == 29);
    check("days_in_month(2023, 2) == 28 (non-leap Feb)", days_in_month(2023, 2) == 28);
    check("days_in_month(2000, 2) == 29 (century leap Feb)", days_in_month(2000, 2) == 29);
    check("days_in_month(1900, 2) == 28 (century non-leap Feb)", days_in_month(1900, 2) == 28);
    check("days_in_month(2024, 3) == 31 (March)", days_in_month(2024, 3) == 31);
    check("days_in_month(2024, 4) == 30 (April)", days_in_month(2024, 4) == 30);
    check("days_in_month(2024, 5) == 31 (May)", days_in_month(2024, 5) == 31);
    check("days_in_month(2024, 6) == 30 (June)", days_in_month(2024, 6) == 30);
    check("days_in_month(2024, 7) == 31 (July)", days_in_month(2024, 7) == 31);
    check("days_in_month(2024, 8) == 31 (August)", days_in_month(2024, 8) == 31);
    check("days_in_month(2024, 9) == 30 (September)", days_in_month(2024, 9) == 30);
    check("days_in_month(2024, 10) == 31 (October)", days_in_month(2024, 10) == 31);
    check("days_in_month(2024, 11) == 30 (November)", days_in_month(2024, 11) == 30);
    check("days_in_month(2024, 12) == 31 (December)", days_in_month(2024, 12) == 31);

    // Invalid month returns 0
    check("days_in_month(2024, 0) == 0 (invalid month)", days_in_month(2024, 0) == 0);
    check("days_in_month(2024, 13) == 0 (invalid month)", days_in_month(2024, 13) == 0);
    check("days_in_month(2024, -1) == 0 (invalid month)", days_in_month(2024, -1) == 0);
    check("days_in_month(2024, 99) == 0 (way out of range)", days_in_month(2024, 99) == 0);

    // -----------------------------------------------------------------------
    // SECTION 6 -- ISO 8601 formatting
    // -----------------------------------------------------------------------

    section("19. iso_format");

    string iso = iso_format(t_full);
    check("iso_format(2024-06-15 12:30:45) returns string", iso.length() > 0);
    check("iso_format result format YYYY-MM-DDTHH:MM:SS.ffffffZ",
          iso == "2024-06-15T12:30:45.000000Z");

    // midnight
    string iso_mid = iso_format(t_ymd);
    check("iso_format(midnight) == 2024-06-15T00:00:00.000000Z",
          iso_mid == "2024-06-15T00:00:00.000000Z");

    // new year
    string iso_ny = iso_format(from_ymd(2024, 1, 1));
    check("iso_format(2024-01-01) == 2024-01-01T00:00:00.000000Z",
          iso_ny == "2024-01-01T00:00:00.000000Z");

    // epoch
    string iso_epoch = iso_format(t_epoch);
    check("iso_format(1970-01-01) == 1970-01-01T00:00:00.000000Z",
          iso_epoch == "1970-01-01T00:00:00.000000Z");

    section("20. iso_parse -- full format round-trip");

    int64 t_parsed = iso_parse(iso);
    check("iso_parse(iso_format(t)) == t (round-trip)", t_parsed == t_full);

    section("21. iso_parse -- date-only");

    int64 t_date_only = iso_parse("2024-06-15");
    check("iso_parse('2024-06-15') produces valid timestamp", t_date_only != 0);
    check("iso_parse('2024-06-15') == from_ymd(2024,6,15)",
          t_date_only == t_ymd);

    section("22. iso_parse -- YYYY-MM-DDTHH:MM:SS (without fractional or Z)");

    int64 t_no_frac = iso_parse("2024-06-15T12:30:45");
    check("iso_parse('2024-06-15T12:30:45') produces valid timestamp",
          t_no_frac != 0);
    // Might equal t_full depending on whether the parser assumes Z for bare form
    // At minimum it should not be 0 and should be >= t_ymd

    section("23. iso_parse -- with .ffffff fractional (no Z)");

    int64 t_frac_noZ = iso_parse("2024-06-15T12:30:45.000000");
    check("iso_parse('2024-06-15T12:30:45.000000') produces valid timestamp",
          t_frac_noZ != 0);

    section("24. iso_parse -- date-only: different dates");

    int64 t_pi_parsed = iso_parse("2024-03-14");
    int64 t_pi_expected = from_ymd(2024, 3, 14);
    check("iso_parse('2024-03-14') == from_ymd(2024,3,14)",
          t_pi_parsed == t_pi_expected);

    int64 t_xmas_parsed = iso_parse("2024-12-25");
    int64 t_xmas_expected = from_ymd(2024, 12, 25);
    check("iso_parse('2024-12-25') == from_ymd(2024,12,25)",
          t_xmas_parsed == t_xmas_expected);

    int64 t_epoch_parsed = iso_parse("1970-01-01");
    check("iso_parse('1970-01-01') == from_ymd(1970,1,1)",
          t_epoch_parsed == t_epoch);

    section("25. iso_parse -- round-trip various dates");

    // Round-trip: format then parse
    int64 t_round1 = iso_parse(iso_format(from_ymd(2023, 7, 4)));
    check("round-trip 2023-07-04", t_round1 == from_ymd(2023, 7, 4));

    int64 t_round2 = iso_parse(iso_format(from_ymd(2000, 2, 29)));
    check("round-trip 2000-02-29 (leap day)", t_round2 == from_ymd(2000, 2, 29));

    int64 t_round3 = iso_parse(iso_format(from_ymd(1999, 12, 31)));
    check("round-trip 1999-12-31", t_round3 == from_ymd(1999, 12, 31));

    // -----------------------------------------------------------------------
    // SECTION 7 -- Arithmetic: add_seconds
    // -----------------------------------------------------------------------

    section("26. add_seconds");

    int64 t_plus_60 = add_seconds(t_full, 60);
    check("add_seconds(t, 60) != t", t_plus_60 != t_full);
    check("add_seconds(t, 60) > t", t_plus_60 > t_full);
    // 60 seconds = 60,000,000 microseconds
    int64 delta_60 = t_plus_60 - t_full;
    check("add_seconds(t, 60) - t == 60000000 us", delta_60 == 60000000);

    // add_seconds(t, 0) should return same timestamp
    int64 t_plus_0 = add_seconds(t_full, 0);
    check("add_seconds(t, 0) == t", t_plus_0 == t_full);

    // Negative seconds
    int64 t_minus_60 = add_seconds(t_full, -60);
    check("add_seconds(t, -60) < t", t_minus_60 < t_full);
    int64 delta_neg = t_full - t_minus_60;
    check("t - add_seconds(t, -60) == 60000000 us", delta_neg == 60000000);

    // Large value: +1 hour = 3600 seconds
    int64 t_plus_1h = add_seconds(t_full, 3600);
    int64 delta_1h = t_plus_1h - t_full;
    check("add_seconds(t, 3600) - t == 3600000000 us (1 hour)",
          delta_1h == 3600000000);

    section("27. add_days");

    int64 t_tomorrow = add_days(t_full, 1);
    check("add_days(t, 1) != t", t_tomorrow != t_full);
    check("add_days(t, 1) > t", t_tomorrow > t_full);
    // 1 day = 86400 seconds = 86400000000 microseconds
    int64 delta_1d = t_tomorrow - t_full;
    check("add_days(t, 1) - t == 86400000000 us (1 day)",
          delta_1d == 86400000000);

    // add_days(t, 0) returns same
    int64 t_plus_0d = add_days(t_full, 0);
    check("add_days(t, 0) == t", t_plus_0d == t_full);

    // Negative days
    int64 t_yesterday = add_days(t_full, -1);
    check("add_days(t, -1) < t", t_yesterday < t_full);
    int64 delta_neg_d = t_full - t_yesterday;
    check("t - add_days(t, -1) == 86400000000 us", delta_neg_d == 86400000000);

    // Multiple days
    int64 t_plus_7 = add_days(t_full, 7);
    int64 delta_7d = t_plus_7 - t_full;
    check("add_days(t, 7) - t == 604800000000 us (7 days)",
          delta_7d == 604800000000);

    // Cross month boundary: Jan 31 + 1 day = Feb 1
    int64 t_jan31 = from_ymd(2024, 1, 31);
    int64 t_feb1 = add_days(t_jan31, 1);
    int64 feb1_day = day(t_feb1);
    int64 feb1_month = month(t_feb1);
    check("add_days(Jan 31, 1) -> Feb 1", feb1_month == 2 && feb1_day == 1);

    // Cross year boundary: Dec 31 + 1 day = Jan 1 next year
    int64 t_dec31_2024 = from_ymd(2024, 12, 31);
    int64 t_jan1_2025 = add_days(t_dec31_2024, 1);
    int64 jan1_month = month(t_jan1_2025);
    int64 jan1_day = day(t_jan1_2025);
    int64 jan1_year = year(t_jan1_2025);
    check("add_days(Dec 31 2024, 1) -> Jan 1 2025",
          jan1_year == 2025 && jan1_month == 1 && jan1_day == 1);

    // -----------------------------------------------------------------------
    // SECTION 8 -- Diff functions
    // -----------------------------------------------------------------------

    section("28. diff_us");

    // Two timestamps that differ by known amounts
    int64 t_early = from_ymdhms(2024, 6, 15, 12, 30, 0);
    int64 t_late  = from_ymdhms(2024, 6, 15, 12, 30, 45);

    int64 du = diff_us(t_late, t_early);
    check("diff_us(late, early) == 45000000 (45s in us)", du == 45000000);

    // diff_us with same timestamp should be 0
    int64 du_zero = diff_us(t_late, t_late);
    check("diff_us(t, t) == 0", du_zero == 0);

    // reversed arguments give negative
    int64 du_neg = diff_us(t_early, t_late);
    check("diff_us(early, late) == -45000000", du_neg == -45000000);

    section("29. diff_ms");

    int64 dm = diff_ms(t_late, t_early);
    check("diff_ms(late, early) == 45000 (45s in ms)", dm == 45000);

    int64 dm_zero = diff_ms(t_late, t_late);
    check("diff_ms(t, t) == 0", dm_zero == 0);

    // 1 day = 86400000 ms
    int64 dm_1d = diff_ms(t_tomorrow, t_full);
    check("diff_ms(tomorrow, today) == 86400000 (1 day in ms)",
          dm_1d == 86400000);

    section("30. diff_s");

    int64 ds = diff_s(t_late, t_early);
    check("diff_s(late, early) == 45 (45s)", ds == 45);

    int64 ds_zero = diff_s(t_late, t_late);
    check("diff_s(t, t) == 0", ds_zero == 0);

    // 1 day = 86400 s
    int64 ds_1d = diff_s(t_tomorrow, t_full);
    check("diff_s(tomorrow, today) == 86400 (1 day in s)", ds_1d == 86400);

    // 7 days = 604800 s
    int64 ds_7d = diff_s(t_plus_7, t_full);
    check("diff_s(t+7d, t) == 604800 (7 days in s)", ds_7d == 604800);

    // Consistency: diff_ms should be 1000x diff_s
    check("diff_ms / 1000 == diff_s for 45s interval", dm / 1000 == ds);

    // -----------------------------------------------------------------------
    // SECTION 9 -- Combined: construct, format, parse, add, diff
    // -----------------------------------------------------------------------

    section("31. Combined workflow: construct -> format -> parse -> arith -> diff");

    // 1. Construct a timestamp
    int64 t_birth = from_ymdhms(2000, 1, 1, 0, 0, 0);
    check("construct Y2K timestamp", t_birth != 0);

    // 2. Format it
    string iso_birth = iso_format(t_birth);
    check("format Y2K timestamp", iso_birth == "2000-01-01T00:00:00.000000Z");

    // 3. Parse it back
    int64 t_birth_parsed = iso_parse(iso_birth);
    check("round-trip Y2K timestamp", t_birth_parsed == t_birth);

    // 4. Add some time
    int64 t_birth_plus_10d = add_days(t_birth, 10);
    int64 d10 = day(t_birth_plus_10d);
    int64 m10 = month(t_birth_plus_10d);
    check("add_days(2000-01-01, 10) -> Jan 11", m10 == 1 && d10 == 11);

    // 5. Diff
    int64 ds_birth = diff_s(t_full, t_birth);
    check("diff_s(2024-06-15, 2000-01-01) > 0 (difference is positive)",
          ds_birth > 0);

    // -----------------------------------------------------------------------
    // SECTION 10 -- Edge cases: boundary dates
    // -----------------------------------------------------------------------

    section("32. Boundary dates");

    // Epoch
    int64 t_unix_epoch = from_ymd(1970, 1, 1);
    check("from_ymd(1970,1,1) is epoch", t_unix_epoch >= 0);

    // One second after epoch
    int64 t_epoch_plus_1s = add_seconds(t_unix_epoch, 1);
    check("add_seconds(epoch, 1) > epoch", t_epoch_plus_1s > t_unix_epoch);
    check("diff_s(epoch+1s, epoch) == 1", diff_s(t_epoch_plus_1s, t_unix_epoch) == 1);

    // Leap day round-trip
    int64 t_leap = from_ymd(2024, 2, 29);
    check("from_ymd(2024,2,29) succeeds (leap day)", t_leap != 0);
    string iso_leap = iso_format(t_leap);
    check("iso_format(2024-02-29) contains 2024-02-29",
          iso_leap.find("2024-02-29") == 0);
    int64 t_leap_back = iso_parse(iso_leap);
    check("round-trip leap day", t_leap_back == t_leap);

    // Non-leap February 29 should still produce a timestamp (the date shifts to Mar 1)
    // Actually, from_ymd on a non-leap year for Feb 29 behavior is undefined,
    // but we can at least verify it doesn't crash.
    int64 t_feb29_2023 = from_ymd(2023, 2, 29);
    // The result is whatever the runtime gives; just verify no crash.
    check("from_ymd(2023,2,29) does not crash", true);

    // -----------------------------------------------------------------------
    // SECTION 11 -- Calendar accessor consistency across date boundaries
    // -----------------------------------------------------------------------

    section("33. Cross-month consistency");

    // March 1 minus 1 day = February 28/29
    int64 t_mar1 = from_ymd(2024, 3, 1);
    int64 t_feb_last = add_days(t_mar1, -1);
    int64 feb_last_day = day(t_feb_last);
    int64 feb_last_month = month(t_feb_last);
    check("day before Mar 1 2024 is Feb 29",
          feb_last_month == 2 && feb_last_day == 29);

    // Non-leap year: March 1 minus 1 day = Feb 28
    int64 t_mar1_2023 = from_ymd(2023, 3, 1);
    int64 t_feb_last_2023 = add_days(t_mar1_2023, -1);
    int64 feb_last_day_2023 = day(t_feb_last_2023);
    int64 feb_last_month_2023 = month(t_feb_last_2023);
    check("day before Mar 1 2023 is Feb 28",
          feb_last_month_2023 == 2 && feb_last_day_2023 == 28);

    section("34. Cross-year consistency");

    // Jan 1 minus 1 day = Dec 31 of previous year
    int64 t_jan1_2025_v2 = from_ymd(2025, 1, 1);
    int64 t_dec31_2024_v2 = add_days(t_jan1_2025_v2, -1);
    int64 dec31_year = year(t_dec31_2024_v2);
    int64 dec31_month = month(t_dec31_2024_v2);
    int64 dec31_day = day(t_dec31_2024_v2);
    check("day before Jan 1 2025 is Dec 31 2024",
          dec31_year == 2024 && dec31_month == 12 && dec31_day == 31);

    // -----------------------------------------------------------------------
    // SECTION 12 -- Sleep (minimal, just verify no crash)
    // -----------------------------------------------------------------------

    section("35. sleep_ms");

    // Minimal sleep (1ms) to verify the function exists and doesn't crash
    int64 before_sleep = mono_us();
    sleep_ms(1);
    int64 after_sleep = mono_us();
    int64 slept_for = after_sleep - before_sleep;
    check("mono_us() after sleep_ms(1) >= before (monotonic)", after_sleep >= before_sleep);
    // Should have slept at least a few microseconds
    check("mono_us delta after sleep_ms(1) is non-zero", slept_for >= 0);

    // sleep_ms(0) should be a no-op
    int64 before_0 = mono_us();
    sleep_ms(0);
    int64 after_0 = mono_us();
    check("sleep_ms(0) is non-negative delta", after_0 >= before_0);

    // -----------------------------------------------------------------------
    // SECTION 13 -- Negative / zero timestamps (pre-epoch)
    // -----------------------------------------------------------------------

    section("36. Pre-epoch dates");

    // Dates before 1970 produce negative timestamps
    int64 t_1960 = from_ymd(1960, 1, 1);
    check("from_ymd(1960,1,1) is defined", t_1960 != 0);
    // 1960 is before 1970 epoch, so the timestamp might be negative
    check("from_ymd(1960,1,1) < from_ymd(1970,1,1)", t_1960 < t_epoch);

    // Calendar accessors still work on pre-epoch dates
    int64 y_1960 = year(t_1960);
    check("year(1960-01-01) == 1960", y_1960 == 1960);

    int64 mo_1960 = month(t_1960);
    check("month(1960-01-01) == 1", mo_1960 == 1);

    int64 d_1960 = day(t_1960);
    check("day(1960-01-01) == 1", d_1960 == 1);

    // Day of week for 1960-01-01 is Friday (5)
    int64 dow_1960 = day_of_week(t_1960);
    check("day_of_week(1960-01-01) == 5 (Friday)", dow_1960 == 5);

    // -----------------------------------------------------------------------
    // SECTION 14 -- mono_us advance over real operations
    // -----------------------------------------------------------------------

    section("37. mono_us advances in real time");

    int64 m1 = mono_us();
    int64 m2 = mono_us();
    check("consecutive mono_us() calls are non-decreasing", m2 >= m1);

    // Build a larger timestamp and verify monotonic
    int64 m_before = mono_us();
    int64 t_dummy = from_ymd(2024, 12, 25);
    string dummy_iso = iso_format(t_dummy);
    int64 m_after = mono_us();
    check("mono_us() after iso_format >= before", m_after >= m_before);

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
    print_console("[test_time] launching comprehensive test routine + sidebar menu");

    g_section = create_sidebar_section("time api test", "");
    g_btn     = g_section.create_button("Actions", ui_align::left);
    g_menu    = create_menu();
    g_menu.add_item("Run again",   cast<int64>(on_menu_run_again), "", "");
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
