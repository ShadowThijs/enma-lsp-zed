// =============================================================================
// Hash Set addon comprehensive test
//
// Exercises every type, method, and standalone function documented in:
//   docs/Addons/Hash Set.md
//
// Types:
//   hash_set<T>              — generic hashed set, T bound at declaration time
//
// Methods on hash_set<T>:
//   void   add(T v)          — insert element (dedup)
//   bool   contains(T v)     — membership check
//   bool   remove(T v)       — remove element, true if was present
//   int64  size()            — element count
//   void   clear()           — remove all elements
//   array  to_array()        — copy contents into new array (order not guaranteed)
//   hash_set copy()          — independent deep copy
//
// Set operations (mutate receiver in place):
//   union_with(other)        — add every element of `other` to receiver
//   intersect_with(other)    — keep only elements present in both
//   diff_with(other)         — remove every element of `other` from receiver
//   bool is_subset_of(other) — is every element of receiver also in other?
//   bool equals(other)       — do both sets have identical elements?
//
// Supported element types:
//   int8 / int16 / int32 / int64 / uint8 / uint16 / uint32 / uint64
//   bool
//   float32 / float64
//   string                    — hashed by content, dedup by value
//   pointer types (T*)       — compared as raw pointer values
//
// Not supported (documented limitation):
//   Class types as T          — would need user-defined ==
//
// Compile-time type enforcement:
//   hash_set<int64> s;  s.add("oops");  // compile error
// =============================================================================

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

void print_console(string input) {
    print(input);
}

void section(string title) {
    print_console("");
    print_console("--- " + title + " ---");
}

// =============================================================================
// 1. int64 — primary integer type
// =============================================================================

void test_int64() {
    section("hash_set<int64> — basic operations");

    hash_set<int64> s;

    check("new set size == 0", s.size() == 0);
    check("new set contains(1) == false", !s.contains(1));
    check("new set remove(1) == false", !s.remove(1));

    s.add(1);
    s.add(2);
    s.add(3);
    check("size == 3 after three adds", s.size() == 3);
    check("contains(1) == true", s.contains(1));
    check("contains(2) == true", s.contains(2));
    check("contains(3) == true", s.contains(3));
    check("contains(99) == false", !s.contains(99));

    // Dedup — adding existing element does not increase size.
    s.add(2);
    s.add(3);
    check("size still 3 after adding duplicates", s.size() == 3);

    section("hash_set<int64> — remove");

    check("remove(2) == true", s.remove(2));
    check("size == 2 after removal", s.size() == 2);
    check("contains(2) == false after removal", !s.contains(2));
    check("contains(1) == true", s.contains(1));
    check("contains(3) == true", s.contains(3));

    check("remove(99) == false (not present)", !s.remove(99));
    check("size still 2 after failed remove", s.size() == 2);

    section("hash_set<int64> — to_array");

    s.add(2);   // add back for a fuller array
    array<int64> arr = s.to_array();
    check("to_array length == size", arr.length() == s.size());

    // Verify every element in the array is in the set.
    bool all_in = true;
    int64 i = 0;
    while (i < arr.length()) {
        if (!s.contains(arr.get(i))) { all_in = false; }
        i = i + 1;
    }
    check("all array elements present in set", all_in);

    section("hash_set<int64> — clear");

    s.clear();
    check("size == 0 after clear", s.size() == 0);
    check("contains(1) == false after clear", !s.contains(1));
    check("contains(2) == false after clear", !s.contains(2));
    check("contains(3) == false after clear", !s.contains(3));

    section("hash_set<int64> — copy (independent deep copy)");

    hash_set<int64> orig;
    orig.add(10);
    orig.add(20);
    orig.add(30);

    hash_set<int64> cpy = orig.copy();
    check("copy size matches original", cpy.size() == orig.size());
    check("copy contains original elements", cpy.contains(10) && cpy.contains(20) && cpy.contains(30));

    // Mutate copy — original should be unaffected.
    cpy.add(40);
    check("original unchanged after copy add", orig.size() == 3);
    check("original does not contain copy's new element", !orig.contains(40));
    check("copy reflects new element", cpy.contains(40) && cpy.size() == 4);

    // Mutate original — copy unaffected.
    orig.add(50);
    check("copy unchanged after original add", !cpy.contains(50));
    check("copy still size 4", cpy.size() == 4);
}

// =============================================================================
// 2. int32 / int16 / int8
// =============================================================================

