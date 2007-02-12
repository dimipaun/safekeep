name        := safekeep
timestamp   := $(shell LANG=C date)
timestamp_svn := $(shell date -u -d '$(timestamp)' '+%Y%m%dT%H%MZ')
version_num := $(shell grep 'VERSION *=' safekeep | sed s'/[^"]*"\([^"].*\)".*/\1/')
version_ts  := $(shell date -u -d '$(timestamp)' '+%Y%m%d%H%M')
version     := $(version_num)
releasename := $(name)-$(version)
snapshotname:= $(name)-$(version).$(version_ts)
tagname     := $(shell echo Release-$(releasename) | tr . _)
dirname     := $(shell basename $(PWD))
rpmroot     := $(shell grep '%_topdir' ~/.rpmmacros | sed 's/^[^ \t]*[ \t]*//')
svnroot     := $(shell LANG=C svn info | grep Root | cut -c 18-)
MAN_TXT     := doc/safekeep.txt doc/safekeep.conf.txt
DOC_MAN     := doc/safekeep.1 doc/safekeep.conf.5
DOC_HTML    := $(patsubst %.txt,%.html,$(MAN_TXT))


all: help

help:
	@echo "Targets:"
	@echo "    help        Displays this message"
	@echo "    info        Displays package information (version, tag, etc.)"
	@echo "    install     Installs safekeep and the online documentation"
	@echo "    docs        Builds all documentation formats"
	@echo "    build       Builds everything needed for an installation"
	@echo "    deb         Builds snapshot binary and source DEBs"
	@echo "    rpm         Buidls snapshot binary and source RPMs"
	@echo "    tar         Builds snapshot source distribution"
	@echo "    test        Invokes a quick local test for SafeKeep"
	@echo "    fulltest    Invokes a comprehensive remote test for SafeKeep"
	@echo "    clean       Cleans up the source tree"

info:
	@echo "Release Name   = $(releasename)"
	@echo "Snapshot Name  = $(snapshotname)"
	@echo "Version        = $(version)"
	@echo "Timestamp      = $(timestamp)"
	@echo "Tag            = $(tagname)"
	@echo "RPM Root       = $(rpmroot)"
	@echo "SVN Root       = $(svnroot)"


build: docs

release: check-info commit-release tag-release rpm-release

commit-release:
	svn ci -m "Release $(version) (tagged as $(tagname))"

tag-release:
	svn cp . $(svnroot)/safekeep/tags/$(tagname)

check-info: info
	@echo -n 'Is this information correct? (yes/No) '
	@read x; if [ "$$x" != "yes" ]; then exit 1; fi

docs: html man

html: $(DOC_HTML)

man: $(DOC_MAN)

%.html: %.txt
	asciidoc -b xhtml11 -d manpage -f doc/asciidoc.conf $<

%.1 %.5: %.xml
	xmlto -o doc -m doc/callouts.xsl man $<

%.xml: %.txt
	asciidoc -b docbook -d manpage -f doc/asciidoc.conf $<

$(DOC_HTML) $(DOC_MAN): doc/asciidoc.conf

changelog:
	svn log -v --xml | svn2log.py -D 0 -u doc/users

install: $(DOC_MAN)
	install -m 755 safekeep "/usr/bin/"
	install -m 755 doc/safekeep.1 "/usr/share/man/man1/"
	install -m 755 doc/safekeep.conf.5 "/usr/share/man/man5/"

tar: tar-snapshot

tar-snapshot:
	svn export -r {'$(timestamp_svn)'} $(svnroot)/safekeep/trunk $(snapshotname)
	cat $(snapshotname)/$(name).spec.in | sed 's/^%define version.*/%define version $(version).$(version_ts)/' > $(snapshotname)/$(name).spec
	cat $(snapshotname)/debian/changelog.in | sed 's/^safekeep.*/safekeep ($(version).$(version_ts)) unstable; urgency=low/' > $(snapshotname)/debian/changelog
	tar cz -f $(snapshotname).tar.gz $(snapshotname)
	rm -rf $(snapshotname)

tar-release:
	svn export $(svnroot)/safekeep/tags/$(tagname) $(releasename)
	cat $(releasename)/$(name).spec.in | sed 's/^%define version.*/%define version $(version)/' > $(releasename)/$(name).spec
	cat $(releasename)/debian/changelog.in | sed 's/^safekeep.*/safekeep ($(version)) unstable; urgency=low/' > $(releasename)/debian/changelog
	tar cz -f $(releasename).tar.gz $(releasename)
	rm -rf $(releasename)

deb: deb-snapshot

deb-snapshot: tar-snapshot
	tar xz -C /tmp -f $(snapshotname).tar.gz
	rm -rf $(snapshotname).tar.gz
	cd /tmp/$(snapshotname) && debuild --check-dirname-regex 'safekeep(-.*)?'

deb-release: tar-release
	tar xz -C /tmp -f $(releasename).tar.gz
	rm -rf $(releasename).tar.gz
	cd /tmp/$(releasename) && debuild --check-dirname-regex 'safekeep(-.*)?'

rpm: rpm-snapshot

rpm-snapshot: tar-snapshot
	rpmbuild -ta $(snapshotname).tar.gz

rpm-release: tar-release
	rpmbuild -ta $(releasename).tar.gz

test: test-local

fulltest: test-remote

test-local:
	safekeep-test --local

test-remote:
	safekeep-test --remote

clean:
	rm -f {.,doc,debian}/*~ *.py[co] 
	rm -f $(name).spec debian/changelog
	rm -f doc/*.xml doc/*.html doc/*.[15]
