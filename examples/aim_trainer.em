// aim_trainer.em
//
// 3D aim trainer with sidebar GUI.
//   Click to start a 30 second session.
//   Mouse moves the camera (yaw/pitch). LMB shoots whatever's under the
//   crosshair. R restarts after the session ends.
//
// Sidebar
//   Sensitivity slider (0.1x .. 5.0x)
//   Invert X / Invert Y
//   Moving targets toggle  -- targets bounce inside the spawn volume
//   Target style options   -- 0 Bullseye, 1 Dummy (humanoid silhouette)
//   Restart button
//
// Background
//   Fullscreen PS reconstructs view rays from the camera basis vectors
//   (passed via 64 B CB) and renders a procedural sky with multi-octave
//   FBM clouds drifting at different rates, a hard sun disc, soft sun
//   halo, a 1m grid floor with anti-aliased lines, distance fog, and a
//   gentle vignette.

// ----------------------------- constants -----------------------------

int64 NUM_TARGETS = 5;

// ----------------------------- world / targets -----------------------------

float64[] g_target_x;
float64[] g_target_y;
float64[] g_target_z;
float64[] g_target_velx;
float64[] g_target_vely;
float64[] g_target_velz;
float64[] g_target_sx;
float64[] g_target_sy;
float64[] g_target_sr;
float64[] g_target_vz;
int64[]   g_target_visible;
int64[]   g_target_alive;
int64[]   g_target_spawn_ms;

float64 g_target_radius = 0.45;

// ----------------------------- camera -----------------------------

float64 g_yaw   = 0.0;
float64 g_pitch = 0.0;
float64 g_tan_half;

// ----------------------------- session state -----------------------------

int64 g_state       = 0;
int64 g_hits        = 0;
int64 g_shots       = 0;
int64 g_t_start     = 0;
int64 g_t_end       = 0;
int64 g_t_prev_update = 0;
int64 g_session_ms  = 30000;
int64 g_rng_state;
int64 g_t_app_start;

// ----------------------------- gpu resources -----------------------------

int64 g_shader;
int64 g_vb;
int64 g_cb;

// ----------------------------- sidebar / settings -----------------------------

slider_t   g_sens_slider;
checkbox_t g_invert_x;
checkbox_t g_invert_y;
checkbox_t g_moving_cb;
options_t  g_style_opts;

float64    g_sens_mult     = 1.0;
float64    g_sens_base     = 0.0025;
int64      g_inv_x         = 0;
int64      g_inv_y         = 0;
int64      g_moving        = 0;
int64      g_target_style  = 0;     // 0 = bullseye, 1 = dummy

// ----------------------------- rng -----------------------------

int64 rng_next() {
    int64 x = g_rng_state;
    x = x ^ (x << 13);
    x = x ^ (x >> 7);
    x = x ^ (x << 17);
    if (x == 0) x = 1;
    g_rng_state = x;
    return x;
}
float64 rng_float() {
    int64 r = rng_next();
    if (r < 0) r = -r;
    if (r < 0) r = 0;
    return cast<float64>(r % 1000000) / 1000000.0;
}

// ----------------------------- targets -----------------------------

void set_target_velocity(int64 i) {
    // Random unit-ish direction with a forced minimum horizontal motion
    // and reduced vertical (vy) so targets mostly slide rather than bob.
    float64 vx = rng_float() * 2.0 - 1.0;
    float64 vy = (rng_float() * 2.0 - 1.0) * 0.4;
    float64 vz = (rng_float() * 2.0 - 1.0) * 0.6;
    float64 mag = sqrt(vx * vx + vy * vy + vz * vz);
    if (mag < 0.01) mag = 0.01;
    float64 speed = 0.9 + rng_float() * 1.4;       // 0.9 .. 2.3 units/sec
    g_target_velx.set(i, vx / mag * speed);
    g_target_vely.set(i, vy / mag * speed);
    g_target_velz.set(i, vz / mag * speed);
}

