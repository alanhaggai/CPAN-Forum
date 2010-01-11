package CPAN::Forum::RM::Other;
use strict;
use warnings;


=head2 about

About box with some statistics.

=cut

sub about {
	my $self = shift;
	my $t    = $self->load_tmpl("about.tmpl");

	$t->param( distro_cnt       => CPAN::Forum::DBI->count_rows_in('groups') );
	$t->param( posts_cnt        => CPAN::Forum::DBI->count_rows_in('posts') );
	$t->param( users_cnt        => CPAN::Forum::DBI->count_rows_in('users') );
	$t->param( subscription_cnt => CPAN::Forum::DBI->count_rows_in('subscriptions') );
	$t->param( tag_cloud_cnt    => CPAN::Forum::DBI->count_rows_in('tag_cloud') );
	$t->param( version          => $self->version );

	# number of posts per group name, can create some xml feed from it that can
	# be used by search.cpan.org and Kobes to add a number of posts next to the link
	#select count(*),groups.name from posts, groups where groups.id=gid group by gid;
	#
	#count posts for a specific group:
	#select count(*) from posts, groups where groups.id=gid and groups.name="CPAN-Forum";

	$t->output;
}

=head2 stats

The stats run-mode showing some statistics
(actually the 50 busiest groups)

=cut

sub stats {
	my $self        = shift;
	my $t           = $self->load_tmpl("stats.tmpl");
	my $modules_cnt = 50;
	my $groups      = CPAN::Forum::DB::Posts->stat_posts_by_group($modules_cnt);
	$t->param( modules_cnt => $modules_cnt );
	$t->param( groups      => $groups );

	my $users_cnt = 50;
	my $top_users = CPAN::Forum::DB::Posts->stat_posts_by_user($users_cnt);
	$t->param( users_cnt => $users_cnt );
	$t->param( users     => $top_users );

	my $tagging_users_cnt = 20;
	my $top_tagging_users = CPAN::Forum::DB::Tags->stat_tags_by_user($tagging_users_cnt);
	$t->param( tagging_users_cnt => $tagging_users_cnt );
	$t->param( tagging_users     => $top_tagging_users );

	$t->output;
}

=head2 faq

Show FAQ

=cut

sub faq {
	my $self = shift;
	my $t    = $self->load_tmpl("faq.tmpl");
	$t->output;
}

1;

