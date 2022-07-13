#!/bin/bash
#
# Limit how many links to scan (to avoid hanging on really big html files)
maxlinks=1500

newline=$'\n'

if [ ! "$4" = "" ]; then pl=$4; fi
if [ ! "$5" = "" ]; then tempdir=$5; fi
if [ ! "$6" = "" ]; then logfile=$6; fi
if [ ! "$7" = "" ]; then startpath=$7; fi

# Only set maxdepth if it is not found as a exported var
if [[ -z $maxdepth ]]; then maxdepth=1; fi

if [ "$1" == "" ]; then
  echo =============================================================
  echo Open HTML file and parse direct and relative links.
  echo Usage
  echo $0 www.domain.com/file.html 199612 [--verbose]
  echo
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

  if [[ -z $tempdir ]]; then
    tempdir="./temp"
  fi
  tempfile="$tempdir/${host}_links.tmp"

  # Scan links on only specific filetypes, when process level ($pl) is less than maxdepth
  if [[ "$1" == *.html || "$1" == *.htm || "$1" == *.asp || "$1" == *.shtml ]]; then
    if [ -f "./sites/$1" ]; then
      if [ "$3" == "--verbose" ]; then echo; echo $0: Parameters: $1 $2 $3; fi
      if [ "$3" == "--verbose" ]; then echo $0: Parsing links from HTML...; fi

      # ---------------------- PARSE LINKS ------------------------
      searchbuffer=512
      fn="./sites/$1"
      linklist=$(grep -obi $fn -e "<a\|<img\|<body\|<script\|<frame") # add tags to detect
      if [[ -z $linklist ]]; then
        # No links in file. Exit.
        exit 0;
      fi

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
          # step 1 - parse tag
          link="$(echo -n $tag |cut -b$linkoffset- |cut -d'=' -f2 |cut -d'>' -f1 |cut -d'?' -f1)" # "./case32.html" name
          # step 2 - remove spaces and quotes and anything else that we missed
          link="$(echo -n $link |tr -d '\"' |cut -d' ' -f1)"           # ./case32.html
          # step 3 - remove ./ from beginning of link
          link="$(echo -n $link |sed 's/^\.\///')"

          # Add link to list...
          echo $link >> $tempfile
        fi
      done 4<<< "$linklist"
      # -----------------------------------------------------------


      # Convert direct and full URLs pointing to self into non-relative URL's
      # and remove repetitive links (uniq) and filter out (grep -v) links which
      # contain the specified strings:

      if [ "$3" == "--verbose" ]; then echo $0: Parse complete.; fi
      if [ "$3" == "--verbose" ]; then echo $0: "Sorting links, special mailto: links, etc."; fi
      #
      # Convert links into a very standard format:
      # - sort links
      # - remove domain part of the link
      # - remove any links that point to other domains.
      a=`sort $tempfile |uniq |sed -e "s/http:\/\/www.$hostdomain//ig;s/http:\/\/$hostdomain//ig;s/www.$hostdomain//ig;s/$hostdomain//ig" |grep -vE 'http:|mailto:|ftp:|telnet:|https:|javascript:|#'`


      if [ "$3" == "--verbose" ]; then
        echo "======================================================"
        echo "$0: Found the following links:"
      fi

      # Limit how many links to scan (to avoid hanging on really big html files)
      a=$(printf "$a" |head -n $maxlinks)


      for line in $a; do
        linkcount=$(expr $linkcount + 1)

#        #printf .$linkcount
#        #printf .

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
          if [ "$debug" == "2" ]; then
            echo "COMPARE SHOULDBE:  $sdshouldbe"
            echo "COMPARE CURRENTLY: $sdcurrently"
          fi
          if [[ "${sdshouldbe,,}" == "${sdcurrently,,}" ]]; then
            if [ "$debug" == "2" ]; then echo "Including in-bounds file: $fullpath"; fi
            ignorefile=""
          else
            # File is out of bounds, but is it an image file?
            fileext=$(echo $line |rev |cut -d. -f1 -s |rev)
            if [[ "${fileext^^}" == "GIF" ]] || [[ "${fileext^^}" == "JPEG" ]] || [[ "${fileext^^}" == "JPG" ]]; then
              if [ "$debug" == "2" ]; then echo "Including out of bounds file: $fullpath because it is an image."; fi
              ignorefile=""
            else
              if [ "$debug" == "2" ]; then echo "Ignoring out of bounds file: $fullpath"; fi
              ignorefile="1"
              linktype="IGNORED "
            fi
          fi
        fi

        # The link parser is not perfect, so check here to see if link is
        # valid with no special characters floating around to prevent downloading
        # invalid files.
        # MATCH: = & + % ; | : " @
        if [[ "$fullpath" =~ [=\&+%\;|:\"@\<\>] ]]; then
          ignorefile="1"
          linktype="INVALID "
        fi

        if [ "$3" == "--verbose" ]; then echo "$0: --- $linktype $fullpath"; fi

        if [[ "$ignorefile" == "1" ]]; then
          # File is ignored because it is out of bounds, do not download
          if [[ $debug == 0 ]]; then printf " "; fi
        else
          # Please download
          if [[ $debug == 0 ]]; then printf "."; fi
          cmdadd="$fullpath $2 null null $pl $tempdir $logfile $startpath${newline}"
        fi
        # Add determined command to command list
        cmdlist+="$cmdadd"

        if [ "$debug" == "2" ]; then echo "------------------------------"; fi
      done

      if [ "$3" == "--verbose" ]; then
        echo
        echo Is this correct? press enter or ^C.
        read
      fi

      # delete temporary link list
      rm "$tempfile"

      while IFS=$newline read -u 3 -r "line"; do
        if [[ ! -z $line ]]; then ./get.sh $line; fi
      done 3<<< "$cmdlist"
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