void spawn_target(int64 i) {
    g_target_x.set(i, rng_float() *  8.0 - 4.0);
    g_target_y.set(i, rng_float() *  3.0 - 1.5);
    g_target_z.set(i, rng_float() *  4.0 + 5.0);
    set_target_velocity(i);
    g_target_spawn_ms.set(i, time_ms());
    g_target_alive.set(i, 1);
}

void alloc_target_arrays() {
    g_target_x.clear(); g_target_y.clear(); g_target_z.clear();
    g_target_velx.clear(); g_target_vely.clear(); g_target_velz.clear();
    g_target_sx.clear(); g_target_sy.clear(); g_target_sr.clear();
    g_target_vz.clear();
    g_target_visible.clear(); g_target_alive.clear(); g_target_spawn_ms.clear();
    int64 i = 0;
    while (i < NUM_TARGETS) {
        g_target_x.push(0.0); g_target_y.push(0.0); g_target_z.push(5.0);
        g_target_velx.push(0.0); g_target_vely.push(0.0); g_target_velz.push(0.0);
        g_target_sx.push(0.0); g_target_sy.push(0.0); g_target_sr.push(0.0);
        g_target_vz.push(0.0);
        g_target_visible.push(0); g_target_alive.push(0); g_target_spawn_ms.push(0);
        i = i + 1;
    }
}

void start_session() {
    g_state    = 1;
    g_hits     = 0;
    g_shots    = 0;
    g_t_start  = time_ms();
    g_t_prev_update = g_t_start;
    int64 i = 0;
    while (i < NUM_TARGETS) { spawn_target(i); i = i + 1; }
}

void end_session() {
    g_state = 2;
    g_t_end = time_ms();
    int64 i = 0;
    while (i < NUM_TARGETS) { g_target_alive.set(i, 0); i = i + 1; }
}

void integrate_targets(int64 now) {
    if (g_moving == 0)   { g_t_prev_update = now; return; }
    if (g_state  != 1)   { g_t_prev_update = now; return; }
    float64 dt = cast<float64>(now - g_t_prev_update) * 0.001;
    g_t_prev_update = now;
    if (dt > 0.1) dt = 0.1;
    int64 i = 0;
    while (i < NUM_TARGETS) {
        if (g_target_alive.get(i) == 1) {
            float64 x = g_target_x.get(i) + g_target_velx.get(i) * dt;
            float64 y = g_target_y.get(i) + g_target_vely.get(i) * dt;
            float64 z = g_target_z.get(i) + g_target_velz.get(i) * dt;
            if (x < -4.0) { x = -4.0; g_target_velx.set(i, -g_target_velx.get(i)); }
            if (x >  4.0) { x =  4.0; g_target_velx.set(i, -g_target_velx.get(i)); }
            if (y < -1.5) { y = -1.5; g_target_vely.set(i, -g_target_vely.get(i)); }
            if (y >  1.5) { y =  1.5; g_target_vely.set(i, -g_target_vely.get(i)); }
            if (z <  5.0) { z =  5.0; g_target_velz.set(i, -g_target_velz.get(i)); }
            if (z >  9.0) { z =  9.0; g_target_velz.set(i, -g_target_velz.get(i)); }
            g_target_x.set(i, x);
            g_target_y.set(i, y);
            g_target_z.set(i, z);
        }
        i = i + 1;
    }
}

// ----------------------------- camera basis -----------------------------

vec3 cam_forward() {
    return vec3(cos(g_pitch) * sin(g_yaw),
                -sin(g_pitch),
                cos(g_pitch) * cos(g_yaw));
}
vec3 cam_right() { return vec3(cos(g_yaw), 0.0, -sin(g_yaw)); }
vec3 cam_up()    {
    vec3 f = cam_forward();
    vec3 r = cam_right();
    return f.cross(r);
}

// ----------------------------- projection -----------------------------

