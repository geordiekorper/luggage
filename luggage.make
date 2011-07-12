# 
#   Copyright 2009 Joe Block <jpb@ApesSeekingKnowledge.net>
#
#   mpkg and migration to quoting command line calls
#   Copyright 2011 Geordie Korper <geordie@korper.org>
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#
# Version 1.0.1x18


LUGGAGE_DIR=/usr/local/share/luggage

STAMP:=`date +%Y%m%d`
YY:=`date +%Y`
MM:=`date +%m`
DD:=`date +%d`
BUILD_DATE=`date -u "+%Y-%m-%dT%H:%M:%SZ"`

# mai plist haz a flavor
PLIST_FLAVOR=plist
PACKAGE_PLIST=.package.plist

PACKAGE_TARGET_OS=10.4
PLIST_TEMPLATE=prototype.plist
TITLE=CHANGE_ME
REVERSE_DOMAIN=com.replaceme
ORGANIZATION_NAME=Self Organizing
PACKAGE_ID=${REVERSE_DOMAIN}.${TITLE}

# Set PACKAGE_VERSION in your Makefile if you don't want version set to
# today's date
PACKAGE_VERSION=${STAMP}
PACKAGE_MAJOR_VERSION=${YY}
PACKAGE_MINOR_VERSION=${MM}${DD}

# Set PACKAGE_NAME in your Makefile if you don't want it to be TITLE-PACKAGEVERSION.
PACKAGE_NAME=${TITLE}-${PACKAGE_VERSION}
PACKAGE_FILE=${PACKAGE_NAME}.pkg
DMG_NAME=${PACKAGE_NAME}.dmg
ZIP_NAME=${PACKAGE_FILE}.zip

# Set METAPACKAGE_BUNDLE in your Makefile if you don't want it to be TITLE-PACKAGEVERSION.mpkg.
METAPACKAGE_BUNDLE=${PACKAGE_NAME}.mpkg
METAPACKAGE_RESOURCES_DIR=${METAPACKAGE_BUNDLE}/Contents/Resources
METAPACKAGE_PACKAGES_DIR=${METAPACKAGE_BUNDLE}/Contents/Packages

# Only use Apple tools for file manipulation, or deal with a world of pain
# when your resource forks get munched.  This is particularly important on
# 10.6 since it stores compressed binaries in the resource fork.
TAR=/usr/bin/tar
CP=/bin/cp
INSTALL=/usr/bin/install
DITTO=/usr/bin/ditto

PACKAGEMAKER=/Developer/usr/bin/packagemaker

XATTR=/usr/bin/xattr

# We use the checksum from InstaUp2Date
CHECKSUM=/usr/local/instadmg/AddOns/InstaUp2Date/checksum.py

# Must be on an HFS+ filesystem. Yes, I know some network servers will do
# their best to preserve the resource forks, but it isn't worth the aggravation
# to fight with them.
LUGGAGE_TMP=/tmp/the_luggage
SCRATCH_D=${LUGGAGE_TMP}/${PACKAGE_NAME}

SCRIPT_D=${SCRATCH_D}/scripts
RESOURCE_D=${SCRATCH_D}/resources
WORK_D=${SCRATCH_D}/root
PAYLOAD_D=${SCRATCH_D}/payload

# packagemaker parameters
#
# packagemaker will helpfully apply the permissions it finds on the system
# if one of the files in the payload exists on the disk, rather than the ones
# you've carefully set up in the package root, so I turn that crap off with
# --no-recommend. You can disable this by overriding PM_EXTRA_ARGS in your
# package's Makefile.

PM_EXTRA_ARGS=--verbose --no-recommend

# Override if you want to require a restart after installing your package.
PM_RESTART=None
PAYLOAD=

# hdiutil parameters
#
# hdiutil will create a compressed disk image with the UDZO and UDBZ formats,
# or a bland, uncompressed, read-only image with UDRO. Wouldn't you rather
# trade a little processing time for some disk savings now that you can make
# packages and images with reckless abandon?
#
# The UDZO format is selected as the default here for compatibility, but you
# can override it to achieve higher compression. If you want to switch away
# from UDZO, it is probably best to override DMG_FORMAT in your makefile.
#
# Format notes:
# The UDRO format is an uncompressed, read-only disk image that is compatible
# with Mac OS X 10.0 and later.
# The UDZO format is gzip-based, defaults to gzip level 1, and is compatible
# with Mac OS X 10.2 and later.
# The UDBZ format is bzip2-based and is compatible with Mac OS X 10.4 and later.

