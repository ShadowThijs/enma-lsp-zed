// =============================================================================
// arrays.em - comprehensive exercise of every Array addon method and function
// =============================================================================
//
// Checklist -- every method and standalone function from docs/Addons/Arrays.md:
//
// -- Core (18) ---------------------------------------------------------------
//   M push(v)             M pop()              M insert(i, v)
//   M remove(i)           M get(i)             M set(i, v)
//   M length()             M capacity()         M stride()
//   M resize(n)            M contains(v)        M index_of(v)
//   M sort()              M reverse()          M join(sep)
//   M clear()              M free()             M slice(start, end)
//
// -- Front/Back/Swap/Fill (6) ------------------------------------------------
//   M first()             M last()             M pop_front()
//   M push_front(x)       M swap(i, j)         M fill(x)
//
// -- Aggregates (9) ----------------------------------------------------------
//   M count(x)            M unique()           M sum()
//   M min()               M max()              M min_idx()
//   M max_idx()           M chunk(n)           M flat()
//
// -- Higher-order/Callback (6) -----------------------------------------------
//   M map(int64 fn)       M filter(int64 fn)   M reduce(int64 fn, T acc)
//   M any(int64 fn)       M all(int64 fn)      M find(int64 fn)
//
// -- Print helpers (6) -------------------------------------------------------
//   M print_int()         M println_int()      M print_float()
//   M println_float()     M print_str()        M println_str()
//
// -- Standalone functions (1) ------------------------------------------------
//   F array_create_strided(capacity, stride)
//
// Callback shapes:
//   int64 doubler(int64 x)         -- map
//   int64 is_even(int64 x)         -- filter, any, all, find
//   int64 add_fn(int64 acc, int64 x)  -- reduce
//
// Legend: M = method, F = free function
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

void section(string title) {
    print_console("");
    print_console("--- " + title + " ---");
}

void print_console(string input) {
    print(input);
}

// ===========================================================================
// Callback functions for higher-order methods
// ===========================================================================

int64 doubler(int64 x) {
    return x * 2;
}

int64 is_even(int64 x) {
    return (x % 2) == 0 ? 1 : 0;
}

int64 add_fn(int64 acc, int64 x) {
    return acc + x;
}

// ===========================================================================
// 1. Core: push / pop / length / capacity
// ===========================================================================

void test_push_pop_length_capacity() {
    section("1. push / pop / length / capacity");

    array<int64> a;
    check("new array length == 0", a.length() == 0);
    check("new array capacity >= 0", a.capacity() >= 0);

    a.push(10);
    a.push(20);
    a.push(30);
    a.push(40);
    check("length == 4 after 4 pushes", a.length() == 4);
    check("capacity >= 4 after pushes", a.capacity() >= 4);

    int64 v = a.pop();
    check("pop() returns 40", v == 40);
    check("length == 3 after pop", a.length() == 3);

    int64 v2 = a.pop();
    check("second pop() returns 30", v2 == 30);
    check("length == 2 after second pop", a.length() == 2);
}

// ===========================================================================
// 2. Core: get / set (including subscript syntax)
// ===========================================================================

void test_get_set() {
    section("2. get / set");

    array<int64> a;
    a.push(10);
    a.push(20);
    a.push(30);

    check("get(0) == 10", a.get(0) == 10);
    check("get(1) == 20", a.get(1) == 20);
    check("get(2) == 30", a.get(2) == 30);

    a.set(1, 99);
    check("get(1) == 99 after set(1, 99)", a.get(1) == 99);
    check("get(0) unchanged after set", a.get(0) == 10);
    check("get(2) unchanged after set", a.get(2) == 30);

    // Subscript syntax: arr[i] and arr[i] = v
    check("a[0] == 10 via subscript", a[0] == 10);
    check("a[1] == 99 via subscript", a[1] == 99);

    a[2] = 77;
    check("a[2] == 77 after subscript write", a.get(2) == 77);
}

// ===========================================================================
// 3. Core: insert / remove
// ===========================================================================

