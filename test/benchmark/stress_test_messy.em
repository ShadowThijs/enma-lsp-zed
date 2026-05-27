// Enma formatter stress test — ~500 lines exercising every language construct
// Run: enma-lsp → textDocument/formatting → measure time+correctness
// ============================================================================
// PREPROCESSOR
// ============================================================================
#define MAX_SIZE 1024
#define PI 3.14159265359
#define ENABLE_FEATURE
#ifdef ENABLE_FEATURE
#define FEATURE_FLAG 1
#else
#define FEATURE_FLAG 0
#endif
// ============================================================================
// IMPORTS
// ============================================================================
import "lib/math.em";

import "lib/collections.em";

import "lib/io.em";
// ============================================================================
// FORWARD DECLARATIONS
// ============================================================================
float64 compute_area(float64 radius)

void process_data(array<int32> data)

bool validate_input(string input) // ============================================================================ // ENUMS // ============================================================================

enum Vec2 {
	float32,
	x;
	float32 y;,
}
;

struct Vec3 {
	float32 x;
	float32 y;
	float32 z;
	float32 length() {
		return sqrt(x * x + y * y + z * z);
	}
	Vec3 normalize() {
		float32 len = length();
		if (len > 0.0) {
			return Vec3(x / len, y / len, z / len);
		}
		return Vec3(0.0, 0.0, 0.0);
	}
	float32 dot(Vec3 other) {
		return x * other.x + y * other.y + z * other.z;
	}
	Vec3 cross(Vec3 other) {
		return Vec3(y * other.z - z * other.y, z * other.x - x * other.z, x * other
						.y - y * other.x);
	}
};

struct Transform {
	Vec3 position;
	quat rotation;
	Vec3 scale;
};
// ============================================================================
// CLASSES
// ============================================================================
class Entity {
	int64 id;
	string name;
	Transform transform;
	bool active;
	Entity(int64 _id, string _name) {
		id = _id;
		name = _name;
		transform.position = Vec3(0.0, 0.0, 0.0);
		transform.rotation = quat_identity();
		transform.scale = Vec3(1.0, 1.0, 1.0);
		active = true;
	}
	~ Entity() {
		active = false;
	}
	void set_position(Vec3 pos) {
		transform.position = pos;
	}
	Vec3 get_position() {
		return transform.position;
	}
	void translate(Vec3 delta) {
		transform.position.x = transform.position.x + delta.x;
		transform.position.y = transform.position.y + delta.y;
		transform.position.z = transform.position.z + delta.z;
	}
	void rotate(float32 yaw, float32 pitch, float32 roll) {
		quat q = quat_from_euler(yaw, pitch, roll);
		transform.rotation = transform.rotation * q;
	}
	bool is_active() {
		return active;
	}
	virtual void update(float64 dt) {}
	virtual void render() {}
};
// ============================================================================
// INHERITANCE
// ============================================================================
class Player: Entity {
	int32 health;
	int32 max_health;
	float32 speed;
	array<string> inventory;
	Player(int64 _id, string _name) : Entity(_id,_name) {
		health = 100;
		max_health = 100;
		speed = 5.0;
	}
	void update(float64 dt) override {
		if (! active) {
			return;
		}
		if (health <= 0) {
			active = false;
		}
	}
	void render() override {
		if (! active) {
			return;
		}
	}
	void take_damage(int32 amount) {
		health = health - amount;
		if (health <0) {
			health = 0;
		}
	}
	void heal(int32 amount) {
		health = health + amount;
		if (health > max_health) {
			health = max_health;
		}
	}
	bool add_item(string item) {
		if (inventory.length() < 20) {
			inventory.push_back(item);
			return true;
		}
		return false;
	}
	bool has_item(string item) {
		for (int32i = 0; i <inventory.length(); i = i + 1) {
			if (inventory[i] == item) {
				return true;
			}
		}
		return false;
	}
};
// ============================================================================
// NAMESPACE
// ============================================================================
namespace Physics

Vec3 operator -(Vec3 a, Vec3 b) {
	return Vec3(a.x - b.x, a.y - b.y, a.z - b.z);
}

Vec3 operator *(Vec3 v, float32 s) {
	return Vec3(v.x * s, v.y * s, v.z * s);
}

// ============================================================================
// TEMPLATES
// ============================================================================
template<typename T>
				T min_value(T a,T b)
				{
		if (a<b)
		{
	return a;
  }
return b;
		}

template<typename T>
				T max_value(T a,T b) {

if (a>b) {
		return a;

     }
  return b;
				}

template<typename T>
  T clamp_value(T value,T lo,T hi) {
     if (value<lo)
     {
     return lo;
     }
	if (value>hi)
	{
  return hi;
}
return value;

  }