void test_int_other_sizes() {
    section("hash_set<int32>");

    hash_set<int32> s32;
    s32.add(100);
    s32.add(200);
    s32.add(100);   // dedup
    check("int32 size == 2 after dedup", s32.size() == 2);
    check("int32 contains(100)", s32.contains(100));
    check("int32 contains(200)", s32.contains(200));
    check("int32 !contains(300)", !s32.contains(300));
    check("int32 remove(200)", s32.remove(200));
    check("int32 size == 1 after remove", s32.size() == 1);

    section("hash_set<int16>");

    hash_set<int16> s16;
    s16.add(cast<int16>(1));
    s16.add(cast<int16>(2));
    s16.add(cast<int16>(3));
    check("int16 size == 3", s16.size() == 3);
    check("int16 contains(1)", s16.contains(cast<int16>(1)));
    check("int16 remove(1)", s16.remove(cast<int16>(1)));
    check("int16 size == 2 after remove", s16.size() == 2);
    s16.clear();
    check("int16 size == 0 after clear", s16.size() == 0);

    section("hash_set<int8>");

    hash_set<int8> s8;
    s8.add(cast<int8>(10));
    s8.add(cast<int8>(20));
    s8.add(cast<int8>(10));   // dedup
    check("int8 size == 2 after dedup", s8.size() == 2);
    check("int8 contains(10)", s8.contains(cast<int8>(10)));
    check("int8 !contains(99)", !s8.contains(cast<int8>(99)));
}

// =============================================================================
// 3. uint64 / uint32 / uint16 / uint8
// =============================================================================

void test_unsigned() {
    section("hash_set<uint64>");

    hash_set<uint64> su64;
    su64.add(cast<uint64>(1));
    su64.add(cast<uint64>(2));
    su64.add(cast<uint64>(3));
    check("uint64 size == 3", su64.size() == 3);
    check("uint64 contains(1)", su64.contains(cast<uint64>(1)));
    check("uint64 remove(2)", su64.remove(cast<uint64>(2)));
    check("uint64 size == 2 after remove", su64.size() == 2);

    section("hash_set<uint32>");

    hash_set<uint32> su32;
    su32.add(cast<uint32>(10));
    su32.add(cast<uint32>(20));
    su32.add(cast<uint32>(30));
    su32.add(cast<uint32>(10));   // dedup
    check("uint32 size == 3 after dedup", su32.size() == 3);

    // to_array
    array<uint32> uarr = su32.to_array();
    check("uint32 to_array length == size", uarr.length() == su32.size());

    // copy
    hash_set<uint32> ucpy = su32.copy();
    check("uint32 copy size matches", ucpy.size() == su32.size());
    su32.add(cast<uint32>(99));
    check("uint32 copy independent after add", ucpy.size() == 3);

    section("hash_set<uint16>");

    hash_set<uint16> su16;
    su16.add(cast<uint16>(5));
    su16.add(cast<uint16>(10));
    check("uint16 size == 2", su16.size() == 2);
    check("uint16 contains(5)", su16.contains(cast<uint16>(5)));
    su16.clear();
    check("uint16 size == 0 after clear", su16.size() == 0);

    section("hash_set<uint8>");

    hash_set<uint8> su8;
    su8.add(cast<uint8>(1));
    su8.add(cast<uint8>(2));
    check("uint8 size == 2", su8.size() == 2);
    check("uint8 contains(1)", su8.contains(cast<uint8>(1)));
    check("uint8 remove(2)", su8.remove(cast<uint8>(2)));
    check("uint8 size == 1 after remove", su8.size() == 1);
}

// =============================================================================
// 4. bool
// =============================================================================

void test_bool() {
    section("hash_set<bool>");

    hash_set<bool> sb;

    // False and true are distinct 0 and 1 in the set.
    sb.add(false);
    check("bool.size == 1 after add(false)", sb.size() == 1);
    check("bool contains(false)", sb.contains(false));
    check("bool !contains(true)", !sb.contains(true));

    sb.add(true);
    check("bool.size == 2 after add(true)", sb.size() == 2);
    check("bool contains(true)", sb.contains(true));

    // Dedup — adding false again should not increase size.
    sb.add(false);
    check("bool.size still 2 after dedup", sb.size() == 2);

    check("bool remove(false)", sb.remove(false));
    check("bool.size == 1 after remove", sb.size() == 1);
    check("bool !contains(false) after remove", !sb.contains(false));

    sb.clear();
    check("bool.size == 0 after clear", sb.size() == 0);
}

