name        := safekeep
timestamp   := $(shell LANG=C date)
timestamp_svn := $(shell date -u -d '$(timestamp)' '+%Y%m%dT%H%MZ')
version_num := $(shell grep 'VERSION *=' safekeep | sed s'/[^"]*"\([^"].*\)".*/\1/')
version_ts  := $(shell date -u -d '$(timestamp)' '+%Y%m%d%H%M')
version     := $(version_num)
release     := 1
releasename := $(name)-$(version)
snapshotname:= $(name)-$(version).$(version_ts)
tagname     := $(shell echo Release-$(releasename) | tr . _)
dirname     := $(shell basename $(PWD))
rpmroot     := $(shell grep '%_topdir' ~/.rpmmacros 2>/dev/null | sed 's/^[^ \t]*[ \t]*//')
svnroot     := $(shell LANG=C svn info 2>/dev/null | grep Root | cut -c 18-)
releasedir  := releases
repo_srv    := root@ulysses
repo_dir    := /var/www/repos/lattica
webroot     := ../website/WebContent/
MAN_TXT     := doc/safekeep.txt doc/safekeep.conf.txt doc/safekeep.backup.txt
DOC_MAN     := doc/safekeep.1 doc/safekeep.conf.5 doc/safekeep.backup.5
DOC_HTML    := $(patsubst %.txt,%.html,$(MAN_TXT))


all: help

help:
	@echo "Targets:"
	@echo "    help        Displays this message"
	@echo "    info        Displays package information (version, etc.)"
	@echo "    install     Installs safekeep and the online documentation"
	@echo "    docs        Builds all documentation formats"
	@echo "    web         Updates the website to the latest documentation"
	@echo "    build       Builds everything needed for an installation"
	@echo "    tar         Builds snapshot source distribution"
	@echo "    deb         Builds snapshot binary and source DEBs"
	@echo "    rpm         Buidls snapshot binary and source RPMs"
	@echo "    tag         Tags the source for release"
	@echo "    dist        Builds release source distribution"
	@echo "    distdeb     Builds release binary and source DEBs"
	@echo "    distrpm     Buidls release binary and source RPMs"
	@echo "    deploy      Deployes the release RPMs to Lattica's repos"
	@echo "    check       Invokes a quick local test for SafeKeep"
	@echo "    test        Invokes a comprehensive remote test for SafeKeep"
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

release: check-info commit-release dist distrpm

deploy: deploy-lattica deploy-sf

commit-release:
	svn ci -m "Release $(version) (tagged as $(tagname))"

tag:
	svn cp -m "Tag safekeep $(version)" . $(svnroot)/safekeep/tags/$(tagname)

check-info: info
	@echo -n 'Is this information correct? (yes/No) '
	@read x; if [ "$$x" != "yes" ]; then exit 1; fi

web: html
	cp doc/*.html $(webroot)
	cd  $(webroot); svn ci -m "Update man pages on website to latest as of $(timestamp)"

docs: html man

html: $(DOC_HTML)

man: $(DOC_MAN)

%.html: %.txt
	asciidoc -b html4 -d manpage -f doc/asciidoc.conf $<

%.1 %.5: %.xml
	xmlto -o doc -m doc/callouts.xsl man $<

%.xml: %.txt
	asciidoc -b docbook -d manpage -f doc/asciidoc.conf $<

$(DOC_HTML) $(DOC_MAN): doc/asciidoc.conf

changelog:
	svn log -v --xml | svn2log.py -D 0 -u doc/users

install:
	install -m 755 safekeep "/usr/bin/"
	install -d -m 755 "/etc/safekeep/backup.d/"
	install -m 755 safekeep.conf "/etc/safekeep/"
	install -m 755 doc/safekeep.1 "/usr/share/man/man1/"
	install -m 755 doc/safekeep.conf.5 "/usr/share/man/man5/"
	install -m 755 doc/safekeep.backup.5 "/usr/share/man/man5/"

tar:
	svn export -r {'$(timestamp_svn)'} $(svnroot)/safekeep/trunk $(snapshotname)
	cat $(snapshotname)/$(name).spec.in | sed 's/^%define version.*/%define version $(version).$(version_ts)/' > $(snapshotname)/$(name).spec
	cat $(snapshotname)/debian/changelog.in | sed 's/^safekeep.*/safekeep ($(version).$(version_ts)) unstable; urgency=low/' > $(snapshotname)/debian/changelog
	tar cz -f $(snapshotname).tar.gz $(snapshotname)
	rm -rf $(snapshotname)

deb: tar
	tar xz -C /tmp -f $(snapshotname).tar.gz
	rm -rf $(snapshotname).tar.gz
	cd /tmp/$(snapshotname) && debuild --check-dirname-regex 'safekeep(-.*)?'

rpm: tar
	rpmbuild -ta $(snapshotname).tar.gz
	mv $(rpmroot)/SRPMS/$(snapshotname)-$(release)*.src.rpm .
	mv $(rpmroot)/RPMS/noarch/$(name)-*-$(version).$(version_ts)-$(release)*.noarch.rpm .

dist:
	svn export $(svnroot)/safekeep/tags/$(tagname) $(releasename)
	cat $(releasename)/$(name).spec.in | sed 's/^%define version.*/%define version $(version)/' > $(releasename)/$(name).spec
	cat $(releasename)/debian/changelog.in | sed 's/^safekeep.*/safekeep ($(version)) unstable; urgency=low/' > $(releasename)/debian/changelog
	mkdir -p $(releasedir); tar cz -f $(releasedir)/$(releasename).tar.gz $(releasename)
	cd $(releasename); make docs
	rm -rf $(releasename)

distdeb: dist
	tar xz -C /tmp -f $(releasedir)/$(releasename).tar.gz
	rm -rf $(releasedir)/$(releasename).tar.gz
	cd /tmp/$(releasename) && debuild --check-dirname-regex 'safekeep(-.*)?'
	mv /tmp/$(releasename)/safekeep*deb $(releasedir)

distrpm: dist
	rpmbuild -ta $(releasedir)/$(releasename).tar.gz
	mv $(rpmroot)/SRPMS/$(releasename)-$(release)*.src.rpm $(releasedir)
	mv $(rpmroot)/RPMS/noarch/$(name)-*-$(version)-$(release)*.noarch.rpm $(releasedir)
	rpm --addsign $(releasedir)/$(releasename)-$(release)*.src.rpm $(releasedir)/$(name)-*-$(version)-$(release)*.noarch.rpm

deploy-lattica:
	scp $(releasedir)/${name}{,-common,-client,-server}-${version}-*.rpm ${repo_srv}:${repo_dir}/upload
	ssh ${repo_srv} "cd ${repo_dir}; ./deploy-rpms.sh upload/${name}-*${version}-*.rpm"

deploy-sf:
	scp releases/${name}{-${version}.tar.gz,{,-common,-client,-server}-${version}-*.rpm} frs.sourceforge.net:uploads

check:
	safekeep-test --local

test:
	safekeep-test --remote

clean:
	rm -f {.,doc,debian}/*~ *.py[co] 
	rm -f $(name).spec debian/changelog
	rm -f doc/*.xml doc/*.html doc/*.[15]
	rm -f safekeep-*[.]20[01][0-9][01][0-9][0-3][0-9][012][0-9][0-5][0-9]*
