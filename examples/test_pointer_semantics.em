// =============================================================================
// Pointer semantics smoke test — *pt deref + move(x) intrinsic
//
// Validates the C++-class-semantics phases that landed 2026-05-04:
//   Phase 1 — `*pt` does shallow field-by-field copy of the pointee.
//             Returns a fresh independent heap T. Mutating the copy
//             doesn't affect *pt and vice-versa.
//   Phase 4 — `move(x)` transfers ownership: returns x's value AND
//             nullifies the source slot. Subsequent `x->field` faults
//             on null deref.
// =============================================================================

class Point {
    float64 x;
    float64 y;
    int64   tag;
    Point() { x = 0.0; y = 0.0; tag = 0; }
    Point(float64 x_, float64 y_, int64 tag_) { x = x_; y = y_; tag = tag_; }
}

struct Inner { int64 a; int64 b; }
class Mixed {
    int64   i;
    float64 f;
    Inner   inner;
    Mixed() { i = 0; f = 0.0; }
}

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

void section(string title) {
    print_console("");
    print_console("--- " + title + " ---");
}

void test_routine(int64 data) {
    if (g_done != 0) return;
    g_done = 1;

    print_console("=== pointer semantics smoke test ===");

    // =======================================================================
    // *pt deref — shallow field-by-field copy
    // =======================================================================
    section("*pt deref - basic + independence");

    Point* a = new Point(1.0, 2.0, 100);
    Point  b = *a;                   // independent copy
    check("b.x == 1.0 (post-deref)", b.x == 1.0);
    check("b.y == 2.0 (post-deref)", b.y == 2.0);
    check("b.tag == 100 (post-deref)", b.tag == 100);

    // Mutate b. Must NOT affect *a.
    b.x = 99.0; b.tag = 555;
    check("after b.x = 99: a->x still 1.0", a->x == 1.0);
    check("after b.tag = 555: a->tag still 100", a->tag == 100);

    // Mutate a. Must NOT affect b.
    a->x = 7.7; a->tag = 888;
    check("after a->x = 7.7: b.x still 99", b.x == 99.0);
    check("after a->tag = 888: b.tag still 555", b.tag == 555);

    // -----------------------------------------------------------------------
    // *pt with nested struct field — recurses into Inner
    // -----------------------------------------------------------------------
    section("*pt deref - nested struct field");

    Mixed* m = new Mixed();
    m->i = 42; m->f = 3.14;
    m->inner.a = 100; m->inner.b = 200;

    Mixed mc = *m;
    check("mc.i == 42",         mc.i == 42);
    check("mc.f == 3.14",       mc.f == 3.14);
    check("mc.inner.a == 100",  mc.inner.a == 100);
    check("mc.inner.b == 200",  mc.inner.b == 200);  // requires nested-struct recursion

    mc.i = -1; mc.inner.a = -3; mc.inner.b = -4;
    check("after mc.i = -1: m->i still 42", m->i == 42);
    check("after mc.inner.a = -3: m->inner.a still 100", m->inner.a == 100);
    check("after mc.inner.b = -4: m->inner.b still 200", m->inner.b == 200);

    // =======================================================================
    // move(x) — ownership transfer + source nullification
    // =======================================================================
    section("move(x) - basic ownership transfer");

    Point* p = new Point(10.0, 20.0, 700);
    Point* q = move(p);
    check("after move: q->x == 10.0", q->x == 10.0);
    check("after move: q->tag == 700", q->tag == 700);
    check("after move: p is null (cast<int64>(p) == 0)", cast<int64>(p) == 0);

    // Mutating q mutates the original heap (q owns it).
    q->x = 99.0;
    check("q->x = 99 took effect", q->x == 99.0);

    // -----------------------------------------------------------------------
    // move chain
    // -----------------------------------------------------------------------
    section("move(x) - chain transfer");

    Point* r = move(q);
    check("after move(q) -> r: r->x == 99", r->x == 99.0);
    check("after move(q) -> r: q is null", cast<int64>(q) == 0);

    // -----------------------------------------------------------------------
    // *pt vs move() distinction
    // -----------------------------------------------------------------------
    section("*pt copy vs move() — distinct semantics");

    Point* d = new Point(50.0, 60.0, 500);
    Point  copy_d = *d;             // independent copy
    Point* moved = move(d);         // ownership transfer

    check("copy_d.x == 50 (independent)", copy_d.x == 50.0);
    check("moved->x == 50 (handle inherited)", moved->x == 50.0);
    check("d is null after move", cast<int64>(d) == 0);

    // Mutate moved (which owns the heap). copy_d stays independent.
    moved->x = 7777.0;
    check("after moved->x = 7777: copy_d.x still 50", copy_d.x == 50.0);
    check("after moved->x = 7777: moved->x == 7777", moved->x == 7777.0);

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
    print_console("[test_pointer_semantics] launching test routine + sidebar menu");

    g_section = create_sidebar_section("ptr semantics", "");
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