// =============================================================================
// 5. float32 / float64
// =============================================================================

void test_float() {
    section("hash_set<float64>");

    hash_set<float64> sd;
    sd.add(1.0);
    sd.add(2.0);
    sd.add(3.0);
    sd.add(1.0);    // dedup
    check("float64 size == 3 after dedup", sd.size() == 3);
    check("float64 contains(1.0)", sd.contains(1.0));
    check("float64 contains(3.0)", sd.contains(3.0));
    check("float64 !contains(99.9)", !sd.contains(99.9));

    // IEEE bit comparison: +0.0 and -0.0 are different bit patterns.
    // Per the docs, hash_set compares as IEEE bit patterns.
    sd.add(-0.0);
    check("float64 added -0.0 without crashing", sd.contains(-0.0));
    // 0.0 and -0.0 may or may not dedup depending on the hash strategy;
    // we just verify the operation is safe.

    check("float64 remove(2.0)", sd.remove(2.0));
    check("float64 size == 2 after remove", sd.size() == 2);

    // to_array
    array<float64> darr = sd.to_array();
    check("float64 to_array returns elements", darr.length() == sd.size());
    // Verify round-trip: every returned element is in the set.
    bool dcheck = true;
    int64 di = 0;
    while (di < darr.length()) {
        if (!sd.contains(darr.get(di))) { dcheck = false; }
        di = di + 1;
    }
    check("float64 to_array elements all in set", dcheck);

    // copy
    hash_set<float64> dcopy = sd.copy();
    check("float64 copy size matches", dcopy.size() == sd.size());
    sd.add(99.9);
    check("float64 copy independent", dcopy.size() == 2);

    sd.clear();
    check("float64 size == 0 after clear", sd.size() == 0);

    section("hash_set<float32>");

    hash_set<float32> sf;
    sf.add(cast<float32>(1.5f));
    sf.add(cast<float32>(2.5f));
    sf.add(cast<float32>(3.5f));
    sf.add(cast<float32>(1.5f));   // dedup (same IEEE bit pattern)
    check("float32 size == 3 after dedup", sf.size() == 3);
    check("float32 contains(1.5)", sf.contains(cast<float32>(1.5f)));
    check("float32 !contains(10.0)", !sf.contains(cast<float32>(10.0f)));

    sf.remove(cast<float32>(2.5f));
    check("float32 size == 2 after remove", sf.size() == 2);
}

// =============================================================================
// 6. string — hashed by content, dedup by value
// =============================================================================

void test_string() {
    section("hash_set<string> — basic operations (content-based hashing)");

    hash_set<string> tags;

    check("string new set size == 0", tags.size() == 0);

    tags.add("alpha");
    tags.add("beta");
    tags.add("gamma");
    check("string size == 3 after three adds", tags.size() == 3);
    check("string contains('alpha')", tags.contains("alpha"));
    check("string contains('beta')", tags.contains("beta"));
    check("string !contains('delta')", !tags.contains("delta"));

    // Dedup by string value (not pointer).
    tags.add("alpha");
    tags.add("beta");
    check("string size still 3 after adding duplicates", tags.size() == 3);

    check("string remove('beta')", tags.remove("beta"));
    check("string size == 2 after remove", tags.size() == 2);
    check("string !contains('beta') after remove", !tags.contains("beta"));
    check("string remove('nonexistent') == false", !tags.remove("nonexistent"));

    section("hash_set<string> — to_array");

    array<string> tarr = tags.to_array();
    check("string to_array length == size", tarr.length() == tags.size());
    bool tall = true;
    int64 ti = 0;
    while (ti < tarr.length()) {
        if (!tags.contains(tarr.get(ti))) { tall = false; }
        ti = ti + 1;
    }
    check("string to_array elements all in set", tall);

    section("hash_set<string> — copy");

    hash_set<string> tcpy = tags.copy();
    check("string copy size matches", tcpy.size() == tags.size());
    check("string copy contains 'alpha'", tcpy.contains("alpha"));
    check("string copy contains 'gamma'", tcpy.contains("gamma"));

    tags.add("zeta");
    check("string copy independent after original add", !tcpy.contains("zeta"));
    check("string copy size unchanged", tcpy.size() == 2);

    tcpy.add("omega");
    check("string original unchanged after copy add", !tags.contains("omega"));
    check("string original size unchanged", tags.size() == 3);

    section("hash_set<string> — clear");

    tags.clear();
    check("string size == 0 after clear", tags.size() == 0);
    check("string !contains('alpha') after clear", !tags.contains("alpha"));
    check("string !contains('gamma') after clear", !tags.contains("gamma"));
}