DMG_FORMAT_CODE=UDZO
ZLIB_LEVEL=9
DMG_FORMAT_OPTION=-imagekey zlib-level=${ZLIB_LEVEL}
DMG_FORMAT=${DMG_FORMAT_CODE} ${DMG_FORMAT_OPTION}

# Set .PHONY declarations so things don't break if someone has files in
# their workdir with the same names as our special stanzas

.PHONY: clean
.PHONY: debug
.PHONY: dmg
.PHONY: grind_package
.PHONY: local_pkg
.PHONY: package_root
.PHONY: payload_d
.PHONY: pkg
.PHONY: mpkg
.PHONY: scratchdir
.PHONY: superclean

# Convenience variables
USER_TEMPLATE=${WORK_D}/System/Library/User Template
USER_TEMPLATE_PREFERENCES=${USER_TEMPLATE}/English.lproj/Library/Preferences
USER_TEMPLATE_PICTURES=${USER_TEMPLATE}/English.lproj/Pictures

# target stanzas

help:
	@-echo
	@-echo "make clean - clean up work files."
	@-echo "make dmg - roll a pkg, then stuff it into a dmg file."
	@-echo "make zip - roll a pkg, then stuff it into a zip file."
	@-echo "make mpkg - roll a bunch of pkgs, then stuff them in an mpkg."	
	@-echo "make pkg - roll a pkg."
	@-echo

# set up some work directories

payload_d:
	@sudo mkdir -p "${PAYLOAD_D}"

package_root:
	@sudo mkdir -p "${WORK_D}"

# packagemaker chokes if the pkg doesn't contain any payload, making script-only
# packages fail to build mysteriously if you don't remember to include something
# in it, so we're including the /usr/local directory, since it's harmless.
scriptdir: l_usr_local
	@sudo mkdir -p "${SCRIPT_D}"

resourcedir:
	@sudo mkdir -p "${RESOURCE_D}"

scratchdir:
	@sudo mkdir -p "${SCRATCH_D}"

# user targets

clean:
	@sudo rm -fr "${SCRATCH_D}" .luggage.pkg.plist "${PACKAGE_PLIST}" "${METAPACKAGE_BUNDLE}" "${PACKAGE_FILE}"

superclean:
	@sudo rm -fr "${LUGGAGE_TMP}"

dmg: scratchdir compile_package
	@echo "Wrapping ${PACKAGE_NAME}..."
	@sudo hdiutil create -volname "${PACKAGE_NAME}" \
		-srcfolder "${PAYLOAD_D}" \
		-uid 99 -gid 99 \
		-ov \
		-format ${DMG_FORMAT} \
		"${DMG_NAME}"
	@echo "Checksumming ${PACKAGE_NAME} for InstaUp2Date..."
	@${CHECKSUM} "${DMG_NAME}"

zip: scratchdir compile_package
	@echo "Zipping ${PACKAGE_NAME}..."
	@${DITTO} -c -k \
		--noqtn --noacl \
		--sequesterRsrc \
		"${PAYLOAD_D}" \
		"${ZIP_NAME}"
		
modify_packageroot:
	@echo "If you need to override permissions or ownerships, override modify_packageroot in your Makefile"

prep_pkg: clean compile_package
# NOP

pkg: prep_pkg local_pkg
	@-echo

pkgls: prep_pkg
	@echo
	@echo
	lsbom -p fmUG "${PAYLOAD_D}/${PACKAGE_FILE}/Contents/Archive.bom"

payload: payload_d package_root scratchdir scriptdir resourcedir ${PAYLOAD}
	@make -f "${CURDIR}/$(firstword $(MAKEFILE_LIST))" $(PAYLOAD)
	@-echo

compile_package: payload .luggage.pkg.plist modify_packageroot
	@-sudo rm -fr "${PAYLOAD_D}/${PACKAGE_FILE}"
	@echo "Creating ${PAYLOAD_D}/${PACKAGE_FILE}"
	sudo ${PACKAGEMAKER} --root "${WORK_D}" \
		--id "${PACKAGE_ID}" \
		--filter DS_Store \
		--target "${PACKAGE_TARGET_OS}" \
		--title "${TITLE}" \
		--info "${SCRATCH_D}/luggage.pkg.plist" \
		--scripts "${SCRIPT_D}" \
		--resources "${RESOURCE_D}" \
		--version "${PACKAGE_VERSION}" \
		${PM_EXTRA_ARGS} --out "${PAYLOAD_D}/${PACKAGE_FILE}"