void compute_target_screen() {
    float64 vw = get_view_width();
    float64 vh = get_view_height();
    float64 aspect = vw / vh;

    vec3 f = cam_forward();
    vec3 r = cam_right();
    vec3 u = cam_up();

    int64 i = 0;
    while (i < NUM_TARGETS) {
        if (g_target_alive.get(i) == 0) { g_target_visible.set(i, 0); i = i + 1; continue; }
        float64 tx = g_target_x.get(i);
        float64 ty = g_target_y.get(i);
        float64 tz = g_target_z.get(i);
        float64 vx = tx * r.x + ty * r.y + tz * r.z;
        float64 vy = tx * u.x + ty * u.y + tz * u.z;
        float64 vz = tx * f.x + ty * f.y + tz * f.z;
        g_target_vz.set(i, vz);
        if (vz <= 0.2) {
            g_target_visible.set(i, 0);
        } else {
            float64 ndc_x = vx / (vz * aspect * g_tan_half);
            float64 ndc_y = vy / (vz * g_tan_half);
            g_target_sx.set(i, (ndc_x + 1.0) * 0.5 * vw);
            g_target_sy.set(i, (1.0 - (ndc_y + 1.0) * 0.5) * vh);
            g_target_sr.set(i, g_target_radius / vz * vh * 0.5 / g_tan_half);
            g_target_visible.set(i, 1);
        }
        i = i + 1;
    }
}

// ----------------------------- input + game flow -----------------------------

int64 hit_test_at(int64 i, float64 cx, float64 cy) {
    float64 sx = g_target_sx.get(i);
    float64 sy = g_target_sy.get(i);
    float64 sr = g_target_sr.get(i);
    float64 dx = cx - sx;
    float64 dy = cy - sy;
    if (g_target_style == 0) {
        if (dx * dx + dy * dy <= sr * sr) return 1;
        return 0;
    }
    // Dummy: elongated ellipse, centred a bit above the screen-space anchor
    // (head + torso extend upward from the projection point).
    float64 cdy = dy + sr * 0.30;
    float64 rx  = sr * 0.55;
    float64 ry  = sr * 1.20;
    float64 nx  = dx  / rx;
    float64 ny  = cdy / ry;
    if (nx * nx + ny * ny <= 1.0) return 1;
    return 0;
}

int64 check_hit() {
    float64 cx = get_view_width()  * 0.5;
    float64 cy = get_view_height() * 0.5;
    int64   best     = -1;
    float64 best_vz  = 1.0e30;
    int64 i = 0;
    while (i < NUM_TARGETS) {
        if (g_target_alive.get(i) == 1 && g_target_visible.get(i) == 1) {
            if (hit_test_at(i, cx, cy) == 1) {
                float64 vz = g_target_vz.get(i);
                if (vz < best_vz) { best_vz = vz; best = i; }
            }
        }
        i = i + 1;
    }
    return best;
}

void on_click() {
    if (g_state == 0) { start_session(); return; }
    if (g_state == 2) return;
    g_shots = g_shots + 1;
    int64 hit = check_hit();
    if (hit >= 0) { g_hits = g_hits + 1; spawn_target(hit); }
}

// ----------------------------- GUI callbacks -----------------------------

void on_sens_change(int64 widget)  { g_sens_mult = g_sens_slider.get(); }
void on_invx_change(int64 widget)  { if (g_invert_x.get()) g_inv_x = 1; else g_inv_x = 0; }
void on_invy_change(int64 widget)  { if (g_invert_y.get()) g_inv_y = 1; else g_inv_y = 0; }
void on_moving_change(int64 w)     {
    if (g_moving_cb.get()) g_moving = 1; else g_moving = 0;
    g_t_prev_update = time_ms();
}
void on_style_change(int64 w)      { g_target_style = g_style_opts.get(); }
void on_restart_click(int64 widget) {
    g_state = 0; g_yaw = 0.0; g_pitch = 0.0;
}

