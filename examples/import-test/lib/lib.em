struct Cell {
	int32	v;
	Cell()	{ this->v = 0; }
	~Cell()	{ this->v = 0; }
	void	inc() { this->v = this->v + 1; }
}
