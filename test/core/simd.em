// =============================================================================
// simd.em — comprehensive exercise of every SIMD addon function
// =============================================================================
//
// Registered with register_addon_simd(engine). Uses SSE2 intrinsics; ops
// fall back to scalar for trailing elements when array length is odd.
//
// Argument convention: (a, b, dst) — inputs first, output last.
// Output arrays must be pre-sized; the natives don't grow them.
//
// ── CHECKLIST ─────────────────────────────────────────────────────────────────
//
// Elementwise float64 (10 functions):
//   F  simd_add_f64(a, b, dst)         dst[i] = a[i] + b[i]
//   F  simd_sub_f64(a, b, dst)         dst[i] = a[i] - b[i]
//   F  simd_mul_f64(a, b, dst)         dst[i] = a[i] * b[i]
//   F  simd_div_f64(a, b, dst)         dst[i] = a[i] / b[i]
//   F  simd_min_f64(a, b, dst)         dst[i] = min(a[i], b[i])
//   F  simd_max_f64(a, b, dst)         dst[i] = max(a[i], b[i])
//   F  simd_abs_f64(src, dst)          dst[i] = |src[i]|
//   F  simd_sqrt_f64(src, dst)         dst[i] = sqrt(src[i])
//   F  simd_fma_f64(a, b, c, dst)      dst[i] = a[i] * b[i] + c[i]
//   F  simd_scale_f64(src, k, dst)     dst[i] = src[i] * k
//
// Reductions (4 functions):
//   F  simd_dot_f64(a, b)           -> float64   a . b
//   F  simd_sum_f64(a)              -> float64   sum of elements
//   F  simd_min_reduce_f64(a)       -> float64   minimum element
//   F  simd_max_reduce_f64(a)       -> float64   maximum element
//
// Compare f64 - returns 1.0 / 0.0 per lane (2 functions):
//   F  simd_cmp_eq_f64(a, b, dst)
//   F  simd_cmp_lt_f64(a, b, dst)
//
// Elementwise int64 (4 functions):
//   F  simd_add_i64(a, b, dst)
//   F  simd_sub_i64(a, b, dst)
//   F  simd_mul_i64(a, b, dst)          scalar fallback (no SSE2 packed 64-bit mul)
//   F  simd_sum_i64(a)               -> int64
//
// Memory (2 functions):
//   F  simd_memset(arr, val)            fill entire array with int64 val
//   F  simd_memcpy(src, dst)
//
// int8 / uint8 — 16 lanes (5 functions):
//   F  simd_add_i8(a, b, dst)           wrap
//   F  simd_sub_i8(a, b, dst)           wrap
//   F  simd_cmp_eq_i8(a, b, dst)        dst[i] = 0xFF if eq else 0x00
//   F  simd_movemask_i8(a)           -> int64   bit i = sign bit of a[i]
//   F  simd_shuffle_i8(src, mask, dst)  pshufb per 16-byte block
//
// int16 / uint16 — 8 lanes (3 functions):
//   F  simd_add_i16(a, b, dst)
//   F  simd_sub_i16(a, b, dst)
//   F  simd_mul_i16(a, b, dst)
//
// int32 / uint32 — 4 lanes (3 functions):
//   F  simd_add_i32(a, b, dst)
//   F  simd_sub_i32(a, b, dst)
//   F  simd_mul_i32(a, b, dst)
//
// float32 — 4 lanes (10 functions):
//   F  simd_add_f32(a, b, dst)
//   F  simd_sub_f32(a, b, dst)
//   F  simd_mul_f32(a, b, dst)
//   F  simd_div_f32(a, b, dst)
//   F  simd_sqrt_f32(src, dst)
//   F  simd_min_f32(a, b, dst)
//   F  simd_max_f32(a, b, dst)
//   F  simd_abs_f32(src, dst)
//   F  simd_dot_f32(a, b)            -> float64
//   F  simd_sum_f32(a)               -> float64
//
// Bitwise — any stride-1 array (3 functions):
//   F  simd_and(a, b, dst)
//   F  simd_or(a, b, dst)
//   F  simd_xor(a, b, dst)
//
// Legend: F = free function
// =============================================================================

int64 g_pass = 0;
int64 g_fail = 0;

void check(string label, bool ok) {
    if (ok) {
        print_console("  [PASS] " + label);
        g_pass = g_pass + 1;
    } else {
        print_console("  [FAIL] " + label);
        g_fail = g_fail + 1;
    }
}

void section(string name) {
    print_console("");
    print_console("--- " + name + " ---");
}

void print_console(string s) {
    print(s);
}

// float64 comparisons
bool feq(float64 a, float64 b) {
    float64 d = a - b;
    if (d < 0.0) d = -d;
    return d < 1e-12;
}

// float32 comparisons (lower precision)
bool feq32(float64 a, float64 b) {
    float64 d = a - b;
    if (d < 0.0) d = -d;
    return d < 1e-6;
}

// ============================================================================
// Array helpers — create or verify arrays
// ============================================================================

// Push N copies of val into arr
void fill_f64(float64[] arr, int64 n, float64 val) {
    int64 i = 0;
    while (i < n) { arr.push(val); i = i + 1; }
}

void fill_i64(int64[] arr, int64 n, int64 val) {
    int64 i = 0;
    while (i < n) { arr.push(val); i = i + 1; }
}

void fill_i8(int8[] arr, int64 n, int8 val) {
    int64 i = 0;
    while (i < n) { arr.push(val); i = i + 1; }
}

void fill_i16(int16[] arr, int64 n, int16 val) {
    int64 i = 0;
    while (i < n) { arr.push(val); i = i + 1; }
}

