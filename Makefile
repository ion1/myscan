.PHONY : all locale clean

all : locale build/myscan build/myscan.desktop
locale ::
	make -C po mo

build/myscan : myscan.sh
	mkdir -p build
	install -m0755 $< $@

build/myscan.desktop : myscan.desktop.in
	mkdir -p build
	intltool-merge -d po $< $@

clean ::
	$(RM) -r build