void test_insert_remove() {
    section("3. insert / remove");

    array<int64> a;
    a.push(1);
    a.push(2);
    a.push(4);

    a.insert(2, 3);
    check("length == 4 after insert(2, 3)", a.length() == 4);
    check("inserted element at 2 is 3", a.get(2) == 3);
    check("original shifted to 3 is 4", a.get(3) == 4);

    a.insert(0, 0);
    check("insert at front: length == 5", a.length() == 5);
    check("insert at front: get(0) == 0", a.get(0) == 0);

    int64 r = a.remove(0);
    check("remove(0) returns 0", r == 0);
    check("length == 4 after remove front", a.length() == 4);
    check("get(0) == 1 after front removal", a.get(0) == 1);

    int64 r2 = a.remove(2);
    check("remove(2) returns 3", r2 == 3);
    check("length == 3 after second remove", a.length() == 3);
}

// ===========================================================================
// 4. Core: stride (bytes per element, sign encodes signedness)
// ===========================================================================

void test_stride() {
    section("4. stride");

    // int64 -> signed 8-byte -> stride -8
    array<int64> i64a;
    i64a.push(42);
    check("int64[] stride == -8", i64a.stride() == -8);

    // uint32 -> unsigned 4-byte -> stride +4
    array<uint32> u32a;
    u32a.push(1);
    check("uint32[] stride == 4", u32a.stride() == 4);

    // float64 -> 8-byte float -> stride +8
    array<float64> f64a;
    f64a.push(3.14);
    check("float64[] stride == 8", f64a.stride() == 8);
}

// ===========================================================================
// 5. Core: resize / contains / index_of
// ===========================================================================

void test_resize_contains_index_of() {
    section("5. resize / contains / index_of");

    array<int64> a;
    a.push(10);
    a.push(20);
    a.push(30);

    // contains (returns int64: 1 if found, 0 if not)
    check("contains(10) == 1 (first)", a.contains(10) == 1);
    check("contains(20) == 1 (middle)", a.contains(20) == 1);
    check("contains(30) == 1 (last)", a.contains(30) == 1);
    check("contains(99) == 0 (absent)", a.contains(99) == 0);

    // index_of (returns int64, -1 if not found)
    check("index_of(10) == 0", a.index_of(10) == 0);
    check("index_of(20) == 1", a.index_of(20) == 1);
    check("index_of(30) == 2", a.index_of(30) == 2);
    check("index_of(99) == -1 (not found)", a.index_of(99) == -1);

    // resize larger
    a.resize(5);
    check("length == 5 after resize(5)", a.length() == 5);
    check("resized[3] defaults to 0", a.get(3) == 0);
    check("resized[4] defaults to 0", a.get(4) == 0);
    check("resize preserves existing get(0) == 10", a.get(0) == 10);
    check("resize preserves existing get(1) == 20", a.get(1) == 20);

    // resize smaller
    a.resize(2);
    check("length == 2 after shrink resize", a.length() == 2);
    check("get(0) still 10 after shrink", a.get(0) == 10);
    check("get(1) still 20 after shrink", a.get(1) == 20);
}

// ===========================================================================
// 6. Core: sort (ascending) / reverse (in-place)
// ===========================================================================

void test_sort_reverse() {
    section("6. sort / reverse");

    array<int64> a;
    a.push(3);
    a.push(1);
    a.push(4);
    a.push(1);
    a.push(5);

    a.sort();
    check("sorted[0] == 1", a.get(0) == 1);
    check("sorted[1] == 1", a.get(1) == 1);
    check("sorted[2] == 3", a.get(2) == 3);
    check("sorted[3] == 4", a.get(3) == 4);
    check("sorted[4] == 5", a.get(4) == 5);

    a.reverse();
    check("reversed[0] == 5", a.get(0) == 5);
    check("reversed[1] == 4", a.get(1) == 4);
    check("reversed[2] == 3", a.get(2) == 3);
    check("reversed[3] == 1", a.get(3) == 1);
    check("reversed[4] == 1", a.get(4) == 1);
}

// ===========================================================================
// 7. Core: join (elements to string with separator)
// ===========================================================================

