use strict;
use Test::HTML::Content( tests => 6 );

title_ok('<html><head><title>A test title</title></head><body></body></html>',qr"A test title","Title RE");
title_ok('<html><head><title>A test title</title></head><body></body></html>',qr"^A test title$","Anchored title RE");
title_ok('<html><head><title>A test title</title></head><body></body></html>',qr"test","Title RE works for partial matches");
title_ok('<html><head><title>A test title</title></head><body></body></html>',"A test title","Title string");
no_title('<html><head><title>A test title</title></head><body></body></html>',"test","Complete title string gets compared");
no_title('<html><head><title>A test title</title></head><body></body></html>',"A toast title","no_title string");