// ============================================================================
// UGLY FUNCTION (testing extreme formatting recovery)
// ============================================================================
int32 messy_fn;(int32 a, int32 b, float32 c) {
	if (a > b) {
		return a + b * c;
	} else if (a == b) {
		return 0;
	} else {
		switch (a) {
			case 1 : return 10;
			case 2:return   20;
			default: return
  -1;
		}
	}
}
// ============================================================================
// DEEPLY NESTED CONTROL FLOW
// ============================================================================
int32 deep_nesting;(int32 level) {
	int32 result = 0;
	if (level > 10) {
		if (level > 20) {
			if (level > 30) {
				if (level > 40) {
					if (level > 50) {
						result = 100;
					} else {
						result = 80;
					}
				} else {
					result = 60;
				}
			} else {
				result = 40;
			}
		} else {
			result = 20;
		}
	} else {
		result = 0;
	}
	return result;
}
// ============================================================================
// TRY/CATCH/THROW
// ============================================================================
int32 safe_divide;(int32 numerator, int32 denominator) {
	if (denominator == 0) {
		throw "Division by zero";
	}
	return numerator / denominator;
}

int32 compute_with_fallback(int32 a, int32 b) {
	int32 result = 0;
	try {
		result = safe_divide(a, b);
	}
	return result;
}
// ============================================================================
// DEFER
// ============================================================================
void file_processing_example;(string path) {
	file_t f = file_open(path, "r");
	defer {
		if (f. is_open()) {
			f.close();
		}
	}
	if (! f. is_open()) {
		return;
	}
	string content = f. read_all();
	println(content);
}
// ============================================================================
// MATCH EXPRESSION
// ============================================================================
string token_kind_name;(TokenKind kind) {
	return match (kind) {
		TOKEN_INTEGER => "integer"
	TOKEN_FLOAT => "float"
	TOKEN_STRING => "string"
	TOKEN_IDENTIFIER => "identifier"
	TOKEN_OPERATOR => "operator"
	TOKEN_EOF => "eof",
	};
}

int32 log_level_priority(LogLevel level) {
	return match (level) {
		LOG_DEBUG => 0
		LOG_INFO => 1
		LOG_WARNING => 2
		LOG_ERROR => 3
		LOG_FATAL => 4,
	};
}
// ============================================================================
// LAMBDAS
// ============================================================================
void lambda_examples;() {
	// Arrow lambda
	auto doubler = (int32 x) => x*2;
	// Bracketed lambda with capture
	int32 base = 10;
	auto adder = [base](int32 x) -> int32 {
		return base+x;
        };
	int32 result1 = doubler(5);
	int32 result2 = adder(3);
	println(result1);
	println(result2);
}
// ============================================================================
// POINTERS AND ARRAYS
// ============================================================================
void memory_operations;() {
	int32* ptr = new int32(42);
	println( * ptr);
	 * ptr = 100;
	println( * ptr);
	delete ptr;
	int32[] numbers = { 1,2,3,4,5 };
	for (int32v : numbers) {
	println(v);
} Cell * cells = new Cell[10]; for(int32i = 0); i <10; i = i + 1) {
		cells[i].inc();
	}
	delete[] cells;
}
// ============================================================================
// COMPLEX EXPRESSIONS
// ============================================================================
int32 complex_calculations;(int32 x, int32 y, int32 z) {
	int32 a = (x + y) * z - (x / (y + 1));
	int32 b = ((x << 2) & 0xFF) | (y >> 1);
	int32 c = (x > y) ? x : y;
	int32 d = ((a + b) * (c - x)) / (y > 0?y:1);
	bool cond1 = (a > b) && (c<d) || (x != y);
	bool cond2 = ! cond1 && (a >= b) || (c <= d);
	if (cond1 && cond2) {
		return a + b + c + d;
	}
	int32 e = x * x + y * y;
	int32 f = z * z * z;
	return e +f;
}
// ============================================================================
// FOR LOOP VARIANTS
// ============================================================================
voidloop_variants;(array<int32> items){// Classic for
for (int32i = 0; i <items.length(); i = i + 1) {
	println(items[i]);
}
// For-each
for(int32v : items) {println(v)}// While
int32j = 0while (j<items.length()) {
	println(items[j]);
	j = j + 1;
}
// Do-while
int32 k = 0;
do {
	if (items.length() > 0) {
		println(items[k]);
	}
	k = k + 1;
}
while (k<items.length());}// ============================================================================
// SWITCH WITH FALLTHROUGH (no break between cases)
// ============================================================================
string describe_number;(int32 n){switch (n) {
	case 0:
return "zero";
	case 1:
        return "one";
	case 2:
				return "two";
	case 3:

				return "three";
	default:
return "many";
}
}// ============================================================================
// RECURSIVE FUNCTION
// ============================================================================
int64 factorial;
(int64 n){if (n <= 1) {
	return 1;
}
return n * factorial(n - 1);
}

