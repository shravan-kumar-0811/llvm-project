// RUN: %clang_cc1 -std=c++20 -Wunsafe-buffer-usage \
// RUN:            -fsafe-buffer-usage-suggestions -verify %s

using size_t = __typeof(sizeof(int));

namespace std {
  class type_info;
  class bad_cast;
  class bad_typeid;

  template <typename T> class span {

  private:
    T *elements;
    size_t size_;

  public:
    span(T *, size_t){}

    constexpr T* data() const noexcept {
      return elements;
    }

    constexpr size_t size() const noexcept {
      return size_;
    }

  };
}

struct A {
    [[clang::unsafe_buffer_usage]]
    int *ptr;

    size_t sz;
};

struct B {
   A a;
 
   [[clang::unsafe_buffer_usage]]
   int buf[];
};

union Union {
  [[clang::unsafe_buffer_usage]]
  int *ptr1;

  int ptr2;
};

struct C {
  Union ptr; 
};

struct D { 
  [[clang::unsafe_buffer_usage]]
  int *ptr, *ptr2;

  [[clang::unsafe_buffer_usage]]
  int buf[10];
 
  size_t sz;
  
};

void foo(int *ptr);

void foo_safe(std::span<int> sp);

void test_attribute_union(C c) {
  int *p = c.ptr.ptr1; //expected-warning{{field ptr1 prone to unsafe buffer manipulation}}

  // TODO: Warn here about the field
  int address = c.ptr.ptr2;
}

int* test_atribute_struct(A a) {
   int b = *(a.ptr); //expected-warning{{field ptr prone to unsafe buffer manipulation}}
   a.sz++;
   // expected-warning@+1{{unsafe pointer arithmetic}}
   return a.ptr++; //expected-warning{{field ptr prone to unsafe buffer manipulation}}
}

void test_attribute_field_deref_chain(B b) {
  int *ptr = b.a.ptr;//expected-warning{{field ptr prone to unsafe buffer manipulation}} 
  foo(b.buf); //expected-warning{{field buf prone to unsafe buffer manipulation}}
}

void test_safe_writes(std::span<int> sp) {
  A a;
  // TODO: We should not warn for safe assignments from hardened types
  a.ptr = sp.data(); //expected-warning{{field ptr prone to unsafe buffer manipulation}}
  a.sz = sp.size();
}

void test_safe_reads(A a) {
  //expected-warning@+1{{the two-parameter std::span construction is unsafe as it can introduce mismatch between buffer size and the bound information}}
  std::span<int> sp {a.ptr, a.sz}; //expected-warning{{field ptr prone to unsafe buffer manipulation}}
  foo_safe(sp);
}

void test_attribute_multiple_fields (D d) {
   int *p =d.ptr; //expected-warning{{field ptr prone to unsafe buffer manipulation}}
   p = d.ptr2; //expected-warning{{field ptr2 prone to unsafe buffer manipulation}}

   p = d.buf; //expected-warning{{field buf prone to unsafe buffer manipulation}}

   int v = d.buf[0]; //expected-warning{{field buf prone to unsafe buffer manipulation}}

   //expected-warning@+1{{unsafe buffer access}}
   v = d.buf[5]; //expected-warning{{field buf prone to unsafe buffer manipulation}}
}
