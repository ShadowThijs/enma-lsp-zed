// =============================================================================
// proc API memory-leak stress test (run with notepad.exe open)
//
// Non-blocking shape: main() does setup + registers two routines and returns
// 1 to keep the script alive. Both routines tick every 1ms in their own host
// threads.
//
//   leak_routine        — hammers the alloc/drop paths every tick
//   coordinator_routine — waits for the hammer to finish, unregisters it,
//                         lets the heap settle, samples + prints the report,
//                         self-unregisters
//
// Pass: heap_count() before vs after the loop differs by a small constant
// (routine struct + closure handle + bookkeeping).
// Fail: count climbs linearly with iterations.
// =============================================================================

const int64 NUM_TICKS  = 500;
const int64 LOG_EVERY  = 50;
const int64 BURST_PER_TICK = 5;
const int64 SETTLE_TICKS = 200;   // ~200ms to let heap stabilise post-unreg

proc_t g_proc;
int64 g_base   = 0;

// State shared between main + the two routines.
int64 g_baseline       = 0;
int64 g_leak_handle    = 0;
int64 g_coord_handle   = 0;
int64 g_tick           = 0;
int64 g_done           = 0;
int64 g_errors         = 0;

// Coordinator state machine.
int64 g_done_ticks     = 0;       // ticks since g_done flipped to 1
int64 g_unreg_pending  = 0;       // 1 once we've unregistered the hammer
int64 g_reported       = 0;       // 1 once final report printed

// Single-shot: runs the entire NUM_TICKS x BURST_PER_TICK workload in one
// routine call so we hit the framework's per-tick MBV_Sleep(1) only once,
// not NUM_TICKS times. Subsequent ticks bail at the top guard.
//
// Errors use `continue` (not `return`) — we want to see total failures
// across the whole run, not stop on the first one.
void leak_routine(int64 data) {
    if (g_done != 0) return;   // already ran (or another thread set it)

    for (int64 t = 0; t < NUM_TICKS; t = t + 1) {
        g_tick = t + 1;

        for (int64 i = 0; i < BURST_PER_TICK; i = i + 1) {
            int64 hdr = g_proc.r64(g_base);
            if ((hdr & 0xFFFF) != 0x5A4D) { g_errors = g_errors + 1; continue; }

            array<uint8> bytes = g_proc.rvm(g_base, 64);
            if (bytes.length() != 64) { g_errors = g_errors + 1; continue; }

            array<uint8> sse = g_proc.r128(g_base);
            if (sse.length() != 16) { g_errors = g_errors + 1; continue; }

            array<int64> tebs = g_proc.get_all_tebs();
            if (tebs.length() == 0) { g_errors = g_errors + 1; continue; }

            array<int64> ptrs = g_proc.read_pointer_array(tebs.get(0), 4, 0);
            if (ptrs.length() != 4) { g_errors = g_errors + 1; continue; }

            // bytes / sse / tebs / ptrs all drop at iteration end.
        }

        if (g_tick % LOG_EVERY == 0) {
            int64 live = heap_count();
            print_console("tick=" + cast<string>(g_tick) +
                    "  heap_count=" + cast<string>(live) +
                    "  errors=" + cast<string>(g_errors));
        }
    }

    g_done = 1;
}

// Runs alongside the hammer. Each tick: bail out unless the hammer has
// finished. Then walks a small state machine to unregister + settle +
// report + self-unregister, one phase per tick.
void coordinator_routine(int64 data) {
    if (g_done == 0) return;
    if (g_reported != 0) return;

    g_done_ticks = g_done_ticks + 1;

    // Phase 1: stop the hammer.
    if (g_unreg_pending == 0) {
        print_console("hammer signalled done, unregistering...");
        unregister_routine(g_leak_handle);
        g_unreg_pending = 1;
        return;
    }

    // Phase 2: wait SETTLE_TICKS for the host to actually release the
    // routine thread + drain any in-flight allocations.
    if (g_done_ticks < SETTLE_TICKS) return;

    // Phase 3: final report.
    int64 final_count = heap_count();
    int64 delta = final_count - g_baseline;
    print_console("");
    print_console("===========================================");
    print_console("  baseline:    " + cast<string>(g_baseline));
    print_console("  final:       " + cast<string>(final_count));
    print_console("  delta:       " + cast<string>(delta));
    print_console("  errors:      " + cast<string>(g_errors));
    print_console("===========================================");

    if (g_errors != 0) {
        print_console("[FAIL] " + cast<string>(g_errors) + " errors during routine ticks");
    } else if (delta > 1000) {
        print_console("[FAIL] heap delta " + cast<string>(delta) + " too large; likely leak");
    } else {
        print_console("[PASS] heap delta within tolerance");
    }

    g_reported = 1;
    // Self-unregister. unregister_routine called from the routine's own
    // thread flips an orphaned flag + requests termination; the thread's
    // exit path destroys the routine struct itself.
    unregister_routine(g_coord_handle);
}

int32 main() {
    print_console("=== proc API leak stress (non-blocking) ===");
    print_console("ticks=" + cast<string>(NUM_TICKS) +
            "  burst/tick=" + cast<string>(BURST_PER_TICK) +
            "  total cycles=" + cast<string>(NUM_TICKS * BURST_PER_TICK));

    g_proc = ref_process("notepad.exe");
    if (!g_proc.alive()) {
        print_console("[FAIL] notepad not running");
        return 1;
    }
    g_base = g_proc.base_address();
    if (g_base == 0) {
        print_console("[FAIL] base_address() == 0");
        return 1;
    }

    g_baseline = heap_count();
    print_console("baseline heap_count=" + cast<string>(g_baseline));

    g_leak_handle = register_routine(cast<int64>(leak_routine), 0);
    if (g_leak_handle == 0) {
        print_console("[FAIL] register_routine(leak_routine) returned 0");
        return 1;
    }

    g_coord_handle = register_routine(cast<int64>(coordinator_routine), 0);
    if (g_coord_handle == 0) {
        print_console("[FAIL] register_routine(coordinator_routine) returned 0");
        return 1;
    }

    print_console("both routines registered, main returning");
    // Return positive so the engine keeps the script alive. The routines
    // run on their own host threads; the coordinator self-unregisters
    // when finished. Script stays loaded until you unload it manually.
    return 1;
}