void test_join() {
    section("7. join");

    // String array joining
    array<string> strs;
    strs.push("a");
    strs.push("b");
    strs.push("c");

    string joined = strs.join(", ");
    check("strings join(', ') == 'a, b, c'", joined == "a, b, c");

    string joined_dash = strs.join("-");
    check("strings join('-') == 'a-b-c'", joined_dash == "a-b-c");

    // Int array joining
    array<int64> ints;
    ints.push(1);
    ints.push(2);
    ints.push(3);

    string int_joined = ints.join("+");
    check("ints join('+') == '1+2+3'", int_joined == "1+2+3");

    // Single element
    array<string> single;
    single.push("only");
    check("single-element join == 'only'", single.join(",") == "only");
}

// ===========================================================================
// 8. Core: clear (remove all) / free (release memory)
// ===========================================================================

void test_clear_free() {
    section("8. clear / free");

    array<int64> a;
    a.push(1);
    a.push(2);
    a.push(3);

    a.clear();
    check("length == 0 after clear", a.length() == 0);

    // Array is reusable after clear
    a.push(42);
    check("can push after clear", a.get(0) == 42);
    check("length == 1 after push-after-clear", a.length() == 1);

    a.free();
    check("length == 0 after free", a.length() == 0);

    // Array is reusable after free (re-initializes)
    a.push(77);
    check("can push after free", a.get(0) == 77);
    check("length == 1 after push-after-free", a.length() == 1);
}

// ===========================================================================
// 9. Core: slice (sub-array from start to end index)
// ===========================================================================

void test_slice() {
    section("9. slice");

    array<int64> a;
    a.push(0);
    a.push(1);
    a.push(2);
    a.push(3);
    a.push(4);
    a.push(5);

    // Middle slice
    array<int64> sub = a.slice(2, 5);
    check("slice(2,5) length == 3", sub.length() == 3);
    check("slice(2,5)[0] == 2", sub.get(0) == 2);
    check("slice(2,5)[1] == 3", sub.get(1) == 3);
    check("slice(2,5)[2] == 4", sub.get(2) == 4);

    // Front slice
    array<int64> front = a.slice(0, 3);
    check("slice(0,3) length == 3", front.length() == 3);
    check("slice(0,3)[0] == 0", front.get(0) == 0);
    check("slice(0,3)[2] == 2", front.get(2) == 2);

    // Full slice
    array<int64> full = a.slice(0, 6);
    check("slice(0,6) covers whole array", full.length() == 6);
    check("slice(0,6)[0] == 0", full.get(0) == 0);
    check("slice(0,6)[5] == 5", full.get(5) == 5);

    // Original array unchanged
    check("original array length unchanged by slice", a.length() == 6);
}

// ===========================================================================
// 10. Front / back: first, last, pop_front, push_front
// ===========================================================================

void test_front_back() {
    section("10. first / last / pop_front / push_front");

    array<int64> a;
    a.push(10);
    a.push(20);
    a.push(30);

    check("first() == 10", a.first() == 10);
    check("last() == 30", a.last() == 30);

    int64 f = a.pop_front();
    check("pop_front() returns 10", f == 10);
    check("length == 2 after pop_front", a.length() == 2);
    check("first() == 20 after pop_front", a.first() == 20);

    a.push_front(5);
    check("length == 3 after push_front(5)", a.length() == 3);
    check("first() == 5 after push_front", a.first() == 5);
    check("last() still 30 after push_front", a.last() == 30);
}

// ===========================================================================
// 11. Swap / fill
// ===========================================================================

void test_swap_fill() {
    section("11. swap / fill");

    array<int64> a;
    a.push(1);
    a.push(2);
    a.push(3);
    a.push(4);

    a.swap(0, 3);
    check("swap(0,3): get(0) == 4", a.get(0) == 4);
    check("swap(0,3): get(3) == 1", a.get(3) == 1);

    a.swap(1, 2);
    check("swap(1,2): get(1) == 3", a.get(1) == 3);
    check("swap(1,2): get(2) == 2", a.get(2) == 2);

    // Overwrite all elements with fill
    a.fill(99);
    check("fill(99): get(0) == 99", a.get(0) == 99);
    check("fill(99): get(1) == 99", a.get(1) == 99);
    check("fill(99): get(2) == 99", a.get(2) == 99);
    check("fill(99): get(3) == 99", a.get(3) == 99);
    check("length unchanged after fill", a.length() == 4);
}

// ===========================================================================
// 12. Aggregates: count / unique
// ===========================================================================

