// Minimal proc API repro. Each println marks a step so we can see where
// execution dies. The first missing print = the faulting call.

int32 main() {
    print_console("step 1: entered main");

    proc_t p = ref_process("notepad.exe");
    print_console("step 2: ref_process('notepad.exe') returned");

    bool a = p.alive();
    print_console("step 3: alive() returned");

    if (a) {
        print_console("  -> notepad IS alive");
    } else {
        print_console("  -> notepad NOT running");
        return 0;
    }

    int64 pid_v = p.pid();
    print_console("step 4: pid() returned");
    print_console("  pid = " + cast<string>(pid_v));

    int64 base = p.base_address();
    print_console("step 5: base_address() returned");
    print_console("  base = " + cast<string>(base));

    uint8 mz = p.ru8(base);
    print_console("step 6: ru8(base) returned");
    print_console("  byte0 = " + cast<string>(mz));

    print_console("step 7: about to drop p");
    return 0;
    // p destructs here
}