// =============================================================================
// 7. Set operations — union_with / intersect_with / diff_with / is_subset_of / equals
// =============================================================================

void test_set_operations() {
    section("set operations — union_with");

    hash_set<int64> a;
    a.add(1); a.add(2); a.add(3);

    hash_set<int64> b;
    b.add(3); b.add(4); b.add(5);

    a.union_with(b);
    check("union size == 5", a.size() == 5);
    check("union contains 1", a.contains(1));
    check("union contains 2", a.contains(2));
    check("union contains 3", a.contains(3));
    check("union contains 4", a.contains(4));
    check("union contains 5", a.contains(5));

    // Receiver was mutated, b unchanged.
    check("other unchanged after union", b.size() == 3);
    check("other still contains 3", b.contains(3));
    check("other still contains 4", b.contains(4));

    // Union with empty set = no change.
    hash_set<int64> empty;
    a.union_with(empty);
    check("union with empty: size unchanged", a.size() == 5);

    // Union with self = no change.
    a.union_with(a);
    check("union with self: size unchanged", a.size() == 5);

    section("set operations — intersect_with");

    hash_set<int64> c;
    c.add(1); c.add(2); c.add(3); c.add(4); c.add(5);

    hash_set<int64> d;
    d.add(3); d.add(4); d.add(5); d.add(6); d.add(7);

    c.intersect_with(d);
    check("intersection size == 3 (3,4,5)", c.size() == 3);
    check("intersection !contains 1", !c.contains(1));
    check("intersection !contains 2", !c.contains(2));
    check("intersection contains 3", c.contains(3));
    check("intersection contains 4", c.contains(4));
    check("intersection contains 5", c.contains(5));

    // Other unchanged.
    check("other unchanged after intersect", d.size() == 5);
    check("other still contains 6", d.contains(6));

    // Intersect with disjoint set = empty.
    hash_set<int64> e;
    e.add(1); e.add(2);
    hash_set<int64> f;
    f.add(99); f.add(100);
    e.intersect_with(f);
    check("disjoint intersection: size == 0", e.size() == 0);

    // Intersect with self = no change.
    hash_set<int64> g;
    g.add(10); g.add(20); g.add(30);
    g.intersect_with(g);
    check("intersect with self: size unchanged", g.size() == 3);

    section("set operations — diff_with");

    hash_set<int64> h;
    h.add(1); h.add(2); h.add(3); h.add(4); h.add(5);

    hash_set<int64> i;
    i.add(2); i.add(4); i.add(6);

    h.diff_with(i);
    check("diff size == 2 (1, 3, 5 removed)", h.size() == 2);
    check("diff contains 1", h.contains(1));
    check("diff contains 5", h.contains(5));
    check("diff !contains 2", !h.contains(2));
    check("diff !contains 3", !h.contains(3));
    check("diff !contains 4", !h.contains(4));

    // Other unchanged.
    check("other unchanged after diff", i.size() == 3);
    check("other still contains 2", i.contains(2));

    // Diff with disjoint set = no change.
    hash_set<int64> j;
    j.add(100); j.add(200);
    h.diff_with(j);
    check("diff with disjoint: size unchanged", h.size() == 2);

    // Diff with self = empty.
    hash_set<int64> k;
    k.add(1); k.add(2);
    k.diff_with(k);
    check("diff with self: size == 0", k.size() == 0);

    section("set operations — is_subset_of");

    hash_set<int64> sub;
    sub.add(3); sub.add(4);

    hash_set<int64> sup;
    sup.add(1); sup.add(2); sup.add(3); sup.add(4); sup.add(5);

    check("subset: {3,4} is subset of {1,2,3,4,5}", sub.is_subset_of(sup));
    check("superset: is NOT subset of subset", !sup.is_subset_of(sub));

    // Equal sets are subsets of each other.
    check("equal sets are subsets", sub.is_subset_of(sub));

    // Empty set is subset of everything.
    hash_set<int64> empty2;
    check("empty set is subset of non-empty", empty2.is_subset_of(sup));
    check("empty set is subset of itself", empty2.is_subset_of(empty2));

    // Non-subset.
    hash_set<int64> notsub;
    notsub.add(99);
    check("{99} is NOT subset of {1..5}", !notsub.is_subset_of(sup));

    section("set operations — equals");

    hash_set<int64> eq1;
    eq1.add(1); eq1.add(2); eq1.add(3);
    hash_set<int64> eq2;
    eq2.add(3); eq2.add(2); eq2.add(1);
    check("equal sets (different insertion order)", eq1.equals(eq2));
    check("equal symmetric", eq2.equals(eq1));
    check("set equals itself", eq1.equals(eq1));

    hash_set<int64> neq;
    neq.add(1); neq.add(2); neq.add(4);
    check("different sets not equal", !eq1.equals(neq));

    hash_set<int64> empty3;
    check("empty set equals empty set", empty3.equals(empty3));
    check("empty != non-empty", !empty3.equals(eq1));
    check("non-empty != empty", !eq1.equals(empty3));
}