void fill_i32(int32[] arr, int64 n, int32 val) {
    int64 i = 0;
    while (i < n) { arr.push(val); i = i + 1; }
}

void fill_f32(float32[] arr, int64 n, float32 val) {
    int64 i = 0;
    while (i < n) { arr.push(val); i = i + 1; }
}

void fill_u8(uint8[] arr, int64 n, uint8 val) {
    int64 i = 0;
    while (i < n) { arr.push(val); i = i + 1; }
}

// ============================================================================
// 1. Elementwise float64
// ============================================================================

void test_elementwise_f64() {
    section("Elementwise float64");

    // Input data: 8 elements
    // a = [10, 20, 30, 40, 50, 60, 70, 80]
    // b = [ 1,  2,  3,  4,  5,  6,  7,  8]
    float64[] a;
    float64[] b;
    int64 i = 0;
    float64 v = 10.0;
    while (i < 8) { a.push(v); v = v + 10.0; i = i + 1; }
    i = 0;
    v = 1.0;
    while (i < 8) { b.push(v); v = v + 1.0; i = i + 1; }
    float64[] dst;
    fill_f64(dst, 8, 0.0);

    // simd_add_f64
    simd_add_f64(a, b, dst);
    check("simd_add_f64[0] == 11 (10+1)",  feq(dst.get(0), 11.0));
    check("simd_add_f64[3] == 44 (40+4)",  feq(dst.get(3), 44.0));
    check("simd_add_f64[7] == 88 (80+8)",  feq(dst.get(7), 88.0));

    // simd_sub_f64
    simd_sub_f64(a, b, dst);
    check("simd_sub_f64[0] == 9 (10-1)",    feq(dst.get(0), 9.0));
    check("simd_sub_f64[4] == 45 (50-5)",   feq(dst.get(4), 45.0));
    check("simd_sub_f64[7] == 72 (80-8)",   feq(dst.get(7), 72.0));

    // simd_mul_f64
    simd_mul_f64(a, b, dst);
    check("simd_mul_f64[0] == 10 (10*1)",   feq(dst.get(0), 10.0));
    check("simd_mul_f64[2] == 90 (30*3)",   feq(dst.get(2), 90.0));
    check("simd_mul_f64[7] == 640 (80*8)",  feq(dst.get(7), 640.0));

    // simd_div_f64
    simd_div_f64(a, b, dst);
    check("simd_div_f64[0] == 10 (10/1)",   feq(dst.get(0), 10.0));
    check("simd_div_f64[1] == 10 (20/2)",   feq(dst.get(1), 10.0));
    check("simd_div_f64[7] == 10 (80/8)",   feq(dst.get(7), 10.0));

    // simd_min_f64
    float64[] a_high;
    a_high.push(100.0); a_high.push(5.0); a_high.push(30.0); a_high.push(1.0);
    a_high.push(99.0);  a_high.push(60.0); a_high.push(2.0); a_high.push(80.0);
    float64[] b_low;
    b_low.push(1.0);   b_low.push(50.0); b_low.push(3.0);   b_low.push(40.0);
    b_low.push(10.0);  b_low.push(6.0);  b_low.push(70.0);  b_low.push(8.0);
    simd_min_f64(a_high, b_low, dst);
    check("simd_min_f64[0] == 1",    feq(dst.get(0), 1.0));
    check("simd_min_f64[1] == 5",    feq(dst.get(1), 5.0));
    check("simd_min_f64[3] == 1",    feq(dst.get(3), 1.0));
    check("simd_min_f64[6] == 2",    feq(dst.get(6), 2.0));

    // simd_max_f64
    simd_max_f64(a_high, b_low, dst);
    check("simd_max_f64[0] == 100",  feq(dst.get(0), 100.0));
    check("simd_max_f64[1] == 50",   feq(dst.get(1), 50.0));
    check("simd_max_f64[4] == 99",   feq(dst.get(4), 99.0));
    check("simd_max_f64[6] == 70",   feq(dst.get(6), 70.0));

    // simd_abs_f64 — use negative and positive values
    float64[] neg_src;
    neg_src.push(-5.0); neg_src.push(3.0); neg_src.push(-10.0); neg_src.push(0.0);
    neg_src.push(-0.5); neg_src.push(100.0); neg_src.push(-1.0); neg_src.push(-999.0);
    float64[] abs_dst;
    fill_f64(abs_dst, 8, 0.0);
    simd_abs_f64(neg_src, abs_dst);
    check("simd_abs_f64[0] == 5",    feq(abs_dst.get(0), 5.0));
    check("simd_abs_f64[1] == 3",    feq(abs_dst.get(1), 3.0));
    check("simd_abs_f64[2] == 10",   feq(abs_dst.get(2), 10.0));
    check("simd_abs_f64[3] == 0",    feq(abs_dst.get(3), 0.0));
    check("simd_abs_f64[4] == 0.5",  feq(abs_dst.get(4), 0.5));
    check("simd_abs_f64[7] == 999",  feq(abs_dst.get(7), 999.0));

    // simd_sqrt_f64
    float64[] sq_src;
    sq_src.push(0.0); sq_src.push(1.0); sq_src.push(4.0); sq_src.push(9.0);
    sq_src.push(16.0); sq_src.push(25.0); sq_src.push(36.0); sq_src.push(49.0);
    float64[] sqrt_dst;
    fill_f64(sqrt_dst, 8, 0.0);
    simd_sqrt_f64(sq_src, sqrt_dst);
    check("simd_sqrt_f64[0] == 0",   feq(sqrt_dst.get(0), 0.0));
    check("simd_sqrt_f64[1] == 1",   feq(sqrt_dst.get(1), 1.0));
    check("simd_sqrt_f64[2] == 2",   feq(sqrt_dst.get(2), 2.0));
    check("simd_sqrt_f64[3] == 3",   feq(sqrt_dst.get(3), 3.0));
    check("simd_sqrt_f64[5] == 5",   feq(sqrt_dst.get(5), 5.0));
    check("simd_sqrt_f64[7] == 7",   feq(sqrt_dst.get(7), 7.0));

    // simd_fma_f64(a, b, c, dst) — dst[i] = a[i] * b[i] + c[i]
    float64[] fma_a;
    float64[] fma_b;
    float64[] fma_c;
    fma_a.push(2.0); fma_a.push(3.0); fma_a.push(4.0); fma_a.push(5.0);
    fma_a.push(6.0); fma_a.push(7.0); fma_a.push(8.0); fma_a.push(9.0);
    fma_b.push(10.0); fma_b.push(20.0); fma_b.push(30.0); fma_b.push(40.0);
    fma_b.push(50.0); fma_b.push(60.0); fma_b.push(70.0); fma_b.push(80.0);
    fma_c.push(1.0); fma_c.push(1.0); fma_c.push(1.0); fma_c.push(1.0);
    fma_c.push(1.0); fma_c.push(1.0); fma_c.push(1.0); fma_c.push(1.0);
    float64[] fma_dst;
    fill_f64(fma_dst, 8, 0.0);
    simd_fma_f64(fma_a, fma_b, fma_c, fma_dst);
    check("simd_fma_f64[0] == 21  (2*10+1)",  feq(fma_dst.get(0), 21.0));
    check("simd_fma_f64[1] == 61  (3*20+1)",  feq(fma_dst.get(1), 61.0));
    check("simd_fma_f64[3] == 201 (5*40+1)",  feq(fma_dst.get(3), 201.0));
    check("simd_fma_f64[7] == 721 (9*80+1)",  feq(fma_dst.get(7), 721.0));

    // simd_scale_f64(src, k, dst) — dst[i] = src[i] * k
    float64[] scale_src;
    scale_src.push(1.0); scale_src.push(2.0); scale_src.push(3.0); scale_src.push(4.0);
    scale_src.push(5.0); scale_src.push(6.0); scale_src.push(7.0); scale_src.push(8.0);
    float64[] scale_dst;
    fill_f64(scale_dst, 8, 0.0);
    simd_scale_f64(scale_src, 3.0, scale_dst);
    check("simd_scale_f64[0] == 3",    feq(scale_dst.get(0), 3.0));
    check("simd_scale_f64[2] == 9",    feq(scale_dst.get(2), 9.0));
    check("simd_scale_f64[5] == 18",   feq(scale_dst.get(5), 18.0));
    check("simd_scale_f64[7] == 24",   feq(scale_dst.get(7), 24.0));
}