${PACKAGE_PLIST}: ${LUGGAGE_DIR}/prototype.plist
# override this stanza if you have a different plist you want to use as
# a custom local template.
	@cat ${LUGGAGE_DIR}/prototype.plist > ${PACKAGE_PLIST}

.luggage.pkg.plist: ${PACKAGE_PLIST}
	@cat ${PACKAGE_PLIST} | \
		sed "s/{DD}/${DD}/g" | \
		sed "s/{MM}/${MM}/g" | \
		sed "s/{YY}/${YY}/g" | \
		sed "s/{PACKAGE_MAJOR_VERSION}/${PACKAGE_MAJOR_VERSION}/g" | \
		sed "s/{PACKAGE_MINOR_VERSION}/${PACKAGE_MINOR_VERSION}/g" | \
		sed "s/{BUILD_DATE}/${BUILD_DATE}/g" | \
		sed "s/{PACKAGE_ID}/${PACKAGE_ID}/g" | \
		sed "s/{PACKAGE_VERSION}/${PACKAGE_VERSION}/g" | \
		sed "s/{PM_RESTART}/${PM_RESTART}/g" | \
	        sed "s/{PLIST_FLAVOR}/${PLIST_FLAVOR}/g" \
		> .luggage.pkg.plist
	@sudo ${CP} .luggage.pkg.plist "${SCRATCH_D}/luggage.pkg.plist"
	@rm .luggage.pkg.plist ${PACKAGE_PLIST}

local_pkg:
	@${CP} -R "${PAYLOAD_D}/${PACKAGE_FILE}" .

# Target directory rules

l_root: package_root
	@sudo mkdir -p "${WORK_D}"
	@sudo chmod 755 "${WORK_D}"
	@sudo chown root:admin "${WORK_D}"

l_etc: l_root
	@sudo mkdir -p "${WORK_D}/etc"
	@sudo chown -R root:wheel "${WORK_D}/etc"
	@sudo chmod -R 755 "${WORK_D}/etc"

l_etc_hooks: l_etc
	@sudo mkdir -p "${WORK_D}/etc/hooks"
	@sudo chown -R root:wheel "${WORK_D}/etc/hooks"
	@sudo chmod -R 755 "${WORK_D}/etc/hooks"

l_etc_openldap: l_etc
	@sudo mkdir -p "${WORK_D}/etc/openldap"
	@sudo chmod 755 "${WORK_D}/etc/openldap"
	@sudo chown root:wheel "${WORK_D}/etc/openldap"

l_usr: l_root
	@sudo mkdir -p "${WORK_D}/usr"
	@sudo chown -R root:wheel "${WORK_D}/usr"
	@sudo chmod -R 755 "${WORK_D}/usr"

l_usr_bin: l_usr
	@sudo mkdir -p "${WORK_D}/usr/bin"
	@sudo chown -R root:wheel "${WORK_D}/usr/bin"
	@sudo chmod -R 755 "${WORK_D}/usr/bin"

l_usr_lib: l_usr
	@sudo mkdir -p "${WORK_D}/usr/lib"
	@sudo chown -R root:wheel "${WORK_D}/usr/lib"
	@sudo chmod -R 755 "${WORK_D}/usr/lib"

l_usr_local: l_usr
	@sudo mkdir -p "${WORK_D}/usr/local"
	@sudo chown -R root:wheel "${WORK_D}/usr/local"
	@sudo chmod -R 755 "${WORK_D}/usr/local"

l_usr_local_bin: l_usr_local
	@sudo mkdir -p "${WORK_D}/usr/local/bin"
	@sudo chown -R root:wheel "${WORK_D}/usr/local/bin"
	@sudo chmod -R 755 "${WORK_D}/usr/local/bin"

l_usr_local_lib: l_usr_local
	@sudo mkdir -p "${WORK_D}/usr/local/lib"
	@sudo chown -R root:wheel "${WORK_D}/usr/local/lib"
	@sudo chmod -R 755 "${WORK_D}/usr/local/lib"

l_usr_local_man: l_usr_local
	@sudo mkdir -p "${WORK_D}/usr/local/man"
	@sudo chown -R root:wheel "${WORK_D}/usr/local/man"
	@sudo chmod -R 755 "${WORK_D}/usr/local/man"

