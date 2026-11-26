# Third-party notices

`lib/src/core/html/named_entities.dart` is generated from the WHATWG HTML
named character references table at <https://html.spec.whatwg.org/entities.json>.
Only entries with a semicolon are included, as required by CommonMark.
The source snapshot was retrieved on 2026-10-17; its SHA-256 is recorded in
the generated file. The conversion changes the data format, not the mappings.

Copyright WHATWG (Apple, Google, Mozilla, Microsoft).

Under section 7.1.1 of <https://whatwg.org/ipr-policy>, portions incorporated
into source code are available under the BSD 3-Clause License:

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice,
   this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.
3. Neither the name of the copyright holder nor the names of its contributors
   may be used to endorse or promote products derived from this software
   without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.


## CommonMark and GFM specification examples

`test/core/spec/fixtures/commonmark-0.31.2.json` contains the unmodified
652 examples published by John MacFarlane and CommonMark contributors at
<https://spec.commonmark.org/0.31.2/spec.json>.
Source SHA-256: `d431b29d97b6f73e69d547109cf5081578fac931e72afe95639ebe766c1b2a20`.

`test/core/spec/fixtures/gfm-0.29-extensions.json` contains 27 examples extracted
from the tables, task lists, strikethrough and autolinks sections of GitHub's
GFM 0.29 specification (2019-04-06), <https://github.github.com/gfm/>.
GFM is based on the CommonMark specification by John MacFarlane.
Source HTML SHA-256: `b153d814fdfc8624bb6da7449162c1cd707a637f7d1c1b636eb44b9cf63fa220`.
The extraction changes the container format to JSON and turns visible tab
markers back into tab characters. Example Markdown and expected HTML are
otherwise preserved. Reproduce with `tool/extract_gfm_fixtures.py` and a saved
copy of the official HTML page.

Both specifications license these examples under
[Creative Commons Attribution-ShareAlike 4.0 International](https://creativecommons.org/licenses/by-sa/4.0/).
These fixture files retain that license. Source snapshots were retrieved on
2026-10-17. The license does not imply endorsement of this implementation.

## Unicode Character Database

The direction ranges in `bidi_classes.dart` derive from the Unicode 17.0.0
`DerivedBidiClass.txt` data. The following license applies to that data.

UNICODE LICENSE V3

COPYRIGHT AND PERMISSION NOTICE

Copyright © 1991-2026 Unicode, Inc.

NOTICE TO USER: Carefully read the following legal agreement. BY
DOWNLOADING, INSTALLING, COPYING OR OTHERWISE USING DATA FILES, AND/OR
SOFTWARE, YOU UNEQUIVOCALLY ACCEPT, AND AGREE TO BE BOUND BY, ALL OF THE
TERMS AND CONDITIONS OF THIS AGREEMENT. IF YOU DO NOT AGREE, DO NOT
DOWNLOAD, INSTALL, COPY, DISTRIBUTE OR USE THE DATA FILES OR SOFTWARE.

Permission is hereby granted, free of charge, to any person obtaining a
copy of data files and any associated documentation (the "Data Files") or
software and any associated documentation (the "Software") to deal in the
Data Files or Software without restriction, including without limitation
the rights to use, copy, modify, merge, publish, distribute, and/or sell
copies of the Data Files or Software, and to permit persons to whom the
Data Files or Software are furnished to do so, provided that either (a)
this copyright and permission notice appear with all copies of the Data
Files or Software, or (b) this copyright and permission notice appear in
associated Documentation.

THE DATA FILES AND SOFTWARE ARE PROVIDED "AS IS", WITHOUT WARRANTY OF ANY
KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT OF
THIRD PARTY RIGHTS.

IN NO EVENT SHALL THE COPYRIGHT HOLDER OR HOLDERS INCLUDED IN THIS NOTICE
BE LIABLE FOR ANY CLAIM, OR ANY SPECIAL INDIRECT OR CONSEQUENTIAL DAMAGES,
OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS,
WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION,
ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THE DATA
FILES OR SOFTWARE.

Except as contained in this notice, the name of a copyright holder shall
not be used in advertising or otherwise to promote the sale, use or other
dealings in these Data Files or Software without prior written
authorization of the copyright holder.
