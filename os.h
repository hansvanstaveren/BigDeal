typedef unsigned int (*get_hwr)(char *, int);
int getchtm (int *);
void os_start (void);
void cooked (void);
void os_finish (void);
void cbreak (void);
void os_collect(void);
int legal_filename_prefix(char *s);
char *os_init_file_name(void);
