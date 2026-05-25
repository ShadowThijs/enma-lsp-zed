// === STRUCTS ===

struct Particle {
    float64 x;
    float64 y;
    float64 vx;
    float64 vy;
    float64 hue;
    float64 size;
}

// === CLASSES ===

class Boid {
    float64 x;
    float64 y;
    float64 angle;
    float64 speed;
    int64 seed;

    Boid() {
        x = 0.0;
        y = 0.0;
        angle = 0.0;
        speed = 1.5;
        seed = 0;
    }

    void update(float64 vw, float64 vh) {
        x = x + cos(angle) * speed;
        y = y + sin(angle) * speed;
        if (x < 0.0) { x = vw; }
        if (x > vw)  { x = 0.0; }
        if (y < 0.0) { y = vh; }
        if (y > vh)  { y = 0.0; }
        angle = angle + 0.04;
    }

    int64 col_r() { return 110 + (seed * 7) % 145; }
    int64 col_g() { return 110 + (seed * 13) % 145; }
    int64 col_b() { return 110 + (seed * 19) % 145; }

    int64 nose_x() { return cast<int64>(x + cos(angle) * 12.0); }
    int64 nose_y() { return cast<int64>(y + sin(angle) * 12.0); }
}

class Counter {
    string label;
    int64 value;
    Counter() { label = ""; value = 0; }
    Counter(string n, int64 v) { label = n; value = v; }
    void inc() { value = value + 1; }
    void add(int64 d) { value = value + d; }
    int64 get() { return value; }
}

// === TEMPLATES ===

template<typename T>
T tmin(T a, T b) { if (a < b) return a; return b; }

template<typename T>
T tmax(T a, T b) { if (a > b) return a; return b; }

template<typename T>
T tclamp(T v, T lo, T hi) { return tmax<T>(lo, tmin<T>(hi, v)); }

template<typename T>
struct Pair {
    T first;
    T second;
    Pair() { }
    Pair(T a, T b) { first = a; second = b; }
    T sum() { return first + second; }
}

// === GLOBALS ===

int64 g_tick;
int64 g_caught_count;
int64 g_mode;
int64 g_mode_age;
int64 g_inited;
int64 g_trace;   // 1 = log take_int markers, 0 = silent (set to 0 after first 3 frames)

int64 g_neb_shader;
int64 g_neb_vb;
int64 g_neb_cb;
float32[] g_neb_cbdata;

int64 g_tri_shader;
int64 g_tri_vb;

// Heap arrays of struct / class — exercises pointer-to-struct and pointer-to-class.
int64 g_part_n;
Particle* g_particles;

int64 g_boid_n;
Boid* g_boids;

int64 g_counter_n;
Counter* g_counters;

// Templated value (heap-allocated so we can assign in init)
Pair<int64>* g_score;

// FPS history (primitive typed array)
int64 g_fps_max;
int64 g_fps_idx;
float64[] g_fps_hist;

// === HELPERS ===

int64 fib(int64 n) {
    if (n < 2) { return n; }
    return fib(n - 1) + fib(n - 2);
}

int64 sum_range(int64 from, int64 to) {
    int64 acc = 0;
    int64 i = from;
    while (i <= to) {
        acc = acc + i;
        i = i + 1;
    }
    return acc;
}

void try_throw_test() {
    try {
        if (g_tick % 7 == 0) {
            throw "string-throw";
        }
        if (g_tick % 11 == 0) {
            int64 v = 9000;
            throw v;
        }
    } catch (string e) {
        g_caught_count = g_caught_count + 1;
    } catch (int64 e) {
        g_caught_count = g_caught_count + 1;
    }
}

// === PARTICLE SYSTEM (struct + Particle*) ===

void init_particles(int64 n, float64 vw, float64 vh) {
    take_int(3000);
    g_part_n = n;
    take_int(3001);
    g_particles = new Particle[n];
    take_int(3002);
    int64 i = 0;
    while (i < n) {
        if (i % 16 == 0) { take_int(3100 + i); }
        g_particles[i].x = rand() * vw;
        g_particles[i].y = rand() * vh;
        float64 ang = rand() * 6.28318530718;
        float64 spd = 1.0 + rand() * 2.5;
        g_particles[i].vx = cos(ang) * spd;
        g_particles[i].vy = sin(ang) * spd;
        g_particles[i].hue = rand() * 360.0;
        g_particles[i].size = 3.5 + rand() * 4.0;
        i = i + 1;
    }
    take_int(3003);
}

