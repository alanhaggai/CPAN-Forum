#!/usr/bin/perl

use strict;
use warnings;

use lib "lib";
use Parse::CPAN::Packages;
use LWP::Simple;
use FindBin qw ($Bin);
use Text::CSV_XS;
use Mail::Sendmail qw(sendmail);
use Getopt::Long qw(GetOptions);

use CPAN::Forum::DBI;
use CPAN::Forum::Groups;



my %opts;

GetOptions(\%opts, "sendmail", "source=s", "dir=s", "fetch", "help") 
    or usage();
usage() if $opts{help};
usage() if not $opts{dir};

sub usage {
    print <<"END_USAGE";
$0
    --sendmail      to send report to Gabor
    --source FILE   path to the 02packages.details.txt
    --dir DIR       directory of the database
    --fetch
    --help          this help
END_USAGE
    exit;
}


my $dbfile       = "$opts{dir}/forum.db";
CPAN::Forum::DBI->myinit("dbi:SQLite:$dbfile");


my $csv          = Text::CSV_XS->new();

print "This operation can take a couple of minutes\n";



if (not $opts{source}) {
    my $file = "02packages.details.txt";
    $opts{source} = "$opts{dir}/$file";
}

if ($opts{fetch}) {
    unlink $opts{source} if -e $opts{source};
    # must have downloaded and un-gzip-ed
    # ~/mirror/cpan/modules/02packages.details.txt.gz 
    print "Fecthing  $opts{source} from CPAN\n";
    getstore("http://www.cpan.org/modules/02packages.details.txt.gz", "$opts{source}.gz");
    print "Unzipping $opts{source}\n";
    system("gunzip $opts{source}.gz");
}

print "Processing $opts{source} file, adding distros to database, will take a few minutes\n";
print "Go get a beer\n";
my $p = Parse::CPAN::Packages->new($opts{source});
;

my %message = (
    version => "",
    pauseid => "",
    new     => "",
);

LINE:
my $cnt;
foreach my $d ($p->latest_distributions) {
    $cnt++;

    # skip scripts
    if (not $d->prefix or $d->prefix =~ m{^\w/\w\w/\w+/scripts/}) {
        warn "no prefix line $cnt\n";
        next LINE;
    }

    my $name        = $d->dist;
    if (not $name) {
        warn "No name: line: $cnt prefix:" . $d->prefix . "\n";
        next LINE;
    }
    
    # for now skip names that start with lower case
    #next LINE if $name =~ /^[a-z]/;

    my %new = (
        version => ($d->version() || ""),
    );


    my $pauseid = ($d->cpanid()  || "");
    my $p;
    if ($pauseid) {
        eval {
            $p = CPAN::Forum::Authors->find_or_create({ pauseid => $pauseid });
        };
        if ($@) {
            warn "$name\n";
            warn $@;
            next LINE;
        }
    }
    if (not $p) {
        warn "No PAUSEID?" . $d->prefix . "\n";
        next LINE;
    }
    $new{pauseid} = $p->id;


    my ($g) = CPAN::Forum::Groups->search(name => $name);
    if ($g) {
        my $changed;
        foreach my $field (qw(version pauseid)) {
            #print "$name\n";
            #print "NEW: $new{$field}\n";
            #print "OLD: " . $g->$field, "\n";
            #<STDIN>;
            if (not defined $g->$field or $g->$field ne $new{$field}) {
                #print "change\n";
                $message{$field} .= sprintf "The %s of %s has changed from %s to %s\n",
                                $field, $name, ($g->$field || ""), $new{$field};
                $g->$field($new{$field});
                $changed++;
            }
        }

        if ($changed) {
            $g->update;
        }
        next LINE;
    }

    $message{new} .= sprintf "Creating %s   %s\n", $name, $new{version}, $pauseid;

    eval {
        my $g = CPAN::Forum::Groups->create({
            name    => $name,
            gtype   => $CPAN::Forum::DBI::group_types{Distribution}, 
            version => $new{version},
            pauseid => $new{pauseid},
        });
    };
    if ($@) {
        warn "$name\n";
        warn $@;
    }
}


#open my $out, ">", $version_file or die "Could not open '$version_file' for writing $!\n";
#foreach my $name (sort keys %version) {
#   print $out qq("$name","$version{$name}"\n);
#}

my %mail = (
    To       => 'gabor@pti.co.il',
    From     => 'cpanforum@cpanforum.com',
    Subject  => 'CPAN Version Update',
    Message  => $message{version},
);
if ($opts{sendmail}) {
    sendmail(%mail);
} else {
    open my $fh, ">", "$Bin/../cpan_version_update";
    print $fh $message{version};
}

%mail = (
    To       => 'gabor@pti.co.il',
    From     => 'cpanforum@cpanforum.com',
    Subject  => 'New CPAN Distros',
    Message  => $message{new},
);
if ($opts{sendmail}) {
    sendmail(%mail);
} else {
    open my $fh, ">", "$Bin/../cpan_new_distros";
    print $fh $message{new};
}



