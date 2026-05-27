// math.em
int32 add(int32 x, int32 y) {
	return x + y; // End line comment
}

/*
* Comment block right here
* I can simply type as much as I want
*/

int32 mul(int32 x, int32 y) {
	return /* Inline comment block */ x * y;
}

// Comment line









// strings.em
// strings.em — string utilities
// math.em (already bundled)

int32 strlen(string s) {
	int32 count = 0;
	for (int32 i = 0; s[i] != 0; i = i + 1) {
		count = count + 1;
	}
	return mul(count, 1); // use mul from math.em
}


int32 main() {
	int32 a = add(3, 4);
	int32 b = strlen("hello");
	return a + b;
}
