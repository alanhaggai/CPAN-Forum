package t::lib::CPAN::Forum::Test;
use strict;
use warnings;

use Cwd            qw(abs_path cwd);
use File::Basename qw(dirname);
use File::Copy     qw(copy);
use File::Path     qw(mkpath);
use File::Temp     qw(tempdir);


my $ROOT = dirname(dirname(dirname(dirname(dirname(abs_path(__FILE__))))));

our @users = (
    {
        username => 'abcder',
        email    => 't@cpanforum.com',
    },
);

sub setup_database {
    my $dbdir = dirname($ENV{CPAN_FORUM_DB_FILE});
    mkpath($dbdir);

    system "$^X bin/setup.pl    --config t/CONFIG                 --dbfile $ENV{CPAN_FORUM_DB_FILE}";
    system "$^X bin/populate.pl --source t/02packages.details.txt --dbfile $ENV{CPAN_FORUM_DB_FILE}";



    return;
}

sub init_db {
    require CPAN::Forum::DBI;
    CPAN::Forum::DBI->myinit(db_connect());
}

sub db_connect {
    return "dbi:SQLite:$ENV{CPAN_FORUM_DB_FILE}";
}


sub register_user {
    my ($id) = @_;

    init_db();
    require CPAN::Forum::DB::Users;
    my $user = CPAN::Forum::DB::Users->add_user($users[$id]);
    return $user;
}

sub register_users {
    my ($id, $n) = @_;

    init_db();
    require CPAN::Forum::DB::Users;
    my @users;
    foreach my $i (1..$n) {
        my %user;
        $user{$_} = $i . $users[$id]{$_} foreach qw(username email);
        push @users, CPAN::Forum::DB::Users->add_user(\%user);
    }
    return @users;
}

sub get_mech {
    # TODO Enable using an environment variable?
    #require Test::WWW::Mechanize;
    #Test::WWW::Mechanize->new;
    
    require Test::WWW::Mechanize::CGI;
    # for some reason the environemnt variable is not visible inside the cgi request
    # so we use a temporary variable here
    my $db_file = $ENV{CPAN_FORUM_DB_FILE};

    my $w = Test::WWW::Mechanize::CGI->new;
    $w->cgi(sub {
        require CPAN::Forum;
        $ENV{CPAN_FORUM_LOGFILE} = "/tmp/message.log";
        my $webapp = CPAN::Forum->new(
                TMPL_PATH => "templates",
                PARAMS => {
                    ROOT       => $ROOT,
                    DB_CONNECT => "dbi:SQLite:$db_file",

                },
            );
        $webapp->run();
        }); 
    return $w;
};

sub CPAN::Forum::_test_my_sendmail {
    my %mail = @_;
    my @fields = qw(Message From Subject To);
    my %m;
    @m{@fields} = @mail{@fields};
    push @CPAN::Forum::messages, \%m;
    return;
}

1;

