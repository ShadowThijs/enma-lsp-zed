// voxlands/render.em
//
// Shader source + GPU resource creation, per-frame render pass, and
// 2D HUD overlay.
//
// Single combined CB at slot 0 carrying both camera params and the
// voxel grid.  The earlier attempt at a separate WorldCB bound via
// custom_bind_constant_buffer(slot=1) silently failed to upload, so
// everything goes through custom_draw's embedded cb_data which we
// know works.

#pragma once
import "C:/Users/senti/Documents/My Games/3dgame/voxlands/state.em";
import "C:/Users/senti/Documents/My Games/3dgame/voxlands/camera.em";

void init_gpu() {
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
        "    float4 iCamFwd;     // .w = time\n" +
        "    float4 iCamPos;     // .xyz = world position\n" +
        "    float4 world[512];  // 16*16*8 = 2048 block IDs packed 4/vec4\n" +
        "};\n" +
        "static const int WORLD_X   = 16;\n" +
        "static const int WORLD_Y   = 8;\n" +
        "static const int WORLD_Z   = 16;\n" +
        "static const int MAX_STEPS = 96;\n" +
        "struct PSIn { float4 pos : SV_POSITION; float2 uv : TEXCOORD0; };\n" +
        "\n" +
        "int get_block(int x, int y, int z) {\n" +
        "    if (x < 0 || x >= WORLD_X) return 0;\n" +
        "    if (y < 0 || y >= WORLD_Y) return 0;\n" +
        "    if (z < 0 || z >= WORLD_Z) return 0;\n" +
        "    int idx  = x + z * WORLD_X + y * WORLD_X * WORLD_Z;\n" +
        "    int slot = idx / 4;\n" +
        "    int comp = idx % 4;\n" +
        "    float4 v = world[slot];\n" +
        "    if (comp == 0) return (int)v.x;\n" +
        "    if (comp == 1) return (int)v.y;\n" +
        "    if (comp == 2) return (int)v.z;\n" +
        "    return (int)v.w;\n" +
        "}\n" +
        "// Noise helpers used by both block_color and sky_color.\n" +
        "float hash21f(float2 p) {\n" +
        "    p = frac(p * float2(127.1, 311.7));\n" +
        "    p += dot(p, p + 33.33);\n" +
        "    return frac(p.x * p.y);\n" +
        "}\n" +
        "float vnoise(float2 p) {\n" +
        "    float2 ip = floor(p); float2 fp = frac(p);\n" +
        "    float a = hash21f(ip);\n" +
        "    float b = hash21f(ip + float2(1.0, 0.0));\n" +
        "    float c = hash21f(ip + float2(0.0, 1.0));\n" +
        "    float d = hash21f(ip + float2(1.0, 1.0));\n" +
        "    float2 u = fp * fp * (3.0 - 2.0 * fp);\n" +
        "    return lerp(lerp(a, b, u.x), lerp(c, d, u.x), u.y);\n" +
        "}\n" +
        "float fbm(float2 p, float t) {\n" +
        "    float v = 0.0; float a = 0.5;\n" +
        "    [unroll] for (int i = 0; i < 5; i++) {\n" +
        "        v += a * vnoise(p + float2(t * (0.015 + 0.008 * float(i)),\n" +
        "                                   t * (0.011 + 0.006 * float(i))));\n" +
        "        p *= 2.05;\n" +
        "        a *= 0.55;\n" +
        "    }\n" +
        "    return v;\n" +
        "}\n" +
        "// Procedural per-face block texture.  uv is the [0,1) position on\n" +
        "// the hit face, cs is a per-cell hash so adjacent cells of the same\n" +
        "// block type don't share an identical pattern.\n" +
        "float3 block_color(int id, int axis, float dir_y, float2 uv, float cs, float t) {\n" +
        "    float2 uv2 = uv + float2(cs * 7.13, cs * 11.97);\n" +
        "    if (id == 1) {\n" +
        "        // grass top: noisy green\n" +
        "        if (axis == 1 && dir_y < 0.0) {\n" +
        "            float n = vnoise(uv2 * 6.5);\n" +
        "            return lerp(float3(0.22, 0.50, 0.14), float3(0.36, 0.66, 0.24), n);\n" +
        "        }\n" +
        "        // grass bottom face: pure dirt\n" +
        "        if (axis == 1) {\n" +
        "            float n = vnoise(uv2 * 5.0);\n" +
        "            return lerp(float3(0.40, 0.26, 0.12), float3(0.54, 0.36, 0.18), n);\n" +
        "        }\n" +
        "        // grass side: dirt with a noisy green strip across the top edge\n" +
        "        float n = vnoise(uv2 * 5.0);\n" +
        "        float3 dirt = lerp(float3(0.40, 0.26, 0.12), float3(0.54, 0.36, 0.18), n);\n" +
        "        float gmix = saturate((uv.y - 0.78) * 6.0);\n" +
        "        float gn = vnoise(uv2 * 6.0);\n" +
        "        float3 grass = lerp(float3(0.22, 0.50, 0.14), float3(0.36, 0.66, 0.24), gn);\n" +
        "        return lerp(dirt, grass, gmix);\n" +
        "    }\n" +
        "    if (id == 2) {\n" +
        "        // dirt with sparse dark specks\n" +
        "        float n = vnoise(uv2 * 5.5);\n" +
        "        float3 c = lerp(float3(0.40, 0.26, 0.12), float3(0.56, 0.38, 0.20), n);\n" +
        "        float specks = step(0.86, vnoise(uv2 * 20.0));\n" +
        "        return lerp(c, float3(0.22, 0.15, 0.08), specks * 0.55);\n" +
        "    }\n" +
        "    if (id == 3) {\n" +
        "        // stone: two-octave grey with darker cracks\n" +
        "        float n = vnoise(uv2 * 4.5) * 0.6 + vnoise(uv2 * 11.0) * 0.4;\n" +
        "        float3 c = lerp(float3(0.38, 0.38, 0.42), float3(0.58, 0.58, 0.62), n);\n" +
        "        float cracks = step(0.80, vnoise(uv2 * 14.0));\n" +
        "        return lerp(c, float3(0.24, 0.24, 0.27), cracks * 0.45);\n" +
        "    }\n" +
        "    if (id == 4) {\n" +
        "        // sand: fine high-frequency grain\n" +
        "        float n = vnoise(uv2 * 14.0) * 0.5 + vnoise(uv2 * 28.0) * 0.5;\n" +
        "        return lerp(float3(0.74, 0.66, 0.42), float3(0.93, 0.86, 0.62), n);\n" +
        "    }\n" +
        "    if (id == 5) {\n" +
        "        // water: animated sine waves\n" +
        "        float w = (sin(uv.x * 8.0 + t * 1.5) + cos(uv.y * 7.0 + t * 1.2)) * 0.25 + 0.5;\n" +
        "        return lerp(float3(0.10, 0.30, 0.62), float3(0.30, 0.55, 0.88), w);\n" +
        "    }\n" +
        "    if (id == 6) {\n" +
        "        if (axis == 1) {\n" +
        "            // log end: concentric rings\n" +
        "            float2 d = uv - 0.5;\n" +
        "            float rings = sin(length(d) * 30.0) * 0.5 + 0.5;\n" +
        "            return lerp(float3(0.55, 0.36, 0.18), float3(0.34, 0.22, 0.10), rings * 0.6);\n" +
        "        }\n" +
        "        // log side: vertical bark stripes + noise\n" +
        "        float lines = sin(uv.x * 16.0) * 0.5 + 0.5;\n" +
        "        float n     = vnoise(uv2 * 8.0) * 0.35;\n" +
        "        return lerp(float3(0.26, 0.15, 0.07), float3(0.44, 0.28, 0.14), lines * 0.7 + n);\n" +
        "    }\n" +
        "    if (id == 7) {\n" +
        "        // leaves: noisy green clusters\n" +
        "        float n = vnoise(uv2 * 9.0);\n" +
        "        return lerp(float3(0.06, 0.26, 0.05), float3(0.22, 0.52, 0.14), n);\n" +
        "    }\n" +
        "    if (id == 8) {\n" +
        "        // snow: faint cool-tinted noise\n" +
        "        float n = vnoise(uv2 * 7.0);\n" +
        "        return lerp(float3(0.84, 0.88, 0.95), float3(0.99, 1.00, 1.00), n);\n" +
        "    }\n" +
        "    return float3(1.0, 0.0, 1.0);\n" +
        "}\n" +
        "float face_shade(int axis, float dir_y) {\n" +
        "    if (axis == 1) { if (dir_y < 0.0) return 1.00; return 0.40; }\n" +
        "    if (axis == 0) return 0.66;\n" +
        "    return 0.85;\n" +
        "}\n" +
        "float3 sky_color(float3 rd, float t) {\n" +
        "    float3 sun_dir = normalize(float3(0.45, 0.65, 0.55));\n" +
        "    float3 col;\n" +
        "    if (rd.y > 0.0) {\n" +
        "        float h = saturate(rd.y);\n" +
        "        col = lerp(float3(0.85, 0.92, 0.97), float3(0.18, 0.40, 0.72), pow(h, 0.55));\n" +
        "        float2 cuv  = rd.xz / max(rd.y, 0.05);\n" +
        "        float  base = fbm(cuv * 0.30, t);\n" +
        "        float  detail = fbm(cuv * 1.20 + 17.3, t * 1.4);\n" +
        "        float density = base * 0.7 + detail * 0.45;\n" +
        "        density = smoothstep(0.55, 0.88, density);\n" +
        "        density *= smoothstep(0.02, 0.22, rd.y);\n" +
        "        float sun_align = saturate(dot(rd, sun_dir) * 0.5 + 0.5);\n" +
        "        float3 cloud_col = lerp(float3(0.55, 0.58, 0.65), float3(1.0, 0.98, 0.94), pow(sun_align, 1.4));\n" +
        "        col = lerp(col, cloud_col, density);\n" +
        "        float sd = dot(rd, sun_dir);\n" +
        "        col += smoothstep(0.9994, 0.9999, sd) * float3(1.6, 1.5, 1.3);\n" +
        "        col += pow(saturate(sd), 90.0) * float3(1.0, 0.85, 0.65) * 0.45;\n" +
        "    } else {\n" +
        "        col = lerp(float3(0.42, 0.36, 0.30), float3(0.18, 0.16, 0.14), -rd.y);\n" +
        "    }\n" +
        "    return col;\n" +
        "}\n" +
        "\n" +
        "float4 main(PSIn i) : SV_TARGET {\n" +
        "    float2 ndc   = (i.uv - 0.5) * 2.0;\n" +
        "    float  scale = iResAspectFov.w;\n" +
        "    float  aspect= iResAspectFov.z;\n" +
        "    float3 rd = normalize(iCamFwd.xyz\n" +
        "                        + iCamRight.xyz * ndc.x * aspect * scale\n" +
        "                        + iCamUp.xyz    * ndc.y * scale);\n" +
        "    float3 ro = iCamPos.xyz;\n" +
        "    float  t_time = iCamFwd.w;\n" +
        "    float3 cell  = floor(ro);\n" +
        "    float3 stepf = sign(rd);\n" +
        "    float3 inv_rd  = 1.0 / (abs(rd) + 1e-6);\n" +
        "    float3 frac_ro = ro - cell;\n" +
        "    float3 tmax;\n" +
        "    tmax.x = ((stepf.x > 0.0) ? (1.0 - frac_ro.x) : frac_ro.x) * inv_rd.x;\n" +
        "    tmax.y = ((stepf.y > 0.0) ? (1.0 - frac_ro.y) : frac_ro.y) * inv_rd.y;\n" +
        "    tmax.z = ((stepf.z > 0.0) ? (1.0 - frac_ro.z) : frac_ro.z) * inv_rd.z;\n" +
        "    int hit_axis = -1;\n" +
        "    int hit_id   = 0;\n" +
        "    float hit_t  = 0.0;\n" +
        "    float dir_y_hit = 0.0;\n" +
        "    [loop] for (int s = 0; s < MAX_STEPS; s++) {\n" +
        "        int b = get_block((int)cell.x, (int)cell.y, (int)cell.z);\n" +
        "        if (b > 0) { hit_id = b; break; }\n" +
        "        if (tmax.x < tmax.y && tmax.x < tmax.z) {\n" +
        "            hit_t = tmax.x; tmax.x += inv_rd.x; cell.x += stepf.x; hit_axis = 0;\n" +
        "        } else if (tmax.y < tmax.z) {\n" +
        "            hit_t = tmax.y; tmax.y += inv_rd.y; cell.y += stepf.y; hit_axis = 1; dir_y_hit = stepf.y;\n" +
        "        } else {\n" +
        "            hit_t = tmax.z; tmax.z += inv_rd.z; cell.z += stepf.z; hit_axis = 2;\n" +
        "        }\n" +
        "        // Direction-aware early-out: only bail when the ray is past\n" +
        "        // the world on a given axis AND still heading further away.\n" +
        "        if (stepf.x < 0.0 && cell.x < -1.0)              break;\n" +
        "        if (stepf.x > 0.0 && cell.x > (float)WORLD_X)    break;\n" +
        "        if (stepf.y < 0.0 && cell.y < -1.0)              break;\n" +
        "        if (stepf.y > 0.0 && cell.y > (float)WORLD_Y)    break;\n" +
        "        if (stepf.z < 0.0 && cell.z < -1.0)              break;\n" +
        "        if (stepf.z > 0.0 && cell.z > (float)WORLD_Z)    break;\n" +
        "    }\n" +
        "    float3 col;\n" +
        "    if (hit_id > 0) {\n" +
        "        // Face UV: pick the two axes that aren't the hit axis.\n" +
        "        float3 hp = ro + rd * hit_t;\n" +
        "        float2 uv;\n" +
        "        if (hit_axis == 0)      uv = frac(float2(hp.z, hp.y));\n" +
        "        else if (hit_axis == 1) uv = frac(float2(hp.x, hp.z));\n" +
        "        else                    uv = frac(float2(hp.x, hp.y));\n" +
        "        // Per-cell hash so adjacent same-type blocks differ.\n" +
        "        float cs = frac(sin(dot(cell, float3(127.1, 311.7, 74.7))) * 43758.5453);\n" +
        "        float3 albedo = block_color(hit_id, hit_axis, dir_y_hit, uv, cs, t_time);\n" +
        "        float  shade  = face_shade(hit_axis, dir_y_hit);\n" +
        "        col = albedo * shade;\n" +
        "        float3 sun_dir = normalize(float3(0.45, 0.65, 0.55));\n" +
        "        float3 n = float3(0.0, 0.0, 0.0);\n" +
        "        if (hit_axis == 0) n.x = -stepf.x;\n" +
        "        if (hit_axis == 1) n.y = -stepf.y;\n" +
        "        if (hit_axis == 2) n.z = -stepf.z;\n" +
        "        float nl = max(dot(n, sun_dir), 0.0);\n" +
        "        col *= 0.55 + 0.50 * nl;\n" +
        "        float fog = saturate(hit_t * 0.005);\n" +
        "        col = lerp(col, float3(0.80, 0.87, 0.95), fog);\n" +
        "    } else {\n" +
        "        col = sky_color(rd, t_time);\n" +
        "    }\n" +
        "    float2 vc = (i.uv - 0.5) * 2.0;\n" +
        "    float  vig = 1.0 - dot(vc, vc) * 0.16;\n" +
        "    col *= saturate(vig);\n" +
        "    return float4(col, 1.0);\n" +
        "}\n";

    g_shader = create_shader(vs, ps, "POSITION:0:FLOAT2, COLOR:0:FLOAT2");
    if (g_shader == 0) {
        println("[voxlands] create_shader failed");
        return;
    }
    g_vb = create_vertex_buffer(16, 4, true);
    // Camera (5 vec4) + world (512 vec4) = 517 vec4 = 8272 bytes.
    g_cb = create_constant_buffer(8272);
}

