name        = LaBackup
timestamp   = $(shell LANG=C date)
version_num = $(shell grep 'VERSION *=' LaBackup | sed s'/[^"]*"\([^"].*\)".*/\1/')
version_ts  = $(shell date -d '$(timestamp)' '+%Y%m%d-%H%M-%Z')
version     = $(version_num)
releasename = $(name)-$(version)
snapshotname= $(name)-$(version)-$(version_ts)
tagname     = $(shell echo Release-$(releasename) | tr . _)
dirname     = $(shell basename $(PWD))
rpmroot     = $(shell grep '%_topdir' ~/.rpmmacros | sed 's/^[^ \t]*[ \t]*//')
cvsroot     = $(shell cat CVS/Root)
cvsmodule   = $(shell cat CVS/Repository)

all: help

help:
	@echo "Targets:"
	@echo "    help        Displays this message"
	@echo "    info        Displays package information (version, tag, etc.)"
	@echo "    build       Builds everything needed for an installation"
	@echo "    deb         Builds snapshot binary and source DEBs"
	@echo "    rpm         Buidls snapshot binary and source RPMs"
	@echo "    tar         Builds snapshot source distribution"
	@echo "    clean       Cleans up the source tree"

info:
	@echo "Release Name   = $(releasename)"
	@echo "Snapshot Name  = $(snapshotname)"
	@echo "Version        = $(version)"
	@echo "Timestamp      = $(timestamp)"
	@echo "Tag            = $(tagname)"
	@echo "RPM Root       = $(rpmroot)"
	@echo "CVS Root       = $(cvsroot)"
	@echo "CVS Module     = $(cvsmodule)"

build:

release: check-info commit-release tag-release rpm-release

commit-release:
	cvs ci -m "Release $(version) (tagged as $(tagname))"

snapshot: rpm-snapshot

tag-release:
	cvs tag -c "$(tagname)"

check-info: info
	@echo -n 'Is this information correct? (yes/No) '
	@read x; if [ "$$x" != "yes" ]; then exit 1; fi

tar: tar-snapshot

tar-release:
	cvs -Q -d '$(cvsroot)' export -d $(releasename) -r '$(tagname)' '$(cvsmodule)'
	cat LaBackup.spec.in | sed 's/^%define version.*/%define version $(version)/' > LaBackup.spec
	cat debian/changelog.in | sed 's/^labackup.*/labackup ($(version)-1) unstable; urgency=low/' > debian/changelog
	tar cz -f $(releasename).tar.gz $(releasename)
	rm -rf $(releasename)

tar-snapshot:
	cvs -Q -d '$(cvsroot)' export -d $(snapshotname) -D '$(timestamp)' '$(cvsmodule)'
	cat LaBackup.spec.in | sed 's/^%define version.*/%define version $(version)-$(version_ts)/' > LaBackup.spec
	cat debian/changelog.in | sed 's/^labackup.*/labackup ($(version)-$(version_ts)-1) unstable; urgency=low/' > debian/changelog
	tar cz -f $(snapshotname).tar.gz $(snapshotname)
	rm -rf $(snapshotname)

deb: deb-snapshot

deb-release: tar-release
	tar xfz $(releasename).tar.gz
	cd $(releasename) && debuild
	rm -rf $(releasename)

deb-snapshot: tar-snapshot
	tar xfz $(snapshotname).tar.gz
	cd $(snapshotname) && debuild
	rm -rf $(snapshotname)

rpm: rpm-snapshot

rpm-release: tar-release
	rpmbuild -ta $(releasename).tar.gz

rpm-snapshot: tar-snapshot
	rpmbuild -ta $(snapshotname).tar.gz

clean:
	rm -rf `find -name "*.py[co]" -o -name "*~"```
	rm -f LaBackup.spec debian/changelog

foobar:
	cat LaBackup.spec.in | sed 's/^%define version.*/%define version $(version)-$(version_ts)/' > LaBackup.spec
	cat debian/changelog.in | sed 's/^labackup.*/labackup ($(version)-$(version_ts)-1) unstable; urgency=low/' > debian/changelog
