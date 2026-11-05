export PREFIX ?= /usr/local

DST := dst

.PHONY: clean install uninstall

all: $(PREFIX)/lib/lua/nat/libhook.so

install: all
	mkdir -p "$(PREFIX)/lib/lua"
	mkdir -p "$(PREFIX)/bin"

	cp -r dst/* "$(PREFIX)"
	cp -r lib/* "$(PREFIX)/lib/lua"
	cp -r bin/* "$(PREFIX)/bin"

clean:
	rm -rf dst

$(DST)/lib/lua/nat/libhook.so: src/hook.c
	mkdir -p $(dir $@)
	gcc -shared -lluajit -Ideps/luajit/src -o $@
