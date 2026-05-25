// Comprehensive multi-inheritance test suite — runs through enma_cli.
// Tests layout correctness, method dispatch with this-adjustment, ctor/dtor
// chaining order, field conflict rejection (compile-time, separate file),
// heap stress with multi-base classes, and composition mixed with MI.

int64 g_fails;
int64 g_checks;

void check(bool ok, string label) {
    g_checks = g_checks + 1;
    if (!ok) {
        println("  FAIL: " + label);
        g_fails = g_fails + 1;
    }
}

void check_eq(int64 actual, int64 expected, string label) {
    g_checks = g_checks + 1;
    if (actual != expected) {
        println("  FAIL: " + label + " — got " + cast<string>(actual) +
                ", expected " + cast<string>(expected));
        g_fails = g_fails + 1;
    }
}

// ============================================================================
// Test 1: basic 2-base (class A + class B)
// ============================================================================

class T1_A {
    int64 a_field;
    T1_A() { a_field = 100; }
    int64 read_a() { return a_field; }
    int64 a_doubled() { return a_field * 2; }
}

class T1_B {
    int64 b_field;
    T1_B() { b_field = 200; }
    int64 read_b() { return b_field; }
}

class T1_C : T1_A, T1_B {
    int64 c_field;
    T1_C() { c_field = 300; }
    int64 sum_all() { return a_field + b_field + c_field; }
}

void test_basic_2base() {
    println("Test 1: basic 2-base class");
    T1_C* c = new T1_C();
    check_eq(c->a_field, 100, "ctor chain initialized A.a_field");
    check_eq(c->b_field, 200, "ctor chain initialized B.b_field");
    check_eq(c->c_field, 300, "C.c_field initialized");
    check_eq(c->read_a(), 100, "method from A");
    check_eq(c->read_b(), 200, "method from B (this-adjusted)");
    check_eq(c->a_doubled(), 200, "second method from A");
    check_eq(c->sum_all(), 600, "C's own method sees all fields");
    delete c;
}

// ============================================================================
// Test 2: 3-base
// ============================================================================

class T2_X {
    int64 x_v;
    T2_X() { x_v = 1; }
    int64 x() { return x_v; }
}
class T2_Y {
    int64 y_v;
    T2_Y() { y_v = 10; }
    int64 y() { return y_v; }
}
class T2_Z {
    int64 z_v;
    T2_Z() { z_v = 100; }
    int64 z() { return z_v; }
}
class T2_W : T2_X, T2_Y, T2_Z {
    int64 w_v;
    T2_W() { w_v = 1000; }
}

void test_3base() {
    println("Test 2: 3-base inheritance");
    T2_W* w = new T2_W();
    check_eq(w->x_v, 1,    "X ctor fired");
    check_eq(w->y_v, 10,   "Y ctor fired");
    check_eq(w->z_v, 100,  "Z ctor fired");
    check_eq(w->w_v, 1000, "W ctor fired");
    check_eq(w->x(), 1,    "X method via 3-base derived");
    check_eq(w->y(), 10,   "Y method (this-adjusted)");
    check_eq(w->z(), 100,  "Z method (this-adjusted further)");
    delete w;
}

// ============================================================================
// Test 3: ctor/dtor ordering observable via global
// ============================================================================

string g_ctor_log;
string g_dtor_log;

class T3_A {
    T3_A() { g_ctor_log = g_ctor_log + "A"; }
    ~T3_A() { g_dtor_log = g_dtor_log + "A"; }
}
class T3_B {
    T3_B() { g_ctor_log = g_ctor_log + "B"; }
    ~T3_B() { g_dtor_log = g_dtor_log + "B"; }
}
class T3_C : T3_A, T3_B {
    T3_C() { g_ctor_log = g_ctor_log + "C"; }
    ~T3_C() { g_dtor_log = g_dtor_log + "C"; }
}