l_usr_local_sbin: l_usr_local
	@sudo mkdir -p "${WORK_D}/usr/local/sbin"
	@sudo chown -R root:wheel "${WORK_D}/usr/local/sbin"
	@sudo chmod -R 755 "${WORK_D}/usr/local/sbin"

l_usr_local_share: l_usr_local
	@sudo mkdir -p "${WORK_D}/usr/local/share"
	@sudo chown -R root:wheel "${WORK_D}/usr/local/share"
	@sudo chmod -R 755 "${WORK_D}/usr/local/share"

l_usr_man: l_usr_share
	@sudo mkdir -p "${WORK_D}/usr/share/man"
	@sudo chown -R root:wheel "${WORK_D}/usr/share/man"
	@sudo chmod -R 0755 "${WORK_D}/usr/share/man"

l_usr_man_man1: l_usr_man
	@sudo mkdir -p "${WORK_D}/usr/share/man/man1"
	@sudo chown -R root:wheel "${WORK_D}/usr/share/man/man1"
	@sudo chmod -R 0755 "${WORK_D}/usr/share/man/man1"

l_usr_man_man2: l_usr_man
	@sudo mkdir -p "${WORK_D}/usr/share/man/man2"
	@sudo chown -R root:wheel "${WORK_D}/usr/share/man/man2"
	@sudo chmod -R 0755 "${WORK_D}/usr/share/man/man2"

l_usr_man_man3: l_usr_man
	@sudo mkdir -p "${WORK_D}/usr/share/man/man3"
	@sudo chown -R root:wheel "${WORK_D}/usr/share/man/man3"
	@sudo chmod -R 0755 "${WORK_D}/usr/share/man/man3"

l_usr_man_man4: l_usr_man
	@sudo mkdir -p "${WORK_D}/usr/share/man/man4"
	@sudo chown -R root:wheel "${WORK_D}/usr/share/man/man4"
	@sudo chmod -R 0755 "${WORK_D}/usr/share/man/man4"

l_usr_man_man5: l_usr_man
	@sudo mkdir -p "${WORK_D}/usr/share/man/man5"
	@sudo chown -R root:wheel "${WORK_D}/usr/share/man/man5"
	@sudo chmod -R 0755 "${WORK_D}/usr/share/man/man5"

l_usr_man_man6: l_usr_man
	@sudo mkdir -p "${WORK_D}/usr/share/man/man6"
	@sudo chown -R root:wheel "${WORK_D}/usr/share/man/man6"
	@sudo chmod -R 0755 "${WORK_D}/usr/share/man/man6"

l_usr_man_man7: l_usr_man
	@sudo mkdir -p "${WORK_D}/usr/share/man/man7"
	@sudo chown -R root:wheel "${WORK_D}/usr/share/man/man7"
	@sudo chmod -R 0755 "${WORK_D}/usr/share/man/man7"

l_usr_man_man8: l_usr_man
	@sudo mkdir -p "${WORK_D}/usr/share/man/man8"
	@sudo chown -R root:wheel "${WORK_D}/usr/share/man/man8"
	@sudo chmod -R 0755 "${WORK_D}/usr/share/man/man8"

l_usr_sbin: l_usr
	@sudo mkdir -p "${WORK_D}/usr/sbin"
	@sudo chown -R root:wheel "${WORK_D}/usr/sbin"
	@sudo chmod -R 755 "${WORK_D}/usr/sbin"

l_usr_share: l_usr
	@sudo mkdir -p "${WORK_D}/usr/share"
	@sudo chown -R root:wheel "${WORK_D}/usr/share"
	@sudo chmod -R 755 "${WORK_D}/usr/share"

l_var: l_root
	@sudo mkdir -p "${WORK_D}/var"
	@sudo chown -R root:wheel "${WORK_D}/var"
	@sudo chmod -R 755 "${WORK_D}/var"

l_var_db: l_var
	@sudo mkdir -p "${WORK_D}/var/db"
	@sudo chown -R root:wheel "${WORK_D}/var/db"
	@sudo chmod -R 755 "${WORK_D}/var/db"

l_var_root: l_var
	@sudo mkdir -p "${WORK_D}/var/root"
	@sudo chown -R root:wheel "${WORK_D}/var/root"
	@sudo chmod -R 750 "${WORK_D}/var/root"

l_Applications: l_root
	@sudo mkdir -p "${WORK_D}/Applications"
	@sudo chown root:admin "${WORK_D}/Applications"
	@sudo chmod 775 "${WORK_D}/Applications"

