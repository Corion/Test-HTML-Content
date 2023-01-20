use 5.006000;

our $have_xml_libxml;
our @libxml;
BEGIN {
  eval { require XML::LibXML;
         $have_xml_libxml = $XML::LibXML::VERSION };
  undef $@;
  if ($have_xml_libxml) {
    print "XML::LibXML version $have_xml_libxml found\n";
    push @libxml, "XML::LibXML" => '2.0133'; # a random recent-ish version
  };
};


use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'    => 'Test::HTML::Content',
    'VERSION_FROM'  => 'lib/Test/HTML/Content.pm', # finds $VERSION
    'PREREQ_PM'    => {
              'Test::Builder' => 0,
              'Test::More' => 0,
              'HTML::TokeParser' => 0,
              @libxml,
          }, # e.g., Module::Name => 1.1
);

our $have_test_inline;
BEGIN {
  eval { require Test::Inline;
         $have_test_inline = 1 };
  undef $@;
  if (! $have_test_inline) {
    print "Test::Inline is nice for testing the examples, but not necessary\n"
  };
};

1;