void update_particles_array(Particle* arr, int64 n, float64 vw, float64 vh) {
    int64 i = 0;
    while (i < n) {
        arr[i].x = arr[i].x + arr[i].vx;
        arr[i].y = arr[i].y + arr[i].vy;
        if (arr[i].x < 0.0) { arr[i].x = 0.0; arr[i].vx = -arr[i].vx; }
        if (arr[i].x > vw)  { arr[i].x = vw;  arr[i].vx = -arr[i].vx; }
        if (arr[i].y < 0.0) { arr[i].y = 0.0; arr[i].vy = -arr[i].vy; }
        if (arr[i].y > vh)  { arr[i].y = vh;  arr[i].vy = -arr[i].vy; }
        arr[i].hue = fmod(arr[i].hue + 0.7, 360.0);
        i = i + 1;
    }
}

void draw_particles_array(Particle* arr, int64 n) {
    if (g_trace == 1) { take_int(8000); take_int(900000 + n); }
    int64 i = 0;
    while (i < n) {
        // Log i + n every 16 iters so we can see if n is being corrupted
        // by one of the natives inside the loop body.
        if (g_trace == 1 && i % 16 == 0) {
            take_int(8100 + i);
            take_int(910000 + n);
        }
        float64 rad_h = arr[i].hue * 0.0174532925;
        int64 r = 110 + cast<int64>(fabs(sin(rad_h)) * 145.0);
        int64 g = 110 + cast<int64>(fabs(sin(rad_h + 2.094)) * 145.0);
        int64 b = 110 + cast<int64>(fabs(sin(rad_h + 4.188)) * 145.0);
        color c = color(r, g, b, 220);
        float64 px = arr[i].x;
        float64 py = arr[i].y;
        float64 sz = arr[i].size;
        vec2 pos = vec2(px, py);
        draw_circle(pos, sz, c, 0.0, true);
        i = i + 1;
    }
    if (g_trace == 1) { take_int(8001); take_int(920000 + n); }
}

// === BOID SWARM (class + Boid*) ===

void init_boids(int64 n, float64 vw, float64 vh) {
    take_int(4000);
    g_boid_n = n;
    take_int(4001);
    g_boids = new Boid[n];
    take_int(4002);
    int64 i = 0;
    while (i < n) {
        if (i % 16 == 0) { take_int(4100 + i); }
        g_boids[i].x = rand() * vw;
        g_boids[i].y = rand() * vh;
        g_boids[i].angle = rand() * 6.28318530718;
        g_boids[i].speed = 1.0 + rand() * 2.0;
        g_boids[i].seed = i + 1;
        i = i + 1;
    }
    take_int(4003);
}

void update_boids(float64 vw, float64 vh) {
    int64 i = 0;
    while (i < g_boid_n) {
        g_boids[i].update(vw, vh);
        i = i + 1;
    }
}

void draw_boids() {
    int64 i = 0;
    while (i < g_boid_n) {
        int64 r = g_boids[i].col_r();
        int64 g = g_boids[i].col_g();
        int64 b = g_boids[i].col_b();
        color body  = color(r, g, b, 230);
        color trail = color(r, g, b, 120);
        float64 bx = g_boids[i].x;
        float64 by = g_boids[i].y;
        float64 nx = cast<float64>(g_boids[i].nose_x());
        float64 ny = cast<float64>(g_boids[i].nose_y());
        draw_line(vec2(bx, by), vec2(nx, ny), body, 1.5);
        draw_circle(vec2(bx, by), 3.5, trail, 0.0, true);
        i = i + 1;
    }
}

// === COUNTERS (class array) ===

void init_counters() {
    g_counter_n = 4;
    g_counters = new Counter[g_counter_n];
    // Field-set pattern — `g_counters[i] = Counter(...)` would create a stack
    // value that escapes via the heap array.
    g_counters[0].label = "ticks";     g_counters[0].value = 0;
    g_counters[1].label = "throws";    g_counters[1].value = 0;
    g_counters[2].label = "particles"; g_counters[2].value = g_part_n;
    g_counters[3].label = "boids";     g_counters[3].value = g_boid_n;
}