l_Applications_Utilities: l_root
	@sudo mkdir -p "${WORK_D}/Applications/Utilities"
	@sudo chown root:admin "${WORK_D}/Applications/Utilities"
	@sudo chmod 755 "${WORK_D}/Applications/Utilities"

l_Library: l_root
	@sudo mkdir -p "${WORK_D}/Library"
	@sudo chown root:admin "${WORK_D}/Library"
	@sudo chmod 1775 "${WORK_D}/Library"

l_Library_Application_Support: l_Library
	@sudo mkdir -p "${WORK_D}/Library/Application Support"
	@sudo chown root:admin "${WORK_D}/Library/Application Support"
	@sudo chmod 775 "${WORK_D}/Library/Application Support"

l_Library_Application_Support_Adobe: l_Library
	@sudo mkdir -p "${WORK_D}/Library/Application Support/Adobe"
	@sudo chown root:admin "${WORK_D}/Library/Application Support/Adobe"
	@sudo chmod 775 "${WORK_D}/Library/Application Support/Adobe"

l_Library_Application_Support_Organization: l_Library_Application_Support
	$(call createdir,${WORK_D}/Library/Application Support/${ORGANIZATION_NAME},root:wheel,755)
	
l_Library_Desktop_Pictures: l_Library
	@sudo mkdir -p "${WORK_D}/Library/Desktop Pictures"
	@sudo chown root:admin "${WORK_D}/Library/Desktop Pictures"
	@sudo chmod 775 "${WORK_D}/Library/Desktop Pictures"

l_Library_Fonts: l_Library
	@sudo mkdir -p "${WORK_D}/Library/Fonts"
	@sudo chown root:admin "${WORK_D}/Library/Fonts"
	@sudo chmod 775 "${WORK_D}/Library/Fonts"

l_Library_LaunchAgents: l_Library
	@sudo mkdir -p "${WORK_D}/Library/LaunchAgents"
	@sudo chown root:wheel "${WORK_D}/Library/LaunchAgents"
	@sudo chmod 755 "${WORK_D}/Library/LaunchAgents"

l_Library_LaunchDaemons: l_Library
	@sudo mkdir -p "${WORK_D}/Library/LaunchDaemons"
	@sudo chown root:wheel "${WORK_D}/Library/LaunchDaemons"
	@sudo chmod 755 "${WORK_D}/Library/LaunchDaemons"

l_Library_Preferences: l_Library
	@sudo mkdir -p "${WORK_D}/Library/Preferences"
	@sudo chown root:admin "${WORK_D}/Library/Preferences"
	@sudo chmod 775 "${WORK_D}/Library/Preferences"

l_Library_Preferences_DirectoryService: l_Library_Preferences
	@sudo mkdir -p "${WORK_D}/Library/Preferences/DirectoryService"
	@sudo chown root:admin "${WORK_D}/Library/Preferences/DirectoryService"
	@sudo chmod 775 "${WORK_D}/Library/Preferences/DirectoryService"

l_Library_Printers: l_Library
	@sudo mkdir -p "${WORK_D}/Library/Printers"
	@sudo chown root:admin "${WORK_D}/Library/Printers"
	@sudo chmod 775 "${WORK_D}/Library/Printers"

l_Library_Printers_PPDs: l_Library_Printers
	@sudo mkdir -p "${WORK_D}/Library/Printers/PPDs/Contents/Resources"
	@sudo chown root:admin "${WORK_D}/Library/Printers/PPDs"
	@sudo chmod 775 "${WORK_D}/Library/Printers/PPDs"

l_PPDs: l_Library_Printers_PPDs

l_Library_Receipts: l_Library
	@sudo mkdir -p "${WORK_D}/Library/Receipts"
	@sudo chown root:admin "${WORK_D}/Library/Receipts"
	@sudo chmod 775 "${WORK_D}/Library/Receipts"

l_Library_User_Pictures: l_Library
	@sudo mkdir -p "${WORK_D}/Library/User Pictures"
	@sudo chown root:admin "${WORK_D}/Library/User Pictures"
	@sudo chmod 775 "${WORK_D}/Library/User Pictures"

l_Library_CorpSupport: l_Library
	@sudo mkdir -p "${WORK_D}/Library/CorpSupport"
	@sudo chown root:admin "${WORK_D}/Library/CorpSupport"
	@sudo chmod 775 "${WORK_D}/Library/CorpSupport"

