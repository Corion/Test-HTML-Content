package Test::HTML::Content;

require 5.005_62;
use strict;
use File::Spec;
use Carp qw(carp croak);

use HTML::TokeParser;

# we want to stay compatible to 5.5 and use warnings if
# we can
eval 'use warnings' if $] >= 5.006;
use Test::Builder;
require Exporter;

use vars qw/@ISA @EXPORT_OK @EXPORT $VERSION $can_xpath/;

@ISA = qw(Exporter);

use vars qw( $tidy );

# DONE:
# * use Test::Builder;
# * Add comment_ok() method
# * Allow RE instead of plain strings in the functions (for tag attributes and comments)
# * Create a function to check the DOCTYPE and other directives
# * Have a better way to diagnose ignored candidates in tag_ok(), tag_count
#   and no_tag() in case a test fails

@EXPORT = qw(
  link_ok no_link link_count
  tag_ok no_tag tag_count
  comment_ok no_comment comment_count
  has_declaration no_declaration
  text_ok no_text text_count
  title_ok no_title
  );

$VERSION = '0.05';

my $Test = Test::Builder->new;

use vars qw($HTML_PARSER_StripsTags);

# Cribbed from the Test::Builder synopsis
sub import {
    my($self) = shift;
    my $pack = caller;
    $Test->exported_to($pack);
    $Test->plan(@_);
    $self->export_to_level(1, $self, @EXPORT);
}

sub __dwim_compare {
  # Do the Right Thing (Perl 6 style) with the RHS being a Regex or a string
  my ($target,$template) = @_;
  if (ref $template) { # supposedly a Regexp, but possibly blessed, so no eq comparision
    return ($target =~ $template )
  } else {
    return $target eq $template;
  };
};

sub __match_comment {
  my ($text,$template) = @_;
  $text =~ s/^<!--(.*?)-->$/$1/ unless $HTML_PARSER_StripsTags;
  unless (ref $template eq "Regexp") {
    $text =~ s/^\s*(.*?)\s*$/$1/;
    $template =~ s/^\s*(.*?)\s*$/$1/;
  };
  return __dwim_compare($text, $template);
};

sub __count_comments {
  my ($HTML,$comment) = @_;
  my $tree;
  $tree = __get_node_tree($HTML,'//comment()');
  return (undef,undef) unless ($tree);

  my $result = 0;
  my $seen = [];
  
  foreach my $node ($tree->get_nodelist) {
    my $content = XML::XPath::XMLParser::as_string($node);
    $content =~ s/\A<!--(.*?)-->\Z/$1/gsm;
    push @$seen, $content;
    $result++ if __match_comment($content,$comment);
  };

  return ($result, $seen);
};

sub __output_diag {
  my ($cond,$match,$descr,$kind,$name,$seen) = @_;

  local $Test::Builder::Level = 2;

  unless ($Test->ok($cond,$name)) {
    if (@$seen) {
      $Test->diag( "Saw '$_'" ) for @$seen;
    } else {
      $Test->diag( "No $kind found at all" );
    };
    $Test->diag( "Expected $descr like '$match'" );
  };
};

sub __invalid_html {
  my ($HTML,$name) = @_;
  carp "No test name given" unless $name;
  $Test->ok(0,$name);
  $Test->diag( "Invalid HTML:");
  $Test->diag($HTML);
};

sub comment_ok {
  my ($HTML,$comment,$name) = @_;
  my ($result,$seen) = __count_comments($HTML,$comment);

  if (defined $result) {
    __output_diag($result > 0,$comment,"at least one comment","comment",$name,$seen);
  } else {
    local $Test::Builder::Level = $Test::Builder::Level +1;
    __invalid_html($HTML,$name);
  };

  $result;
};

sub no_comment {
  my ($HTML,$comment,$name) = @_;
  my ($result,$seen) = __count_comments($HTML,$comment);

  if (defined $result) {
    __output_diag($result == 0,$comment,"no comment","comment",$name,$seen);
  } else {
    local $Test::Builder::Level = $Test::Builder::Level +1;
    __invalid_html($HTML,$name);
  };

  $result;
};

