#!/usr/bin/env perl
# hello.pl - Simple greeting utility in Perl
# RC Summary: Displays a customizable greeting message (Perl version)

use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;

# Default values
my $format = "Hello, NAME!";
my $uppercase = 0;
my $show_summary = 0;
my $show_version = 0;
my $show_help = 0;
my $name = "Friend";

# Parse command line options
GetOptions(
    "format=s"  => \$format,
    "uppercase|u" => \$uppercase,
    "summary"   => \$show_summary,
    "version"   => \$show_version,
    "help|h"    => \$show_help
) or pod2usage(1);

# Get name from positional argument if provided
$name = $ARGV[0] if @ARGV > 0;

# Handle special rc command flags
if ($show_help) {
    pod2usage(-verbose => 2);
    exit 0;
}

if ($show_summary) {
    print "Displays a customizable greeting message (Perl version)\n";
    exit 0;
}

if ($show_version) {
    print "hello - rcForge Utility v0.4.1\n";
    exit 0;
}

# Main functionality
my $greeting = $format;
$greeting =~ s/NAME/$name/g;

if ($uppercase) {
    $greeting = uc($greeting);
}

print "$greeting\n";
exit 0;

__END__

=head1 NAME

hello - Displays a customizable greeting message

=head1 SYNOPSIS

hello [options] [name]

=head1 OPTIONS

=over 8

=item B<--format>=FORMAT

Greeting format (default: "Hello, NAME!")

=item B<--uppercase>, B<-u>

Convert greeting to uppercase

=item B<--summary>

Show summary for rc help

=item B<--version>

Show version information

=item B<--help>, B<-h>

Show this help message

=back

=head1 DESCRIPTION

A simple utility that displays a greeting message with configurable name and format.

=head1 EXAMPLES

hello World               # Outputs: Hello, World!
hello --format="Hi, NAME" Mark  # Outputs: Hi, Mark
hello --uppercase Alice        # Outputs: HELLO, ALICE!

=cut
