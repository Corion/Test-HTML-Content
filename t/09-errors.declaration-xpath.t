# Test script to test the failure modes of Test::HTML::Content
use Test::More;

eval {
  require Test::Builder::Tester;
  Test::Builder::Tester->import;
};

if ($@) {
  plan skip_all => "Test::Builder::Tester required for testing error messages";
}

plan tests => 6;

use_ok('Test::HTML::Content');

# Test that each exported function fails as documented

test_out("not ok 1 - Link failure (no links)");
test_fail(+4);
test_diag("Expected to find at least one <a> tag(s) matching",
          "  href = http://www.perl.com",
          "Got none");
link_ok("<html><body></body></html>","http://www.perl.com","Link failure (no links)");
test_test("Finding no link works");

test_out("not ok 1 - Link failure (two links that don't match)");
test_fail(+6);
test_diag("Expected to find at least one <a> tag(s) matching",
          "  href = http://www.perl.com",
          "Got",
          '  <a href="http://www.foo.com">foo</a>',
          '  <a href="index.html">Home</a>');
link_ok("<a href='http://www.foo.com'>foo</a><a href='index.html'>Home</a>",
        "http://www.perl.com","Link failure (two links that don't match)");
test_test("Finding no link returns all other links");

test_out("not ok 1 - Link failure (two links shouldn't exist do)");
test_fail(+6);
test_diag("Expected to find no <a> tag(s) matching",
          "  href = (?-xism:.)",
          "Got",
          '  <a href="http://www.foo.com">foo</a>',
          '  <a href="index.html">Home</a>');
no_link("<a href='http://www.foo.com'>foo</a><a href='index.html'>Home</a>",
        qr".","Link failure (two links shouldn't exist do)");
test_test("Finding a link where one should be returns all other links");

test_out("not ok 1 - Link failure (too few links)");
test_fail(+6);
test_diag("Expected to find exactly 3 <a> tag(s) matching",
          "  href = (?-xism:.)",
          "Got",
          '  <a href="http://www.foo.com">foo</a>',
          '  <a href="index.html">Home</a>');
link_count("<a href='http://www.foo.com'>foo</a><a href='index.html'>Home</a>",qr".",3,"Link failure (too few links)");
test_test("Diagnosing too few links works");

test_out("not ok 1 - Link failure (too many links)");
test_fail(+8);
test_diag("Expected to find exactly 3 <a> tag(s) matching",
          "  href = (?-xism:.)",
          "Got",
          '  <a href="http://www.bar.com">bar</a>',
          '  <a href="http://www.dot.com">.</a>',
          '  <a href="http://www.foo.com">foo</a>',
          '  <a href="index.html">Home</a>');
link_count("<a href='http://www.bar.com'>bar</a><a href='http://www.dot.com'>.</a><a href='http://www.foo.com'>foo</a><a href='index.html'>Home</a>",qr".",3,"Link failure (too many links)");
test_test("Diagnosing too many links works");