// RUN: %clang_cc1 -std=c++2c -verify %s -fcxx-exceptions -Wno-unused -triple=x86_64-linux-gnu

inline void* operator new(__SIZE_TYPE__, void* p) noexcept { return p; }
namespace std {
template<typename T, typename... Args>
constexpr T* construct_at(T* p, Args&&... args) { return ::new((void*)p) T(static_cast<Args&&>(args)...); }
template<typename T>
constexpr void destroy_at(T* p) { p->~T(); }
template<typename T>
struct allocator {
  constexpr T* allocate(__SIZE_TYPE__ n) { return static_cast<T*>(::operator new(n * sizeof(T))); }
  constexpr void deallocate(T* p, __SIZE_TYPE__) { ::operator delete(p); }
};
}

constexpr void check_immediate() {
  if consteval {
    if (false) __builtin_is_within_lifetime(static_cast<int*>(nullptr));
  }
}
auto* not_escalated = &check_immediate;

template<typename T>
constexpr bool check_immediate2() { // #check_immediate2
  T i{};
  if (false)
    __builtin_is_within_lifetime(&i); // #check_immediate2-call
  return true;
}
static_assert(check_immediate2<int>());
auto* escalated = &check_immediate2<int>;
// expected-error@-1 {{cannot take address of immediate function 'check_immediate2<int>' outside of an immediate invocation}}
//   expected-note@#check_immediate2 {{declared here}}
//   expected-note@#check_immediate2-call {{'check_immediate2<int>' is an immediate function because its body contains a call to a consteval function '__builtin_is_within_lifetime' and that call is not a constant expression}}

consteval bool test_union(int& i, char& c) {
  if (__builtin_is_within_lifetime(&i) || __builtin_is_within_lifetime(&c))
    return false;
  std::construct_at(&c, 1);
  if (__builtin_is_within_lifetime(&i) || !__builtin_is_within_lifetime(&c))
    return false;
  std::construct_at(&i, 3);
  if (!__builtin_is_within_lifetime(&i) || __builtin_is_within_lifetime(&c))
    return false;
  return true;
}

static_assert([]{
  union { int i; char c; } u;
  return test_union(u.i, u.c);
}());
static_assert([]{
  union { int i; char c; };
  return test_union(i, c);
}());
static_assert([]{
  struct { union { int i; char c; }; } u;
  return test_union(u.i, u.c);
}());
static_assert([]{
  struct { union { int i; char c; } u; } r;
  return test_union(r.u.i, r.u.c);
}());

consteval bool test_nested() {
  union {
    union { int i; char c; } u;
    long l;
  };
  if (__builtin_is_within_lifetime(&l) || __builtin_is_within_lifetime(&u) || __builtin_is_within_lifetime(&u.i) || __builtin_is_within_lifetime(&u.c))
    return false;
  std::construct_at(&l);
  if (!__builtin_is_within_lifetime(&l) || __builtin_is_within_lifetime(&u) || __builtin_is_within_lifetime(&u.i) || __builtin_is_within_lifetime(&u.c))
    return false;
  std::construct_at(&u);
  std::construct_at(&u.i);
  if (__builtin_is_within_lifetime(&l) || !__builtin_is_within_lifetime(&u) || !__builtin_is_within_lifetime(&u.i) || __builtin_is_within_lifetime(&u.c))
    return false;
  std::construct_at(&u.c);
  if (__builtin_is_within_lifetime(&l) || !__builtin_is_within_lifetime(&u) || __builtin_is_within_lifetime(&u.i) || !__builtin_is_within_lifetime(&u.c))
    return false;
  return true;
}
static_assert(test_nested());

consteval bool test_dynamic() {
  std::allocator<int> a;
  int* p = a.allocate(1);
  if (__builtin_is_within_lifetime(p))
    return false;
  std::construct_at(p);
  if (!__builtin_is_within_lifetime(p))
    return false;
  std::destroy_at(p);
  if (__builtin_is_within_lifetime(p))
    return false;
  a.deallocate(p, 1);
  if (__builtin_is_within_lifetime(p))
    return false;
  return true;
}
static_assert(test_dynamic());

