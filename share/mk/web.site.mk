# bsd.web.mk
# $FreeBSD: www/share/mk/web.site.mk,v 1.60 2004/04/12 11:52:38 phantom Exp $

#
# Build and install a web site.
#
# Basic targets:
#
# all (default) -- performs batch mode processing necessary
# install -- installs everything
# clean -- remove anything generated by processing
#

.if exists(${.CURDIR}/../Makefile.inc)
.include "${.CURDIR}/../Makefile.inc"
.endif

WEBDIR?=	${.CURDIR:T}
CGIDIR?=	${.CURDIR:T}
DESTDIR?=	${HOME}/public_html

WEBOWN?=	${USER}
WEBGRP?=	www
WEBMODE?=	664

CGIOWN?=	${USER}
CGIGRP?=	www
CGIMODE?=	775

CP?=		/bin/cp
CVS?=		/usr/bin/cvs
ECHO_CMD?=	echo
FIND?=		/usr/bin/find
SETENV?=	/usr/bin/env
LN?=		/bin/ln
MKDIR?=		/bin/mkdir
MV?=		/bin/mv
PERL?=		/usr/bin/perl5
RM?=		/bin/rm
SED?=		/usr/bin/sed
SH?=		/bin/sh
SORT?=		/usr/bin/sort
TOUCH?=		/usr/bin/touch
TRUE?=		/usr/bin/true

LOCALBASE?=	/usr/local
PREFIX?=	${LOCALBASE}

.if !defined(OPENJADE)
SGMLNORM?=	${PREFIX}/bin/sgmlnorm
.else
SGMLNORM?=	${PREFIX}/bin/osgmlnorm
.endif
CATALOG?=	${PREFIX}/share/sgml/html/catalog
SGMLNORMOPTS?=	-d ${SGMLNORMFLAGS} -c ${CATALOG} -D ${.CURDIR}

XSLTPROC?=	${PREFIX}/bin/xsltproc
XSLTPROCOPTS?=	${XSLTPROCFLAGS}

TIDY?=		${PREFIX}/bin/tidy
.if defined(TIDY_VERBOSE)
_TIDYLOGFILE=	tidyerr.${.TARGET}
CLEANFILES+=	tidyerr.*
.else
_TIDYLOGFILE=	/dev/null
.endif
TIDYOPTS?=	-i -m -raw -preserve -f ${_TIDYLOGFILE} -asxml ${TIDYFLAGS}

HTML2TXT?=	${PREFIX}/bin/w3m
HTML2TXTOPTS?=	-dump ${HTML2TXTFLAGS}
ISPELL?=	ispell
ISPELLOPTS?=	-l -p /usr/share/dict/freebsd ${ISPELLFLAGS}

WEBCHECK?=	${PREFIX}/bin/webcheck
WEBCHECKOPTS?=	-ab ${WEBCHECKFLAGS}
WEBCHECKDIR?=	/webcheck
WEBCHECKINSTALLDIR?= ${DESTDIR}${WEBCHECKDIR} 
.if !defined(WEBCHECKURL)
WEBCHECKURL!=	${ECHO_CMD} http://www.FreeBSD.org/${WEBBASE:S/data//}/${WEBDIR:S/data//}/ | ${SED} -E "s%/+%/%g"
.endif

#
# Install dirs derived from the above.
#
DOCINSTALLDIR=	${DESTDIR}${WEBBASE}/${WEBDIR}
CGIINSTALLDIR=	${DESTDIR}${WEBBASE}/${CGIDIR}

#
# The orphan list contains sources specified in DOCS that there
# is no transform rule for.  We start out with all of them, and
# each rule below removes the ones it knows about.  If any are
# left over at the end, the user is warned about them and build
# breaks.
#
ORPHANS:=	${DOCS}

#
# Tell install(1) to always copy file being installed.
#
COPY=	-C

#
# Where the ports live, if CVS isn't used (ie. NOPORTSCVS is defined)
#
PORTSBASE?=	/usr

#
# Instruct bsd.subdir.mk to NOT to process SUBDIR directive.  It is not
# neccessary since web.site.mk do it using own rules.
#
NO_SUBDIR=	YES

#
# for dependency
#
.if !defined(WITHOUT_DOC)
#
# When WITHOUT_DOC is not defined, we use doc.common.mk.
#
DOC_PREFIX?=	${WEB_PREFIX}/../doc
.if exists(${DOC_PREFIX}/share/mk/doc.common.mk)
.include "${DOC_PREFIX}/share/mk/doc.common.mk"
.else
.error	${DOC_PREFIX}/share/mk/doc.common.mk not found.\
	Define $$WITHOUT_DOC for building without the doc/ module.
.endif
.else # !defined(WITHOUT_DOC)
#
# When WITHOUT_DOC is defined, we should not use files in doc/ module at all.
#
.if !defined(WWW_LANGCODE) || empty(WWW_LANGCODE)
_WEB_PREFIX!=			realpath ${WEB_PREFIX}
WWW_LANGCODE:=			${.CURDIR:S,^${_WEB_PREFIX}/,,:C,^([^/]+)/.*,\1,}
.undef _WEB_PREFIX
.endif
.endif # !defined(WITHOUT_DOC)

