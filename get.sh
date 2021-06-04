#!/bin/bash
#
# WARNICK Web-site mirroring tool for archive.org
#
# Developed by Oliver Molini for ProtoWeb.org
# Some portions based on warrick.pl by Frank McCown at Old Dominion University
#
# Copyright (CC BY-NC-SA 4.0) Oliver Molini
# For further licensing information, please visit 
# https://creativecommons.org/licenses/by-nc-sa/4.0/
#
# Usage:
# $ get.sh <URL> [datestring] [owner] [maxdepth]
# $ get.sh www.domain.com
# $ get.sh www.domain.com/path_to/file.html 199704
#
# This will start mirroring content from archive.org under the given path and date.
# Date must be given in YYYYMM format.
#
# SCRIPT PREREQUISITES
# - bash, tee, cut, grep, cat, md5sum, date
# - wget, curl
# - perl
# - RuntimeDirectorySize directive in /etc/systemd/logind.conf set to 50% or more
#
# CHANGE IN RUNTIME REQUIREMENTS
# You must edit /etc/systemd/logind.conf and change "RuntimeDirectorySize" directive to 
# 50% or more. By default, 10% of physical memory is used by the runtime temporary directory.
# This may or may not be enough for Warnick to create its temporary log files.
# A larger size may be needed for Warnick to run properly.
#
# CHANGELOG
# -----------------------------------------------------------------------------
# 2020-08-29    1.2.3    Add more robust logging with adjustable logging levels
#                        to cut down on log file sizes.
# 2020-08-29    1.3.0    Enforce dates to prevent drifting to different years.
# 2020-09-07    1.4.0    Included code to integrate with web configuration 
#                        panel.
# 2020-09-07    1.4.1    Fixed bugs.
# 2021-04-30    1.4.2    Improved console usage, autodetect http:// prefix and
#                        remove if necessary. Added notice when program is
#                        started. Added version number in it's own variable.
# 2021-04-30    1.4.3    Improved efficiency in code. Fixed bugs. The link
#                        parser isn't perfect, and may think ALIGN=MIDDLE is a
#                        perfectly valid file. With some changes the parser
#                        script now makes a better attempt at detecting and
#                        ignoring links that clearly are not real files.
# 2021-04-30    1.4.4    Added watchdog counter to prevent infinite loops.
# -----------------------------------------------------------------------------

# Script version number
export version="1.4.4"

# This variable sets the default maximum depth hardlimit, and will exit the
# subprocess once the limit has been reached.
#
# Note: If the site is large, do not use much more than 5 or 6 here, to prevent
# the script from entering seemingly neverending infinite loops.
#
# In many cases a page that is 5 links deep can be reached from a page that is
# at a shallower depth, unless the web site happens to be a portal, so it
# should be relatively safe to use a lower value here, such as 4 or 5. This
# setting can be overridden with a maxdepth parameter issued from the command
# line.
#
# How deep should the script delve into the site (by default)
#
export defaultmaxdepth=5

# Log level for Warnick
# After operation completes, the log file (recovery.log) will be saved along with
# the site files.
#
# 0 - Silent operation.
# 1 - Normal logs. Display start of session, downloaded files and error conditions
# 2 - All logs. In addition to normal logs, display existing files.
# 3 - Display debug information in addition to all above
#
export loglevel=1

#
# If a file cannot be downloaded, create a dummy file in its place.
# Dummy files help the script keep track of referenced files that do not exist
# at archive.org for the given target date and is recommended to be left as is.
#
# Creating dummy files makes sure that the script does not make any attempts
# to download non-retrievable files over and over again, which saves time and 
# capacity.
#
# Create dummy files in place of non-retrievable files?
#
# 0 - Dummy files off
# 1 - Dummy files on
dummies=1

#
# --------------------------------------------
# INIT VARS
# Parse host and remove http:// prefix just in case it was entered...
host=$(echo "$1" |sed "s/^http:\/\///g" |cut -d'/' -f1)

# Parse path from given address, edit out http:// prefix.
path=`echo "${1%/}" |sed "s/^http:\/\///g" |cut -s -d/ -f2-`

# If no target date is specified, the defaultdate variable is used.
# The target date governs which files from archive.org wayback machine
# should be downloaded, when multiple versions of the same file exist.
defaultdate=1999

# This is the default owner for the job, used by ProtoWeb. No need
# to change this when launched from linux console.
defaultowner=nobody

# If path is specified by parameter $2, and subdirsonly is set to 1,
# stay in subdirectory, and download html files only within the subdirectory.
# Download images from anywhere if necessary.
export subdirsonly=1

# The script avoids infinite loops by using a watchdog counter. This counter
# is incremented every time there is a page referencing itself somewhere else.
# A higher number usually means a more complete page capture, but increases time
# to download exponentially. The watchdog counter may go over this value.
# If you don't know what this is, leave it at default value of 100.
export wdthreshold=100

