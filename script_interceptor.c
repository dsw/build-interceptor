// $Id: script_interceptor.c,v 1.1 2005/02/03 02:48:45 quarl Exp $

#include <unistd.h>
#include <stdio.h>

#ifndef IPROGNAME
# error IPROGNAME needs to be defined
#endif

#ifndef INTERCEPTORPATH
# error INTERCEPTORPATH needs to be defined
#endif

int main(int argc, char **argv)
{
    argv[0] = IPROGNAME;
    execvp(INTERCEPTORPATH, argv);
    perror(IPROGNAME "_interceptor: couldn't exec " INTERCEPTORPATH);
    return 1;
}