// ============================================================================
// 2. Reductions
// ============================================================================

void test_reductions() {
    section("Reductions");

    // Data: a = [1, 2, 3, 4], b = [5, 6, 7, 8]
    float64[] a;
    a.push(1.0); a.push(2.0); a.push(3.0); a.push(4.0);
    float64[] b;
    b.push(5.0); b.push(6.0); b.push(7.0); b.push(8.0);

    // simd_dot_f64(a, b) -> float64  = 1*5 + 2*6 + 3*7 + 4*8 = 5+12+21+32 = 70
    float64 dot = simd_dot_f64(a, b);
    check("simd_dot_f64([1,2,3,4], [5,6,7,8]) == 70", feq(dot, 70.0));

    // simd_sum_f64(a) -> float64  = 1+2+3+4 = 10
    float64 sum = simd_sum_f64(a);
    check("simd_sum_f64([1,2,3,4]) == 10", feq(sum, 10.0));

    // simd_min_reduce_f64(a) -> float64
    float64 min_val = simd_min_reduce_f64(a);
    check("simd_min_reduce_f64([1,2,3,4]) == 1", feq(min_val, 1.0));

    // simd_max_reduce_f64(a) -> float64
    float64 max_val = simd_max_reduce_f64(a);
    check("simd_max_reduce_f64([1,2,3,4]) == 4", feq(max_val, 4.0));

    // Test with all-negative for meaningful min/max
    float64[] neg;
    neg.push(-10.0); neg.push(-3.0); neg.push(-7.0); neg.push(-1.0);
    check("simd_min_reduce_f64 negatives == -10", feq(simd_min_reduce_f64(neg), -10.0));
    check("simd_max_reduce_f64 negatives == -1",  feq(simd_max_reduce_f64(neg), -1.0));
}

// ============================================================================
// 3. Compare
// ============================================================================