void render_scene() {
    float64 vw = get_view_width();
    float64 vh = get_view_height();
    float64 aspect = vw / vh;
    float64 t_sec  = cast<float64>(time_ms() - g_t_app_start) * 0.001;

    vec3 f = cam_forward();
    vec3 r = cam_right();
    vec3 u = cam_up();

    float32[] verts;
    verts.push(-1.0f); verts.push(-1.0f); verts.push(0.0f); verts.push(0.0f);
    verts.push( 1.0f); verts.push(-1.0f); verts.push(1.0f); verts.push(0.0f);
    verts.push(-1.0f); verts.push( 1.0f); verts.push(0.0f); verts.push(1.0f);
    verts.push( 1.0f); verts.push( 1.0f); verts.push(1.0f); verts.push(1.0f);

    // Build combined CB payload: 5 vec4 camera + 512 vec4 world.
    float32[] cb_data;
    cb_data.push(cast<float32>(vw));
    cb_data.push(cast<float32>(vh));
    cb_data.push(cast<float32>(aspect));
    cb_data.push(cast<float32>(g_tan_half));
    cb_data.push(cast<float32>(r.x)); cb_data.push(cast<float32>(r.y)); cb_data.push(cast<float32>(r.z)); cb_data.push(0.0f);
    cb_data.push(cast<float32>(u.x)); cb_data.push(cast<float32>(u.y)); cb_data.push(cast<float32>(u.z)); cb_data.push(0.0f);
    cb_data.push(cast<float32>(f.x)); cb_data.push(cast<float32>(f.y)); cb_data.push(cast<float32>(f.z));
    cb_data.push(cast<float32>(t_sec));
    cb_data.push(cast<float32>(g_cam_x)); cb_data.push(cast<float32>(g_cam_y)); cb_data.push(cast<float32>(g_cam_z)); cb_data.push(0.0f);

    int64 i = 0;
    int64 n = g_world_cb_data.length();
    while (i < n) {
        cb_data.push(g_world_cb_data.get(i));
        i = i + 1;
    }

    custom_draw(g_shader, g_vb, verts, 4, 1, 0, 0, 0, 0, g_cb, cb_data, 0);
    custom_restore_state();
}

