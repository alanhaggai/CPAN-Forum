package CPAN::Forum::DB::Groups;
use strict;
use warnings;
use Carp;
use base 'CPAN::Forum::DBI';
__PACKAGE__->table('groups');
__PACKAGE__->columns(Primary   => qw/id/);
__PACKAGE__->columns(Essential => qw/id name version pauseid/);
__PACKAGE__->columns(Others    => qw/gtype status rating review_count/);

__PACKAGE__->has_many(posts         => "CPAN::Forum::DB::Posts");
__PACKAGE__->has_many(subscriptions => "CPAN::Forum::DB::Subscriptions");
__PACKAGE__->has_a   (pauseid       => "CPAN::Forum::DB::Authors");

__PACKAGE__->set_sql(count_like     => "SELECT count(*) FROM __TABLE__ WHERE %s LIKE '%s'");
__PACKAGE__->set_sql(count          => "SELECT count(*) FROM __TABLE__ WHERE %s = '%s'");
#use Data::Dumper;
#__PACKAGE__->add_trigger(before_update => sub {warn Dumper $_[0]});

sub info_by {
    my ($self, $field, $value) = @_;
    Carp::croak("Invalid field '$field'") if $field ne 'id' and $field ne 'name';

    my $sql = "SELECT id, name, status
               FROM groups
               WHERE $field=?";
    return $self->_fetch_single_hashref($sql, $value);
}

sub dump_groups {
    my ($self) = @_;
    my $sql = "SELECT id, name FROM groups";
    return $self->_dump($sql); 
}

sub groups_by_gtype {
    my ($self, $value) = @_;
    #return {} if not %args; # ?
    my $sql = "SELECT id, name FROM groups WHERE gtype=?";
    return $self->_fetch_hashref($sql, $value);
}
sub groups_by_name {
    my ($self, $value) = @_;
    #return {} if not %args; # ?
    $value = '%' . $value . '%';
    my $sql = "SELECT id, name FROM groups WHERE name LIKE ?";
    return $self->_fetch_hashref($sql, $value);
}


1;