function log {
  if [ "$loglevel" -ge "$1" ]; then
    if [ ! -z $pl ]; then
      plstr=" ($pl/$maxdepth)"
    fi
    wdcounter="$(cat $tempdir/watchdog.tmp 2>/dev/null)"
    if [ $wdcounter -lt $wdthreshold ]; then wdcounter=; else wdcounter=" (watchdog counter $wdcounter)"; fi
    printf "\n$(date +"%Y/%m/%d %H:%M:%S")$plstr:$wdcounter $2" 2>&1 |tee -a $logfile
  fi
}


# RUN ONLY ON FIRST START
if [[ -z "$5" ]]; then
  echo
  echo "Warnick web-site mirroring tool for archive.org version $version"
  echo "============================================================="
  echo
  echo "Developed by Oliver Molini for ProtoWeb.org 2011-2021"
  echo "Some portions based on warrick.pl by Frank McCown at Old Dominion University"
fi

if [ "$1" = "" ]; then
  echo
  echo "Usage:"
  echo "  $ $0 <URL> [datestring] [owner] [maxdepth]"
  echo
  echo "  $ $0 www.domain.com"
  echo "  $ $0 www.domain.com 1997"
  echo "  $ $0 www.domain.com/path/ 199704"
  echo "  $ $0 www.domain.com/path/file.html 199704 nobody 5"
  echo
  echo "  A proper invocation of this script will mirror the given URL from"
  echo "  archive.org, and store the site files under the subdirectory"
  echo "  ./sites/www.domain.com"
  echo
  exit 0
fi

if [ -z "$2" ]; then
  log 1 "Warning: No date specified. Using default \"$defaultdate\""
  d=$defaultdate
else
  d=$2
fi


# RUN ONLY ON FIRST START
if [[ -z "$5" ]]; then
  # Set starting path
  startpath=$path

  if [[ -z "$3" ]]; then
    log 1 "No owner specified. Using default \"$defaultowner\""
    owner=$defaultowner
  else
    owner=$3
  fi

  # Set temporary directory
  wid="$(date +%N |md5sum |cut -b 1-10)"
  if [ "$owner" != "$defaultowner" ]; then
    # This part gets executed when the owner is specified,
    # as expected when web integration and multiuser mode are enabled.
    tempdir="./temp/pending/warnick-$wid"
  else
    tempdir="/run/user/$UID/warnick-$wid"
  fi
  logfile="$tempdir/recovery.log"
  mkdir -p $tempdir
  chown :www-data $tempdir
  chmod 770 $tempdir

  if [ -z "$4" ]; then
    log 1 "Warning: No max depth specified. Using default \"$defaultmaxdepth\""
    export maxdepth=$defaultmaxdepth
  else
    export maxdepth=$4
  fi

  # reset watchdog counter
  echo "0" >$tempdir/watchdog.tmp

  log 1 "Mirroring contents from: $host/$startpath"
  log 1 "Target Date: $d"
  log 1 "Max Traversal Depth: $maxdepth"
  log 1 "Temporary directory set to: $tempdir/"
  log 1 "Log file is: $logfile"
  log 1 "Job owner: $owner"
  log 1 "Operation started at: $(date +"%Y/%m/%d %H:%M:%S %Z")"
  log 1 "========================================================"
fi

# If tempdir was passed on to us, then use it
if [[ ! -z "$6" ]]; then tempdir=$6; fi

# If logfile was passed on to us, then use it
if [[ ! -z "$7" ]]; then logfile=$7; fi

# If startpath was passed on to us, then use it
if [[ ! -z "$8" ]]; then startpath=$8; fi

