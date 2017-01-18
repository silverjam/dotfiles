#!/bin/bash

SCM_TOOLS=$HOME/dev/IBM.RTC/jazz

http_proxy= https_proxy= no_proxy= \
SCM_ALLOW_INSECURE=1 \
RTC_SCRIPTS_BASE=$SCM_TOOLS/scmtools/eclipse/scripts \
PRGPATH=$SCM_TOOLS/scmtools/eclipse/scripts \
\
    $SCM_TOOLS/scmtools/eclipse/lscm "$@"
