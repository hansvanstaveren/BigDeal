#include <stdint.h>

typedef unsigned char byte;
typedef uint32_t dword;			/* not unsigned long, because of 64 bit words implementations */

#define RMDsize 160
#define RMDbytes (RMDsize/8)
#define RMDdwords (RMDsize/32)
