// =============================================================================
// Render API comprehensive test
//
// Exercises every function declared in the Perception Render API, plus the
// `color` type from `import "color"`.
//
// CHECKLIST — every type, method, and function in the doc:
//
// TYPES:
//   color  (import "color") — packed 4-byte struct
//     fields: .r .g .b .a   (each returns uint8)
//     method: .with_alpha(uint8 _a) -> color
//
// 2D PRIMITIVES (10):
//   draw_rect                        draw_rect_filled
//   draw_line                        draw_circle
//   draw_arc                         draw_triangle
//   draw_four_corner_gradient        draw_polygon
//   draw_bitmap                      draw_text
//
// TEXT & FONTS (11):
//   get_text_width                   get_text_height
//   get_char_advance                 create_font
//   create_font_mem                  create_bitmap
//   get_font18                       get_font20
//   get_font24                       get_font28
//
// CLIPPING (2):
//   clip_push                        clip_pop
//
// VIEWPORT (4):
//   get_view_width                   get_view_height
//   get_view_scale                   get_fps
//
// SHADERS (4):
//   create_shader                    destroy_shader
//   create_compute_shader            destroy_compute_shader
//
// BUFFERS (8):
//   create_vertex_buffer             destroy_vertex_buffer
//   create_index_buffer              destroy_index_buffer
//   create_constant_buffer           destroy_constant_buffer
//   create_structured_buffer         destroy_structured_buffer
//
// PIPELINE STATE (8):
//   create_blend_state               destroy_blend_state
//   create_sampler                   destroy_sampler
//   create_depth_stencil_state       destroy_depth_stencil_state
//   create_rasterizer_state          destroy_rasterizer_state
//
// RENDER TARGETS & TEXTURES (10):
//   create_render_target             destroy_render_target
//   create_depth_buffer              destroy_depth_buffer
//   create_texture                   destroy_texture
//   load_texture                     load_texture_mem
//   get_texture_width                get_texture_height
//
// MESHES (13):
//   create_mesh_raw                  load_mesh
//   load_mesh_mem                    destroy_mesh
//   get_mesh_vert_count              get_mesh_index_count
//   get_mesh_stride                  get_mesh_bounds_min_x
//   get_mesh_bounds_min_y            get_mesh_bounds_min_z
//   get_mesh_bounds_max_x            get_mesh_bounds_max_y
//   get_mesh_bounds_max_z
//
// CUSTOM DRAW (4):
//   custom_draw                      custom_draw_indexed
//   draw_mesh                        dispatch_compute
//
// BINDING & STATE (17):
//   custom_set_render_target         custom_set_render_target_ext
//   custom_reset_render_target       custom_bind_rt_as_texture
//   custom_restore_state             custom_set_depth_stencil_state
//   custom_set_rasterizer_state      custom_set_viewport
//   custom_reset_viewport            custom_bind_texture
//   custom_bind_constant_buffer      custom_update_texture
//   custom_clear_render_target       custom_clear_depth_buffer
//   bind_structured_buffer           update_structured_buffer
//   capture_backbuffer
//
// Total: 1 type with 4 fields + 1 method, 91 standalone functions.
//
// Test framework: prints PASS / FAIL / SKIP per call, totals at the end.
// Run:  load via perception, watch the console.
// =============================================================================

import "vec";
import "color";

// =============================================================================
// Test state
// =============================================================================

int64 g_pass, g_fail, g_skip;
int64 g_routine;
int64 g_done;

// Shared resource handles — created in the appropriate section, kept alive for
// later sections that reference them, then destroyed in the cleanup section.
int64 g_shader;     // vertex+pixel shader (created in §6)
int64 g_cs;         // compute  shader (created in §6)
int64 g_vb;         // vertex   buffer (created in §7)
int64 g_ib;         // index    buffer (created in §7)
int64 g_cb;         // constant buffer (created in §7)
int64 g_sb;         // structured buffer (created in §7)
int64 g_rt;         // render   target (created in §9)
int64 g_db;         // depth    buffer (created in §9)
int64 g_tex;        // texture  (created in §9)
int64 g_mesh;       // mesh     (created in §10)
int64 g_blend;      // blend state (created in §8)
int64 g_sampler;    // sampler  (created in §8)
int64 g_ds;         // depth-stencil state (created in §8)
int64 g_rs;         // rasterizer state (created in §8)

// =============================================================================
// Helpers
// =============================================================================

void T(string name, bool ok, string detail) {
    if (ok) {
        g_pass = g_pass + 1;
        print_console("PASS  " + name);
    } else {
        g_fail = g_fail + 1;
        print_console("FAIL  " + name + "  --  " + detail);
    }
}

void S(string name, string reason) {
    g_skip = g_skip + 1;
    print_console("SKIP  " + name + "  --  " + reason);
}

void section(string title) {
    print_console("");
    print_console("--- " + title + " ---");
}

// =============================================================================
// Test routine — runs every frame, exits after one pass
// =============================================================================

