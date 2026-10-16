export PREFIX ?= /usr/local

DST := dst

.PHONY: clean install uninstall

all:

install: all
	mkdir -p "$(PREFIX)/lib/lua"
	mkdir -p "$(PREFIX)/bin"

# 	cp -r dst/* "$(PREFIX)"
	cp -r lib/* "$(PREFIX)/lib/lua"
	cp -r bin/* "$(PREFIX)/bin"

clean:
	rm -rf dst