void update_input(int64 now) {
    vec2 d = get_mouse_delta();
    float64 sx = -1.0;
    if (g_inv_x == 1) sx =  1.0;
    float64 sy = -1.0;
    if (g_inv_y == 1) sy =  1.0;
    float64 step = g_sens_base * g_sens_mult;
    g_yaw   = g_yaw   + d.x * step * sx;
    g_pitch = g_pitch + d.y * step * sy;
    if (g_pitch >  1.45) g_pitch =  1.45;
    if (g_pitch < -1.45) g_pitch = -1.45;
    if (key_singlepress(vk::lbutton)) on_click();
    if (g_state == 2 && key_singlepress(vk::r)) {
        g_state = 0; g_yaw = 0.0; g_pitch = 0.0;
    }
}

// ----------------------------- background shader pass -----------------------------

void render_background() {
    float32[] verts;
    verts.push(-1.0f); verts.push(-1.0f); verts.push(0.0f); verts.push(0.0f);
    verts.push( 1.0f); verts.push(-1.0f); verts.push(1.0f); verts.push(0.0f);
    verts.push(-1.0f); verts.push( 1.0f); verts.push(0.0f); verts.push(1.0f);
    verts.push( 1.0f); verts.push( 1.0f); verts.push(1.0f); verts.push(1.0f);

    float64 vw = get_view_width();
    float64 vh = get_view_height();
    float64 aspect = vw / vh;
    float64 t_sec  = cast<float64>(time_ms() - g_t_app_start) * 0.001;

    vec3 f = cam_forward();
    vec3 r = cam_right();
    vec3 u = cam_up();

    float32[] cb_data;
    cb_data.push(cast<float32>(vw));
    cb_data.push(cast<float32>(vh));
    cb_data.push(cast<float32>(aspect));
    cb_data.push(cast<float32>(g_tan_half));
    cb_data.push(cast<float32>(r.x)); cb_data.push(cast<float32>(r.y)); cb_data.push(cast<float32>(r.z)); cb_data.push(0.0f);
    cb_data.push(cast<float32>(u.x)); cb_data.push(cast<float32>(u.y)); cb_data.push(cast<float32>(u.z)); cb_data.push(0.0f);
    cb_data.push(cast<float32>(f.x)); cb_data.push(cast<float32>(f.y)); cb_data.push(cast<float32>(f.z));
    cb_data.push(cast<float32>(t_sec));

    custom_draw(g_shader, g_vb, verts, 4, 1, 0, 0, 0, 0, g_cb, cb_data, 0);
    custom_restore_state();
}

// ----------------------------- target drawing -----------------------------

void draw_bullseye_at(float64 sx, float64 sy, float64 sr) {
    color outer = color( 30,  20,  20, 255);
    color red   = color(220,  60,  60, 255);
    color white = color(245, 235, 230, 255);
    color black = color( 25,  20,  20, 255);
    draw_circle(vec2(sx, sy), sr,        red,   0.0, true);
    draw_circle(vec2(sx, sy), sr * 0.75, white, 0.0, true);
    draw_circle(vec2(sx, sy), sr * 0.50, red,   0.0, true);
    draw_circle(vec2(sx, sy), sr * 0.25, white, 0.0, true);
    draw_circle(vec2(sx, sy), sr * 0.10, black, 0.0, true);
    draw_circle(vec2(sx, sy), sr,        outer, 2.5, false);
}