void test_compare() {
    section("Compare (1.0 / 0.0 per lane)");

    // a = [1, 2, 3, 4, 5, 6, 7, 8]
    // b = [5, 2, 9, 4, 1, 6, 7, 0]
    float64[] a;
    a.push(1.0); a.push(2.0); a.push(3.0); a.push(4.0);
    a.push(5.0); a.push(6.0); a.push(7.0); a.push(8.0);
    float64[] b;
    b.push(5.0); b.push(2.0); b.push(9.0); b.push(4.0);
    b.push(1.0); b.push(6.0); b.push(7.0); b.push(0.0);

    float64[] cmp_dst;
    fill_f64(cmp_dst, 8, 0.0);

    // simd_cmp_eq_f64 — lanes: 0:1!=5→0, 1:2==2→1, 2:3!=9→0, 3:4==4→1,
    //                        4:5!=1→0, 5:6==6→1, 6:7==7→1, 7:8!=0→0
    simd_cmp_eq_f64(a, b, cmp_dst);
    check("simd_cmp_eq_f64[0] == 0 (1!=5)",  feq(cmp_dst.get(0), 0.0));
    check("simd_cmp_eq_f64[1] == 1 (2==2)",  feq(cmp_dst.get(1), 1.0));
    check("simd_cmp_eq_f64[3] == 1 (4==4)",  feq(cmp_dst.get(3), 1.0));
    check("simd_cmp_eq_f64[5] == 1 (6==6)",  feq(cmp_dst.get(5), 1.0));
    check("simd_cmp_eq_f64[7] == 0 (8!=0)",  feq(cmp_dst.get(7), 0.0));

    // simd_cmp_lt_f64 — lanes: 0:1<5→1, 1:2<2→0, 2:3<9→1, 3:4<4→0,
    //                       4:5<1→0, 5:6<6→0, 6:7<7→0, 7:8<0→0
    simd_cmp_lt_f64(a, b, cmp_dst);
    check("simd_cmp_lt_f64[0] == 1 (1<5)",   feq(cmp_dst.get(0), 1.0));
    check("simd_cmp_lt_f64[1] == 0 (2<2)",   feq(cmp_dst.get(1), 0.0));
    check("simd_cmp_lt_f64[2] == 1 (3<9)",   feq(cmp_dst.get(2), 1.0));
    check("simd_cmp_lt_f64[4] == 0 (5<1)",   feq(cmp_dst.get(4), 0.0));
    check("simd_cmp_lt_f64[7] == 0 (8<0)",   feq(cmp_dst.get(7), 0.0));
}

// ============================================================================
// 4. Elementwise int64
// ============================================================================

void test_elementwise_i64() {
    section("Elementwise int64");

    int64[] a;
    int64[] b;
    a.push(100); a.push(200); a.push(300); a.push(400);
    a.push(500); a.push(600); a.push(700); a.push(800);
    b.push(10); b.push(20); b.push(30); b.push(40);
    b.push(50); b.push(60); b.push(70); b.push(80);
    int64[] dst;
    fill_i64(dst, 8, 0);

    // simd_add_i64
    simd_add_i64(a, b, dst);
    check("simd_add_i64[0] == 110",   dst.get(0) == 110);
    check("simd_add_i64[3] == 440",   dst.get(3) == 440);
    check("simd_add_i64[7] == 880",   dst.get(7) == 880);

    // simd_sub_i64
    simd_sub_i64(a, b, dst);
    check("simd_sub_i64[0] == 90",    dst.get(0) == 90);
    check("simd_sub_i64[5] == 540",   dst.get(5) == 540);
    check("simd_sub_i64[7] == 720",   dst.get(7) == 720);

    // simd_mul_i64 — scalar fallback
    simd_mul_i64(a, b, dst);
    check("simd_mul_i64[0] == 1000",        dst.get(0) == 1000);
    check("simd_mul_i64[2] == 9000",        dst.get(2) == 9000);
    check("simd_mul_i64[7] == 64000",       dst.get(7) == 64000);

    // simd_sum_i64(a) -> int64  = 100+200+300+400+500+600+700+800 = 3600
    int64 sum_i64 = simd_sum_i64(a);
    check("simd_sum_i64([100..800]) == 3600", sum_i64 == 3600);
}

// ============================================================================
// 5. Memory
// ============================================================================

void test_memory() {
    section("Memory");

    // simd_memset(arr, val) — fill entire array with int64 val
    int64[] mem_arr;
    fill_i64(mem_arr, 8, 0);
    simd_memset(mem_arr, 42);
    check("simd_memset[0] == 42",  mem_arr.get(0) == 42);
    check("simd_memset[3] == 42",  mem_arr.get(3) == 42);
    check("simd_memset[7] == 42",  mem_arr.get(7) == 42);

    // simd_memcpy(src, dst)
    int64[] src_arr;
    src_arr.push(10); src_arr.push(20); src_arr.push(30); src_arr.push(40);
    src_arr.push(50); src_arr.push(60); src_arr.push(70); src_arr.push(80);
    int64[] cpy_dst;
    fill_i64(cpy_dst, 8, 0);
    simd_memcpy(src_arr, cpy_dst);
    check("simd_memcpy[0] == 10",  cpy_dst.get(0) == 10);
    check("simd_memcpy[2] == 30",  cpy_dst.get(2) == 30);
    check("simd_memcpy[5] == 60",  cpy_dst.get(5) == 60);
    check("simd_memcpy[7] == 80",  cpy_dst.get(7) == 80);
}

// ============================================================================
// 6. int8 / uint8 — 16 lanes
// ============================================================================

