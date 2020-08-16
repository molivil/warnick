# WARNICK v1.2.1
Web-site mirroring tool for archive.org

Developed by Oliver Molini for Protonet
Influenced by warrick.pl written by Frank McCown at Old Dominion University

Copyright (CC BY-NC-SA 4.0) Oliver Molini
For further licensing information, please visit.
https://creativecommons.org/licenses/by-nc-sa/4.0/

## Installation
- Copy get.sh and getrel.sh into a directory.
- Make a writable subdirectory called "sites".

## Script prerequisites
- bash, tee, cut, grep, cat, md5sum, date
- wget
- perl
- RuntimeDirectorySize directive in /etc/systemd/logind.conf set to 50% or more
 
## Change in runtime requirements
You must edit /etc/systemd/logind.conf and change "RuntimeDirectorySize" directive to.
50% or more. By default, 10% of physical memory is used by the runtime temporary directory.
This may or may not be enough for Warnick to create its temporary log files.
A larger size may be needed for Warnick to run properly.

You may use the software any way you would like, just know you do it at your own risk. 
The developer and the project team members may not be held liable for any damages direct or indirect resulting from the use of this software.

## Usage
```
$ get.sh <url> [datestring]
$ get.sh www.domain.com
$ get.sh www.domain.com/path_to/file.html 199704
```

This will start mirroring content from archive.org under the given path and date.
Date must be given in YYYYMM format.
