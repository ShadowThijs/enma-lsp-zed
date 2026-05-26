// ============================================================================
// math.em — comprehensive exercise of every Math addon function and constant
// ============================================================================
//
// Checklist — every function, every overload, every constant covered:
//
// ── Trigonometry ──────────────────────────────────────────────────────────────
//   F  sin(x)                   F  cos(x)                   F  tan(x)
//   F  asin(x)                  F  acos(x)                  F  atan(x)
//   F  atan2(y, x)
//
// ── Hyperbolic ────────────────────────────────────────────────────────────────
//   F  sinh(x)                  F  cosh(x)                  F  tanh(x)
//   F  asinh(x)                 F  acosh(x)                 F  atanh(x)
//
// ── Power & Logarithm ─────────────────────────────────────────────────────────
//   F  sqrt(x)                  F  cbrt(x)                  F  pow(x, y)
//   F  hypot(a, b)              F  log(x)                   F  log2(x)
//   F  log10(x)                 F  log_base(x, base)        F  exp(x)
//
// ── Rounding ──────────────────────────────────────────────────────────────────
//   F  floor(x)                 F  ceil(x)                  F  round(x)
//   F  round_up(x)              F  round_down(x)
//
// ── Float utilities ───────────────────────────────────────────────────────────
//   F  fabs(x)                  F  fmod(x, y)
//   F  fmin(a, b)               F  fmax(a, b)
//   F  fclamp(x, lo, hi)
//
// ── Integer utilities ─────────────────────────────────────────────────────────
//   F  iabs(x)                  F  imin(a, b)
//   F  imax(a, b)               F  iclamp(x, lo, hi)
//
// ── Overloaded (int64 + float64) ──────────────────────────────────────────────
//   F  abs(x)                   F  min(a, b)
//   F  max(a, b)                F  clamp(x, lo, hi)
//
// ── Constants ─────────────────────────────────────────────────────────────────
//   F  pi()                     F  euler()
//
// ── Random ────────────────────────────────────────────────────────────────────
//   F  seed(s)                  F  rand()
//   F  rand_int(lo, hi)         F  random_bool()
//   F  random_gaussian(mu, sigma)
//
// ── Interpolation ─────────────────────────────────────────────────────────────
//   F  lerp(a, b, t)            F  inverse_lerp(a, b, v)
//
// ── Classification ────────────────────────────────────────────────────────────
//   F  is_nan(v)                F  is_inf(v)
//   F  is_finite(v)
//
// ── Sign / fractional / wrap ──────────────────────────────────────────────────
//   F  sign(v)                  F  fract(v)
//   F  wrap(v, lo, hi)
//
// ── Float bit ops ─────────────────────────────────────────────────────────────
//   F  copysign(mag, sgn)       F  nextafter(from, toward)
//
// ── Bit-cast helpers ──────────────────────────────────────────────────────────
//   F  f32_to_u32(x)            F  u32_to_f32(bits)
//   F  f64_to_u64(x)            F  u64_to_f64(bits)
//
// Legend: F = free function, M = method, T = type, E = enum
// ============================================================================

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

void print_console(string input) {
    print(input);
}

// ============================================================================
// 1. Trigonometry: sin, cos, tan, asin, acos, atan, atan2
// ============================================================================

void test_trigonometry() {
    section("Trigonometry");

    float64 half_pi = pi() / 2.0;

    // sin
    float64 s = sin(0.0);
    check("sin(0) == 0", s == 0.0);

    float64 s_pi2 = sin(half_pi);
    check("sin(pi/2) ~= 1", s_pi2 > 0.99 && s_pi2 < 1.01);

    // cos
    float64 c = cos(0.0);
    check("cos(0) == 1", c == 1.0);

    float64 c_pi2 = cos(half_pi);
    check("cos(pi/2) ~= 0", c_pi2 > -0.01 && c_pi2 < 0.01);

    // tan
    float64 t = tan(0.0);
    check("tan(0) == 0", t == 0.0);

    float64 t_pi4 = tan(pi() / 4.0);
    check("tan(pi/4) ~= 1", t_pi4 > 0.99 && t_pi4 < 1.01);

    // asin
    float64 as = asin(0.0);
    check("asin(0) == 0", as == 0.0);

    float64 as_1 = asin(1.0);
    check("asin(1) ~= pi/2", as_1 > 1.5 && as_1 < 1.6);

    // acos
    float64 ac = acos(1.0);
    check("acos(1) == 0", ac == 0.0);

    float64 ac_0 = acos(0.0);
    check("acos(0) ~= pi/2", ac_0 > 1.5 && ac_0 < 1.6);

    // atan
    float64 at = atan(0.0);
    check("atan(0) == 0", at == 0.0);

    float64 at_1 = atan(1.0);
    check("atan(1) ~= pi/4", at_1 > 0.7 && at_1 < 0.8);

    // atan2
    float64 at2 = atan2(0.0, 1.0);
    check("atan2(0, 1) == 0", at2 == 0.0);

    float64 at2_90 = atan2(1.0, 0.0);
    check("atan2(1, 0) ~= pi/2", at2_90 > 1.5 && at2_90 < 1.6);
}