void update_counters() {
    g_counters[0].inc();
    g_counters[1].value = g_caught_count;
    g_counters[2].value = g_part_n;
    g_counters[3].value = g_boid_n;
}

// === FPS GRAPH (primitive typed array, no panel) ===

void init_fps_history(int64 cap) {
    g_fps_max = cap;
    g_fps_idx = 0;
    int64 i = 0;
    while (i < cap) { g_fps_hist.push(60.0); i = i + 1; }
}

void record_fps() {
    g_fps_hist.set(g_fps_idx, get_fps());
    g_fps_idx = (g_fps_idx + 1) % g_fps_max;
}

void draw_fps_strip(float64 x, float64 y, float64 w, float64 h) {
    if (g_trace == 1) { take_int(7000); }
    color line_c = color(120, 220, 255, 220);
    int64 n = g_fps_max;
    float64 dx = w / cast<float64>(n);
    int64 i = 0;
    if (g_trace == 1) { take_int(7001); }
    while (i < n - 1) {
        if (g_trace == 1 && i % 16 == 0) { take_int(7100 + i); }
        int64 a = (g_fps_idx + i) % n;
        int64 b = (g_fps_idx + i + 1) % n;
        float64 va = fmin(fmax(g_fps_hist.get(a) / 144.0, 0.0), 1.0);
        float64 vb = fmin(fmax(g_fps_hist.get(b) / 144.0, 0.0), 1.0);
        float64 px = x + cast<float64>(i) * dx;
        float64 qx = x + cast<float64>(i + 1) * dx;
        float64 py = y + h - va * h;
        float64 qy = y + h - vb * h;
        draw_line(vec2(px, py), vec2(qx, qy), line_c, 1.0);
        i = i + 1;
    }
    if (g_trace == 1) { take_int(7002); }
}

// === LISSAJOUS ===

void draw_lissajous(float64 cx, float64 cy, float64 r) {
    float64 t = cast<float64>(g_tick) * 0.025;
    float64 a = 3.0;
    float64 b = 2.0;
    int64 steps = 128;
    float64 du = 6.28318530718 / cast<float64>(steps);
    float64 prev_x = cx + r * sin(t);
    float64 prev_y = cy + r * sin(0.0);
    int64 i = 0;
    while (i < steps) {
        float64 u = cast<float64>(i + 1) * du;
        float64 nx = cx + r * sin(a * u + t);
        float64 ny = cy + r * sin(b * u);
        float64 frac01 = cast<float64>(i) / cast<float64>(steps);
        int64 cr = 140 + cast<int64>(115.0 * frac01);
        int64 cg = 220 - cast<int64>(80.0 * frac01);
        color line_c = color(cr, cg, 255, 220);
        draw_line(vec2(prev_x, prev_y), vec2(nx, ny), line_c, 1.6);
        prev_x = nx;
        prev_y = ny;
        i = i + 1;
    }
}

// === DEFER + EXCEPTION DEMO (uses the new pattern) ===

int64 defer_smoke(int64 input) {
    int64 result = input;
    defer { g_score->second = g_score->second + 1; }
    if (input < 0) {
        int64 v = 4242;
        throw v;
    }
    result = result * 2;
    return result;
}

void run_defer_demo() {
    try {
        int64 a = defer_smoke(10);
        int64 b = defer_smoke(-1);
        g_score->first = a + b;
    } catch (int64 e) {
        g_caught_count = g_caught_count + 1;
    }
}

// === NEBULA (uses cb) ===

void render_nebula(float64 vw, float64 vh) {
    if (g_neb_shader == 0 || g_neb_vb == 0) { return; }
    g_neb_cbdata.set(0, cast<float32>(cast<float64>(g_tick) * 0.0166));
    g_neb_cbdata.set(1, cast<float32>(vw / vh));
    g_neb_cbdata.set(2, 1.0f);
    g_neb_cbdata.set(3, 0.0f);

    float32[] verts;
    verts.push(-1.0f); verts.push(-1.0f);
    verts.push( 3.0f); verts.push(-1.0f);
    verts.push(-1.0f); verts.push( 3.0f);

    custom_draw(g_neb_shader, g_neb_vb, verts, 3, 0, 0, 0, 0, 0, g_neb_cb, g_neb_cbdata, 0);
}