void test_i8() {
    section("int8 / uint8");

    // simd_add_i8(a, b, dst) — wrap
    int8[] i8_a;
    int8[] i8_b;
    i8_a.push(10); i8_a.push(20); i8_a.push(30); i8_a.push(40);
    i8_a.push(50); i8_a.push(60); i8_a.push(70); i8_a.push(80);
    i8_a.push(90); i8_a.push(100); i8_a.push(110); i8_a.push(120);
    i8_a.push(127); i8_a.push(-10); i8_a.push(-20); i8_a.push(-30);
    i8_b.push(1); i8_b.push(2); i8_b.push(3); i8_b.push(4);
    i8_b.push(5); i8_b.push(6); i8_b.push(7); i8_b.push(8);
    i8_b.push(9); i8_b.push(10); i8_b.push(11); i8_b.push(12);
    i8_b.push(13); i8_b.push(14); i8_b.push(15); i8_b.push(16);
    int8[] i8_dst;
    fill_i8(i8_dst, 16, 0);

    simd_add_i8(i8_a, i8_b, i8_dst);
    check("simd_add_i8[0] == 11",   i8_dst.get(0) == 11);
    check("simd_add_i8[3] == 44",   i8_dst.get(3) == 44);
    check("simd_add_i8[7] == 88",   i8_dst.get(7) == 88);
    check("simd_add_i8[15] == -14", i8_dst.get(15) == -14);  // -30 + 16 = -14

    // simd_sub_i8(a, b, dst) — wrap
    simd_sub_i8(i8_a, i8_b, i8_dst);
    check("simd_sub_i8[0] == 9",    i8_dst.get(0) == 9);
    check("simd_sub_i8[4] == 45",   i8_dst.get(4) == 45);
    check("simd_sub_i8[12] == 114", i8_dst.get(12) == 114);  // 127 - 13 = 114
    check("simd_sub_i8[14] == -35", i8_dst.get(14) == -35);  // -20 - 15 = -35

    // simd_cmp_eq_i8 — dst[i] = 0xFF if eq else 0x00
    int8[] i8_cmp_a;
    int8[] i8_cmp_b;
    i8_cmp_a.push(10); i8_cmp_a.push(20); i8_cmp_a.push(30); i8_cmp_a.push(40);
    i8_cmp_a.push(50); i8_cmp_a.push(60); i8_cmp_a.push(70); i8_cmp_a.push(80);
    i8_cmp_a.push(90); i8_cmp_a.push(100); i8_cmp_a.push(110); i8_cmp_a.push(120);
    i8_cmp_a.push(0); i8_cmp_a.push(-1); i8_cmp_a.push(127); i8_cmp_a.push(-128);
    // b matches at indices 1 (20), 5 (60), 12 (0), 14 (127)
    i8_cmp_b.push(0); i8_cmp_b.push(20); i8_cmp_b.push(31); i8_cmp_b.push(41);
    i8_cmp_b.push(49); i8_cmp_b.push(60); i8_cmp_b.push(71); i8_cmp_b.push(81);
    i8_cmp_b.push(89); i8_cmp_b.push(99); i8_cmp_b.push(111); i8_cmp_b.push(121);
    i8_cmp_b.push(0); i8_cmp_b.push(1); i8_cmp_b.push(127); i8_cmp_b.push(-128);
    int8[] i8_cmp_dst;
    fill_i8(i8_cmp_dst, 16, 0);
    simd_cmp_eq_i8(i8_cmp_a, i8_cmp_b, i8_cmp_dst);
    // 0xFF = -1 in int8
    check("simd_cmp_eq_i8[0] == 0 (10!=0)",     i8_cmp_dst.get(0) == 0);
    check("simd_cmp_eq_i8[1] == -1 (20==20)",   i8_cmp_dst.get(1) == cast<int8>(-1));
    check("simd_cmp_eq_i8[5] == -1 (60==60)",   i8_cmp_dst.get(5) == cast<int8>(-1));
    check("simd_cmp_eq_i8[12] == -1 (0==0)",    i8_cmp_dst.get(12) == cast<int8>(-1));
    check("simd_cmp_eq_i8[14] == -1 (127==127)", i8_cmp_dst.get(14) == cast<int8>(-1));
    check("simd_cmp_eq_i8[15] == -1 (-128==-128)", i8_cmp_dst.get(15) == cast<int8>(-1));
    check("simd_cmp_eq_i8[2] == 0 (30!=31)",    i8_cmp_dst.get(2) == 0);

    // simd_movemask_i8(a) -> int64 — bit i = sign bit of a[i]
    // Sign bit is set when a[i] < 0 (in int8).
    // For [10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120, 0, -1, 127, -128]
    // Negative at indices: 13 (-1), 15 (-128). Bits 13 and 15.
    // Mask = (1<<13) | (1<<15) = 8192 | 32768 = 40960
    int64 mask = simd_movemask_i8(i8_cmp_a);
    check("simd_movemask_i8 has bits 13+15 set", mask == 40960);

    // Test with all-positive → mask == 0
    int8[] pos_only;
    pos_only.push(1); pos_only.push(2); pos_only.push(3); pos_only.push(4);
    pos_only.push(5); pos_only.push(6); pos_only.push(7); pos_only.push(8);
    pos_only.push(9); pos_only.push(10); pos_only.push(11); pos_only.push(12);
    pos_only.push(13); pos_only.push(14); pos_only.push(15); pos_only.push(16);
    int64 mask_zero = simd_movemask_i8(pos_only);
    check("simd_movemask_i8 all-positive == 0", mask_zero == 0);

    // Test with all-negative → mask has all 16 bits set = 0xFFFF = 65535
    int8[] neg_only;
    fill_i8(neg_only, 16, cast<int8>(-1));
    int64 mask_all = simd_movemask_i8(neg_only);
    check("simd_movemask_i8 all-negative == 65535", mask_all == 65535);

    // simd_shuffle_i8(src, mask, dst) — pshufb semantics per 16-byte block
    // With pshufb, mask byte bit 7 set → dst byte = 0; otherwise
    // dst[i] = src[mask[i] & 0x0F] (within each 16-byte block).
    int8[] shuf_src;
    shuf_src.push(0); shuf_src.push(10); shuf_src.push(20); shuf_src.push(30);
    shuf_src.push(40); shuf_src.push(50); shuf_src.push(60); shuf_src.push(70);
    shuf_src.push(80); shuf_src.push(90); shuf_src.push(100); shuf_src.push(110);
    shuf_src.push(120); shuf_src.push(-128); shuf_src.push(-64); shuf_src.push(-32);
    // Mask: reverse order within block + zero some entries
    int8[] shuf_mask;
    // Reverse the 16 bytes: shuffle index 15, 14, ..., 0
    shuf_mask.push(15); shuf_mask.push(14); shuf_mask.push(13); shuf_mask.push(12);
    shuf_mask.push(11); shuf_mask.push(10); shuf_mask.push(9); shuf_mask.push(8);
    shuf_mask.push(7); shuf_mask.push(6); shuf_mask.push(5); shuf_mask.push(4);
    shuf_mask.push(3); shuf_mask.push(2); shuf_mask.push(1); shuf_mask.push(0);
    int8[] shuf_dst;
    fill_i8(shuf_dst, 16, 0);
    simd_shuffle_i8(shuf_src, shuf_mask, shuf_dst);
    check("simd_shuffle_i8[0] == -32 (src[15])",  shuf_dst.get(0) == -32);
    check("simd_shuffle_i8[1] == -64 (src[14])",  shuf_dst.get(1) == -64);
    check("simd_shuffle_i8[14] == 10 (src[1])",   shuf_dst.get(14) == 10);
    check("simd_shuffle_i8[15] == 0 (src[0])",    shuf_dst.get(15) == 0);

    // Mask with high bit set → zero that lane
    int8[] zero_mask;
    fill_i8(zero_mask, 16, cast<int8>(0x80));  // all high bits set → all zero
    int8[] zero_dst;
    fill_i8(zero_dst, 16, 0);
    simd_shuffle_i8(shuf_src, zero_mask, zero_dst);
    check("simd_shuffle_i8 with 0x80 mask gives all zeros",
          zero_dst.get(0) == 0 && zero_dst.get(7) == 0 && zero_dst.get(15) == 0);
}