if [ ! -z "$1" ]; then
    # Track how many subprocesses we are running
    if [ "$5" = "" ]
      then
        pl=1
      else
        pl=`expr $5 + 1`
    fi

    # Prevent infinite loops here
    if [ "$pl" -gt "$maxdepth" ]; then
      log 2 "- Maximum depth reached (maxdepth=$maxdepth), exiting subprocess."
      exit
    fi

    # Stop processing, if "cancel-job" file is found in $tempdir
    if [ -f "$tempdir/cancel-job" ]; then
      log 1 "- Job canceled!"
      exit
    fi

    # Stop processing, if watchdog counter is above threshold
    wdcounter=$(cat $tempdir/watchdog.tmp 2>/dev/null)
    wdoverage=$(expr $wdcounter - $wdthreshold)
    if [ $wdoverage -ge 0 ] && [ "$pl" -ge "$(expr $maxdepth - $wdoverage / $wdthreshold)" ]; then
      log 3 "- Watchdog limit reached (wdcounter=$wdcounter, wdoverage=$wdoverage). Exiting subprocess."
      exit
    fi

    # Stop processing if filename contains weird names
    if [[ "${path,,}" == *"border="* ]]; then weirdname=1; fi
    if [[ "${path,,}" == *"width="* ]]; then weirdname=1; fi
    if [[ "${path,,}" == *"height="* ]]; then weirdname=1; fi
    if [[ "${path,,}" == *"alt="* ]]; then weirdname=1; fi
    if [[ "${path,,}" == *"onmouseover"* ]]; then weirdname=1; fi
    if [[ "${path,,}" == *"onmouseout"* ]]; then weirdname=1; fi
    if [[ "${path,,}" == *"()"* ]]; then weirdname=1; fi
    if [[ "${path,,}" == *","* ]]; then weirdname=1; fi
    if [[ "${path,,}" == *"+"* ]]; then weirdname=1; fi
    if [[ "${path,,}" == *"file:"* ]]; then weirdname=1; fi

    if [[ ! -z $weirdname ]]; then
      log 2 "$host/$path Not processing weird file: $path"
      exit
    fi

    # Remove weird characters
    host=$(echo -n $host | tr -d ":\'\"")
    path=$(echo -n $path | tr -d ":\'\"")

#    printf "`date +"%d.%m.%Y %T"` GET($pl): http://$host/$path\n" 2>&1 |tee -a $logfile

    # Check if file exists before attempting to download...
    if [ -f "./sites/$host/$path" ] || [ -f "./sites/$host/$path/index.html" ] || [ -f "./sites/$host/$path/index.htm" ] || [ -f "./sites/$host/$path/index.shtml" ] || [ -f "./sites/$host/$path/index.asp" ]; then
      mkdir -p "$tempdir/web" >/dev/null 2>&1
      existing="1"
    else
      # wget --quiet -nH -p -nc -P ./sites/$host http://web.archive.org/web/${d}00000000id_/http://$host/$path
      #wget --quiet -e robots=off -nH -nc -P ./sites/$host/web http://web.archive.org/web/${d}00000000id_/http://$host/$path 2>&1 |tee -a ./sites/recovery.log

      archurl="https://web.archive.org/web/${d}00000000id_/http://$host/$path"

      log 2 "Trying $archurl"

      # Get status code for next page to be archived.
      archstatus="$(curl -sI $archurl |head -n1 |cut -b8-10)"
      # File not found
      if [[ $archstatus == "404" ]]; then
        log 1 "$host/$path 404 - Not found."
        #log 3 "404 - File not found, cannot proceed."
      fi

      # Page found and archived (200)
      if [[ $archstatus == "200" ]]; then
        log 3 "200 - Page found!"
        wget --quiet --max-redirect=0 -e robots=off -nH -nc -P $tempdir/web $archurl 2>&1 |tee -a $logfile
      fi

      # Page redirected (302)
      if [[ $archstatus == "302" ]]; then
        archfounddate=$(curl -sI $archurl |grep "x-archive-redirect-reason: found" |rev |cut -d' ' -f1 |rev)
        archfounddate=${archfounddate:0:14}
        log 3 "$host/$path 302 - Resource found on a different date ($archfounddate) $path$ext"

        if [[ "$path$ext" == *.html || "$path$ext" == *.htm || "$path$ext" == *.asp || "$path$ext" == *.shtml ]]; then
          # File is a HTML document. Only download if it is at or near target date.
          # Get location field
          if [[ "${archfounddate:0:8}" == "${d:0:8}" ]]; then altfound=1      # Alt found same day
          elif [[ "${archfounddate:0:6}" == "${d:0:6}" ]]; then altfound=1    # Alt found same month
          elif [[ "${archfounddate:0:4}" == "${d:0:4}" ]]; then altfound=1    # Alt found same year
          elif [[ "${archfounddate:0:4}" == "$(expr ${d:0:4} - 1)" ]]; then altfound=1    # Alt found year - 1
          elif [[ "${archfounddate:0:4}" == "$(expr ${d:0:4} - 2)" ]]; then altfound=1    # Alt found year - 2
          elif [[ "${archfounddate:0:4}" == "$(expr ${d:0:4} - 3)" ]]; then altfound=1    # Alt found year - 3
          elif [[ "${archfounddate:0:4}" == "$(expr ${d:0:4} - 4)" ]]; then altfound=1    # Alt found year - 4
          elif [[ "${archfounddate:0:4}" == "$(expr ${d:0:4} + 1)" ]]; then altfound=1    # Alt found year + 1
          elif [[ "${archfounddate:0:4}" == "$(expr ${d:0:4} + 2)" ]]; then altfound=1    # Alt found year + 2
          elif [[ "${archfounddate:0:4}" == "$(expr ${d:0:4} + 3)" ]]; then altfound=1    # Alt found year + 3
          fi
        else
          # The file is not an HTML file, so we can go ahead and download the alternative,
          # since this file won't be parsed for more links.
          altfound=1
        fi

        if [[ "$altfound" == "1" ]]; then
          log 2 "$host/$path 302 - Alternative copy was found that is within target search range (timecode: $archfounddate)"
          wget --quiet --max-redirect=2 -e robots=off -nH -nc -P $tempdir/web $archurl 2>&1 |tee -a $logfile
        else
          log 1 "$host/$path 302 - No resource found near target date. ($archfounddate)"
        fi
      fi
    fi

    # Check to see if wget created the directory ./sites/$host/web
    if [ -d "$tempdir/web" ]; then
      # if /web -directory found, assume the file is there, find the file and save
      # full path to file in the variable $outputfile
      outputfile=`find $tempdir/web -type f`
    else
      # Otherwise clear $outputfile
      outputfile=""
    fi

    # if the file wget just downloaded is a home page for a directory,
    # rename it to index.html
    # BUG: When path contains something/../something, it trips this part
    # old method:   if [[ ! "$path" == *.* ]]; then

    if [[ ! $(echo -n "$path" | rev | cut -d'/' -f1 | rev) == *.* ]]; then
      ext="/index.html" # add extension to filename to be added later!
    fi

    # Create path for downloaded file
    mkdir -p `dirname ./sites/$host/$path$ext` >/dev/null 2>&1

    # If a file was downloaded
    if [ -f "$outputfile" ]; then
      mv $outputfile ./sites/$host/$path$ext >/dev/null 2>&1   #move wget'ed file out of ./web
      rm -r $tempdir/web >/dev/null 2>&1                  #remove ./web
      log 1 "$host/$path OK!"

      # reset watchdog counter
      echo "0" >$tempdir/watchdog.tmp

      # cooldown timer
      printf "\b\b\b   \b\b"
      for i in {1..2}
      do
        printf "\b/"; sleep .1
        printf "\b-"; sleep .1
        printf "\b\\"; sleep .1
        printf "\b|"; sleep .1
      done
      printf "\bOK! "
    else
      if [ "$existing" == "1" ]; then
        if [ "$loglevel" -ge "2" ]; then
          log 2 "EXISTS $host/$path$ext "
        else
          printf " "
        fi
        # Add to watchdog counter
        wdcounter=$(cat $tempdir/watchdog.tmp)
        wdcounter=$(expr $wdcounter \+ 1)
        echo $wdcounter >$tempdir/watchdog.tmp
      fi
      if [ ! "$existing" == "1" ]; then
        log 2 "- Error processing file or retrieved file not found."
        if [ "$dummies" == "1" ]; then
          log 3 "- Creating dummy file ./sites/$host/$path$ext"
          touch ./sites/$host/$path$ext 2>&1
        fi
      fi
    fi

    # Scan links on only specific filetypes
    if [[ "$path$ext" == *.html || "$path$ext" == *.htm || "$path$ext" == *.asp || "$path$ext" == *.shtml ]]; then
      if [ "$path" == "" ]; then
        ./getrel.sh $host/`basename $path$ext` $d --noverbose $pl $tempdir $logfile $startpath # --noverbose or --verbose
      else
        ./getrel.sh $host/$path$ext $d --noverbose $pl $tempdir $logfile $startpath # --noverbose or --verbose
      fi
    fi
