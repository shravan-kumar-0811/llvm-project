#include "gtest/gtest.h"
#include "cpuid.h"

int __cpu_indicator_init(void);

extern struct __processor_model {
  unsigned int __cpu_vendor;
  unsigned int __cpu_type;
  unsigned int __cpu_subtype;
  unsigned int __cpu_features[1];
} __cpu_model;

TEST(BuiltsinCPUModelTest, TestTrue) {
  OverrideCPUID(1,0,0,4294967295);
  __cpu_model.__cpu_vendor = 0;
  __cpu_indicator_init();
  int SupportsCmov = __builtin_cpu_supports("cmov");
  ASSERT_TRUE(SupportsCmov);
}

int main(int argc, char **argv) {
  testing::InitGoogleTest(&argc, argv);
  return RUN_ALL_TESTS();
}