XML_ADVISORIES?=		${WEB_PREFIX}/share/sgml/advisories.xml
XML_NOTICES?=			${WEB_PREFIX}/share/sgml/notices.xml

XML_NEWS_NEWS_MASTER=		${WEB_PREFIX}/en/news/news.xml
XML_NEWS_NEWS=			${WEB_PREFIX}/${WWW_LANGCODE}/news/news.xml
XML_NEWS_PRESS_MASTER=		${WEB_PREFIX}/en/news/press.xml
XML_NEWS_PRESS=			${WEB_PREFIX}/${WWW_LANGCODE}/news/press.xml
XML_NEWS_INCLUDES_MASTER=	${WEB_PREFIX}/en/news/includes.xsl
XML_NEWS_INCLUDES=		${WEB_PREFIX}/${WWW_LANGCODE}/news/includes.xsl

XML_NAVIGATION=			${WEB_PREFIX}/${WWW_LANGCODE}/navigation.xml

XML_INCLUDES=	${WEB_PREFIX}/${WWW_LANGCODE}/includes.xsl
XML_INCLUDES+=	${WEB_PREFIX}/share/sgml/includes.header.xsl
XML_INCLUDES+=	${WEB_PREFIX}/share/sgml/includes.misc.xsl
XML_INCLUDES+=	${WEB_PREFIX}/share/sgml/includes.release.xsl
XML_INCLUDES+=	${WEB_PREFIX}/share/sgml/transtable-common.xsl
XML_INCLUDES+=	${WEB_PREFIX}/share/sgml/includes.xsl

SGML_INCLUDES=	${WEB_PREFIX}/${WWW_LANGCODE}/includes.sgml
SGML_INCLUDES+=	${WEB_PREFIX}/share/sgml/includes.header.sgml
SGML_INCLUDES+=	${WEB_PREFIX}/share/sgml/includes.misc.sgml
SGML_INCLUDES+=	${WEB_PREFIX}/share/sgml/includes.release.sgml
SGML_INCLUDES+=	${WEB_PREFIX}/share/sgml/includes.sgml

##################################################################
# Transformation rules

###
# file.sgml --> file.html
#
# Runs file.sgml through spam to validate and expand some entity
# references are expanded.  file.html is added to the list of
# things to install.