void draw_dummy_at(float64 sx, float64 sy, float64 sr) {
    // Anchor the figure so the projection point lies roughly at the chest.
    color skin     = color(180, 165, 145, 255);
    color body     = color(110, 110, 120, 255);
    color body_dk  = color( 70,  70,  80, 255);
    color outline  = color( 25,  25,  30, 255);
    color chest    = color(220,  70,  70, 255);

    float64 head_r  = sr * 0.30;
    float64 head_cy = sy - sr * 0.95;

    float64 body_w  = sr * 0.95;
    float64 body_h  = sr * 1.55;
    float64 body_x  = sx - body_w * 0.5;
    float64 body_y  = sy - sr * 0.50;
    float64 body_rd = sr * 0.18;

    // Shoulders -- a slightly wider band at the top of the torso for shape.
    float64 sh_w = sr * 1.20;
    float64 sh_h = sr * 0.30;
    float64 sh_x = sx - sh_w * 0.5;
    float64 sh_y = body_y;

    // Body + outline
    draw_rect_filled(vec2(body_x, body_y), vec2(body_w, body_h), body, body_rd, 15);
    draw_rect_filled(vec2(sh_x,   sh_y),   vec2(sh_w,   sh_h),   body, body_rd, 15);
    draw_rect_filled(vec2(body_x, body_y + body_h * 0.55), vec2(body_w, body_h * 0.45), body_dk, body_rd, 12);
    draw_rect(vec2(body_x, body_y), vec2(body_w, body_h), outline, 2.0, body_rd, 15);

    // Head
    draw_circle(vec2(sx, head_cy), head_r,         skin,    0.0, true);
    draw_circle(vec2(sx, head_cy), head_r,         outline, 2.0, false);

    // Chest marker (the actual scoring spot)
    draw_circle(vec2(sx, sy),       sr * 0.13,     chest,   0.0, true);
    draw_circle(vec2(sx, sy),       sr * 0.13,     outline, 1.5, false);
}

void draw_target_at(float64 sx, float64 sy, float64 sr) {
    if (g_target_style == 0) draw_bullseye_at(sx, sy, sr);
    else                     draw_dummy_at(sx, sy, sr);
}

void draw_targets() {
    int64[] order;
    int64 i = 0;
    while (i < NUM_TARGETS) {
        if (g_target_alive.get(i) == 1 && g_target_visible.get(i) == 1) order.push(i);
        i = i + 1;
    }
    int64 a = 0;
    while (a < order.length()) {
        int64 b = a + 1;
        while (b < order.length()) {
            if (g_target_vz.get(order.get(a)) < g_target_vz.get(order.get(b))) {
                int64 tmp = order.get(a);
                order.set(a, order.get(b));
                order.set(b, tmp);
            }
            b = b + 1;
        }
        a = a + 1;
    }
    int64 j = 0;
    while (j < order.length()) {
        int64 idx = order.get(j);
        draw_target_at(g_target_sx.get(idx), g_target_sy.get(idx), g_target_sr.get(idx));
        j = j + 1;
    }
}

void draw_crosshair() {
    float64 cx = get_view_width()  * 0.5;
    float64 cy = get_view_height() * 0.5;
    color cc = color(60, 255, 130, 230);
    color cd = color( 0,   0,   0, 200);
    float64 gap = 4.0;
    float64 arm = 10.0;
    draw_line(vec2(cx - arm - gap + 1.0, cy + 1.0), vec2(cx - gap + 1.0, cy + 1.0), cd, 3.0);
    draw_line(vec2(cx + gap + 1.0, cy + 1.0),       vec2(cx + arm + gap + 1.0, cy + 1.0), cd, 3.0);
    draw_line(vec2(cx + 1.0, cy - arm - gap + 1.0), vec2(cx + 1.0, cy - gap + 1.0), cd, 3.0);
    draw_line(vec2(cx + 1.0, cy + gap + 1.0),       vec2(cx + 1.0, cy + arm + gap + 1.0), cd, 3.0);
    draw_line(vec2(cx - arm - gap, cy), vec2(cx - gap, cy), cc, 2.0);
    draw_line(vec2(cx + gap, cy),       vec2(cx + arm + gap, cy), cc, 2.0);
    draw_line(vec2(cx, cy - arm - gap), vec2(cx, cy - gap), cc, 2.0);
    draw_line(vec2(cx, cy + gap),       vec2(cx, cy + arm + gap), cc, 2.0);
    draw_circle(vec2(cx, cy), 1.6, cc, 0.0, true);
}

