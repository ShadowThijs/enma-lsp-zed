// strings.em — string utilities
import "math.em";

int32 strlen(string s) {
	int32 count = 0;
	for (int32 i = 0; s[i] != 0; i = i + 1) {
		count = count + 1;
	}
	return mul(count, 1); // use mul from math.em
}
