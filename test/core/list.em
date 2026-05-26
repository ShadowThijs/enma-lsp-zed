// =============================================================================
// list<T> — comprehensive exercise of every type, method, and standalone
// function documented in the List addon.
//
// DOCUMENTATION SOURCE: docs/Addons/List.md
//
// ── TYPE ─────────────────────────────────────────────────────────────────────
//   T  list<T>                       generic double-ended container
//     (also list<T*> for user-managed pointer elements)
//
// ── METHODS on list<T> ───────────────────────────────────────────────────────
//   Add / remove:
//     M  push_back(x)                append (alias: push)
//     M  push_front(x)               prepend
//     M  pop_back()                  remove + return last (alias: pop)
//     M  pop_front()                 remove + return first
//     M  insert(idx, x)              insert at idx (clamps oob to end)
//     M  remove(idx)                 remove + return at idx (returns 0 if oob)
//
//   Access:
//     M  get(idx)                    bounds-checked; returns 0 if oob (alias: at)
//     M  set(idx, x)                 bounds-checked; no-op if oob
//     M  lst[idx]                    subscript (read + write)
//     M  first()                     front element (0 if empty)
//     M  last()                      back element (0 if empty)
//
//   Search:
//     M  contains(x)                 true if any element equals x (alias: has)
//     M  index_of(x)                 index of first match, or -1
//
//   Size:
//     M  size()                      alias: length()
//     M  empty()                     == size() == 0
//
//   Modify:
//     M  clear()                     empty the list
//     M  reverse()                   in-place reverse
//
//   Conversion / combine / copy:
//     M  to_array()                  snapshot to array<T>, preserves order
//     M  copy()                      independent shallow copy
//     M  extend(other)               append every element of `other`
//
//   Iteration:
//     M  for (idx, value : lst)      kv-iterable foreach (index is "key")
//     M  for (value : lst)           value-only foreach
//
// ── CLASS STORAGE PATTERNS ───────────────────────────────────────────────────
//   P  Reference handle semantics    list stores handles, mutation aliases back
//   P  Auto-cleanup in class field   list<T> field in class auto-frees on delete
//   P  Cross-container sharing       same heap instance in list + imap + map
//   P  list<T*> pointer storage      manual pointer management (no auto-free)
//
// ── STANDALONE FUNCTIONS ─────────────────────────────────────────────────────
//   (none — list<T> is purely a type with methods)
//
// TOTAL: 1 type, 22 methods, 4 class-storage patterns
// =============================================================================

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

// =============================================================================
// Helper class for class-storage tests
// =============================================================================
class Entity {
    int64 id;
    int64 hp;
    int64 x;
    int64 y;

    Entity() { id = 0; hp = 0; x = 0; y = 0; }
    Entity(int64 i, int64 h, int64 px, int64 py) {
        id = i; hp = h; x = px; y = py;
    }
}

// =============================================================================
// Helper class for auto-cleanup test (Squad with list<Entity> field)
// =============================================================================
class Squad {
    list<Entity> members;
    string name;
    Squad(string n) { name = n; }
}

// =============================================================================
// Helper class for cross-container sharing test
// =============================================================================
class Player {
    int64 id;
    int64 hp;
    Player(int64 i, int64 h) { id = i; hp = h; }
}

// =============================================================================
// 1. Construction — empty list
// =============================================================================
void test_construction() {
    section("Construction");

    // Empty list<int64>
    list<int64> a;
    check("empty list<int64> created", true);
    check("fresh list.size() == 0", a.size() == 0);

    // Empty list<Entity> (class T)
    list<Entity> ents;
    check("empty list<Entity> created", true);
    check("fresh list<Entity>.size() == 0", ents.size() == 0);
}

