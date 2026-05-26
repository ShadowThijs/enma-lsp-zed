// =============================================================================
// Bits Addon -- Comprehensive Test File
// =============================================================================
// Registered with: register_addon_bits(engine)
//
// All operations treat the input as an unsigned bit pattern. 64-bit variants
// operate on the full int64. _i32 variants mask to the low 32 bits first.
//
// COMPLETE API CHECKLIST
// ======================
//
// TYPES: (none -- all standalone functions)
//
// STANDALONE FUNCTIONS (26 total):
//
//   Population count (2):
//   [x] popcount(v)        -> int64   -- count set bits (64-bit)
//   [x] popcount_i32(v)    -> int64   -- count set bits (masked to low 32)
//
//   Leading / trailing zeros (4):
//   [x] clz(v)             -> int64   -- count leading zeros (64-bit)
//   [x] clz_i32(v)         -> int64   -- count leading zeros (masked to low 32)
//   [x] ctz(v)             -> int64   -- count trailing zeros (64-bit)
//   [x] ctz_i32(v)         -> int64   -- count trailing zeros (masked to low 32)
//
//   Rotates (4):
//   [x] rotl(v, n)         -> int64   -- rotate left (64-bit)
//   [x] rotr(v, n)         -> int64   -- rotate right (64-bit)
//   [x] rotl_i32(v, n)     -> int64   -- rotate left (masked to low 32)
//   [x] rotr_i32(v, n)     -> int64   -- rotate right (masked to low 32)
//
//   Byte swap (2):
//   [x] bswap(v)           -> int64   -- byte swap (64-bit)
//   [x] bswap_i32(v)       -> int64   -- byte swap (32-bit)
//
//   Parity (1):
//   [x] parity(v)          -> int64   -- 1 if odd set bits, else 0
//
//   Bit reverse (2):
//   [x] bit_reverse(v)     -> int64   -- reverse bit pattern (64-bit)
//   [x] bit_reverse_i32(v) -> int64   -- reverse within low 32 bits
//
//   Single-bit ops (4):
//   [x] set_bit(v, bit)    -> int64   -- set bit position
//   [x] clear_bit(v, bit)  -> int64   -- clear bit position
//   [x] toggle_bit(v, bit) -> int64   -- flip bit position
//   [x] test_bit(v, bit)   -> int64   -- 1 if bit set, else 0
//
//   Bit-range extract / insert (2):
//   [x] extract_bits(v, lo, hi) -> int64  -- extract inclusive range [lo, hi]
//   [x] insert_bits(v, val, lo, hi) -> int64 -- overwrite range with val
//
//   Power-of-two helpers (3):
//   [x] is_pow2(v)         -> bool   -- true if v is a power of two
//   [x] next_pow2(v)       -> int64  -- smallest pow2 >= v (1 if v <= 1)
//   [x] prev_pow2(v)       -> int64  -- largest pow2 <= v (0 if v == 0)
//
//   Alignment (2):
//   [x] align_up(v, n)     -> int64  -- round up to multiple of n
//   [x] align_down(v, n)   -> int64  -- round down to multiple of n
// =============================================================================


// =============================================================================
// 1. Population count
// =============================================================================

int64 popcnt_ff   = popcount(0xFF)         // Expected: 8 (eight 1 bits)
int64 popcnt_all  = popcount(-1)           // Expected: 64 (all bits set)
int64 popcnt_zero = popcount(0)            // Expected: 0 (no bits set)

int64 popcnt_i32_all = popcount_i32(-1)    // Expected: 32 (masked to low 32)
int64 popcnt_i32_ff  = popcount_i32(0xFF)  // Expected: 8


// =============================================================================
// 2. Leading / trailing zeros
// =============================================================================

// --- clz (count leading zeros, 64-bit) ---
int64 clz_one  = clz(1)                    // Expected: 63
int64 clz_zero = clz(0)                    // Expected: 64 (bit width for zero)
int64 clz_high = clz(0x8000000000000000)   // Expected: 0

// --- clz_i32 (count leading zeros, masked to low 32) ---
int64 clz_i32_one  = clz_i32(1)            // Expected: 31
int64 clz_i32_zero = clz_i32(0)            // Expected: 32
int64 clz_i32_high = clz_i32(0x80000000)   // Expected: 0

// --- ctz (count trailing zeros, 64-bit) ---
int64 ctz_256   = ctz(256)                 // Expected: 8  (bit 8 is first set)
int64 ctz_one   = ctz(1)                   // Expected: 0  (bit 0 is set)
int64 ctz_zero  = ctz(0)                   // Expected: 64 (bit width for zero)
int64 ctz_pow2  = ctz(0x8000000000000000)  // Expected: 63

