SHELL    = /bin/sh
PREFIX   = /usr/local
execdir  = $(PREFIX)/bin
libdir   = $(PREFIX)/lib

all: install

install:
	install -d "$(execdir)"
	install -d "$(libdir)/hostnamer"
	install ./lib/hostnamer/hostnamer.rb "$(libdir)/hostnamer/hostnamer.rb"
	install -m 0755 ./bin/hostnamer "${execdir}"

uninstall:
	rm -rf "$(libdir)/hostnamer"
	rm -r "${execdir}/hostnamer"

