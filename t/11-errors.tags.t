# Test script to test the failure modes of Test::HTML::Content
use Test::More;

eval {
  require Test::Builder::Tester;
  Test::Builder::Tester->import;
};

if ($@) {
  plan skip_all => "Test::Builder::Tester required for testing error messages";
}

plan tests => 2;

use_ok('Test::HTML::Content');

test_out("ok 1 - Tag warning (no attributes)");
test_diag("Usage ambiguity: tag_ok() called without specified tag attributes",
          "(I'm defaulting to any attributes)");
tag_ok("<a href='http://foo.com'>foo</a>","a","Tag warning (no attributes)");
test_test("Warning is generated if tag specification is missing");
