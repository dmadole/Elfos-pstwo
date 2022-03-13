#!/bin/sh

# This script creates the packed font table that is included in the driver.
# It processes the embedded "ASCII Art" version of the font below using
# some messy shell scripting to output the appropriate "db" statements.
# Note that this doesn't do any format or error checking; the input is 
# treated simply as a stream of bits that is broken up into 8-bit chunks
# and then output in hex within "db" lines.

( tr 'X-' '10' |
  tr -d '\n' |
  sed -r 's/(........)/\1\n/g' |
  while read a
  do printf "%xh\n" "$((2#$a))"
  done |
  sed -r 's/^([a-f])/0\1/' |
  tr '\n' ',' |
  sed -r 's/(.{47}[^,]*),/\1\n/g' |
  sed 's/,$/\n/' |
  sed 's/^/            db    /'
) << EOF

-----
-----
-----
-----
-----
-----
-----

--X--
--X--
--X--
--X--
--X--
-----
--X--

-X-X-
-X-X-
-X-X-
-----
-----
-----
-----

-X-X-
-X-X-
XXXXX
-X-X-
XXXXX
-X-X-
-X-X-

--X--
-XXXX
X-X--
-XXX-
--X-X
XXXX-
--X--

XX---
XX--X
---X-
--X--
-X---
X--XX
---XX

-XX--
X--X-
X-X--
-X---
X-X-X
X--X-
-XX-X

-XX--
--X--
-X---
-----
-----
-----
-----

---X-
--X--
-X---
-X---
-X---
--X--
---X-

-X---
--X--
---X-
---X-
---X-
--X--
-X---

-----
--X--
X-X-X
-XXX-
X-X-X
--X--
-----

-----
--X--
--X--
XXXXX
--X--
--X--
-----

-----
-----
-----
-----
-XX--
--X--
-X---

-----
-----
-----
XXXXX
-----
-----
-----

-----
-----
-----
-----
-----
-XX--
-XX--

-----
----X
---X-
--X--
-X---
X----
-----

-XXX-
X---X
X--XX
X-X-X
XX--X
X---X
-XXX-

--X--
-XX--
--X--
--X--
--X--
--X--
-XXX-

-XXX-
X---X
----X
---X-
--X--
-X---
XXXXX

XXXXX
---X-
--X--
---X-
----X
X---X
-XXX-

---X-
--XX-
-X-X-
X--X-
XXXXX
---X-
---X-

XXXXX
X----
XXXX-
----X
----X
X---X
-XXX-

--XX-
-X---
X----
XXXX-
X---X
X---X
-XXX-

XXXXX
----X
---X-
--X--
-X---
-X---
-X---

-XXX-
X---X
X---X
-XXX-
X---X
X---X
-XXX-

-XXX-
X---X
X---X
-XXXX
----X
---X-
-XX--

-----
-XX--
-XX--
-----
-XX--
-XX--
-----

-----
-XX--
-XX--
-----
-XX--
--X--
-X---

---X-
--X--
-X---
X----
-X---
--X--
---X-

-----
-----
XXXXX
-----
XXXXX
-----
-----

-X---
--X--
---X-
----X
---X-
--X--
-X---

-XXX-
X---X
----X
---X-
--X--
-----
--X--

-XXX-
X---X
----X
-XX-X
X-X-X
X-X-X
-XXX-

--X--
-X-X-
-X-X-
X---X
XXXXX
X---X
X---X

XXXX-
X---X
X---X
XXXX-
X---X
X---X
XXXX-

-XXX-
X---X
X----
X----
X----
X---X
-XXX-

XXX--
X--X-
X---X
X---X
X---X
X--X-
XXX--

XXXXX
X----
X----
XXXX-
X----
X----
XXXXX

XXXXX
X----
X----
XXXX-
X----
X----
X----

-XXX-
X---X
X----
X-XXX
X---X
X---X
-XXX-

X---X
X---X
X---X
XXXXX
X---X
X---X
X---X

-XXX-
--X--
--X--
--X--
--X--
--X--
-XXX-

