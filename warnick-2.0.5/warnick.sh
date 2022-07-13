#!/bin/bash

#
# WARNICK Web-site mirroring tool for The Internet Archive (archive.org)
#
# Developed by Oliver Molini for Protoweb.org 2011-2022
#
# Inspired by warrick.pl by Frank McCown at Old Dominion University 2005-2010
#
# Copyright (CC BY-NC-SA 4.0) Oliver Molini
# For further licensing information, please visit
# https://creativecommons.org/licenses/by-nc-sa/4.0/
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# Usage:
# $ get.sh <URL> [datestring] [maxdepth] [owner]
# $ get.sh www.domain.com
# $ get.sh www.domain.com/path_to/file.html 199704
#
# This will start mirroring content for www.domain.com from the Internet Archive
# Wayback Machine and will prioritize files for the given path and date.
# Date must be given in YYYYMMDD format. MM and DD can be omitted.
#
# SCRIPT PREREQUISITE PROGRAMS:
# - bash 5.0.3 or newer
# - tee, cut, grep, cat, date
# - wget 1.20.1 or newer
# - curl 7.64.0 or newer
#
# OTHER PREREQUISITES:
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
# 2020-09-07    1.4.0    Included code to integrate with web configuration.
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
# 2021-05-29    1.4.4    Added watchdog counter to prevent infinite loops.
# 2021-06-04    1.5.0    Rewrote the link parser engine so the script can more
#                        readily parse non-standard links from HTML pages.
# 2021-06-05    1.5.1    Fixed an issue where not all pages would be archived
#                        due to page links being case insensitive. Some servers
#                        were Windows servers, and file.html and File.html were
#                        actually the same file in servers such as this.
# 2022-07-08    2.0.0    Script rewrite. Complete overhaul on how links get
#                        scanned and using a completely different method of 
#                        scanning a site.
# 2022-07-10    2.0.1    Fixed bugs. Added weird file names and improved
#                        reporting on them.
# 2022-07-10    2.0.2    Fixed incorrect handling of weird filenames.
# 2022-07-10    2.0.3    Optimized code, removed unused functions, re-added
#                        cancel-job functionality.
# 2022-07-11    2.0.4    Fixed bugs in the multi-user environment when in use
#                        with Protoweb
# 2022-07-12    2.0.5    Usability improvements. Creates ./sites folder if it
#                        doesn't already exist. Bug fixes.
# -----------------------------------------------------------------------------

# Script version number
export version="2.0.5"

# This variable sets the default maximum depth hardlimit, and will not scan
# pages for further links if the maximum depth limit has been reached.
# This setting can be overridden with a maxdepth parameter issued from the
# command line.
#
# How deep should the script delve into the site (by default)?
#
export defaultmaxdepth=10

# Log level for Warnick
# After operation completes, the log file (recovery.log) will be saved along with
# the site files.
#
# 0 - Silent operation.
# 1 - Normal logs. Display start of session, downloaded files and error conditions
# 2 - All logs. In addition to normal logs, display existing files.
# 3 - Display even more information in addition to all above
#
export loglevel=1

#
# --------------------------------------------
# INIT VARS
# Parse host and remove http:// prefix just in case it was entered...
paramlink=$(echo "$1" |sed "s/^http:\/\///g")

host=$(echo "$paramlink" |cut -d'/' -f1)
domain=$(echo $host |sed -e "s/www*.\.//g")   #    anttila.fi

# Parse path from given address, edit out http:// prefix.
startpath=`echo "${1%/}" |sed "s/^http:\/\///g" |cut -s -d/ -f2-`

# If no target date is specified, the defaultdate variable is used.
# The target date governs which files from archive.org wayback machine
# should be downloaded, when multiple versions of the same file exist.
defaultdate=1997

# This is the default owner for the job, used by ProtoWeb. No need
# to change this when launched from linux console.
defaultowner=nobody