void test_count_unique() {
    section("12. count / unique");

    array<int64> a;
    a.push(1);
    a.push(2);
    a.push(1);
    a.push(3);
    a.push(1);
    a.push(2);

    check("count(1) == 3 (three occurrences)", a.count(1) == 3);
    check("count(2) == 2 (two occurrences)", a.count(2) == 2);
    check("count(3) == 1 (one occurrence)", a.count(3) == 1);
    check("count(4) == 0 (absent)", a.count(4) == 0);

    // unique returns a NEW array; original unchanged
    array<int64> u = a.unique();
    check("unique() length == 3", u.length() == 3);
    check("unique[0] == 1 (first occurrence preserved)", u.get(0) == 1);
    check("unique[1] == 2 (first occurrence preserved)", u.get(1) == 2);
    check("unique[2] == 3 (first occurrence preserved)", u.get(2) == 3);

    // Original unchanged
    check("original array unchanged by unique()", a.length() == 6);
    check("original[0] still 1", a.get(0) == 1);
}

// ===========================================================================
// 13. Aggregates: sum / min / max / min_idx / max_idx
// ===========================================================================

void test_sum_min_max() {
    section("13. sum / min / max / min_idx / max_idx");

    array<int64> a;
    a.push(7);
    a.push(1);
    a.push(4);
    a.push(1);
    a.push(5);
    a.push(9);

    check("sum() == 27", a.sum() == 27);
    check("min() == 1", a.min() == 1);
    check("max() == 9", a.max() == 9);
    check("min_idx() == 1 (first occurrence of min)", a.min_idx() == 1);
    check("max_idx() == 5 (index of max)", a.max_idx() == 5);
}

// ===========================================================================
// 14. Aggregates: chunk (split into array of arrays) / flat (one-level flatten)
// ===========================================================================

void test_chunk_flat() {
    section("14. chunk / flat");

    array<int64> a;
    a.push(1);
    a.push(2);
    a.push(3);
    a.push(4);
    a.push(5);

    array<array<int64> > chunks = a.chunk(2);
    check("chunk(2) produces 3 sub-arrays", chunks.length() == 3);

    // Inspect first chunk
    array<int64> ch0 = chunks.get(0);
    check("chunk[0] length == 2", ch0.length() == 2);
    check("chunk[0][0] == 1", ch0.get(0) == 1);
    check("chunk[0][1] == 2", ch0.get(1) == 2);

    // Inspect second chunk
    array<int64> ch1 = chunks.get(1);
    check("chunk[1] length == 2", ch1.length() == 2);
    check("chunk[1][0] == 3", ch1.get(0) == 3);
    check("chunk[1][1] == 4", ch1.get(1) == 4);

    // Inspect last chunk (remainder)
    array<int64> ch2 = chunks.get(2);
    check("chunk[2] length == 1 (remainder)", ch2.length() == 1);
    check("chunk[2][0] == 5", ch2.get(0) == 5);

    // flat: one-level flatten of array-of-arrays
    array<int64> flat = chunks.flat();
    check("flat() length == 5", flat.length() == 5);
    check("flat[0] == 1", flat.get(0) == 1);
    check("flat[1] == 2", flat.get(1) == 2);
    check("flat[2] == 3", flat.get(2) == 3);
    check("flat[3] == 4", flat.get(3) == 4);
    check("flat[4] == 5", flat.get(4) == 5);

    // Original array unchanged
    check("original array unchanged by chunk/flat", a.length() == 5);
}

// ===========================================================================
// 15. Higher-order: map / filter / reduce / any / all / find
// ===========================================================================

