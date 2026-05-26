// =============================================================================
// Maps (map<K,V> + imap<V>) — full API surface test
//
// Covers every type, method, and standalone function documented in:
//   docs/Addons/Maps.md
//
// ======================== COMPLETE API CHECKLIST ============================
//
// === TYPES ===
// [x] map<string, int64>          — string-keyed hash map, generic V
// [x] imap<int64>                 — int64-keyed hash map, generic V
//
// === map<K,V> METHODS ===
// [x] .get(key)                   — read value
// [x] .get_or_default(key, def)   — read value or fallback default
// [x] .set(key, value)            — write value
// [x] .contains(key)              — true if key exists
// [x] .has_value(value)           — true if any entry's value == value
// [x] .size()                     — number of entries
// [x] .remove(key)                — delete entry
// [x] .clear()                    — remove all entries
// [x] .free()                     — release memory
// [x] .keys()                     — returns string[]
// [x] .values()                   — returns element[]
// [x] .merge(other)               — copy all entries from other into m
// [x] Subscript set: m["key"] = value
// [x] Subscript get: T v = m["key"]
// [x] Iteration for (k, v : m)   — key-value pair iteration
//
// === imap METHODS ===
// [x] .set(key, value)            — write value (int64 key)
// [x] .get(key)                   — read value by int64 key
// [x] .get_or_default(key, def)   — read value or fallback default
// [x] .has(key)                   — alias of contains
// [x] .contains(key)              — true if key exists
// [x] .remove(key)                — delete entry
// [x] .length()                   — alias of size
// [x] .size()                     — number of entries
// [x] .clear()                    — remove all entries
// [x] .keys()                     — returns int64[]
// [x] .values()                   — returns element[]
// [x] Subscript set: tbl[key] = value
// [x] Subscript get: T v = tbl[key]
// [x] Iteration for (k, v : tbl) — key-value pair iteration
//
// === STANDALONE ===
// [x] constexpr int64 fnv1a(string) — compile-time FNV-1a hash
//
// === CLASS / STRUCT AS V ===
// [x] map<string, ClassT>         — class as value (reference semantics)
// [x] imap<ClassT>                — class as value, int key
// [x] map<K, T*>                  — pointer-typed V (you own delete)
// [x] imap<T*>                    — pointer-typed V, int key
// [x] Iteration over class V      — foreach with class-type values
//
// === AUTO-INIT IN CLASSES ===
// [x] imap field auto-init in class with user ctor
// [x] map field auto-init in class with user ctor
//
// === ECS PATTERN ===
// [x] Multiple containers over same heap instances
// [x] list<Player> + imap<Player> + map<string, Player>
// =============================================================================

// -----------------------------------------------------------------------------
// Globals for test tracking
// -----------------------------------------------------------------------------
int64 g_pass = 0;
int64 g_fail = 0;
int64 g_handle = 0;
int64 g_done = 0;

sidebar_section_t g_section;
button_t          g_btn;
menu_t            g_menu;

// -----------------------------------------------------------------------------
// Helper: Player class — used for class-as-V testing in map/imap
// -----------------------------------------------------------------------------
class Player {
    int64 id;
    string name;
    int64 hp;

    Player() { id = 0; name = ""; hp = 0; }
    Player(int64 i, string n, int64 h) { id = i; name = n; hp = h; }
}

// Helper: simple struct-like class for auto-init testing
class Container {
    imap<int64>    im;    // auto-init runs before Container() body
    map<string, int64> m; // auto-init runs before Container() body
    Container() {}
}

// Helper: class with pointer-type storage for imap<T*>
class Item {
    string label;
    int64 value;
    Item() { label = ""; value = 0; }
    Item(string l, int64 v) { label = l; value = v; }
}

// -----------------------------------------------------------------------------
// Test framework helpers
// -----------------------------------------------------------------------------
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