# If path is specified by parameter $2, and subdirsonly is set to 1,
# stay in subdirectory, and download html files only within the subdirectory.
#
# Download images from anywhere if necessary.
export subdirsonly=1

# The script waits for a cooldown period (in seconds) after each successful
# download. This is used to slow down successive downloads, and prevents
# your IP from getting throttled at archive.org. We recommend using 2 or higher.
cooldown=2

function log {
  if [ "$loglevel" -ge "$1" ]; then
    if [ ! -z $depth ]; then
      depthstr=" (link=$linkno/$linktotal depth=$depth/$maxdepth)"
    fi
    loginfo="$2"
    logstr="\n$(date +"%Y/%m/%d %H:%M:%S")$depthstr: $loginfo"
    if [[ -z "$logfile" ]]; then 
      echo -en "$logstr" 2>&1
    else
      echo -en "$logstr" 2>&1 |tee -a $logfile
    fi
  fi
}

function scanlinks {
  fn=$1
  # Open an HTML file and parse direct and relative links
  newline=$'\n'
  log 3 "Debug: Scanning links for file $fn"

  # ---------------------- PARSE LINKS ------------------------
  searchbuffer=1024
  linkscan=$(grep -obi $fn -e "<a\|<img\|<body\|<script\|<frame") # add tags to detect
  if [[ -z $linkscan ]]; then
    # No links in file. Exit.
    log 2 "Debug: No links detected in file $fn"
    exit 0;
  fi

  newlinksfound=0
  ((depth++))

  while IFS= read -u 4 -r line; do
    byteoffset=$(echo $line |cut -d ':' -f1)
    bytestart=$(expr $byteoffset \+ 1)
    byteend=$(expr $byteoffset \+ $searchbuffer)

    tag="$(cut -zb$bytestart-$byteend $fn |tr -d '\0' |tr '\n' ' ' |cut -d'>' -f1)>"                 # <A HReF = "./case32.html?hello&world" name="test">
    # get offset of link parameter href, src... etc. add tag parameters here.
    # if multiple matches, pick first one (head -n1)
    linkoffset="$(echo -n "$tag" |grep -obi "href\|src\|background" |cut -d':' -f1 |head -n1)"

    if [[ ! -z $linkoffset ]]; then
      # link found!

      directlink=""
      linktype=""

      # step 1 - parse tag
      link="$(echo -n $tag |cut -b$linkoffset- |cut -d'=' -f2 |cut -d'>' -f1 |cut -d'?' -f1)" # "./case32.html" name
      # step 2 - remove spaces and quotes and anything else that we missed
      link="$(echo -n $link |tr -d '\"' |cut -d' ' -f1)"           # ./dir\case32.html#anchor
      # step 3 - remove ./ from beginning of link
      link="$(echo -n $link |sed 's/^\.\///')"                     # /dir\case32.html#anchor
      # step 4 - convert invalid directory separator '\' to '/'
      link=$(echo -n $link |tr '\\' '/')                           # /dir/case32.html#anchor
      # step 5 - remove #anchors and ?params from the end of a link
      link=$(echo -n $link |cut -d'#' -f1 |cut -d'?' -f1)          # /dir/case32.html

      log 3 "Debug: Found link $link"

      # Standardize link to www.hostname.com/path/to/file.html
      # Is this a direct link without a hostname? Add hostname.
      #   - /path/to/file.html
      if [[ ${link:0:1} == "/" ]]; then
        directlink="$host$link"
        linktype="direct"
      fi
      # Is this a link with protocol? Assume this is a direct link. Remove protocol.
      #   - http://www.hostname.com/path/to/file.html
      if [[ ${link:0:7} == "http://" ]] || [[ ${link:0:6} == "ftp://" ]]; then
        directlink="$(echo $link |cut -s -d'/' -f3-)"
        linktype="direct"
      fi

      if [[ -z "$linktype" ]]; then linktype="relative"; fi

      if [[ "$linktype" == "relative" ]]; then
        # RELATIVE LINKS
        # Resolve relative link.
        #
        #   - ../file.html
        if [[ ${link:0:3} == "../" ]]; then
          # Count occurrences in relative URL
          parents=$(echo -n "$link" |grep -o "\.\./" | wc -l)
          ((parents++))
          directlink=$(echo -n $link |cut -d'/' -f${parents}-)
          ((parents++))
          resolvedpath=$(echo $path |rev |cut -d'/' -f${parents}- |rev)
          if [[ ! -z "$resolvedpath" ]]; then resolvedpath="${resolvedpath}/";fi   # add directory prefix if there is a path
          directlink="$host/$resolvedpath$directlink"
        fi
        if [[ -z "$directlink" ]]; then
          # Catchall for the other relative link types
          #   - file.html
          #   - test/file.html
          #   - test/path
          #   - test/
          #   - test
          directlink="$host/$path$link"
        fi
      fi

      # Check for skip conditions
      skiplink=0   # Reset skiplink

      # Empty link - could not decode link
      if [[ -z "$directlink" ]]; then
        log 1 "Warning: Could not decode $link"
        skiplink=1
      else
        # Is this a link on another host?
        linkhost=$(echo $directlink |cut -d'/' -f1)
        if [[ ! "${linkhost,,}" == "$host" ]]; then
          log 1 "Notice: Skipping link leading to another host: $directlink"
          skiplink=1
        fi

        if [[ "${directlink,,}" == "$host" ]]; then directlink=${directlink}/; fi

        # Stop processing if filename contains weird names
        if [[ "${link,,}" == *"border="* ]]; then skiplink=1; fi
        if [[ "${link,,}" == *"width="* ]]; then skiplink=1; fi
        if [[ "${link,,}" == *"height="* ]]; then skiplink=1; fi
        if [[ "${link,,}" == *"alt="* ]]; then skiplink=1; fi
        if [[ "${link,,}" == *"onmouseover"* ]]; then skiplink=1; fi
        if [[ "${link,,}" == *"onmouseout"* ]]; then skiplink=1; fi
        if [[ "${link,,}" == *"()"* ]]; then skiplink=1; fi
        if [[ "${link,,}" == *","* ]]; then skiplink=1; fi
        if [[ "${link,,}" == *"+"* ]]; then skiplink=1; fi
        if [[ "${link,,}" == *"file:"* ]]; then log 1 "Notice: Skipping file system link: $link"; skiplink=1; fi
        if [[ "${link,,}" == *"news:"* ]]; then log 1 "Notice: Skipping news link: $link"; skiplink=1; fi
        if [[ "${link,,}" == *"mailto:"* ]]; then log 1 "Notice: Skipping mailto link: $link"; skiplink=1; fi
        if [[ "${link,,}" == *"gopher:"* ]]; then log 1 "Notice: Skipping gopher link: $link"; skiplink=1; fi
        if [[ "${link,,}" == *"/."* ]]; then skiplink=1; fi       # *"/."*
      fi

      if [[ "$skiplink" == "0" ]]; then
        # Add link to list if it's valid and not already on the list
        if [[ $(cat $linkfile |cut -d',' -f2 |grep "^${directlink}$") ]]; then
          log 3 "Debug: Skipping link $directlink, already on the list."
        else
          echo "$depth,$directlink" >> $linkfile
          log 3 "Debug: Adding link $directlink" #>> $linkfile
          ((newlinksfound++))
        fi
      fi
    fi
  done 4<<< "$linkscan"
  if [[ ! $newlinksfound == "0" ]]; then
    log 2 "Notice: New links found: $newlinksfound"
  fi
}

