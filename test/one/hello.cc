#include <iostream>
using namespace std;

extern "C" {
  #include "waga.h"
}

int main() {
  cout << "Hello, World!" << endl;
  foo();
  return 0;
}
