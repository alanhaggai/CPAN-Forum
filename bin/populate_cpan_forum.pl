#!/usr/bin/perl

use strict;
use warnings;

use File::Basename qw(dirname);
use Getopt::Long qw(GetOptions);
use Cwd qw(abs_path);

BEGIN {
	unshift @INC, dirname( dirname( abs_path($0) ) ) . '/lib';
}
use CPAN::Forum::Populate;

usage() if not @ARGV;
my %opt;
GetOptions(
	\%opt,
	'help',
	'dir=s',
	'mirror=s',
	'process=s',
	'html',
	'yaml',
	'ppi',
	'localcpan=s',
	'cpan=s',
) or usage();
usage() if $opt{help};


my $p = CPAN::Forum::Populate->new( \%opt );
$p->run;


sub usage {
	print <<"END_USAGE";
Usage: $0
      --dir  PATH                         # root directory (defaults to ~/.cpanforum)

      --mirror [cpan|mini|path/to/file]   # cpan mirror
			                  # cpan = full (6.5 Gb)
			                  # mini = using Mini::CPAN (1.4 Gb)
                                          # list of Package::Names per line to mirror
   
      --process [all|new|path/to/file]    # which packages to process (need other flags to tell what to do)
                                          # all = rebuilding information about every package
                                          # new = only those that were added recently
                                          # list of Package::Names per line

      --html               # the --process will build the HTML files
      --yaml               # the --process will update the database with mete data (yaml file and others)
      --ppi                # the --process will use PPI to deep analyse the packages
      --cpan      URL      # URL of the CPAN server to mirror from
      --localcpan PATH     # path to the local CPAN mirror (or where it should be)


      --help         this help

END_USAGE
	exit 0;
}
