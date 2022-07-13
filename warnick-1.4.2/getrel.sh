#!/bin/bash
#

debug=0

# Limit how many links to scan (to avoid hanging on really big html files)
maxlinks=1500

if [ ! "$4" = "" ]; then pl=$4; fi
if [ ! "$5" = "" ]; then tempdir=$5; fi
if [ ! "$6" = "" ]; then logfile=$6; fi
if [ ! "$7" = "" ]; then startpath=$7; fi

# Only set maxdepth if it is not found as a exported var
if [[ -z $maxdepth ]]; then maxdepth=1; fi   

if [ "$1" == "" ]; then
  echo =============================================================
  echo Get related links.
  echo Usage
  echo $0 www.domain.com/file.html www.domain.com 199612 [--verbose]
  echo
  echo To quickly test on existing html-file:
  echo $0 www.3drealms.com/index.html 199612 --verbose
  echo =============================================================
  echo
else
  if [[ ! "$pl" -lt "$maxdepth" ]]; then
    exit 0
  fi

  host=`echo $1 |cut -d/ -f1`                      #www.anttila.fi
  hostdomain=`echo $host |sed -e "s/www*.\.//g"`   #    anttila.fi

  path=`echo "${1%/}" |cut -s -d/ -f2-`
  path=/`dirname $path`
  if [[ $path == "/." ]]; then
    path=""
  fi