function geturl {
  # Gets specified URL ($link) from Internet Archive.
  #
  # Set archive URL here
  archurl="https://web.archive.org/web/${datestring}id_/http://$link"
  #archurl="https://web.archive.org/web/${datestring}id_/http://$link"
  log 3 "Debug: Trying $archurl"
  # Get status code for next page to be archived.
  archstatus="$(curl -sI $archurl |head -n1 |cut -b8-10)"
  # 404 File not found
  if [[ $archstatus == "404" ]]; then 
    log 1 "$link 404 - Not found."; 
  fi
  # 200 Page found and archived
  if [[ $archstatus == "200" ]]; then
    log 3 "200 - Page found!"
    wget --quiet --max-redirect=0 -e robots=off -nH -nc -P $tempdir/web $archurl 2>&1 |tee -a $logfile
  fi
  # 302 Page redirect
  if [[ $archstatus == "302" ]]; then
    archfounddate=$(curl -sI $archurl |grep "x-archive-redirect-reason: found" |rev |cut -d' ' -f1 |rev)
    archfounddate=${archfounddate:0:14}
    log 3 "$link 302 - Resource found on a different date ($archfounddate)"
    if [[ "$link" == *.html || "$link" == *.htm || "$link" == *.asp || "$link" == *.shtml || "$link" == *.php || "$link" == *.cgi ]]; then
      # File is likely an HTML document. Only download if it is at or near target date.
      # Get location field
      if [[ "${archfounddate:0:8}" == "${datestring:0:8}" ]]; then altfound=1      # Alt found same day
      elif [[ "${archfounddate:0:6}" == "${datestring:0:6}" ]]; then altfound=1    # Alt found same month
      elif [[ "${archfounddate:0:4}" == "${datestring:0:4}" ]]; then altfound=1    # Alt found same year
      elif [[ "${archfounddate:0:4}" == "$(expr ${datestring:0:4} - 1)" ]]; then altfound=1    # Alt found year - 1
      elif [[ "${archfounddate:0:4}" == "$(expr ${datestring:0:4} - 2)" ]]; then altfound=1    # Alt found year - 2
      elif [[ "${archfounddate:0:4}" == "$(expr ${datestring:0:4} - 3)" ]]; then altfound=1    # Alt found year - 3
      elif [[ "${archfounddate:0:4}" == "$(expr ${datestring:0:4} - 4)" ]]; then altfound=1    # Alt found year - 4
      elif [[ "${archfounddate:0:4}" == "$(expr ${datestring:0:4} + 1)" ]]; then altfound=1    # Alt found year + 1
      elif [[ "${archfounddate:0:4}" == "$(expr ${datestring:0:4} + 2)" ]]; then altfound=1    # Alt found year + 2
      elif [[ "${archfounddate:0:4}" == "$(expr ${datestring:0:4} + 3)" ]]; then altfound=1    # Alt found year + 3
    fi
    else
      # The file is not an HTML file, so we can go ahead and download the alternative,
      # since this file won't be parsed for more links.
      altfound=1
    fi
    if [[ "$altfound" == "1" ]]; then
      log 2 "$link 302 - Alternative copy was found that is within target search range (timecode: $archfounddate)"
      wget --quiet --max-redirect=2 -e robots=off -nH -nc -P $tempdir/web $archurl 2>&1 |tee -a $logfile
    else
      log 1 "$link 302 - No resource found near target date. ($archfounddate)"
    fi
  fi
  # Check to see if wget created the directory ./sites/$host/web
  if [ -d "$tempdir/web" ]; then
    # if /web -directory found, assume the file is there, find the file and 
    # save full path to file in the variable $outputfile
    downloadedfile=`find $tempdir/web -type f`
    filename="$(echo -n "$downloadedfile" | rev | cut -d'/' -f1 | rev)"
    #filename="$(echo -n "$path" | cut -d'/' -f-1)"
  else
    # Otherwise clear $downloadedfile
    downloadedfile=
  fi

  # If a file was downloaded
  if [ -f "$downloadedfile" ]; then
    # Create path for downloaded file
    mkdir -p ./sites/$host/$path 2>&1 |tee -a $logfile
    # Move downloaded file to destination
    mv $downloadedfile ./sites/$host/$path 2>&1 |tee -a $logfile # move wget'ed file out of ./web
    rm -r $tempdir/web 2>&1 |tee -a $logfile                     # remove ./web
    log 1 "$host/$path$filename OK!"

    # cooldown timer
    printf "\b\b\b   \b\b"
    for (( c=1; c<=$cooldown; c++ )); do
      printf "\b/"; sleep .25
      printf "\b-"; sleep .25
      printf "\b\\"; sleep .25
      printf "\b|"; sleep .25
    done
    printf "\bOK! "

  fi
}

