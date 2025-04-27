#define HASH_RMD160
#undef  HASH_SHA256

#ifdef HASH_RMD160
/*
 * Old hash defs
 */

#define RMDsize 160
#define RMDbytes (RMDsize/8)
#define RMDdwords (RMDsize/32)
#endif

#ifdef HASH_SHA256
/*
 * New hash defs
 */

#define RMDsize 256
#define RMDbytes (RMDsize/8)
#define RMDdwords (RMDsize/32)
#endif