// =============================================================================
// 8. Set operations with string sets
// =============================================================================

void test_set_ops_string() {
    section("set operations with string sets");

    hash_set<string> a;
    a.add("apple"); a.add("banana"); a.add("cherry");

    hash_set<string> b;
    b.add("banana"); b.add("cherry"); b.add("date");

    // union
    hash_set<string> u = a.copy();
    u.union_with(b);
    check("string union size == 4", u.size() == 4);
    check("string union contains apple", u.contains("apple"));
    check("string union contains date", u.contains("date"));
    check("string union contains shared elements",
        u.contains("banana") && u.contains("cherry"));

    // intersect
    hash_set<string> inter = a.copy();
    inter.intersect_with(b);
    check("string intersect size == 2 (banana,cherry)", inter.size() == 2);
    check("string intersect contains banana", inter.contains("banana"));
    check("string intersect contains cherry", inter.contains("cherry"));
    check("string intersect !contains apple", !inter.contains("apple"));
    check("string intersect !contains date", !inter.contains("date"));

    // diff
    hash_set<string> df = a.copy();
    df.diff_with(b);
    check("string diff size == 1 (apple)", df.size() == 1);
    check("string diff contains apple", df.contains("apple"));
    check("string diff !contains banana", !df.contains("banana"));

    // subset
    hash_set<string> sub;
    sub.add("banana"); sub.add("cherry");
    check("string subset: {banana,cherry} is subset of a", sub.is_subset_of(a));
    // {banana,cherry} IS a subset of b too (since b has banana,cherry,date)
    check("string subset: {banana,cherry} is subset of b", sub.is_subset_of(b));

    // equals
    hash_set<string> eq;
    eq.add("cherry"); eq.add("banana"); eq.add("apple");
    check("string equals (different order)", a.equals(eq));
}

// =============================================================================
// 9. Chained / combined usage
// =============================================================================

void test_combined() {
    section("combined usage — add/remove/clear/add cycle");

    hash_set<int64> s;

    // Fill, remove half, clear, refill.
    int64 i = 0;
    while (i < 10) {
        s.add(i);
        i = i + 1;
    }
    check("combined: size == 10 after fill", s.size() == 10);

    // Remove evens.
    int64 j = 0;
    while (j < 10) {
        if (j % 2 == 0) { s.remove(j); }
        j = j + 1;
    }
    check("combined: size == 5 after removing evens", s.size() == 5);
    check("combined: contains 1 (odd)", s.contains(1));
    check("combined: !contains 0 (even)", !s.contains(0));

    s.clear();
    check("combined: size == 0 after clear", s.size() == 0);

    // Refill and use copy + to_array.
    int64 k = 0;
    while (k < 5) {
        s.add(k * 10);
        k = k + 1;
    }
    check("combined: size == 5 after refill", s.size() == 5);

    hash_set<int64> dup = s.copy();
    check("combined: copy size matches", dup.size() == s.size());

    array<int64> sa = s.to_array();
    check("combined: to_array length matches", sa.length() == s.size());

    // Verify all values survived.
    bool all_ok = true;
    int64 vi = 0;
    while (vi < sa.length()) {
        int64 val = sa.get(vi);
        if (!s.contains(val) || !dup.contains(val)) { all_ok = false; }
        vi = vi + 1;
    }
    check("combined: all values through copy + to_array", all_ok);
}

// =============================================================================
// 10. Edge cases — empty sets, single element, large-ish sets
// =============================================================================

