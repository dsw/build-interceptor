// Build-Interceptor LD_PRELOAD mode.
//
//   This is the shared library portion of the implementation.
//
//   It simply calls replaces all execve() calls with an execve call to
//   $BUILD_INTERCEPTOR_LDPRELOAD_SCRIPT, which decides whether to then
//   instead call an interceptor script, or call the original intended script
//   with LD_PRELOAD set.
//
//   Based on implementation by Peter Hawkins <hawkinsp@cs.stanford.edu>

#define _GNU_SOURCE 1

#include <sys/types.h>
#include <sys/stat.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <ctype.h>
#include <errno.h>
#include <assert.h>
#include <dlfcn.h>
#include <unistd.h>

#define MAX_ENV_STRINGS 1024
#define PATH_MAX 1024

extern size_t strlcpy(char *dst, char const *src, size_t siz);

/* Pointers to the libc versions of the functions we are initializing.
 * These are lazily initialized on the first use
 */
static int (*real_execve)(const char *, char *const [], char * const []) = NULL;

static char build_interceptor_ldpreload_script[1024];

static char env_ld_preload[1024+sizeof("LD_PRELOAD=")] = "LD_PRELOAD=";

static int initialized_success = 0;

/* Print an error message and abort execution */
static void
die(const char *fmt, ...)
{
    va_list args;

    va_start(args, fmt);
    fprintf(stderr, "build-interceptor preload_helper.so: ");
    vfprintf(stderr, fmt, args);
    va_end(args);
    abort();
}

/* Set *fptr to the address of libc symbol name, aborting the program if
 * the symbol cannot be found */
static void
load_symbol(void **fptr, const char *name)
{
    assert(fptr != NULL && name != NULL);
    *fptr = dlsym(RTLD_NEXT, name);
    if (*fptr == NULL) {
        die("Couldn't locate symbol \"%s\" (%s).\n",
            name, dlerror());
    }
}

/* Library initialization function. Called automatically when the library
 * is loaded */
static void __attribute__((constructor))
initialize(void)
{
    /* Find the addresses of the real copies of the symbols we are faking */
    load_symbol((void **)&real_execve, "execve");

    // This is the helper script to call
    char const *BUILD_INTERCEPTOR_LDPRELOAD_SCRIPT = getenv("BUILD_INTERCEPTOR_LDPRELOAD_SCRIPT");
    if (!BUILD_INTERCEPTOR_LDPRELOAD_SCRIPT) {
        die("Missing $BUILD_INTERCEPTOR_LDPRELOAD_SCRIPT\n");
    }

    strlcpy(build_interceptor_ldpreload_script, BUILD_INTERCEPTOR_LDPRELOAD_SCRIPT, sizeof(build_interceptor_ldpreload_script));

    // Reset LD_PRELOAD to its value before we messed with it.
    // build-interceptor-ldpreload will add it as needed.
    char const *BUILD_INTERCEPTOR_ORIG_LD_PRELOAD = getenv("BUILD_INTERCEPTOR_ORIG_LD_PRELOAD");
    if (!BUILD_INTERCEPTOR_ORIG_LD_PRELOAD) {
        BUILD_INTERCEPTOR_ORIG_LD_PRELOAD = "";
    }
    setenv("LD_PRELOAD", BUILD_INTERCEPTOR_ORIG_LD_PRELOAD, 1);
    strlcpy(env_ld_preload+sizeof("LD_PRELOAD=")-1,
            BUILD_INTERCEPTOR_ORIG_LD_PRELOAD, sizeof(env_ld_preload)-(sizeof("LD_PRELOAD=")));
    initialized_success = 1;
}

void copy_argv(char **new_argv, char * const * argv, int max)
{
    int count = 0;
    while (*argv && count < max) {
        *new_argv++ = *argv++;
        count++;
    }
    *new_argv = NULL;
}

// remove LD_PRELOAD from the environment that's passed to execve -- this is
// often different from 'environ' which setenv messes with, e.g. in sh.
char **fudge_env(char * const *env)
{
    int i = 0;
    while (env[i]) {
        ++i;
    }
    char **new_env = malloc((i+3) * sizeof(char*));
    // static char *new_env[MAX_ENV_STRINGS];

    i = 0;
    while (env[i]) {
        if (0==strncmp(env[i],"LD_PRELOAD=", sizeof("LD_PRELOAD=")-1)) {
            // fprintf(stderr, "## replaced %s with %s\n", env[i], env_ld_preload);
            new_env[i] = env_ld_preload;
        } else {
            new_env[i] = env[i];
        }
        ++i;
        if (i >= MAX_ENV_STRINGS-1) {
            break;
        }
    }
    new_env[i] = 0;
    return new_env;
}