void test_ctor_dtor_order() {
    println("Test 3: ctor/dtor order");
    g_ctor_log = "";
    g_dtor_log = "";
    T3_C* c = new T3_C();
    check(g_ctor_log == "ABC", "ctors fired in declaration order: ABC");
    delete c;
    check(g_dtor_log == "CBA", "dtors fired in reverse order: CBA");
}

// ============================================================================
// Test 4: 2-base struct (not class)
// ============================================================================

struct T4_P {
    int64 px;
    int64 py;
    T4_P() { px = 5; py = 6; }
    int64 sum_p() { return px + py; }
}
struct T4_Q {
    int64 qx;
    int64 qy;
    T4_Q() { qx = 7; qy = 8; }
    int64 sum_q() { return qx + qy; }
}
struct T4_R : T4_P, T4_Q {
    int64 rx;
    T4_R() { rx = 9; }
}

void test_struct_multi_base() {
    println("Test 4: 2-base struct");
    T4_R* r = new T4_R();
    check_eq(r->px, 5, "struct P.px initialized");
    check_eq(r->py, 6, "struct P.py initialized");
    check_eq(r->qx, 7, "struct Q.qx initialized");
    check_eq(r->qy, 8, "struct Q.qy initialized");
    check_eq(r->rx, 9, "struct R.rx initialized");
    check_eq(r->sum_p(), 11, "P's method on R");
    check_eq(r->sum_q(), 15, "Q's method on R (this-adjusted)");
    delete r;
}

// ============================================================================
// Test 5: methods on base call other methods on the same base
// ============================================================================

class T5_Base {
    int64 base_count;
    T5_Base() { base_count = 0; }
    void inc() { base_count = base_count + 1; }
    int64 get_count() { return base_count; }
}

class T5_Other {
    int64 other_count;
    T5_Other() { other_count = 0; }
    void inc_other() { other_count = other_count + 5; }
}

class T5_D : T5_Base, T5_Other {
    int64 d;
    T5_D() { d = 0; }
}

void test_inter_method_calls() {
    println("Test 5: methods that call other methods on same base");
    T5_D* d = new T5_D();
    d->inc();
    d->inc();
    d->inc();
    check_eq(d->get_count(), 3, "T5_Base.inc called 3 times via derived");
    d->inc_other();
    d->inc_other();
    check_eq(d->other_count, 10, "T5_Other.inc_other called 2 times via derived");
    delete d;
}

// ============================================================================
// Test 6: heap stress — 1000 new + delete cycles, no leaks expected
// ============================================================================

class T6_Inner {
    int64 a;
    int64 b;
    int64 c;
    T6_Inner() { a = 1; b = 2; c = 3; }
}
class T6_Other {
    int64 x;
    int64 y;
    T6_Other() { x = 10; y = 20; }
}
class T6_Multi : T6_Inner, T6_Other {
    int64 own;
    T6_Multi() { own = 99; }
    int64 sum() { return a + b + c + x + y + own; }
}

void test_heap_stress() {
    println("Test 6: 1000-cycle heap stress with multi-base");
    int64 i = 0;
    int64 mismatches = 0;
    while (i < 1000) {
        T6_Multi* m = new T6_Multi();
        if (m->sum() != 135) { mismatches = mismatches + 1; }
        delete m;
        i = i + 1;
    }
    check_eq(mismatches, 0, "1000 cycles, no sum mismatches");
}

// ============================================================================
// Test 7: composition — class containing another class as a heap field
// ============================================================================

class T7_Inner {
    int64 v;
    T7_Inner() { v = 42; }
    int64 get() { return v; }
}

class T7_BaseA {
    int64 a;
    T7_BaseA() { a = 11; }
}
class T7_BaseB {
    int64 b;
    T7_BaseB() { b = 22; }
}
class T7_Outer : T7_BaseA, T7_BaseB {
    T7_Inner* inner;
    T7_Outer() {
        inner = new T7_Inner();
    }
    ~T7_Outer() {
        delete inner;
    }
}