int64 fibonacci(int64 n){
	if (n <= 1) {
		return n;
	}
	return fibonacci(n - 1) + fibonacci(n - 2);
}
// ============================================================================
// ANNOTATIONS
// ============================================================================
[[reflect]]
		struct SerializedData{
	int32 version;
	string payload;
	int64 timestamp;
}
;
[[packed]]
struct PackedHeader{
	uint32 magic;
	uint16 version;
	uint16 flags;
}
;
[[align(16)]]structAlignedBuffer {
float64 data[16];
				};
// ============================================================================
// STRING AND CHAR LITERALS
// ============================================================================
void string_examples;
(){string s1 = "Hello,World!";
string s2 = "Line one\nLine two\nLine three";
string s3 = "Tab\tseparated\tvalues";
char c = 'A';
char newline = '\n';
char tab = '\t';
char hex_char = '\x41';
}// ============================================================================
// F-STRINGS AND INTERPOLATION
// ============================================================================
string format_player_info;
(Player p){return f"Player {p.name} (ID: {p.id}) — HP: {p.health}/{p.max_health}";
}

        string format_vector(Vec3 v){
	return f"({v.x},{v.y},
{v.z})";
}
// ============================================================================
// GAME LOOP SIMULATION
// ============================================================================
class GameWorld {
		array<Entity*> entities;
float64 elapsed_time;
bool running;
uint32 tick_count;
GameWorld() {
				elapsed_time=0.0;
running = false;
tick_count = 0;
}voidstart()
				{
running=true;
elapsed_time = 0.0;
tick_count = 0;
}voidstop() {
running=false;
        }

  void add_entity(Entity* entity) {
				entities.push_back(entity);
        }

     void remove_entity(int64 entity_id) {
for (int32 i=0; i<entities.length(); i=i+1) {
     if (entities[i].id==entity_id)
     {
entities.remove(i);
  return;
        }

				}
     }

				void update(float64 dt) {
		if (!running)
		{
        return;
		}

     elapsed_time=elapsed_time+dt;
				tick_count=tick_count+1;

     for (int32 i=0; i<entities.length(); i=i+1) {
		if (entities[i].is_active()) {

  entities[i].update(dt);
				}

  }
	}

				void render() {
				for (int32 i=0; i<entities.length(); i=i+1) {
				if (entities[i].is_active())
				{
				entities[i].render();
  }
		}
}

				Entity* find_entity(int64 id) {
				for (int32 i=0; i<entities.length(); i=i+1) {
     if (entities[i].id==id) {
        return entities[i];
				}
}
return null;
				}};

	// ============================================================================
        // MIXED COMMENTS AND WHITESPACE
        // ============================================================================

	/* Block comment with multiple lines.
	This should be preserved as-is.
        Third line of the comment. */

int32 function_with_comments(int32 x) {
				// This is a line comment
     int32 result = x * 2;
// Inline comment
/*
Multi-line block comment

inside a function body.

        */
result = result + 10;
/// Documentation-style comment
/// @param x The input value
/// @return The computed result
return result;
}// ============================================================================
// MAIN ENTRY POINT
// ============================================================================
int32 main;
() {

	println("=== Enma Formatter Stress Test ===");

// Test entity system
        GameWorld world;
		world.start();

	Player* player=new Player(1,"Hero");
				player.set_position(Vec3(10.0,0.0,5.0));
world.add_entity(player);

		// Test physics

  float32 fall_time=Physics::compute_fall_time(100.0);
        println(f"Fall time from 100m: {fall_time}s");

  // Test complex expressions
  int32 calc_result=complex_calculations(10,20,30);
        println(calc_result);

// Test recursion
				int64 fib20=fibonacci(20);

		println(f"Fibonacci(20)=
		{fib20}");

		// Test templates
int32 min_val=min_value(10,20);
     float32 max_val=max_value(3.14,2.71);
        println(min_val);
		println(max_val);

     // Test operators
        Vec3 a=Vec3(1.0,2.0,3.0);
Vec3 b=Vec3(4.0,5.0,6.0);
		Vec3 c=a+b;

		Vec3 d=a-b;
	Vec3 e=d*2.0;
        float32 dot=a.dot(b);

        Vec3 cross=a.cross(b);
  println(format_vector(c));
	println(format_vector(d));
				println(format_vector(e));
println(dot);
println(format_vector(cross));

// Test file ops
        file_write("output.txt","Stress test complete!");

				// Cleanup
  world.stop();
delete player;

  println("=== Test Complete ===");
        return 0;
  }