# Intro screen
echo
echo "Warnick web-site mirroring tool for Internet Archive version $version"
echo "=================================================================="
echo
echo "Developed by Oliver Molini for Protoweb.org 2011-2022"
echo "Inspired by warrick.pl by Frank McCown at Old Dominion University"

if [[ -z "$1" ]]; then
  # No parameters specified, show usage
  echo
  echo "Usage:"
  echo "  $ $0 <URL> [datestring] [maxdepth] [owner]"
  echo
  echo "  $ $0 www.domain.com"
  echo "  $ $0 www.domain.com 1997"
  echo "  $ $0 www.domain.com 19970401"
  echo "  $ $0 www.domain.com 19970401 8"
  echo
  echo "  A proper invocation of this script will mirror the given URL from"
  echo "  archive.org, and store the site files under the subdirectory"
  echo "  ./sites/www.domain.com"
  echo
  echo "  *** Important! ***"
  echo "  Most (if not all) users will never use the owner parameter. This feature"
  echo "  is reserved for use in a multi-user environment, such as on the Protoweb"
  echo "  development server. If you are unsure, do not use it."
  echo
  exit 0
fi

if [ -z "$2" ]; then
  log 0 "Notice: No date specified. Using default \"$defaultdate\""
  datestring=$defaultdate
