#!/bin/bash
# WARNICK v1.3.0
# Web-site mirroring tool for archive.org
#
# Developed by Oliver Molini
# Based on warrick.pl written by Frank McCown at Old Dominion University
#
# Copyright (CC BY-NC-SA 4.0) Oliver Molini
# For further licensing information, please visit 
# https://creativecommons.org/licenses/by-nc-sa/4.0/
#
# Usage:
# $ get.sh <url> [datestring]
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

# CHANGE IN RUNTIME REQUIREMENTS
# You must edit /etc/systemd/logind.conf and change "RuntimeDirectorySize" directive to 
# 50% or more. By default, 10% of physical memory is used by the runtime temporary directory.
# This may or may not be enough for Warnick to create its temporary log files.
# A larger size may be needed for Warnick to run properly.
#
# 2020-08-29    1.2.3    Add more robust logging with adjustable logging levels to
#                        cut down on log file sizes.
# 2020-08-29    1.3.0    Enforce dates to prevent drifting to different years.
# --------------------------------------------
#
# This is a maximum depth hardlimit (to prevent infinite loops), and 
# will exit the subprocess once the limit has been reached.
# Note: If the site is large, do not use more than 5 or 6 here.
#
# How deep should the script delve into the site (by default)
export maxdepth=5

# Log level for Warnick.
# 0 - Silent operation
# 1 - Normal logs. Display start of session, downloaded files and error conditions
# 2 - All logs. In addition to normal logs, display existing files.
# 3 - Display debug information in addition to all above
export loglevel=1

#
# If a file cannot be downloaded, create a dummy file in its place.
# Creating dummy files makes sure that the script does not make any
# attempts to download non-retrievable files over and over again,
# which saves time and capacity.
#
# Create dummy files in place of non-retrievable files? 
#
dummies=1

#
# --------------------------------------------
# INIT VARS
host=`echo $1 |cut -d/ -f1`
path=`echo "${1%/}" |cut -s -d/ -f2-`
defaultdate=199704

# If path is specified by parameter $2, and subdirsonly is set to 1,
# stay in subdirectory, and download html files only within the subdirectory.
# Download images from anywhere if necessary.
export subdirsonly=1

function log {
  if [ "$loglevel" -ge "$1" ]; then
    printf "\n`date +"%d.%m.%Y %T"` ($pl/$maxdepth): $2" 2>&1 |tee -a $logfile
  fi
}

# RUN ONLY ON FIRST START
if [[ -z "$3" ]]; then
  # Set starting path
  startpath=$path

  # Set temporary directory
  tempdir="/run/user/$UID/warnick-$(date +%N |md5sum |cut -b 1-10)"
  logfile="$tempdir/recovery.log"

  mkdir -p $tempdir

  log 1 "Mirroring contents from: $host/$startpath"
  log 1 "Temporary directory set to: $tempdir/"
  log 1 "Log file is: $logfile"
  log 1 "========================================================"
fi

# If tempdir was passed on to us, then use it
if [[ ! -z "$4" ]]; then tempdir=$4; fi

# If logfile was passed on to us, then use it
if [[ ! -z "$5" ]]; then logfile=$5; fi

# If startpath was passed on to us, then use it
if [[ ! -z "$6" ]]; then startpath=$6; fi

d=$2

if [ "$1" = "" ]
  then
    printf "\nUsage:\n\n"
    printf "  $ $0 <url> [datestring]\n\n"
    printf "  $ $0 www.domain.com\n"
    printf "  $ $0 www.domain.com 1997\n"
    printf "  $ $0 www.domain.com/path_to/file.html 199704\n"
    printf "  $ $0 www.domain.com/path_to/file.html 19970411\n"
  else
    if [ "$2" = "" ]
    then
      log 1 "Warning: No date specified. Using default \"$defaultdate\""
      d=$defaultdate
    fi

    # Track how many subprocesses we are running
    if [ "$3" = "" ]
      then
        pl=1
      else
        pl=`expr $3 + 1`
    fi

    # Prevent infinite loops here
    if [ "$pl" -gt "$maxdepth" ]; then
      log 2 "- Maximum depth reached (maxdepth=$maxdepth), exiting subprocess."
      exit
    fi

#    printf "`date +"%d.%m.%Y %T"` GET($pl): http://$host/$path\n" 2>&1 |tee -a $logfile

    # Check if file exists before downloading...
    if [ -f "./sites/$host/$path" ] || [ -f "./sites/$host/$path/index.html" ] || [ -f "./sites/$host/$path/index.htm" ] || [ -f "./sites/$host/$path/index.shtml" ] || [ -f "./sites/$host/$path/index.asp" ]; then
      mkdir -p "$tempdir/web" >/dev/null 2>&1
      existing="1"
    else
      # wget --quiet -nH -p -nc -P ./sites/$host http://web.archive.org/web/${d}00000000id_/http://$host/$path
      #wget --quiet -e robots=off -nH -nc -P ./sites/$host/web http://web.archive.org/web/${d}00000000id_/http://$host/$path 2>&1 |tee -a ./sites/recovery.log
      archurl="https://web.archive.org/web/${d}00000000id_/http://$host/$path"
      log 3 "Trying $archurl"

      # Get status code for next page to be archived.
      archstatus="$(curl -sI $archurl |head -n1 |cut -b8-10)"
      # File not found
      if [[ $archstatus == "404" ]]; then
        log 3 "404 - File not found, do not proceed."
      fi

      # Page found and archived (200)
      if [[ $archstatus == "200" ]]; then
        log 3 "200 Page found!"
        wget --quiet --max-redirect=0 -e robots=off -nH -nc -P $tempdir/web $archurl 2>&1 |tee -a $logfile
      fi

      # Page redirected (302)
      if [[ $archstatus == "302" ]]; then
        archfounddate=$(curl -sI $archurl |grep "x-archive-redirect-reason: found" |rev |cut -d' ' -f1 |rev)
        archfounddate=${archfounddate:0:14}
        log 3 "302 - Resource found on a different date ($archfounddate)"
        # Get location field
        if [[ "${archfounddate:0:8}" == "${d:0:8}" ]]; then
          log 3 "302 - Alternative resource found from the same day (${archfounddate:0:8}) $archfounddate"
          altfound=1
        elif [[ "${archfounddate:0:6}" == "${d:0:6}" ]]; then
          log 3 "302 - Alternative resource found within the same month (${archfounddate:0:6}) $archfounddate"
          altfound=1
        elif [[ "${archfounddate:0:4}" == "${d:0:4}" ]]; then
          log 3 "302 - Alternative resource found within the same year (${archfounddate:0:4}) $archfounddate"
          altfound=1
        elif [[ "${archfounddate:0:4}" == "$(expr ${d:0:4} - 1)" ]]; then
          log 3 "302 - Alternative resource found on previous year ($(expr ${d:0:4} - 1)) $archfounddate"
          altfound=1
        elif [[ "${archfounddate:0:4}" == "$(expr ${d:0:4} + 1)" ]]; then
          log 3 "302 - Alternative resource found on following year ($(expr ${d:0:4} + 1)) $archfounddate"
          altfound=1
        fi
        if [[ "$altfound" == "1" ]]; then
          wget --quiet --max-redirect=1 -e robots=off -nH -nc -P $tempdir/web $archurl 2>&1 |tee -a $logfile
        else
          log 2 "302 - No resource found close to date range. Giving up!"
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
      log 1 "http://$host/$path OK!"

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
          log 2 "EXISTS http://$host/$path$ext "
        else
          printf " "
        fi
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
