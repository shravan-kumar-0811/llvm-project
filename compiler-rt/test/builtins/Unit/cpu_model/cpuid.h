void OverrideCPUID(unsigned int EAX, unsigned int EBX, unsigned int ECX, unsigned int EDX);

int __get_cpuid(unsigned int leaf, unsigned int *__eax, unsigned int *__ebx, unsigned int *__ecx, unsigned int *__edx);

int __get_cpuid_count(unsigned int __leaf, unsigned int __subleaf, unsigned int *__eax, unsigned int *__ebx, unsigned int *__ecx, unsigned int *__edx);