sub comment_count {
  my ($HTML,$comment,$count,$name) = @_;
  my ($result,$seen) = __count_comments($HTML,$comment);

  if (defined $result) {
    __output_diag($result == $count,$comment,"exactly $count comments","comment",$name,$seen);
  } else {
    local $Test::Builder::Level = $Test::Builder::Level +1;
    __invalid_html($HTML,$name);
  };

  return $result;
};

sub __match_text {
  my ($text,$template) = @_;
  unless (ref $template eq "Regexp") {
    $text =~ s/^\s*(.*?)\s*$/$1/;
    $template =~ s/^\s*(.*?)\s*$/$1/;
  };
  return __dwim_compare($text, $template);
};

sub __count_text {
  my ($HTML,$text) = @_;
  my $tree = __get_node_tree($HTML,'//text()');
  return (undef,undef) unless $tree;

  my $result = 0;
  my $seen = [];

  foreach my $node ($tree->get_nodelist) {
    my $content = XML::XPath::XMLParser::as_string($node);
    push @$seen, $content
      unless $content =~ /\A\r?\n?\Z/sm;
    $result++ if __match_text($content,$text);
  };

  return ($result, $seen);
};

sub text_ok {
  my ($HTML,$text,$name) = @_;
  my ($result,$seen) = __count_text($HTML,$text);

  if (defined $result) {
    __output_diag($result > 0,$text,"at least one text element","text",$name,$seen);
  } else {
    local $Test::Builder::Level = $Test::Builder::Level +1;
    __invalid_html($HTML,$name);
  };

  $result;
};

sub no_text {
  my ($HTML,$text,$name) = @_;
  my ($result,$seen) = __count_text($HTML,$text);

  if (defined $result) {
    __output_diag($result == 0,$text,"no text elements","text",$name,$seen);
  } else {
    local $Test::Builder::Level = $Test::Builder::Level +1;
    __invalid_html($HTML,$name);
  };

  $result;
};

sub text_count {
  my ($HTML,$text,$count,$name) = @_;
  my ($result,$seen) = __count_text($HTML,$text);

  if (defined $result) {
    __output_diag($result == $count,$text,"exactly $count elements","text",$name,$seen);
  } else {
    local $Test::Builder::Level = $Test::Builder::Level +1;
    __invalid_html($HTML,$name);
  };

  $result;
};

sub __match {
  my ($attrs,$currattr,$key) = @_;
  my $result = 1;

  if (exists $currattr->{$key}) {
    if (! defined $attrs->{$key}) {
      $result = 0; # We don't want to see this attribute here
    } else {
      $result = 0 unless __dwim_compare($currattr->{$key}, $attrs->{$key});
    };
  } else {
    if (! defined $attrs->{$key}) {
      $result = 0 if (exists $currattr->{$key});
    } else {
      $result = 0;
    };
  };
  return $result;
};

{
  sub XML::XPath::Function::matches {
    my $self = shift;
    my ($node, @params) = @_;
    die "starts-with: incorrect number of params\n" unless @params == 2;
    my $re = $params[1]->string_value;
    return($params[0]->string_value =~ /$re/)
      ? XML::XPath::Boolean->True
      : XML::XPath::Boolean->False;
  }

  sub XML::XPath::Function::comment {
    my $self = shift;
    my ($node, @params) = @_;
    die "starts-with: incorrect number of params\n" unless @params == 1;
    my $re = $params[1]->string_value;
    return(ref $node =~ /Comment$/)
      ? XML::XPath::Boolean->True
      : XML::XPath::Boolean->False;
  };
};

sub __get_node_tree {
  my ($userHTML,$query) = @_;
  
  croak "No HTML given" unless defined $userHTML;
  croak "No query given" unless defined $query;
  
  $tidy->ParseString($userHTML);
  $tidy->CleanAndRepair();
  my ($stat,$HTML) = $tidy->SaveString();

  my ($tree,$result);
  if ($HTML !~ m!\A\s*\Z!ms) {
    eval {
      require XML::LibXML; XML::LibXML->import;
      $tree = XML::LibXML->new()->parse_string($HTML);
    };
    unless ($tree) {
      eval {
        require XML::XPath; XML::XPath->import;
        require XML::Parser;

        my $p = XML::Parser->new( ErrorContext => 2, ParseParamEnt => 0, NoLWP => 1 );
        $tree = XML::XPath->new( parser => $p, xml => $HTML );
      };
    };
    undef $tree if $@;
    
    if ($tree) {
      eval { 
        $result = $tree->find($query);
        unless ($result) {
          $result = {};
          bless $result, 'Test::HTML::Content::EmptyXPathResult';
        };
      };
    };
  } else { };
  return $result;
};