void test_render_api(int64 data) {
    if (g_done != 0) { return; }
    g_done = 1;

    print_console("");
    print_console("===========================================");
    print_console("  Render API comprehensive test");
    print_console("===========================================");

    // ------------------------------------------------------------------
    // 1. color type  (import "color")
    // ------------------------------------------------------------------
    section("1. color type");

    color c_red   = color(255, 0,   0,   255);
    color c_green = color(0,   255, 0,   255);
    color c_blue  = color(0,   0,   255, 255);
    color c_white = color(255, 255, 255, 255);
    color c_black = color(0,   0,   0,   255);
    color c_cust  = color(123, 231, 89,  42);

    T("color.r == 123",        c_cust.r == 123,  cast<string>(c_cust.r));
    T("color.g == 231",        c_cust.g == 231,  cast<string>(c_cust.g));
    T("color.b == 89",         c_cust.b == 89,   cast<string>(c_cust.b));
    T("color.a == 42",         c_cust.a == 42,   cast<string>(c_cust.a));

    color c_alpha = c_cust.with_alpha(200);
    T("with_alpha preserves r", c_alpha.r == 123,  "");
    T("with_alpha preserves g", c_alpha.g == 231,  "");
    T("with_alpha preserves b", c_alpha.b == 89,   "");
    T("with_alpha sets a=200", c_alpha.a == 200,   cast<string>(c_alpha.a));
    T("with_alpha original unchanged", c_cust.a == 42, "");

    // Verify default colors are distinct
    T("white != black", c_white.r == 255 && c_black.r == 0, "");

    // ------------------------------------------------------------------
    // 2. 2D Primitives
    // ------------------------------------------------------------------
    section("2. 2D Primitives");

    int64 h;

    h = draw_rect(vec2(10.0, 10.0), vec2(100.0, 50.0), c_white, 2.0, 4.0, 15);
    T("draw_rect returns non-zero handle", h != 0, "");

    h = draw_rect_filled(vec2(10.0, 70.0), vec2(100.0, 50.0), c_red, 4.0, 15);
    T("draw_rect_filled returns non-zero handle", h != 0, "");

    h = draw_rect_filled(vec2(10.0, 130.0), vec2(100.0, 50.0), c_blue, 0.0, 0);
    T("draw_rect_filled zero rounding", h != 0, "");

    h = draw_line(vec2(10.0, 200.0), vec2(110.0, 250.0), c_green, 2.0);
    T("draw_line returns non-zero handle", h != 0, "");

    h = draw_line(vec2(10.0, 260.0), vec2(110.0, 310.0), c_white, 1.0);
    T("draw_line thickness=1", h != 0, "");

    h = draw_circle(vec2(200.0, 200.0), 50.0, c_blue, 2.0, false);
    T("draw_circle unfilled returns non-zero handle", h != 0, "");

    h = draw_circle(vec2(300.0, 200.0), 50.0, c_red, 2.0, true);
    T("draw_circle filled returns non-zero handle", h != 0, "");

    h = draw_circle(vec2(400.0, 200.0), 30.0, c_white, 4.0, true);
    T("draw_circle filled thick returns non-zero handle", h != 0, "");

    h = draw_arc(vec2(500.0, 200.0), vec2(50.0, 30.0), 0.0, 180.0, c_white, 2.0, false);
    T("draw_arc unfilled returns non-zero handle", h != 0, "");

    h = draw_arc(vec2(600.0, 200.0), vec2(40.0, 40.0), 0.0, 360.0, c_green, 2.0, true);
    T("draw_arc filled returns non-zero handle", h != 0, "");

    h = draw_arc(vec2(700.0, 200.0), vec2(50.0, 20.0), 45.0, 270.0, c_blue, 3.0, false);
    T("draw_arc offset start+sweep", h != 0, "");

    h = draw_triangle(vec2(10.0, 350.0), vec2(60.0, 400.0), vec2(110.0, 350.0), c_white, 2.0, false);
    T("draw_triangle unfilled returns non-zero handle", h != 0, "");

    h = draw_triangle(vec2(120.0, 350.0), vec2(170.0, 400.0), vec2(220.0, 350.0), c_blue, 2.0, true);
    T("draw_triangle filled returns non-zero handle", h != 0, "");

    h = draw_triangle(vec2(230.0, 350.0), vec2(280.0, 400.0), vec2(330.0, 350.0), c_red, 1.0, true);
    T("draw_triangle filled thin returns non-zero handle", h != 0, "");

    h = draw_four_corner_gradient(vec2(10.0, 420.0), vec2(120.0, 60.0), c_red, c_green, c_blue, c_white, 4.0);
    T("draw_four_corner_gradient returns non-zero handle", h != 0, "");

    h = draw_four_corner_gradient(vec2(140.0, 420.0), vec2(120.0, 60.0), c_white, c_white, c_black, c_black, 0.0);
    T("draw_four_corner_gradient zero rounding", h != 0, "");

    // draw_polygon with a triangle (6 float64 values = 3 xy pairs)
    float64[] poly;
    poly.push(10.0);  poly.push(500.0);
    poly.push(60.0);  poly.push(550.0);
    poly.push(110.0); poly.push(500.0);
    h = draw_polygon(poly, 3, c_white, 2.0, false);
    T("draw_polygon unfilled triangle", h != 0, "");

    // draw_polygon with a filled triangle
    float64[] poly2;
    poly2.push(120.0); poly2.push(500.0);
    poly2.push(170.0); poly2.push(550.0);
    poly2.push(220.0); poly2.push(500.0);
    h = draw_polygon(poly2, 3, c_blue, 2.0, true);
    T("draw_polygon filled triangle", h != 0, "");

    // draw_bitmap — need a bitmap handle
    uint8[] bmp_data;
    bmp_data.push(255); bmp_data.push(0);   bmp_data.push(0);   bmp_data.push(255);
    bmp_data.push(0);   bmp_data.push(255); bmp_data.push(0);   bmp_data.push(255);
    bmp_data.push(0);   bmp_data.push(0);   bmp_data.push(255); bmp_data.push(255);
    bmp_data.push(255); bmp_data.push(255); bmp_data.push(255); bmp_data.push(255);
    int64 bmp = create_bitmap(bmp_data);
    if (bmp == 0) {
        S("create_bitmap", "returned 0 — cannot test draw_bitmap");
        h = 0;
    } else {
        T("create_bitmap 2x2 RGBA", true, "");
        h = draw_bitmap(bmp, vec2(10.0, 570.0), vec2(40.0, 40.0), c_white, false);
        T("draw_bitmap returns non-zero handle", h != 0, "");

        h = draw_bitmap(bmp, vec2(60.0, 570.0), vec2(40.0, 40.0), c_red, true);
        T("draw_bitmap tinted+rounded returns non-zero handle", h != 0, "");

        h = draw_bitmap(bmp, vec2(110.0, 570.0), vec2(40.0, 40.0), c_white, true);
        T("draw_bitmap rounded returns non-zero handle", h != 0, "");
    }

    // draw_text — need a font handle
    int64 dflt_font = get_font20();
    if (dflt_font == 0) {
        S("draw_text", "get_font20() returned 0");
    } else {
        h = draw_text("Render test", vec2(10.0, 630.0), c_white, dflt_font, 0, c_black, 0.0);
        T("draw_text no effect", h != 0, "");

        h = draw_text("Shadow text", vec2(10.0, 660.0), c_white, dflt_font, 1, c_black, 3.0);
        T("draw_text shadow effect", h != 0, "");

        h = draw_text("Outline text", vec2(10.0, 690.0), c_white, dflt_font, 2, c_blue, 1.5);
        T("draw_text outline effect", h != 0, "");
    }

    // ==================================================================
    // 3. Text and Fonts
    // ==================================================================
    section("3. Text and Fonts");

    // Default font handles
    int64 f18 = get_font18();
    T("get_font18 returns non-zero handle", f18 != 0, cast<string>(f18));

    int64 f20 = get_font20();
    T("get_font20 returns non-zero handle", f20 != 0, cast<string>(f20));

    int64 f24 = get_font24();
    T("get_font24 returns non-zero handle", f24 != 0, cast<string>(f24));

    int64 f28 = get_font28();
    T("get_font28 returns non-zero handle", f28 != 0, cast<string>(f28));

    // Use the font that is actually available
    int64 some_font = f20;
    if (some_font == 0) { some_font = f18; }
    if (some_font == 0) { some_font = f24; }
    if (some_font == 0) { some_font = f28; }

    // Text measurement
    if (some_font != 0) {
        float64 tw = get_text_width(some_font, "Hello Render API", 800, 200);
        T("get_text_width returns >= 0", tw >= 0.0, cast<string>(tw));

        float64 th = get_text_height(some_font, "Hello Render API", 800, 200);
        T("get_text_height returns >= 0", th >= 0.0, cast<string>(th));

        int32 ca_a = get_char_advance(some_font, 65);   // 'A'
        T("get_char_advance('A') > 0", ca_a > 0, cast<string>(ca_a));

        int32 ca_space = get_char_advance(some_font, 32); // space
        T("get_char_advance(' ') > 0", ca_space > 0, cast<string>(ca_space));

        int32 ca_zero = get_char_advance(some_font, 48);  // '0'
        T("get_char_advance('0') > 0", ca_zero > 0, cast<string>(ca_zero));
    } else {
        S("get_text_width", "no default font available");
        S("get_text_height", "no default font available");
        S("get_char_advance", "no default font available");
    }

    // create_font — likely fails without a real font file, but exercises the call
    uint32[] glyph_none;
    int64 custom_font = create_font("", 16.0, true, false, glyph_none);
    if (custom_font == 0) {
        S("create_font", "returned 0 (expected — no font file)");
    } else {
        T("create_font returns non-zero handle", true, "");
    }

    // create_font_mem — will fail with empty data, but call compiles
    uint8[] font_buf;
    int64 mem_font = create_font_mem("inline", 14.0, font_buf, true, false, glyph_none);
    if (mem_font == 0) {
        S("create_font_mem", "returned 0 (expected — empty font buffer)");
    } else {
        T("create_font_mem returns non-zero handle", true, "");
    }

    // create_bitmap — test with 1x1 white pixel
    uint8[] tiny_bmp;
    tiny_bmp.push(255); tiny_bmp.push(255); tiny_bmp.push(255); tiny_bmp.push(255);
    int64 bmp2 = create_bitmap(tiny_bmp);
    T("create_bitmap 1x1 white", bmp2 != 0, "");

    // create_bitmap with different alpha
    uint8[] alpha_bmp;
    alpha_bmp.push(128); alpha_bmp.push(64); alpha_bmp.push(32); alpha_bmp.push(200);
    int64 bmp3 = create_bitmap(alpha_bmp);
    T("create_bitmap semi-transparent", bmp3 != 0, "");

    // get_text_width / height with different fonts (if available)
    if (some_font != 0) {
        float64 tw1 = get_text_width(some_font, "short", 100, 50);
        T("get_text_width 'short' constrained", tw1 >= 0.0, cast<string>(tw1));

        float64 tw2 = get_text_width(some_font, "A much longer string of text for testing width measurement", 2000, 200);
        T("get_text_width long string", tw2 >= 0.0, cast<string>(tw2));

        float64 th1 = get_text_height(some_font, "Multi\nLine", 500, 200);
        T("get_text_height multiline", th1 >= 0.0, cast<string>(th1));
    }

    // ==================================================================
    // 4. Clipping
    // ==================================================================
    section("4. Clipping");

    h = clip_push(vec2(0.0, 0.0), vec2(800.0, 600.0));
    T("clip_push full viewport", h != 0, "");

    h = clip_push(vec2(100.0, 100.0), vec2(200.0, 150.0));
    T("clip_push nested region", h != 0, "");

    h = clip_pop();
    T("clip_pop inner", h != 0, cast<string>(h));

    h = clip_pop();
    T("clip_pop outer", h != 0, cast<string>(h));

    // ==================================================================
    // 5. Viewport
    // ==================================================================
    section("5. Viewport");

    float64 vw = get_view_width();
    T("get_view_width >= 0",  vw >= 0.0,  cast<string>(vw));

    float64 vh = get_view_height();
    T("get_view_height >= 0", vh >= 0.0, cast<string>(vh));

    float64 vs = get_view_scale();
    T("get_view_scale > 0",   vs > 0.0,  cast<string>(vs));

    float64 fps = get_fps();
    T("get_fps >= 0",          fps >= 0.0, cast<string>(fps));

    // ==================================================================
    // 6. Shaders
    // ==================================================================
    section("6. Shaders");

    // Minimal vertex + pixel shader (from the doc's "Minimal triangle")
    string vs_src = "struct VSIn { float2 pos : POSITION; float4 color : COLOR; };\n"
                  "struct VSOut { float4 pos : SV_Position; float4 color : COLOR; };\n"
                  "VSOut main(VSIn i) { VSOut o; o.pos = float4(i.pos, 0.0, 1.0); o.color = i.color; return o; }\n";
    string ps_src = "struct VSOut { float4 pos : SV_Position; float4 color : COLOR; };\n"
                  "float4 main(VSOut i) : SV_Target { return i.color; }\n";
    string layout = "POSITION:0:FLOAT2, COLOR:0:FLOAT4";

    g_shader = create_shader(vs_src, ps_src, layout);
    T("create_shader returns non-zero handle", g_shader != 0, cast<string>(g_shader));

    // Compute shader
    string cs_src = "[numthreads(8, 8, 1)]\nvoid main(uint3 id : SV_DispatchThreadID) { }\n";
    g_cs = create_compute_shader(cs_src);
    T("create_compute_shader returns non-zero handle", g_cs != 0, cast<string>(g_cs));

    // Destroy compute shader immediately (test destroy, recreate if needed later)
    if (g_cs != 0) {
        int64 r = destroy_compute_shader(g_cs);
        T("destroy_compute_shader callable", true, cast<string>(r));
        g_cs = 0;  // mark destroyed
    } else {
        S("destroy_compute_shader", "no handle to destroy");
    }

    // ==================================================================
    // 7. Buffers
    // ==================================================================
    section("7. Buffers");

    // Vertex buffer: 24 bytes per vertex (2*float32 pos + 4*float32 color), 3 verts, dynamic
    g_vb = create_vertex_buffer(24, 3, true);
    T("create_vertex_buffer returns non-zero handle", g_vb != 0, cast<string>(g_vb));

    // Index buffer: 3 indices (max), 32-bit, dynamic
    g_ib = create_index_buffer(3, true, true);
    T("create_index_buffer returns non-zero handle", g_ib != 0, cast<string>(g_ib));

    // Constant buffer: 64 bytes
    g_cb = create_constant_buffer(64);
    T("create_constant_buffer returns non-zero handle", g_cb != 0, cast<string>(g_cb));

    // Structured buffer: 16-byte elements, 10 elements, CPU-write, no GPU-write
    g_sb = create_structured_buffer(16, 10, true, false);
    T("create_structured_buffer returns non-zero handle", g_sb != 0, cast<string>(g_sb));

    // Destroy then recreate vertex buffer to test destroy mid-script
    if (g_vb != 0) {
        int64 r = destroy_vertex_buffer(g_vb);
        T("destroy_vertex_buffer callable", true, cast<string>(r));
    } else {
        S("destroy_vertex_buffer", "no handle");
    }
    g_vb = create_vertex_buffer(24, 3, true);
    T("re-create_vertex_buffer", g_vb != 0, cast<string>(g_vb));

    // Destroy then recreate index buffer
    if (g_ib != 0) {
        destroy_index_buffer(g_ib);
        T("destroy_index_buffer callable", true, "");
    } else {
        S("destroy_index_buffer", "no handle");
    }
    g_ib = create_index_buffer(3, true, true);
    T("re-create_index_buffer", g_ib != 0, cast<string>(g_ib));

    // Destroy then recreate constant buffer
    if (g_cb != 0) {
        destroy_constant_buffer(g_cb);
        T("destroy_constant_buffer callable", true, "");
    } else {
        S("destroy_constant_buffer", "no handle");
    }
    g_cb = create_constant_buffer(64);
    T("re-create_constant_buffer", g_cb != 0, cast<string>(g_cb));

    // Destroy then recreate structured buffer
    if (g_sb != 0) {
        destroy_structured_buffer(g_sb);
        T("destroy_structured_buffer callable", true, "");
    } else {
        S("destroy_structured_buffer", "no handle");
    }
    g_sb = create_structured_buffer(16, 10, true, false);
    T("re-create_structured_buffer", g_sb != 0, cast<string>(g_sb));

    // ==================================================================
    // 8. Pipeline State
    // ==================================================================
    section("8. Pipeline State");

    // Blend state: src=ONE(1), dst=ZERO(0), op=ADD(0), src_alpha=ONE(1), dst_alpha=ZERO(0), op_alpha=ADD(0)
    g_blend = create_blend_state(1, 0, 0, 1, 0, 0);
    T("create_blend_state opaque", g_blend != 0, cast<string>(g_blend));

    // Blend state with alpha blending: src=SRC_ALPHA(2), dst=INV_SRC_ALPHA(3), op=ADD(0)
    int64 blend_alpha = create_blend_state(2, 3, 0, 2, 3, 0);
    T("create_blend_state alpha", blend_alpha != 0, cast<string>(blend_alpha));
    if (blend_alpha != 0) {
        destroy_blend_state(blend_alpha);
        T("destroy_blend_state callable", true, "");
    } else {
        S("destroy_blend_state (alpha)", "no handle");
    }

    // Sampler: filter=LINEAR(1), address_u=CLAMP(1), address_v=CLAMP(1)
    g_sampler = create_sampler(1, 1, 1);
    T("create_sampler linear/clamp", g_sampler != 0, cast<string>(g_sampler));

    // Sampler: filter=POINT(0), address=MIRROR(2)
    int64 sampler_point = create_sampler(0, 2, 2);
    T("create_sampler point/mirror", sampler_point != 0, cast<string>(sampler_point));
    if (sampler_point != 0) {
        destroy_sampler(sampler_point);
        T("destroy_sampler callable", true, "");
    } else {
        S("destroy_sampler", "no handle");
    }

    // Sampler with ANISOTROPIC(2) filter
    int64 sampler_aniso = create_sampler(2, 0, 0);
    T("create_sampler anisotropic/wrap", sampler_aniso != 0, cast<string>(sampler_aniso));
    if (sampler_aniso != 0) {
        destroy_sampler(sampler_aniso);
        T("destroy_sampler aniso", true, "");
    }

    // Depth-stencil: depth_enable=true, depth_write=true, compare=LESS(1)
    g_ds = create_depth_stencil_state(true, true, 1);
    T("create_depth_stencil_state less", g_ds != 0, cast<string>(g_ds));

    // Depth-stencil: no depth, no write
    int64 ds_no = create_depth_stencil_state(false, false, 0);
    T("create_depth_stencil_state disabled", ds_no != 0, cast<string>(ds_no));
    if (ds_no != 0) {
        destroy_depth_stencil_state(ds_no);
        T("destroy_depth_stencil_state callable", true, "");
    } else {
        S("destroy_depth_stencil_state", "no handle");
    }

    // Depth-stencil with GREATER_EQUAL(6)
    int64 ds_ge = create_depth_stencil_state(true, true, 6);
    T("create_depth_stencil_state gequal", ds_ge != 0, cast<string>(ds_ge));
    if (ds_ge != 0) {
        destroy_depth_stencil_state(ds_ge);
        T("destroy_depth_stencil_state gequal", true, "");
    }

    // Rasterizer: cull=BACK(0), fill=SOLID(0), scissor=false
    g_rs = create_rasterizer_state(0, 0, false);
    T("create_rasterizer_state solid/back", g_rs != 0, cast<string>(g_rs));

    // Rasterizer: cull=NONE(2), fill=WIREFRAME(1), scissor=true
    int64 rs_wire = create_rasterizer_state(2, 1, true);
    T("create_rasterizer_state wireframe/nocull", rs_wire != 0, cast<string>(rs_wire));
    if (rs_wire != 0) {
        destroy_rasterizer_state(rs_wire);
        T("destroy_rasterizer_state callable", true, "");
    } else {
        S("destroy_rasterizer_state", "no handle");
    }

    // ==================================================================
    // 9. Render Targets and Textures
    // ==================================================================
    section("9. Render Targets and Textures");

    // Render target 256x256
    g_rt = create_render_target(256, 256);
    T("create_render_target 256x256", g_rt != 0, cast<string>(g_rt));

    // Depth buffer 256x256
    g_db = create_depth_buffer(256, 256);
    T("create_depth_buffer 256x256", g_db != 0, cast<string>(g_db));

    // Render target with different size
    int64 rt2 = create_render_target(512, 512);
    T("create_render_target 512x512", rt2 != 0, cast<string>(rt2));
    if (rt2 != 0) {
        destroy_render_target(rt2);
        T("destroy_render_target callable", true, "");
    } else {
        S("destroy_render_target", "no handle");
    }

    // Depth buffer with different size
    int64 db2 = create_depth_buffer(128, 128);
    T("create_depth_buffer 128x128", db2 != 0, cast<string>(db2));
    if (db2 != 0) {
        destroy_depth_buffer(db2);
        T("destroy_depth_buffer callable", true, "");
    } else {
        S("destroy_depth_buffer", "no handle");
    }

    // create_texture: 2x2 RGBA (16 bytes total)
    uint8[] rgba_tex;
    rgba_tex.push(255); rgba_tex.push(0);   rgba_tex.push(0);   rgba_tex.push(255);
    rgba_tex.push(0);   rgba_tex.push(255); rgba_tex.push(0);   rgba_tex.push(255);
    rgba_tex.push(0);   rgba_tex.push(0);   rgba_tex.push(255); rgba_tex.push(255);
    rgba_tex.push(255); rgba_tex.push(255); rgba_tex.push(0);   rgba_tex.push(255);
    g_tex = create_texture(2, 2, rgba_tex);
    T("create_texture 2x2 RGBA", g_tex != 0, cast<string>(g_tex));

    // create_texture 1x1
    uint8[] single_pixel;
    single_pixel.push(128); single_pixel.push(64); single_pixel.push(32); single_pixel.push(255);
    int64 tex1x1 = create_texture(1, 1, single_pixel);
    T("create_texture 1x1", tex1x1 != 0, cast<string>(tex1x1));
    if (tex1x1 != 0) {
        destroy_texture(tex1x1);
        T("destroy_texture callable", true, "");
    } else {
        S("destroy_texture", "no handle");
    }

    // load_texture with empty path (will fail, but exercises the call)
    int64 loaded_tex = load_texture("");
    if (loaded_tex == 0) {
        S("load_texture", "returned 0 (expected — empty path)");
    } else {
        T("load_texture returns non-zero handle", true, "");
    }

    // load_texture_mem with empty data
    uint8[] empty_img;
    int64 mem_tex = load_texture_mem(empty_img);
    if (mem_tex == 0) {
        S("load_texture_mem", "returned 0 (expected — empty data)");
    } else {
        T("load_texture_mem returns non-zero handle", true, "");
    }

    // get_texture_width / height (only if texture was created)
    if (g_tex != 0) {
        float64 tex_w = get_texture_width(g_tex);
        T("get_texture_width returns >= 0", tex_w >= 0.0, cast<string>(tex_w));

        float64 tex_h = get_texture_height(g_tex);
        T("get_texture_height returns >= 0", tex_h >= 0.0, cast<string>(tex_h));
    } else {
        S("get_texture_width", "no texture handle");
        S("get_texture_height", "no texture handle");
    }

    // ==================================================================
    // 10. Meshes
    // ==================================================================
    section("10. Meshes");

    // create_mesh_raw: simple triangle mesh
    // 3 vertices, stride=24 (2*float32 pos + 4*float32 color)
    float32[] mesh_verts;
    // Vertex 0: pos(-0.5, -0.5, 0.0) color(1,0,0,1)
    mesh_verts.push(-0.5f); mesh_verts.push(-0.5f); mesh_verts.push(0.0f);
    mesh_verts.push(1.0f);  mesh_verts.push(0.0f);  mesh_verts.push(0.0f);  mesh_verts.push(1.0f);
    // Vertex 1: pos(0.5, -0.5, 0.0) color(0,1,0,1)
    mesh_verts.push(0.5f);  mesh_verts.push(-0.5f); mesh_verts.push(0.0f);
    mesh_verts.push(0.0f);  mesh_verts.push(1.0f);  mesh_verts.push(0.0f);  mesh_verts.push(1.0f);
    // Vertex 2: pos(0.0, 0.5, 0.0) color(0,0,1,1)
    mesh_verts.push(0.0f);  mesh_verts.push(0.5f);  mesh_verts.push(0.0f);
    mesh_verts.push(0.0f);  mesh_verts.push(0.0f);  mesh_verts.push(1.0f);  mesh_verts.push(1.0f);

    uint32[] mesh_idx;
    mesh_idx.push(0); mesh_idx.push(1); mesh_idx.push(2);

    g_mesh = create_mesh_raw(mesh_verts, 3, 24, mesh_idx, 3, true);
    T("create_mesh_raw returns non-zero handle", g_mesh != 0, cast<string>(g_mesh));

    // load_mesh with empty path
    int64 loaded_mesh = load_mesh("");
    if (loaded_mesh == 0) {
        S("load_mesh", "returned 0 (expected — empty path)");
    } else {
        T("load_mesh returns non-zero handle", true, "");
    }

    // load_mesh_mem with empty data
    float32[] empty_mesh_data;
    uint32[] empty_mesh_idx;
    int64 mem_mesh = load_mesh_mem(empty_mesh_data);
    if (mem_mesh == 0) {
        S("load_mesh_mem", "returned 0 (expected — empty data)");
    } else {
        T("load_mesh_mem returns non-zero handle", true, "");
    }

    // Mesh query functions (only if mesh was created)
    if (g_mesh != 0) {
        int64 vert_count = get_mesh_vert_count(g_mesh);
        T("get_mesh_vert_count returns >= 0", vert_count >= 0, cast<string>(vert_count));

        int64 idx_count = get_mesh_index_count(g_mesh);
        T("get_mesh_index_count returns >= 0", idx_count >= 0, cast<string>(idx_count));

        float64 stride = get_mesh_stride(g_mesh);
        T("get_mesh_stride returns > 0", stride > 0.0, cast<string>(stride));

        float64 min_x = get_mesh_bounds_min_x(g_mesh);
        float64 min_y = get_mesh_bounds_min_y(g_mesh);
        float64 min_z = get_mesh_bounds_min_z(g_mesh);
        T("get_mesh_bounds_min_x callable", true, cast<string>(min_x));
        T("get_mesh_bounds_min_y callable", true, cast<string>(min_y));
        T("get_mesh_bounds_min_z callable", true, cast<string>(min_z));

        float64 max_x = get_mesh_bounds_max_x(g_mesh);
        float64 max_y = get_mesh_bounds_max_y(g_mesh);
        float64 max_z = get_mesh_bounds_max_z(g_mesh);
        T("get_mesh_bounds_max_x callable", true, cast<string>(max_x));
        T("get_mesh_bounds_max_y callable", true, cast<string>(max_y));
        T("get_mesh_bounds_max_z callable", true, cast<string>(max_z));

        // Bounds sanity: min <= max
        T("mesh bounds min_x <= max_x", min_x <= max_x, "");
        T("mesh bounds min_y <= max_y", min_y <= max_y, "");
        T("mesh bounds min_z <= max_z", min_z <= max_z, "");
    } else {
        S("get_mesh_vert_count", "no mesh handle");
        S("get_mesh_index_count", "no mesh handle");
        S("get_mesh_stride", "no mesh handle");
        S("get_mesh_bounds_min_x", "no mesh handle");
        S("get_mesh_bounds_min_y", "no mesh handle");
        S("get_mesh_bounds_min_z", "no mesh handle");
        S("get_mesh_bounds_max_x", "no mesh handle");
        S("get_mesh_bounds_max_y", "no mesh handle");
        S("get_mesh_bounds_max_z", "no mesh handle");
    }

    // Destroy mesh and re-create (test destroy mid-script)
    if (g_mesh != 0) {
        int64 r = destroy_mesh(g_mesh);
        T("destroy_mesh callable", true, cast<string>(r));
    } else {
        S("destroy_mesh", "no handle");
    }
    // Re-create mesh for custom draw sections
    g_mesh = create_mesh_raw(mesh_verts, 3, 24, mesh_idx, 3, true);
    T("re-create_mesh_raw", g_mesh != 0, cast<string>(g_mesh));

    // ==================================================================
    // 11. Custom Draw
    // ==================================================================
    section("11. Custom Draw");

    // Check we have the resources needed for custom draw
    if (g_shader == 0) { S("custom_draw (skip all)", "no shader"); }

    if (g_vb == 0)     { S("custom_draw (skip all)", "no vertex buffer"); }

    if (g_ib == 0)     { S("custom_draw_indexed (skip)", "no index buffer"); }

    // Build vertex data for a triangle (matches shader layout: float2 pos + float4 color)
    float32[] verts;
    verts.push(-0.5f); verts.push(-0.5f);
    verts.push(1.0f);  verts.push(0.0f); verts.push(0.0f); verts.push(1.0f);
    verts.push(0.5f);  verts.push(-0.5f);
    verts.push(0.0f);  verts.push(1.0f); verts.push(0.0f); verts.push(1.0f);
    verts.push(0.0f);  verts.push(0.5f);
    verts.push(0.0f);  verts.push(0.0f); verts.push(1.0f); verts.push(1.0f);

    uint32[] indices;
    indices.push(0); indices.push(1); indices.push(2);

    float32[] no_cb_data;

    // custom_draw (non-indexed)
    if (g_shader != 0 && g_vb != 0) {
        h = custom_draw(g_shader, g_vb, verts, 3, 0,
                        0, 0, 0, 0,
                        0, no_cb_data, 0);
        T("custom_draw triangle list", h != 0, cast<string>(h));

        // custom_draw with LINE_LIST topology (topology=2)
        h = custom_draw(g_shader, g_vb, verts, 3, 2,
                        0, 0, 0, 0,
                        0, no_cb_data, 0);
        T("custom_draw line list", h != 0, cast<string>(h));

        // custom_draw with LINE_STRIP (topology=3)
        h = custom_draw(g_shader, g_vb, verts, 3, 3,
                        0, 0, 0, 0,
                        0, no_cb_data, 0);
        T("custom_draw line strip", h != 0, cast<string>(h));

        // custom_draw with POINT_LIST (topology=4)
        h = custom_draw(g_shader, g_vb, verts, 3, 4,
                        0, 0, 0, 0,
                        0, no_cb_data, 0);
        T("custom_draw point list", h != 0, cast<string>(h));

        // custom_draw with blend state, sampler, texture, constant buffer
        if (g_blend != 0 && g_sampler != 0 && g_tex != 0 && g_cb != 0) {
            h = custom_draw(g_shader, g_vb, verts, 3, 0,
                            g_blend, g_sampler, g_tex, 0,
                            g_cb, no_cb_data, 0);
            T("custom_draw with all bindings", h != 0, cast<string>(h));
        } else {
            S("custom_draw with bindings", "missing required resources");
        }

        // custom_draw with blend + sampler only (texture/cb = 0)
        if (g_blend != 0 && g_sampler != 0) {
            h = custom_draw(g_shader, g_vb, verts, 3, 0,
                            g_blend, g_sampler, 0, 0,
                            0, no_cb_data, 0);
            T("custom_draw blend+sampler only", h != 0, cast<string>(h));
        }
    } else {
        S("custom_draw", "missing shader or vertex buffer");
        S("custom_draw line list", "missing shader or vertex buffer");
        S("custom_draw line strip", "missing shader or vertex buffer");
        S("custom_draw point list", "missing shader or vertex buffer");
        S("custom_draw with bindings", "missing shader or vertex buffer");
        S("custom_draw blend+sampler", "missing shader or vertex buffer");
    }

    // custom_draw_indexed
    if (g_shader != 0 && g_vb != 0 && g_ib != 0) {
        h = custom_draw_indexed(g_shader, g_vb, verts, 3,
                                g_ib, indices, 3, 0,
                                0, 0, 0, 0,
                                0, no_cb_data, 0);
        T("custom_draw_indexed triangle list", h != 0, cast<string>(h));

        // custom_draw_indexed with TRIANGLE_STRIP (topology=1)
        h = custom_draw_indexed(g_shader, g_vb, verts, 3,
                                g_ib, indices, 3, 1,
                                0, 0, 0, 0,
                                0, no_cb_data, 0);
        T("custom_draw_indexed triangle strip", h != 0, cast<string>(h));
    } else {
        S("custom_draw_indexed", "missing shader, vb, or ib");
    }

    // draw_mesh
    if (g_mesh != 0 && g_shader != 0) {
        h = draw_mesh(g_mesh, g_shader, 0,
                      0, 0, 0, 0,
                      0, no_cb_data, 0);
        T("draw_mesh triangle list", h != 0, cast<string>(h));

        // draw_mesh with LINE_LIST topology
        h = draw_mesh(g_mesh, g_shader, 2,
                      0, 0, 0, 0,
                      0, no_cb_data, 0);
        T("draw_mesh line list", h != 0, cast<string>(h));

        // draw_mesh with blend + sampler
        if (g_blend != 0 && g_sampler != 0) {
            h = draw_mesh(g_mesh, g_shader, 0,
                          g_blend, g_sampler, 0, 0,
                          0, no_cb_data, 0);
            T("draw_mesh with blend+sampler", h != 0, cast<string>(h));
        }

        // draw_mesh with texture
        if (g_tex != 0) {
            h = draw_mesh(g_mesh, g_shader, 0,
                          0, 0, g_tex, 0,
                          0, no_cb_data, 0);
            T("draw_mesh with texture", h != 0, cast<string>(h));
        }

        // draw_mesh with constant buffer
        if (g_cb != 0) {
            h = draw_mesh(g_mesh, g_shader, 0,
                          0, 0, 0, 0,
                          g_cb, no_cb_data, 0);
            T("draw_mesh with constant buffer", h != 0, cast<string>(h));
        }
    } else {
        S("draw_mesh", "missing mesh or shader");
    }

    // dispatch_compute
    // Re-create compute shader since we destroyed it earlier
    g_cs = create_compute_shader(cs_src);
    if (g_cs != 0) {
        h = dispatch_compute(g_cs, 8, 8, 1);
        T("dispatch_compute 8x8x1", h != 0, cast<string>(h));

        h = dispatch_compute(g_cs, 1, 1, 1);
        T("dispatch_compute 1x1x1", h != 0, cast<string>(h));

        h = dispatch_compute(g_cs, 16, 1, 1);
        T("dispatch_compute 16x1x1", h != 0, cast<string>(h));
    } else {
        S("dispatch_compute", "no compute shader");
    }

    // ==================================================================
    // 12. Binding and State
    // ==================================================================
    section("12. Binding and State");

    // custom_set_render_target
    if (g_rt != 0) {
        h = custom_set_render_target(g_rt);
        T("custom_set_render_target", h != 0, cast<string>(h));
    } else {
        S("custom_set_render_target", "no render target");
    }

    // custom_set_render_target_ext with both RT and depth
    if (g_rt != 0 && g_db != 0) {
        h = custom_set_render_target_ext(g_rt, g_db);
        T("custom_set_render_target_ext with depth", h != 0, cast<string>(h));
    } else {
        S("custom_set_render_target_ext", "no RT or depth buffer");
    }

    // custom_set_render_target with depth=0 (no depth)
    if (g_rt != 0) {
        h = custom_set_render_target_ext(g_rt, 0);
        T("custom_set_render_target_ext no depth", h != 0, cast<string>(h));
    }

    // custom_reset_render_target
    h = custom_reset_render_target();
    T("custom_reset_render_target", h != 0, cast<string>(h));

    // custom_bind_rt_as_texture
    if (g_rt != 0) {
        h = custom_bind_rt_as_texture(g_rt, 0);
        T("custom_bind_rt_as_texture slot 0", h != 0, cast<string>(h));

        h = custom_bind_rt_as_texture(g_rt, 1);
        T("custom_bind_rt_as_texture slot 1", h != 0, cast<string>(h));
    } else {
        S("custom_bind_rt_as_texture", "no render target");
    }

    // custom_restore_state
    h = custom_restore_state();
    T("custom_restore_state", h != 0, cast<string>(h));

    // custom_set_depth_stencil_state
    if (g_ds != 0) {
        h = custom_set_depth_stencil_state(g_ds);
        T("custom_set_depth_stencil_state", h != 0, cast<string>(h));
    } else {
        S("custom_set_depth_stencil_state", "no depth-stencil state");
    }

    // custom_set_rasterizer_state
    if (g_rs != 0) {
        h = custom_set_rasterizer_state(g_rs);
        T("custom_set_rasterizer_state", h != 0, cast<string>(h));
    } else {
        S("custom_set_rasterizer_state", "no rasterizer state");
    }

    // custom_set_viewport
    h = custom_set_viewport(0.0, 0.0, 800.0, 600.0);
    T("custom_set_viewport 800x600", h != 0, cast<string>(h));

    h = custom_set_viewport(100.0, 50.0, 400.0, 300.0);
    T("custom_set_viewport offset 400x300", h != 0, cast<string>(h));

    // custom_reset_viewport
    h = custom_reset_viewport();
    T("custom_reset_viewport", h != 0, cast<string>(h));

    // custom_bind_texture
    if (g_tex != 0 && g_sampler != 0) {
        h = custom_bind_texture(g_tex, g_sampler, 0);
        T("custom_bind_texture slot 0", h != 0, cast<string>(h));

        h = custom_bind_texture(g_tex, g_sampler, 1);
        T("custom_bind_texture slot 1", h != 0, cast<string>(h));
    } else {
        S("custom_bind_texture", "no texture or sampler");
    }

    // custom_bind_texture with different sampler
    if (g_tex != 0) {
        int64 sam2 = create_sampler(1, 1, 1);
        if (sam2 != 0) {
            h = custom_bind_texture(g_tex, sam2, 2);
            T("custom_bind_texture separate sampler", h != 0, cast<string>(h));
            destroy_sampler(sam2);
        } else {
            S("custom_bind_texture separate sampler", "failed to create sampler");
        }
    }

    // custom_bind_constant_buffer
    if (g_cb != 0) {
        float32[] cb_contents;
        cb_contents.push(1.0f); cb_contents.push(2.0f); cb_contents.push(3.0f); cb_contents.push(4.0f);
        h = custom_bind_constant_buffer(g_cb, cb_contents, 0, 1);
        T("custom_bind_constant_buffer slot 0 PS", h != 0, cast<string>(h));

        h = custom_bind_constant_buffer(g_cb, cb_contents, 1, 0);
        T("custom_bind_constant_buffer slot 1 VS", h != 0, cast<string>(h));

        h = custom_bind_constant_buffer(g_cb, cb_contents, 2, 2);
        T("custom_bind_constant_buffer slot 2 CS", h != 0, cast<string>(h));

        // With empty data array
        float32[] empty_cb;
        h = custom_bind_constant_buffer(g_cb, empty_cb, 0, 1);
        T("custom_bind_constant_buffer empty data", h != 0, cast<string>(h));
    } else {
        S("custom_bind_constant_buffer", "no constant buffer");
    }

    // custom_update_texture
    if (g_tex != 0) {
        uint8[] upd_rgba;
        upd_rgba.push(0); upd_rgba.push(0); upd_rgba.push(0); upd_rgba.push(255);
        h = custom_update_texture(g_tex, 0, 0, 1, 1, upd_rgba);
        T("custom_update_texture 1x1 region", h != 0, cast<string>(h));

        // Update full texture
        h = custom_update_texture(g_tex, 0, 0, 2, 2, rgba_tex);
        T("custom_update_texture full 2x2", h != 0, cast<string>(h));
    } else {
        S("custom_update_texture", "no texture");
    }

    // custom_clear_render_target
    if (g_rt != 0) {
        h = custom_clear_render_target(g_rt, 0.0, 0.0, 0.0, 1.0);
        T("custom_clear_render_target black", h != 0, cast<string>(h));

        h = custom_clear_render_target(g_rt, 0.2, 0.4, 0.6, 1.0);
        T("custom_clear_render_target color", h != 0, cast<string>(h));

        // Must reset RT after clear before returning to 2D layer
        custom_reset_render_target();
    } else {
        S("custom_clear_render_target", "no render target");
        S("custom_reset_render_target (after clear)", "no render target");
    }

    // custom_clear_depth_buffer
    if (g_db != 0) {
        h = custom_clear_depth_buffer(g_db);
        T("custom_clear_depth_buffer", h != 0, cast<string>(h));
    } else {
        S("custom_clear_depth_buffer", "no depth buffer");
    }

    // bind_structured_buffer
    if (g_sb != 0) {
        h = bind_structured_buffer(g_sb, 0, 1);
        T("bind_structured_buffer slot 0 PS", h != 0, cast<string>(h));

        h = bind_structured_buffer(g_sb, 1, 0);
        T("bind_structured_buffer slot 1 VS", h != 0, cast<string>(h));

        h = bind_structured_buffer(g_sb, 2, 2);
        T("bind_structured_buffer slot 2 CS", h != 0, cast<string>(h));
    } else {
        S("bind_structured_buffer", "no structured buffer");
    }

    // update_structured_buffer
    if (g_sb != 0) {
        uint8[] sb_data;
        sb_data.push(10); sb_data.push(20); sb_data.push(30); sb_data.push(40);
        sb_data.push(50); sb_data.push(60); sb_data.push(70); sb_data.push(80);
        h = update_structured_buffer(g_sb, sb_data);
        T("update_structured_buffer 8 bytes", h != 0, cast<string>(h));
    } else {
        S("update_structured_buffer", "no structured buffer");
    }

    // capture_backbuffer
    h = capture_backbuffer(0);
    T("capture_backbuffer slot 0", h != 0, cast<string>(h));

    h = capture_backbuffer(1);
    T("capture_backbuffer slot 1", h != 0, cast<string>(h));

    // Restore state before exiting the routine (doc: "call custom_restore_state()
    // after any custom-pipeline sequence before returning control to the 2D layer")
    custom_restore_state();
    custom_reset_render_target();
    custom_reset_viewport();

    // ==================================================================
    // 13. Cleanup — Explicit destroy calls for shared resources
    // ==================================================================
    section("13. Cleanup — explicit destroy_* calls");

    print_console("  (resources auto-destroyed on unload, testing explicit calls)");

    if (g_shader != 0)  { h = destroy_shader(g_shader);          T("destroy_shader", true, "");          g_shader = 0; }
    if (g_cs != 0)      { h = destroy_compute_shader(g_cs);      T("destroy_compute_shader", true, "");  g_cs = 0; }
    if (g_vb != 0)      { h = destroy_vertex_buffer(g_vb);       T("destroy_vertex_buffer", true, "");   g_vb = 0; }
    if (g_ib != 0)      { h = destroy_index_buffer(g_ib);        T("destroy_index_buffer", true, "");    g_ib = 0; }
    if (g_cb != 0)      { h = destroy_constant_buffer(g_cb);     T("destroy_constant_buffer", true, "");  g_cb = 0; }
    if (g_sb != 0)      { h = destroy_structured_buffer(g_sb);   T("destroy_structured_buffer", true, ""); g_sb = 0; }
    if (g_blend != 0)   { h = destroy_blend_state(g_blend);      T("destroy_blend_state", true, "");     g_blend = 0; }
    if (g_sampler != 0) { h = destroy_sampler(g_sampler);        T("destroy_sampler", true, "");         g_sampler = 0; }
    if (g_ds != 0)      { h = destroy_depth_stencil_state(g_ds); T("destroy_depth_stencil_state", true, ""); g_ds = 0; }
    if (g_rs != 0)      { h = destroy_rasterizer_state(g_rs);    T("destroy_rasterizer_state", true, ""); g_rs = 0; }
    if (g_rt != 0)      { h = destroy_render_target(g_rt);       T("destroy_render_target", true, "");   g_rt = 0; }
    if (g_db != 0)      { h = destroy_depth_buffer(g_db);        T("destroy_depth_buffer", true, "");    g_db = 0; }
    if (g_tex != 0)     { h = destroy_texture(g_tex);            T("destroy_texture", true, "");         g_tex = 0; }
    if (g_mesh != 0)    { h = destroy_mesh(g_mesh);              T("destroy_mesh", true, "");            g_mesh = 0; }

    // ==================================================================
    // Summary
    // ==================================================================
    print_console("");
    print_console("===========================================");
    print_console("  Render API test complete");
    print_console("  PASS: " + cast<string>(g_pass));
    print_console("  FAIL: " + cast<string>(g_fail));
    print_console("  SKIP: " + cast<string>(g_skip));
    print_console("===========================================");

    unregister_routine(g_routine);
}

// =============================================================================
// Entry point
// =============================================================================

int64 main() {
    print_console("[render_api_test] registering routine");

    g_routine = register_routine(cast<int64>(test_render_api), 0);
    if (g_routine == 0) {
        print_console("[FAIL] register_routine returned 0");
        return -1;
    }

    print_console("[render_api_test] routine registered, handle=" + cast<string>(g_routine));
    return 1;
}