void test_composition_with_mi() {
    println("Test 7: composition (heap-allocated member) inside multi-base class");
    T7_Outer* o = new T7_Outer();
    check_eq(o->a, 11, "BaseA inherited field");
    check_eq(o->b, 22, "BaseB inherited field");
    check_eq(o->inner->v, 42, "composed inner field");
    check_eq(o->inner->get(), 42, "composed inner method");
    delete o;
}

// ============================================================================
// Test 8: many small classes — verify large multi-base doesn't break codegen
// ============================================================================

class T8_F1 { int64 f1; T8_F1() { f1 = 1; } }
class T8_F2 { int64 f2; T8_F2() { f2 = 2; } }
class T8_F3 { int64 f3; T8_F3() { f3 = 3; } }
class T8_F4 { int64 f4; T8_F4() { f4 = 4; } }
class T8_F5 { int64 f5; T8_F5() { f5 = 5; } }
class T8_All : T8_F1, T8_F2, T8_F3, T8_F4, T8_F5 {
    int64 own;
    T8_All() { own = 100; }
}

void test_many_bases() {
    println("Test 8: 5 bases combined");
    T8_All* all = new T8_All();
    check_eq(all->f1, 1, "5-base: f1");
    check_eq(all->f2, 2, "5-base: f2");
    check_eq(all->f3, 3, "5-base: f3");
    check_eq(all->f4, 4, "5-base: f4");
    check_eq(all->f5, 5, "5-base: f5");
    check_eq(all->own, 100, "5-base: own");
    delete all;
}

// ============================================================================
// Test 9: chained method calls return correct values
// ============================================================================

class T9_Counter {
    int64 c;
    T9_Counter() { c = 0; }
    int64 incr_get() {
        c = c + 1;
        return c;
    }
}
class T9_Adder {
    int64 sum;
    T9_Adder() { sum = 0; }
    int64 add_and_get(int64 v) {
        sum = sum + v;
        return sum;
    }
}
class T9_Combo : T9_Counter, T9_Adder {
    T9_Combo() { }
    int64 combined(int64 v) {
        int64 a = incr_get();   // T9_Counter method
        int64 b = add_and_get(v); // T9_Adder method
        return a * 1000 + b;
    }
}

void test_method_chaining() {
    println("Test 9: chained method calls across bases");
    T9_Combo* combo = new T9_Combo();
    check_eq(combo->combined(5),  1005,  "1st combined: 1*1000 + 5");
    check_eq(combo->combined(10), 2015,  "2nd combined: 2*1000 + 15");
    check_eq(combo->combined(20), 3035,  "3rd combined: 3*1000 + 35");
    check_eq(combo->c, 3, "counter incremented 3 times");
    check_eq(combo->sum, 35, "adder accumulated 35");
    delete combo;
}

// ============================================================================
// Test 10: derived's own ctor uses inherited fields after base ctor chain
// ============================================================================

class T10_Width { int64 w; T10_Width() { w = 4; } }
class T10_Height { int64 h; T10_Height() { h = 5; } }
class T10_Box : T10_Width, T10_Height {
    int64 area;
    T10_Box() {
        // bases already constructed by chain — w and h are 4 and 5.
        area = w * h;
    }
}

void test_derived_uses_base_fields_in_own_ctor() {
    println("Test 10: derived ctor reads inherited fields");
    T10_Box* b = new T10_Box();
    check_eq(b->area, 20, "area = w * h, computed in derived ctor");
    delete b;
}

// ============================================================================
// Test 11: inheritance through a multi-base class — D : C where C : A, B
// ============================================================================

class T11_Aa { int64 aa; T11_Aa() { aa = 7; } int64 read_aa() { return aa; } }
class T11_Bb { int64 bb; T11_Bb() { bb = 17; } int64 read_bb() { return bb; } }
class T11_Cc : T11_Aa, T11_Bb {
    int64 cc;
    T11_Cc() { cc = 70; }
}
class T11_Dd : T11_Cc {
    int64 dd;
    T11_Dd() { dd = 700; }
}