// =============================================================================
// 2. Add/remove: push_back, push_front, pop_back, pop_front, insert, remove
//    — including alias forms `push`, `pop`
// =============================================================================
void test_add_remove() {
    section("Add / remove — push_back, push_front, pop_back, pop_front");

    list<int64> lst;

    // push_back — append
    lst.push_back(10);
    lst.push_back(20);
    lst.push_back(30);
    check("push_back: size == 3 after 3x push_back", lst.size() == 3);
    check("push_back: first == 10", lst.first() == 10);
    check("push_back: last == 30",  lst.last() == 30);

    // `push` alias for push_back
    lst.push(40);
    check("push alias: size == 4",  lst.size() == 4);
    check("push alias: last == 40", lst.last() == 40);

    // push_front — prepend
    lst.push_front(0);
    check("push_front: size == 5",   lst.size() == 5);
    check("push_front: first == 0",  lst.first() == 0);

    // pop_back — remove + return last
    int64 pb = lst.pop_back();
    check("pop_back returns 40", pb == 40);
    check("pop_back: size == 4",  lst.size() == 4);
    check("pop_back: last now == 30", lst.last() == 30);

    // `pop` alias for pop_back
    int64 p = lst.pop();
    check("pop alias returns 30", p == 30);
    check("pop alias: size == 3", lst.size() == 3);

    // pop_front — remove + return first
    int64 pf = lst.pop_front();
    check("pop_front returns 0",  pf == 0);
    check("pop_front: size == 2", lst.size() == 2);
    check("pop_front: first now == 10", lst.first() == 10);

    // pop_* on empty returns 0
    lst.clear();
    int64 empty_pop = lst.pop_back();
    check("pop_back on empty returns 0", empty_pop == 0);

    int64 empty_pop_front = lst.pop_front();
    check("pop_front on empty returns 0", empty_pop_front == 0);

    int64 empty_pop_alias = lst.pop();
    check("pop alias on empty returns 0", empty_pop_alias == 0);

    section("Add / remove — insert, remove");

    lst.clear();
    lst.push_back(10);
    lst.push_back(20);
    lst.push_back(30);

    // insert at valid index
    lst.insert(1, 15);
    check("insert(1, 15): size == 4",   lst.size() == 4);
    check("insert(1, 15): get(0) == 10", lst.get(0) == 10);
    check("insert(1, 15): get(1) == 15", lst.get(1) == 15);
    check("insert(1, 15): get(2) == 20", lst.get(2) == 20);

    // insert at OOB (clamps to end)
    lst.insert(99, 40);
    check("insert OOB: last == 40", lst.last() == 40);

    // insert at 0 (prepend equivalent)
    lst.insert(0, 5);
    check("insert(0, 5): first == 5", lst.first() == 5);

    // remove
    int64 r = lst.remove(0);
    check("remove(0) returns 5",  r == 5);
    check("remove(0): first now == 10", lst.first() == 10);

    // remove OOB returns 0
    int64 r_oob = lst.remove(999);
    check("remove(OOB) returns 0", r_oob == 0);
}

// =============================================================================
// 3. Access: get, at, set, subscript [], first, last
// =============================================================================
void test_access() {
    section("Access — get, at, set, subscript, first, last");

    list<int64> lst;
    lst.push_back(100);
    lst.push_back(200);
    lst.push_back(300);
    lst.push_back(400);

    // get
    check("get(0) == 100",      lst.get(0) == 100);
    check("get(2) == 300",      lst.get(2) == 300);
    check("get(3) == 400",      lst.get(3) == 400);

    // get OOB returns 0
    check("get(-1) == 0",       lst.get(-1) == 0);
    check("get(99) == 0",       lst.get(99) == 0);

    // at alias for get
    check("at(0) == 100",       lst.at(0) == 100);
    check("at(2) == 300",       lst.at(2) == 300);
    check("at(99) == 0",        lst.at(99) == 0);

    // set — bounds-checked
    lst.set(1, 999);
    check("set(1, 999): get(1) == 999", lst.get(1) == 999);

    // set OOB is no-op (list unchanged)
    lst.set(99, 12345);
    check("set(OOB): size unchanged",   lst.size() == 4);
    check("set(OOB): last still 400",   lst.last() == 400);

    // subscript — read
    check("subscript read [0] == 100",  lst[0] == 100);
    check("subscript read [2] == 300",  lst[2] == 300);

    // subscript — write
    lst[0] = 111;
    check("subscript write lst[0] = 111: get(0) == 111", lst.get(0) == 111);

    // first / last
    check("first() == 111",             lst.first() == 111);
    check("last() == 400",              lst.last() == 400);

    // first / last on empty returns 0
    list<int64> empty;
    check("first() on empty returns 0", empty.first() == 0);
    check("last() on empty returns 0",  empty.last() == 0);
}

