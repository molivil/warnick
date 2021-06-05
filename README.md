# WARNICK v1.5.0
Web-site mirroring tool for archive.org

Developed by Oliver Molini for ProtoWeb.org
Some portions based on warrick.pl by Frank McCown at Old Dominion University

Copyright (CC BY-NC-SA 4.0) Oliver Molini
For further licensing information, please visit.
https://creativecommons.org/licenses/by-nc-sa/4.0/

## Installation
### Script prerequisites
- bash, tee, cut, grep, cat, md5sum, date
- wget, curl
- perl
- RuntimeDirectorySize directive in /etc/systemd/logind.conf set to 50% or more

### Mirror from Github
- Have get.sh and getrel.sh mirrored into an empty directory.
- Make a writable subdirectory called "sites".
 
### Change in runtime requirements
You must edit /etc/systemd/logind.conf and change "RuntimeDirectorySize" directive to.
50% or more. By default, 10% of physical memory is used by the runtime temporary directory.
This may or may not be enough for Warnick to create its temporary log files.
A larger size may be needed for Warnick to run properly.

You may use the software any way you would like, just know you do it at your own risk. 
The developer and the project team members may not be held liable for any damages direct or indirect resulting from the use of this software.

## Usage
```
$ get.sh <URL> [datestring] [owner] [maxdepth]
```
### Examples
```
$ get.sh www.domain.com
$ get.sh www.domain.com 1997 nobody 5
$ get.sh www.domain.com/path/ 199704 nobody 5
$ get.sh www.domain.com/path/file.html 19970411
```
The first command in the list above will mirror an entire site from archive.org (https://web.archive.org/web/1997/http://www.domain.com/), whereas the last one will mirror a specific file and use the datestring to target files that are close to the given date (19970411). The web site  will be stored under the subdirectory ./sites/www.domain.com"

## Parameters explained
### &lt;URL&gt;
Mirror a Wayback Machine URL specified with this parameter.
The "http://" -prefix is not required.

### [Datestring]
Target a specific date. The targeted date will be used when discovering files from archive.org. Datestring must be given in YYYYMMDD or YYYYMM or YYYY format. You may omit the day or month and day.

### [Owner]
This sets the job owner for the script. Use "nobody" here at all times, unless the script is used as part of a web integration in a multiuser environment.

### [Maxdepth]
Override the default maxdepth value specified with the $defaultmaxdepth environment variable. 

This sets the default maximum depth hardlimit, and will exit the subprocess once the limit has been reached. If the site is large, do not use much more than 5 or 6 here, to prevent the script from entering seemingly neverending infinite loops. In many cases a page that is 5 links deep can be reached from a page that is at a shallower depth, unless the web site happens to be a portal, so it should be relatively safe to use a lower value here, such as 4 or 5.

## Important!
If you specify a maxdepth, you must also specify an owner. Owner must always be "nobody", or $defaultowner, unless used in a web integration with ProtoWeb.

# Changelog
## 1.5.0 (2021-06-04)
### Changes
- Rewrote the link parser script so Warnick can more readily parse non-standard HTML tags such as &lt;A Href &nbsp;= &nbsp;link.html &nbsp;&gt;
### Known bugs
- Some links may be rarely left out due to their references being non-case sensitive. See v1.4.2 for more details.

## 1.4.4 (2021-05-29)
### Changes
- Added watchdog code to prevent infinite loops. Fixes the infinite loop problem.
### Known bugs
- Some links do not parse properly when a page uses non-standard HTML tags.
- Some links may be rarely left out due to their references being non-case sensitive. See v1.4.2 for more details.

## 1.4.3 (2021-04-30)
### Changes
- Improved code efficiency.
- Improved the way Warnick detects odd filenames, so that it won't get hung up when there are non-standard HTML tags, and try downloading something like ALIGN=MIDDLE. With some changes the parser script now makes a better attempt at detecting and ignoring links that clearly are not real files.
### Known bugs
- Same as 1.4.2

## 1.4.2
### Changes
- Improved console usage. When run from console, the user may be tempted to add the "http://" prefix, which is not supported. The script will automatically detect this prefix  and remove it if necessary. 
- Added a notice when program is started.
- Added version number in it's own variable.
### Known bugs
- Occasionally Warnick tends to get stuck in an infinite loop with a website. If you run into this bug, as a workaround, you can either use it on subdirectories of the site, until the culprit is found, or use a smaller maxdepth value. 
- Some links do not parse properly when a page uses non-standard HTML tags.
- Some links may be rarely left out due to their references being non-case sensitive. This most commonly happens when original websites were Windows-based, and less commonly with websites with lax redirection rules. An example is when downloading www.geocities.com/Area51/1000/, where the website refers to /area51/main.html, and the actual directory where the file resides, is /Area51/main.html. The script would make a case-sensitive comparison to see if the directory is the same or not, and rule out /area51/main.html, because it sees it as a different directory. From the point of view of Geocities.com, the directories Area51 and area51 are one and the same (aliased). 