l_Library_Python: l_Library
	@sudo mkdir -p "${WORK_D}/Library/Python"
	@sudo chown root:admin "${WORK_D}/Library/Python"
	@sudo chmod 775 "${WORK_D}/Library/Python"

l_Library_Python_26: l_Library_Python
	@sudo mkdir -p "${WORK_D}/Library/Python/2.6"
	@sudo chown root:admin "${WORK_D}/Library/Python/2.6"
	@sudo chmod 775 "${WORK_D}/Library/Python/2.6"

l_Library_Python_26_site_packages: l_Library_Python_26
	@sudo mkdir -p "${WORK_D}/Library/Python/2.6/site-packages"
	@sudo chown root:admin "${WORK_D}/Library/Python/2.6/site-packages"
	@sudo chmod 775 "${WORK_D}/Library/Python/2.6/site-packages"

l_Library_Ruby: l_Library
	@sudo mkdir -p "${WORK_D}/Library/Ruby"
	@sudo chown root:admin "${WORK_D}/Library/Ruby"
	@sudo chmod 775 "${WORK_D}/Library/Ruby"

l_Library_Ruby_Site: l_Library_Ruby
	@sudo mkdir -p "${WORK_D}/Library/Ruby/Site"
	@sudo chown root:admin "${WORK_D}/Library/Ruby/Site"
	@sudo chmod 775 "${WORK_D}/Library/Ruby/Site"

l_Library_Ruby_Site_1_8: l_Library_Ruby_Site
	@sudo mkdir -p "${WORK_D}/Library/Ruby/Site/1.8"
	@sudo chown root:admin "${WORK_D}/Library/Ruby/Site/1.8"
	@sudo chmod 775 "${WORK_D}/Library/Ruby/Site/1.8"

l_Library_Services: l_Library
	$(call createdir,${WORK_D}/Library/Services,root:wheel,755)

l_System: l_root
	@sudo mkdir -p "${WORK_D}/System"
	@sudo chown -R root:wheel "${WORK_D}/System"
	@sudo chmod -R 755 "${WORK_D}/System"

l_System_Library: l_System
	@sudo mkdir -p "${WORK_D}/System/Library"
	@sudo chown -R root:wheel "${WORK_D}/System/Library"
	@sudo chmod -R 755 "${WORK_D}/System/Library"

l_System_Library_User_Template: l_System_Library
	@sudo mkdir -p "${WORK_D}/System/Library/User Template/English.lproj"
	@sudo chown -R root:wheel "${WORK_D}/System/Library/User Template/English.lproj"
	@sudo chmod 700 "${WORK_D}/System/Library/User Template"
	@sudo chmod -R 755 "${WORK_D}/System/Library/User Template/English.lproj"

l_System_Library_User_Template_Library: l_System_Library_User_Template
	@sudo mkdir -p "${WORK_D}/System/Library/User Template/English.lproj/Library"
	@sudo chown root:wheel "${WORK_D}/System/Library/User Template/English.lproj/Library"
	@sudo chmod 700 "${WORK_D}/System/Library/User Template/English.lproj/Library"

l_System_Library_User_Template_Pictures: l_System_Library_User_Template
	@sudo mkdir -p "${WORK_D}/System/Library/User Template/English.lproj/Pictures"
	@sudo chown root:wheel "${WORK_D}/System/Library/User Template/English.lproj/Pictures"
	@sudo chmod 700 "${WORK_D}/System/Library/User Template/English.lproj/Pictures"

l_System_Library_User_Template_Preferences: l_System_Library_User_Template_Library
	@sudo mkdir -p ${USER_TEMPLATE_PREFERENCES}
	@sudo chown root:wheel ${USER_TEMPLATE_PREFERENCES}
	@sudo chmod -R 700 ${USER_TEMPLATE_PREFERENCES}

# file packaging rules

pack-directory-service-preference-%: % l_Library_Preferences_DirectoryService
	sudo install -m 600 -o root -g admin "$<" "${WORK_D}/Library/Preferences/DirectoryService"

pack-site-python-%: % l_Library_Python_26_site_packages
	@sudo ${INSTALL} -m 644 -g admin wheel -o root "$<" "${WORK_D}/Library/Python/2.6/site-packages"

pack-siteruby-%: % l_Library_Ruby_Site_1_8
	@sudo ${INSTALL} -m 644 -g wheel -o root "$<" "${WORK_D}/Library/Ruby/Site/1.8"