--XXX
---X-
---X-
---X-
---X-
X--X-
-XX--

X---X
X--X-
X-X--
XX---
X-X--
X--X-
X---X

X----
X----
X----
X----
X----
X----
XXXXX

X---X
XX-XX
X-X-X
X-X-X
X---X
X---X
X---X

X---X
X---X
XX--X
X-X-X
X--XX
X---X
X---X

-XXX-
X---X
X---X
X---X
X---X
X---X
-XXX-

XXXX-
X---X
X---X
XXXX-
X----
X----
X----

-XXX-
X---X
X---X
X---X
X-X-X
X--X-
-XX-X

XXXX-
X---X
X---X
XXXX-
X-X--
X--X-
X---X

-XXXX
X----
X----
-XXX-
----X
----X
XXXX-

XXXXX
--X--
--X--
--X--
--X--
--X--
--X--

X---X
X---X
X---X
X---X
X---X
X---X
-XXX-

X---X
X---X
X---X
-X-X-
-X-X-
-X-X-
--X--

X---X
X---X
X---X
X-X-X
X-X-X
X-X-X
-X-X-

X---X
X---X
-X-X-
--X--
-X-X-
X---X
X---X

X---X
X---X
X---X
-X-X-
--X--
--X--
--X--

XXXXX
----X
---X-
--X--
-X---
X----
XXXXX

-XXX-
-X---
-X---
-X---
-X---
-X---
-XXX-

-----
X----
-X---
--X--
---X-
----X
-----

-XXX-
---X-
---X-
---X-
---X-
---X-
-XXX-

--X--
-X-X-
X---X
-----
-----
-----
-----

-----
-----
-----
-----
-----
-----
XXXXX

-X---
--X--
---X-
-----
-----
-----
-----

-----
-----
-XXX-
----X
-XXXX
X---X
-XXXX

X----
X----
X-XX-
XX--X
X---X
X---X
XXXX-

-----
-----
-XXX-
X----
X----
X---X
-XXX-

----X
----X
-XX-X
X--XX
X---X
X---X
-XXXX

-----
-----
-XXX-
X---X
XXXXX
X----
-XXX-

--XX-
-X--X
-X---
XXX--
-X---
-X---
-X---

-----
-----
-XXXX
X---X
-XXXX
----X
-XXX-

X----
X----
X-XX-
XX--X
X---X
X---X
X---X

--X--
-----
-XX--
--X--
--X--
--X--
-XXX-

---X-
-----
--XX-
---X-
---X-
X--X-
-XX--

X----
X----
X--X-
X-X--
XX---
X-X--
X--X-

-XX--
--X--
--X--
--X--
--X--
--X--
-XXX-

-----
-----
XX-X-
X-X-X
X-X-X
X---X
X---X

-----
-----
X-XX-
XX--X
X---X
X---X
X---X

-----
-----
-XXX-
X---X
X---X
X---X
-XXX-

-----
-----
XXXX-
X---X
XXXX-
X----
X----

-----
-----
-XXXX
X---X
-XXXX
----X
----X

-----
-----
X-XX-
XX--X
X----
X----
X----

-----
-----
-XXX-
X----
-XXX-
----X
-XXX-

-X---
-X---
XXX--
-X---
-X---
-X--X
--XX-

-----
-----
X---X
X---X
X---X
X--XX
-XX-X

-----
-----
X---X
X---X
X---X
-X-X-
--X--

-----
-----
X---X
X---X
X-X-X
X-X-X
-X-X-

-----
-----
X---X
-X-X-
--X--
-X-X-
X---X

-----
-----
X---X
X---X
-XXXX
----X
-XXX-

-----
-----
XXXXX
---X-
--X--
-X---
XXXXX

---X-
--X--
--X--
-X---
--X--
--X--
---X-

--X--
--X--
--X--
--X--
--X--
--X--
--X--

-X---
--X--
--X--
---X-
--X--
--X--
-X---

-----
-----
-XX-X
X--X-
-----
-----
-----

XXXXX
XXXXX
XXXXX
XXXXX
XXXXX
XXXXX
XXXXX

EOF

