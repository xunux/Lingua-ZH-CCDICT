---------------------------------------------------------------------------------------
readme.txt for CCDICT.txt v3.2.0
---------------------------------------------------------------------------------------

Format for each line (TAB separated): [U|C|D|M|X+][x][x]xxxx.y	fieldname	value

where U+ indicates a Unicode/ISO10646:2 character code xxxx or xxxxx. Otherwise a code xxxxxx used internally.
Unicode values are between U+4E00 and U+9AF5 for characters in the Unicode CJK Unified Ideographic plane,
between U+3400 and U+4DB5 for CJK Unified Ideographs Extension A, and between U+20000 and U+2A6D6 for
CJK Unified Ideographs Extension B. y indicates homograph number.

Field descriptions

fR/S
---------------
Dictionary radical/index
Format rrr.ii  where rrr=K'ang Hsi radical number, ii index (total stroke count minus radical stroke count).

fAltR/S
------
Alternative radical/index. Same format as above fR/S.

fTotalStrokes
-------
Dictionary stroke count.

fCangjie
-------
Cangjie input code.

fFourCorner
-------
Four corner dictionary code.

fMacIver
-------------
MacIver Hakka pronunciation
From Chinese-English Hakka dictionary.

fRey
---
Rey Hakka pronunciation
From Chinese-French Hakka dictionary.

fHagfaPinyim
-----------
Lau Chunfat Hakka pronunciation
Incorporated without changes from the original database maintained by the author.

fSiyan
-----
Siyan Hakka pronunciation.

fHailu
-----
Hailu Hakka pronunciation.

fCantonese
-------
Cantonese jyutpin pronunciation.

fHanyu
--------
Mainland Putonghua pronunciation in hanyu pinyin.

fTongyong
--------
Taiwan guoyu pronunciation in tongyong (universal) pinyin.

fEnglish
-------
English meaning.

Copyright (c) 1995-2002 Thomas Chin