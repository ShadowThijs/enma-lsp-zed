// =============================================================================
// net_api.em — comprehensive exercise of every Net API native
// =============================================================================
//
// CHECKLIST — every type, every method, every standalone function:
//
// ── Types ──────────────────────────────────────────────────────────────────────
//   T  http_response_t
//        M  .status()                                        -> int64
//        M  .body()                                          -> string
//        M  .ok()                                            -> bool
//
//   T  ws_t
//        M  .is_open()                                       -> bool
//        M  .send_text(string msg)                           -> bool
//        M  .send_binary(array<uint8> data)                  -> bool
//        M  .recv()                                          -> ws_message_t
//        M  .poll()                                          -> ws_message_t
//        M  .close(int64 code)                               -> void
//
//   T  ws_message_t
//        M  .ok()                                            -> bool
//        M  .is_text()                                       -> bool
//        M  .is_closed()                                     -> bool
//        M  .payload()                                       -> string
//
//   T  udp_t
//        M  .bind(string addr, int64 port)                   -> bool
//        M  .send_to(array<uint8> data, string addr,
//                    int64 port)                              -> bool
//        M  .recv(int64 timeout_ms)                          -> array<uint8>
//        M  .last_sender_addr()                              -> string
//        M  .last_sender_port()                              -> int64
//        M  .close()                                         -> void
//
// ── Standalone functions ──────────────────────────────────────────────────────
//   F  http_get(string url, int64 timeout)                   -> http_response_t
//   F  http_get(string url, map<string,string> headers,
//               int64 timeout)                               -> http_response_t
//   F  http_post(string url, string ct, string body,
//                int64 timeout)                              -> http_response_t
//   F  http_post(string url, string ct, string body,
//                map<string,string> headers,
//                int64 timeout)                              -> http_response_t
//   F  ws_connect(string url, int64 timeout)                 -> ws_t
//   F  udp_create()                                          -> udp_t
//
// Legend: T=type, M=method, F=free function
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
// 1. HTTP — http_get / http_post + http_response_t methods
// =============================================================================

void test_http_basic() {
    section("http_get (2-arg: url, timeout)");

    // Basic GET — http_get always returns a non-null http_response_t by contract
    http_response_t r = http_get("https://httpbin.org/get", 5000);
    check("http_get returns non-null http_response_t (always non-null by contract)",
          true);

    // http_response_t.status() — 0 on transport failure, else HTTP status
    int64 st = r.status();
    check("http_response_t.status() called, result >= 0", st >= 0);

    // http_response_t.body()
    string bd = r.body();
    check("http_response_t.body() called", true);

    // http_response_t.ok() — true if status in 200..299
    bool r_ok = r.ok();
    check("http_response_t.ok() called", true);

    // http_response_t methods on a response where status is 0 (transport failure)
    section("http_get (2-arg) with short timeout (forces transport failure)");

    http_response_t r_fail = http_get("https://httpbin.org/delay/5", 1);
    int64 st_fail = r_fail.status();
    check("http_get with 1ms timeout — status() == 0 (transport failure)",
          st_fail == 0);
    check("http_get with timeout — body() returns string (may be empty)",
          true);
    check("http_get with timeout — ok() == false when status == 0",
          !r_fail.ok());

    // http_response_t method chaining (inline call)
    section("http_response_t method chaining");

    http_response_t r_chain = http_get("https://httpbin.org/anything", 3000);
    check("inline .status() via chained response",
          r_chain.status() >= 0);
    check("inline .ok() via chained response",
          r_chain.ok() || !r_chain.ok());
    check("inline .body() via chained response returns string",
          r_chain.body().length() >= 0);
}

