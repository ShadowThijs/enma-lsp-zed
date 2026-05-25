class Foo { void run() {} }
Foo* g = null;
namespace ns {
    void f() {
        g.run();
    }
}
int64 main() { return 0; }