// =============================================================================
// 4. Search: contains, has, index_of
// =============================================================================
void test_search() {
    section("Search — contains, has, index_of");

    list<int64> lst;
    lst.push_back(10);
    lst.push_back(20);
    lst.push_back(30);
    lst.push_back(20);   // duplicate

    // contains
    check("contains(10) true",      lst.contains(10));
    check("contains(20) true",      lst.contains(20));
    check("contains(99) false",    !lst.contains(99));

    // has alias for contains
    check("has(30) true",           lst.has(30));
    check("has(99) false",         !lst.has(99));

    // index_of — returns first match
    check("index_of(10) == 0",      lst.index_of(10) == 0);
    check("index_of(20) == 1",      lst.index_of(20) == 1);
    check("index_of(30) == 2",      lst.index_of(30) == 2);

    // index_of for missing value returns -1
    check("index_of(99) == -1",     lst.index_of(99) == -1);
}

// =============================================================================
// 5. Size: size, length, empty
// =============================================================================
void test_size() {
    section("Size — size, length, empty");

    list<int64> lst;

    check("size() == 0 on fresh list",    lst.size() == 0);
    check("length() == 0 on fresh list",  lst.length() == 0);
    check("empty() on fresh list",        lst.empty());

    lst.push_back(1);
    check("after push, size() == 1",      lst.size() == 1);
    check("after push, length() == 1",    lst.length() == 1);
    check("after push, !empty()",        !lst.empty());

    lst.push_back(2);
    lst.push_back(3);
    check("size() == 3 after 3 pushes",   lst.size() == 3);
    check("length() == 3",                lst.length() == 3);

    lst.clear();
    check("after clear, size() == 0",     lst.size() == 0);
    check("after clear, empty()",         lst.empty());
}

// =============================================================================
// 6. Modify: clear, reverse
// =============================================================================
void test_modify() {
    section("Modify — clear, reverse");

    // clear
    list<int64> lst;
    lst.push_back(1);
    lst.push_back(2);
    lst.push_back(3);
    lst.clear();
    check("clear: size == 0",    lst.size() == 0);
    check("clear: empty",       lst.empty());
    check("clear: first == 0",  lst.first() == 0);

    // reverse
    lst.push_back(1);
    lst.push_back(2);
    lst.push_back(3);
    lst.push_back(4);
    lst.reverse();
    check("reverse: get(0) == 4",   lst.get(0) == 4);
    check("reverse: get(1) == 3",   lst.get(1) == 3);
    check("reverse: get(2) == 2",   lst.get(2) == 2);
    check("reverse: get(3) == 1",   lst.get(3) == 1);
    check("reverse: first == 4",    lst.first() == 4);
    check("reverse: last == 1",     lst.last() == 1);

    // reverse of single-element list
    list<int64> single;
    single.push_back(42);
    single.reverse();
    check("reverse single: get(0) == 42", single.get(0) == 42);

    // reverse of empty list
    list<int64> empty;
    empty.reverse();
    check("reverse empty: size == 0", empty.size() == 0);
}

// =============================================================================
// 7. Conversion/combine/copy: to_array, copy, extend
// =============================================================================
void test_conversion() {
    section("Conversion/combine/copy — to_array, copy, extend");

    // to_array
    list<int64> lst;
    lst.push_back(11);
    lst.push_back(22);
    lst.push_back(33);

    array<int64> arr = lst.to_array();
    check("to_array: length == 3",  arr.length() == 3);
    check("to_array: get(0) == 11", arr.get(0) == 11);
    check("to_array: get(1) == 22", arr.get(1) == 22);
    check("to_array: get(2) == 33", arr.get(2) == 33);

    // to_array preserves order
    lst.reverse();
    array<int64> arr2 = lst.to_array();
    check("to_array after reverse: get(0) == 33", arr2.get(0) == 33);

    // copy — independent shallow copy
    lst.clear();
    lst.push_back(1);
    lst.push_back(2);
    lst.push_back(3);

    list<int64> cp = lst.copy();
    check("copy: size matches",  cp.size() == lst.size());
    check("copy: get(0) == 1",   cp.get(0) == 1);
    check("copy: get(1) == 2",   cp.get(1) == 2);
    check("copy: get(2) == 3",   cp.get(2) == 3);

    // Mutating copy does not affect original
    cp.push_back(99);
    check("copy mutate: original size unchanged (3)", lst.size() == 3);
    check("copy mutate: copy size == 4",              cp.size() == 4);

    // extend — append every element of other
    list<int64> a;
    a.push_back(1);
    a.push_back(2);

    list<int64> b;
    b.push_back(3);
    b.push_back(4);
    b.push_back(5);

    a.extend(b);
    check("extend: a.size() == 5", a.size() == 5);
    check("extend: a.get(0) == 1", a.get(0) == 1);
    check("extend: a.get(2) == 3", a.get(2) == 3);
    check("extend: a.get(4) == 5", a.get(4) == 5);

    // b unchanged after extend
    check("extend: b unchanged", b.size() == 3);
    check("extend: b.get(0) == 3", b.get(0) == 3);

    // extend onto empty list
    list<int64> empty_target;
    empty_target.extend(b);
    check("extend onto empty: size == 3", empty_target.size() == 3);
    check("extend onto empty: get(0) == 3", empty_target.get(0) == 3);
}