else
  datestring=$2
fi

if [ -z "$3" ]; then
  log 0 "Notice: No max traversal depth specified. Using default \"$defaultmaxdepth\""
  export maxdepth=$defaultmaxdepth
else
  export maxdepth=$3
fi
if [[ -z "$4" ]]; then
  log 2 "Debug: No owner specified. Using default \"$defaultowner\""
  owner=$defaultowner
else
  owner=$4
fi

# Set up temporary directory
wid="$(date +%Y%m%d%H%M%S)$(date +%N |cut -b1-4)"
if [ "$owner" != "$defaultowner" ]; then
  # This part gets executed when the owner is specified,
  # as expected when web integration and multiuser mode are enabled.
  tempdir="./temp/pending/warnick-$wid"
else
  tempdir="/run/user/$UID/warnick-$wid"
fi
logfile="$tempdir/recovery.log"
linkfile="$tempdir/links.txt"
mkdir -p $tempdir
chown :www-data $tempdir
chmod 770 $tempdir

if [[ ! -z "$logfile" ]]; then
  echo "Warnick web-site mirroring tool for archive.org version $version" >$logfile
  echo "=============================================================" >> $logfile
  echo "Developed by Oliver Molini for Protoweb.org 2011-2022" >> $logfile
  echo "Inspired by warrick.pl by Frank McCown at Old Dominion University" >> $logfile
fi

log 1 "========================================================"
log 1 "Mirroring contents at:   $host/$startpath"
log 1 "Target Date:             $datestring"
log 1 "Max Traversal Depth:     $maxdepth"
log 2 "Temp directory set to:   $tempdir"
log 2 "Log file is set to:      $logfile"
if [[ "$owner" != "$defaultowner" ]]; then
  log 1 "Job owner:               $owner"
fi
log 1 "Operation started at:    $(date +"%Y/%m/%d %H:%M:%S %Z")"
log 1 "========================================================"

# Set starting depth
depth=1

# Set starting link number, incremented at start of each operation
linkno=0

# Set starting link total number
linktotal=1

# Create ./sites directory, if it does not already exist
mkdir ./sites

# Add first link to link list
touch $linkfile
echo "$depth,$host/$startpath" >> $linkfile