void test_inheritance_through_mi() {
    println("Test 11: D : C where C : A, B");
    T11_Dd* d = new T11_Dd();
    check_eq(d->aa, 7,   "transitive: A.aa via D");
    check_eq(d->bb, 17,  "transitive: B.bb via D (non-primary path)");
    check_eq(d->cc, 70,  "transitive: C.cc via D");
    check_eq(d->dd, 700, "D.dd own field");
    check_eq(d->read_aa(), 7,  "transitive: A method via D");
    check_eq(d->read_bb(), 17, "transitive: B method via D (this-adjusted)");
    delete d;
}

// ============================================================================
// Test 12: base mutator method, derived observes field change
// ============================================================================

class T12_Health {
    int64 hp;
    T12_Health() { hp = 100; }
    void take_damage(int64 d) { hp = hp - d; }
}
class T12_Mana {
    int64 mp;
    T12_Mana() { mp = 50; }
    void spend(int64 cost) { mp = mp - cost; }
}
class T12_Player : T12_Health, T12_Mana {
    int64 xp;
    T12_Player() { xp = 0; }
}

void test_base_mutator() {
    println("Test 12: base mutators visible on derived");
    T12_Player* p = new T12_Player();
    p->take_damage(30);
    p->take_damage(10);
    p->spend(15);
    p->spend(5);
    check_eq(p->hp, 60, "T12_Health.hp after 2 take_damage");
    check_eq(p->mp, 30, "T12_Mana.mp after 2 spend (this-adjusted writes)");
    delete p;
}

// ============================================================================
// Test 13: delete[] on contiguous array of multi-base class
// ============================================================================

class T13_X { int64 x; T13_X() { x = 1; } }
class T13_Y { int64 y; T13_Y() { y = 2; } }
class T13_Z : T13_X, T13_Y {
    int64 z;
    T13_Z() { z = 3; }
    int64 sum() { return x + y + z; }
}

void test_array_of_mi() {
    println("Test 13: new T[N] / delete[] for multi-base T");
    T13_Z* arr = new T13_Z[16];
    int64 i = 0;
    int64 mismatches = 0;
    while (i < 16) {
        if (arr[i].sum() != 6) { mismatches = mismatches + 1; }
        i = i + 1;
    }
    check_eq(mismatches, 0, "all 16 elements have ctor-initialized fields");
    delete[] arr;
}

// ============================================================================
// Test 14: try/catch + defer inside method on non-primary base
// ============================================================================

int64 g_t14_defer;

class T14_Catcher {
    int64 caught;
    T14_Catcher() { caught = 0; }
    void try_thing(int64 mode) {
        defer { g_t14_defer = g_t14_defer + 1; }
        try {
            if (mode == 1) {
                int64 v = 42;
                throw v;
            }
        } catch (int64 e) {
            caught = caught + 1;
        }
    }
}
class T14_Other { int64 other; T14_Other() { other = 0; } }
class T14_Combo : T14_Other, T14_Catcher {
    T14_Combo() { }
}

void test_try_catch_in_mi() {
    println("Test 14: try/catch + defer inside method on non-primary base");
    g_t14_defer = 0;
    T14_Combo* c = new T14_Combo();
    c->try_thing(0);   // no throw, defer fires
    c->try_thing(1);   // throws, caught, defer fires
    c->try_thing(0);   // no throw
    c->try_thing(1);   // throws, caught, defer fires
    check_eq(c->caught, 2, "caught count after 2 throws");
    check_eq(g_t14_defer, 4, "defer fired all 4 calls");
    delete c;
}

// ============================================================================
// Test 15: many fields per base (large layout stress)
// ============================================================================