void draw_hud(int64 now) {
    color white = color(245, 245, 250, 255);
    color dim   = color(180, 190, 200, 220);
    color none  = color(  0,   0,   0,   0);
    color shadow= color(  0,   0,   0, 180);
    int64 font  = get_font20();
    float64 vw = get_view_width();
    float64 vh = get_view_height();
    if (g_state == 0) {
        draw_rect_filled(vec2(vw * 0.5 - 220.0, vh * 0.5 + 60.0), vec2(440.0, 64.0), color(0, 0, 0, 160), 8.0, 15);
        draw_text("CLICK TO START", vec2(vw * 0.5 - 90.0, vh * 0.5 + 76.0), white, font, 1, shadow, 1.5);
        draw_text("30 second session  |  use the sidebar to tune",
                  vec2(vw * 0.5 - 200.0, vh * 0.5 + 100.0), dim, font, 0, none, 0.0);
        return;
    }
    draw_text("SCORE", vec2(28.0, 22.0), dim, font, 0, none, 0.0);
    draw_text(int_to_str(g_hits), vec2(28.0, 44.0), white, font, 1, shadow, 1.5);
    draw_text("SHOTS " + int_to_str(g_shots), vec2(28.0, 76.0), dim, font, 0, none, 0.0);
    int64 acc = 0;
    if (g_shots > 0) acc = (g_hits * 100) / g_shots;
    draw_text("ACC " + int_to_str(acc) + "%", vec2(28.0, 98.0), dim, font, 0, none, 0.0);
    int64 elapsed = 0;
    if (g_state == 1) elapsed = now - g_t_start;
    else if (g_state == 2) elapsed = g_t_end - g_t_start;
    int64 remain_ms = g_session_ms - elapsed;
    if (remain_ms < 0) remain_ms = 0;
    int64 secs = remain_ms / 1000;
    int64 tenths = (remain_ms / 100) % 10;
    string tstr = int_to_str(secs) + "." + int_to_str(tenths) + "s";
    draw_text("TIME",  vec2(vw - 110.0, 22.0), dim, font, 0, none, 0.0);
    draw_text(tstr,    vec2(vw - 110.0, 44.0), white, font, 1, shadow, 1.5);
    if (g_state == 2) {
        float64 px = vw * 0.5 - 200.0;
        float64 py = vh * 0.5 - 90.0;
        draw_rect_filled(vec2(px - 12.0, py - 12.0), vec2(424.0, 220.0), color(0, 0, 0, 200), 12.0, 15);
        draw_text("SESSION COMPLETE", vec2(px, py), white, font, 1, shadow, 1.5);
        draw_text("HITS     " + int_to_str(g_hits),  vec2(px, py + 40.0), white, font, 0, none, 0.0);
        draw_text("SHOTS    " + int_to_str(g_shots), vec2(px, py + 64.0), white, font, 0, none, 0.0);
        draw_text("ACCURACY " + int_to_str(acc) + "%", vec2(px, py + 88.0), white, font, 0, none, 0.0);
        draw_text("Press R to restart", vec2(px, py + 140.0), dim, font, 0, none, 0.0);
    }
}

// ----------------------------- routine + main -----------------------------

void render(int64 data) {
    int64 now = time_ms();
    update_input(now);
    if (g_state == 1 && now - g_t_start >= g_session_ms) end_session();
    integrate_targets(now);
    compute_target_screen();
    render_background();
    if (g_state == 1) draw_targets();
    draw_crosshair();
    draw_hud(now);
}

