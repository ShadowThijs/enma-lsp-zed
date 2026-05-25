struct P { float64 x; float64 y; }
P* g_ps;
int32 main() {
    g_ps = new P[8];
    int32 i = 0;
    while (i < 8) {
        float64 fi = cast<float64>(i);
        g_ps[i].x = fi;
        g_ps[i].y = fi * 2.0;
        i = i + 1;
    }
    float64 sum = 0.0;
    int32 j = 0;
    while (j < 8) { sum = sum + g_ps[j].x + g_ps[j].y; j = j + 1; }
    return cast<int32>(sum);
}