// ============================================================================
// 2. Hyperbolic: sinh, cosh, tanh, asinh, acosh, atanh
// ============================================================================

void test_hyperbolic() {
    section("Hyperbolic");

    // sinh
    float64 sh = sinh(0.0);
    check("sinh(0) == 0", sh == 0.0);

    // cosh
    float64 ch = cosh(0.0);
    check("cosh(0) == 1", ch == 1.0);

    // tanh
    float64 th = tanh(0.0);
    check("tanh(0) == 0", th == 0.0);

    float64 th_10 = tanh(10.0);
    check("tanh(10) ~= 1", th_10 > 0.99);

    // asinh
    float64 ash = asinh(0.0);
    check("asinh(0) == 0", ash == 0.0);

    // acosh
    float64 ach = acosh(1.0);
    check("acosh(1) == 0", ach == 0.0);

    // atanh
    float64 ath = atanh(0.0);
    check("atanh(0) == 0", ath == 0.0);

    float64 ath_05 = atanh(0.5);
    check("atanh(0.5) returns finite", is_finite(ath_05));
}

// ============================================================================
// 3. Power & Logarithm: sqrt, cbrt, pow, hypot, log, log2, log10, log_base, exp
// ============================================================================

void test_power_log() {
    section("Power & Logarithm");

    // sqrt
    float64 sq = sqrt(4.0);
    check("sqrt(4) == 2", sq == 2.0);

    float64 sq_zero = sqrt(0.0);
    check("sqrt(0) == 0", sq_zero == 0.0);

    // cbrt
    float64 cb = cbrt(8.0);
    check("cbrt(8) == 2", cb == 2.0);

    float64 cb_neg = cbrt(-8.0);
    check("cbrt(-8) == -2", cb_neg == -2.0);

    // pow
    float64 pw = pow(2.0, 3.0);
    check("pow(2, 3) == 8", pw == 8.0);

    float64 pw_zero = pow(5.0, 0.0);
    check("pow(5, 0) == 1", pw_zero == 1.0);

    // hypot
    float64 hp = hypot(3.0, 4.0);
    check("hypot(3, 4) == 5", hp == 5.0);

    float64 hp_zero = hypot(0.0, 0.0);
    check("hypot(0, 0) == 0", hp_zero == 0.0);

    // log (natural log)
    float64 ln = log(1.0);
    check("log(1) == 0", ln == 0.0);

    float64 ln_e = log(euler());
    check("log(e) ~= 1", ln_e > 0.99 && ln_e < 1.01);

    // log2
    float64 l2 = log2(8.0);
    check("log2(8) == 3", l2 == 3.0);

    float64 l2_1 = log2(1.0);
    check("log2(1) == 0", l2_1 == 0.0);

    // log10
    float64 l10 = log10(100.0);
    check("log10(100) == 2", l10 == 2.0);

    float64 l10_1 = log10(1.0);
    check("log10(1) == 0", l10_1 == 0.0);

    // log_base
    float64 lb = log_base(8.0, 2.0);
    check("log_base(8, 2) == 3", lb == 3.0);

    float64 lb_1 = log_base(100.0, 10.0);
    check("log_base(100, 10) == 2", lb_1 == 2.0);

    // exp
    float64 ex = exp(0.0);
    check("exp(0) == 1", ex == 1.0);

    float64 ex_1 = exp(1.0);
    check("exp(1) ~= e", ex_1 > 2.7 && ex_1 < 2.72);
}

