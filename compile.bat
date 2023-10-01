cl /Fe: bigdeal.exe /D NOTX /I . main.c getopt.c collect.c output.c rmd160.c mp.c binomial.c windows.c /link advapi32.lib
cl /Fe: bigdealx.exe /D BIGDEALX /I . main.c getopt.c collect.c output.c rmd160.c mp.c binomial.c windows.c /link advapi32.lib
main
