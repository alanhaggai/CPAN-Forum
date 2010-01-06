use strict;
use warnings;

use Test::Most;

plan skip_all => 'Need CPAN_FORUM_TEST_DB and CPAN_FORUM_TEST_USER and CPAN_FORUM_LOGFILE' 
	if not $ENV{CPAN_FORUM_TEST_DB} or not $ENV{CPAN_FORUM_TEST_USER} or not $ENV{CPAN_FORUM_LOGFILE};

my $tests;
plan tests => $tests;

bail_on_fail;

use t::lib::CPAN::Forum::Test;
my @users = @t::lib::CPAN::Forum::Test::users;
my $w = t::lib::CPAN::Forum::Test::get_mech();


{
    t::lib::CPAN::Forum::Test::setup_database();
    #ok(-e $ENV{CPAN_FORUM_DB_FILE});
}

{
    $w->get_ok($ENV{CPAN_FORUM_TEST_URL});
    $w->content_like(qr{CPAN Forum});

    $w->follow_link_ok({ text => 'register' });
    $w->content_like(qr{Registration Page}) or diag $w->content;
    BEGIN { $tests += 4; }
}

{
    $w->submit_form(
        fields => {
            nickname => '', 
            email    => 'some@email',
        },
    );
    $w->content_like(qr{Registration Page});
    $w->content_like(qr{Need both nickname and password});

    $w->submit_form(
        fields => {
            nickname => '', 
            email    => '',
        },
    );
    $w->content_like(qr{Registration Page});
    $w->content_like(qr{Need both nickname and password});

    $w->submit_form(
        fields => {
            nickname => 'xyz', 
            email    => '',
        },
    );
    $w->content_like(qr{Registration Page});
    $w->content_like(qr{Need both nickname and password});

    $w->submit_form(
        fields => {
            nickname => 'xyzqwertyuiqwertyuiopqwert', 
            email => 'a@com',
        },
    );
    $w->content_like(qr{Registration Page});
    $w->content_like(qr{Nickname must be lower case alphanumeric between 1-25 characters});
    BEGIN { $tests += 8; }
}

# reject bad usernames
foreach my $username ("ab.c", "Abcde", "asd'er", "ab cd") {
    $w->submit_form(
        fields => {
            nickname => $username, 
            email => 'a@com',
        },
    );
    $w->content_like(qr{Registration Page});
    $w->content_like(qr{Nickname must be lower case alphanumeric between 1-25 characters});
}
    BEGIN { $tests += 4*2; }

# reject bad email address 
foreach my $email ("adb-?", "Abcde", "asd'er", "ab cd") {
    $w->submit_form(
        fields => {
            nickname => "abcde", 
            email    => $email,
        },
    );
    $w->content_like(qr{Registration Page});
    $w->content_like(qr{Email must be a valid address writen in lower case letters});
}
    BEGIN { $tests += 4*2; }



# register user

# TODO: check if the call to submail contains the correct values
{
    @CPAN::Forum::messages = ();
    $w->submit_form(
        fields => {
            nickname => $users[0]{username}, 
            email    => $users[0]{email},
        },
    );
    $w->content_like(qr{Registration Page});
    $w->content_like(qr{Thank you for registering});
    #explain \@CPAN::Forum::messages;
    
    # TODO: disable these when testing with real web server
    is(scalar(@CPAN::Forum::messages), 2, 'two mails sent');
    my ($pw) = $CPAN::Forum::messages[0]{Message} =~ qr/your password is: (\w+)/;
    diag "Password: $pw";
    like($pw, qr{\w{5}}, 'password send');
    BEGIN { $tests += 4; }
}

# try to register the same user again and see it fails
{
    @CPAN::Forum::messages = ();
    $w->back;
    $w->submit_form(
        fields => {
            nickname => $users[0]{username}, 
            email    => $users[0]{email},
        },
    );
    $w->content_like(qr{Registration Page});
    $w->content_like(qr{Nickname or e-mail already in use});

    # TODO: disable these when testing with real web server
    is_deeply(\@CPAN::Forum::messages, [], 'no e-mails sent');
    BEGIN { $tests += 3; }
}