// =============================================================================
// 8. Iteration: kv-foreach (index + value) and value-only
// =============================================================================
void test_iteration() {
    section("Iteration — foreach kv (index + value)");

    list<int64> lst;
    lst.push_back(10);
    lst.push_back(20);
    lst.push_back(30);

    // Index + value
    int64 sum_idx = 0;
    int64 sum_val = 0;
    for (int64 i, int64 v : lst) {
        sum_idx = sum_idx + i;
        sum_val = sum_val + v;
    }
    check("foreach kv: sum of indices == 3",  sum_idx == 3);
    check("foreach kv: sum of values == 60",  sum_val == 60);

    // Value-only
    int64 sum_only = 0;
    for (int64 v : lst) {
        sum_only = sum_only + v;
    }
    check("foreach value-only: sum == 60",    sum_only == 60);

    // foreach on empty list
    list<int64> empty;
    int64 empty_count = 0;
    for (int64 i, int64 v : empty) {
        empty_count = empty_count + 1;
    }
    check("foreach empty: 0 iterations", empty_count == 0);
}

// =============================================================================
// 9. Class T storage — reference handle alias semantics
// =============================================================================
void test_class_storage() {
    section("Class T storage — reference handles");

    list<Entity> ents;
    ents.push_back(new Entity(1, 100, 0, 0));
    ents.push_back(new Entity(2,  85, 5, 5));
    ents.push_back(new Entity(3,  50, 10, 10));

    check("class list: size == 3",      ents.size() == 3);

    // Retrieve and check fields
    Entity first = ents.first();
    check("class list: first.id == 1",  first.id == 1);
    check("class list: first.hp == 100", first.hp == 100);

    Entity last = ents.last();
    check("class list: last.id == 3",   last.id == 3);
    check("class list: last.hp == 50",  last.hp == 50);

    // Chained access: lst.get(i).field
    check("chained: ents.get(0).hp == 100", ents.get(0).hp == 100);
    check("chained: ents.get(1).id == 2",   ents.get(1).id == 2);
    check("chained: ents.get(2).x == 10",   ents.get(2).x == 10);

    // Alias semantics — mutation via retrieved handle flows back into the list
    Entity mid = ents.get(1);
    mid.hp = 5;
    Entity mid2 = ents.get(1);
    check("alias: mutation flows back, mid2.hp == 5", mid2.hp == 5);

    // Class T subscript
    Entity subbed = ents[0];
    check("class subscript: ents[0].id == 1", subbed.id == 1);

    // Class T foreach
    section("Class T storage — foreach");

    int64 total_hp = 0;
    for (int64 ei, Entity e : ents) {
        total_hp = total_hp + e.hp;
    }
    // 100 (id=1) + 5 (id=2, mutated) + 50 (id=3) = 155
    check("class foreach: total_hp == 155", total_hp == 155);

    // Class T insert
    ents.insert(0, new Entity(0, 200, -1, -1));
    check("class insert(0): size == 4",         ents.size() == 4);
    check("class insert(0): get(0).id == 0",    ents.get(0).id == 0);
    check("class insert(0): get(1).id == 1",    ents.get(1).id == 1);

    // Class T remove
    Entity removed = ents.remove(0);
    check("class remove(0): returned.id == 0",   removed.id == 0);
    check("class remove(0): size == 3",          ents.size() == 3);
    check("class remove(0): new first.id == 1",  ents.first().id == 1);

    // Class T remove OOB returns default-constructed Entity
    Entity removed_oob = ents.remove(999);
    // NOTE: remove(idx) returns 0 if oob; for class T, this means a default handle
    check("class remove OOB: handle.tag == 0",
          removed_oob.id == 0 && removed_oob.hp == 0);
}