.SUFFIXES:	.sgml .html
.if defined(REVCHECK)
PREHTML?=	${WEB_PREFIX}/ja/prehtml
CANONPREFIX0!=	cd ${WEB_PREFIX}; ${ECHO_CMD} $${PWD};
CANONPREFIX=	${PWD:S/^${CANONPREFIX0}//:S/^\///}
LOCALTOP!=	${ECHO_CMD} ${CANONPREFIX} | \
	${PERL} -pe 's@[^/]+@..@g; $$_.="/." if($$_ eq".."); s@^\.\./@@;'
DIR_IN_LOCAL!=	${ECHO_CMD} ${CANONPREFIX} | ${PERL} -pe 's@^[^/]+/?@@;'
PREHTMLOPTS?=	-revcheck "${LOCALTOP}" "${DIR_IN_LOCAL}" ${PREHTMLFLAGS}
.else
DATESUBST?=	's/<!ENTITY date[ \t]*"$$Free[B]SD. .* \(.* .*\) .* .* $$">/<!ENTITY date	"Last modified: \1">/'
PREHTML?=	${SED} -e ${DATESUBST}
.endif

GENDOCS+=	${DOCS:M*.sgml:S/.sgml$/.html/g}
ORPHANS:=	${ORPHANS:N*.sgml}

.sgml.html: ${SGML_INCLUDES}
	${PREHTML} ${PREHTMLOPTS} ${.IMPSRC} | \
	${SETENV} SGML_CATALOG_FILES= \
		${SGMLNORM} ${SGMLNORMOPTS} > ${.TARGET} || \
			(${RM} -f ${.TARGET} && false)
.if !defined(NO_TIDY)
	-${TIDY} ${TIDYOPTS} ${.TARGET}
.endif

##################################################################
# Special Targets

#
# Spellcheck all generated documents in the current directory.
#
spellcheck:
.for _entry in ${GENDOCS}
	@echo "Spellcheck ${_entry}"
	@${HTML2TXT} ${HTML2TXTOPTS} ${.OBJDIR}/${_entry} | ${ISPELL} ${ISPELLOPTS}
.endfor

#
# Check installed page's hypertext references.  Checking is done relatively
# to ${.CURDIR} value, i.e. calling 'make webcheck' in www/ru/java
# directory will force checking all URLs at http://www.FreeBSD.org/ru/java/
#
# NOTE: webcheck's output always stored to ${DESTDIR}/webcheck directory.
#
webcheck:
	@[ -d ${WEBCHECKINSTALLDIR} ] || ${MKDIR} ${WEBCHECKINSTALLDIR}
	${WEBCHECK} ${WEBCHECKOPTS} -o ${WEBCHECKINSTALLDIR} ${WEBCHECKURL}

#
# Check if all directories and files in current directory are listed in
# Makefile as processing source.  If anything not listed is found, then
# user is warned about (it can be forgotten file or directory).
#
.if make(checkmissing)
# skip printing '===> ...' while processing SUBDIRs
ECHODIR=	${TRUE}

# detect relative ${.CURDIR}
_CURDIR!=	realpath ${.CURDIR}
_PFXDIR!=	realpath ${WEB_PREFIX}
CDIR=		${_CURDIR:S/${_PFXDIR}\///}

# populate missing directories list based on $SUBDIR
_DIREXCL=	! -name CVS
.for entry in ${SUBDIR}
_DIREXCL+=	! -name ${entry}
.endfor
MISSDIRS!=	${FIND} ./ -type d ${_DIREXCL} -maxdepth 1 | ${SED} "s%./%%g"

# populate missing files list based on $DOCS, $DATA and $CGI
_FILEEXCL=	! -name Makefile\* ! -name includes.\*
.for entry in ${DOCS} ${DATA} ${CGI}
_FILEEXCL+=	! -name ${entry}
.endfor
MISSFILES!=	${FIND} ./ -type f ${_FILEEXCL} -maxdepth 1 | ${SED} "s%./%%g"

checkmissing:	_PROGSUBDIR
.if !empty(MISSDIRS)
	@${ECHO_CMD} "===> ${CDIR}"
	@${ECHO_CMD} "Directories not listed in SUBDIR:"
.for entry in ${MISSDIRS}
	@${ECHO_CMD} "    >>> ${entry}"
.endfor
.endif
.if !empty(MISSFILES)
	@${ECHO_CMD} "===> ${CDIR}"
	@${ECHO_CMD} "Files not listed in DOCS/DATA/CGI:"
.for entry in ${MISSFILES}
	@${ECHO_CMD} "    >>> ${entry} "
.endfor
.endif
.endif

##################################################################
# Main Targets

#
# If no target is specified, .MAIN is made.
#
.MAIN: all

#
# Build most everything.
#
all: ${COOKIE} orphans ${GENDOCS} ${DATA} ${CGI} _PROGSUBDIR

#
# Warn about anything in DOCS that has no suffix translation rule.
#
.if !empty(ORPHANS)
orphans:
	@${ECHO} Warning!  I don\'t know what to do with: ${ORPHANS}; \
	exit 1
.else
orphans:
.endif

#
# Clean things up.
#
.if !target(clean)
clean: _PROGSUBDIR
	${RM} -f Errs errs mklog ${GENDOCS} ${CLEANFILES}
.endif

#
# Install targets: before, real, and after.
#
.if !target(install)
.if !target(beforeinstall)
beforeinstall:
.endif
.if !target(afterinstall)
afterinstall:
.endif

INSTALL_WEB?=	\
	${INSTALL} ${COPY} ${INSTALLFLAGS} \
				-o ${WEBOWN} -g ${WEBGRP} -m ${WEBMODE}
INSTALL_CGI?=	\
	${INSTALL} ${COPY} ${INSTALLFLAGS} \
				-o ${CGIOWN} -g ${CGIGRP} -m ${CGIMODE}
_ALLINSTALL+=	${GENDOCS} ${DATA}

realinstall: ${COOKIE} ${_ALLINSTALL} ${CGI} _PROGSUBDIR
.if !empty(_ALLINSTALL)
	@${MKDIR} -p ${DOCINSTALLDIR}
.for entry in ${_ALLINSTALL}
.if exists(${.CURDIR}/${entry})
	${INSTALL_WEB} ${.CURDIR}/${entry} ${DOCINSTALLDIR}
.else
	${INSTALL_WEB} ${entry} ${DOCINSTALLDIR}
.endif
.endfor
.if defined(INDEXLINK) && !empty(INDEXLINK)
	cd ${DOCINSTALLDIR}; ${LN} -fs ${INDEXLINK} index.html
.endif
.endif
.if defined(CGI) && !empty(CGI)
	@${MKDIR} -p ${CGIINSTALLDIR}
.for entry in ${CGI}
	${INSTALL_CGI} ${.CURDIR}/${entry} ${CGIINSTALLDIR}
.endfor
.endif

# Set up install dependencies so they happen in the correct order.
install: afterinstall
afterinstall: realinstall2
realinstall: beforeinstall
realinstall2: realinstall
.endif 

#
# This recursively calls make in subdirectories.
#
_PROGSUBDIR: .USE
.if defined(SUBDIR) && !empty(SUBDIR)
.for entry in ${SUBDIR}
	@${ECHODIR} "===> ${DIRPRFX}${entry}"
	@cd ${.CURDIR}/${entry}; \
		${MAKE} ${.TARGET:S/realinstall/install/:S/.depend/depend/} \
			DIRPRFX=${DIRPRFX}${entry}/
.endfor
.endif

.include <bsd.obj.mk>

#
# Process 'make obj' recursively (should be declared *after* inclusion
# of bsd.obj.mk)
#
obj:	_PROGSUBDIR

# THE END