sub __count_tags {
  my ($HTML,$tag,$attrref) = @_;
  $attrref = {} unless defined $attrref;

  my $fallback = lc "//$tag";
  my $query = lc "//$tag";
  if ($attrref) {
    for (sort keys %$attrref) {
      my $value = $attrref->{$_};
      my $name;
      if ($_ eq '_content') {
        $name = "."
      } else {
        $name = '@' . $_;
      };
      if (! defined $value) {
        $query .= "[not($name)]"
      } elsif (ref $attrref->{$_} ne 'Regexp') {
        $query .= "[$name = '" . $value . "']";
      } else {
        $query .= "[matches($name, '" . $value . "')]";
      };
    };
  };

  my $tree = __get_node_tree($HTML,$query);
  return (undef,undef) unless $tree;

  my $result = $tree->size;

  # Collect the nodes we did see for later reference :
  my $seen = [];
  foreach my $node (__get_node_tree($HTML,$fallback)->get_nodelist) {
    push @$seen, XML::XPath::XMLParser::as_string($node);
  };
  return $result,$seen;
};

sub __tag_diag {
  my ($tag,$num,$attrs,$found) = @_;
  my $phrase = "Expected to find $num <$tag> tag(s)";
  $phrase .= " matching" if (scalar keys %$attrs > 0);
  $Test->diag($phrase);
  $Test->diag("  $_ = " . $attrs->{$_}) for sort keys %$attrs;
  if (@$found) {
    $Test->diag("Got");
    $Test->diag("  " . $_) for @$found;
  } else {
    $Test->diag("Got none");
  };
};

sub tag_count {
  my ($HTML,$tag,$attrref,$count,$name) = @_;
  my ($currcount,$seen) = __count_tags($HTML,$tag,$attrref);
  my $result;
  if (defined $currcount) {
    if ($currcount eq 'skip') {
      $Test->skip($seen);
    } else {
      $result = $count == $currcount;
      unless ($Test->ok($result, $name)) {
        __tag_diag($tag,"exactly $count",$attrref,$seen) ;
      };
    };
  } else {
    local $Test::Builder::Level = $Test::Builder::Level +1;
    __invalid_html($HTML,$name);
  };

  $result;
};

sub tag_ok {
  my ($HTML,$tag,$attrref,$name) = @_;
  unless (defined $name) {
     if (! ref $attrref) {
       $Test->diag("Usage ambiguity: tag_ok() called without specified tag attributes");
       $Test->diag("(I'm defaulting to any attributes)");
       $name = $attrref;
       $attrref = {};
     };
  };
  my $result;
  my ($count,$seen) = __count_tags($HTML,$tag,$attrref);
  if (defined $count) {
    $result = $Test->ok( $count > 0, $name );
    __tag_diag($tag,"at least one",$attrref,$seen) unless ($result);
  } else {
    local $Test::Builder::Level = $Test::Builder::Level +1;
    __invalid_html($HTML,$name);
  };
  $result;
};

sub no_tag {
  my ($HTML,$tag,$attrref,$name) = @_;
  my ($count,$seen) = __count_tags($HTML,$tag,$attrref);
  my $result;
  if (defined $count) {
    $result = $count == 0;
    $Test->ok($result,$name);
    __tag_diag($tag,"no",$attrref,$seen) unless ($result);
  } else {
    local $Test::Builder::Level = $Test::Builder::Level +1;
    __invalid_html($HTML,$name);
  };

  $result;
};

sub link_count {
  my ($HTML,$link,$count,$name) = @_;
  local $Test::Builder::Level = 2;
  return tag_count($HTML,"a",{href => $link},$count,$name);
};

