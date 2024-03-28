# WARNICK v2.1.4
WARNICK Website recovery tool for the Internet Archive (archive.org)

Developed by Oliver Molini for Protoweb.org 2011-2022

Inspired by warrick.pl by Frank McCown at Old Dominion University 2005-2010

This program will mirror a specified website domain from the Internet Archive's
Wayback Machine using a specified target date. It can be used to recover entire websites, 
or mirror websites so they can be worked on locally.

Copyright (CC BY-NC-SA 4.0) Oliver Molini
For further licensing information, please visit.
https://creativecommons.org/licenses/by-nc-sa/4.0/

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

## Installation
### SCRIPT PREREQUISITE PROGRAMS:
- Debian GNU/Linux, Ubuntu, Raspbian or similar.
- bash 5.0.3 or newer
- tee, cut, grep, cat, date
- wget 1.20.1 or newer
- curl 7.64.0 or newer

### OTHER PREREQUISITES:
- In Debian GNU/Linux, RuntimeDirectorySize directive in /etc/systemd/logind.conf set to 50% or more
- If you have a different Linux distribution, or you don't have this file, check with your local distribution's manual how to increase the runtime directory size (/var/run).

### Mirror from Github
- Copy warnick.sh from Github to an empty directory.
- Make a subdirectory called "sites" (mkdir sites)
- Make both directories writable and script executable (chmod 770 -R ./)
 
### Change in runtime requirements
You must edit /etc/systemd/logind.conf and change "RuntimeDirectorySize" directive to.
50% or more. By default, 10% of physical memory is used by the runtime temporary directory.
This may or may not be enough for Warnick to create its temporary log files.
A larger size may be needed for Warnick to run properly.

You may use the software any way you would like, just know you do it at your own risk. 

The developer and the project team members may not be held liable for any damages direct or indirect resulting from the use of this software.

## Usage
```
$ ./warnick.sh <URL> [datestring] [maxdepth] [owner]
```
### Examples
```
$ ./warnick.sh www.domain.com
$ ./warnick.sh www.domain.com 1997
$ ./warnick.sh www.domain.com 19970401
$ ./warnick.sh www.domain.com 19970401 8
```
The first command in the list above will mirror an entire site from archive.org (https://web.archive.org/web/1997/http://www.domain.com/), whereas the last one will mirror a specific file and use the datestring to target files that are close to the given date (19970411). The web site will be stored under the subdirectory ./sites/www.domain.com".  It will use the maximum link traversal depth of 10 (or whatever you specify, usually 10 is recommended). 

## Parameters explained
### &lt;URL&gt;
Mirror a Wayback Machine URL specified with this parameter.
The "http://" -prefix is not required.

### [Datestring]
Target a specific date. The targeted date will be used when discovering files from archive.org. Datestring must be given in YYYYMMDD or YYYYMM or YYYY format. You may omit the day or month and day.

### [Maxdepth]
Override the default maxdepth value specified with the $defaultmaxdepth environment variable. 

This sets the default maximum depth hardlimit, and will exit the subprocess once the limit has been reached. If the site is large, do not use much more than 5 or 6 here, to prevent the script from entering seemingly neverending infinite loops. In many cases a page that is 5 links deep can be reached from a page that is at a shallower depth, unless the web site happens to be a portal, so it should be relatively safe to use a lower value here, such as 4 or 5.

### [Owner]
This sets the job owner for the script. Never use this parameter, unless the script is used as part of a web integration in a multiuser environment. Using this parameter modifies the behavior of the script, and may create files in unexpected places. So please, do not use this parameter. :)

## Other notes
Previously (version 1.5.1 and older) you were able to mirror specific subdirectories in IA as well. This feature has been discontinued on the newer 2.x.x version for now. I plan to add it to the 2.x.x branch at some point, but right now, if you need to mirror just a subdirectory, download Warnick 1.5.2, and run it with the following example arguments:
$ ./get.sh www.domain.com/path/file.html 19970411 

