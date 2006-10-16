
# config file for PRAT (see http://www.cubewano.org/prat/)

PROJ_NAME = 'build-interceptor'

REPO_BASE = 'https://build-interceptor.tigris.org/svn/%(PROJ_NAME)s'%locals()

REPO_TRUNK = '%(REPO_BASE)s/trunk'%locals()
REPO_TAG_DIR = '%(REPO_BASE)s/tags'%locals()

RELEASES_DIR = '/home/quarl/proj/%(PROJ_NAME)s/www/releases'%locals()

DOC_OUTPUT = '/home/quarl/proj/%(PROJ_NAME)s/www/releases.htxt'%locals()
DOC_URL_DOWNLOAD_PREFIX = 'releases/'
