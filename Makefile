export PREFIX ?= /usr/local

DST := dst

.PHONY: clean install uninstall

all:

install: $(PREFIX)/bin/tal all
	mkdir -p "$(PREFIX)/lib/lua"
	mkdir -p "$(PREFIX)/bin"

	cp -r dst/* "$(PREFIX)"
	cp -r lib/* "$(PREFIX)/lib/lua"

clean:
	rm -rf dst

dst/tal:
	mkdir -p $(dir $@)
	echo '#!/usr/bin/env sh' > $@
	echo '"$(PREFIX)/bin/luajit" "$(PREFIX)/lib/lua/tal.lua" "$$@"' >> $@
	chmod +x $@