// =============================================================================
// 10. Class T auto-cleanup in class field
// =============================================================================
void test_auto_cleanup() {
    section("Class auto-cleanup — list<T> field in class");

    Squad* sq = new Squad("alpha");
    sq->members.push_back(new Entity(1, 100, 0, 0));
    sq->members.push_back(new Entity(2, 100, 1, 1));

    check("squad: members.size() == 2",  sq->members.size() == 2);
    check("squad: name == 'alpha'",     sq->name == "alpha");
    check("squad: members.get(0).id == 1", sq->members.get(0).id == 1);
    check("squad: members.get(1).hp == 100", sq->members.get(1).hp == 100);

    delete sq;   // members + each Entity inside freed (auto-cleanup)
    // After delete, the pointers are freed — we simply verify no crash here.
    // There is no portable way to verify the dtor ran without instrumenting,
    // but the fact we reached this check proves the delete didn't crash.
    check("squad: delete with auto-cleanup completes without crash", true);
}

// =============================================================================
// 11. Cross-container sharing — same heap instance in list + imap + map
// =============================================================================
void test_cross_container() {
    section("Cross-container sharing");

    list<Player>    plist;
    imap<Player>    pimap;
    map<string, Player> pmap;

    Player* p = new Player(1, 100);
    plist.push_back(p);
    pimap.set(1, p);
    pmap.set("alpha", p);

    // Verify all containers hold a handle to the same instance
    check("cross: list.first().id == 1",   plist.first().id == 1);
    check("cross: imap.get(1).id == 1",    pimap.get(1).id == 1);
    check("cross: map.get('alpha').id == 1", pmap.get("alpha").id == 1);

    // Mutate via one container — visible in all
    Player p_from_list = plist.first();
    p_from_list.hp = 50;

    int64 hp_from_imap = pimap.get(1).hp;
    int64 hp_from_map  = pmap.get("alpha").hp;
    int64 hp_from_list = plist.first().hp;

    check("cross: imap sees hp == 50",   hp_from_imap == 50);
    check("cross: map sees hp == 50",    hp_from_map == 50);
    check("cross: list sees hp == 50",   hp_from_list == 50);

    // Another mutation via map
    Player p_from_map = pmap.get("alpha");
    p_from_map.hp = 25;

    check("cross: after map mutation, list sees hp == 25",
          plist.first().hp == 25);
    check("cross: after map mutation, imap sees hp == 25",
          pimap.get(1).hp == 25);
}

// =============================================================================
// 12. list<T*> — pointer storage (user-managed pointers, no auto-free)
// =============================================================================
void test_pointer_storage() {
    section("list<T*> — pointer storage");

    list<Entity*> ptr_list;

    // push_back pointer
    Entity* e1 = new Entity(10, 500, 0, 0);
    Entity* e2 = new Entity(20, 600, 1, 1);
    ptr_list.push_back(e1);
    ptr_list.push_back(e2);

    check("list<T*>: size == 2", ptr_list.size() == 2);

    // get returns T* — verify id via deref
    Entity* got0 = ptr_list.get(0);
    check("list<T*>: get(0)->id == 10", got0->id == 10);
    check("list<T*>: get(0)->hp == 500", got0->hp == 500);

    // set
    Entity* e3 = new Entity(30, 700, 2, 2);
    ptr_list.set(0, e3);
    Entity* got_new0 = ptr_list.get(0);
    check("list<T*>: after set(0, e3), id == 30", got_new0->id == 30);

    // subscript
    Entity* sub = ptr_list[1];
    check("list<T*>: subscript [1]->id == 20", sub->id == 20);

    // first / last
    Entity* f = ptr_list.first();
    check("list<T*>: first()->id == 30", f->id == 30);

    Entity* l = ptr_list.last();
    check("list<T*>: last()->id == 20", l->id == 20);

    // contains with pointer comparison
    check("list<T*>: contains(e2) true",  ptr_list.contains(e2));
    check("list<T*>: contains(0) false", !ptr_list.contains(0));

    // remove
    Entity* removed_ptr = ptr_list.remove(0);
    check("list<T*>: remove(0) returns ptr", removed_ptr->id == 30);
    check("list<T*>: after remove, size == 1", ptr_list.size() == 1);

    // pop_back
    Entity* popped_ptr = ptr_list.pop_back();
    check("list<T*>: pop_back returns ptr", popped_ptr->id == 20);
    check("list<T*>: after pop_back, empty", ptr_list.empty());

    // pop_back on empty returns 0
    Entity* null_pop = ptr_list.pop_back();
    check("list<T*>: pop_back empty returns 0", null_pop == 0);

    // to_array works with pointers
    ptr_list.push_back(e1);
    ptr_list.push_back(e2);
    array<Entity*> ptr_arr = ptr_list.to_array();
    check("list<T*>: to_array length == 2", ptr_arr.length() == 2);
    check("list<T*>: to_array[0] == e1",    ptr_arr.get(0) == e1);

    // foreach works with pointers
    int64 ptr_count = 0;
    for (int64 pi, Entity* pe : ptr_list) {
        ptr_count = ptr_count + 1;
    }
    check("list<T*>: foreach counted 2", ptr_count == 2);

    // Clean up manually (list does not auto-free pointers)
    delete e1;
    delete e2;
    delete e3;
    // ptr_list elements e1, e2 were also present — e1 and e2 already freed
    // For the remaining list: we just clear it
    ptr_list.clear();
    check("list<T*>: clear on pointer list succeeds", true);
}

