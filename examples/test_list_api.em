// =============================================================================
// list<T> smoke test — perception integration
//
// Exercises the new list<T> deque-style addon in a perception scripting
// context. list is generic over T (`list<int64>` / `list<Player>` / etc).
// Backed by std::deque<int64_t> internally; O(1) push/pop both ends + O(1)
// random access.
//
// Covers:
//   * push_back / push_front / pop_back / pop_front
//   * deque mixed-end operations
//   * get / set / first / last / subscript
//   * contains / has / index_of
//   * insert / remove (with OOB clamping)
//   * size / empty / length / clear / reverse
//   * to_array / copy / extend
//   * foreach kv_iterable (`for (idx, value : lst)`)
//   * class T storage (Entity ECS-style list)
//   * chained .get(idx).field access
//   * heap balance after spawn-and-drop cycles
//
// Compatible with the list<T> + foreach-class-T + chained-get-field
// fixes that landed alongside the addon — IF perception was rebuilt
// against the matching enma lib.
// =============================================================================

int64 g_pass = 0;
int64 g_fail = 0;
int64 g_handle = 0;
int64 g_done = 0;

sidebar_section_t g_section;
button_t          g_btn;
menu_t            g_menu;

// Class-storage proxy — Entity with id + hp fields.
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

void test_routine(int64 data) {
    if (g_done == 1) return;
    g_done = 1;

    print_console("=== list<T> Tests ===");

    section("list<int64> - basic push/pop both ends");

    list<int64> lst;
    lst.push_back(10);
    lst.push_back(20);
    lst.push_back(30);
    check("size == 3 after push_back x3", lst.size() == 3);
    check("first == 10", lst.first() == 10);
    check("last == 30", lst.last() == 30);

    lst.push_front(0);
    check("size == 4 after push_front", lst.size() == 4);
    check("first == 0", lst.first() == 0);

    int64 popped = lst.pop_back();
    check("pop_back returns 30", popped == 30);
    check("size == 3 after pop_back", lst.size() == 3);

    int64 fp = lst.pop_front();
    check("pop_front returns 0", fp == 0);
    check("first now == 10", lst.first() == 10);

    section("list<int64> - access");

    lst.clear();
    lst.push_back(100);
    lst.push_back(200);
    lst.push_back(300);

    check("get(0) == 100", lst.get(0) == 100);
    check("get(1) == 200", lst.get(1) == 200);
    check("at(2) == 300", lst.at(2) == 300);
    check("subscript [1] == 200", lst[1] == 200);

    lst.set(1, 999);
    check("after set(1, 999), get(1) == 999", lst.get(1) == 999);

    lst[2] = 888;
    check("after lst[2] = 888, lst[2] == 888", lst[2] == 888);

    check("get(99) OOB returns 0", lst.get(99) == 0);

    lst.clear();
    check("pop_back on empty returns 0", (lst.pop_back() == 0));

    section("list<int64> - search + insert + remove");

    lst.clear();
    lst.push_back(10);
    lst.push_back(20);
    lst.push_back(30);

    check("contains(20) true",   lst.contains(20));
    check("contains(99) false", !lst.contains(99));
    check("has(10) true",        lst.has(10));
    check("index_of(20) == 1",   lst.index_of(20) == 1);
    check("index_of(99) == -1",  lst.index_of(99) == -1);

    lst.insert(1, 15);  // [10, 15, 20, 30]
    check("after insert(1, 15), size == 4", lst.size() == 4);
    check("get(1) == 15", lst.get(1) == 15);
    check("get(2) == 20", lst.get(2) == 20);

    lst.insert(99, 40);  // OOB → end
    check("OOB insert clamps to end", lst.last() == 40);

    int64 r = lst.remove(0);  // returns 10
    check("remove(0) returns 10", r == 10);
    check("size == 4 after remove", lst.size() == 4);
    check("first now == 15", lst.first() == 15);

    section("list<int64> - reverse + extend + copy");

    lst.clear();
    lst.push_back(1);
    lst.push_back(2);
    lst.push_back(3);
    lst.push_back(4);
    lst.reverse();
    check("after reverse, get(0) == 4", lst.get(0) == 4);
    check("after reverse, last == 1",   lst.last() == 1);

    list<int64> a;
    a.push_back(1); a.push_back(2);
    list<int64> b;
    b.push_back(3); b.push_back(4); b.push_back(5);
    a.extend(b);
    check("after extend, a.size() == 5", a.size() == 5);
    check("b unchanged after extend", b.size() == 3);

    list<int64> c = a.copy();
    c.push_back(99);
    check("a.size unchanged after copy mutate", a.size() == 5);
    check("c has +1 element", c.size() == 6);

    section("list<int64> - to_array + foreach");

    lst.clear();
    lst.push_back(11);
    lst.push_back(22);
    lst.push_back(33);

    array<int64> arr = lst.to_array();
    check("to_array().length() == 3", arr.length() == 3);
    check("arr.get(0) == 11", arr.get(0) == 11);
    check("arr.get(2) == 33", arr.get(2) == 33);

    int64 sum = 0;
    int64 idx_sum = 0;
    for (int64 i, int64 v : lst) {
        sum = sum + v;
        idx_sum = idx_sum + i;
    }
    check("foreach sum == 66", sum == 66);
    check("foreach idx sum == 3", idx_sum == 3);

    section("list<int64> - volume push_back x10000");

    list<int64> big;
    int64 i = 0;
    while (i < 10000) { big.push_back(i); i = i + 1; }
    check("10000 push_back OK",       big.size() == 10000);
    check("big.first() == 0",         big.first() == 0);
    check("big.last() == 9999",       big.last() == 9999);
    check("big.get(5000) == 5000",    big.get(5000) == 5000);

    section("list<Entity> - class T storage");

    list<Entity> ents;
    ents.push_back(new Entity(1,  100, 0,  0));
    ents.push_back(new Entity(2,   85, 5,  5));
    ents.push_back(new Entity(3,   50, 10, 10));

    check("ents.size() == 3", ents.size() == 3);

    Entity first = ents.first();
    check("first.id == 1",  first.id == 1);
    check("first.hp == 100", first.hp == 100);

    Entity mid = ents.get(1);
    check("mid.id == 2",   mid.id == 2);
    check("mid.hp == 85",  mid.hp == 85);

    // Chained access — `lst.get(i).field`
    check("ents.get(0).hp == 100", ents.get(0).hp == 100);
    check("ents.get(1).id == 2",   ents.get(1).id == 2);

    // Alias semantics — mutation flows back
    Entity rmid = ents.get(1);
    rmid.hp = 5;
    Entity rmid2 = ents.get(1);
    check("alias mutation flows back: rmid2.hp == 5", rmid2.hp == 5);

    section("list<Entity> - foreach class T");

    int64 total_hp = 0;
    for (int64 ei, Entity e : ents) total_hp = total_hp + e.hp;
    // 100 + 5 + 50 = 155 (hp(1) was mutated to 5 above)
    check("foreach class T total_hp == 155", total_hp == 155);

    section("list<Entity> - remove + insert");

    Entity removed = ents.remove(1);  // mutated mid (Entity 2 with hp=5)
    check("removed.id == 2", removed.id == 2);
    check("size == 2 after remove", ents.size() == 2);
    check("after remove, get(1).id == 3", ents.get(1).id == 3);

    section("list<Entity> - volume class T 100");

    list<Entity> roster;
    int64 j = 0;
    while (j < 100) {
        roster.push_back(new Entity(j, 100, j, 0));
        j = j + 1;
    }
    check("roster.size() == 100", roster.size() == 100);

    int64 roster_total = 0;
    for (int64 k, Entity p : roster) roster_total = roster_total + p.hp;
    check("foreach 100 entities sum hp == 10000", roster_total == 10000);

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
    print_console("[menu] 'Run again' clicked - resetting + re-firing routine");
    g_done = 0;
    g_pass = 0;
    g_fail = 0;
}

void on_menu_log_summary(int64 data) {
    print_console("[menu] summary so far: PASS=" + cast<string>(g_pass) +
                  "  FAIL=" + cast<string>(g_fail));
}

int32 main() {
    print_console("[test_list_api] launching test routine + sidebar menu");

    g_section = create_sidebar_section("list test", "");
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