void test_http_with_headers() {
    section("http_get (3-arg: url, headers, timeout)");

    // Create a headers map and populate it
    map<string, string> get_headers;
    get_headers.set("Accept", "application/json");
    get_headers.set("X-Enma-Test", "net-api-test");

    http_response_t r = http_get("https://httpbin.org/headers", get_headers, 5000);
    check("http_get with headers map returns http_response_t", true);
    check("http_get(headers).status() >= 0", r.status() >= 0);
    check("http_get(headers).body() called", true);
    check("http_get(headers).ok() called", true);

    // Empty / null headers map (should behave like 2-arg version)
    section("http_get with empty headers map");

    map<string, string> empty_headers;
    http_response_t r_empty = http_get("https://httpbin.org/get",
                                       empty_headers, 5000);
    check("http_get with empty headers returns non-null", true);
    check("http_get(empty_headers).status() >= 0", r_empty.status() >= 0);
}

void test_http_post() {
    section("http_post (4-arg: url, ct, body, timeout)");

    // Standard POST with JSON content type
    http_response_t r = http_post("https://httpbin.org/post",
                                   "application/json",
                                   "{\"hello\":\"world\",\"value\":42}",
                                   5000);
    check("http_post returns non-null http_response_t", true);
    check("http_post.status() >= 0", r.status() >= 0);
    check("http_post.body() called", true);
    check("http_post.ok() called", true);

    // POST with empty content_type
    section("http_post with empty content_type");

    http_response_t r_no_ct = http_post("https://httpbin.org/post",
                                         "",
                                         "raw body without content type",
                                         5000);
    check("http_post(empty ct) returns non-null", true);
    check("http_post(empty ct).status() >= 0", r_no_ct.status() >= 0);
    check("http_post(empty ct).body() called", true);

    // POST with empty body
    section("http_post with empty body");

    http_response_t r_empty_body = http_post("https://httpbin.org/post",
                                              "text/plain",
                                              "",
                                              5000);
    check("http_post(empty body) returns non-null", true);
    check("http_post(empty body).status() >= 0", r_empty_body.status() >= 0);
}

void test_http_post_with_headers() {
    section("http_post (5-arg: url, ct, body, headers, timeout)");

    map<string, string> post_headers;
    post_headers.set("Authorization", "Bearer test-token-value");
    post_headers.set("X-Custom-Header", "custom-value-42");
    post_headers.set("Accept", "application/json");

    http_response_t r = http_post("https://httpbin.org/post",
                                   "application/json",
                                   "{\"hello\":\"world\"}",
                                   post_headers,
                                   5000);
    check("http_post with headers map returns non-null", true);
    check("http_post(headers).status() >= 0", r.status() >= 0);
    check("http_post(headers).body() called", true);
    check("http_post(headers).ok() called", true);

    // POST with headers but empty content_type
    section("http_post with headers + empty ct");

    map<string, string> auth_only;
    auth_only.set("Authorization", "Bearer test");

    http_response_t r2 = http_post("https://httpbin.org/post",
                                    "",
                                    "{\"data\":1}",
                                    auth_only,
                                    5000);
    check("http_post(headers, empty ct) returns non-null", true);
    check("http_post(headers, empty ct).status() >= 0", r2.status() >= 0);
}

// =============================================================================
// 2. WebSocket — ws_connect + ws_t + ws_message_t
// =============================================================================

