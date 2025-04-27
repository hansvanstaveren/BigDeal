#define HASH_RMD160
#undef  HASH_SHA256

#ifdef HASH_RMD160
/*
 * Old hash defs
 */

#define RMDsize 160
#define RMDbytes (RMDsize/8)
#define RMDdwords (RMDsize/32)

#define HASHsize RMDsize
#define HASHbytes RMDbytes
#define HASHdwords RMDdwords
#endif

#ifdef HASH_SHA256
/*
 * New hash defs
 */

#define HASHsize 256
#define HASHbytes (HASHsize/8)
#define HASHdwords (HASHsize/32)
#endif