sub link_ok {
  my ($HTML,$link,$name) = (@_);
  local $Test::Builder::Level = 2;
  return tag_ok($HTML,'a',{ href => $link },$name);
};

sub no_link {
  my ($HTML,$link,$name) = (@_);
  local $Test::Builder::Level = 2;
  return no_tag($HTML,'a',{ href => $link },$name);
};

sub title_ok {
  my ($HTML,$title,$name) = @_;
  local $Test::Builder::Level = 2;
  return tag_ok($HTML,"title",{_content => $title},$name);
};

sub no_title {
  my ($HTML,$title,$name) = (@_);
  local $Test::Builder::Level = 2;
  return no_tag($HTML,'title',{ _content => $title },$name);
};

sub __match_declaration {
  my ($text,$template) = @_;
  $text =~ s/^<!(.*?)>$/$1/ unless $HTML_PARSER_StripsTags;
  unless (ref $template eq "Regexp") {
    $text =~ s/^\s*(.*?)\s*$/$1/;
    $template =~ s/^\s*(.*?)\s*$/$1/;
  };
  return __dwim_compare($text, $template);
};

sub __count_declarations {
  my ($HTML,$doctype) = @_;
  my $result = 0;
  my $seen = [];

  my $p = HTML::TokeParser->new(\$HTML);
  my $token;
  while ($token = $p->get_token) {
    my ($type,$text) = @$token;
    if ($type eq "D") {
      push @$seen, $text;
      $result++ if __match_declaration($text,$doctype);
    };
  };

  return $result, $seen;
};

sub has_declaration {
  my ($HTML,$declaration,$name) = @_;
  my ($result,$seen) = __count_declarations($HTML,$declaration);

  if (defined $result) {
    __output_diag($result == 1,$declaration,"exactly one declaration","declaration",$name,$seen);
  } else {
    local $Test::Builder::Level = $Test::Builder::Level +1;
    __invalid_html($HTML,$name);
  };

  $result;
};

sub no_declaration {
  my ($HTML,$declaration,$name) = @_;
  my ($result,$seen) = __count_declarations($HTML,$declaration);

  if (defined $result) {
    __output_diag($result == 0,$declaration,"no declaration","declaration",$name,$seen);
  } else {
    local $Test::Builder::Level = $Test::Builder::Level +1;
    __invalid_html($HTML,$name);
  };

  $result;
};

BEGIN {
  # Load the no-XML-variant if our prerequisites aren't there :
  eval q{ 
    require XML::XPath;
    use HTML::Tidy;
  };
  $can_xpath = $@ eq '';
};
    
# And install our plain handlers if we have to :
if ($can_xpath) {
  # Set up some more stuff :    
  $tidy = HTML::Tidy::Document->new();
  $tidy->Create();
  $tidy->OptSetBool( &HTML::Tidy::TidyXhtmlOut(), 1);
  $tidy->OptSetBool( &HTML::Tidy::TidyIndentContent(), 0 );
  $tidy->OptSetBool( &HTML::Tidy::TidyMark(), 0 );
  $tidy->OptSetBool( &HTML::Tidy::TidyBodyOnly(), 0 );
  $tidy->OptSetValue( &HTML::Tidy::TidyForceOutput(), 0 );
  $tidy->OptSetValue( &HTML::Tidy::TidyIndentSpaces(), 0 );
  $tidy->OptSetValue( &HTML::Tidy::TidyWrapLen(), 32000 );
  $tidy->SetErrorFile( File::Spec->devnull );
} else {
  require Test::HTML::Content::NoXPath;
  Test::HTML::Content::NoXPath->install;
};

{
  package Test::HTML::Content::EmptyXPathResult;
  sub size { 0 };
  sub get_nodelist { () };
};

1;

__END__

=head1 NAME

Test::HTML::Content - Perl extension for testing HTML output

=head1 SYNOPSIS

  use Test::HTML::Content( tests => 10 );