// ============================================================================
// 4. Rounding: floor, ceil, round, round_up, round_down
// ============================================================================

void test_rounding() {
    section("Rounding");

    // floor
    float64 fl = floor(3.7);
    check("floor(3.7) == 3", fl == 3.0);

    float64 fl_neg = floor(-3.7);
    check("floor(-3.7) == -4", fl_neg == -4.0);

    // ceil
    float64 ce = ceil(3.2);
    check("ceil(3.2) == 4", ce == 4.0);

    float64 ce_neg = ceil(-3.2);
    check("ceil(-3.2) == -3", ce_neg == -3.0);

    // round
    float64 r1 = round(3.4);
    check("round(3.4) == 3", r1 == 3.0);

    float64 r2 = round(3.6);
    check("round(3.6) == 4", r2 == 4.0);

    float64 r3 = round(-3.4);
    check("round(-3.4) == -3", r3 == -3.0);

    // round_up (alias for ceil)
    float64 ru = round_up(3.2);
    check("round_up(3.2) == 4 (== ceil)", ru == 4.0);

    float64 ru_neg = round_up(-3.2);
    check("round_up(-3.2) == -3 (== ceil)", ru_neg == -3.0);

    // round_down (alias for floor)
    float64 rd = round_down(3.7);
    check("round_down(3.7) == 3 (== floor)", rd == 3.0);

    float64 rd_neg = round_down(-3.7);
    check("round_down(-3.7) == -4 (== floor)", rd_neg == -4.0);
}

// ============================================================================
// 5. Float utilities: fabs, fmod, fmin, fmax, fclamp
// ============================================================================

void test_float_utilities() {
    section("Float utilities");

    // fabs
    float64 fa = fabs(-5.5);
    check("fabs(-5.5) == 5.5", fa == 5.5);

    float64 fa_pos = fabs(3.0);
    check("fabs(3) == 3", fa_pos == 3.0);

    // fmod
    float64 fm = fmod(10.5, 3.0);
    check("fmod(10.5, 3) == 1.5", fm == 1.5);

    float64 fm_exact = fmod(9.0, 3.0);
    check("fmod(9, 3) == 0", fm_exact == 0.0);

    // fmin
    float64 fmin_val = fmin(2.5, 7.3);
    check("fmin(2.5, 7.3) == 2.5", fmin_val == 2.5);

    float64 fmin_eq = fmin(4.0, 4.0);
    check("fmin(4, 4) == 4", fmin_eq == 4.0);

    // fmax
    float64 fmax_val = fmax(2.5, 7.3);
    check("fmax(2.5, 7.3) == 7.3", fmax_val == 7.3);

    float64 fmax_eq = fmax(4.0, 4.0);
    check("fmax(4, 4) == 4", fmax_eq == 4.0);

    // fclamp
    float64 fcl_hi = fclamp(15.0, 0.0, 10.0);
    check("fclamp(15, 0, 10) == 10", fcl_hi == 10.0);

    float64 fcl_lo = fclamp(-5.0, 0.0, 10.0);
    check("fclamp(-5, 0, 10) == 0", fcl_lo == 0.0);

    float64 fcl_mid = fclamp(4.5, 0.0, 10.0);
    check("fclamp(4.5, 0, 10) == 4.5", fcl_mid == 4.5);
}

// ============================================================================
// 6. Integer utilities: iabs, imin, imax, iclamp
// ============================================================================

void test_integer_utilities() {
    section("Integer utilities");

    // iabs
    int64 ia = iabs(-42);
    check("iabs(-42) == 42", ia == 42);

    int64 ia_pos = iabs(7);
    check("iabs(7) == 7", ia_pos == 7);

    // imin
    int64 imn = imin(10, 20);
    check("imin(10, 20) == 10", imn == 10);

    int64 imn_eq = imin(5, 5);
    check("imin(5, 5) == 5", imn_eq == 5);

    // imax
    int64 imx = imax(10, 20);
    check("imax(10, 20) == 20", imx == 20);

    int64 imx_eq = imax(5, 5);
    check("imax(5, 5) == 5", imx_eq == 5);

    // iclamp
    int64 icl_hi = iclamp(50, 0, 10);
    check("iclamp(50, 0, 10) == 10", icl_hi == 10);

    int64 icl_lo = iclamp(-10, 0, 10);
    check("iclamp(-10, 0, 10) == 0", icl_lo == 0);

    int64 icl_mid = iclamp(7, 0, 10);
    check("iclamp(7, 0, 10) == 7", icl_mid == 7);
}

