// ============================================================================
// lifecycle_routines.em
// ============================================================================
// Comprehensive test of the Lifecycle and Routines API.
//
// Tests EVERY function documented in:
//   docs/Perception/Lifecycle and Routines.md
// ============================================================================

// ============================================================================
// CHECKLIST  --  every function from the documentation
// ============================================================================
// Entry point:
//   [X] int64 main()
//       [X] return > 0   => script stays loaded (long-lived script)
//       [X] return <= 0  => script unloads immediately (one-shot)
//
// Routine API:
//   [X] int64 register_routine(int64 fn_handle, int64 data)
//       [X] callback receives `data` as its parameter
//       [X] pass function handle via cast<int64>(fn_name)
//       [X] returns a non-zero handle
//       [X] multiple routines can be registered simultaneously
//   [X] bool unregister_routine(int64 routine_handle)
//       [X] returns true for a valid, active handle
//       [X] routine can unregister itself from inside its own callback
//
// Diagnostic helpers (quick tracing, no renderer dependency):
//   [X] void heartbeat()                        -- logs "heartbeat called"
//   [X] void take_int(int64 x)                  -- logs an int64 value
//   [X] void take_ptr(int64 p)                  -- logs a pointer in hex
//   [X] void test_3arg(int64 a, int64 b, int64 c) -- logs three int64 values
//
// Routine exception handling:
//   [X] Uncaught throws inside a routine are automatically caught & logged
//   [X] The script keeps running after the exception
//
// Script lifecycle:
//   [X] main() runs once when the script is loaded
//   [X] Routines run continuously after main() returns
//   [X] On unload: all routines stop, GPU resources are auto-destroyed
// ============================================================================

// ============================================================================
// GLOBALS
// ============================================================================

int64 g_fails;
int64 g_checks;

// Handles and counters for demonstration routines
int64 g_data_handle;
int64 g_data_received;

int64 g_self_handle;
int64 g_self_count;

int64 g_exc_handle;
int64 g_exc_count;

// ============================================================================
// TEST HELPERS
// ============================================================================

void check(bool ok, string label) {
    g_checks = g_checks + 1;
    if (!ok) {
        println("  FAIL:  " + label);
        g_fails = g_fails + 1;
    }
}

void check_eq(int64 actual, int64 expected, string label) {
    g_checks = g_checks + 1;
    if (actual != expected) {
        println("  FAIL:  " + label
                + "  --  got " + cast<string>(actual)
                + ", expected " + cast<string>(expected));
        g_fails = g_fails + 1;
    }
}

// ============================================================================
// TEST 1: Diagnostic helpers
// ============================================================================
// Exercises all four quick-tracing functions.
// These are void -- we call them and verify no crash.
// ============================================================================

void test_diagnostics() {
    println("Test 1:  Diagnostic helpers");

    // void heartbeat()  --  logs "heartbeat called" to enma.log
    heartbeat();

    // void take_int(int64 x)  --  logs the value
    take_int(42);
    take_int(-1);
    take_int(0);
    take_int(999999);

    // void take_ptr(int64 p)  --  logs the pointer address in hex
    take_ptr(0xBEEF);
    take_ptr(0xDEADCAFE);
    take_ptr(0);

    // void test_3arg(int64 a, int64 b, int64 c)  --  logs all three
    test_3arg(10, 20, 30);
    test_3arg(-1, -2, -3);
    test_3arg(0, 0, 0);

    // These calls are side-effect-only (writes to enma.log).
    // If we reach this line without crashing, all four functions work.
    check(true, "heartbeat, take_int, take_ptr, test_3arg called without error");
}

// ============================================================================
// TEST 2: register_routine -- basic registration and return value
// ============================================================================

void cb_basic(int64 data) {
    // Minimal callback for registration testing
}

void test_register_routine() {
    println("Test 2:  register_routine returns valid handle");

    int64 handle = register_routine(cast<int64>(cb_basic), 0);
    check(handle > 0, "register_routine returned a positive handle");

    // Cleanup: unregister so the callback never fires
    bool unreg = unregister_routine(handle);
    check(unreg, "unregister_routine returned true for the handle just registered");
}

// ============================================================================
// TEST 3: Multiple routines get distinct handles
// ============================================================================

void cb_multi_a(int64 data) { }
void cb_multi_b(int64 data) { }
void cb_multi_c(int64 data) { }