void render_corner_triangle() {
    if (g_tri_shader == 0 || g_tri_vb == 0) { return; }
    float32[] verts;
    verts.push(0.65f); verts.push(0.50f);
    verts.push(1.0f);  verts.push(0.2f); verts.push(0.2f); verts.push(1.0f);

    verts.push(0.95f); verts.push(0.50f);
    verts.push(0.2f);  verts.push(1.0f); verts.push(0.3f); verts.push(1.0f);

    verts.push(0.80f); verts.push(0.95f);
    verts.push(0.3f);  verts.push(0.4f); verts.push(1.0f); verts.push(1.0f);

    float32[] no_cb;
    custom_draw(g_tri_shader, g_tri_vb, verts, 3, 0, 0, 0, 0, 0, 0, no_cb, 0);
}

// === HUD (no panel — text-only with shadow on nebula) ===

void hud_line(string text, float64 x, float64 y, color c) {
    if (g_trace == 1) { take_int(5000); }
    color shadow = color(0, 0, 0, 200);
    if (g_trace == 1) { take_int(5001); }
    int64 font = get_font20();
    if (g_trace == 1) { take_int(5002); }
    draw_text(text, vec2(x, y), c, font, 1, shadow, 1.5);
    if (g_trace == 1) { take_int(5003); }
}

void draw_hud(float64 vw, float64 vh) {
    if (g_trace == 1) { take_int(6000); }
    color white  = color(240, 240, 250, 255);
    color cyan   = color(140, 220, 255, 255);
    color yellow = color(255, 220, 100, 255);
    color green  = color(160, 255, 180, 255);
    if (g_trace == 1) { take_int(6001); }

    int64 tick_local = g_tick;
    string l1 = "tick=" + cast<string>(tick_local);
    hud_line(l1, 24.0, 24.0, white);

    int64 fps_i = cast<int64>(get_fps());
    string l2 = "fps=" + cast<string>(fps_i);
    hud_line(l2, 24.0, 46.0, cyan);

    int64 mode_local = g_mode;
    string l3 = "mode " + cast<string>(mode_local) + "/3";
    hud_line(l3, 24.0, 68.0, yellow);

    int64 caught_local = g_caught_count;
    string l4 = "caught=" + cast<string>(caught_local);
    hud_line(l4, 24.0, 90.0, green);

    string label = "?";
    if (g_mode == 0) { label = "[0] particle struct array"; }
    if (g_mode == 1) { label = "[1] boid class swarm"; }
    if (g_mode == 2) { label = "[2] counters + templates"; }
    if (g_mode == 3) { label = "[3] try / catch / defer / lissajous"; }
    hud_line(label, 24.0, 116.0, white);
    if (g_trace == 1) { take_int(6011); }

    draw_fps_strip(24.0, 144.0, 200.0, 30.0);
    if (g_trace == 1) { take_int(6012); }
}

// === MODE BODIES ===

void draw_mode_particles() {
    draw_particles_array(g_particles, g_part_n);
}

void draw_mode_boids(float64 vw, float64 vh) {
    update_boids(vw, vh);
    draw_boids();
}

void draw_mode_counters(float64 vw, float64 vh) {
    color label_c = color(220, 220, 240, 255);
    color val_c   = color(255, 230, 120, 255);
    color shadow  = color(0, 0, 0, 200);
    int64 font = get_font24();
    int64 i = 0;
    float64 base_x = vw * 0.5 - 140.0;
    float64 base_y = 240.0;
    while (i < g_counter_n) {
        float64 row_y = base_y + cast<float64>(i) * 36.0;
        Counter c = g_counters[i];
        string lab = c.label;
        int64 v = c.value;
        string val_s = cast<string>(v);
        draw_text(lab, vec2(base_x, row_y), label_c, font, 1, shadow, 1.5);
        draw_text(val_s, vec2(base_x + 180.0, row_y), val_c, font, 1, shadow, 1.5);
        i = i + 1;
    }

    // template demo: tclamp + Pair<int64> readout
    int64 score_first = g_score->first;
    int64 score_second = g_score->second;
    int64 sum = g_score->sum();
    string s1 = "Pair<int64>.first=" + cast<string>(score_first);
    string s2 = "Pair<int64>.second(defers)=" + cast<string>(score_second);
    string s3 = "Pair<int64>.sum()=" + cast<string>(sum);
    draw_text(s1, vec2(base_x, base_y + cast<float64>(g_counter_n) * 36.0 + 8.0),  label_c, font, 1, shadow, 1.5);
    draw_text(s2, vec2(base_x, base_y + cast<float64>(g_counter_n) * 36.0 + 36.0), label_c, font, 1, shadow, 1.5);
    draw_text(s3, vec2(base_x, base_y + cast<float64>(g_counter_n) * 36.0 + 64.0), val_c,   font, 1, shadow, 1.5);
}