int64 main() {
    g_rng_state    = time_ms();
    if (g_rng_state == 0) g_rng_state = 1;
    g_t_app_start  = time_ms();
    g_t_prev_update = g_t_app_start;
    g_tan_half     = tan(40.0 * 3.14159265 / 180.0);   // 80 deg vertical FOV
    alloc_target_arrays();

    string vs =
        "struct VSIn { float2 pos : POSITION; float2 uv : COLOR; };\n" +
        "struct PSIn { float4 pos : SV_POSITION; float2 uv : TEXCOORD0; };\n" +
        "PSIn main(VSIn i) {\n" +
        "    PSIn o;\n" +
        "    o.pos = float4(i.pos, 0.0, 1.0);\n" +
        "    o.uv  = i.uv;\n" +
        "    return o;\n" +
        "}\n";

    string ps =
        "cbuffer CB : register(b0) {\n" +
        "    float4 iResAspectFov;\n" +
        "    float4 iCamRight;\n" +
        "    float4 iCamUp;\n" +
        "    float4 iCamFwd;        // w = time\n" +
        "};\n" +
        "struct PSIn { float4 pos : SV_POSITION; float2 uv : TEXCOORD0; };\n" +
        "\n" +
        "float hash21(float2 p) {\n" +
        "    p = frac(p * float2(127.1, 311.7));\n" +
        "    p += dot(p, p + 33.33);\n" +
        "    return frac(p.x * p.y);\n" +
        "}\n" +
        "float vnoise(float2 p) {\n" +
        "    float2 ip = floor(p);\n" +
        "    float2 fp = frac(p);\n" +
        "    float a = hash21(ip);\n" +
        "    float b = hash21(ip + float2(1.0, 0.0));\n" +
        "    float c = hash21(ip + float2(0.0, 1.0));\n" +
        "    float d = hash21(ip + float2(1.0, 1.0));\n" +
        "    float2 u = fp * fp * (3.0 - 2.0 * fp);\n" +
        "    return lerp(lerp(a, b, u.x), lerp(c, d, u.x), u.y);\n" +
        "}\n" +
        "float fbm(float2 p, float t) {\n" +
        "    float v = 0.0;\n" +
        "    float a = 0.5;\n" +
        "    [unroll] for (int i = 0; i < 5; i++) {\n" +
        "        // Each octave drifts at a slightly different rate so the\n" +
        "        // pattern evolves over time instead of just translating.\n" +
        "        v += a * vnoise(p + float2(t * (0.015 + 0.008 * float(i)),\n" +
        "                                   t * (0.011 + 0.006 * float(i))));\n" +
        "        p *= 2.05;\n" +
        "        a *= 0.55;\n" +
        "    }\n" +
        "    return v;\n" +
        "}\n" +
        "\n" +
        "float4 main(PSIn i) : SV_TARGET {\n" +
        "    float2 ndc = (i.uv - 0.5) * 2.0;\n" +
        "    float scale  = iResAspectFov.w;\n" +
        "    float aspect = iResAspectFov.z;\n" +
        "    float3 ray = normalize(iCamFwd.xyz\n" +
        "                         + iCamRight.xyz * ndc.x * aspect * scale\n" +
        "                         + iCamUp.xyz    * ndc.y * scale);\n" +
        "    float3 sun_dir = normalize(float3(0.45, 0.65, 0.55));\n" +
        "    float t = iCamFwd.w;\n" +
        "    float3 col;\n" +
        "    if (ray.y > 0.0) {\n" +
        "        // ---- sky base ----\n" +
        "        float h = saturate(ray.y);\n" +
        "        float3 sky_horizon = float3(0.85, 0.92, 0.97);\n" +
        "        float3 sky_zenith  = float3(0.18, 0.40, 0.72);\n" +
        "        col = lerp(sky_horizon, sky_zenith, pow(h, 0.55));\n" +
        "        // ---- procedural clouds on a virtual plane above ----\n" +
        "        float2 cuv  = ray.xz / max(ray.y, 0.05);\n" +
        "        float  base = fbm(cuv * 0.30, t);\n" +
        "        float  detail = fbm(cuv * 1.20 + 17.3, t * 1.4);\n" +
        "        float density = base * 0.7 + detail * 0.45;\n" +
        "        density = smoothstep(0.55, 0.88, density);\n" +
        "        // fade clouds to nothing near horizon to avoid haze stripe\n" +
        "        density *= smoothstep(0.02, 0.22, ray.y);\n" +
        "        // sun-lit edges -- brighter on the side facing the sun.\n" +
        "        float sun_align = saturate(dot(ray, sun_dir) * 0.5 + 0.5);\n" +
        "        float3 cloud_dark = float3(0.55, 0.58, 0.65);\n" +
        "        float3 cloud_lit  = float3(1.00, 0.98, 0.94);\n" +
        "        float3 cloud_col  = lerp(cloud_dark, cloud_lit, pow(sun_align, 1.4));\n" +
        "        col = lerp(col, cloud_col, density);\n" +
        "        // ---- sun disc + halo ----\n" +
        "        float sd = dot(ray, sun_dir);\n" +
        "        float disc = smoothstep(0.9994, 0.9999, sd);\n" +
        "        float halo = pow(saturate(sd), 90.0);\n" +
        "        col += disc * float3(1.6, 1.5, 1.3);\n" +
        "        col += halo * float3(1.0, 0.85, 0.65) * 0.45;\n" +
        "    } else {\n" +
        "        // ---- ground plane at y = -1 ----\n" +
        "        float gt = -1.0 / min(ray.y, -0.0001);\n" +
        "        float2 gpos = float2(ray.x, ray.z) * gt;\n" +
        "        float3 ground_dark  = float3(0.18, 0.16, 0.14);\n" +
        "        float3 ground_light = float3(0.34, 0.30, 0.24);\n" +
        "        float2 gd = abs(frac(gpos + 0.5) - 0.5);\n" +
        "        float  gridv = min(gd.x, gd.y);\n" +
        "        float  fw   = max(fwidth(gridv), 0.001);\n" +
        "        float  gmsk = 1.0 - smoothstep(0.0, fw * 1.5, gridv);\n" +
        "        float3 g_col = lerp(ground_dark, ground_light, gmsk * 0.7);\n" +
        "        float fog = 1.0 - exp(-gt * 0.04);\n" +
        "        col = lerp(g_col, float3(0.62, 0.66, 0.74), saturate(fog));\n" +
        "    }\n" +
        "    // horizon glow\n" +
        "    float horizon_pow = exp(-abs(ray.y) * 8.0);\n" +
        "    col += float3(1.0, 0.85, 0.55) * horizon_pow * 0.08;\n" +
        "    // gentle vignette\n" +
        "    float2 vc = (i.uv - 0.5) * 2.0;\n" +
        "    float  vig = 1.0 - dot(vc, vc) * 0.18;\n" +
        "    col *= saturate(vig);\n" +
        "    return float4(col, 1.0);\n" +
        "}\n";

    g_shader = create_shader(vs, ps, "POSITION:0:FLOAT2, COLOR:0:FLOAT2");
    if (g_shader == 0) { println("[aim] create_shader failed"); return 0; }
    g_vb = create_vertex_buffer(16, 4, true);
    g_cb = create_constant_buffer(64);

    // ----- sidebar GUI -----
    sidebar_section_t sec = create_sidebar_section("Aim Trainer", "");

    g_sens_slider = sec.create_slider("Sensitivity", 1.0, 0.1, 5.0, 0.05);
    g_sens_slider.set_tooltip("Mouse sensitivity multiplier (1.0 = base rate)");
    g_sens_slider.on_change(cast<int64>(on_sens_change));
    g_sens_mult = g_sens_slider.get();

    g_invert_x = sec.create_checkbox("Invert X", false);
    g_invert_x.on_change(cast<int64>(on_invx_change));
    g_invert_y = sec.create_checkbox("Invert Y", false);
    g_invert_y.on_change(cast<int64>(on_invy_change));

    sec.create_separator();

    g_moving_cb = sec.create_checkbox("Moving targets", false);
    g_moving_cb.set_tooltip("Targets bounce inside the spawn volume");
    g_moving_cb.on_change(cast<int64>(on_moving_change));

    array<string> styles;
    styles.push("Bullseye");
    styles.push("Dummy");
    g_style_opts = sec.create_options("Target style", styles, 0);
    g_style_opts.on_change(cast<int64>(on_style_change));

    sec.create_separator();

    button_t restart_btn = sec.create_button("Restart session", ui_align::center);
    restart_btn.on_change(cast<int64>(on_restart_click));

    register_routine(cast<int64>(render), 0);
    println("[aim] running -- click to start, R to restart after the timer");
    return 1;
}
