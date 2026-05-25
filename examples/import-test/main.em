import "lib/lib.em";

int32 main() {
	Cell* cs = new Cell[4];
	cs[0].inc();
	cs[0].inc();
	int32 sum = cs[0].v + cs[1].v + cs[2].v + cs[3].v;
	delete[] cs;
	return sum;
}