// --- ctz_i32 (count trailing zeros, masked to low 32) ---
int64 ctz_i32_4k   = ctz_i32(cast<int64>(0x00001000)) // Expected: 12
int64 ctz_i32_one  = ctz_i32(1)                       // Expected: 0
int64 ctz_i32_zero = ctz_i32(0)                       // Expected: 32


// =============================================================================
// 3. Rotates
// =============================================================================

// --- rotl / rotr (64-bit) ---
int64 rotl_a = rotl(0x12345678, 4)
int64 rotr_b = rotr(rotl_a, 4)             // Expected: 0x12345678 (round trip)

int64 rotl_zero = rotl(0, 16)              // Expected: 0
int64 rotl_full = rotl(0xFFFFFFFFFFFFFFFF, 8)  // Expected: 0xFFFFFFFFFFFFFFFF

int64 rotr_zero = rotr(0, 16)              // Expected: 0

// --- rotl_i32 / rotr_i32 (masked to low 32) ---
int64 rotl_i32_v   = rotl_i32(0x12345678, 8)    // Expected: 0x34567812
int64 rotl_i32_wrap = rotl_i32(0x12345678, 32)  // Expected: 0x12345678 (full wrap)

int64 rotr_i32_v     = rotr_i32(0x34567812, 8)   // Expected: 0x12345678 (round trip)
int64 rotr_i32_wrap  = rotr_i32(0x12345678, 32)  // Expected: 0x12345678 (full wrap)


// =============================================================================
// 4. Byte swap
// =============================================================================

int64 bswap_v   = bswap(0x0102030405060708)     // Expected: 0x0807060504030201
int64 bswap_i32 = bswap_i32(0x12345678)         // Expected: 0x78563412

int64 bswap_zero   = bswap(0)                   // Expected: 0
int64 bswap_i32_ff = bswap_i32(0xFFFFFFFF)      // Expected: 0xFFFFFFFF


// =============================================================================
// 5. Parity
// =============================================================================

int64 parity_odd  = parity(7)                // Expected: 1  (three 1s)
int64 parity_even = parity(3)                // Expected: 0  (two 1s)
int64 parity_zero = parity(0)                // Expected: 0  (zero 1s)
int64 parity_one  = parity(1)                // Expected: 1  (one 1)


// =============================================================================
// 6. Bit reverse
// =============================================================================

int64 bitrev_1   = bit_reverse(1)                // Expected: 0x8000000000000000
int64 bitrev_80  = bit_reverse(0x8000000000000000)  // Expected: 1 (round trip)
int64 bitrev_0   = bit_reverse(0)                // Expected: 0

int64 bitrev_i32_1  = bit_reverse_i32(1)         // Expected: 0x80000000
int64 bitrev_i32_0  = bit_reverse_i32(0)         // Expected: 0
int64 bitrev_i32_ff = bit_reverse_i32(0xFFFF0000)
int64 bitrev_round  = bit_reverse_i32(0x80000000)   // Expected: 1 (round trip within 32)


// =============================================================================
// 7. Single-bit ops
// =============================================================================

// set_bit
int64 set_bit_0_3  = set_bit(0, 3)           // Expected: 8     (set bit 3)
int64 set_bit_8_0  = set_bit(8, 0)           // Expected: 9     (set bit 0)
int64 set_bit_already = set_bit(8, 3)        // Expected: 8     (bit 3 already set)

// clear_bit
int64 clear_bit_15_1 = clear_bit(15, 1)      // Expected: 13    (clear bit 1 from 1111 -> 1101)
int64 clear_bit_already_clear = clear_bit(8, 0)  // Expected: 8  (bit 0 already clear)
int64 clear_bit_0_0  = clear_bit(0, 0)       // Expected: 0

// toggle_bit
int64 toggle_5_1    = toggle_bit(5, 1)       // Expected: 7     (flip bit 1: 101 -> 111)
int64 toggle_5_1_again = toggle_bit(7, 1)    // Expected: 5     (flip bit 1: 111 -> 101)
int64 toggle_0_3    = toggle_bit(0, 3)       // Expected: 8     (flip bit 3: 0 -> 1)

// test_bit
int64 test_4_2      = test_bit(4, 2)         // Expected: 1     (bit 2 is set in 4)
int64 test_4_1      = test_bit(4, 1)         // Expected: 0     (bit 1 is not set in 4)
int64 test_0_any    = test_bit(0, 5)         // Expected: 0
int64 test_high     = test_bit(0x8000000000000000, 63)  // Expected: 1


