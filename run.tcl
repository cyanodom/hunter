#!/bin/sh
# the next line restarts using tclsh \
exec tclsh "$0" ${1+"$@"}

set env(LD_LIBRARY_PATH) [pwd]/lib
set env(HIGHLIGHT_DATADIR) [pwd]/share/highlight/

cd bin

if {$argc > 0} {
   exec [pwd]/hunter [list $argv] >@stdout
} else {
   exec [pwd]/hunter >@stdout
}