int
execve(const char *filename, char *const argv[], char *const env[])
{
    if (!initialized_success) {
        die("execve after failed initialization");
    }

    if (getenv("BUILD_INTERCEPTOR_DEBUG")) {
        fprintf(stderr, "build-interceptor preload_helper.so: execve");
        char * const *p = argv;
        while (*p) {
            fprintf(stderr, " %s", *p++);
        }
        fprintf(stderr, "\n");
    }

    if (0 != access(filename, X_OK)) {
        // file doesn't exist, or not executable, etc.
        //
        // Exit now since the build_interceptor_ldpreload_script exec is going
        // to succeed even if filename doesn't exist.
        return -1;
    }

    char *newargv[MAX_ENV_STRINGS];

    newargv[0] = build_interceptor_ldpreload_script;
    newargv[1] = (char*) filename;
    newargv[2] = "--argv0";
    copy_argv(newargv+3, argv, MAX_ENV_STRINGS-4);

    if (getenv("BUILD_INTERCEPTOR_DEBUG")) {
        fprintf(stderr, "build-interceptor preload_helper.so: real_execve");
        char **p = newargv;
        while (*p) {
            fprintf(stderr, " %s", *p++);
        }
        fprintf(stderr, "\n");
    }

    env = fudge_env(env);

    return real_execve(newargv[0], (char**) newargv, env);
}

int
execv(const char *filename, char *const argv[])
{
    return execve(filename, argv, environ);
}

int
execvp(const char *filename, char *const argv[])
{
    char newfile[PATH_MAX];
    int len;
    const char *path;
    const char *next;

    /* If the specified filename contains a slash character, execvp does
     * not seach the PATH. */
    if (strchr(filename, '/') != NULL)
        return execve(filename, argv, environ);


    /* Seach the directories specified in the PATH environment for the
     * file filename. We have to do this ourselves since we do our mapping
     * on the absolute filename. */

    /* Fetch the PATH environment variable, using the libc default if
     * it doesn't exist */
    path = getenv("PATH");
    if (path == NULL)
        path = ":/bin:/usr/bin";

    while (path[0] != 0) {
        next = strchr(path, ':');
        if (next == NULL)
            next = path + strlen(path);

        len = (int)(next - path);
        if (len > PATH_MAX)
            len = PATH_MAX;

        if (len == 0) {
            /* Empty path segment means current working directory */
            getcwd(newfile, PATH_MAX);
            len = strlen(newfile);
        } else {
            memcpy(newfile, path, len);
        }
        /* Add a trailing slash, if necessary */
        if (len > 0 && newfile[len - 1] != '/')
            newfile[len++] = '/';
        newfile[len] = 0;

        strncat(newfile, filename, PATH_MAX - len - 1);

        /* Try to execute this file. If this works, execve will not
         * return */
        execve(newfile, argv, environ);

        path = next;
        if (*path == ':') path++;
    }

    errno = ENOENT;
    return -1;

}

int
execl(const char *filename, const char *arg0, ...)
{
    va_list arg_list;
    char *args[MAX_ENV_STRINGS], *a;
    int i;

    va_start(arg_list, arg0);

    args[0] = (char *)arg0;
    a = va_arg(arg_list, char *const);
    i = 1;
    while (a != NULL && i < MAX_ENV_STRINGS) {
        args[i] = a;
        i++;
        a = va_arg(arg_list, char *const);
    }
    args[i] = NULL;

    va_end(arg_list);
    return execve(filename, args, environ);
}

int
execle(const char *filename, const char *arg0, ...)
{
    va_list arg_list;
    char *args[MAX_ENV_STRINGS], *a;
    char * const * env;
    int i;

    va_start(arg_list, arg0);
    args[0] = (char *)arg0;
    a = va_arg(arg_list, char *const);
    i = 1;
    while (a != NULL && i < MAX_ENV_STRINGS) {
        args[i] = a;
        i++;
        a = va_arg(arg_list, char *const);
    }
    args[i] = NULL;
    env = va_arg(arg_list, char * const *);

    va_end(arg_list);
    return execve(filename, args, env);
}

int
execlp(const char *filename, const char *arg0, ...)
{
    va_list arg_list;
    char *args[MAX_ENV_STRINGS], *a;
    int i;

    va_start(arg_list, arg0);
    args[0] = (char *)arg0;
    a = va_arg(arg_list, char *const);
    i = 1;
    while (a != NULL && i < MAX_ENV_STRINGS) {
        args[i] = a;
        i++;
        a = va_arg(arg_list, char *const);
    }
    args[i] = NULL;

    va_end(arg_list);
    return execvp(filename, args);
}