// ============================================================================
// 7. Overloaded: abs, min, max, clamp (int64 and float64)
// ============================================================================

void test_overloaded() {
    section("Overloaded abs / min / max / clamp");

    // --- abs (float64) ---
    float64 abs_f = abs(-3.14);
    check("abs(-3.14) == 3.14 (float64)", abs_f == 3.14);

    float64 abs_f_pos = abs(2.71);
    check("abs(2.71) == 2.71 (float64)", abs_f_pos == 2.71);

    // --- abs (int64) ---
    int64 abs_i = abs(-100);
    check("abs(-100) == 100 (int64)", abs_i == 100);

    int64 abs_i_pos = abs(42);
    check("abs(42) == 42 (int64)", abs_i_pos == 42);

    // --- min (float64) ---
    float64 min_f = min(1.5, 3.5);
    check("min(1.5, 3.5) == 1.5 (float64)", min_f == 1.5);

    // --- min (int64) ---
    int64 min_i = min(10, 30);
    check("min(10, 30) == 10 (int64)", min_i == 10);

    // --- max (float64) ---
    float64 max_f = max(1.5, 3.5);
    check("max(1.5, 3.5) == 3.5 (float64)", max_f == 3.5);

    // --- max (int64) ---
    int64 max_i = max(10, 30);
    check("max(10, 30) == 30 (int64)", max_i == 30);

    // --- clamp (float64) ---
    float64 cl_f_hi = clamp(20.0, 0.0, 10.0);
    check("clamp(20, 0, 10) == 10 (float64)", cl_f_hi == 10.0);

    float64 cl_f_lo = clamp(-5.0, 0.0, 10.0);
    check("clamp(-5, 0, 10) == 0 (float64)", cl_f_lo == 0.0);

    float64 cl_f_mid = clamp(4.5, 0.0, 10.0);
    check("clamp(4.5, 0, 10) == 4.5 (float64)", cl_f_mid == 4.5);

    // --- clamp (int64) ---
    int64 cl_i_hi = clamp(100, 0, 50);
    check("clamp(100, 0, 50) == 50 (int64)", cl_i_hi == 50);

    int64 cl_i_lo = clamp(-20, 0, 50);
    check("clamp(-20, 0, 50) == 0 (int64)", cl_i_lo == 0);

    int64 cl_i_mid = clamp(25, 0, 50);
    check("clamp(25, 0, 50) == 25 (int64)", cl_i_mid == 25);
}

// ============================================================================
// 8. Constants: pi, euler
// ============================================================================

void test_constants() {
    section("Constants");

    // pi
    float64 p = pi();
    check("pi() > 3.14", p > 3.14);
    check("pi() < 3.15", p < 3.15);

    // euler
    float64 e = euler();
    check("euler() > 2.71", e > 2.71);
    check("euler() < 2.72", e < 2.72);
}

// ============================================================================
// 9. Random: seed, rand, rand_int, random_bool, random_gaussian
// ============================================================================

void test_random() {
    section("Random");

    // seed — deterministic sequence
    seed(42);

    // rand — float64 in [0, 1)
    float64 r = rand();
    check("rand() >= 0", r >= 0.0);
    check("rand() < 1", r < 1.0);

    // Second call should differ (RNG advances)
    float64 r2 = rand();
    check("second rand() also in [0,1)", r2 >= 0.0 && r2 < 1.0);

    // Reseed produces same sequence
    seed(42);
    float64 r_re = rand();
    check("reseed(42) reproduces first rand()", r_re == r);

    // rand_int — int64 in [lo, hi)
    int64 ri = rand_int(0, 100);
    check("rand_int(0, 100) >= 0", ri >= 0);
    check("rand_int(0, 100) < 100", ri < 100);

    int64 ri2 = rand_int(5, 10);
    check("rand_int(5, 10) >= 5", ri2 >= 5);
    check("rand_int(5, 10) < 10", ri2 < 10);

    // random_bool
    bool rb = random_bool();
    check("random_bool() is bool", rb == true || rb == false);

    // random_gaussian — normal distribution
    float64 rg = random_gaussian(0.0, 1.0);
    check("random_gaussian(0,1) returns finite", is_finite(rg));
}

