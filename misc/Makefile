# timestamp the $HOME/build-interceptor.log; useful to run between
# compilations
.PHONY: stamp-log
stamp-log: stamp-log/---
.PHONY: stamp-log/%
stamp-log/%:
	echo >> ${HOME}/build-interceptor.log
	date >> ${HOME}/build-interceptor.log
	echo '$*' >> ${HOME}/build-interceptor.log
	echo >> ${HOME}/build-interceptor.log

.PHONY: clean-build-interceptor
clean-build-interceptor: clean-build-interceptor-tmp clean-preproc

.PHONY: clean-build-interceptor-tmp
clean-build-interceptor-tmp:
	rm -rf ${HOME}/build-interceptor-tmp

.PHONY: clean-preproc
clean-preproc:
	rm -rf ${HOME}/preproc/*
