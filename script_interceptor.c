// $Id: script_interceptor.c,v 1.2 2005/03/03 06:19:50 quarl Exp $

// This dummy wrapper just exists because bash can't use a script to execute
// another shebang script (not all shells have this limitation)

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
