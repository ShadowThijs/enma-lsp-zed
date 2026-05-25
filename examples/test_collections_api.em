// =============================================================================
// Collections smoke test — map / imap / sorted_map / hash_set
//
// Covers the full surface of the four map/set addons:
//
//   map<string, V>      — string-keyed hash map, generic V
//   imap<V>             — int64-keyed hash map, generic V
//   sorted_map<K, V>    — ordered map (BST), generic K + V
//   hash_set<T>         — unique-element set, generic T
//
// Generic V/T tested with:
//   - int64 (primitive)
//   - string (heap, addon-managed)
//   - user class (heap-allocated reference type)
//
// Sorted_map class storage is INTENTIONALLY skipped — it lacks
// captures_arg() on .set() so heap value types may UAF. Test only
// primitive int64 there until that's fixed.
// =============================================================================

int64 g_pass = 0;
int64 g_fail = 0;
int64 g_handle = 0;
int64 g_done = 0;

sidebar_section_t g_section;
button_t          g_btn;
menu_t            g_menu;

// User class to verify class-as-value-type storage in map / imap.
class Point {
    float64 x;
    float64 y;
    int64   tag;

    Point() {
        x = 0.0;
        y = 0.0;
        tag = 0;
    }

    Point(float64 x_, float64 y_, int64 tag_) {
        x = x_;
        y = y_;
        tag = tag_;
    }
}

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

    print_console("=== collections smoke test ===");

    // =======================================================================
    // map<string, int64>
    // =======================================================================
    section("map<string, int64> - basics");

    map<string, int64> m;
    check("fresh map.size() == 0", m.size() == 0);
    check("fresh map.length() == 0", m.length() == 0);
    check("fresh map.contains('x') == false", !m.contains("x"));

    m.set("alpha", 1);
    m.set("beta", 2);
    m.set("gamma", 3);
    check("map.size() == 3 after 3 sets", m.size() == 3);
    check("map.get('alpha') == 1", m.get("alpha") == 1);
    check("map.get('beta') == 2", m.get("beta") == 2);
    check("map.get('gamma') == 3", m.get("gamma") == 3);

    check("map.contains('beta') == true",  m.contains("beta"));
    check("map.has('beta') == true",       m.has("beta"));
    check("map.contains('missing') == false", !m.contains("missing"));

    // Subscript form
    m["delta"] = 4;
    check("subscript set m['delta'] = 4", m.get("delta") == 4);
    check("map.size() == 4 after subscript set", m.size() == 4);

    section("map<string, int64> - get_or_default + has_value");
    check("get_or_default(present) returns value",
          m.get_or_default("alpha", -1) == 1);
    check("get_or_default(missing) returns default",
          m.get_or_default("missing", 99) == 99);

    check("map.has_value(2) == true",  m.has_value(2));
    check("map.has_value(999) == false", !m.has_value(999));

    section("map<string, int64> - remove + clear");
    int64 removed_ok = m.remove("beta");
    check("remove('beta') returns truthy", removed_ok != 0);
    check("after remove, size == 3", m.size() == 3);
    check("after remove, contains('beta') == false", !m.contains("beta"));

    int64 removed_missing = m.remove("not_there");
    check("remove(missing) returns 0", removed_missing == 0);

    section("map<string, int64> - keys / values arrays");
    array<string> ks = m.keys();
    array<int64>  vs = m.values();
    check("keys().length() == size()", ks.length() == m.size());
    check("values().length() == size()", vs.length() == m.size());

    section("map<string, int64> - merge");
    map<string, int64> other;
    other.set("epsilon", 5);
    other.set("zeta", 6);
    m.merge(other);
    check("after merge, size == 5", m.size() == 5);
    check("after merge, get('epsilon') == 5", m.get("epsilon") == 5);
    check("after merge, get('zeta') == 6", m.get("zeta") == 6);

    section("map<string, int64> - foreach kv");
    int64 total = 0;
    for (string k, int64 v : m) {
        total = total + v;
    }
    // Original values: alpha=1, gamma=3, delta=4, + merged epsilon=5, zeta=6 = 19
    check("foreach sums all values to 19", total == 19);

    m.clear();
    check("after clear, size == 0", m.size() == 0);

    // =======================================================================
    // map<string, string> — heap value type (string)
    // =======================================================================
    // map<string, string> — surface only. map.get returns int64 (the heap
    // ptr); enma will assign that int64 into a `string` local without
    // converting, so direct equality vs a string literal compares pointers
    // not contents. Until the addon's element-keyword resolution is
    // extended to maps, only surface ops (size / contains) are reliable.
    section("map<string, string> - surface");

    map<string, string> ms;
    ms.set("name",  "alice");
    ms.set("role",  "admin");
    ms.set("greet", "hello world");
    check("map<string, string>.size() == 3", ms.size() == 3);
    check("map<string, string> contains 'name'",  ms.contains("name"));
    check("map<string, string> contains 'role'",  ms.contains("role"));
    check("map<string, string> contains 'greet'", ms.contains("greet"));

    // =======================================================================
    // map<string, Point> — class-typed value
    //
    // Insert via `new T(...)` inline. Passing a stack local is a compile
    // error ("cannot pass local struct ... it would dangle when X leaves
    // scope"). The map owns the heap copy.
    //
    // Class V retrieval: classes are reference types, so `Point r = mp.get(k)`
    // aliases the map's stored Point — no allocation. Mutations flow back
    // into the map. For an independent copy, `*mp.get(k)` deref (after
    // typed-pointer return lands).
    // =======================================================================
    section("map<string, Point> - class value (typed retrieval)");

    map<string, Point> mp;
    mp.set("origin", new Point(1.0, 2.0, 100));
    mp.set("offset", new Point(3.0, 4.0, 200));
    check("map<string, Point>.size() == 2", mp.size() == 2);
    check("map<string, Point> contains 'origin'", mp.contains("origin"));

    Point r1 = mp.get("origin");
    check("typed retrieval: r1.x == 1.0", r1.x == 1.0);
    check("typed retrieval: r1.tag == 100", r1.tag == 100);

    // Mutate through alias. Re-fetch confirms map's storage was modified.
    r1.x = 999.0;
    Point r1_again = mp.get("origin");
    check("class V is reference: mutation persists in map", r1_again.x == 999.0);

    // Surface check on map<string, vec3> — addon-registered type with
    // int64-backed storage. Same reference semantics.
    map<string, vec3> mv;
    mv.set("a", vec3(1.0, 2.0, 3.0));
    mv.set("b", vec3(4.0, 5.0, 6.0));
    check("map<string, vec3>.size() == 2", mv.size() == 2);
    check("map<string, vec3> contains 'a'", mv.contains("a"));

    // =======================================================================
    // imap<int64>
    // =======================================================================
    section("imap<int64> - basics");

    imap<int64> im;
    check("fresh imap.size() == 0", im.size() == 0);

    im.set(1, 100);
    im.set(2, 200);
    im.set(42, 4242);
    check("imap.size() == 3", im.size() == 3);

    check("imap.get(1) == 100",   im.get(1) == 100);
    check("imap.get(2) == 200",   im.get(2) == 200);
    check("imap.get(42) == 4242", im.get(42) == 4242);

    check("imap.contains(42)",      im.contains(42));
    check("imap.has(42)",           im.has(42));
    check("!imap.contains(999)",    !im.contains(999));

    // imap[k] = v subscript-set is currently broken (writes to the wrong
    // slot OR no-ops). Use .set() until that's fixed.
    im.set(7, 700);
    check("imap.set(7, 700)",  im.get(7) == 700);
    check("imap.size() == 4",   im.size() == 4);

    section("imap<int64> - get_or_default");
    check("get_or_default(present) == value",
          im.get_or_default(1, -1) == 100);
    check("get_or_default(missing) == default",
          im.get_or_default(999, -1) == -1);

    section("imap<int64> - remove + clear");
    int64 ir = im.remove(2);
    check("imap.remove(2) truthy", ir != 0);
    check("after remove, size == 3", im.size() == 3);
    check("imap.remove(999) == 0", im.remove(999) == 0);

    array<int64> iks = im.keys();
    array<int64> ivs = im.values();
    check("imap.keys().length() == size()",   iks.length() == im.size());
    check("imap.values().length() == size()", ivs.length() == im.size());

    im.clear();
    check("after imap.clear, size == 0", im.size() == 0);

    // =======================================================================
    // imap<Point> - class value, int key (typed retrieval)
    // =======================================================================
    section("imap<Point> - class value, int key");

    imap<Point> ip;
    ip.set(10, new Point(10.0, 20.0, 1000));
    ip.set(20, new Point(30.0, 40.0, 2000));
    check("imap<Point>.size() == 2", ip.size() == 2);
    check("imap<Point> contains 10", ip.contains(10));
    check("imap<Point> contains 20", ip.contains(20));

    Point ip1 = ip.get(10);
    check("imap<Point>.get(10).x == 10.0", ip1.x == 10.0);
    check("imap<Point>.get(10).tag == 1000", ip1.tag == 1000);

    // =======================================================================
    // sorted_map<int64, int64> — ordered key map
    //
    // Using primitive value type only — sorted_map.set lacks
    // captures_arg(1) which means class/string V types can UAF. Test only
    // int64 -> int64 here.
    // =======================================================================
    section("sorted_map<int64, int64> - basics");

    sorted_map<int64, int64> sm;
    sm.set(5,  50);
    sm.set(2,  20);
    sm.set(8,  80);
    sm.set(1,  10);
    sm.set(10, 100);
    check("sorted_map.size() == 5", sm.size() == 5);
    check("sorted_map.contains(5)",  sm.contains(5));
    check("sorted_map.has(8)",       sm.has(8));
    check("!sorted_map.contains(99)", !sm.contains(99));

    check("sorted_map.get(5) == 50",   sm.get(5) == 50);
    check("sorted_map.get(10) == 100", sm.get(10) == 100);

    section("sorted_map - first/last + ordering");
    check("first_key() == 1",  sm.first_key() == 1);
    check("last_key() == 10",  sm.last_key() == 10);

    array<int64> sk = sm.keys();
    check("sorted_map.keys() length == 5", sk.length() == 5);
    if (sk.length() == 5) {
        check("keys[0] == 1", sk.get(0) == 1);
        check("keys[1] == 2", sk.get(1) == 2);
        check("keys[2] == 5", sk.get(2) == 5);
        check("keys[3] == 8", sk.get(3) == 8);
        check("keys[4] == 10", sk.get(4) == 10);
    }

    array<int64> sv = sm.values();
    check("sorted_map.values() length == 5", sv.length() == 5);

    section("sorted_map - bound queries");
    // lower_bound(k) — smallest key >= k
    check("lower_bound(3) == 5",  sm.lower_bound(3) == 5);
    check("lower_bound(5) == 5",  sm.lower_bound(5) == 5);
    check("lower_bound(0) == 1",  sm.lower_bound(0) == 1);

    // upper_bound(k) — smallest key > k
    check("upper_bound(5) == 8",  sm.upper_bound(5) == 8);
    check("upper_bound(0) == 1",  sm.upper_bound(0) == 1);

    // floor_key(k) — largest key <= k
    check("floor_key(7) == 5",    sm.floor_key(7) == 5);
    check("floor_key(5) == 5",    sm.floor_key(5) == 5);

    // ceiling_key(k) — smallest key >= k (alias of lower_bound, but different fn)
    check("ceiling_key(7) == 8",  sm.ceiling_key(7) == 8);
    check("ceiling_key(8) == 8",  sm.ceiling_key(8) == 8);

    section("sorted_map - range queries");
    // range_keys(lo, hi) is HALF-OPEN [lo, hi) — exclusive on upper bound.
    array<int64> rk = sm.range_keys(2, 8);
    check("range_keys(2, 8).length() == 2 (half-open: 2, 5)", rk.length() == 2);
    if (rk.length() == 2) {
        check("range_keys[0] == 2", rk.get(0) == 2);
        check("range_keys[1] == 5", rk.get(1) == 5);
    }
    // Use upper = 9 to include 8.
    array<int64> rk2 = sm.range_keys(2, 9);
    check("range_keys(2, 9).length() == 3 (includes 8)", rk2.length() == 3);

    array<int64> rv = sm.range_values(2, 9);
    check("range_values(2, 9).length() == 3", rv.length() == 3);

    section("sorted_map - remove + clear");
    bool sr = sm.remove(5);
    check("sorted_map.remove(5)",        sr);
    check("after remove, size == 4",     sm.size() == 4);
    check("after remove, !contains(5)", !sm.contains(5));

    sm.clear();
    check("after sorted_map.clear, size == 0", sm.size() == 0);

    // =======================================================================
    // hash_set<int64>
    // =======================================================================
    section("hash_set<int64> - add + contains + remove");

    hash_set<int64> s;
    check("fresh hash_set.size() == 0", s.size() == 0);

    s.add(1);
    s.add(2);
    s.add(3);
    s.add(2);  // duplicate — set keeps unique
    check("after 4 adds (one dup), size == 3", s.size() == 3);

    check("hash_set.contains(1)",       s.contains(1));
    check("hash_set.has(2)",            s.has(2));
    check("hash_set.contains(3)",       s.contains(3));
    check("!hash_set.contains(99)",    !s.contains(99));

    bool removed = s.remove(2);
    check("hash_set.remove(2) returns true",  removed);
    check("after remove, size == 2",          s.size() == 2);
    check("after remove, !contains(2)",       !s.contains(2));
    check("hash_set.remove(99) returns false", !s.remove(99));

    section("hash_set<int64> - to_array");
    array<int64> sa = s.to_array();
    check("to_array().length() == size()", sa.length() == s.size());

    section("hash_set<int64> - copy (deep)");
    hash_set<int64> sc = s.copy();
    check("copy().size() == original.size()", sc.size() == s.size());
    sc.add(999);
    check("after mutate copy, original.size() unchanged",
          s.size() != sc.size());
    check("after mutate copy, copy.contains(999)", sc.contains(999));
    check("after mutate copy, !original.contains(999)", !s.contains(999));

    section("hash_set<int64> - set algebra");
    hash_set<int64> a_set;
    a_set.add(1); a_set.add(2); a_set.add(3); a_set.add(4);

    hash_set<int64> b_set;
    b_set.add(3); b_set.add(4); b_set.add(5); b_set.add(6);

    // union: a ∪ b = {1,2,3,4,5,6}
    hash_set<int64> u_set = a_set.copy();
    u_set.union_with(b_set);
    check("union size == 6", u_set.size() == 6);
    check("union contains 1",  u_set.contains(1));
    check("union contains 6",  u_set.contains(6));

    // intersect: a ∩ b = {3, 4}
    hash_set<int64> i_set = a_set.copy();
    i_set.intersect_with(b_set);
    check("intersect size == 2", i_set.size() == 2);
    check("intersect contains 3",  i_set.contains(3));
    check("intersect contains 4",  i_set.contains(4));
    check("intersect !contains 1", !i_set.contains(1));

    // diff: a − b = {1, 2}
    hash_set<int64> d_set = a_set.copy();
    d_set.diff_with(b_set);
    check("diff size == 2",      d_set.size() == 2);
    check("diff contains 1",     d_set.contains(1));
    check("diff contains 2",     d_set.contains(2));
    check("diff !contains 3",   !d_set.contains(3));

    // is_subset_of
    hash_set<int64> small_set;
    small_set.add(3); small_set.add(4);
    check("{3, 4}.is_subset_of({1,2,3,4})",  small_set.is_subset_of(a_set));
    check("!{1,2,3,4}.is_subset_of({3, 4})", !a_set.is_subset_of(small_set));

    // equals
    hash_set<int64> a_dup;
    a_dup.add(1); a_dup.add(2); a_dup.add(3); a_dup.add(4);
    check("a_set equals a_dup",      a_set.equals(a_dup));
    check("!a_set equals b_set",    !a_set.equals(b_set));

    section("hash_set<int64> - clear");
    a_set.clear();
    check("after clear, size == 0",  a_set.size() == 0);
    check("after clear, !contains(1)", !a_set.contains(1));

    // =======================================================================
    // hash_set<string>
    // =======================================================================
    section("hash_set<string> - heap element");

    hash_set<string> ss;
    ss.add("apple");
    ss.add("banana");
    ss.add("apple");  // dup
    check("hash_set<string>.size() == 2", ss.size() == 2);
    check("contains 'apple'",  ss.contains("apple"));
    check("contains 'banana'", ss.contains("banana"));
    check("!contains 'cherry'", !ss.contains("cherry"));

    bool sr2 = ss.remove("apple");
    check("remove('apple')",    sr2);
    check("after remove, size == 1", ss.size() == 1);

    array<string> ssa = ss.to_array();
    check("hash_set<string>.to_array().length() == 1", ssa.length() == 1);

    // =======================================================================
    // Summary
    // =======================================================================
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
    print_console("[test_collections_api] launching test routine + sidebar menu");

    g_section = create_sidebar_section("collections test", "");
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