class T15_Big1 {
    int64 a; int64 b; int64 c; int64 d; int64 e;
    T15_Big1() { a = 1; b = 2; c = 3; d = 4; e = 5; }
    int64 sum1() { return a + b + c + d + e; }
}
class T15_Big2 {
    int64 f; int64 g; int64 h; int64 i; int64 j;
    T15_Big2() { f = 10; g = 20; h = 30; i = 40; j = 50; }
    int64 sum2() { return f + g + h + i + j; }
}
class T15_BigD : T15_Big1, T15_Big2 {
    int64 k;
    T15_BigD() { k = 1000; }
}

void test_large_fields_per_base() {
    println("Test 15: 5 fields per base, 2 bases");
    T15_BigD* d = new T15_BigD();
    check_eq(d->a, 1,    "Big1.a");
    check_eq(d->j, 50,   "Big2.j (later in non-primary base)");
    check_eq(d->k, 1000, "Own k");
    check_eq(d->sum1(), 15,  "Big1.sum1 via derived");
    check_eq(d->sum2(), 150, "Big2.sum2 via derived (this-adjusted)");
    delete d;
}

// ============================================================================
// Test 16: upcast — `B* b = c` shifts pointer, fields/methods through b work
// ============================================================================

class T16_Aa { int64 av; T16_Aa() { av = 1; } }
class T16_Bb { int64 bv; T16_Bb() { bv = 2; } int64 get_bv() { return bv; } }
class T16_Cc : T16_Aa, T16_Bb { T16_Cc() { } }

void test_upcast() {
    println("Test 16: upcast (B* b = c) shifts pointer to non-primary base");
    T16_Cc* c = new T16_Cc();
    T16_Bb* b = c;
    int64 v1 = b->bv;
    check_eq(v1, 2, "b.bv after upcast (field via B*)");
    int64 v2 = b->get_bv();
    check_eq(v2, 2, "b.get_bv() after upcast (virtual dispatch via B*)");
    delete c;
}

// ============================================================================
// Test 17: dtor fires for class with simple ctor/dtor pair
// ============================================================================

int64 g_t17_drops;

class T17_Holder {
    int64 sentinel;
    T17_Holder() { sentinel = 99; }
    ~T17_Holder() { g_t17_drops = g_t17_drops + 100; }
}

void test_basic_class_dtor() {
    println("Test 17: basic class dtor fires on delete");
    g_t17_drops = 0;
    T17_Holder* h = new T17_Holder();
    delete h;
    check_eq(g_t17_drops, 100, "T17_Holder dtor fired (sentinel +100)");
}

// ============================================================================
// Test 18: dtor fires for HEAP class field (composition with new in ctor)
// ============================================================================

int64 g_t18_drops;

class T18_Heaped {
    int64 v;
    T18_Heaped() { v = 7; }
    ~T18_Heaped() { g_t18_drops = g_t18_drops + 1; }
}

class T18_Owner {
    T18_Heaped* heap;
    T18_Owner() { heap = new T18_Heaped(); }
    ~T18_Owner() { delete heap; }
}

void test_dtor_chain_through_ownership() {
    println("Test 18: owner's dtor deletes its heap field");
    g_t18_drops = 0;
    T18_Owner* o = new T18_Owner();
    delete o;
    check_eq(g_t18_drops, 1, "Owner.~Owner deleted heap field, T18_Heaped dtor fired");
}

// ============================================================================
// Test 19: dtor for class containing a heap array (manually managed)
// ============================================================================

int64 g_t19_drops;

class T19_Item {
    int64 id;
    T19_Item() { id = 0; }
    ~T19_Item() { g_t19_drops = g_t19_drops + 1; }
}

class T19_Container {
    T19_Item* items;
    int64 n;
    T19_Container() {
        n = 8;
        items = new T19_Item[n];
    }
    ~T19_Container() {
        delete[] items;
    }
}

void test_dtor_on_class_with_array() {
    println("Test 19: class owning new T[N] array invokes element dtors");
    g_t19_drops = 0;
    T19_Container* c = new T19_Container();
    delete c;
    check_eq(g_t19_drops, 8, "8 element dtors fired via container's delete[]");
}

// ============================================================================
// Test 20: struct with class field + dtor chain
// ============================================================================