void draw_crosshair() {
    float64 cx = get_view_width()  * 0.5;
    float64 cy = get_view_height() * 0.5;
    color cc = color(245, 245, 245, 230);
    color cd = color(  0,   0,   0, 200);
    draw_rect_filled(vec2(cx - 1.5, cy - 6.0), vec2(3.0, 12.0), cd, 0.0, 0);
    draw_rect_filled(vec2(cx - 6.0, cy - 1.5), vec2(12.0, 3.0), cd, 0.0, 0);
    draw_rect_filled(vec2(cx - 1.0, cy - 5.0), vec2(2.0, 10.0), cc, 0.0, 0);
    draw_rect_filled(vec2(cx - 5.0, cy - 1.0), vec2(10.0, 2.0), cc, 0.0, 0);
}

void draw_hud() {
    color white  = color(245, 245, 250, 255);
    color dim    = color(180, 190, 200, 220);
    color none   = color(  0,   0,   0,   0);
    color shadow = color(  0,   0,   0, 180);
    int64 font   = get_font20();

    string pos_str = "POS  x=" + int_to_str(cast<int64>(g_cam_x))
                   + "  y=" + int_to_str(cast<int64>(g_cam_y))
                   + "  z=" + int_to_str(cast<int64>(g_cam_z));
    draw_text(pos_str, vec2(20.0, 16.0), white, font, 1, shadow, 1.5);
    draw_text("WASD move  Space up  Ctrl down  Shift sprint",
              vec2(20.0, 40.0), dim, font, 0, none, 0.0);
}
