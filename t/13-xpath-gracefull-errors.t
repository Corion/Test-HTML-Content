# Test script to test the failure modes of Test::HTML::Content
use Test::More;

eval {
  require Test::Builder::Tester;
  Test::Builder::Tester->import;
};

if ($@) {
  plan skip_all => "Test::Builder::Tester required for testing error messages";
}

plan tests => 4;

use_ok('Test::HTML::Content');

SKIP: {
  { no warnings 'once';
    $Test::HTML::Content::can_xpath
      or skip "XML::XPath and HTML::Tidy required", 3;
  };

  my ($tree,$result,$seen);

  eval {
    ($result,$seen) = Test::HTML::Content::__count_comments("<!-- hidden massage --><!-- hidden massage --><!-- hidden massage -->", "hidden message");
  };
  is($@,'',"Invalid HTML does not crash the test");
  eval {
    ($tree) = Test::HTML::Content::__get_node_tree("<!-- hidden massage --><!-- hidden massage --><!-- hidden massage -->",'//comment()');
  };
  is($@,'',"Invalid HTML does not crash the test");
  is($tree,undef,"The result of __get_node_tree is undef");
}