typedef unsigned int (*get_hwr)(char *, int);
int getchtm (int *);
void os_start ();
void cooked ();
void os_finish ();
void cbreak ();
get_hwr os_collect(char *hw_random);
int legal_filename_prefix(char *s);
char *os_init_file_name();
