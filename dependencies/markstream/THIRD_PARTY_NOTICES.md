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
