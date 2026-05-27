// Line comment at top

/* Block comment
   spanning multiple lines
   to test preservation */

#define MAX_SIZE 100

import "lib/test.em";

// Enum
enum Color {
	RED,
	GREEN,
	BLUE,
}

// Struct with fields and methods
struct Vec3 {
	float32 x;
	float32 y;
	float32 z;

	float32 length() {
		return sqrt(x * x + y * y + z * z);
	}

	Vec3 normalized() {
		float32 len = length();
		if (len > 0.0) {
			return Vec3(x / len, y / len, z / len);
		}
		return Vec3(0.0, 0.0, 0.0);
	}
};

// Class with constructor
class Entity {
	int64 id;
	string name;
	bool active;

	Entity(int64 _id, string _name) {
		id = _id;
		name = _name;
		active = true;
	}

	~Entity() {
		active = false;
	}

	void set_active(bool state) {
		active = state;
	}
};

// Global function
float32 compute_area(float32 width, float32 height) {
	return width * height;
}

// Function with multiple params and conditions
int32 process(int32 a, int32 b, int32 c) {
	if (a > b && b > c) {
		return a + b - c;
	} else if (a == b) {
		return 0;
	} else {
		return -1;
	}
}

// While and for loops
void loop_test(array<int32> items) {
	// While
	int32 i = 0;
	while (i < items.length()) {
		items[i] = items[i] * 2; // inline comment
		i = i + 1;
	}

	// For
	for (int32 j = 0; j < items.length(); j = j + 1) {
		items[j] = items[j] + 10;
	}

	// Do-while
	int32 k = 0;
	do {
		k = k + 1;
	} while (k < 10);
}

// Switch
string describe(int32 n) {
	switch (n) {
		case 0:
			return "zero";
		case 1:
			return "one";
		default:
			return "many";
	}
}

// Match expression
string color_name(Color c) {
	return match (c) {
		RED => "red",
		GREEN => "green",
		BLUE => "blue",
	};
}

// Try/catch
int32 safe_div(int32 a, int32 b) {
	try {
		return a / b;
	} catch (string e) {
		return 0;
	}
}

// Subscript and complex expression
int32 compute(Vec3 a, Vec3 b) {
	int32 result = (a.x + b.x) * (a.y - b.y);
	result = result + a[0] + b[1];
	return result;
}

// Template
template<typename T>
T clamp(T value, T lo, T hi) {
	if (value < lo) {
		return lo;
	}
	if (value > hi) {
		return hi;
	}
	return value;
}

// Entry
int32 main() {
	int32 x = 10;
	int32 y = 20;
	if (x < y) {
		return 1;
	}
	return 0;
}