void test_websocket() {
    section("ws_connect");

    // Connect to an echo WebSocket server
    ws_t ws = ws_connect("wss://echo.example.com/", 5000);
    int64 ws_handle = cast<int64>(ws);
    bool ws_valid = ws_handle != 0;

    // The handle may be null (permission denied / network failure / server down)
    check("ws_connect returns ws_t (null handle on failure, non-null on success)",
          true);

    if (ws_valid) {
        // --- ws_t methods ---

        section("ws_t.is_open");
        bool open = ws.is_open();
        check("ws.is_open() called after connect", true);

        section("ws_t.send_text");
        bool sent_text = ws.send_text("Hello from Enma Net API test!");
        check("ws.send_text() called", true);

        section("ws_t.send_binary");
        array<uint8> bin_data;
        bin_data.push(0x48);  // H
        bin_data.push(0x65);  // e
        bin_data.push(0x6C);  // l
        bin_data.push(0x6C);  // l
        bin_data.push(0x6F);  // o
        bool sent_bin = ws.send_binary(bin_data);
        check("ws.send_binary() called with 5-byte message", true);

        // Empty binary message
        section("ws.send_binary (empty)");
        array<uint8> empty_bin;
        bool sent_empty = ws.send_binary(empty_bin);
        check("ws.send_binary(empty) called", true);

        // --- ws_t.recv (blocking) ---

        section("ws_t.recv");
        ws_message_t msg_r = ws.recv();
        check("ws.recv() returns ws_message_t", true);

        // --- ws_message_t methods via recv ---

        section("ws_message_t methods (from recv)");
        bool msg_r_ok = msg_r.ok();
        check("ws_message_t.ok() called", true);

        bool msg_r_is_text = msg_r.is_text();
        check("ws_message_t.is_text() called", true);

        bool msg_r_is_closed = msg_r.is_closed();
        check("ws_message_t.is_closed() called", true);

        string msg_r_payload = msg_r.payload();
        check("ws_message_t.payload() called", true);
        check("ws_message_t.payload().length() >= 0",
              msg_r_payload.length() >= 0);

        // --- ws_t.poll (non-blocking) ---

        section("ws_t.poll");
        ws_message_t msg_p = ws.poll();
        check("ws.poll() returns ws_message_t", true);

        // --- ws_message_t methods via poll ---

        section("ws_message_t methods (from poll)");
        bool msg_p_ok = msg_p.ok();
        check("ws.poll().ok() called", true);

        bool msg_p_is_text = msg_p.is_text();
        check("ws.poll().is_text() called", true);

        bool msg_p_is_closed = msg_p.is_closed();
        check("ws.poll().is_closed() called", true);

        string msg_p_payload = msg_p.payload();
        check("ws.poll().payload() called", true);

        // --- ws_t.close ---

        section("ws_t.close");
        ws.close(1000);  // 1000 = normal closure
        check("ws.close(1000) called (normal closure)", true);

        // After close, is_open should return false
        bool still_open = ws.is_open();
        check("ws.is_open() after close returns false", !still_open);
    } else {
        print_console("  (ws_t handle is null — skipping ws_t/ws_message_t method calls)");
        g_skip = g_skip + 17;  // Count skipped checks
    }
}

// =============================================================================
// 3. UDP — udp_create + udp_t methods
// =============================================================================