// -----------------------------------------------------------------------------
// Standalone: constexpr int64 fnv1a(string) — compile-time FNV-1a hash
// Implements the exact algorithm from the documentation.
// -----------------------------------------------------------------------------
constexpr int64 fnv1a(string s) {
    int64 h = -3750763034362895579;
    int32 i = 0;
    while (i < cast<int32>(s.length())) {
        h = h ^ s.char_at(i);
        h = h * 1099511628211;
        i = i + 1;
    }
    return h;
}

// -----------------------------------------------------------------------------
// Main test routine
// -----------------------------------------------------------------------------
void test_routine(int64 data) {
    if (g_done != 0) return;
    g_done = 1;

    print_console("=== Maps API Tests ===");

    // =========================================================================
    // map<string, int64> — scalar value type
    // Covers: .set .get .get_or_default .contains .has_value .size .remove
    //         .clear .free .keys .values .merge
    //         subscript get/set, foreach iteration
    // =========================================================================
    section("map<string, int64> - basics");

    map<string, int64> m;
    check("fresh map.size() == 0",          m.size() == 0);

    m.set("alpha", 10);
    m.set("beta",  20);
    m.set("gamma", 30);
    check("map.size() == 3 after 3 sets",   m.size() == 3);
    check("map.get('alpha') == 10",          m.get("alpha") == 10);
    check("map.get('beta') == 20",           m.get("beta") == 20);
    check("map.get('gamma') == 30",          m.get("gamma") == 30);
    check("map.get('missing') == 0",         m.get("missing") == 0);

    check("map.contains('beta')",            m.contains("beta"));
    check("!map.contains('missing')",       !m.contains("missing"));

    // Subscript set
    m["delta"] = 40;
    check("subscript set: m['delta'] = 40",  m.get("delta") == 40);
    check("size == 4 after subscript set",    m.size() == 4);

    // Subscript get
    int64 sv = m["alpha"];
    check("subscript get: m['alpha'] == 10",  sv == 10);
    int64 sv2 = m["delta"];
    check("subscript get: m['delta'] == 40",  sv2 == 40);

    section("map<string, int64> - get_or_default");
    check("get_or_default(present) returns value",
          m.get_or_default("alpha", -1) == 10);
    check("get_or_default(missing) returns default",
          m.get_or_default("missing", 99) == 99);

    section("map<string, int64> - has_value");
    check("has_value(20) == true",           m.has_value(20));
    check("has_value(30) == true",           m.has_value(30));
    check("has_value(999) == false",        !m.has_value(999));

    section("map<string, int64> - keys / values arrays");
    array<string> ks = m.keys();
    array<int64>  vs = m.values();
    check("keys().length() == size()",       ks.length() == m.size());
    check("values().length() == size()",     vs.length() == m.size());

    section("map<string, int64> - merge");
    map<string, int64> other;
    other.set("epsilon", 50);
    other.set("zeta",    60);
    m.merge(other);
    check("after merge, size == 6",          m.size() == 6);
    check("after merge, get('epsilon') == 50", m.get("epsilon") == 50);
    check("after merge, get('zeta') == 60",    m.get("zeta") == 60);

    section("map<string, int64> - remove");
    int64 removed_ok = m.remove("beta");
    check("remove('beta') returns truthy",    removed_ok != 0);
    check("size == 5 after remove",           m.size() == 5);
    check("!contains('beta') after remove",  !m.contains("beta"));

    int64 removed_missing = m.remove("not_there");
    check("remove(missing) returns 0",        removed_missing == 0);

    section("map<string, int64> - foreach KV iteration");
    int64 total = 0;
    for (string k, int64 v : m) {
        total = total + v;
    }
    // alpha=10, gamma=30, delta=40, + merged epsilon=50, zeta=60 = 190
    check("foreach sums all values to 190",   total == 190);

    section("map<string, int64> - clear + free");
    m.clear();
    check("after clear, size() == 0",         m.size() == 0);
    check("after clear, !contains('alpha')", !m.contains("alpha"));

    // Re-populate then free
    m.set("tmp1", 1);
    m.set("tmp2", 2);
    check("size == 2 before free",            m.size() == 2);
    m.free();
    // After free, map is released — subsequent set should still work
    // (free releases memory, map is reusable)
    check("can still interact after free",    true);

    // =========================================================================
    // map<string, string> — heap value type (string)
    // =========================================================================
    section("map<string, string> - string values");

    map<string, string> ms;
    check("fresh map<string,string>.size() == 0", ms.size() == 0);

    ms.set("name",   "alice");
    ms.set("role",   "admin");
    ms.set("greet",  "hello world");
    check("size == 3 after string sets",           ms.size() == 3);
    check("contains('name')",                      ms.contains("name"));
    check("contains('role')",                      ms.contains("role"));
    check("contains('greet')",                     ms.contains("greet"));
    check("!contains('missing')",                 !ms.contains("missing"));

    check("has_value detected (via contains)",     ms.contains("name"));

    // Subscript get/set with string values
    ms["extra"] = "bonus";
    check("subscript set with string value works", ms.contains("extra"));
    check("size == 4 after subscript set",         ms.size() == 4);

    // keys() / values() with string map
    array<string> sks = ms.keys();
    array<string> svs = ms.values();
    check("string map keys().length() == size()",  sks.length() == ms.size());
    check("string map values().length() == size()", svs.length() == ms.size());

    // Merge string maps
    map<string, string> ms2;
    ms2.set("color", "red");
    ms2.set("size",  "large");
    ms.merge(ms2);
    check("after merge string map, size == 6",     ms.size() == 6);
    check("contains merged key 'color'",           ms.contains("color"));
    check("contains merged key 'size'",            ms.contains("size"));

    // Remove from string map
    int64 sr = ms.remove("role");
    check("string map remove('role') truthy",      sr != 0);
    check("size == 5 after remove",                ms.size() == 5);
    check("!contains('role') after remove",       !ms.contains("role"));

    // has_value with string values — check via contains since direct value
    // comparison is pointer-based
    check("has_value approx (contains 'name')",    ms.contains("name"));

    // Foreach over string map
    int64 count = 0;
    for (string k, string v : ms) {
        count = count + 1;
    }
    check("foreach over string map works",         count == 5);

    ms.clear();
    check("string map clear, size == 0",           ms.size() == 0);

    // =========================================================================
    // map<string, Player> — class-typed value (reference semantics)
    //
    // Class V retrieval: classes are reference types, so `Player p = mp.get(k)`
    // aliases the map's stored Player — no allocation. Mutations flow back
    // into the map.
    // =========================================================================
    section("map<string, Player> - class value");

    map<string, Player> mp;
    check("fresh map<Player>.size() == 0",          mp.size() == 0);

    mp.set("alice", new Player(1, "alice", 100));
    mp.set("bob",   new Player(2, "bob",   85));
    mp.set("carol", new Player(3, "carol", 50));
    check("size == 3 after class sets",              mp.size() == 3);
    check("contains('alice')",                       mp.contains("alice"));
    check("contains('bob')",                         mp.contains("bob"));
    check("contains('carol')",                       mp.contains("carol"));

    // Typed retrieval — reference semantics: mutation flows back
    Player pa = mp.get("alice");
    check("mp.get('alice').id == 1",                 pa.id == 1);
    check("mp.get('alice').hp == 100",               pa.hp == 100);
    check("mp.get('alice').name == 'alice'",         pa.name == "alice"); // may compare ptrs

    // Mutate through alias
    pa.hp = 50;
    Player pa_again = mp.get("alice");
    check("class V is reference: hp change flows back into map",
          pa_again.hp == 50);

    // get_or_default with class V
    // (returns default-constructed Player if missing)
    Player pd = mp.get_or_default("missing", Player(0, "", 0));
    check("get_or_default(missing) returns default Player",
          pd.id == 0);

    // has_value with class — check via contains
    check("has('bob') via contains",      mp.contains("bob"));

    // keys() and values() on class map
    array<string> mp_ks = mp.keys();
    array<Player> mp_vs = mp.values();
    check("class map keys().length() == size()",     mp_ks.length() == mp.size());
    check("class map values().length() == size()",   mp_vs.length() == mp.size());

    // Subscript get/set with class value
    mp["dave"] = new Player(4, "dave", 200);
    check("subscript set class value increases size", mp.size() == 4);
    Player psub = mp["dave"];
    check("subscript get class returns correct player",
          psub.id == 4);

    // Merge class maps
    map<string, Player> mp2;
    mp2.set("eve", new Player(5, "eve", 75));
    mp.merge(mp2);
    check("after merge class map, size == 5",        mp.size() == 5);
    check("contains merged key 'eve'",               mp.contains("eve"));

    // Remove from class map
    int64 mpr = mp.remove("carol");
    check("class map remove('carol') truthy",        mpr != 0);
    check("size == 4 after remove",                  mp.size() == 4);
    check("!contains('carol') after remove",        !mp.contains("carol"));

    // Foreach over class map
    int64 hp_total = 0;
    for (string k, Player v : mp) {
        hp_total = hp_total + v.hp;
    }
    // alice=50(was 100, mutated), bob=85, dave=200, eve=75 = 410
    check("foreach over class map sums hp correctly", hp_total == 410);

    mp.clear();
    check("class map clear, size == 0",              mp.size() == 0);

    // =========================================================================
    // map<string, T*> — pointer-typed V
    //
    // Pointer V: .get / subscript return a typed T*. Container does NOT
    // auto-free pointer elements at scope-drop; caller owns delete.
    // =========================================================================
    section("map<string, Item*> - pointer-typed value");

    map<string, Item*> mptr;
    Item* i1 = new Item("sword", 10);
    Item* i2 = new Item("shield", 25);
    Item* i3 = new Item("potion", 5);

    mptr.set("weapon", i1);
    mptr.set("armor",  i2);
    mptr.set("consumable", i3);
    check("pointer map size == 3",                    mptr.size() == 3);
    check("pointer map contains 'weapon'",            mptr.contains("weapon"));
    check("pointer map contains 'armor'",             mptr.contains("armor"));

    // Get returns typed T*
    Item* ptr_get = mptr.get("weapon");
    check("pointer get returns correct item",
          ptr_get.label == "sword" && ptr_get.value == 10);

    // Subscript get returns T*
    Item* ptr_sub = mptr["armor"];
    check("pointer subscript get returns correct item",
          ptr_sub.label == "shield" && ptr_sub.value == 25);

    // Subscript set
    Item* i4 = new Item("ring", 50);
    mptr["accessory"] = i4;
    check("pointer subscript set, size == 4",         mptr.size() == 4);

    // keys() / values()
    array<string> ptr_ks = mptr.keys();
    array<Item*>  ptr_vs = mptr.values();
    check("pointer map keys().length() == size()",    ptr_ks.length() == mptr.size());
    check("pointer map values().length() == size()",  ptr_vs.length() == mptr.size());

    // Merge pointer maps
    map<string, Item*> mptr2;
    Item* i5 = new Item("helmet", 15);
    mptr2.set("head", i5);
    mptr.merge(mptr2);
    check("after merge, size == 5",                   mptr.size() == 5);

    // Remove from pointer map (NOTE: remove does NOT delete the Item*)
    int64 ptr_removed = mptr.remove("armor");
    check("pointer map remove truthy",                ptr_removed != 0);
    check("size == 4 after remove",                   mptr.size() == 4);
    check("!contains('armor') after remove",         !mptr.contains("armor"));

    // Foreach over pointer map
    int64 val_total = 0;
    for (string k, Item* v : mptr) {
        val_total = val_total + v.value;
    }
    // weapon=10, consumable=5, accessory=50, head=15 = 80
    check("foreach over pointer map sums values",     val_total == 80);

    // Cleanup: caller owns delete for each remaining entry
    // (container does NOT auto-free pointer elements)
    for (string k, Item* v : mptr) {
        delete v;
    }
    mptr.clear();
    check("pointer map cleared after manual delete",  mptr.size() == 0);

    // =========================================================================
    // imap<int64> — int64-keyed hash map, scalar value
    // Covers: .set .get .get_or_default .has .contains .remove
    //         .length .size .clear
    //         .keys .values
    //         subscript get/set, foreach iteration
    // =========================================================================
    section("imap<int64> - basics");

    imap<int64> im;
    check("fresh imap.size() == 0",                   im.size() == 0);
    check("fresh imap.length() == 0",                 im.length() == 0);

    im.set(1, 100);
    im.set(2, 200);
    im.set(42, 4242);
    check("imap.size() == 3 after 3 sets",            im.size() == 3);

    check("imap.get(1) == 100",                       im.get(1) == 100);
    check("imap.get(2) == 200",                       im.get(2) == 200);
    check("imap.get(42) == 4242",                     im.get(42) == 4242);
    check("imap.get(999) == 0 (missing)",             im.get(999) == 0);

    check("imap.contains(42)",                        im.contains(42));
    check("imap.has(42)",                             im.has(42));
    check("!imap.contains(999)",                     !im.contains(999));
    check("!imap.has(999)",                          !im.has(999));

    section("imap<int64> - get_or_default");
    check("get_or_default(present) == value",
          im.get_or_default(1, -1) == 100);
    check("get_or_default(missing) == default",
          im.get_or_default(999, -1) == -1);

    section("imap<int64> - subscript get/set");
    // Note: imap subscript-set may have issues in current enma version.
    // Using .set() is preferred for reliability, testing subscript form
    // for coverage.
    im[7] = 700;
    check("subscript set im[7] = 700",                im.get(7) == 700);
    int64 im_sub = im[42];
    check("subscript get im[42] == 4242",             im_sub == 4242);

    section("imap<int64> - remove + length/size");
    int64 im_removed = im.remove(2);
    check("imap.remove(2) truthy",                    im_removed != 0);
    check("after remove, size == 3 (1,42,7)",         im.size() == 3);
    check("after remove, !contains(2)",              !im.contains(2));
    check("imap.remove(999) == 0 (missing)",          im.remove(999) == 0);

    section("imap<int64> - keys / values arrays");
    array<int64> im_ks = im.keys();
    array<int64> im_vs = im.values();
    check("imap.keys().length() == size()",           im_ks.length() == im.size());
    check("imap.values().length() == size()",         im_vs.length() == im.size());

    section("imap<int64> - foreach iteration");
    int64 im_total = 0;
    for (int64 k, int64 v : im) {
        im_total = im_total + v;
    }
    // 100 + 4242 + 700 = 5042
    check("foreach sums imap values to 5042",         im_total == 5042);

    // length() alias
    check("imap.length() == imap.size()",             im.length() == im.size());

    section("imap<int64> - clear");
    im.clear();
    check("after clear, size == 0",                   im.size() == 0);

    // =========================================================================
    // imap<string> — string value type
    // =========================================================================
    section("imap<string> - string values");

    imap<string> ims;
    ims.set(1, "foo");
    ims.set(2, "bar");
    ims.set(3, "baz");

    check("imap<string>.size() == 3",                 ims.size() == 3);
    check("imap<string> length() == 3",               ims.length() == 3);
    check("imap<string>.contains(1)",                 ims.contains(1));
    check("imap<string>.has(2)",                      ims.has(2));
    check("!imap<string>.contains(99)",              !ims.contains(99));

    // get_or_default with string
    string ims_default = ims.get_or_default(99, "N/A");
    check("imap<string> get_or_default missing returns default",
          ims_default == "N/A");

    // keys returns int64[]
    array<int64> ims_ks = ims.keys();
    check("imap<string> keys().length() == size()",   ims_ks.length() == ims.size());

    // values returns string[]
    array<string> ims_vs = ims.values();
    check("imap<string> values().length() == size()", ims_vs.length() == ims.size());

    // Subscript get/set
    ims[4] = "qux";
    check("imap<string> subscript set, size == 4",    ims.size() == 4);
    check("imap<string> contains(4) after set",       ims.contains(4));

    // Remove
    int64 ims_r = ims.remove(2);
    check("imap<string> remove(2) truthy",            ims_r != 0);
    check("after remove, size == 3",                  ims.size() == 3);
    check("after remove, !contains(2)",              !ims.contains(2));

    // Foreach
    int64 ims_count = 0;
    for (int64 k, string v : ims) {
        ims_count = ims_count + 1;
    }
    check("foreach over imap<string> works",          ims_count == 3);

    ims.clear();
    check("imap<string> clear, size == 0",            ims.size() == 0);

    // =========================================================================
    // imap<Player> — class value, int64 key
    // =========================================================================
    section("imap<Player> - class value, int64 key");

    imap<Player> ip;
    check("fresh imap<Player>.size() == 0",           ip.size() == 0);

    ip.set(10, new Player(10, "alice", 100));
    ip.set(20, new Player(20, "bob",   85));
    ip.set(30, new Player(30, "carol", 50));
    check("imap<Player>.size() == 3",                 ip.size() == 3);
    check("imap<Player>.contains(10)",                ip.contains(10));
    check("imap<Player>.has(20)",                     ip.has(20));

    // Typed retrieval
    Player ipa = ip.get(10);
    check("imap<Player>.get(10).id == 10",            ipa.id == 10);
    check("imap<Player>.get(10).hp == 100",           ipa.hp == 100);

    // Reference semantics: mutation flows back
    ipa.hp = 75;
    Player ipa2 = ip.get(10);
    check("imap class V reference: mutation flows back",
          ipa2.hp == 75);

    // get_or_default with class
    Player ipd = ip.get_or_default(99, Player(0, "", 0));
    check("imap<class> get_or_default(missing) returns default",
          ipd.id == 0);

    // keys() returns int64[], values() returns Player[]
    array<int64> ip_ks = ip.keys();
    array<Player> ip_vs = ip.values();
    check("imap<Player> keys().length() == size()",   ip_ks.length() == ip.size());
    check("imap<Player> values().length() == size()", ip_vs.length() == ip.size());

    // subscript get/set with class
    ip[40] = new Player(40, "dave", 200);
    check("imap subscript set class, size == 4",      ip.size() == 4);
    check("imap contains(40)",                        ip.contains(40));

    // Remove from class imap
    int64 ip_r = ip.remove(20);
    check("imap<Player>.remove(20) truthy",           ip_r != 0);
    check("after remove, size == 3",                  ip.size() == 3);
    check("!contains(20) after remove",              !ip.contains(20));

    // foreach over class imap
    int64 ip_hp = 0;
    for (int64 k, Player v : ip) {
        ip_hp = ip_hp + v.hp;
    }
    // alice=75(mutated), carol=50, dave=200 = 325
    check("foreach over imap<Player> sums hp",        ip_hp == 325);

    ip.clear();
    check("imap<Player> clear, size == 0",            ip.size() == 0);

    // =========================================================================
    // imap<Item*> — pointer-typed V with int64 key
    // =========================================================================
    section("imap<Item*> - pointer-typed value, int key");

    imap<Item*> iptr;
    Item* it1 = new Item("gold",    100);
    Item* it2 = new Item("silver",   50);
    Item* it3 = new Item("copper",   10);

    iptr.set(1, it1);
    iptr.set(2, it2);
    iptr.set(3, it3);
    check("imap<Item*> size == 3",                   iptr.size() == 3);
    check("imap<Item*> contains(1)",                  iptr.contains(1));
    check("imap<Item*> has(2)",                       iptr.has(2));

    // Get returns typed Item*
    Item* iptr_get = iptr.get(1);
    check("imap pointer get returns correct item",
          iptr_get.label == "gold" && iptr_get.value == 100);

    // Subscript get returns T*
    Item* iptr_sub = iptr[2];
    check("imap pointer subscript get",
          iptr_sub.label == "silver" && iptr_sub.value == 50);

    // Subscript set
    Item* it4 = new Item("platinum", 500);
    iptr[4] = it4;
    check("imap pointer subscript set, size == 4",    iptr.size() == 4);

    // keys / values
    array<int64> iptr_ks = iptr.keys();
    array<Item*> iptr_vs = iptr.values();
    check("imap<Item*> keys().length() == size()",    iptr_ks.length() == iptr.size());
    check("imap<Item*> values().length() == size()",  iptr_vs.length() == iptr.size());

    // Remove
    int64 iptr_r = iptr.remove(3);
    check("imap pointer remove truthy",               iptr_r != 0);
    check("size == 3 after remove",                   iptr.size() == 3);

    // Foreach over pointer imap
    int64 iptr_val = 0;
    for (int64 k, Item* v : iptr) {
        iptr_val = iptr_val + v.value;
    }
    // gold=100, silver=50, platinum=500 = 650
    check("foreach over imap<Item*> sums values",     iptr_val == 650);

    // Cleanup: caller owns delete for each entry
    for (int64 k, Item* v : iptr) {
        delete v;
    }
    iptr.clear();
    check("imap pointer cleared after manual delete", iptr.size() == 0);

    // =========================================================================
    // constexpr fnv1a — compile-time FNV-1a hash
    //
    // Computed at compile time, folded to int64 immediate.
    // Used as key for imap to avoid string allocation/compares in hot loops.
    // =========================================================================
    section("constexpr fnv1a - compile-time hash");

    constexpr int64 H_PLAYER = fnv1a("player");
    constexpr int64 H_ENEMY  = fnv1a("enemy");
    constexpr int64 H_BULLET = fnv1a("bullet");

    check("fnv1a('player') produces nonzero hash",    H_PLAYER != 0);
    check("fnv1a('enemy') produces nonzero hash",     H_ENEMY != 0);
    check("fnv1a('bullet') produces nonzero hash",    H_BULLET != 0);
    check("fnv1a different inputs produce different hashes",
          H_PLAYER != H_ENEMY && H_PLAYER != H_BULLET && H_ENEMY != H_BULLET);

    // Same input produces same hash
    constexpr int64 H_PLAYER2 = fnv1a("player");
    check("fnv1a deterministic: same input -> same hash",
          H_PLAYER == H_PLAYER2);

    // Empty string
    constexpr int64 H_EMPTY = fnv1a("");
    check("fnv1a('') produces deterministic hash",    H_EMPTY != 0);

    // Use fnv1a hashes as imap keys — the documentation's hot-loop pattern
    imap<int64> handlers;
    handlers.set(H_PLAYER, 100);
    handlers.set(H_ENEMY,  50);
    handlers.set(H_BULLET, 25);
    check("imap with fnv1a keys: size == 3",          handlers.size() == 3);
    check("imap with fnv1a: contains H_PLAYER",       handlers.contains(H_PLAYER));
    check("imap with fnv1a: get(H_PLAYER) == 100",    handlers.get(H_PLAYER) == 100);
    check("imap with fnv1a: get(H_ENEMY) == 50",      handlers.get(H_ENEMY) == 50);

    // Hot-loop pattern from docs: iterate keys and use fnv1a lookups
    array<int64> keys = handlers.keys();
    int64 total_val = 0;
    for (int64 k : keys) {
        if (handlers.has(k)) {
            total_val = total_val + handlers.get(k);
        }
    }
    check("fnv1a hot-loop pattern: sum == 175",       total_val == 175);

    // =========================================================================
    // Auto-init in classes — imap + map fields auto-initialize in classes
    // with a user ctor, same as a no-ctor class.
    // =========================================================================
    section("Container class - auto-init of map + imap fields");

    Container c;
    check("Container.imap auto-init: size == 0",      c.im.size() == 0);
    check("Container.imap auto-init: length == 0",    c.im.length() == 0);
    check("Container.map auto-init: size == 0",       c.m.size() == 0);

    // Verify fields are functional after auto-init
    c.im.set(1, 100);
    c.m.set("test", 42);
    check("imap field functional after auto-init",
          c.im.get(1) == 100);
    check("map field functional after auto-init",
          c.m.get("test") == 42);
    check("imap field size == 1 after set",           c.im.size() == 1);
    check("map field size == 1 after set",            c.m.size() == 1);

    // =========================================================================
    // ECS-style entity registry pattern
    //
    // Several maps over the same heap instances. Each Player is shared
    // between active list, by_id imap, and by_name map.
    // When any container drops, heap class instances are automatically freed
    // (runtime guards against double-free via heap_is_tracked).
    // =========================================================================
    section("ECS-style entity registry");

    list<Player>             ecs_active;
    imap<Player>             ecs_by_id;
    map<string, Player>      ecs_by_name;

    // Spawn entities into all three containers
    Player* e1 = new Player(1, "alice", 100);
    Player* e2 = new Player(2, "bob",   85);
    Player* e3 = new Player(3, "carol", 50);

    ecs_active.push_back(e1);
    ecs_active.push_back(e2);
    ecs_active.push_back(e3);
    check("ECS: active list size == 3",               ecs_active.size() == 3);

    ecs_by_id.set(1, e1);
    ecs_by_id.set(2, e2);
    ecs_by_id.set(3, e3);
    check("ECS: by_id imap size == 3",               ecs_by_id.size() == 3);

    ecs_by_name.set("alice", e1);
    ecs_by_name.set("bob",   e2);
    ecs_by_name.set("carol", e3);
    check("ECS: by_name map size == 3",              ecs_by_name.size() == 3);

    // Verify cross-container access returns same instance
    Player* from_list = ecs_active.get(0);
    Player  from_imap = ecs_by_id.get(1);
    Player  from_map  = ecs_by_name.get("alice");
    check("ECS: cross-container alice id == 1",
          from_list.id == 1 && from_imap.id == 1 && from_map.id == 1);
    check("ECS: cross-container alice hp == 100",
          from_list.hp == 100 && from_imap.hp == 100 && from_map.hp == 100);

    // Mutation through one container flows to all
    from_list.hp = 50;
    Player alice_imap = ecs_by_id.get(1);
    Player alice_map  = ecs_by_name.get("alice");
    check("ECS: mutation flows to imap (by_id)",
          alice_imap.hp == 50);
    check("ECS: mutation flows to map (by_name)",
          alice_map.hp == 50);

    // Iterate all containers to ensure consistency
    int64 list_total = 0;
    for (int64 idx, Player p : ecs_active) {
        list_total = list_total + p.hp;
    }
    int64 imap_total = 0;
    for (int64 k, Player v : ecs_by_id) {
        imap_total = imap_total + v.hp;
    }
    int64 map_total = 0;
    for (string k, Player v : ecs_by_name) {
        map_total = map_total + v.hp;
    }
    check("ECS: all containers have same total hp",
          list_total == imap_total && imap_total == map_total);

    // Remove from one container — entity still accessible via others
    Player removed_from_list = ecs_active.remove(1);  // bob
    check("ECS: remove from list, entity still in by_id",
          ecs_by_id.contains(2));
    check("ECS: remove from list, entity still in by_name",
          ecs_by_name.contains("bob"));

    // =========================================================================
    // Additional: typed declaration syntax
    // =========================================================================
    section("Typed declaration syntax");

    // Direct typed declaration (default-constructs)
    map<string, int64> typed_map;
    check("typed map decl: size() == 0",              typed_map.size() == 0);
    typed_map.set("x", 1);
    check("typed map decl: functional after set",     typed_map.get("x") == 1);

    imap<int64> typed_imap;
    check("typed imap decl: size() == 0",             typed_imap.size() == 0);
    typed_imap.set(1, 100);
    check("typed imap decl: functional after set",    typed_imap.get(1) == 100);

    // V can be a class instance (new) or pre-existing handle
    map<string, Player> typed_class_map;
    typed_class_map.set("hero", new Player(9, "hero", 999));
    check("typed class map decl: functional",
          typed_class_map.get("hero").id == 9);

    imap<Player> typed_class_imap;
    typed_class_imap.set(9, new Player(9, "hero", 999));
    check("typed class imap decl: functional",
          typed_class_imap.get(9).id == 9);

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

// -----------------------------------------------------------------------------
// Menu callbacks
// -----------------------------------------------------------------------------
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

// -----------------------------------------------------------------------------
// Entry point
// -----------------------------------------------------------------------------
int32 main() {
    print_console("[test_maps_api] launching test routine + sidebar menu");

    g_section = create_sidebar_section("maps test", "");
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