void draw_mode_demo(float64 vw, float64 vh) {
    try_throw_test();
    run_defer_demo();
    draw_lissajous(vw * 0.5, vh * 0.55, 110.0);

    int64 caught_local = g_caught_count;
    string s = "try/catch lifetime=" + cast<string>(caught_local);
    color y = color(255, 220, 100, 255);
    color shadow = color(0, 0, 0, 220);
    int64 font = get_font24();
    draw_text(s, vec2(vw * 0.5 - 140.0, vh * 0.5 + 140.0), y, font, 1, shadow, 1.5);
}

// === MAIN CALLBACK ===

void my_draw(int64 data) {
    if (g_trace == 1) { take_int(1000); }
    g_tick = g_tick + 1;

    float64 vw = get_view_width();
    float64 vh = get_view_height();
    if (g_trace == 1) { take_int(1001); }

    if (g_inited == 0) {
        take_int(2000);
        init_particles(72, vw, vh);
        take_int(2001);
        init_boids(48, vw, vh);
        take_int(2002);
        init_fps_history(60);
        take_int(2003);
        init_counters();
        take_int(2004);
        g_score = new Pair<int64>(0, 0);
        take_int(2005);
        g_inited = 1;
        take_int(2006);
    }

    g_mode_age = g_mode_age + 1;
    if (g_mode_age >= 240) {
        g_mode = (g_mode + 1) % 4;
        g_mode_age = 0;
    }
    if (g_trace == 1) { take_int(1002); }

    update_particles_array(g_particles, g_part_n, vw, vh);
    if (g_trace == 1) { take_int(1003); }
    record_fps();
    if (g_trace == 1) { take_int(1004); }
    update_counters();
    if (g_trace == 1) { take_int(1005); }

    // render_nebula removed — full-screen black background was hiding everything
    if (g_trace == 1) { take_int(1006); }

    // Log which mode we're about to dispatch (each mode has a unique value
    // so a single missing-1007 line tells us which mode crashed).
    if (g_trace == 1) { take_int(1100 + g_mode); }
    if (g_mode == 0) { draw_mode_particles(); }
    if (g_mode == 1) { draw_mode_boids(vw, vh); }
    if (g_mode == 2) { draw_mode_counters(vw, vh); }
    if (g_mode == 3) { draw_mode_demo(vw, vh); }
    if (g_trace == 1) { take_int(1007); }

    draw_hud(vw, vh);
    if (g_trace == 1) { take_int(1008); }
    render_corner_triangle();
    if (g_trace == 1) { take_int(1009); }

    // Trace only the first 3 frames — kills the spam after we've confirmed
    // the script reaches 1009 cleanly.
    if (g_tick >= 3) { g_trace = 0; }
}

// === MAIN ===

