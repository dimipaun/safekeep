name        := safekeep
version_num := $(shell grep 'VERSION *=' safekeep | sed s'/[^"]*"\([^"].*\)".*/\1/')
version     := $(version_num)
release     := 1
releasename := $(name)-$(version)
dirname     := $(shell basename $(PWD))
rpmroot     := $(shell grep '^%_topdir' ~/.rpmmacros 2>/dev/null | sed -e 's/^[^ \t]*[ \t]*//' -e 's/%/$$/g')
deb_box	    := 192.168.3.202
rpm_box     := 192.168.3.242
SF_USER     := $(shell whoami)
sf_login    := $(SF_USER),$(name)@frs.sourceforge.net
sf_dir	    := /home/frs/project/s/sa/$(name)/$(name)
gitroot     := https://github.com/dimipaun
releasedir  := releases
repo_srv    := root@ulysses
repo_dir    := /var/www/repos/lattica
webroot     := ../../website/trunk/WebContent/
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
	@echo "Version        = $(version)"
	@echo "RPM Root       = $(rpmroot)"


build: docs

release: check-info commit-release dist distrpm

deploy: deploy-lattica deploy-sf

commit-release:
	git commit -a -m "Release $(version)"

tag:
	git tag $(version)
	git push --tags

check-info: info
	@echo -n 'Is this information correct? (yes/No) '
	@read x; if [ "$$x" != "yes" ]; then exit 1; fi

web: html
	cp doc/*.html $(webroot)
	cd  $(webroot); svn ci -m "Update man pages on website to latest"

docs: html man

html: $(DOC_HTML)

man: $(DOC_MAN)

%.html: %.txt
	asciidoc --unsafe -b html4 -d manpage -f doc/asciidoc.conf $<

%.1 %.5: %.xml
	xmlto -o doc -m doc/callouts.xsl man $<

%.xml: %.txt
	asciidoc --unsafe -b docbook -d manpage -f doc/asciidoc.conf $<

$(DOC_HTML) $(DOC_MAN): doc/asciidoc.conf

install:
	install -d -m 755 "$(DESTDIR)/usr/bin/"
	install -m 755 $(name) "$(DESTDIR)/usr/bin/"
	install -d -m 755 "$(DESTDIR)/etc/$(name)/backup.d"
	install -m 664 $(name).conf "$(DESTDIR)/etc/$(name)/"
	install -d -m 755 "$(DESTDIR)/etc/cron.daily"
	install -m 755 $(name).cron "$(DESTDIR)/etc/cron.daily/$(name)"
	install -d -m 755 "$(DESTDIR)/usr/share/man/man1/"
	install -m 444 doc/$(name).1 "$(DESTDIR)/usr/share/man/man1/"
	install -d -m 755 "$(DESTDIR)/usr/share/man/man5/"
	install -m 444 doc/$(name).conf.5 "$(DESTDIR)/usr/share/man/man5/"
	install -m 444 doc/$(name).backup.5 "$(DESTDIR)/usr/share/man/man5/"

tar: $(releasedir)/$(releasename).tar.gz

dist: $(releasedir)/$(releasename).tar.gz

$(releasedir)/$(releasename).tar.gz:
	wget -q $(gitroot)/$(name)/archive/$(version).tar.gz
	tar xz -f $(version).tar.gz
	rm $(version).tar.gz
	cat $(releasename)/$(name).spec.in | sed 's/^%define version.*/%define version $(version)/' > $(releasename)/$(name).spec
	cat $(releasename)/debian/changelog.in | sed 's/^safekeep.*/safekeep ($(version)) unstable; urgency=low/' > $(releasename)/debian/changelog
	cd $(releasename); make docs
	mkdir -p $(releasedir); tar cz -f $(releasedir)/$(releasename).tar.gz $(releasename)
	rm -rf $(releasename)

distdeb: distdeb-build distdeb-sign

distdeb-build: $(releasedir)/$(releasename).tar.gz
	tar xz -C /tmp -f $<
	cd /tmp/$(releasename) && dpkg-buildpackage -us -uc
	mv /tmp/$(name)-*_$(version)_all.deb $(releasedir)

distdeb-sign:
	debsign $(releasedir)/$(name)-*_$(version)_all.deb

distrpm: distrpm-build distrpm-sign

distrpm-build: $(releasedir)/$(releasename).tar.gz
	rpmbuild -ta $<
	mv $(rpmroot)/SRPMS/$(releasename)-$(release)*.src.rpm $(releasedir)
	mv $(rpmroot)/RPMS/noarch/$(name)-*-$(version)-$(release)*.noarch.rpm $(releasedir)

distrpm-sign:
	rpm --addsign $(releasedir)/$(releasename)-$(release)*.src.rpm $(releasedir)/$(name)-*-$(version)-$(release)*.noarch.rpm

dist-sign: distrpm-sign distdeb-sign

dist-all: dist distdeb-remote fetch-debs distrpm-remote fetch-rpms dist-sign

distdeb-remote:
	ssh $(deb_box) 'cd ~/git/safekeep; git pull; make distdeb-build'

fetch-debs:
	scp $(deb_box):~/git/safekeep/$(releasedir)/$(name)-*_$(version)_all.deb $(releasedir)

distrpm-remote:
	ssh $(rpm_box) 'cd ~/git/safekeep; git pull; make distrpm-build'

fetch-rpms:
	scp $(rpm_box):~/git/safekeep/$(releasedir)/$(name)-*$(version)-$(release).*.rpm $(releasedir)

deploy-lattica:
	scp $(releasedir)/${name}{,-common,-client,-server}-${version}-*.rpm ${repo_srv}:${repo_dir}/upload
	ssh ${repo_srv} "cd ${repo_dir}; ./deploy-rpms.sh upload/${name}-*${version}-*.rpm"

deploy-sf: $(releasedir)/CHECKSUM-$(releasename).txt
	echo -e "cd $(sf_dir)\nmkdir $(version)" | sftp -b- $(sf_login)
	scp $(releasedir)/$(releasename).tar.gz $(sf_login):$(sf_dir)/$(version)
	scp ANNOUNCE $(sf_login):$(sf_dir)/$(version)/README.txt
	scp $(releasedir)/$(releasename)-$(release)*.src.rpm $(releasedir)/$(name)-*-$(version)-$(release)*.noarch.rpm $(sf_login):$(sf_dir)/$(version)
	scp $(releasedir)/$(name)-*_$(version)_all.deb $(sf_login):$(sf_dir)/$(version)
	scp $(releasedir)/$(name)_* $(sf_login):$(sf_dir)/$(version)
	scp $(releasedir)/CHECKSUM-$(releasename).txt $(sf_login):$(sf_dir)/$(version)
	scp RPM-GPG-KEY-SafeKeep $(sf_login):$(sf_dir)/$(version)
	scp README_SF_Top $(sf_login):$(sf_dir)/../README.txt

$(releasedir)/CHECKSUM-$(releasename).txt:
	cd $(releasedir); sha512sum $(name)*$(version)* | gpg --clearsign -u $(name) > CHECKSUM-$(releasename).txt

check:
	safekeep-test --local

test:
	safekeep-test --remote

clean:
	rm -f {.,doc,debian}/*~ *.py[co] 
	rm -f $(name).spec debian/changelog
	rm -f doc/*.xml doc/*.html doc/*.[15]
	rm -f safekeep-*[.]20[01][0-9][01][0-9][0-3][0-9][012][0-9][0-5][0-9]*

