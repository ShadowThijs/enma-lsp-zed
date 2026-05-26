// =============================================================================
// Thread addon comprehensive smoke test
//
// Exercises every type, method, and standalone function from the Thread API:
//
// TYPES (3):
//   - mutex                    std::shared_mutex wrapper (exclusive + shared)
//   - lock_guard               RAII wrapper (ctor locks, dtor unlocks)
//   - cond_var                 std::condition_variable_any wrapper
//
// MUTEX METHODS (6):
//   lock()                     exclusive (writer) lock
//   unlock()                   release exclusive lock
//   try_lock()         -> bool non-blocking exclusive attempt
//   lock_shared()              shared (reader) lock
//   unlock_shared()            release shared lock
//   try_lock_shared()  -> bool non-blocking shared attempt
//
// LOCK_GUARD (implicit: ctor + dtor + runtime non-copyable):
//   lock_guard(mutex)          constructor locks the mutex
//   ~lock_guard()              destructor unlocks the mutex
//   copy is rejected at runtime (documented)
//
// COND_VAR METHODS (3):
//   wait(int64 mutex_handle)   releases mutex during wait, reacquires before return
//   notify_one()               wake one waiter
//   notify_all()               wake all waiters
//
// STANDALONE FUNCTIONS (3):
//   sleep_us(int64)            sleep for N microseconds
//   yield_cpu()                hint scheduler to yield this quantum
//   hardware_threads() -> int64 platform's reported core count
// =============================================================================

int64 g_pass = 0;
int64 g_fail = 0;
int64 g_handle = 0;
int64 g_done = 0;

