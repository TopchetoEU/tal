.PHONY: clean install-mods install

install: clean install-mods
	luajit build/init.lua --linux

install-mods: clean
	rm -rf ~/.local/lib/.tal_mod
	mkdir -p ~/.local/lib/.tal_mod
	cp -r mod/* ~/.local/lib/.tal_mod/

clean:
	rm -rf ~/.local/bin/tal
	rm -rf ~/.local/lib/.tal_mod