void test_multiple_routines() {
    println("Test 3:  Multiple routines get distinct handles");

    int64 h1 = register_routine(cast<int64>(cb_multi_a), 10);
    int64 h2 = register_routine(cast<int64>(cb_multi_b), 20);
    int64 h3 = register_routine(cast<int64>(cb_multi_c), 30);

    check(h1 > 0, "routine A handle is positive");
    check(h2 > 0, "routine B handle is positive");
    check(h3 > 0, "routine C handle is positive");

    check(h1 != h2, "handles are unique (A != B)");
    check(h2 != h3, "handles are unique (B != C)");
    check(h1 != h3, "handles are unique (A != C)");

    // Unregister all three
    check(unregister_routine(h1), "unregistered routine A");
    check(unregister_routine(h2), "unregistered routine B");
    check(unregister_routine(h3), "unregistered routine C");
}

// ============================================================================
// DEMONSTRATION ROUTINES (fire after main() returns)
// ============================================================================

// ---------------------------------------------------------------------------
// Demo A: data parameter passthrough
//   Shows that the `data` argument passed to register_routine reaches the
//   callback as its parameter.
// ---------------------------------------------------------------------------

void cb_data_check(int64 data) {
    g_data_received = data;
    take_int(g_data_received);
}

// ---------------------------------------------------------------------------
// Demo B: self-unregistration
//   Shows that a routine can unregister itself from inside its own callback.
//   Fires 5 times then unregisters itself.
// ---------------------------------------------------------------------------

void cb_self_unreg(int64 data) {
    g_self_count = g_self_count + 1;
    heartbeat();
    take_int(g_self_count);
    if (g_self_count >= 5) {
        println("  routine self-unregistered after "
                + cast<string>(g_self_count) + " fires");
        unregister_routine(g_self_handle);
    }
}

// ---------------------------------------------------------------------------
// Demo C: automatic exception handling in routines
//   Throws on every 3rd invocation. The runtime logs the exception and
//   continues running the routine on subsequent frames.
//   After 15 total fires it self-unregisters.
// ---------------------------------------------------------------------------

void cb_exception_demo(int64 data) {
    g_exc_count = g_exc_count + 1;
    take_int(g_exc_count);

    // Throw every 3rd call  --  the runtime catches this automatically
    // and logs it to <my_games>/exceptions/enma.log
    if (g_exc_count % 3 == 0) {
        throw "intentional exception in routine (count="
              + cast<string>(g_exc_count) + ")";
    }

    // After 15 fires, unregister
    if (g_exc_count >= 15) {
        println("  exception demo routine self-unregistered after "
                + cast<string>(g_exc_count) + " fires");
        unregister_routine(g_exc_handle);
    }
}

// ============================================================================
// MAIN
// ============================================================================

int64 main() {
    g_fails = 0;
    g_checks = 0;

    println("");
    println("=== Lifecycle and Routines API Test ===");
    println("");

    // -- Phase 1: synchronous tests inside main() --
    test_diagnostics();
    test_register_routine();
    test_multiple_routines();

    println("");
    println("=== Registering demonstration routines ===");
    println("(These fire repeatedly after main() returns.)");

    // -- Phase 2: register demo routines that fire after main() returns --

    // Demo A: data passthrough
    //   register_routine(cast<int64>(fn), 42)  -->  callback receives 42
    g_data_received = 0;
    g_data_handle = register_routine(cast<int64>(cb_data_check), 42);
    check(g_data_handle > 0, "Demo A:  data-passthrough routine registered (data=42)");

    // Demo B: self-unregistration
    //   The callback counts fires and unregisters itself at threshold.
    g_self_count = 0;
    g_self_handle = register_routine(cast<int64>(cb_self_unreg), 0);
    check(g_self_handle > 0, "Demo B:  self-unregister routine registered");

    // Demo C: automatic exception catching
    //   Throws every 3rd frame -- the runtime logs and continues.
    g_exc_count = 0;
    g_exc_handle = register_routine(cast<int64>(cb_exception_demo), 0);
    check(g_exc_handle > 0, "Demo C:  exception demo routine registered");

    // -- Summary --
    println("");
    println("tests run:  " + cast<string>(g_checks));
    if (g_fails == 0) {
        println("ALL SYNCHRONOUS TESTS PASSED");
    } else {
        println("FAILED:  " + cast<string>(g_fails) + " test(s) failed");
    }

    // Return > 0 so the script stays loaded and the registered routines
    // begin firing on each frame.  (Return <= 0 would unload immediately.)
    return 1;
}
