GETTEXT_PACKAGE := myscan

sources := $(shell sed -nre 's:^\s*([^\#]\S*)\s*$$:../\1:p' POTFILES.in)
pofiles := $(wildcard *.po)

pot := $(GETTEXT_PACKAGE).pot
mofiles := $(pofiles:%.po=../build/locale/%/LC_MESSAGES/$(GETTEXT_PACKAGE).mo)

.PHONY : all pot mo clean

all : pot mo
pot : $(pot)
mo  : $(mofiles)

$(pot) : $(sources)
	intltool-update -p --verbose -g $(GETTEXT_PACKAGE)
	for po in $(pofiles); do msgmerge -U $$po $(pot); done

../build/locale/%/LC_MESSAGES/$(GETTEXT_PACKAGE).mo : %.po $(pot)
	mkdir -p $(dir $@)
	msgfmt -o $@ $<

clean ::
	$(RM) -r ../build/locale
