# $Id: version.py 148 2006-09-22 01:30:23Z quarl $

import subprocess

def pipefrom(cmd):
    return subprocess.Popen(cmd, stdout=subprocess.PIPE).communicate()[0]

version = pipefrom(['../build-interceptor-version', '-n'])