int64 g_t20_drops;

class T20_Resource {
    int64 fd;
    T20_Resource() { fd = 1234; }
    ~T20_Resource() { g_t20_drops = g_t20_drops + 1; }
}

struct T20_Wrapper {
    T20_Resource* r;
    int64 user_id;
    T20_Wrapper() { r = new T20_Resource(); user_id = 42; }
    ~T20_Wrapper() { delete r; g_t20_drops = g_t20_drops + 100; }
}

void test_struct_with_class_dtor() {
    println("Test 20: struct with class field — dtor releases the class");
    g_t20_drops = 0;
    T20_Wrapper* w = new T20_Wrapper();
    delete w;
    check_eq(g_t20_drops, 101, "T20_Wrapper dtor + T20_Resource dtor both fired");
}

// ============================================================================
// Test 21: nested class-in-class-in-class composition + dtor cascade
// ============================================================================

int64 g_t21_drops;

class T21_L3 {
    int64 v;
    T21_L3() { v = 3; }
    ~T21_L3() { g_t21_drops = g_t21_drops + 1; }
}
class T21_L2 {
    T21_L3* l3;
    T21_L2() { l3 = new T21_L3(); }
    ~T21_L2() { delete l3; g_t21_drops = g_t21_drops + 10; }
}
class T21_L1 {
    T21_L2* l2;
    T21_L1() { l2 = new T21_L2(); }
    ~T21_L1() { delete l2; g_t21_drops = g_t21_drops + 100; }
}

void test_three_level_composition() {
    println("Test 21: 3-level nested class composition with cascading dtors");
    g_t21_drops = 0;
    T21_L1* l1 = new T21_L1();
    delete l1;
    check_eq(g_t21_drops, 111, "L1 (100) + L2 (10) + L3 (1) = 111");
}

// ============================================================================
// Test 22: dtor + ctor count match in heap stress (no leaks)
// ============================================================================

int64 g_t22_ctors;
int64 g_t22_dtors;

class T22_Leakprobe {
    int64 v;
    T22_Leakprobe() { g_t22_ctors = g_t22_ctors + 1; v = 0; }
    ~T22_Leakprobe() { g_t22_dtors = g_t22_dtors + 1; }
}

void test_leak_balance_stress() {
    println("Test 22: ctor/dtor balance across 5000 alloc/free cycles");
    g_t22_ctors = 0;
    g_t22_dtors = 0;
    int64 i = 0;
    while (i < 5000) {
        T22_Leakprobe* p = new T22_Leakprobe();
        delete p;
        i = i + 1;
    }
    check_eq(g_t22_ctors, 5000, "5000 ctors fired");
    check_eq(g_t22_dtors, 5000, "5000 dtors fired (no leaks)");
}

// ============================================================================
// Test 23: dtor chain in multi-base class with composed member
// ============================================================================

string g_t23_seq;

class T23_BaseX {
    T23_BaseX() { }
    ~T23_BaseX() { g_t23_seq = g_t23_seq + "X"; }
}
class T23_BaseY {
    T23_BaseY() { }
    ~T23_BaseY() { g_t23_seq = g_t23_seq + "Y"; }
}
class T23_Member {
    T23_Member() { }
    ~T23_Member() { g_t23_seq = g_t23_seq + "M"; }
}
class T23_Derived : T23_BaseX, T23_BaseY {
    T23_Member* m;
    T23_Derived() { m = new T23_Member(); }
    ~T23_Derived() { delete m; g_t23_seq = g_t23_seq + "D"; }
}

void test_mi_dtor_with_composition() {
    println("Test 23: multi-base class with composed member: dtor sequence");
    g_t23_seq = "";
    T23_Derived* d = new T23_Derived();
    delete d;
    // ~Derived body runs first: delete m → "M", then sentinel "D"
    // Then base dtors fire in REVERSE base-decl order: Y, then X.
    check(g_t23_seq == "MDYX", "dtor seq: 'MDYX' (member, derived sentinel, then bases reversed) — got '" + g_t23_seq + "'");
}