// ============================================================================
// 7. int16 / uint16 — 8 lanes
// ============================================================================

void test_i16() {
    section("int16 / uint16");

    int16[] a;
    int16[] b;
    a.push(100); a.push(200); a.push(300); a.push(400);
    a.push(500); a.push(600); a.push(700); a.push(800);
    b.push(10); b.push(20); b.push(30); b.push(40);
    b.push(50); b.push(60); b.push(70); b.push(80);
    int16[] dst;
    fill_i16(dst, 8, 0);

    // simd_add_i16
    simd_add_i16(a, b, dst);
    check("simd_add_i16[0] == 110",   dst.get(0) == 110);
    check("simd_add_i16[4] == 550",   dst.get(4) == 550);
    check("simd_add_i16[7] == 880",   dst.get(7) == 880);

    // simd_sub_i16
    simd_sub_i16(a, b, dst);
    check("simd_sub_i16[0] == 90",    dst.get(0) == 90);
    check("simd_sub_i16[3] == 360",   dst.get(3) == 360);
    check("simd_sub_i16[7] == 720",   dst.get(7) == 720);

    // simd_mul_i16
    simd_mul_i16(a, b, dst);
    check("simd_mul_i16[0] == 1000",   dst.get(0) == 1000);
    check("simd_mul_i16[2] == 9000",   dst.get(2) == 9000);
    check("simd_mul_i16[7] == 64000",  dst.get(7) == 64000);

    // Wrapping test for i16: 32767 + 1 = -32768
    // simd_add_i16 with wrap
    int16[] wrap_a;
    int16[] wrap_b;
    wrap_a.push(32767); wrap_a.push(-32768); wrap_a.push(100); wrap_a.push(-1);
    wrap_a.push(0); wrap_a.push(20000); wrap_a.push(-20000); wrap_a.push(-16384);
    wrap_b.push(1); wrap_b.push(-1); wrap_b.push(200); wrap_b.push(-32767);
    wrap_b.push(0); wrap_b.push(20000); wrap_b.push(-20000); wrap_b.push(-16384);
    int16[] wrap_dst;
    fill_i16(wrap_dst, 8, 0);
    simd_add_i16(wrap_a, wrap_b, wrap_dst);
    check("simd_add_i16 wrap: 32767+1 == -32768", wrap_dst.get(0) == -32768);
    check("simd_add_i16 wrap: -32768+(-1) == 32767", wrap_dst.get(1) == 32767);
    check("simd_add_i16 normal: -1+(-32767) == -32768", wrap_dst.get(3) == -32768);
    check("simd_add_i16: 20000+20000 == 40000", wrap_dst.get(5) == 40000);
}

// ============================================================================
// 8. int32 / uint32 — 4 lanes
// ============================================================================

void test_i32() {
    section("int32 / uint32");

    int32[] a;
    int32[] b;
    a.push(1000); a.push(2000); a.push(3000); a.push(4000);
    a.push(5000); a.push(6000); a.push(7000); a.push(8000);
    b.push(100); b.push(200); b.push(300); b.push(400);
    b.push(500); b.push(600); b.push(700); b.push(800);
    int32[] dst;
    fill_i32(dst, 8, 0);

    // simd_add_i32
    simd_add_i32(a, b, dst);
    check("simd_add_i32[0] == 1100",   dst.get(0) == 1100);
    check("simd_add_i32[3] == 4400",   dst.get(3) == 4400);
    check("simd_add_i32[7] == 8800",   dst.get(7) == 8800);

    // simd_sub_i32
    simd_sub_i32(a, b, dst);
    check("simd_sub_i32[0] == 900",    dst.get(0) == 900);
    check("simd_sub_i32[5] == 5400",   dst.get(5) == 5400);
    check("simd_sub_i32[7] == 7200",   dst.get(7) == 7200);

    // simd_mul_i32
    simd_mul_i32(a, b, dst);
    check("simd_mul_i32[0] == 100000",   dst.get(0) == 100000);
    check("simd_mul_i32[3] == 1600000",  dst.get(3) == 1600000);
    check("simd_mul_i32[7] == 6400000",  dst.get(7) == 6400000);
}

