Planned Copy
============
Ștefan Suciu
2016-12-07

Version: 0.911

Planned Copy - a smarter copy application for your Linux box.  See the
manual for details.


Install
-------

The easiest method is to download the latest binary package made with
Cava Packager from the GitHub repository and then:

```
# chmod 755 planned-copy-linux-x86_64-0-XXX.bin
# cp planned-copy-linux-x86_64-0-XXX.bin /opt/
# cd /opt
# ./planned-copy-linux-x86_64-0-XXX.bin
```

Put `/opt/planned-copy/bin/` in your PATH.

The second option is to download the source package from the GitHub
repository and install like any other Perl package.

Download the distribution, unpack and install:

```
$ tar xaf App::PlannedCopy-0.NNN.tar.gz
$ cd App::PlannedCopy-0.NNN
```

Then as usual for a Perl application:

```
$ perl Makefile.PL
$ make
$ make test
$ make install
```

The third option is to clone the repository, build and install with `dzil`.


Known Issues
------------

If the `diff` program is set to ignore whitespace, then when `plcp`
reports differences, the `diff` program may report identical files.

If the destination path for an item is too long, it will alter the
printing format.


License And Copyright
---------------------

Copyright (C) 2016 Ștefan Suciu

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; version 2 dated June, 1991 or at your option
any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

A copy of the GNU General Public License is available in the source tree;
if not, write to the Free Software Foundation, Inc.,
59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