constexpr bool self = __builtin_is_within_lifetime(&self);
// expected-error@-1 {{call to consteval function '__builtin_is_within_lifetime' is not a constant expression}}
//   expected-note@-2 {{initializer of 'self' is unknown}}
//   expected-note@-3 {{declared here}}
constexpr int external{};
static_assert(__builtin_is_within_lifetime(&external));
bool not_constexpr() {
    return __builtin_is_within_lifetime(&external);
}
constexpr struct {
  union {
    int i;
    char c;
  };
  mutable int mi;  // #x-mi
} x1{ .c = 2 };
static_assert(!__builtin_is_within_lifetime(&x1.i));
static_assert(__builtin_is_within_lifetime(&x1.c));
static_assert(__builtin_is_within_lifetime(&x1.mi));
// expected-error@-1 {{static assertion expression is not an integral constant expression}}
//   expected-note@-2 {{read of mutable member 'mi' is not allowed in a constant expression}}
//   expected-note@#x-mi {{declared here}}

constexpr struct {
  bool a = __builtin_is_within_lifetime(&b);
  bool b = __builtin_is_within_lifetime(&a);
  bool c = __builtin_is_within_lifetime(this);
} x2;
static_assert(!x2.a);
static_assert(!x2.b);
static_assert(!x2.c);

struct X3 {
  bool a, b, c, d;
  consteval X3();
};
extern const X3 x3;
consteval X3::X3() : a(__builtin_is_within_lifetime(&b)), b(false), c(__builtin_is_within_lifetime(&b)) {
  b = __builtin_is_within_lifetime(&b);
  d = __builtin_is_within_lifetime(&x3.c);
}
constexpr X3 x3{};
static_assert(!x3.a);
static_assert(!x3.b);
static_assert(!x3.c);
static_assert(!x3.d);

constexpr int i = 2;
static_assert(__builtin_is_within_lifetime(const_cast<int*>(&i)));
static_assert(__builtin_is_within_lifetime(const_cast<volatile int*>(&i)));
static_assert(__builtin_is_within_lifetime(static_cast<const void*>(&i)));

constexpr int arr[2]{};
static_assert(__builtin_is_within_lifetime(arr));
static_assert(__builtin_is_within_lifetime(arr + 0));
static_assert(__builtin_is_within_lifetime(arr + 1));
void f() {
  __builtin_is_within_lifetime(&i + 1);
// expected-error@-1 {{call to consteval function '__builtin_is_within_lifetime' is not a constant expression}}
// expected-error@-2 {{'__builtin_is_within_lifetime' cannot be called with a one-past-the-end pointer}}
  __builtin_is_within_lifetime(arr + 2);
// expected-error@-1 {{call to consteval function '__builtin_is_within_lifetime' is not a constant expression}}
// expected-error@-2 {{'__builtin_is_within_lifetime' cannot be called with a one-past-the-end pointer}}
}

template<typename T>
consteval bool allow_bad_types_unless_used(bool b, T* p) {
  if (b) {
    __builtin_is_within_lifetime(p); // #bad_type_used
  }
  return true;
}
void fn();
static_assert(allow_bad_types_unless_used<void()>(false, &fn));
void g() {
  allow_bad_types_unless_used<void()>(true, &fn);
// expected-error@-1 {{call to consteval function 'allow_bad_types_unless_used<void ()>' is not a constant expression}}
// expected-error@#bad_type_used {{'__builtin_is_within_lifetime' cannot be called with a function pointer}}
}

struct OptBool {
  union { bool b; char c; };

  // note: this assumes common implementation properties for bool and char:
  // * sizeof(bool) == sizeof(char), and
  // * the value representations for true and false are distinct
  //   from the value representation for 2
  constexpr OptBool() : c(2) { }
  constexpr OptBool(bool b) : b(b) { }

  constexpr auto has_value() const -> bool {
    if consteval {
      return __builtin_is_within_lifetime(&b);   // during constant evaluation, cannot read from c
    } else {
      return c != 2;                        // during runtime, must read from c
    }
  }

  constexpr auto operator*() const -> const bool& {
    return b;
  }
};

constexpr OptBool disengaged;
constexpr OptBool engaged(true);
static_assert(!disengaged.has_value());
static_assert(engaged.has_value());
static_assert(*engaged);
