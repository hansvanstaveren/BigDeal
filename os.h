typedef unsigned int (*get_hwr)(char *, int);
int getchtm (int *);
void os_start ();
void cooked ();
void os_finish ();
void cbreak ();
void os_collect();
int legal_filename_prefix(char *s);
char *os_init_file_name();
