// voxlands/world.em
//
// Terrain generation, block I/O, CB packing.
//
// Block IDs
//   0  air
//   1  grass        (green top, dirt sides)
//   2  dirt
//   3  stone
//   4  sand         (low coastal cells)
//   5  water        (fills cells below SEA_LEVEL)
//   6  log          (tree trunk)
//   7  leaves       (tree canopy)
//   8  snow         (caps on cells at or above SNOW_LEVEL)

#pragma once
import "C:/Users/senti/Documents/My Games/3dgame/voxlands/state.em";

// ----------------------------- noise -----------------------------

float64 fract(float64 x) { return x - floor(x); }

float64 hash21(float64 x, float64 z) {
    float64 v = sin(x * 12.9898 + z * 78.233 + g_seed * 0.137) * 43758.5453;
    return fract(v);
}

float64 vnoise2d(float64 x, float64 z) {
    float64 ix = floor(x); float64 iz = floor(z);
    float64 fx = x - ix;   float64 fz = z - iz;
    float64 a = hash21(ix,       iz);
    float64 b = hash21(ix + 1.0, iz);
    float64 c = hash21(ix,       iz + 1.0);
    float64 d = hash21(ix + 1.0, iz + 1.0);
    float64 ux = fx * fx * (3.0 - 2.0 * fx);
    float64 uz = fz * fz * (3.0 - 2.0 * fz);
    float64 ab = a + ux * (b - a);
    float64 cd = c + ux * (d - c);
    return ab + uz * (cd - ab);
}

float64 fbm2d(float64 x, float64 z) {
    float64 v = 0.0;
    float64 a = 0.5;
    int64 i = 0;
    while (i < 4) {
        v = v + a * vnoise2d(x, z);
        x = x * 2.07 + 1.7;
        z = z * 2.03 - 0.9;
        a = a * 0.55;
        i = i + 1;
    }
    return v;
}

// ----------------------------- block I/O -----------------------------

void set_block(int64 x, int64 y, int64 z, int64 id) {
    g_world.set(x + z * WORLD_X + y * WORLD_X * WORLD_Z, id);
}
int64 get_block(int64 x, int64 y, int64 z) {
    if (x < 0 || x >= WORLD_X) return 0;
    if (y < 0 || y >= WORLD_Y) return 0;
    if (z < 0 || z >= WORLD_Z) return 0;
    return g_world.get(x + z * WORLD_X + y * WORLD_X * WORLD_Z);
}

// ----------------------------- terrain -----------------------------

int64 terrain_height(int64 x, int64 z) {
    // DIAGNOSTIC: dramatic high-frequency hills.  Heights change every cell
    // by design so there's zero ambiguity if you still see a uniform slab.
    // If this looks flat we know the bug is in the render pipeline.
    float64 fx = cast<float64>(x);
    float64 fz = cast<float64>(z);
    float64 v = (sin(fx * 1.3) + cos(fz * 1.1) + 2.0) * 0.25;     // [0, 1]
    int64 h = 1 + cast<int64>(v * 6.0);
    if (h < 1)            h = 1;
    if (h > WORLD_Y - 1)  h = WORLD_Y - 1;
    return h;
}

int64 surface_block(int64 h) {
    if (h <= SEA_LEVEL)        return 4;   // sand at the shoreline
    if (h >= SNOW_LEVEL)       return 8;   // snowcap on tall columns
    return 1;                              // grass elsewhere
}

void plant_tree(int64 cx, int64 base_y, int64 cz) {
    // 2-block trunk + 3x3 leaves at trunk top + a single leaf above.
    // Skip cells that would overwrite existing solids (adjacent hills).
    set_block(cx, base_y,     cz, 6);
    set_block(cx, base_y + 1, cz, 6);
    int64 dx = -1;
    while (dx <= 1) {
        int64 dz = -1;
        while (dz <= 1) {
            if (dx != 0 || dz != 0) {
                int64 lx = cx + dx;
                int64 lz = cz + dz;
                if (get_block(lx, base_y + 1, lz) == 0) {
                    set_block(lx, base_y + 1, lz, 7);
                }
            }
            dz = dz + 1;
        }
        dx = dx + 1;
    }
    if (base_y + 2 < WORLD_Y) set_block(cx, base_y + 2, cz, 7);
}

// ----------------------------- generation -----------------------------

void generate_world() {
    g_world.clear();
    int64 i = 0;
    while (i < WORLD_TOTAL) { g_world.push(0); i = i + 1; }

    // Pass 1: terrain columns + water fill.
    int64 x = 0;
    while (x < WORLD_X) {
        int64 z = 0;
        while (z < WORLD_Z) {
            int64 h = terrain_height(x, z);
            int64 surf = surface_block(h);
            int64 y = 0;
            while (y < h) {
                int64 id = 3;                                              // stone
                if (y == h - 1)                                            id = surf;
                else if (h >= 3 && h < SNOW_LEVEL && y >= h - 3)           id = 2;   // dirt only under grass
                set_block(x, y, z, id);
                y = y + 1;
            }
            int64 wy = h;
            while (wy < SEA_LEVEL) {                   // water fills low cells
                set_block(x, wy, z, 5);
                wy = wy + 1;
            }
            z = z + 1;
        }
        x = x + 1;
    }

    // Pass 2: scatter trees on plain grass columns with room above.
    int64 tx = 0;
    while (tx < WORLD_X) {
        int64 tz = 0;
        while (tz < WORLD_Z) {
            int64 h = terrain_height(tx, tz);
            if (h > SEA_LEVEL && h < SNOW_LEVEL && h + 2 < WORLD_Y) {
                float64 r = hash21(cast<float64>(tx) * 7.31, cast<float64>(tz) * 11.91);
                if (r > 0.92) plant_tree(tx, h, tz);
            }
            tz = tz + 1;
        }
        tx = tx + 1;
    }
}

void rebuild_world_cb() {
    g_world_cb_data.clear();
    int64 i = 0;
    int64 n = WORLD_CB_V4 * 4;
    while (i < n) {
        if (i < WORLD_TOTAL) g_world_cb_data.push(cast<float32>(g_world.get(i)));
        else                 g_world_cb_data.push(0.0f);
        i = i + 1;
    }
}