while IFS="" read -r line || [ -n "$line" ]; do
  # Main loop - start with $startpath, then discover links as we go
  ((linkno++))
  # Stop processing, if "cancel-job" file is found in $tempdir
  if [ -f "$tempdir/cancel-job" ]; then
    log 1 "Notice: Received signal to cancel job."
    break
  fi
  depth="$(echo $line |cut -d',' -f1)"                                     # 1
  link="$(echo $line |cut -d',' -f2)"                                      # www.domain.com/path/to/file.html
  # Parse given URL to components
  # take last component of URL and get filename if exists
  filename=$(echo "$link" |rev |cut -s -d'/' -f1 |cut -s -d'.' -f1- |rev)  # file.html
  if [[ -z $filename ]]; then
    path=$(echo "$link" |cut -s -d'/' -f2-)                                # path/to
  else
    path=$(echo "$link" |rev |cut -s -d'/' -f2- |rev |cut -s -d'/' -f2-)   # path/to
  fi
  if [[ ! -z "$path" ]] && [[ ! ${path: -1} == "/" ]]; then
    # Add a leading '/' if there is a path to be considered,
    # and only add it if there is no leading '/' yet.
    path=${path}/                                                          # path/to/
  fi

  log 3 "Debug: Link:     $link"
  log 3 "Debug: Host:     $host"
  log 3 "Debug: Domain:   $domain"
  log 3 "Debug: Path:     $path"
  log 3 "Debug: Filename: $filename"

  geturl "$link"

  # Scan links on the file, if we are not beyond maxdepth
  if [[ "$depth" -lt "$maxdepth" ]]; then
    # Scan links on only specific filetypes
    if [[ "$filename" == *.html || "$filename" == *.htm || "$filename" == *.asp || "$filename" == *.shtml || "$filename" == *.php || "$filename" == *.cgi ]]; then
      # Scan links only if file is larger than 64 bytes. Anything less and it's probably a dummy file.
      if [[ ! -z $(find ./sites/$host/$path$filename -type f -size +64c) ]]; then
        scanlinks ./sites/$host/$path$filename
      fi
    fi
  fi
  linktotal=$(cat $linkfile |wc -l)
done < $linkfile

# Job finished.
log 1 "Operation finished at: $(date +"%Y/%m/%d %H:%M:%S %Z")"
echo
cp $logfile ./sites/$host/recovery.log
cp $linkfile ./sites/$host/links.log

# Was the job canceled in a multi-user environment? 
# Signal that cancelation was successful.
if [[ -f "$tempdir/cancel-job" ]] && [[ "$owner" != "$defaultowner" ]]; then
  log 1 "Job was canceled prematurely."
  touch $tempdir/cancel-job-success
  exit
fi

# Multi-user environment operations
if [[ "$owner" != "$defaultowner" ]]; then
  cp -r $tempdir ./temp/complete #  2>&1 |tee -a $logfile
  # Change permissions of all downloaded files to be readable and writable by the web server.
  chown -R :www-data ./temp/complete/warnick-$wid/ 2>&1 |tee -a $logfile
  chmod -R 770 ./temp/complete/warnick-$wid/ 2>&1 |tee -a $logfile
  if [[ ! -z "$host" ]]; then
    # Copy and then remove duplicate directory
    cp -r ./sites/$host ./remote/sites-www #  2>&1 |tee -a $logfile
    rm -r ./sites/$host
  fi
fi

# Cleanup
if [[ ! -z "$tempdir" ]]; then 
  if [[ -f "$tempdir/cancel-job" ]]; then rm $tempdir/cancel-job; fi
  if [[ -f "$tempdir/cancel-job-success" ]]; then rm $tempdir/cancel-job-success; fi
  if [[ ! -z "$logfile" ]]; then rm $logfile; fi
  if [[ ! -z "$linkfile" ]]; then rm $linkfile; fi
  rmdir "$tempdir"
fi