// ============================================================================
// 10. Interpolation: lerp, inverse_lerp
// ============================================================================

void test_interpolation() {
    section("Interpolation");

    // lerp: a + (b - a) * t
    float64 l1 = lerp(0.0, 10.0, 0.5);
    check("lerp(0, 10, 0.5) == 5", l1 == 5.0);

    float64 l2 = lerp(0.0, 10.0, 0.0);
    check("lerp(0, 10, 0) == 0", l2 == 0.0);

    float64 l3 = lerp(0.0, 10.0, 1.0);
    check("lerp(0, 10, 1) == 10", l3 == 10.0);

    float64 l4 = lerp(10.0, 20.0, 0.3);
    check("lerp(10, 20, 0.3) == 13", l4 == 13.0);

    // inverse_lerp: (v - a) / (b - a); 0 if a == b
    float64 il = inverse_lerp(0.0, 10.0, 5.0);
    check("inverse_lerp(0, 10, 5) == 0.5", il == 0.5);

    float64 il_start = inverse_lerp(0.0, 10.0, 0.0);
    check("inverse_lerp(0, 10, 0) == 0", il_start == 0.0);

    float64 il_end = inverse_lerp(0.0, 10.0, 10.0);
    check("inverse_lerp(0, 10, 10) == 1", il_end == 1.0);

    float64 il_eq = inverse_lerp(5.0, 5.0, 42.0);
    check("inverse_lerp(5, 5, 42) == 0 (a==b guard)", il_eq == 0.0);
}

// ============================================================================
// 11. Classification: is_nan, is_inf, is_finite
// ============================================================================

void test_classification() {
    section("Classification");

    float64 normal_val = 42.5;
    float64 zero = 0.0;

    // is_nan
    bool nan_normal = is_nan(normal_val);
    check("is_nan(42.5) == false", !nan_normal);

    bool nan_zero = is_nan(zero);
    check("is_nan(0) == false", !nan_zero);

    // is_inf
    bool inf_normal = is_inf(normal_val);
    check("is_inf(42.5) == false", !inf_normal);

    bool inf_zero = is_inf(zero);
    check("is_inf(0) == false", !inf_zero);

    // is_finite
    bool fin_normal = is_finite(normal_val);
    check("is_finite(42.5) == true", fin_normal);

    bool fin_zero = is_finite(zero);
    check("is_finite(0) == true", fin_zero);
}

// ============================================================================
// 12. Sign / fractional / wrap: sign, fract, wrap
// ============================================================================

void test_sign_fract_wrap() {
    section("Sign / fractional / wrap");

    // sign
    float64 sg_pos = sign(5.5);
    check("sign(5.5) == 1.0", sg_pos == 1.0);

    float64 sg_neg = sign(-3.2);
    check("sign(-3.2) == -1.0", sg_neg == -1.0);

    float64 sg_zero = sign(0.0);
    check("sign(0) == 0.0", sg_zero == 0.0);

    // fract: v - floor(v)
    float64 fr = fract(3.7);
    check("fract(3.7) == 0.7", fr == 0.7);

    float64 fr_neg = fract(-3.7);
    check("fract(-3.7) == 0.3 (positive for negative)", fr_neg > 0.29 && fr_neg < 0.31);

    float64 fr_int = fract(5.0);
    check("fract(5) == 0", fr_int == 0.0);

    // wrap: wrap v into [lo, hi)
    float64 wr = wrap(7.0, 0.0, 5.0);
    check("wrap(7, 0, 5) == 2", wr == 2.0);

    float64 wr_neg = wrap(-3.0, 0.0, 5.0);
    check("wrap(-3, 0, 5) == 2", wr_neg == 2.0);

    float64 wr_in = wrap(2.5, 0.0, 5.0);
    check("wrap(2.5, 0, 5) == 2.5 (already in range)", wr_in == 2.5);
}

// ============================================================================
// 13. Float bit ops: copysign, nextafter
// ============================================================================

