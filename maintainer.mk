all :: target

Makefile: maintainer.mk

target: source
	cat source >$@
