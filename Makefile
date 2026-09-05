export PREFIX ?= /usr/local

LUAJIT_LIBS := deps/luajit/src/libluajit.a deps/luajit/src/libluajit.so
LUAJIT_EXE := deps/luajit/src/luajit
LUAJIT_MK := deps/luajit/Makefile

OS ?= $(shell uname)

LIBEV_LIBS := deps/libyaooi/bin/$(OS)/libyaooi.a deps/libyaooi/bin/$(OS)/libyaooi.so
LIBEV_MK := deps/libyaooi/Makefile

LIBS := $(LUAJIT_LIBS)

ifneq ($(SYSLIBS),yes)
	LIBS += $(LIBEV_LIBS)
endif

.PHONY: luajit clean install uninstall

all: $(LIBS) $(LUAJIT_EXE) $(PREFIX)/lib/lua/nat/libhook.so

install: $(PREFIX)/bin/tal all
	mkdir -p "$(PREFIX)/bin"
	mkdir -p "$(PREFIX)/lib"
	mkdir -p "$(PREFIX)/lib/lua"

	cp $(LUAJIT_EXE) "$(PREFIX)/bin/"
	cp $(LIBS) "$(PREFIX)/lib"
	cp -r deps/luajit/src/jit "$(PREFIX)/lib/lua/"
	cp -r lib/* "$(PREFIX)/lib/lua"

clean: $(LUAJIT_MK) $(LIBEV_MK)
	$(MAKE) -C deps/luajit clean
	$(MAKE) -C deps/libyaooi clean
	rm -rf bin

$(PREFIX)/lib/lua/nat/libhook.so: src/hook.c deps/luajit/src/libluajit.so
	mkdir -p $(dir $@)
	gcc -shared $^ -Ideps/luajit/src -o $@

$(PREFIX)/bin/tal:
	mkdir -p $(dir $@)
	echo '#!/usr/bin/env sh' > $@
	echo '"$(PREFIX)/bin/luajit" "$(PREFIX)/lib/lua/tal.lua" "$$@"' >> $@
	chmod +x $@

$(LUAJIT_MK):
	git submodule update --init deps/luajit
$(LUAJIT_EXE) $(LUAJIT_LIBS)&: $(LUAJIT_MK)
	$(MAKE) -C deps/luajit XCFLAGS=-DLUAJIT_ENABLE_LUA52COMPAT

$(LIBEV_MK):
	git submodule update --init deps/libyaooi
$(LIBEV_LIBS)&: $(LIBEV_MK)
	$(MAKE) -C deps/libyaooi
