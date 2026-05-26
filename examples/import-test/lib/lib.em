struct Cell {
	int32	v;
	Cell()	{ this->v = 0; }
	~Cell()	{ this->v = 0; }
	void	inc() { this->v = this->v + 1; }
}

struct P {
	int32 x;
	int32 y;
	P() { x = 0; y = 0; }
}

P* ps = new P[10];              // default-ctor each
delete[] ps;                     // dtor each, then free

P* ys = new P[4](3, 5);          // every elem ctor'd with (3, 5)
delete[] ys;