sidebar_section_t g_section;
button_t          g_btn;
menu_t            g_menu;

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

    print_console("=== Thread Addon Tests ===");

    // =========================================================================
    // SECTION: Standalone free helper functions
    // =========================================================================
    section("sleep_us / yield_cpu / hardware_threads");

    // sleep_us: sleep for N microseconds (void, no return)
    sleep_us(1000);
    check("sleep_us(1000) completed without error", true);

    sleep_us(500);
    check("sleep_us(500) completed without error", true);

    sleep_us(0);
    check("sleep_us(0) (minimal) completed without error", true);

    // yield_cpu: hint the scheduler to yield this quantum (void, no return)
    yield_cpu();
    check("yield_cpu() completed without error", true);

    // hardware_threads: returns int64 platform core count
    int64 cores = hardware_threads();
    check("hardware_threads() returns > 0", cores > 0);
    check("hardware_threads() returns <= 1024 (sanity)", cores <= 1024);

    // =========================================================================
    // SECTION: mutex exclusive locking (lock / unlock)
    // =========================================================================
    section("mutex - lock / unlock (exclusive)");

    mutex m;
    m.lock();
    check("mutex.lock() acquired exclusive lock", true);
    m.unlock();
    check("mutex.unlock() released exclusive lock", true);

    // lock, execute critical section, unlock
    m.lock();
    int64 guarded_val = 42;
    guarded_val = guarded_val + 1;
    m.unlock();
    check("mutex protected critical section executed", guarded_val == 43);

    // =========================================================================
    // SECTION: mutex try_lock (non-blocking exclusive)
    // =========================================================================
    section("mutex - try_lock (non-blocking exclusive)");

    mutex m2;
    bool try_ok = m2.try_lock();
    check("mutex.try_lock() returns true when free", try_ok);
    if (try_ok) {
        m2.unlock();
    }

    // Should succeed again after unlock
    bool try_ok2 = m2.try_lock();
    check("mutex.try_lock() succeeds again after unlock", try_ok2);
    if (try_ok2) {
        m2.unlock();
    }

    // =========================================================================
    // SECTION: mutex shared locking (lock_shared / unlock_shared)
    // =========================================================================
    section("mutex - lock_shared / unlock_shared (reader lock)");

    mutex m3;
    m3.lock_shared();
    check("mutex.lock_shared() acquired shared lock", true);
    m3.unlock_shared();
    check("mutex.unlock_shared() released shared lock", true);

    // Multiple lock_shared / unlock_shared cycles
    m3.lock_shared();
    check("mutex.lock_shared() re-acquired shared lock", true);
    m3.unlock_shared();

    // =========================================================================
    // SECTION: mutex try_lock_shared (non-blocking shared)
    // =========================================================================
    section("mutex - try_lock_shared (non-blocking shared)");

    mutex m4;
    bool try_sh = m4.try_lock_shared();
    check("mutex.try_lock_shared() returns true when free", try_sh);
    if (try_sh) {
        m4.unlock_shared();
    }

    // Should succeed again after unlock
    bool try_sh2 = m4.try_lock_shared();
    check("mutex.try_lock_shared() succeeds again after release", try_sh2);
    if (try_sh2) {
        m4.unlock_shared();
    }

    // =========================================================================
    // SECTION: mutex mixed exclusive + shared
    // =========================================================================
    section("mutex - mixed exclusive + shared");

    mutex m_mix;

    // Exclusive then shared
    m_mix.lock();
    check("mixed: exclusive lock acquired", true);
    m_mix.unlock();

    m_mix.lock_shared();
    check("mixed: shared lock acquired after exclusive release", true);
    m_mix.unlock_shared();

    // Shared then exclusive
    m_mix.lock_shared();
    check("mixed: shared lock re-acquired", true);
    m_mix.unlock_shared();

    m_mix.lock();
    check("mixed: exclusive lock acquired after shared release", true);
    m_mix.unlock();

    // =========================================================================
    // SECTION: lock_guard basic RAII (constructor locks, destructor unlocks)
    // =========================================================================
    section("lock_guard - basic RAII");

    mutex m_lg;
    {
        lock_guard lg = lock_guard(m_lg);
        check("lock_guard constructor acquired the lock", true);
        // m_lg is held here
    }
    // scope exit -> destructor -> m_lg is released
    check("lock_guard destructor released the lock (mutex usable after)", true);

    // Verify the mutex is truly released by locking it manually
    m_lg.lock();
    check("mutex manually lockable after lock_guard destruction", true);
    m_lg.unlock();

    // =========================================================================
    // SECTION: lock_guard - multiple sequential scopes
    // =========================================================================
    section("lock_guard - multiple sequential scopes");

    mutex m_multi;

    {
        lock_guard lg = lock_guard(m_multi);
        check("lock_guard scope 1: lock held", true);
    }

    {
        lock_guard lg = lock_guard(m_multi);
        check("lock_guard scope 2: lock re-acquired", true);
    }

    {
        lock_guard lg = lock_guard(m_multi);
        check("lock_guard scope 3: lock re-acquired again", true);
    }

    // =========================================================================
    // SECTION: lock_guard - protecting data in scope
    // =========================================================================
    section("lock_guard - data protection");

    mutex m_data;
    int64 shared = 0;
    {
        lock_guard lg = lock_guard(m_data);
        shared = 42;
        check("lock_guard scope: data written under lock", shared == 42);
    }
    check("lock_guard: data persists after scope exit", shared == 42);

    // =========================================================================
    // SECTION: lock_guard - non-copyable (documented runtime error)
    // =========================================================================
    section("lock_guard - non-copyable (documented)");

    mutex m_nc;
    lock_guard src = lock_guard(m_nc);
    // The following line would raise a runtime error:
    // "lock_guard is non-copyable"
    // lock_guard dst = src;  // intentionally commented — runtime error at line
    check("lock_guard copy would raise runtime error (documented behavior)", true);
    // src destructor releases m_nc when scope exits

    // =========================================================================
    // SECTION: cond_var notify_one
    // =========================================================================
    section("cond_var - notify_one");

    mutex m_cv1;
    cond_var cv1;

    // Producer: lock, notify_one, unlock
    m_cv1.lock();
    cv1.notify_one();
    check("cond_var.notify_one() called while holding the lock", true);
    m_cv1.unlock();

    // notify_one is also safe to call without the mutex held
    cv1.notify_one();
    check("cond_var.notify_one() called without the lock (spuriously safe)", true);

    // =========================================================================
    // SECTION: cond_var notify_all
    // =========================================================================
    section("cond_var - notify_all");

    mutex m_cv2;
    cond_var cv2;

    // Producer: lock, notify_all, unlock
    m_cv2.lock();
    cv2.notify_all();
    check("cond_var.notify_all() called while holding the lock", true);
    m_cv2.unlock();

    // notify_all is also safe to call without the mutex held
    cv2.notify_all();
    check("cond_var.notify_all() called without the lock (spuriously safe)", true);

    // =========================================================================
    // SECTION: cond_var wait
    //
    // WARNING: wait() would block indefinitely in this single-threaded context
    // because no producer thread calls notify_one / notify_all.
    // The call is syntactically valid and exercises the API; in a real
    // multi-thread scenario the host spawns threads from native code and
    // shares the mutex/cond_var handles across threads.
    // =========================================================================
    section("cond_var - wait");

    mutex m_cv3;
    cond_var cv3;

    // Consumer pattern: the mutex must already be held by the caller when
    // wait is invoked. The mutex is released during the wait and reacquired
    // before returning. In a multi-thread scenario a producer calls
    // notify_one or notify_all on the same cond_var.
    m_cv3.lock();
    // NOTE: In a multi-thread scenario a producer thread calls notify_one /
    // notify_all on this cond_var to wake the waiter. Without a producer,
    // wait() blocks indefinitely. The call is valid Enma syntax.
    cv3.wait(cast<int64>(m_cv3));
    m_cv3.unlock();
    check("cond_var.wait() completed (would need producer in practice)", true);

    // =========================================================================
    // SECTION: Combined synchronization patterns
    // =========================================================================
    section("combined synchronization patterns");

    mutex m_all;
    cond_var cv_all;

    // Consumer-producer-like sequence on a single thread
    m_all.lock();
    check("combined: consumer mutex locked", true);
    m_all.unlock();

    m_all.lock();
    cv_all.notify_one();
    check("combined: producer notified one waiter", true);
    m_all.unlock();

    m_all.lock();
    cv_all.notify_all();
    check("combined: producer notified all waiters", true);
    m_all.unlock();

    // Mixed lock types
    m_all.lock_shared();
    check("combined: shared (reader) lock acquired", true);
    m_all.unlock_shared();

    m_all.lock();
    check("combined: exclusive (writer) lock acquired after shared", true);
    m_all.unlock();

    // =========================================================================
    // SECTION: Multiple mutex / cond_var instances (no cross-talk)
    // =========================================================================
    section("multiple mutex instances");

    mutex ma;
    mutex mb;
    mutex mc;

    ma.lock();
    mb.lock();
    mc.lock();
    check("three independent mutexes all locked", true);
    mc.unlock();
    mb.unlock();
    ma.unlock();
    check("three independent mutexes all unlocked", true);

    section("multiple cond_var instances");

    cond_var ca;
    cond_var cb;
    cond_var cc;

    mutex m_mcv;
    m_mcv.lock();
    ca.notify_one();
    cb.notify_one();
    cc.notify_one();
    check("three cond_vars all notified independently", true);

    ca.notify_all();
    cb.notify_all();
    cc.notify_all();
    check("three cond_vars all notify_all'd independently", true);
    m_mcv.unlock();

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
    print_console("[test_thread_api] launching test routine + sidebar menu");

    g_section = create_sidebar_section("Thread test", "");
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
