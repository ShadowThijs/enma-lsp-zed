// =============================================================================
// Sorted Map Addon — comprehensive coverage test
//
// Exercises every type, method, bound/range query, and edge case documented
// in the Sorted Map API specification.
//
// --- Registration ---
//   register_addon_sorted_map(engine)    C++ engine registration.
//
// --- Type ---
//   sorted_map<K, V>                     Ordered map; O(log n)
//                                        put/get/contains/remove.
//                                        K and V must be 64-bit scalar types:
//                                        int64, bool, float-bits, pointer.
//                                        Not suitable for string keys.
//
// --- Core methods ---
//   void   m.set(K k, V v)               Insert or overwrite.
//   V      m.get(K k)                    0 if missing.
//   bool   m.contains(K k)
//   bool   m.remove(K k)                 true if k was present.
//   int64  m.size()
//   void   m.clear()
//   array  m.keys()                      Sorted.
//   array  m.values()                    Values in key order.
//   K      m.first_key()                 Smallest; 0 if empty.
//   K      m.last_key()                  Largest; 0 if empty.
//
// --- Bound / range queries ---
//   K      m.lower_bound(K k)            Smallest key >= k; 0 if none.
//   K      m.upper_bound(K k)            Smallest key >  k; 0 if none.
//   K      m.floor_key(K k)              Largest  key <= k; 0 if none.
//   K      m.ceiling_key(K k)            Alias of lower_bound.
//   array  m.range_keys(K lo, K hi)      Keys in [lo, hi).
//   array  m.range_values(K lo, K hi)    Values for those keys.
//
// --- Key/value type constraints ---
//   K and V each must fit in 64 bits and order/equate by raw bits.
//   Works for: int64, bool, float-bits, pointer.
//   Not suitable for string keys.
//
// --- Sentinel ---
//   0 means "no key". Call contains() first if 0 is a valid key in your map.
//
// --- Edge cases covered ---
//   - Empty map      (size 0, first_key/last_key 0, all queries safe)
//   - Single element (first_key == last_key)
//   - Duplicate key / overwrite via set
//   - Missing key    (get returns 0, remove returns false)
//   - Clear and re-use
//   - Range: lo == hi (empty)
//   - Range: no keys in interval
//   - Range: all keys
//   - lower_bound / upper_bound at start, middle, end, past-end
//   - floor_key / ceiling_key at various positions
//   - bool value type
//   - Sentinel 0 as valid key (check with contains())
//   - keys() returns sorted order
//   - values() returns key order
// =============================================================================

int64 g_pass = 0;
int64 g_fail = 0;
int64 g_handle = 0;
int64 g_done = 0;

sidebar_section_t g_section;
button_t          g_btn;
menu_t            g_menu;

// ---------------------------------------------------------------------------
// Test harness helpers
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Helper: dump map contents for diagnostic output
// ---------------------------------------------------------------------------

void dump_map(string label, sorted_map<int64, int64> m) {
    string msg = "  " + label + " {";
    array ks = m.keys();
    array vs = m.values();
    int64 ii = 0;
    while (ii < cast<int64>(ks.length())) {
        if (ii > 0) msg = msg + ", ";
        msg = msg + cast<string>(cast<int64>(ks.get(ii))) + ":"
            + cast<string>(cast<int64>(vs.get(ii)));
        ii = ii + 1;
    }
    msg = msg + "}  size=" + cast<string>(m.size());
    print_console(msg);
}

// ===========================================================================
// Test routine
// ===========================================================================