=for example begin

  $HTML = "<html><title>A test page</title><body>
           <img src='http://www.perl.com/camel.png' alt='camel'>
           <a href='http://www.perl.com'>Perl</a>
           <img src='http://www.perl.com/camel.png' alt='more camel'>
           <!--Hidden message--></body></html>";

  link_ok($HTML,"http://www.perl.com","We link to Perl");
  no_link($HTML,"http://www.pearl.com","We have no embarassing typos");
  link_ok($HTML,qr"http://[a-z]+\.perl.com","We have a link to perl.com");

  title_count($HTML,1,"We have one title tag");
  title_ok($HTML,qr/test/);

  tag_ok($HTML,"img", {src => "http://www.perl.com/camel.png"},
                        "We have an image of a camel on the page");
  tag_count($HTML,"img", {src => "http://www.perl.com/camel.png"}, 2,
                        "In fact, we have exactly two camel images on the page");
  no_tag($HTML,"blink",{}, "No annoying blink tags ..." );

  # We can check the textual contents
  text_ok($HTML,"Perl");

  # We can also check the contents of comments
  comment_ok($HTML,"Hidden message");

  # Advanced stuff

  # Using a regular expression to match against
  # tag attributes - here checking there are no ugly styles
  no_tag($HTML,"p",{ style => qr'ugly$' }, "No ugly styles" );

  # REs also can be used for substrings in comments
  comment_ok($HTML,qr"[hH]idden\s+mess");

=for example end

=head1 DESCRIPTION

This is a module to test the HTML output of your programs in simple
test scripts. It can test a scalar (presumably containing HTML) for
the presence (or absence, or a specific number) of tags having (or
lacking) specific attributes. Unspecified attributes are ignored,
and the attribute values can be specified as either scalars (meaning
a match succeeds if the strings are identical) or regular expressions
(meaning that a match succeeds if the actual attribute value is matched
by the given RE) or undef (meaning that the attribute must not
be present).

There is no way (yet) to specify or test the deeper structure
of the HTML (for example, META tags within the BODY) or the (textual)
content of tags. The next generation will most likely be based on
HTML::TreeBuilder to alleviate that situation, or implement
its own scheme.

The used HTML parser is HTML::TokeParser.

The test functionality is derived from L<Test::Builder>, and the export
behaviour is the same. When you use Test::HTML::Content, a set of
HTML testing functions is exported into the namespace of the caller.

=head2 EXPORT

Exports the bunch of test functions :

  link_ok() no_link() link_count()
  tag_ok() no_tag() tag_count()
  text_ok no_text() text_count()
  comment_ok() no_comment() comment_count()
  has_declaration() no_declaration()

=head2 CONSIDERATIONS

The module reparses the HTML string every time a test function is called.
This will make running many tests over the same, large HTML stream relatively
slow. I plan to add a simple minded caching mechanism that keeps the most
recent HTML stream in a cache.

=head2 BUGS

Currently, if there is text split up by comments, the text will be seen
as two separate entities, so the following dosen't work :

  is_text( "Hello<!-- brave new--> World", "Hello World" );

Whether this is a real bug or not, I don't know at the moment - most likely,
I'll modify text_ok() and siblings to ignore embedded comments.

=head2 TODO

My things on the todo list for this module. Patches are welcome !

=over 4

=item * Refactor the code to fold some of the internal routines

=item * Implement a cache for the last parsed tree / token sequence

=item * Possibly diag() the row/line number for failing tests

=item * Create a function (and a syntax) to inspect tag text contents without
reimplementing XSLT. ?possibly a special attribute? Will not happen
until HTML::TreeBuilder is used

=item * Consider HTML::TableExtractor for easy parsing of tables into arrays
and then subsequent testing of the arrays

=item * Find syntax for easily specifying relationships between tags
(see XSLT comment above)

=item * Consider HTML::TreeBuilder for more advanced structural checks

=item * Have a way of declaring "the link that shows 'foo' points to http://www.foo.com/"
(which is, after all, a way to check a tags contents, and thus won't happen
until HTML::TreeBuilder is used)

=item * Allow RE instead of plain strings in the functions (for tags themselves). This
one is most likely useless.

=back

=head1 LICENSE

This code may be distributed under the same terms as Perl itself.

=head1 AUTHOR

Max Maischein, corion@cpan.org

=head1 SEE ALSO

perl(1), L<Test::Builder>,L<Test::Simple>,L<HTML::TokeParser>,L<Test::HTML::Lint>.

=cut