// =============================================================================
// 13. Edge cases and safety
// =============================================================================
void test_edge_cases() {
    section("Edge cases");

    // OOB access patterns
    list<int64> lst;
    lst.push_back(10);
    lst.push_back(20);

    check("get(-1) OOB returns 0",    lst.get(-1) == 0);
    check("get(99) OOB returns 0",    lst.get(99) == 0);
    check("at(-5) OOB returns 0",     lst.at(-5) == 0);

    // set OOB is no-op
    lst.set(-1, 999);
    check("set(-1, 999): size unchanged",  lst.size() == 2);
    check("set(-1, 999): first still 10",  lst.first() == 10);

    lst.set(99, 999);
    check("set(99, 999): size unchanged",  lst.size() == 2);
    check("set(99, 999): last still 20",   lst.last() == 20);

    // remove OOB returns 0
    check("remove(-1) OOB returns 0",      lst.remove(-1) == 0);
    check("remove(99) OOB returns 0",      lst.remove(99) == 0);

    // insert negative clamps to beginning
    lst.clear();
    lst.push_back(1);
    lst.push_back(2);
    lst.insert(-5, 0);
    check("insert(-5, 0): first == 0",     lst.first() == 0);

    // contains on empty list
    list<int64> empty;
    check("contains on empty: false",      !empty.contains(42));
    check("index_of on empty: -1",         empty.index_of(42) == -1);
    check("has on empty: false",          !empty.has(42));

    // Duplicate values
    list<int64> dups;
    dups.push_back(5);
    dups.push_back(5);
    dups.push_back(5);
    check("duplicates: size == 3",         dups.size() == 3);
    check("duplicates: index_of(5) == 0 (first)", dups.index_of(5) == 0);
    check("duplicates: contains(5) true",  dups.contains(5));

    // Single element operations
    list<int64> single;
    single.push_back(42);
    check("single: first == last",         single.first() == single.last());
    check("single: get(0) == 42",          single.get(0) == 42);

    single.push_front(0);
    check("single push_front: first == 0", single.first() == 0);
    check("single push_front: size == 2",  single.size() == 2);

    // Alternating push_front / push_back
    list<int64> alt;
    alt.push_back(2);
    alt.push_front(1);
    alt.push_back(3);
    check("alternating: get(0) == 1",      alt.get(0) == 1);
    check("alternating: get(1) == 2",      alt.get(1) == 2);
    check("alternating: get(2) == 3",      alt.get(2) == 3);
}

