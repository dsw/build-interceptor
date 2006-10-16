// $Id$

// This is just a dummy compiled wrapper for another non-compiled program.  It
// just exists because bash can't use a script to execute another shebang
// script (other shells, such as zsh, don't have this limitation).  This is
// used for rename-mode make_interceptor.

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
    execv(INTERCEPTORPATH, argv);
    perror(IPROGNAME "_interceptor: couldn't exec " INTERCEPTORPATH);
    return 1;
}