// =============================================================================
// 8. Bit-range extract / insert
// =============================================================================

// extract_bits(v, lo, hi) -- inclusive range [lo, hi]
int64 extract_lo  = extract_bits(0xDEAD, 0, 7)    // Expected: 0xAD  (bits 0..7)
int64 extract_hi  = extract_bits(0xDEAD, 8, 15)   // Expected: 0xDE  (bits 8..15)
int64 extract_mid = extract_bits(0xDEAD, 4, 11)   // bits 4..11 of 0xDEAD
int64 extract_single = extract_bits(0xFF, 3, 3)   // single bit
int64 extract_zero   = extract_bits(0, 0, 31)     // Expected: 0

// insert_bits(v, val, lo, hi) -- overwrite range with val
int64 insert_lo  = insert_bits(0xFF00, 0xAB, 0, 7)  // Expected: 0xFFAB
int64 insert_mid = insert_bits(0xFFFF, 0x00, 4, 11) // clear middle bits
int64 insert_full = insert_bits(0xFFFF, 0xAAAA, 0, 15) // replace low 16


// =============================================================================
// 9. Power-of-two helpers
// =============================================================================

// is_pow2(v) -> bool
bool is_pow2_16   = is_pow2(16)             // Expected: true
bool is_pow2_1    = is_pow2(1)              // Expected: true
bool is_pow2_0    = is_pow2(0)              // Expected: false
bool is_pow2_3    = is_pow2(3)              // Expected: false
bool is_pow2_neg  = is_pow2(-1)             // Expected: false

// next_pow2(v)  (smallest pow2 >= v; 1 if v <= 1)
int64 next_5     = next_pow2(5)             // Expected: 8
int64 next_16    = next_pow2(16)            // Expected: 16 (already pow2)
int64 next_1     = next_pow2(1)             // Expected: 1
int64 next_0     = next_pow2(0)             // Expected: 1 (v <= 1)
int64 next_large = next_pow2(1000)          // Expected: 1024

// prev_pow2(v)  (largest pow2 <= v; 0 if v == 0)
int64 prev_17    = prev_pow2(17)            // Expected: 16
int64 prev_16    = prev_pow2(16)            // Expected: 16 (exact pow2)
int64 prev_1     = prev_pow2(1)             // Expected: 1
int64 prev_0     = prev_pow2(0)             // Expected: 0 (v == 0)
int64 prev_1000  = prev_pow2(1000)          // Expected: 512


// =============================================================================
// 10. Alignment
// =============================================================================

// align_up(v, n) -- round up to multiple of n
int64 align_up_13_8  = align_up(13, 8)      // Expected: 16
int64 align_up_16_8  = align_up(16, 8)      // Expected: 16 (already aligned)
int64 align_up_0_8   = align_up(0, 8)       // Expected: 0
int64 align_up_1_1   = align_up(1, 1)       // Expected: 1
int64 align_up_5_16  = align_up(5, 16)      // Expected: 16
int64 align_up_32_32 = align_up(32, 32)     // Expected: 32

// align_down(v, n) -- round down to multiple of n
int64 align_down_13_8  = align_down(13, 8)  // Expected: 8
int64 align_down_16_8  = align_down(16, 8)  // Expected: 16 (already aligned)
int64 align_down_0_8   = align_down(0, 8)   // Expected: 0
int64 align_down_7_16  = align_down(7, 16)  // Expected: 0 (below first multiple)
int64 align_down_32_32 = align_down(32, 32) // Expected: 32


// =============================================================================
// Cross-section: combining multiple bit ops
// =============================================================================

// Extract, modify, re-insert
int64 orig   = 0xAABB
int64 low    = extract_bits(orig, 0, 7)
int64 mod    = insert_bits(orig, 0xCC, 0, 7)

// Test parity of a byte after swapping
int64 swapped  = bswap(0x0102030405060708)
int64 parity_after_bswap = parity(swapped)

// Power-of-two alignment via next_pow2 then align
int64 p2    = next_pow2(37)
int64 up    = align_up(37, p2)

// Extract then test bits in the extracted value
int64 ex     = extract_bits(0xF0F0, 4, 7)
int64 test_ex = test_bit(ex, 0)

// Rotate and then extract
int64 rot    = rotl(0xDEAD, 8)
int64 ex_rot = extract_bits(rot, 0, 15)