void test_float_bit_ops() {
    section("Float bit ops");

    // copysign: |mag| with sign of sgn
    float64 cs1 = copysign(5.0, -1.0);
    check("copysign(5, -1) == -5", cs1 == -5.0);

    float64 cs2 = copysign(5.0, 1.0);
    check("copysign(5, 1) == 5", cs2 == 5.0);

    float64 cs3 = copysign(-8.0, 1.0);
    check("copysign(-8, 1) == 8 (magnitude preserved)", cs3 == 8.0);

    // nextafter: next representable float toward `toward`
    float64 na = nextafter(0.0, 1.0);
    check("nextafter(0, 1) > 0 (smallest positive subnormal)", na > 0.0);

    float64 na_zero = nextafter(0.0, -1.0);
    check("nextafter(0, -1) < 0 (smallest negative subnormal)", na_zero < 0.0);

    float64 na_same = nextafter(5.0, 5.0);
    check("nextafter(5, 5) == 5 (toward == from)", na_same == 5.0);
}

// ============================================================================
// 14. Bit-cast helpers: f32_to_u32, u32_to_f32, f64_to_u64, u64_to_f64
// ============================================================================

void test_bitcast_helpers() {
    section("Bit-cast helpers");

    // f32_to_u32 + roundtrip via u32_to_f32
    float32 orig_f32 = 3.14159;
    uint32 bits32 = f32_to_u32(orig_f32);
    float32 roundtrip_f32 = u32_to_f32(bits32);
    check("f32_to_u32 + u32_to_f32 roundtrip", roundtrip_f32 == orig_f32);

    // Known value: 1.0f in IEEE-754 is 0x3F800000
    float32 one_f32 = 1.0;
    uint32 one_bits = f32_to_u32(one_f32);
    check("f32_to_u32(1.0) == 0x3F800000", one_bits == 0x3F800000);

    // u32_to_f32 reverse of known value
    float32 back_one = u32_to_f32(0x3F800000);
    check("u32_to_f32(0x3F800000) == 1.0", back_one == 1.0);

    // Zero roundtrip
    float32 zero_f32 = 0.0;
    uint32 zero_bits = f32_to_u32(zero_f32);
    float32 zero_back = u32_to_f32(zero_bits);
    check("f32_to_u32(0) + u32_to_f32 roundtrip == 0", zero_back == 0.0);

    // f64_to_u64 + roundtrip via u64_to_f64
    float64 orig_f64 = 2.718281828459045;
    uint64 bits64 = f64_to_u64(orig_f64);
    float64 roundtrip_f64 = u64_to_f64(bits64);
    check("f64_to_u64 + u64_to_f64 roundtrip", roundtrip_f64 == orig_f64);

    // Known value: 1.0 in IEEE-754 double is 0x3FF0000000000000
    float64 one_f64 = 1.0;
    uint64 one_bits64 = f64_to_u64(one_f64);
    check("f64_to_u64(1.0) == 0x3FF0000000000000", one_bits64 == 0x3FF0000000000000);

    // u64_to_f64 reverse of known value
    float64 back_one64 = u64_to_f64(0x3FF0000000000000);
    check("u64_to_f64(0x3FF0000000000000) == 1.0", back_one64 == 1.0);

    // Zero roundtrip
    float64 zero_f64 = 0.0;
    uint64 zero_bits64 = f64_to_u64(zero_f64);
    float64 zero_back64 = u64_to_f64(zero_bits64);
    check("f64_to_u64(0) + u64_to_f64 roundtrip == 0", zero_back64 == 0.0);
}

// ============================================================================
// 15. Main — call all test functions
// ============================================================================

int32 main() {
    print_console("=== Math addon comprehensive test ===");

    test_trigonometry();
    test_hyperbolic();
    test_power_log();
    test_rounding();
    test_float_utilities();
    test_integer_utilities();
    test_overloaded();
    test_constants();
    test_random();
    test_interpolation();
    test_classification();
    test_sign_fract_wrap();
    test_float_bit_ops();
    test_bitcast_helpers();

    print_console("");
    print_console("===========================================");
    print_console("  PASS: " + cast<string>(g_pass));
    print_console("  FAIL: " + cast<string>(g_fail));
    print_console("===========================================");

    if (g_fail > 0) {
        return 1;
    }
    return 0;
}