// ============================================================================
// 9. float32 — 4 lanes
// ============================================================================

void test_f32() {
    section("float32 4-lane");

    // a = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]
    // b = [0.5, 1.5, 2.5, 3.5, 4.5, 5.5, 6.5, 7.5]
    float32[] a;
    float32[] b;
    a.push(1.0); a.push(2.0); a.push(3.0); a.push(4.0);
    a.push(5.0); a.push(6.0); a.push(7.0); a.push(8.0);
    b.push(0.5); b.push(1.5); b.push(2.5); b.push(3.5);
    b.push(4.5); b.push(5.5); b.push(6.5); b.push(7.5);
    float32[] dst;
    fill_f32(dst, 8, 0.0);

    // simd_add_f32
    simd_add_f32(a, b, dst);
    check("simd_add_f32[0] == 1.5",  feq32(cast<float64>(dst.get(0)), 1.5));
    check("simd_add_f32[3] == 7.5",  feq32(cast<float64>(dst.get(3)), 7.5));
    check("simd_add_f32[7] == 15.5", feq32(cast<float64>(dst.get(7)), 15.5));

    // simd_sub_f32
    simd_sub_f32(a, b, dst);
    check("simd_sub_f32[0] == 0.5",  feq32(cast<float64>(dst.get(0)), 0.5));
    check("simd_sub_f32[4] == 0.5",  feq32(cast<float64>(dst.get(4)), 0.5));
    check("simd_sub_f32[7] == 0.5",  feq32(cast<float64>(dst.get(7)), 0.5));

    // simd_mul_f32
    simd_mul_f32(a, b, dst);
    check("simd_mul_f32[0] == 0.5",    feq32(cast<float64>(dst.get(0)), 0.5));
    check("simd_mul_f32[2] == 7.5",    feq32(cast<float64>(dst.get(2)), 7.5));
    check("simd_mul_f32[7] == 60.0",   feq32(cast<float64>(dst.get(7)), 60.0));

    // simd_div_f32
    simd_div_f32(a, b, dst);
    check("simd_div_f32[0] == 2.0",    feq32(cast<float64>(dst.get(0)), 2.0));
    check("simd_div_f32[2] == 1.2",    feq32(cast<float64>(dst.get(2)), 1.2));
    check("simd_div_f32[7] == 1.066666", feq32(cast<float64>(dst.get(7)), 1.066666));

    // simd_sqrt_f32
    float32[] sqrt_src;
    sqrt_src.push(0.0); sqrt_src.push(1.0); sqrt_src.push(4.0); sqrt_src.push(9.0);
    sqrt_src.push(16.0); sqrt_src.push(25.0); sqrt_src.push(36.0); sqrt_src.push(49.0);
    simd_sqrt_f32(sqrt_src, dst);
    check("simd_sqrt_f32[0] == 0",  feq32(cast<float64>(dst.get(0)), 0.0));
    check("simd_sqrt_f32[1] == 1",  feq32(cast<float64>(dst.get(1)), 1.0));
    check("simd_sqrt_f32[3] == 3",  feq32(cast<float64>(dst.get(3)), 3.0));
    check("simd_sqrt_f32[7] == 7",  feq32(cast<float64>(dst.get(7)), 7.0));

    // simd_min_f32
    float32[] min_a;
    float32[] min_b;
    min_a.push(10.0); min_a.push(1.0); min_a.push(30.0); min_a.push(0.5);
    min_a.push(99.0); min_a.push(60.0); min_a.push(3.0); min_a.push(80.0);
    min_b.push(1.0); min_b.push(50.0); min_b.push(3.0); min_b.push(40.0);
    min_b.push(10.0); min_b.push(6.0); min_b.push(70.0); min_b.push(8.0);
    simd_min_f32(min_a, min_b, dst);
    check("simd_min_f32[0] == 1",     feq32(cast<float64>(dst.get(0)), 1.0));
    check("simd_min_f32[1] == 1",     feq32(cast<float64>(dst.get(1)), 1.0));
    check("simd_min_f32[4] == 10",    feq32(cast<float64>(dst.get(4)), 10.0));
    check("simd_min_f32[6] == 3",     feq32(cast<float64>(dst.get(6)), 3.0));

    // simd_max_f32
    simd_max_f32(min_a, min_b, dst);
    check("simd_max_f32[0] == 10",    feq32(cast<float64>(dst.get(0)), 10.0));
    check("simd_max_f32[2] == 30",    feq32(cast<float64>(dst.get(2)), 30.0));
    check("simd_max_f32[5] == 60",    feq32(cast<float64>(dst.get(5)), 60.0));
    check("simd_max_f32[7] == 80",    feq32(cast<float64>(dst.get(7)), 80.0));

    // simd_abs_f32
    float32[] neg_src;
    neg_src.push(-5.0); neg_src.push(3.0); neg_src.push(-10.0); neg_src.push(0.0);
    neg_src.push(-0.5); neg_src.push(100.0); neg_src.push(-1.0); neg_src.push(-999.0);
    simd_abs_f32(neg_src, dst);
    check("simd_abs_f32[0] == 5",     feq32(cast<float64>(dst.get(0)), 5.0));
    check("simd_abs_f32[2] == 10",    feq32(cast<float64>(dst.get(2)), 10.0));
    check("simd_abs_f32[3] == 0",     feq32(cast<float64>(dst.get(3)), 0.0));
    check("simd_abs_f32[7] == 999",   feq32(cast<float64>(dst.get(7)), 999.0));

    // simd_dot_f32(a, b) -> float64
    // a = [1,2,3,4,5,6,7,8], b = [0.5,1.5,2.5,3.5,4.5,5.5,6.5,7.5]
    // dot = 1*0.5 + 2*1.5 + 3*2.5 + 4*3.5 + 5*4.5 + 6*5.5 + 7*6.5 + 8*7.5
    //     = 0.5 + 3.0 + 7.5 + 14.0 + 22.5 + 33.0 + 45.5 + 60.0 = 186.0
    float64 dot_f32 = simd_dot_f32(a, b);
    check("simd_dot_f32(a, b) == 186", feq32(dot_f32, 186.0));

    // simd_sum_f32(a) -> float64 = 1+2+3+4+5+6+7+8 = 36
    float64 sum_f32 = simd_sum_f32(a);
    check("simd_sum_f32(a) == 36", feq32(sum_f32, 36.0));
}