// ============================================================================
// Test 24: override dispatch through non-primary base ptr (thunks)
// ============================================================================

class T24_A {
    int64 av;
    T24_A() { av = 1; }
    int64 sig() { return 10; }
}
class T24_B {
    int64 bv;
    T24_B() { bv = 2; }
    int64 sig() { return 20; }
    int64 take(int64 v) { return v + bv; }   // for forwarded-arg thunk test
}
class T24_C : T24_A, T24_B {
    T24_C() { }
    override int64 sig() { return 999; }
    override int64 take(int64 v) { return v + 1000; }
}

void test_override_via_secondary_base() {
    println("Test 24: override dispatch through non-primary base ptr");
    T24_C* c = new T24_C();
    check_eq(c->sig(),  999, "direct: c.sig() returns override");

    T24_A* a = c;
    check_eq(a->sig(),  999, "via TA* (primary base): override fires");

    T24_B* b = c;
    check_eq(b->sig(),  999, "via TB* (non-primary base): thunk dispatches to override");
    check_eq(b->take(5), 1005, "via TB*: thunk forwards arg to override");

    delete c;
}

// ============================================================================
// Test 25: upcast in all conversion contexts (var_decl, fn arg, assignment, return)
// ============================================================================

class T25_A { int64 av; T25_A() { av = 11; } int64 ra() { return av; } }
class T25_B { int64 bv; T25_B() { bv = 22; } int64 rb() { return bv; } }
class T25_D : T25_A, T25_B { T25_D() { } }

int64 g_t25_observed;

void t25_take_b(T25_B* b) {
    g_t25_observed = b->rb();
}

T25_B* t25_make_b(T25_D* d) {
    return d;
}

void test_upcast_in_all_contexts() {
    println("Test 25: upcast in var_decl, fn arg, assignment, return");
    T25_D* d = new T25_D();

    // var-decl upcast
    T25_B* b1 = d;
    check_eq(b1->rb(), 22, "var_decl: T25_B* = T25_D* shifts to B subobject");

    // fn-arg upcast
    g_t25_observed = 0;
    t25_take_b(d);
    check_eq(g_t25_observed, 22, "fn_arg: passing T25_D* to T25_B* param shifts");

    // assignment upcast (after initial var_decl)
    T25_D* d2 = new T25_D();
    b1 = d2;
    check_eq(b1->rb(), 22, "assignment: re-assign T25_D* to T25_B* var shifts");

    // return upcast
    T25_B* rb = t25_make_b(d);
    check_eq(rb->rb(), 22, "return: T25_B* fn returning T25_D* shifts");

    delete d;
    delete d2;
}

// ============================================================================
// main
// ============================================================================

int64 main() {
    g_fails = 0;
    g_checks = 0;

    println("=== multi-inheritance test suite ===");
    println("");

    test_basic_2base();
    test_3base();
    test_ctor_dtor_order();
    test_struct_multi_base();
    test_inter_method_calls();
    test_heap_stress();
    test_composition_with_mi();
    test_many_bases();
    test_method_chaining();
    test_derived_uses_base_fields_in_own_ctor();
    test_inheritance_through_mi();
    test_base_mutator();
    test_array_of_mi();
    test_try_catch_in_mi();
    test_large_fields_per_base();
    test_upcast();
    test_basic_class_dtor();
    test_dtor_chain_through_ownership();
    test_dtor_on_class_with_array();
    test_struct_with_class_dtor();
    test_three_level_composition();
    test_leak_balance_stress();
    test_mi_dtor_with_composition();
    test_override_via_secondary_base();
    test_upcast_in_all_contexts();

    println("");
    println("checks run: " + cast<string>(g_checks));
    if (g_fails == 0) {
        println("ALL PASS");
        return 0;
    }
    println("FAILED: " + cast<string>(g_fails));
    return g_fails;
}