int64 main() {
    take_int(1);

    g_tick = 0;
    g_caught_count = 0;
    g_mode = 0;
    g_mode_age = 0;
    g_inited = 0;
    g_trace = 1;   // log take_int markers for first 3 frames, then auto-off

    seed(1337);

    string nv = "" +
        "struct VSIn { float2 pos : POSITION; };\n" +
        "struct VSOut { float4 pos : SV_Position; float2 ndc : TEXCOORD0; };\n" +
        "VSOut main(VSIn i) {\n" +
        "    VSOut o;\n" +
        "    o.pos = float4(i.pos, 0.0, 1.0);\n" +
        "    o.ndc = i.pos;\n" +
        "    return o;\n" +
        "}\n";

    string np = "" +
        "cbuffer Params : register(b0) {\n" +
        "    float u_time;\n" +
        "    float u_aspect;\n" +
        "    float u_intensity;\n" +
        "    float u_pad;\n" +
        "};\n" +
        "struct VSOut { float4 pos : SV_Position; float2 ndc : TEXCOORD0; };\n" +
        "float hash21(float2 p) {\n" +
        "    return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);\n" +
        "}\n" +
        "float vnoise(float2 p) {\n" +
        "    float2 i = floor(p);\n" +
        "    float2 f = frac(p);\n" +
        "    f = f*f*(3.0 - 2.0*f);\n" +
        "    float a = hash21(i);\n" +
        "    float b = hash21(i + float2(1.0, 0.0));\n" +
        "    float c = hash21(i + float2(0.0, 1.0));\n" +
        "    float d = hash21(i + float2(1.0, 1.0));\n" +
        "    return lerp(lerp(a, b, f.x), lerp(c, d, f.x), f.y);\n" +
        "}\n" +
        "float fbm(float2 p) {\n" +
        "    float v = 0.0;\n" +
        "    float a = 0.5;\n" +
        "    [unroll]\n" +
        "    for (int k = 0; k < 5; ++k) {\n" +
        "        v += a * vnoise(p);\n" +
        "        p *= 2.03;\n" +
        "        a *= 0.5;\n" +
        "    }\n" +
        "    return v;\n" +
        "}\n" +
        "float4 main(VSOut input) : SV_Target {\n" +
        "    float2 uv = input.ndc;\n" +
        "    uv.x *= u_aspect;\n" +
        "    uv *= 1.7;\n" +
        "    float t = u_time * 0.06;\n" +
        "    float2 q = float2(fbm(uv + t * 0.5), fbm(uv + float2(5.2, 1.3) - t * 0.7));\n" +
        "    float2 r = float2(fbm(uv + 4.0*q + float2(1.7, 9.2) + t * 0.4),\n" +
        "                      fbm(uv + 4.0*q + float2(8.3, 2.8) - t * 0.3));\n" +
        "    float v = fbm(uv + 3.5*r);\n" +
        "    float3 c1 = float3(0.02, 0.0, 0.10);\n" +
        "    float3 c2 = float3(0.35, 0.05, 0.45);\n" +
        "    float3 c3 = float3(0.85, 0.30, 0.55);\n" +
        "    float3 c4 = float3(1.0, 0.85, 0.55);\n" +
        "    float3 col = lerp(c1, c2, smoothstep(0.0, 0.42, v));\n" +
        "    col = lerp(col, c3, smoothstep(0.42, 0.72, v));\n" +
        "    col = lerp(col, c4, smoothstep(0.72, 0.92, v));\n" +
        "    float starN = hash21(input.ndc * 700.0 + t * 30.0);\n" +
        "    float stars = pow(starN, 70.0) * 1.4;\n" +
        "    col += float3(stars, stars * 0.95, stars * 1.1);\n" +
        "    col *= u_intensity;\n" +
        "    col = saturate(col);\n" +
        "    return float4(col, 1.0);\n" +
        "}\n";

    g_neb_shader = create_shader(nv, np, "POSITION:0:FLOAT2");
    g_neb_vb     = create_vertex_buffer(8, 3, true);
    g_neb_cb     = create_constant_buffer(16);

    g_neb_cbdata.push(0.0f);
    g_neb_cbdata.push(0.0f);
    g_neb_cbdata.push(0.0f);
    g_neb_cbdata.push(0.0f);

    take_int(g_neb_shader);
    take_int(g_neb_vb);
    take_int(g_neb_cb);

    string tv = "struct VSIn { float2 pos : POSITION; float4 color : COLOR; };\nstruct VSOut { float4 pos : SV_Position; float4 color : COLOR; };\nVSOut main(VSIn i) { VSOut o; o.pos = float4(i.pos, 0.0, 1.0); o.color = i.color; return o; }\n";
    string tp = "struct VSOut { float4 pos : SV_Position; float4 color : COLOR; };\nfloat4 main(VSOut i) : SV_Target { return i.color; }\n";

    g_tri_shader = create_shader(tv, tp, "POSITION:0:FLOAT2, COLOR:0:FLOAT4");
    g_tri_vb     = create_vertex_buffer(24, 3, true);

    take_int(g_tri_shader);
    take_int(g_tri_vb);

    int64 r = register_routine(cast<int64>(my_draw), 42);
    take_int(r);

    take_int(2);
    return 1;
}