void test_routine(int64 data) {
    if (g_done == 1) return;
    g_done = 1;

    print_console("=== Sorted Map Addon — Full Coverage Test ===");

    // -----------------------------------------------------------------------
    // SECTION 1 — Empty map behaviour
    // Every method must tolerate an empty map without crashing.
    // -----------------------------------------------------------------------

    section("1. Empty map");

    sorted_map<int64, int64> empty;

    check("empty.size() == 0",               empty.size() == 0);
    check("empty.first_key() == 0",          empty.first_key() == 0);
    check("empty.last_key() == 0",           empty.last_key() == 0);
    check("empty.contains(1) == false",     !empty.contains(1));
    check("empty.get(1) == 0",               empty.get(1) == 0);
    check("empty.remove(1) == false",       !empty.remove(1));
    check("empty.keys().length() == 0",      empty.keys().length() == 0);
    check("empty.values().length() == 0",    empty.values().length() == 0);
    check("empty.lower_bound(5) == 0",       empty.lower_bound(5) == 0);
    check("empty.upper_bound(5) == 0",       empty.upper_bound(5) == 0);
    check("empty.floor_key(5) == 0",         empty.floor_key(5) == 0);
    check("empty.ceiling_key(5) == 0",       empty.ceiling_key(5) == 0);
    check("empty.range_keys(0, 10).len == 0", empty.range_keys(0, 10).length() == 0);
    check("empty.range_values(0, 10).len == 0", empty.range_values(0, 10).length() == 0);

    // -----------------------------------------------------------------------
    // SECTION 2 — Basic insertion, retrieval, and size
    // Tests: set, get, size, contains
    // -----------------------------------------------------------------------

    section("2. Basic insertion and retrieval");

    sorted_map<int64, int64> m;

    m.set(3, 300);
    m.set(1, 100);
    m.set(2, 200);
    dump_map("after set(3,300) set(1,100) set(2,200)", m);

    check("size() == 3 after 3 inserts",     m.size() == 3);
    check("get(1) == 100",                   m.get(1) == 100);
    check("get(2) == 200",                   m.get(2) == 200);
    check("get(3) == 300",                   m.get(3) == 300);
    check("contains(1)",                     m.contains(1));
    check("contains(2)",                     m.contains(2));
    check("contains(3)",                     m.contains(3));
    check("!contains(99)",                  !m.contains(99));
    check("!contains(0)",                   !m.contains(0));

    // -----------------------------------------------------------------------
    // SECTION 3 — Sorted iteration: keys and values
    // Tests: keys, values (both sorted)
    // -----------------------------------------------------------------------

    section("3. Sorted keys and values");

    array ks = m.keys();
    check("keys().length() == 3",            ks.length() == 3);
    check("keys[0] == 1",                    cast<int64>(ks.get(0)) == 1);
    check("keys[1] == 2",                    cast<int64>(ks.get(1)) == 2);
    check("keys[2] == 3",                    cast<int64>(ks.get(2)) == 3);

    array vs = m.values();
    check("values().length() == 3",          vs.length() == 3);
    check("values[0] == 100 (key 1)",        cast<int64>(vs.get(0)) == 100);
    check("values[1] == 200 (key 2)",        cast<int64>(vs.get(1)) == 200);
    check("values[2] == 300 (key 3)",        cast<int64>(vs.get(2)) == 300);

    // -----------------------------------------------------------------------
    // SECTION 4 — first_key and last_key
    // Tests: first_key, last_key on populated and single-element map
    // -----------------------------------------------------------------------

    section("4. first_key / last_key");

    check("first_key() == 1",                m.first_key() == 1);
    check("last_key() == 3",                 m.last_key() == 3);

    // Single element: first_key == last_key
    sorted_map<int64, int64> single;
    single.set(42, 4200);
    check("single.first_key() == 42",        single.first_key() == 42);
    check("single.last_key() == 42",         single.last_key() == 42);
    check("single.first_key() == last_key()", single.first_key() == single.last_key());

    // -----------------------------------------------------------------------
    // SECTION 5 — Overwrite via set
    // Tests: set overwrites existing key
    // -----------------------------------------------------------------------

    section("5. Overwrite (duplicate key)");

    m.set(2, 250);
    dump_map("after set(2, 250)", m);
    check("size() still 3 after overwrite",  m.size() == 3);
    check("get(2) == 250 after overwrite",   m.get(2) == 250);
    check("get(1) unchanged == 100",         m.get(1) == 100);
    check("get(3) unchanged == 300",         m.get(3) == 300);

    // Restore for subsequent tests
    m.set(2, 200);
    check("restored get(2) == 200",          m.get(2) == 200);

    // -----------------------------------------------------------------------
    // SECTION 6 — Remove
    // Tests: remove on existing key, missing key, size after remove
    // -----------------------------------------------------------------------

    section("6. Remove");

    // Remove the middle key
    bool r1 = m.remove(2);
    check("remove(2) returns true",          r1);
    check("size() == 2 after remove",        m.size() == 2);
    check("!contains(2) after remove",      !m.contains(2));
    check("get(2) == 0 after remove",        m.get(2) == 0);
    check("keys().length() == 2",            m.keys().length() == 2);
    check("values().length() == 2",          m.values().length() == 2);

    // Remove again — should return false
    bool r2 = m.remove(2);
    check("remove(2) again returns false",  !r2);

    // Remove first key
    bool r3 = m.remove(1);
    check("remove(1) returns true",          r3);
    check("size() == 1",                     m.size() == 1);

    // Remove last key
    bool r4 = m.remove(3);
    check("remove(3) returns true",          r4);
    check("size() == 0 (fully emptied)",     m.size() == 0);

    // Remove from empty map
    bool r5 = m.remove(1);
    check("remove(1) on empty returns false", !r5);

    // -----------------------------------------------------------------------
    // SECTION 7 — Clear and re-use
    // Tests: clear then re-populate
    // -----------------------------------------------------------------------

    section("7. Clear and re-use");

    sorted_map<int64, int64> m2;
    m2.set(100, 1000);
    m2.set(200, 2000);
    check("before clear: size == 2",         m2.size() == 2);

    m2.clear();
    check("after clear: size == 0",          m2.size() == 0);
    check("after clear: first_key == 0",     m2.first_key() == 0);
    check("after clear: last_key == 0",      m2.last_key() == 0);
    check("after clear: keys empty",         m2.keys().length() == 0);
    check("after clear: values empty",       m2.values().length() == 0);

    // Re-use the cleared map
    m2.set(99, 9999);
    check("re-use after clear: size == 1",   m2.size() == 1);
    check("re-use after clear: get(99) == 9999", m2.get(99) == 9999);

    // -----------------------------------------------------------------------
    // SECTION 8 — Lower bound
    // Tests: lower_bound at various positions
    // -----------------------------------------------------------------------

    section("8. lower_bound");

    sorted_map<int64, int64> lb;
    lb.set(10, 100);
    lb.set(20, 200);
    lb.set(30, 300);
    lb.set(40, 400);
    lb.set(50, 500);
    dump_map("map for bound tests", lb);

    // At exact key
    check("lower_bound(10) == 10 (exact)",   lb.lower_bound(10) == 10);
    check("lower_bound(30) == 30 (exact)",   lb.lower_bound(30) == 30);
    check("lower_bound(50) == 50 (exact)",   lb.lower_bound(50) == 50);

    // Between keys — next larger
    check("lower_bound(25) == 30",           lb.lower_bound(25) == 30);
    check("lower_bound(11) == 20",           lb.lower_bound(11) == 20);
    check("lower_bound(49) == 50",           lb.lower_bound(49) == 50);

    // Before first key
    check("lower_bound(0) == 10",            lb.lower_bound(0) == 10);
    check("lower_bound(5) == 10",            lb.lower_bound(5) == 10);

    // Past last key — none
    check("lower_bound(55) == 0 (none)",     lb.lower_bound(55) == 0);
    check("lower_bound(100) == 0 (none)",    lb.lower_bound(100) == 0);

    // At first key
    check("lower_bound(10) == 10 (first)",   lb.lower_bound(10) == 10);

    // -----------------------------------------------------------------------
    // SECTION 9 — Upper bound
    // Tests: upper_bound at various positions
    // -----------------------------------------------------------------------

    section("9. upper_bound");

    // At exact key — strictly greater
    check("upper_bound(20) == 30",           lb.upper_bound(20) == 30);
    check("upper_bound(10) == 20",           lb.upper_bound(10) == 20);
    check("upper_bound(50) == 0 (past end)", lb.upper_bound(50) == 0);

    // Between keys
    check("upper_bound(25) == 30",           lb.upper_bound(25) == 30);
    check("upper_bound(15) == 20",           lb.upper_bound(15) == 20);

    // Before first key
    check("upper_bound(0) == 10",            lb.upper_bound(0) == 10);
    check("upper_bound(5) == 10",            lb.upper_bound(5) == 10);

    // Past last key
    check("upper_bound(55) == 0 (none)",     lb.upper_bound(55) == 0);

    // -----------------------------------------------------------------------
    // SECTION 10 — Floor key
    // Tests: floor_key at various positions
    // -----------------------------------------------------------------------

    section("10. floor_key");

    // At exact key
    check("floor_key(10) == 10 (exact)",     lb.floor_key(10) == 10);
    check("floor_key(30) == 30 (exact)",     lb.floor_key(30) == 30);
    check("floor_key(50) == 50 (exact)",     lb.floor_key(50) == 50);

    // Between keys — next smaller
    check("floor_key(25) == 20",             lb.floor_key(25) == 20);
    check("floor_key(39) == 30",             lb.floor_key(39) == 30);
    check("floor_key(11) == 10",             lb.floor_key(11) == 10);

    // Before first key — none
    check("floor_key(5) == 0 (none)",        lb.floor_key(5) == 0);
    check("floor_key(0) == 0 (none)",        lb.floor_key(0) == 0);

    // Past last key
    check("floor_key(55) == 50",             lb.floor_key(55) == 50);
    check("floor_key(100) == 50",            lb.floor_key(100) == 50);

    // At last key
    check("floor_key(50) == 50 (last)",      lb.floor_key(50) == 50);

    // -----------------------------------------------------------------------
    // SECTION 11 — Ceiling key (alias of lower_bound)
    // Tests: ceiling_key == lower_bound for same inputs
    // -----------------------------------------------------------------------

    section("11. ceiling_key (alias of lower_bound)");

    check("ceiling_key(25) == 30",           lb.ceiling_key(25) == 30);
    check("ceiling_key(10) == 10 (exact)",   lb.ceiling_key(10) == 10);
    check("ceiling_key(55) == 0 (none)",     lb.ceiling_key(55) == 0);
    check("ceiling_key(0) == 10",            lb.ceiling_key(0) == 10);
    check("ceiling_key(30) == 30",           lb.ceiling_key(30) == 30);

    // Verify ceiling_key matches lower_bound
    check("ceiling(25) == lower_bound(25)",  lb.ceiling_key(25) == lb.lower_bound(25));
    check("ceiling(10) == lower_bound(10)",  lb.ceiling_key(10) == lb.lower_bound(10));
    check("ceiling(55) == lower_bound(55)",  lb.ceiling_key(55) == lb.lower_bound(55));

    // -----------------------------------------------------------------------
    // SECTION 12 — Range keys
    // Tests: range_keys with various intervals
    // -----------------------------------------------------------------------

    section("12. range_keys");

    // Normal range [20, 40)
    array rk1 = lb.range_keys(20, 40);
    check("range_keys(20, 40).length() == 2", rk1.length() == 2);
    if (rk1.length() == 2) {
        check("rk1[0] == 20",                cast<int64>(rk1.get(0)) == 20);
        check("rk1[1] == 30",                cast<int64>(rk1.get(1)) == 30);
    }

    // Range covering all keys
    array rk_all = lb.range_keys(0, 100);
    check("range_keys(0, 100) covers all 5",  rk_all.length() == 5);
    if (rk_all.length() == 5) {
        check("rk_all[0] == 10",             cast<int64>(rk_all.get(0)) == 10);
        check("rk_all[4] == 50",             cast<int64>(rk_all.get(4)) == 50);
    }

    // lo == hi — empty range
    array rk_eq = lb.range_keys(30, 30);
    check("range_keys(30, 30).length() == 0", rk_eq.length() == 0);

    // No keys in interval
    array rk_none = lb.range_keys(15, 19);
    check("range_keys(15, 19).length() == 0", rk_none.length() == 0);

    // Range from first key exactly
    array rk_first = lb.range_keys(10, 30);
    check("range_keys(10, 30).length() == 2", rk_first.length() == 2);
    if (rk_first.length() == 2) {
        check("rk_first[0] == 10",           cast<int64>(rk_first.get(0)) == 10);
        check("rk_first[1] == 20",           cast<int64>(rk_first.get(1)) == 20);
    }

    // Range past last key
    array rk_past = lb.range_keys(60, 100);
    check("range_keys(60, 100).length() == 0", rk_past.length() == 0);

    // Range entirely before first key
    array rk_before = lb.range_keys(1, 9);
    check("range_keys(1, 9).length() == 0",   rk_before.length() == 0);

    // Single key range
    array rk_single = lb.range_keys(20, 21);
    check("range_keys(20, 21).length() == 1", rk_single.length() == 1);
    if (rk_single.length() == 1) {
        check("rk_single[0] == 20",          cast<int64>(rk_single.get(0)) == 20);
    }

    // -----------------------------------------------------------------------
    // SECTION 13 — Range values
    // Tests: range_values with various intervals, verifies key-order matches
    // -----------------------------------------------------------------------

    section("13. range_values");

    // Normal range [20, 40) — expects values for keys 20 and 30
    array rv1 = lb.range_values(20, 40);
    check("range_values(20, 40).length() == 2", rv1.length() == 2);
    if (rv1.length() == 2) {
        check("rv1[0] == 200 (key 20)",      cast<int64>(rv1.get(0)) == 200);
        check("rv1[1] == 300 (key 30)",      cast<int64>(rv1.get(1)) == 300);
    }

    // Range covering all keys
    array rv_all = lb.range_values(0, 100);
    check("range_values(0, 100) covers all 5", rv_all.length() == 5);
    if (rv_all.length() == 5) {
        check("rv_all[0] == 100 (key 10)",   cast<int64>(rv_all.get(0)) == 100);
        check("rv_all[1] == 200 (key 20)",   cast<int64>(rv_all.get(1)) == 200);
        check("rv_all[2] == 300 (key 30)",   cast<int64>(rv_all.get(2)) == 300);
        check("rv_all[3] == 400 (key 40)",   cast<int64>(rv_all.get(3)) == 400);
        check("rv_all[4] == 500 (key 50)",   cast<int64>(rv_all.get(4)) == 500);
    }

    // lo == hi — empty range
    array rv_eq = lb.range_values(30, 30);
    check("range_values(30, 30).length() == 0", rv_eq.length() == 0);

    // No keys in interval
    array rv_none = lb.range_values(15, 19);
    check("range_values(15, 19).length() == 0", rv_none.length() == 0);

    // Range past last key
    array rv_past = lb.range_values(60, 100);
    check("range_values(60, 100).length() == 0", rv_past.length() == 0);

    // Range before first key
    array rv_before = lb.range_values(1, 9);
    check("range_values(1, 9).length() == 0", rv_before.length() == 0);

    // -----------------------------------------------------------------------
    // SECTION 14 — Value type: bool
    // Tests: sorted_map<int64, bool> with true/false values
    // -----------------------------------------------------------------------

    section("14. Value type: bool");

    sorted_map<int64, bool> mb;

    mb.set(1, true);
    mb.set(2, false);
    mb.set(3, true);
    check("bool map: size == 3",             mb.size() == 3);
    check("bool map: get(1) == true",        mb.get(1) == true);
    check("bool map: get(2) == false",       mb.get(2) == false);
    check("bool map: get(3) == true",        mb.get(3) == true);
    check("bool map: get(99) == false (0)",  mb.get(99) == false);

    // Overwrite bool value
    mb.set(2, true);
    check("bool map: get(2) == true after overwrite", mb.get(2) == true);

    // Remove
    bool b_removed = mb.remove(1);
    check("bool map: remove(1) == true",     b_removed);
    check("bool map: size == 2 after remove", mb.size() == 2);
    check("bool map: !contains(1)",         !mb.contains(1));

    // Keys / values
    array bk = mb.keys();
    check("bool map: keys[0] == 2",          cast<int64>(bk.get(0)) == 2);
    check("bool map: keys[1] == 3",          cast<int64>(bk.get(1)) == 3);

    array bv = mb.values();
    // After removing key 1: remaining {2: true, 3: true}
    check("bool map: values[0] == true",     cast<bool>(bv.get(0)) == true);
    check("bool map: values[1] == true",     cast<bool>(bv.get(1)) == true);

    // Clear
    mb.clear();
    check("bool map: size == 0 after clear", mb.size() == 0);

    // -----------------------------------------------------------------------
    // SECTION 15 — Sentinel 0 as valid key
    // Tests: contains() before get() when 0 is a valid key
    // -----------------------------------------------------------------------

    section("15. Sentinel 0 as valid key");

    sorted_map<int64, int64> m0;

    // 0 is not present yet
    check("contains(0) == false initially",  !m0.contains(0));
    check("get(0) == 0 (sentinel, not a key)", m0.get(0) == 0);

    // Insert 0 as a valid key
    m0.set(0, 42);
    check("size == 1 after set(0, 42)",      m0.size() == 1);
    check("contains(0) == true",             m0.contains(0));
    check("get(0) == 42 (valid key)",        m0.get(0) == 42);

    // The recommended pattern: check contains() first
    if (m0.contains(0)) {
        int64 val = m0.get(0);
        check("safe pattern: contains(0) -> get(0) == 42", val == 42);
    } else {
        check("safe pattern: 0 not in map (unexpected)", false);
    }

    // Insert other keys around 0
    m0.set(-10, 100);
    m0.set(10, 200);
    check("size == 3 after adding -10 and 10", m0.size() == 3);

    check("contains(-10)",                   m0.contains(-10));
    check("contains(10)",                    m0.contains(10));

    // Keys should be sorted: -10, 0, 10
    array m0_keys = m0.keys();
    check("keys[0] == -10",                  cast<int64>(m0_keys.get(0)) == -10);
    check("keys[1] == 0",                    cast<int64>(m0_keys.get(1)) == 0);
    check("keys[2] == 10",                   cast<int64>(m0_keys.get(2)) == 10);

    check("first_key() == -10",              m0.first_key() == -10);
    check("last_key() == 10",                m0.last_key() == 10);

    // lower_bound with 0 as existing key
    check("lower_bound(-5) == 0",            m0.lower_bound(-5) == 0);
    check("floor_key(0) == 0",               m0.floor_key(0) == 0);

    // Remove the sentinel key 0
    bool rm0 = m0.remove(0);
    check("remove(0) == true",               rm0);
    check("contains(0) == false after remove", !m0.contains(0));
    check("get(0) == 0 (back to sentinel)",  m0.get(0) == 0);

    // -----------------------------------------------------------------------
    // SECTION 16 — Ordered insertion/deletion stress
    // Tests: keys come out sorted with non-sequential insert order
    // -----------------------------------------------------------------------

    section("16. Insertion order vs sorted order");

    sorted_map<int64, int64> stress;

    // Insert in seemingly random order
    stress.set(7, 700);
    stress.set(2, 200);
    stress.set(9, 900);
    stress.set(1, 100);
    stress.set(5, 500);
    stress.set(8, 800);
    stress.set(3, 300);
    stress.set(4, 400);
    stress.set(6, 600);
    stress.set(0, 0);

    check("stress: size == 10",              stress.size() == 10);

    array stress_ks = stress.keys();
    check("stress: keys.length() == 10",     stress_ks.length() == 10);

    // Verify sorted order
    int64 prev_k = -1;
    bool sorted = true;
    int64 si = 0;
    while (si < cast<int64>(stress_ks.length())) {
        int64 k = cast<int64>(stress_ks.get(si));
        if (k < prev_k) {
            sorted = false;
        }
        prev_k = k;
        si = si + 1;
    }
    check("stress: all keys in sorted order", sorted);

    // Verify values correspond correctly
    array stress_vs = stress.values();
    check("stress: values[0] == 0 (key 0)",  cast<int64>(stress_vs.get(0)) == 0);
    check("stress: values[1] == 100 (key 1)", cast<int64>(stress_vs.get(1)) == 100);
    check("stress: values[5] == 500 (key 5)", cast<int64>(stress_vs.get(5)) == 500);
    check("stress: values[9] == 900 (key 9)", cast<int64>(stress_vs.get(9)) == 900);

    // Remove some mid-range keys
    stress.remove(3);
    stress.remove(5);
    stress.remove(7);
    check("stress: size == 7 after removals", stress.size() == 7);

    // Verify remaining sorted order
    array stress_ks2 = stress.keys();
    bool sorted2 = true;
    int64 prev_k2 = -1;
    int64 sj = 0;
    while (sj < cast<int64>(stress_ks2.length())) {
        int64 k = cast<int64>(stress_ks2.get(sj));
        if (k < prev_k2) {
            sorted2 = false;
        }
        prev_k2 = k;
        sj = sj + 1;
    }
    check("stress: still sorted after removals", sorted2);

    // -----------------------------------------------------------------------
    // SECTION 17 — Bound queries with alternative type: sorted_map<int64, bool>
    // Tests: all bound methods work with bool values
    // -----------------------------------------------------------------------

    section("17. Bound queries with bool values");

    sorted_map<int64, bool> m_bool_bounds;
    m_bool_bounds.set(5, true);
    m_bool_bounds.set(15, false);
    m_bool_bounds.set(25, true);

    check("bool map: lower_bound(10) == 15",  m_bool_bounds.lower_bound(10) == 15);
    check("bool map: lower_bound(5) == 5",    m_bool_bounds.lower_bound(5) == 5);
    check("bool map: upper_bound(15) == 25",  m_bool_bounds.upper_bound(15) == 25);
    check("bool map: floor_key(20) == 15",    m_bool_bounds.floor_key(20) == 15);
    check("bool map: ceiling_key(10) == 15",  m_bool_bounds.ceiling_key(10) == 15);
    check("bool map: ceiling_key(5) == 5",    m_bool_bounds.ceiling_key(5) == 5);

    array brk = m_bool_bounds.range_keys(10, 20);
    check("bool map: range_keys(10, 20).len == 1", brk.length() == 1);
    if (brk.length() == 1) {
        check("bool map: rk[0] == 15",        cast<int64>(brk.get(0)) == 15);
    }

    array brv = m_bool_bounds.range_values(10, 20);
    check("bool map: range_values(10, 20).len == 1", brv.length() == 1);
    if (brv.length() == 1) {
        check("bool map: rv[0] == false",     cast<bool>(brv.get(0)) == false);
    }

    // -----------------------------------------------------------------------
    // SECTION 18 — first_key / last_key with negative keys
    // Tests: negative keys in ordering
    // -----------------------------------------------------------------------

    section("18. Negative keys and ordering");

    sorted_map<int64, int64> neg;
    neg.set(-50, 1);
    neg.set(-10, 2);
    neg.set(0, 3);
    neg.set(10, 4);
    neg.set(50, 5);

    check("neg: first_key() == -50",         neg.first_key() == -50);
    check("neg: last_key() == 50",           neg.last_key() == 50);

    array neg_ks = neg.keys();
    check("neg: keys[0] == -50",             cast<int64>(neg_ks.get(0)) == -50);
    check("neg: keys[1] == -10",             cast<int64>(neg_ks.get(1)) == -10);
    check("neg: keys[2] == 0",               cast<int64>(neg_ks.get(2)) == 0);
    check("neg: keys[3] == 10",              cast<int64>(neg_ks.get(3)) == 10);
    check("neg: keys[4] == 50",              cast<int64>(neg_ks.get(4)) == 50);

    // Bound queries with negatives
    check("neg: lower_bound(-20) == -10",    neg.lower_bound(-20) == -10);
    check("neg: upper_bound(-10) == 0",      neg.upper_bound(-10) == 0);
    check("neg: floor_key(-5) == -10",       neg.floor_key(-5) == -10);
    check("neg: floor_key(-50) == -50",      neg.floor_key(-50) == -50);
    check("neg: ceiling_key(-20) == -10",    neg.ceiling_key(-20) == -10);

    array neg_rk = neg.range_keys(-10, 10);
    check("neg: range_keys(-10, 10).len == 2", neg_rk.length() == 2);
    if (neg_rk.length() == 2) {
        check("neg: rk[0] == -10",           cast<int64>(neg_rk.get(0)) == -10);
        check("neg: rk[1] == 0",             cast<int64>(neg_rk.get(1)) == 0);
    }

    // -----------------------------------------------------------------------
    // Summary
    // -----------------------------------------------------------------------

    print_console("");
    print_console("===========================================");
    print_console("  TOTAL PASS: " + cast<string>(g_pass));
    print_console("  TOTAL FAIL: " + cast<string>(g_fail));
    print_console("===========================================");

    unregister_routine(g_handle);
}

// ---------------------------------------------------------------------------
// Menu callbacks
// ---------------------------------------------------------------------------

void on_menu_run_again(int64 data) {
    print_console("[menu] Resetting and re-running tests...");
    g_done = 0;
    g_pass = 0;
    g_fail = 0;
}

void on_menu_summary(int64 data) {
    print_console("[menu] Current totals — PASS: " + cast<string>(g_pass) +
                  "  FAIL: " + cast<string>(g_fail));
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

int32 main() {
    print_console("[sorted_map] Launching comprehensive Sorted Map test...");

    g_section = create_sidebar_section("sorted map test", "");
    g_btn     = g_section.create_button("Actions", ui_align::left);
    g_menu    = create_menu();
    g_menu.add_item("Run again",   cast<int64>(on_menu_run_again), "", "");
    g_menu.add_separator();
    g_menu.add_item("Log summary", cast<int64>(on_menu_summary),   "", "");
    g_menu.attach_to_button(g_btn);

    g_handle = register_routine(cast<int64>(test_routine), 0);
    if (g_handle == 0) {
        print_console("[FAIL] register_routine returned 0");
        return -1;
    }
    return 1;
}
