export PREFIX ?= /usr/local

LUAJIT_LIBS := deps/luajit/src/libluajit.a deps/luajit/src/libluajit.so
LUAJIT_EXE := deps/luajit/src/luajit
LUAJIT_MK := deps/luajit/Makefile

OS ?= $(shell uname)

LIBEV_LIBS := \
	deps/libev/bin/$(OS)/libev.a deps/libev/bin/$(OS)/libev.so \
	deps/libev/bin/$(OS)/libev-dyn.a deps/libev/bin/$(OS)/libev-dyn.so
LIBEV_MK := deps/libev/Makefile

LIBSODIUM_LIB := deps/libsodium/src/libsodium/.libs/libsodium.a
LIBSODIUM_SO := bin/libsodium.so
LIBSODIUM_MK := deps/libsodium/Makefile

LIBS := $(LUAJIT_LIBS)

ifneq ($(SYSLIBS),yes)
	LIBS += $(LIBEV_LIBS) $(LIBSODIUM_SO) $(LIBSODIUM_LIB)
endif

.PHONY: luajit build clean install uninstall

install: build
	mkdir -p "$(PREFIX)/bin"
	mkdir -p "$(PREFIX)/lib"
	mkdir -p "$(PREFIX)/lib/lua"

	cp $(LUAJIT_EXE) "$(PREFIX)/bin/"
	cp $(LIBS) "$(PREFIX)/lib"
	cp -r lib/* "$(PREFIX)/lib/lua"

	cp bin/tal "$(PREFIX)/bin/tal"
clean: $(LUAJIT_MK) $(LIBEV_MK)
	$(MAKE) -C deps/luajit clean
	$(MAKE) -C deps/libev clean
	$(MAKE) -C deps/libsodium clean
	rm -rf bin

build: bin/tal $(LIBS) $(LUAJIT_EXE)

bin/tal:
	mkdir -p bin
	echo "#!$(PREFIX)/bin/luajit" > bin/tal
	echo 'local ffi = require "ffi";' >> bin/tal
	echo "ffi.path = \"$(PREFIX)/lib/lib?.so;$(PREFIX)/lib/?\";" >> bin/tal
	echo "return require \"tal.entry\" (...);" >> bin/tal
	chmod +x bin/tal

$(LUAJIT_MK):
	git submodule update --init deps/luajit
$(LUAJIT_EXE) $(LUAJIT_LIBS)&: $(LUAJIT_MK)
	$(MAKE) -C deps/luajit XCFLAGS=-DLUAJIT_ENABLE_LUA52COMPAT

$(LIBEV_MK):
	git submodule update --init deps/libev
$(LIBEV_LIBS)&: $(LIBEV_MK)
	$(MAKE) -C deps/libev

$(LIBSODIUM_MK):
	git submodule update --init deps/libsodium
$(LIBSODIUM_LIB)&: $(LIBSODIUM_MK)
	cd deps/libsodium && ./autogen.sh -s && ./configure
	$(MAKE) -C deps/libsodium
	mkdir -p bin
$(LIBSODIUM_SO): $(LIBSODIUM_LIB)
	mkdir -p bin
	gcc $^ -shared -o $@
