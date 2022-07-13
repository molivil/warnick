#!/bin/bash
#

searchbuffer=512
fn="index.html"
linkfile="linklist.tmp"

# echo -e "This is a string, and this is a string!" |tr '\n' ' ' | sed -e "s/this\(.*\)string/\1/i"

linklist=$(grep -obi $fn -e "<a\|<img\|<body\|<script")          # add tags to detect

echo Parsing links...

while IFS= read -r line; do
  byteoffset=$(echo $line |cut -d ':' -f1)
  bytestart=$(expr $byteoffset \+ 1)
  byteend=$(expr $byteoffset \+ $searchbuffer)

#  tag="$(cat $fn | cut -b$bytestart-$byteend |tr '\n' ' ' |cut -d'>' -f1)>"
  tag="$(cut -zb$bytestart-$byteend $fn |tr -d '\0' |tr '\n' ' ' |cut -d'>' -f1)>"        # <A HReF = "/case32.html?hello&world" name="test">
  linkoffset="$(echo -n "$tag" |grep -obi "href\|src\|background" |cut -d':' -f1)"        # add tag parameters here, eg. href, src...
  link="$(echo -n $tag |cut -b$linkoffset- |cut -d'=' -f2 |cut -d'>' -f1 |cut -d'?' -f1)" # "/case32.html" name
  # remove spaces and quotes
  link="$(echo -n $link |tr -d '\"' |cut -d' ' -f1)"           # /case32.html

  echo -n .

  # Add link to list...
  if [ -f "$linkfile" ]; then
    if [[ -z $(cat "$linkfile" |grep $link) ]]; then 
      echo $link >> $linkfile
    fi
  else
    echo $link > $linkfile
  fi

  tag=$(echo $line |cut -d ':' -f2)
#  echo $tag: $byteoffset
done <<< "$linklist"