#  echo hello $path

  if [[ -z $tempdir ]]; then
    tempdir="./temp"
  fi
  #tempfile="./sites/$host/links-`date |md5sum |cut -b 1-10`.tmp"
  #tempfile="/run/user/1001/links-`date +%N |md5sum |cut -b 1-10`.tmp"
  tempfile="$tempdir/links.tmp"


  # Create site directory if missing
  #if [ ! -d "./sites/$host" ]; then
  #  mkdir -p ./sites/$host
  #fi

  # Scan links on only specific filetypes, when process level ($pl) is less than maxdepth
  if [[ "$1" == *.html || "$1" == *.htm || "$1" == *.asp || "$1" == *.shtml ]]; then 
    # && [[ "$pl" -lt "$maxdepth" ]]; then
    if [ -f "./sites/$1" ]; then
      if [ "$3" == "--verbose" ]; then echo $0: Parameters: $1 $2 $3; fi
      if [ "$3" == "--verbose" ]; then echo $0: Parsing links from HTML...; fi

      # Warning: this matches <script [src=""]> too.

      # <img [src="/path/to_file.jpg"]>
      perl -0ne 'print "$1\n" while (/ src=\"(.*?)\"/igs)' ./sites/$1 > $tempfile

      # <img [src=/path/to_file.jpg>]
      perl -0ne 'print "$1\n" while (/ src=([^"].*?)[\s]?>/igs)' ./sites/$1 >> $tempfile

      # <body [background="/path/to_file.jpg"]>
      perl -0ne 'print "$1\n" while (/background=\"(.*?)\"/igs)' ./sites/$1 >> $tempfile

      # <a[ href="/path/to_file.jpg"]>
      perl -0ne 'print "$1\n" while (/ href=\"(.*?)\"/igs)' ./sites/$1 >> $tempfile
      # [<a href=/path/to_file.jpg>]
      perl -0ne 'print "$1\n" while (/<a href=([^"].*?)[\s]?>/igs)' ./sites/$1 >> $tempfile

      #   old method would include [&lt;a href=&quot;http://...] which we don't want:
      # # <a [href="/path/to_file.jpg"]>
      # perl -0ne 'print "$1\n" while (/href=\"(.*?)\"/igs)' ./sites/$1 >> $tempfile
      # # <a [href=/path/to_file.jpg>]
      # perl -0ne 'print "$1\n" while (/href=([^"].*?)[\s]?>/igs)' ./sites/$1 >> $tempfile

      # Convert direct and full URLs pointing to self into non-relative URL's
      # and remove repetitive links (uniq) and filter out (grep -v) links which
      # contain the specified strings:

      if [ "$3" == "--verbose" ]; then echo $0: Parse complete.; fi
      if [ "$3" == "--verbose" ]; then echo $0: "Sorting and removing repeated URLs, special mailto: links, etc."; fi
      #
      #a=`cat $tempfile |sed -e "s/http:\/\/www.$hostdomain//ig;s/http:\/\/$hostdomain//ig;s/www.$hostdomain//ig;s/$hostdomain//ig" |uniq |grep -vE 'http:|mailto:|ftp:|telnet:|https:|javascript:|#'`
      # Changed from cat to sort |uniq, to better detect repeated URL's.
      a=`sort $tempfile |uniq |sed -e "s/http:\/\/www.$hostdomain//ig;s/http:\/\/$hostdomain//ig;s/www.$hostdomain//ig;s/$hostdomain//ig" |grep -vE 'http:|mailto:|ftp:|telnet:|https:|javascript:|#'`

      rm "$tempfile"
      if [ "$3" == "--verbose" ]; then
        echo "======================================================"
        echo "$0: Found the following links:"
      fi

      # Limit how many links to scan (to avoid hanging on really big html files)
      a=$(printf "$a" |head -n $maxlinks)

      for line in $a; do
        linkcount=$(expr $linkcount + 1)

        #printf .$linkcount
        #printf .
        # determine if line starts with ./ and remove if so
        if [ "`echo $line |cut -b -2`" == "./" ]; then
          line=$(echo $line |cut -b 3-)
        fi

        # decode relative path and determine actual path
        if [ "`echo $line |cut -b 1`" == "/" ]; then
          #not relative path
          fullpath="$host$line"
          linktype="NOT REL "
        else
          #relative path
          fullpath="$host$path/$line"
          linktype="RELATIVE"
        fi

        # Check if sub directory limitation is on, and we're in a subdir
        if [[ $subdirsonly == "1" ]] && [[ ! -z "$startpath" ]]; then
          sdshouldbe=$(echo "$host/$startpath/")
          # get length of string
          lenstartpath=$(expr length "$host/$startpath/")
          sdcurrently=$(echo $fullpath/ | cut -b-$lenstartpath)
          if [ "$debug" == "1" ]; then
            echo "COMPARE SHOULDBE:  $sdshouldbe"
            echo "COMPARE CURRENTLY: $sdcurrently"
          fi
          if [[ "$sdshouldbe" == "$sdcurrently" ]]; then
            if [ "$debug" == "1" ]; then echo "Including in-bounds file: $fullpath"; fi
            ignorefile=""
          else
            # File is out of bounds, but is it an image file?
            fileext=$(echo $line |rev |cut -d. -f1 -s |rev)
            if [[ "${fileext^^}" == "GIF" ]] || [[ "${fileext^^}" == "JPEG" ]] || [[ "${fileext^^}" == "JPG" ]]; then
              if [ "$debug" == "1" ]; then echo "Including out of bounds file: $fullpath because it is an image."; fi
              ignorefile=""
            else
              if [ "$debug" == "1" ]; then echo "Ignoring out of bounds file: $fullpath"; fi
              ignorefile="1"
              linktype="IGNORED "
            fi
          fi
        fi

        if [ "$3" == "--verbose" ]; then echo "$0: --- $linktype $fullpath"; fi

        if [[ "$ignorefile" == "1" ]]; then
          # File is ignored because it is out of bounds, do not download
          printf " "
        else
          # Please download
          printf "."
          cmdadd=$(echo "./get.sh $fullpath $2 null null $pl $tempdir $logfile $startpath")
        fi

        # Add determined command to command list
        cmdlist=$(printf "$cmdlist$cmdadd\n ")

        if [ "$debug" == "1" ]; then echo "------------------------------"; fi
      done
      if [ "$3" == "--verbose" ]; then 
        echo
        echo Is this correct? press enter or ^C.
        read
      fi

      echo -n "$cmdlist" | while read line
      do
        $line
      done

    else
      if [ "$3" == "--verbose" ]; then
        printf "`date +"%d.%m.%Y %T"` GETREL: File not found error. Tried looking for ./sites/$1\n" 2>&1 |tee -a ./sites/recovery.log
      else
        printf "`date +"%d.%m.%Y %T"` GETREL: File not found error. Tried looking for ./sites/$1\n" >> ./sites/recovery.log
      fi
    fi
  else
    if [ "$3" == "--verbose" ]; then
      printf "`date +"%d.%m.%Y %T"` GETREL: Not a .htm or .html file.\n" 2>&1 |tee -a ./sites/recovery.log
    else
      printf "`date +"%d.%m.%Y %T"` GETREL: Not a .htm or .html file.\n" >> ./sites/recovery.log
    fi
  fi
fi