pack-Library-Fonts-%: % l_Library_Fonts
	@sudo ${INSTALL} -m 664 -g admin wheel -o root "$<" "${WORK_D}/Library/Fonts"

pack-Library-LaunchAgents-%: % l_Library_LaunchAgents
	@sudo ${INSTALL} -m 644 -g wheel -o root "$<" "${WORK_D}/Library/LaunchAgents"
	@sudo ${REMOVE_FILETYPE} "${WORK_D}/Library/LaunchAgents/$<"

pack-Library-LaunchDaemons-%: % l_Library_LaunchDaemons
	@sudo ${INSTALL} -m 644 -g wheel -o root "$<" "${WORK_D}/Library/LaunchDaemons"
	@sudo ${REMOVE_FILETYPE} "${WORK_D}/Library/LaunchDaemons/$<"

pack-Library-Preferences-%: % l_Library_Preferences
	@sudo ${INSTALL} -m 644 -g admin wheel -o root "$<" "${WORK_D}/Library/Preferences"

pack-ppd-%: % l_PPDs
	@sudo ${INSTALL} -m 664 -g admin wheel -o root "$<" "${WORK_D}/Library/Printers/PPDs/Contents/Resources"

pack-script-%: % scriptdir
	@sudo ${INSTALL} -m 755 "$<" "${SCRIPT_D}"

pack-resource-%: % resourcedir
	@sudo ${INSTALL} -m 755 "$<" "${RESOURCE_D}"

pack-user-template-plist-%: % l_System_Library_User_Template_Preferences
	@sudo ${INSTALL} -m 644 "$<" "${USER_TEMPLATE_PREFERENCES}"

pack-user-picture-%: % l_Library_Desktop_Pictures
	@sudo ${INSTALL} -m 644 "$<" "${WORK_D}/Library/Desktop Pictures"

# metapackaging rules

mpkg: clean luggage.mpkg.info payload
	@echo >> "${METAPACKAGE_RESOURCES_DIR}/${PACKAGE_NAME}.list"

${METAPACKAGE_BUNDLE}:
	@mkdir -p "${METAPACKAGE_RESOURCES_DIR}"
	@mkdir -p "${METAPACKAGE_PACKAGES_DIR}"

luggage.mpkg.info: ${METAPACKAGE_BUNDLE}
	@cat ${LUGGAGE_DIR}/prototype_mpkg.info \
	| sed "s/{TITLE}/${TITLE}/g" \
	| sed "s/{PACKAGE_VERSION}/${PACKAGE_VERSION}/g" \
	| sed "s/{DESCRIPTION}/${DESCRIPTION}/g" \
	> "${METAPACKAGE_RESOURCES_DIR}/${PACKAGE_NAME}.info"

