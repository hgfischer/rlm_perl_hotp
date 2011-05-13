NAME = rlm-perl-hotp
SUMMARY = Freeradius HOTP token module
GROUP = Applications/Tools
LICENSE = GPLv2
VENDOR = Herbert G. Fischer <herbert.fischer@gmail.com>
PREFIX = /
PYTHON = python2.6
DEPS = redis-server, freeradius, libdigest-hmac-perl, libdigest-sha1-perl
DATE = $(shell date +'%a, %d %b %Y %T %z')

# Get Version from GIT tags with pattern (N.N.N)
VERSION = $(shell git describe --abbrev=0 --match=[0-9]\.[0-9]\.[0-9])
ifeq ($(strip $(VERSION)),)
	VERSION = 0.0.0
endif
BUILD_STAMP = $(shell date +"%Y%m")
# Get URL from remote GIT repo
URL = $(shell git config --get remote.origin.url)
ifeq ($(strip $(URL)),)
	URL = http://url.for.your.project.com/
endif
# Get git author config
AUTHOR = $(shell git config --get user.name)
ifeq ($(strip $(AUTHOR)),)
	AUTHOR = Unknown
endif
# Get author email from git
EMAIL = $(shell git config --get user.email)
ifeq ($(strip $(EMAIL)),)
	EMAIL = unknown@unknown
endif

RELEASE = $(BUILD_STAMP)
PACKAGER = $(USER)
PROJROOT = $(shell pwd)

DEPS_DIR = deps
DIST_DIR = dist
TAR_DIR = tar
RPM_DIR = rpm
DEBIAN_DIR = debian
RPM_DIRS = SPECS RPMS SOURCES BUILD

TAR = $(PROJROOT)/$(DIST_DIR)/$(NAME).tar

define control
Source: $(NAME)
Section: unknown
Priority: extra
Maintainer: $(AUTHOR) <$(EMAIL)>
Build-Depends: debhelper (>= 7.0.50~)
Standards-Version: 3.8.4
Homepage: $(URL)
Vcs-Git: $(URL)

Package: $(NAME)
Architecture: all
Depends: $${misc:Depends}
Description: $(SUMMARY)
# 
endef
export control

define copyright
This work was packaged for Debian by:
    $(AUTHOR) <$(EMAIL)> on $(DATE)
It was downloaded from:
    <$(URL)>
Upstream Author(s):
    $(AUTHOR) <$(EMAIL)>
Copyright:
    Copyright (C) 2011 $(AUTHOR)
License:
    $(LICENSE)
The Debian packaging is:
    Copyright (C) 2011 $(AUTHOR) <$(EMAIL)> 
endef
export copyright

define changelog
$(NAME) ($(VERSION)) unstable; urgency=low

  * None.

 -- $(AUTHOR) <$(EMAIL)>  $(DATE)
endef
export changelog

define rules
#!/usr/bin/make -f
# -*- makefile -*-
export DH_VERBOSE=1
#%:
#	dh $$@

clean:
	echo dh_clean

binary:
	@install -d debian/$(NAME)/
	@tar xf dist/$(NAME).tar -C debian/$(NAME)/
	@dh_installdeb
	@dh_gencontrol -- -v${VERSION}+${RELEASE}
	@dh_fixperms
	@dh_builddeb --destdir dist

build:
	echo Build
endef
export rules

define conffiles
/etc/freeradius/sites-available/2factor
endef
export conffiles

all: 	tar

clean:
	@echo Cleaning temporary dirs...
	@rm -rf $(TAR_DIR)
	@rm -rf $(DIST_DIR)
	@rm -rf $(RPM_DIR)
	@rm -rf $(DEBIAN_DIR)
	@rm -rf $(DEPS_DIR)

$(DIST_DIR):
	@mkdir -p $(DIST_DIR)
init:	$(DIST_DIR)
	@echo Creating directories...
	@mkdir -p $(DIST_DIR)

preptar:	init
	@echo Copying files to generate tarball...
	@mkdir -p $(TAR_DIR)/etc/freeradius/; 
	@cp -Rp freeradius/* $(TAR_DIR)/etc/freeradius/

tar:	preptar
	@echo Generating tarball...
	@cd $(PROJROOT)/$(TAR_DIR); \
		tar cf $(TAR) .

rpm:	tar
	@echo Creating directories...
	@for dir in $(RPM_DIRS); do \
		mkdir -p $(RPM_DIR)/$$dir; \
	done;

	@echo Copying tarball...
	@cp $(TAR) $(PROJROOT)/$(RPM_DIR)/SOURCES/

	@echo Calling rpmbuild...
	@cp data/$(NAME).spec $(RPM_DIR)/SPECS/

	@cd $(PROJROOT)/$(RPM_DIR)/SPECS ; \
		rpmbuild -bb \
			--buildroot="$(PROJROOT)/$(RPM_DIR)/BUILD/$(NAME)" \
			--define "_topdir $(PROJROOT)/$(RPM_DIR)" \
			--define "name $(NAME)" \
			--define "summary $(SUMMARY)" \
			--define "version $(VERSION)" \
			--define "release $(RELEASE)" \
			--define "url _$(URL)_" \
			--define "license $(LICENSE)" \
			--define "group $(GROUP)" \
			--define "vendor $(VENDOR)" \
			--define "packager $(PACKAGER)" \
			--define "prefix $(PREFIX)" \
			--define "source_dir $(PROJROOT)/$(RPM_DIR)/SOURCES" \
			$(NAME).spec
	@echo Copying generated RPM to dist dir...
	@cp $(PROJROOT)/$(RPM_DIR)/RPMS/noarch/*.rpm $(PROJROOT)/$(DIST_DIR)/


deb:	tar
	@echo Creating directories...
	@mkdir -p $(DEBIAN_DIR)
	@echo "$$control" > $(DEBIAN_DIR)/control
	@echo "$$copyright" > $(DEBIAN_DIR)/copyright
	@echo "$$changelog" > $(DEBIAN_DIR)/changelog
	@echo "$$rules" > $(DEBIAN_DIR)/rules
	@echo "$$conffiles" > $(DEBIAN_DIR)/conffiles
	@echo "7" > $(DEBIAN_DIR)/compat
	@chmod a+x $(DEBIAN_DIR)/rules
	@dpkg-buildpackage -us -uc -b --changes-option="-udist"
	@mkdir -p $(PROJROOT)/$(DEPS_DIR)
	@cd $(PROJROOT)/$(DEPS_DIR); \
		wget http://search.cpan.org/CPAN/authors/id/I/IW/IWADE/Authen-HOTP-0.02.tar.gz; \
		tar xvzf Authen-HOTP-0.02.tar.gz
	@cd $(PROJROOT)/$(DEPS_DIR)/Authen-HOTP-0.02/ ; \
		dh-make-perl; \
		dpkg-buildpackage -us -uc -b
	@mv $(PROJROOT)/$(DEPS_DIR)/*.deb $(PROJROOT)/$(DIST_DIR)/
