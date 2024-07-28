#include "CPUIDOverride.h"

unsigned OverrideEAX = 0;
unsigned OverrideEBX = 0;
unsigned OverrideECX = 0;
unsigned OverrideEDX = 0;

void OverrideCPUID(unsigned int EAX, unsigned int EBX, unsigned int ECX, unsigned int EDX) {
  OverrideEAX = EAX;
  OverrideEBX = EBX;
  OverrideECX = ECX;
  OverrideEDX = EDX;
}

int __get_cpuid(unsigned int leaf, unsigned int *__eax, unsigned int *__ebx, unsigned int *__ecx, unsigned int *__edx) {
  *__eax = OverrideEAX;
  *__ebx = OverrideEBX;
  *__ecx = OverrideECX;
  *__edx = OverrideEDX;

  return 0;
}

int __get_cpuid_count(unsigned int __leaf, unsigned int __subleaf, unsigned int *__eax, unsigned int *__ebx, unsigned int *__ecx, unsigned int *__edx) {
  *__eax = OverrideEAX;
  *__ebx = OverrideEBX;
  *__ecx = OverrideECX;
  *__edx = OverrideEDX;

  return 0;
}