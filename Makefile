NAME	=	lltag
ifeq ($(shell [ -d .svn ] && echo 1),1)
	VERSION	=	$(shell cat VERSION)+svn
else
	VERSION	=	$(shell cat VERSION)
endif

.PHONY: lltag clean install uninstall tarball

DESTDIR	=	
PREFIX	=	/usr/local
EXEC_PREFIX	=	$(PREFIX)
BINDIR	=	$(EXEC_PREFIX)/bin
DATADIR	=	$(PREFIX)/share
SYSCONFDIR	=	$(PREFIX)/etc
MANDIR	=	$(PREFIX)/man

TARBALL	=	$(NAME)-$(VERSION)
DEBIAN_TARBALL	=	$(NAME)_$(VERSION).orig

lltag::
	sed -e 's!@SYSCONFDIR@!$(DESTDIR)$(SYSCONFDIR)!g' -e 's!@VERSION@!$(DESTDIR)$(VERSION)!g' < lltag.in > lltag

clean::
	rm -f lltag

install::
	install -d -m 0755 $(DESTDIR)$(BINDIR)/ $(DESTDIR)$(SYSCONFDIR)/lltag/ $(DESTDIR)$(MANDIR)/man1/
	install -m 0755 lltag $(DESTDIR)$(BINDIR)/lltag
	install -m 0644 formats $(DESTDIR)$(SYSCONFDIR)/lltag/
	install -m 0644 config $(DESTDIR)$(SYSCONFDIR)/lltag/
	install -m 0644 lltag.1 $(DESTDIR)$(MANDIR)/man1/

uninstall::
	rm $(DESTDIR)$(BINDIR)/lltag
	rm $(DESTDIR)$(SYSCONFDIR)/lltag/formats
	rm $(DESTDIR)$(SYSCONFDIR)/lltag/config
	rmdir $(DESTDIR)$(SYSCONFDIR)/lltag/
	rm $(DESTDIR)$(MANDIR)/man1/lltag.1

tarball::
	mkdir /tmp/$(TARBALL)
	cp lltag.in /tmp/$(TARBALL)
	cp formats /tmp/$(TARBALL)
	cp config /tmp/$(TARBALL)
	cp lltag.1 /tmp/$(TARBALL)
	cp Makefile /tmp/$(TARBALL)
	cp COPYING /tmp/$(TARBALL)
	cp README /tmp/$(TARBALL)
	cp VERSION /tmp/$(TARBALL)
	cp Changes /tmp/$(TARBALL)
	cd /tmp && tar cfz $(DEBIAN_TARBALL).tar.gz $(TARBALL)
	cd /tmp && tar cfj $(TARBALL).tar.bz2 $(TARBALL)
	mv /tmp/$(DEBIAN_TARBALL).tar.gz /tmp/$(TARBALL).tar.bz2 ..
	rm -rf /tmp/$(TARBALL)