void test_higher_order() {
    section("15. map / filter / reduce / any / all / find");

    // -- map: T(T) --
    array<int64> src;
    src.push(1);
    src.push(2);
    src.push(3);

    array<int64> mapped = src.map(cast<int64>(doubler));
    check("map(doubler) length == 3", mapped.length() == 3);
    check("map(doubler)[0] == 2", mapped.get(0) == 2);
    check("map(doubler)[1] == 4", mapped.get(1) == 4);
    check("map(doubler)[2] == 6", mapped.get(2) == 6);
    check("map leaves source unchanged", src.get(0) == 1);

    // -- filter: bool/int(T) --
    array<int64> b;
    b.push(1);
    b.push(2);
    b.push(3);
    b.push(4);
    b.push(5);

    array<int64> filtered = b.filter(cast<int64>(is_even));
    check("filter(is_even) length == 2", filtered.length() == 2);
    check("filter(is_even)[0] == 2", filtered.get(0) == 2);
    check("filter(is_even)[1] == 4", filtered.get(1) == 4);

    // -- reduce: T(T acc, T x) --
    int64 sum = src.reduce(cast<int64>(add_fn), 0);
    check("reduce(add_fn, 0) == 6", sum == 6);

    int64 sum_with_init = src.reduce(cast<int64>(add_fn), 100);
    check("reduce(add_fn, 100) == 106", sum_with_init == 106);

    // -- any: true if any element matches --
    array<int64> odds;
    odds.push(1);
    odds.push(3);
    odds.push(5);

    bool any_even = odds.any(cast<int64>(is_even));
    check("any(is_even) on [1,3,5] == false", !any_even);

    odds.push(4);
    any_even = odds.any(cast<int64>(is_even));
    check("any(is_even) after adding 4 == true", any_even);

    // -- all: true if all elements match --
    array<int64> evens;
    evens.push(2);
    evens.push(4);
    evens.push(6);

    bool all_even = evens.all(cast<int64>(is_even));
    check("all(is_even) on [2,4,6] == true", all_even);

    evens.push(7);
    all_even = evens.all(cast<int64>(is_even));
    check("all(is_even) after adding 7 == false", !all_even);

    // -- find: index of first predicate match, -1 if none --
    array<int64> no_match;
    no_match.push(1);
    no_match.push(3);
    no_match.push(5);

    int64 find_idx = no_match.find(cast<int64>(is_even));
    check("find(is_even) on all odds == -1", find_idx == -1);

    no_match.push(6);
    find_idx = no_match.find(cast<int64>(is_even));
    check("find(is_even) after adding 6 at index 3 == 3", find_idx == 3);
}

// ===========================================================================
// 16. Print helpers (reinterpret int64 slots as named type for output)
// ===========================================================================

void test_print_helpers() {
    section("16. print helpers (visual output - no assertions)");

    array<int64> ints;
    ints.push(10);
    ints.push(20);
    ints.push(30);
    ints.print_int();
    ints.println_int();

    array<float64> floats;
    floats.push(1.5);
    floats.push(2.5);
    floats.push(3.5);
    floats.print_float();
    floats.println_float();

    array<string> strs;
    strs.push("hello");
    strs.push("world");
    strs.print_str();
    strs.println_str();

    check("all print helpers executed without error", true);
}

// ===========================================================================
// 17. Standalone: array_create_strided(capacity, stride)
// ===========================================================================

void test_array_create_strided() {
    section("17. array_create_strided");

    // int64[] stride: signed 8-byte -> -8
    array<int64> i64_arr = array_create_strided(10, -8);
    check("strided int64 capacity >= 10", i64_arr.capacity() >= 10);
    check("strided int64 stride == -8", i64_arr.stride() == -8);
    i64_arr.push(42);
    check("strided int64 push/get works", i64_arr.get(0) == 42);

    // uint32[] stride: unsigned 4-byte -> +4
    array<uint32> u32_arr = array_create_strided(5, 4);
    check("strided uint32 capacity >= 5", u32_arr.capacity() >= 5);
    check("strided uint32 stride == 4", u32_arr.stride() == 4);
    u32_arr.push(100);
    check("strided uint32 push/get works", u32_arr.get(0) == 100);
}

// ===========================================================================
// Main - call all test functions and print summary
// ===========================================================================

int32 main() {
    print_console("=== Arrays addon comprehensive test ===");

    test_push_pop_length_capacity();
    test_get_set();
    test_insert_remove();
    test_stride();
    test_resize_contains_index_of();
    test_sort_reverse();
    test_join();
    test_clear_free();
    test_slice();
    test_front_back();
    test_swap_fill();
    test_count_unique();
    test_sum_min_max();
    test_chunk_flat();
    test_higher_order();
    test_print_helpers();
    test_array_create_strided();

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