# Changelog
## 2.1.4 (2022-11-15)
### Changes
- Combined "skipping link to other host" log entries into a single-line log entry to reduce log spamming.
### Bug fixes
- Removed 2.1.2, it was causing issues. Instead, added more robust checking of downloaded files so that they do not end up overwriting files that were downloaded earlier. Although the link list can usually mitigate downloading the same files over and over again, it will not eliminate the problem, for example, the same file can be referred to as /dir/index.html and /dir/.

## 2.1.3 (2022-11-12)
### Bug fixes
- Kept the format of the log file header the same when using debug mode, assisting usage with the development portal on Protoweb. It does not affect functionality when Warnick is used in console.

## 2.1.2 (2022-11-12)
### Bug fixes
- Fixed a bug that allowed the main homepage of a domain to be downloaded twice by error. Added additional handling for IA HTTP status codes to account for connection throttling.

## 2.1.1 (2022-11-12)
### Bug fixes
- Fixed a bug in link parsing where a link such as "calling.gif"ALT would be decoded as calling.gifALT. Now quotes are parsed properly.

## 2.1.0 (2022-11-11)
### Changes
- Added variables for the user to customize the search range, which was previously hard-coded.
### Bug fixes
- Made redirection handling more robust. The previous version of Warnick contained a bug that would skip target date search when the file to be downloaded was a directory. This version follows the redirect, and looks at the MIME type of the downloaded file before determining if a file is within target date range.

## 2.0.7 (2022-07-20)
### Bug fixes
- Fixed a bug that would kill the whole recovery process if no links are found on the page.

## 2.0.6 (2022-07-20)
### Changes
- Improved link parser to be more robust at parsing links with broken or non-standard HTML code.
### Bug fixes
- Fixed bugs when downloading files with spaces or other special characters in filenames and a file operation would fail.

## 2.0.5 (2022-07-12)
### Changes
- Usability improvements. 
- Now creates ./sites folder if it doesn't already exist.
### Bug fixes
- Fixed various bugs

## 2.0.4 (2022-07-11)
### Bug fixes
- Fixed various bugs when used as part of a multi-user environment in Protoweb

## 2.0.3 (2022-07-10)
### Changes
- Optimized code
- Removed unused functions
- Re-added cancel-job functionality for use in web integrations.

## 2.0.2 (2022-07-10)
### Bug fixes
- Fixed incorrect handling of weird filenames.

## 2.0.1 (2022-07-10)
### Changes
- Added support for discarding weird file names and improved reporting on them.
### Bug fixes
- Fixed various bugs

## 2.0.0 (2022-07-08)
### Changes
- Script rewrite. 
- Complete overhaul on how links get scanned. Now using a completely different methodology to scan the site for links for a major improvement on the amount of results found.

## 1.5.1 (2021-06-05)
### Bug fixes
- Fixed an issue where not all pages would be archived due to page links being case insensitive. Some servers were Windows servers, and file.html and File.html were actually the same file in servers such as this.

## 1.5.0 (2021-06-04)
### Changes
- Rewrote the link parser script so Warnick can more readily parse non-standard HTML tags such as &lt;A Href &nbsp;= &nbsp;link.html &nbsp;&gt;
### Known bugs
- In rare circumstances some links may rarely be left out due to their references being written with a non-case sensitive server in mind. See v1.4.2 for more details.

## 1.4.4 (2021-05-29)
### Changes
- Added watchdog code to prevent infinite loops. Fixes the infinite loop problem.
### Known bugs
- Some links do not parse properly when a page uses non-standard HTML tags.
- In rare circumstances some links may rarely be left out due to their references being written with a non-case sensitive server in mind. See v1.4.2 for more details.

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
- In rare circumstances some links may rarely be left out due to their references being written with a non-case sensitive server in mind. This situation can happen when pages were written for a Windows-based server, and less commonly with websites with lax rules in place taken care of with numerous redirections. An example is when downloading www.geocities.com/Area51/1000/, where the website refers to /area51/main.html, and the actual directory where the file resides, is /Area51/main.html. Geocities had a redirection from /area51/ to /Area51/ so the problem was transparent from the author's view. This however makes a case-sensitive comparison to see if the directory is the same or not, and rules out /area51/main.html, because it sees it as a different directory. From the point of view of Geocities.com, the directories Area51 and area51 are one and the same (aliased). 