mpack-%: %
	@echo
	@echo Making subpackage "$<"
	@$(MAKE) -C $< pkg
	@${CP} -pR $</*.pkg "${METAPACKAGE_PACKAGES_DIR}"

mpack-unselected-%: % mpack-%
	@echo `ls -d $</*.pkg | xargs -0 basename`:unselected >> "${METAPACKAGE_RESOURCES_DIR}/${PACKAGE_NAME}.list"

mpack-selected-%: % mpack-%
	@echo `ls -d $</*.pkg | xargs -0 basename`:selected >> "${METAPACKAGE_RESOURCES_DIR}/${PACKAGE_NAME}.list"

mpack-required-%: % mpack-%
	@echo `ls -d $</*.pkg | xargs -0 basename`:required >> "${METAPACKAGE_RESOURCES_DIR}/${PACKAGE_NAME}.list"

# posixy file stanzas

pack-etc-%: % l_etc
	@sudo ${INSTALL} -m 644 -g wheel -o root "$<" "${WORK_D}/etc"

pack-usr-bin-%: % l_usr_bin
	@sudo ${INSTALL} -m 755 -g wheel -o root "$<" "${WORK_D}/usr/bin"

pack-usr-sbin-%: % l_usr_sbin
	@sudo ${INSTALL} -m 755 -g wheel -o root "$<" "${WORK_D}/usr/sbin"

pack-usr-local-bin-%: % l_usr_local_bin
	@sudo ${INSTALL} -m 755 -g wheel -o root "$<" "${WORK_D}/usr/local/bin"

pack-usr-local-sbin-%: % l_usr_local_sbin
	@sudo ${INSTALL} -m 755 -g wheel -o root "$<" "${WORK_D}/usr/local/sbin"

pack-man-%: l_usr_man
	@sudo ${INSTALL} -m 0644 -g wheel -o root "$<" "${WORK_D}/usr/share/man"

pack-man1-%: l_usr_man_man1
	@sudo ${INSTALL} -m 0644 -g wheel -o root "$<" "${WORK_D}/usr/share/man/man8"

pack-man2-%: l_usr_man_man2
	@sudo ${INSTALL} -m 0644 -g wheel -o root "$<" "${WORK_D}/usr/share/man/man8"

pack-man3-%: l_usr_man_man3
	@sudo ${INSTALL} -m 0644 -g wheel -o root "$<" "${WORK_D}/usr/share/man/man8"

pack-man4-%: l_usr_man_man4
	@sudo ${INSTALL} -m 0644 -g wheel -o root "$<" "${WORK_D}/usr/share/man/man8"

pack-man5-%: l_usr_man_man5
	@sudo ${INSTALL} -m 0644 -g wheel -o root "$<" "${WORK_D}/usr/share/man/man8"

pack-man6-%: l_usr_man_man6
	@sudo ${INSTALL} -m 0644 -g wheel -o root "$<" "${WORK_D}/usr/share/man/man8"

pack-man7-%: l_usr_man_man7
	@sudo ${INSTALL} -m 0644 -g wheel -o root "$<" "${WORK_D}/usr/share/man/man8"

pack-man8-%: l_usr_man_man8
	@sudo ${INSTALL} -m 0644 -g wheel -o root "$<" "${WORK_D}/usr/share/man/man8"

pack-hookscript-%: % l_etc_hooks
	@sudo ${INSTALL} -m 755 "$<" "${WORK_D}/etc/hooks"

# Applications and Utilities
#
# We use ${TAR} because it respects resource forks. This is still
# critical - just when I thought I'd seen the last of the damn things, Apple
# decided to stash compressed binaries in them in 10.6.

unbz2-applications-%: %.tar.bz2 l_Applications
	@sudo ${TAR} xjf "$<" -C "${WORK_D}/Applications"
	@sudo chown -R root:admin "${WORK_D}/Applications/$(shell echo $< | sed s/\.tar\.bz2//g)"

unbz2-utilities-%: %.tar.bz2 l_Applications_Utilities
	@sudo ${TAR} xjf "$<" -C "${WORK_D}/Applications/Utilities"
	@sudo chown -R root:admin "${WORK_D}/Applications/Utilities/$(shell echo $< | sed s/\.tar\.bz2//g)"

ungz-applications-%: %.tar.gz l_Applications
	@sudo ${TAR} xzf "$<" -C "${WORK_D}/Applications"
	@sudo chown -R root:admin "${WORK_D}/Applications/$(shell echo $< | sed s/\.tar\.gz//g)"

ungz-utilities-%: %.tar.gz l_Applications_Utilities
	@sudo ${TAR} xzf "$<" -C "${WORK_D}/Applications/Utilities"
	@sudo chown -R root:admin "${WORK_D}/Applications/Utilities/$(shell echo $< | sed s/\.tar\.gz//g)"

#Some helpful functions to combine multiple shell commands into a single call
# Note that spaces matter when calling functions and the arguments are comma separated.
# Examples: $(call createdir,${WORK_D}/Library/Services,root:wheel,755)
#         : $(call copydir,My.app,${WORK_D}/Library/Services/My.app,root:wheel,755)

createdir=@\
	sudo mkdir -p "$(1)"; \
	sudo chown "$(2)" "$(1)"; \
	sudo chmod "$(3)" "$(1)"; \

copydir=@\
	sudo ${CP} -R "$(1)" "$(2)"; \
	sudo chown -R "$(3)" "$(2)"; \
	sudo chmod -R "$(4)" "$(2)"; \
	
# Some text files have types and creators, encodings, markers for last edit location etc.
# If you want to remove one or more of these from your text files you can use the following functions
# Because xattr will fail if there is no extended attribute we eat ALL errors
REMOVE_FILETYPE=sudo ${XATTR} -d "com.apple.FinderInfo"   "$(1)" 2> /dev/null || NOP=42
REMOVE_RESOURCE=sudo ${XATTR} -d "com.apple.ResourceFork" "$(1)" 2> /dev/null || NOP=42
REMOVE_ENCODING=sudo ${XATTR} -d "com.apple.TextEncoding" "$(1)" 2> /dev/null || NOP=42

#remove_all_xattrs

