package HTML::Tidy::Simple;

require 5.005_62;
use strict;
use File::Spec;
use File::Temp qw( tempfile );
use Carp qw(carp croak);

# we want to stay compatible to 5.5 and use warnings if
# we can
eval 'use warnings' if $] >= 5.006;

use vars qw/@ISA $VERSION /;

@ISA = qw(Exporter);

use vars qw( @options %can );

$VERSION = '0.01';

BEGIN {
  eval q{ use HTML::Tidy };
  $can{module} = $@ eq '';
};

sub import {
  my $module = shift;
  @options = @_;
  
  my $envsep = $^O =~ /win32/i ? ";" : ":";
  if (scalar @options == 0) {
    @options = (
      namespace => 'HTML::Tidy',
      path => [ split $envsep, $ENV{PATH} ],
    );
  };
};

sub new {
  my ($class,@instance_options) = @_;
  my $self = { options => [ scalar @instance_options ? @instance_options : @options ] };
  
  bless $self,$class;
  $self;
};

sub tidy {
  my ($self,$HTML) = @_;
  my @order = @{$self->{options}};
  while (my ($name,$params) = splice @order,0,2) {
    no strict 'refs';
    my $result;
    eval {
      #print "Trying tidy_$name\n";
      $result = &{"tidy_$name"}( $self, $HTML, $params );
    };
    return $result if defined $result;
  };
  croak __PACKAGE__ . ": Could not find a cleanup routine";
};

sub tidy_tidy {
  my ($self,$HTML,$program) = @_;
  my @args = qw(--asxhtml);

  my ($fh,$tempfile) = tempfile();
  binmode $fh;
  print $fh $HTML;
  close $fh;
  
  my $result = system( $program, @args, $tempfile );
  
  unlink $tempfile
    or warn "Couldn't remove tempfile '$tempfile' : $!";
  
  return $result;
};

sub tidy_search {
  my ($self,$HTML,$path) = @_;
  my ($prog) = map {} @$path;
  die "'tidy' not found in ".join(" ",@$path) unless $prog;
  $self->tidy($HTML,$prog)
};

sub tidy_namespace {
  my ($self, $userHTML, $namespace) = @_;

  my $tidy;
  { no strict 'refs';
    $tidy = "${namespace}::Document"->new();
    $tidy->Create();
    $tidy->OptSetBool( &{"${namespace}::TidyXhtmlOut"}(), 1);
    $tidy->OptSetBool( &{"${namespace}::TidyIndentContent"}(), 0 );
    $tidy->OptSetBool( &{"${namespace}::TidyMark"}(), 0 );
    $tidy->OptSetBool( &{"${namespace}::TidyBodyOnly"}(), 0 );
    $tidy->OptSetValue( &{"${namespace}::TidyForceOutput"}(), 0 );
    $tidy->OptSetValue( &{"${namespace}::TidyIndentSpaces"}(), 0 );
    $tidy->OptSetValue( &{"${namespace}::TidyWrapLen"}(), 32000 );
  };
  $tidy->SetErrorFile( File::Spec->devnull );
  $self->{tidy} = $tidy;

  $tidy->ParseString($userHTML);
  $tidy->CleanAndRepair();
  my ($stat,$HTML) = $tidy->SaveString();
  return wantarray ? ($HTML,$stat) : $HTML;
};

1;

__END__

=head1 NAME

HTML::Tidy::Simple - Simplicistic wrapper around HTML Tidy

=head1 SYNOPSIS

=for example begin

  # Be smart
  use HTML::Tidy::Simple;

  # or give a list of directories where to look
  use HTML::Tidy::Simple( search => [ qw( /bin /usr/bin )]);

  # or specify where tidy resides
  use HTML::Tidy::Simple( tidy => '/path/to/tidy' );

  # or exclusively apply the HTML::Tidy module :
  use HTML::Tidy::Simple( namespace => 'HTML::Tidy' );

  my $cleaner = HTML::Tidy::Simple->new();
  my $badHTML = "";
  my $xHTML = $cleaner->tidy( $badHTML );

=for example end

=head1 DESCRIPTION

This module provides a very simplicistic interface to the HTML cleaning
functions of the HTML tidy library, either through the Perl module HTML::Tidy
or through the external C<tidy> program. The only currently supported
function is a conversion of the supplied HTML to xHTML

=head2 EXPORT

None. The interface is object oriented, in case options are allowed
to be reconfigured after import time.

=head2 CONSIDERATIONS

The HTML::Tidy module is quite unperlish, as it contains no pod
and no examples, and is not on CPAN, which make incorporating it
into other modules/programs a bit harder. 

It is also written in 
C++, so using that module will also require a working C++ 
compiler, something which is also not available everywhere Perl
is available. In fact, installing HTML::Tidy under Win32 was
easier than under Linux, where I gave up after the third set
of missing prerequisite libraries.

Tidylib also has some more prerequisites, like AutoConf, Automaker
and some C(++)? libraries, which make installing it even harder
resp. more tedious if you don't have a package system that
provides these as dependencies.

So, as long as you can get hold of a binary for the C<tidy> program,
it's easier to use that one.

=head1 LICENSE

This code may be distributed under the same terms as Perl itself.

=head1 AUTHOR

Max Maischein, corion@cpan.org

=head1 SEE ALSO

http://search.cpan.org/search?query=TidyXML&mode=module,L<Test::HTML::Lint>.

=cut