fi

# RUN ONLY WHEN LAST PROCESS EXITS
if [[ -z "$5" ]]; then
#  log 1 "Exited process."
#  tempdir="./temp/pending/warnick-$(date +%N |md5sum |cut -b 1-10)"
#  logfile="$tempdir/recovery.log"
  log 1 "Operation finished at: $(date +"%Y/%m/%d %H:%M:%S %Z")"
  echo

  # Canceled? Signal that cancelation was successful.
  if [ -f "$tempdir/cancel-job" ]; then
    log 1 "Job was canceled."
    touch $tempdir/cancel-job-success 2>&1
  fi

  # Change permissions of all files to be readable and writable by www-server
  chown -R :www-data $tempdir 2>&1
  chmod -R 770 $tempdir 2>&1
  chown -R :www-data ./sites/$host 2>&1
  chmod -R 770 ./sites/$host 2>&1

  # Finished successfully
  if [ ! -f "$tempdir/cancel-job" ]; then
    log 1 "Job finished successfully.\n"
    cp $tempdir/recovery.log ./sites/$host/recovery.log
    if [ "$owner" != "$defaultowner" ]; then
      # This part gets executed when the owner is specified,
      # as expected when web integration and multiuser mode are enabled.
      mkdir -p ./temp/complete/warnick-$wid 2>&1 |tee -a $logfile
      mv $tempdir ./temp/complete/ 2>&1  |tee -a $logfile
      mv ./sites/$host ./remote/sites-www/ 2>&1 |tee -a $logfile
    fi
  fi
fi