// ============================================================================
// 10. Bitwise — any stride-1 array
// ============================================================================

void test_bitwise() {
    section("Bitwise (uint8[] stride-1)");

    // uint8[] a = [0x0F, 0xF0, 0xAA, 0x55, 0xFF, 0x00, 0xCC, 0x33,
    //              0x0F, 0xF0, 0xAA, 0x55, 0xFF, 0x00, 0xCC, 0x33]
    // uint8[] b = [0xF0, 0x0F, 0x55, 0xAA, 0x00, 0xFF, 0x33, 0xCC,
    //              0xF0, 0x0F, 0x55, 0xAA, 0x00, 0xFF, 0x33, 0xCC]
    uint8[] a;
    uint8[] b;
    a.push(0x0F); a.push(0xF0); a.push(0xAA); a.push(0x55);
    a.push(0xFF); a.push(0x00); a.push(0xCC); a.push(0x33);
    a.push(0x0F); a.push(0xF0); a.push(0xAA); a.push(0x55);
    a.push(0xFF); a.push(0x00); a.push(0xCC); a.push(0x33);
    b.push(0xF0); b.push(0x0F); b.push(0x55); b.push(0xAA);
    b.push(0x00); b.push(0xFF); b.push(0x33); b.push(0xCC);
    b.push(0xF0); b.push(0x0F); b.push(0x55); b.push(0xAA);
    b.push(0x00); b.push(0xFF); b.push(0x33); b.push(0xCC);

    uint8[] dst;
    fill_u8(dst, 16, 0);

    // simd_and — a & b
    // 0x0F & 0xF0 = 0x00, 0xF0 & 0x0F = 0x00, 0xAA & 0x55 = 0x00, 0x55 & 0xAA = 0x00
    // 0xFF & 0x00 = 0x00, 0x00 & 0xFF = 0x00, 0xCC & 0x33 = 0x00, 0x33 & 0xCC = 0x00
    simd_and(a, b, dst);
    check("simd_and[0] == 0x00 (0x0F & 0xF0)",  dst.get(0) == 0x00);
    check("simd_and[2] == 0x00 (0xAA & 0x55)",  dst.get(2) == 0x00);
    check("simd_and[4] == 0x00 (0xFF & 0x00)",  dst.get(4) == 0x00);
    check("simd_and[6] == 0x00 (0xCC & 0x33)",  dst.get(6) == 0x00);

    // Test AND with matching values
    uint8[] all_ff;
    fill_u8(all_ff, 16, 0xFF);
    simd_and(a, all_ff, dst);
    check("simd_and with 0xFF preserves value[0]", dst.get(0) == 0x0F);
    check("simd_and with 0xFF preserves value[2]", dst.get(2) == 0xAA);

    // simd_or — a | b
    // 0x0F | 0xF0 = 0xFF, 0xF0 | 0x0F = 0xFF, 0xAA | 0x55 = 0xFF
    // 0xFF | 0x00 = 0xFF, 0xCC | 0x33 = 0xFF
    simd_or(a, b, dst);
    check("simd_or[0] == 0xFF (0x0F | 0xF0)",  dst.get(0) == 0xFF);
    check("simd_or[5] == 0xFF (0x00 | 0xFF)",  dst.get(5) == 0xFF);
    check("simd_or[7] == 0xFF (0x33 | 0xCC)",  dst.get(7) == 0xFF);

    // simd_xor — a ^ b
    // 0x0F ^ 0xF0 = 0xFF, 0xF0 ^ 0x0F = 0xFF, 0xAA ^ 0x55 = 0xFF
    // 0xFF ^ 0x00 = 0xFF, 0xCC ^ 0x33 = 0xFF
    simd_xor(a, b, dst);
    check("simd_xor[0] == 0xFF (0x0F ^ 0xF0)",  dst.get(0) == 0xFF);
    check("simd_xor[3] == 0xFF (0x55 ^ 0xAA)",  dst.get(3) == 0xFF);
    check("simd_xor[6] == 0xFF (0xCC ^ 0x33)",  dst.get(6) == 0xFF);

    // XOR with self = 0
    simd_xor(a, a, dst);
    check("simd_xor a ^ a == 0 at [0]",  dst.get(0) == 0x00);
    check("simd_xor a ^ a == 0 at [7]",  dst.get(7) == 0x00);
    check("simd_xor a ^ a == 0 at [15]", dst.get(15) == 0x00);
}

// ============================================================================
// Main — call all test sections
// ============================================================================

int32 main() {
    print_console("=== SIMD addon comprehensive test ===");

    test_elementwise_f64();
    test_reductions();
    test_compare();
    test_elementwise_i64();
    test_memory();
    test_i8();
    test_i16();
    test_i32();
    test_f32();
    test_bitwise();

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