void test_edge_cases() {
    section("edge cases");

    // Empty set operations.
    hash_set<int64> e1;
    hash_set<int64> e2;
    check("empty.equals(empty)", e1.equals(e2));
    check("empty.is_subset_of(empty)", e1.is_subset_of(e2));

    e1.union_with(e2);
    check("union of two empties == 0", e1.size() == 0);

    e1.intersect_with(e2);
    check("intersection of two empties == 0", e1.size() == 0);

    e1.diff_with(e2);
    check("diff of two empties == 0", e1.size() == 0);

    // Single element.
    hash_set<int64> single;
    single.add(42);
    check("single element size == 1", single.size() == 1);
    check("single contains 42", single.contains(42));
    check("single remove 42", single.remove(42));
    check("single empty after remove", single.size() == 0);

    // to_array on empty set.
    hash_set<int64> empty_set;
    array<int64> empty_arr = empty_set.to_array();
    check("empty set to_array length == 0", empty_arr.length() == 0);

    // copy on empty set.
    hash_set<int64> empty_copy = empty_set.copy();
    check("empty set copy size == 0", empty_copy.size() == 0);
}

// =============================================================================
// 11. Pointer element type
// =============================================================================

// Simple class for pointer-type testing.
class Point {
    int64 x;
    int64 y;
    Point() { x = 0; y = 0; }
    Point(int64 px, int64 py) { x = px; y = py; }
}

void test_pointers() {
    section("hash_set<T*> — pointer types (compared by raw pointer value)");

    hash_set<Point*> sp;

    Point* p1 = Point(1, 2);
    Point* p2 = Point(3, 4);
    Point* p3 = Point(5, 6);

    sp.add(p1);
    sp.add(p2);
    sp.add(p3);
    check("pointer set size == 3", sp.size() == 3);
    check("pointer set contains p1", sp.contains(p1));
    check("pointer set contains p2", sp.contains(p2));
    check("pointer set contains p3", sp.contains(p3));

    // Same pointer again = dedup.
    sp.add(p1);
    check("pointer set size still 3 after dedup", sp.size() == 3);

    // Different object, even with same values, is different pointer.
    Point* p1b = Point(1, 2);
    check("pointer set !contains different object (same values)", !sp.contains(p1b));

    // Remove.
    check("pointer set remove p2", sp.remove(p2));
    check("pointer set !contains p2 after remove", !sp.contains(p2));
    check("pointer set size == 2 after remove", sp.size() == 2);

    // to_array
    array<Point*> parr = sp.to_array();
    check("pointer to_array length == size", parr.length() == sp.size());

    // copy
    hash_set<Point*> pcopy = sp.copy();
    check("pointer copy size matches", pcopy.size() == sp.size());
    check("pointer copy contains p1", pcopy.contains(p1));
    // pcopy was created before p3 removal, so it still has p3.
    check("pointer copy contains p3", pcopy.contains(p3));

    sp.clear();
    check("pointer set size == 0 after clear", sp.size() == 0);
    check("pointer set !contains p1 after clear", !sp.contains(p1));
    check("pointer copy still has elements after original clear", pcopy.size() == 2);

    // Clean up heap objects.
    // (In a real script the GC would handle this; we just test set behavior.)
}

// =============================================================================
// 12. Registration note
// =============================================================================
//
// IMPORTANT: Before using hash_set in a Perception script, register the addon:
//
//   register_addon_hash_set(engine);
//
// This is done once during engine setup, typically before any script runs.

// =============================================================================
// 13. Compile-time type enforcement (documented)
// =============================================================================
//
// The compiler enforces T at every method call:
//
//   hash_set<int64> s;
//   s.add("oops");      // compile error: expected int64, got string
//
// This test file intentionally does NOT include a compile-error test since it
// would prevent loading. The compile-time check is documented and enforced by
// the compiler at parse time.

// =============================================================================
// Main — run all tests
// =============================================================================

int32 main() {
    print_console("=== hash_set addon comprehensive test ===");

    test_int64();
    test_int_other_sizes();
    test_unsigned();
    test_bool();
    test_float();
    test_string();
    test_set_operations();
    test_set_ops_string();
    test_combined();
    test_edge_cases();
    test_pointers();

    print_console("");
    print_console("=== summary ===");
    print_console("  pass: " + cast<string>(g_pass));
    print_console("  fail: " + cast<string>(g_fail));
    if (g_fail == 0) {
        print_console("ALL GREEN");
    } else {
        print_console("FAILURES PRESENT — see FAIL lines above");
    }
    return cast<int32>(g_fail == 0 ? 1 : 0);
}