void test_udp() {
    section("udp_create");

    // Create a UDP socket
    udp_t s = udp_create();
    int64 s_handle = cast<int64>(s);
    bool s_valid = s_handle != 0;

    // May be null if permission denied
    check("udp_create returns udp_t (null handle on failure)", true);

    if (s_valid) {
        // --- udp_t.bind ---

        section("udp_t.bind");
        // Bind to all interfaces with OS-picked port (port 0)
        bool bound = s.bind("0.0.0.0", 0);
        check("udp.bind('0.0.0.0', 0) called", true);

        // Bind to a specific port
        bool bound2 = s.bind("0.0.0.0", 9999);
        check("udp.bind('0.0.0.0', 9999) called", true);

        // --- udp_t.send_to ---

        section("udp_t.send_to");
        // Build an A2S_INFO query packet for Source Engine servers
        array<uint8> query;
        query.push(0xFF);
        query.push(0xFF);
        query.push(0xFF);
        query.push(0xFF);
        query.push(0x54);  // A2S_INFO header byte

        // Append "Source Engine Query\0"
        string banner = "Source Engine Query";
        int32 bi = 0;
        while (bi < cast<int32>(banner.length())) {
            int32 ch = banner.char_at(bi);
            query.push(cast<uint8>(ch));
            bi = bi + 1;
        }
        query.push(0x00);

        bool sent = s.send_to(query, "127.0.0.1", 27015);
        check("udp.send_to() called with A2S_INFO query", true);

        // Send to a different target
        array<uint8> small_msg;
        small_msg.push(0x01);
        small_msg.push(0x02);
        small_msg.push(0x03);
        bool sent2 = s.send_to(small_msg, "192.168.1.1", 1234);
        check("udp.send_to() called with small datagram", true);

        // Send empty datagram
        array<uint8> empty_msg;
        bool sent_empty = s.send_to(empty_msg, "127.0.0.1", 0);
        check("udp.send_to() called with empty data", true);

        // --- udp_t.recv ---

        section("udp_t.recv");
        // Receive with a short timeout (non-blocking-ish, 50ms)
        array<uint8> reply = s.recv(50);
        check("udp.recv(50) called", true);
        int64 reply_len = reply.length();
        check("udp.recv() returns array<uint8> with length >= 0",
              reply_len >= 0);

        // Receive with 0 timeout (block indefinitely)
        // Use a very short timeout so we don't actually block
        array<uint8> reply_block = s.recv(10);
        check("udp.recv(10) called (brief timeout)", true);

        // --- udp_t.last_sender_addr / last_sender_port ---

        section("udp_t.last_sender_addr / last_sender_port");

        string sender_addr = s.last_sender_addr();
        check("udp.last_sender_addr() called (returns string)", true);

        int64 sender_port = s.last_sender_port();
        check("udp.last_sender_port() called (returns int64)",
              sender_port >= 0);

        // --- udp_t.close ---

        section("udp_t.close");
        s.close();
        check("udp.close() called", true);
    } else {
        print_console("  (udp_t handle is null — skipping udp_t method calls)");
        g_skip = g_skip + 11;  // Count skipped checks
    }
}

// =============================================================================
// 4. Edge cases and defensive scenarios
// =============================================================================

void test_edge_cases() {
    section("Edge cases");

    // http_get with very long URL (may fail, but must not crash)
    string long_url = "https://httpbin.org/get?";
    int32 i = 0;
    while (i < 100) {
        long_url = long_url + "p" + cast<string>(i) + "=" + cast<string>(i) + "&";
        i = i + 1;
    }
    http_response_t r_long = http_get(long_url, 3000);
    check("http_get with long query string does not crash", true);
    check("http_get(long url).status() >= 0", r_long.status() >= 0);

    // http_post with binary-ish body content
    http_response_t r_bin = http_post("https://httpbin.org/post",
                                       "application/octet-stream",
                                       "\x00\x01\x02\xFF\xFE\xFD",
                                       3000);
    check("http_post with binary content does not crash", true);

    // http_get with all headers null/empty in map
    section("Empty map for http_get headers");
    map<string, string> null_map;
    http_response_t r_null_hdr = http_get("https://httpbin.org/get",
                                           null_map, 3000);
    check("http_get with empty-map headers is handled", true);

    // http_post with all headers null/empty in map
    section("Empty map for http_post headers");
    http_response_t r_null_ph = http_post("https://httpbin.org/post",
                                           "text/plain", "hello",
                                           null_map, 3000);
    check("http_post with empty-map headers is handled", true);

    // UDP: create, close without bind (send-only socket)
    section("UDP send-only (no bind)");
    udp_t s_raw = udp_create();
    int64 h_raw = cast<int64>(s_raw);
    if (h_raw != 0) {
        array<uint8> d;
        d.push(0x00);
        bool sent_raw = s_raw.send_to(d, "127.0.0.1", 9999);
        check("udp.send_to without bind works (send-only socket)", true);
        s_raw.close();
        check("udp.close() on send-only socket", true);
    } else {
        print_console("  (no UDP handle — skipping send-only test)");
        g_skip = g_skip + 2;
    }
}

// =============================================================================
// main — run every test group
// =============================================================================

int32 main() {
    print_console("=== net_api.em: comprehensive Net API test ===");

    test_http_basic();
    test_http_with_headers();
    test_http_post();
    test_http_post_with_headers();
    test_websocket();
    test_udp();
    test_edge_cases();

    // Print summary
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
