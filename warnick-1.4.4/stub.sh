#!/bin/bash
#
# Create stub for Contributor Control Panel to enable page edits.
#
if [ "$1" = "" ] || [ "$2" = "" ]; then
  printf "\nUsage:\n\n"
  printf "  $ $0 <domain.com> [owner]\n"
  #printf "  $ $0 www.domain.com/ 19970411 nobody\n"
  printf "  $ $0 www.domain.com nobody\n"
  exit 0
fi

fdir="./temp/published/warnick-$(date +%N |md5sum |cut -b 1-10)"
frec="$fdir/recovery.log"

mkdir -p "$fdir"
touch "$frec"
echo "$(date +"%Y/%m/%d %H:%M:%S"): Recovery stub from: $1" >> $frec
echo "$(date +"%Y/%m/%d %H:%M:%S"): Target Date: 00000000" >> $frec
echo "$(date +"%Y/%m/%d %H:%M:%S"): Max Traversal Depth: N/A" >> $frec
echo "$(date +"%Y/%m/%d %H:%M:%S"): Log file is: ./temp/published/warnick-$1/recovery.log" >> $frec
echo "$(date +"%Y/%m/%d %H:%M:%S"): Job owner: $2" >> $frec
echo "$(date +"%Y/%m/%d %H:%M:%S"): Operation started at: $(date +"%Y/%m/%d %H:%M:%S %Z")" >> $frec
echo "$(date +"%Y/%m/%d %H:%M:%S"): ========================================================" >> $frec
chmod -R 774 "$fdir"
chown -R www-data:www-data "$fdir"