// =============================================================================
// 14. Volume / performance spot-check
// =============================================================================
void test_volume() {
    section("Volume — push_back x10000");

    list<int64> big;
    int64 i = 0;
    while (i < 10000) {
        big.push_back(i);
        i = i + 1;
    }
    check("volume: size == 10000",      big.size() == 10000);
    check("volume: first() == 0",       big.first() == 0);
    check("volume: last() == 9999",     big.last() == 9999);
    check("volume: get(0) == 0",        big.get(0) == 0);
    check("volume: get(5000) == 5000",  big.get(5000) == 5000);
    check("volume: get(9999) == 9999",  big.get(9999) == 9999);
    check("volume: contains(0) true",   big.contains(0));
    check("volume: contains(9999) true", big.contains(9999));
    check("volume: contains(-1) false", !big.contains(-1));

    // to_array on large list
    array<int64> big_arr = big.to_array();
    check("volume: to_array length == 10000", big_arr.length() == 10000);

    // reverse on large list
    big.reverse();
    check("volume: after reverse, get(0) == 9999",  big.get(0) == 9999);
    check("volume: after reverse, last() == 0",     big.last() == 0);

    // copy of large list
    list<int64> big_copy = big.copy();
    check("volume: copy size matches", big_copy.size() == big.size());
    check("volume: copy.get(0) == 9999", big_copy.get(0) == 9999);

    section("Volume — push_front x100 (O(n))");

    list<int64> front_big;
    int64 j = 0;
    while (j < 100) {
        front_big.push_front(j);
        j = j + 1;
    }
    // After 100 push_fronts: first = 99, last = 0
    check("front volume: size == 100",     front_big.size() == 100);
    check("front volume: first == 99",     front_big.first() == 99);
    check("front volume: last == 0",       front_big.last() == 0);

    // pop_front x50
    int64 k = 0;
    while (k < 50) {
        front_big.pop_front();
        k = k + 1;
    }
    check("front volume: after 50 pop_front, size == 50", front_big.size() == 50);
    check("front volume: first now == 49", front_big.first() == 49);

    // Volume class T
    section("Volume — class T x1000");

    list<Entity> roster;
    int64 n = 0;
    while (n < 1000) {
        roster.push_back(new Entity(n, 100, n, 0));
        n = n + 1;
    }
    check("class volume: size == 1000",       roster.size() == 1000);
    check("class volume: first.id == 0",      roster.first().id == 0);
    check("class volume: last.id == 999",     roster.last().id == 999);
    check("class volume: get(500).id == 500", roster.get(500).id == 500);

    int64 roster_total = 0;
    for (int64 ei, Entity e : roster) {
        roster_total = roster_total + e.hp;
    }
    check("class volume: foreach sum hp == 100000", roster_total == 100000);
}

// =============================================================================
// 15. Mixed-type patterns (int64, string, bool)
// =============================================================================
void test_mixed_types() {
    section("list<int64> — additional int64 operations");

    // Negative values
    list<int64> neg;
    neg.push_back(-5);
    neg.push_back(0);
    neg.push_back(5);
    check("negatives: size == 3",           neg.size() == 3);
    check("negatives: get(0) == -5",       neg.get(0) == -5);
    check("negatives: contains(-5) true",  neg.contains(-5));
    check("negatives: index_of(0) == 1",   neg.index_of(0) == 1);

    // Large values
    list<int64> large;
    large.push_back(0x7FFFFFFFFFFFFFFF);  // max int64
    large.push_back(-0x8000000000000000); // min int64
    check("large: first() == max_int64",
          large.first() == 0x7FFFFFFFFFFFFFFF);
    check("large: last() == min_int64",
          large.last() == -0x8000000000000000);

    // copy and extend on large ints
    list<int64> lcopy = large.copy();
    check("large copy: get(0) == max", lcopy.get(0) == 0x7FFFFFFFFFFFFFFF);
    check("large copy: get(1) == min", lcopy.get(1) == -0x8000000000000000);

    // copy of empty list
    list<int64> empty;
    list<int64> empty_copy = empty.copy();
    check("empty copy: size == 0", empty_copy.size() == 0);
    check("empty copy: empty",     empty_copy.empty());

    // extend empty
    list<int64> target;
    list<int64> source;
    source.push_back(10);
    source.push_back(20);
    target.extend(source);
    check("extend empty: size == 2",  target.size() == 2);
    check("extend empty: get(0) == 10", target.get(0) == 10);

    // extend self? Not documented but worth noting
}

// =============================================================================
// main — run everything
// =============================================================================

int32 main() {
    print_console("=== list.em: comprehensive List addon test ===");

    test_construction();
    test_add_remove();
    test_access();
    test_search();
    test_size();
    test_modify();
    test_conversion();
    test_iteration();
    test_class_storage();
    test_auto_cleanup();
    test_cross_container();
    test_pointer_storage();
    test_edge_cases();
    test_volume();
    test_mixed_types();

    // Summary
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
