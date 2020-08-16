#!/bin/bash
# WARNICK v1.2.1
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
# - wget
# - perl
# - RuntimeDirectorySize directive in /etc/systemd/logind.conf set to 50% or more

# CHANGE IN RUNTIME REQUIREMENTS
# You must edit /etc/systemd/logind.conf and change "RuntimeDirectorySize" directive to 
# 50% or more. By default, 10% of physical memory is used by the runtime temporary directory.
# This may or may not be enough for Warnick to create its temporary log files.
# A larger size may be needed for Warnick to run properly.
# --------------------------------------------
#
# This is a maximum depth hardlimit (to prevent infinite loops), and 
# will exit the subprocess once the limit has been reached.
# Note: If the site is large, do not use more than 5 or 6 here.
#
# How deep should the script delve into the site (by default)
export maxdepth=5


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

# RUN ONLY ON FIRST START
if [[ -z "$3" ]]; then
  # Set starting path
  startpath=$path

  # Set temporary directory
  tempdir="/run/user/$UID/warnick-$(date +%N |md5sum |cut -b 1-10)"
  logfile="$tempdir/recovery.log"

  mkdir -p $tempdir

  echo "Mirroring contents from: $host/$startpath" 2>&1 |tee -a $logfile
  echo "Temporary directory set to: $tempdir/" 2>&1 |tee -a $logfile
  echo "Log file is: $logfile" 2>&1 |tee -a $logfile
  echo "=============================================================" 2>&1 |tee -a $logfile
fi

# If tempdir was passed on to us, then use it
if [[ ! -z "$4" ]]; then tempdir=$4; fi

# If logfile was passed on to us, then use it
if [[ ! -z "$5" ]]; then logfile=$5; fi

# If startpath was passed on to us, then use it
if [[ ! -z "$6" ]]; then startpath=$6; fi

d=$2

# Create output data directory if not already existing
#mkdir "./sites" >/dev/null 2>&1

if [ "$1" = "" ]
  then
    printf "\nUsage:\n\n"
    printf "  $ $0 <url> [datestring]\n\n"
    printf "  $ $0 www.domain.com\n"
    printf "  $ $0 www.domain.com/path_to/file.html 199704\n"
  else
    if [ "$2" = "" ]
    then
      printf "Warning: No date specified. Using default \"$defaultdate\"\n" 2>&1 |tee -a $logfile
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
      printf "\n`date +"%d.%m.%Y %T"` GET($pl/$maxdepth): - Maximum depth reached (maxdepth=$maxdepth), exiting subprocess." 2>&1 |tee -a $logfile
      exit
    fi

    #touch ./sites/recovery.log
#    printf "`date +"%d.%m.%Y %T"` GET($pl): http://$host/$path\n" 2>&1 |tee -a $logfile
    #rm -r ./sites/$host/web >/dev/null 2>&1

    # Check if file exists before downloading...
    if [ -f "./sites/$host/$path" ] || [ -f "./sites/$host/$path/index.html" ] || [ -f "./sites/$host/$path/index.htm" ] || [ -f "./sites/$host/$path/index.shtml" ] || [ -f "./sites/$host/$path/index.asp" ]; then
      mkdir -p "$tempdir/web" >/dev/null 2>&1
      existing="1"
    else
      # wget --quiet -nH -p -nc -P ./sites/$host http://web.archive.org/web/${d}00000000id_/http://$host/$path
      #wget --quiet -e robots=off -nH -nc -P ./sites/$host/web http://web.archive.org/web/${d}00000000id_/http://$host/$path 2>&1 |tee -a ./sites/recovery.log
      printf "\n`date +"%d.%m.%Y %T"` GET($pl/$maxdepth): http://$host/$path " 2>&1 |tee -a $logfile
      wget --quiet -e robots=off -nH -nc -P $tempdir/web http://web.archive.org/web/${d}id_/http://$host/$path 2>&1 |tee -a $logfile
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
    if [[ ! "$path" == *.* ]]; then
      ext="/index.html" # add extension to filename to be added later!
    fi

    # Create path for downloaded file
#    echo EEEEEEEEE $outputfile -- $path -- $ext EEEEEEEEEEE
#    echo "mkdir -p `dirname ./sites/$host/$path$ext.`"
    mkdir -p `dirname ./sites/$host/$path$ext` >/dev/null 2>&1

    # If a file was downloaded
    if [ -f "$outputfile" ]; then
#      echo "mv $outputfile ./sites/$host/$path$ext" >/dev/null 2>&1
      mv $outputfile ./sites/$host/$path$ext >/dev/null 2>&1   #move wget'ed file out of ./web
      rm -r $tempdir/web >/dev/null 2>&1                  #remove ./web

      # cooldown timer
      printf " "
      for i in {1..2}
      do
        printf "\b/"; sleep .1
        printf "\b-"; sleep .1
        printf "\b\\"; sleep .1
        printf "\b|"; sleep .1
      done
      printf "\bOK! "

#      if [ "$path" == "" ]; then
#        ./getrel.sh $host/`basename $outputfile` $d --noverbose $pl # --noverbose or --verbose
#      else
#        ./getrel.sh $host/$path$ext $d --noverbose $pl          # --noverbose or --verbose
#      fi
    else
      if [ "$existing" == "1" ]; then
        printf "\n`date +"%d.%m.%Y %T"` GET($pl/$maxdepth): EXISTS http://$host/$path$ext " 2>&1 |tee -a $logfile
        #printf "/"
      fi
#      else
      if [ ! "$existing" == "1" ]; then
        printf "\n`date +"%d.%m.%Y %T"` GET($pl/$maxdepth): - Error processing file or retrieved file not found." 2>&1 |tee -a $logfile
        if [ "$dummies" == "1" ]; then
#          printf "`date +"%d.%m.%Y %T"` GET($pl): Creating dummy file in its place.\n" 2>&1 |tee -a ./sites/recovery.log
#          printf "`date +"%d.%m.%Y %T"` GET($pl):   $ touch ./sites/$host/$path$ext\n" 2>&1 |tee -a ./sites/recovery.log
          printf "\n`date +"%d.%m.%Y %T"` GET($pl/$maxdepth): - Creating dummy file ./sites/$host/$path$ext" 2>&1 |tee -a $logfile
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
#    rm -r $tempdir >/dev/null 2>&1
fi
