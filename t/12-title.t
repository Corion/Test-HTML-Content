use strict;
use Test::HTML::Content( tests => 1 );

title_ok('<html><head><title>A test title</title></head><body></body></html>',qr"A test title","Title RE");


