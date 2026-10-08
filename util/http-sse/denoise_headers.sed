#!/bin/sed -nurf
# -*- coding: UTF-8, tab-width: 2 -*-
s~\r$~~
/^$/q
/^[Cc]ontent-[Ll]ength:/b
/^[Dd]ate:/b
/^[Ss]erver:/b
/^[Ss]et-[Cc]ookie:/b
p
