package CPAN::Forum::DB::Posts;
use strict;
use warnings;
use Carp;
use base 'CPAN::Forum::DBI';
__PACKAGE__->table('posts');
__PACKAGE__->columns(All => qw/id gid uid parent subject text date thread hidden/);
__PACKAGE__->columns(Essential => qw/id gid uid parent subject text date thread hidden/);
__PACKAGE__->has_a(parent => "CPAN::Forum::DB::Posts");
__PACKAGE__->has_a(uid    => "CPAN::Forum::DB::Users");
__PACKAGE__->has_a(gid    => "CPAN::Forum::DB::Groups");

__PACKAGE__->set_sql(latest         => "SELECT __ESSENTIAL__ FROM __TABLE__ ORDER BY DATE DESC LIMIT %s");

__PACKAGE__->set_sql(count_where    => "SELECT count(*) FROM __TABLE__ WHERE %s='%s'");
__PACKAGE__->set_sql(count_like     => "SELECT count(*) FROM __TABLE__ WHERE %s LIKE '%s'");
my $MORE_SQL = 'groups.name group_name, users.fname user_fname, users.lname user_lname, users.username user_username';


sub get_post {
    my ($self, $post_id) = @_;
    return if not $post_id;
    #Carp::croak("No post_id given") if not $post_id;

    my $sql = "SELECT posts.id, gid, uid, parent, thread, hidden, subject, text, date,
                groups.name group_name, groups.pauseid, username, fname, lname
                FROM posts, groups, users
                WHERE posts.id=? AND posts.gid=groups.id AND users.id=posts.uid";
    return $self->_fetch_single_hashref($sql, $post_id);
}

sub posts_in_thread {
    my ($self, $thread) = @_;
    my $sql = "SELECT posts.id, gid, uid, parent, thread, hidden, subject, text, date,
                groups.name group_name, groups.pauseid, username, fname, lname
                FROM posts, groups, users
                WHERE posts.thread=? AND posts.gid=groups.id AND users.id=posts.uid";
    $self->_fetch_arrayref_of_hashes($sql, $thread);
}



sub _get_latest_pid_by_uid {
    my ($self, $uid) = @_;
    my $sql = "SELECT id, text, subject FROM posts WHERE uid=? ORDER BY date DESC LIMIT 1";
    return $self->_fetch_single_value($sql, $uid);
}

sub get_latest_post_by_uid {
    my ($self, $uid) = @_;
    Carp::croak("no uid provided") if not $uid;
    my $post_id = $self->_get_latest_pid_by_uid($uid);
    if ($post_id) {
        return $self->get_post($post_id);
    } else {
        return;
    }
}

sub retrieve_latest { 
    my ($self, $limit) = @_;

    $limit ||= 10;
    my $sql = "SELECT posts.id id, posts.subject, 
                $MORE_SQL
                FROM posts, groups, users
                WHERE posts.gid=groups.id AND posts.uid=users.id
                ORDER BY date DESC LIMIT ?";
    #$self->log->debug("SQL: $sql");

    return $self->_fetch_arrayref_of_hashes($sql, $limit);
}

sub search_post_by_groupname {
    my ($self, $groupname, $limit) = @_;

    return [] if not $groupname;
    $limit ||= 10;
    my $sql = qq{SELECT posts.id id, posts.subject,
                        $MORE_SQL
                        FROM posts, groups, users
                        WHERE groups.name=?
                            AND posts.gid=groups.id AND posts.uid=users.id
                        ORDER BY date DESC LIMIT ?};
    return $self->_fetch_arrayref_of_hashes($sql, $groupname, $limit);
}
sub search_post_by_pauseid {
    my ($self, $pauseid, $limit) = @_;

    return [] if not $pauseid;
    $limit ||= 10;
    my $sql = qq{SELECT posts.id id, posts.subject,
                        $MORE_SQL
                        FROM posts, groups, users
                        WHERE gid IN (
                            SELECT DISTINCT groups.id 
                            FROM groups, authors
                            WHERE groups.pauseid=authors.id and authors.pauseid=?)
                            AND posts.gid=groups.id AND posts.uid=users.id
                        ORDER BY date DESC LIMIT ?};
    return $self->_fetch_arrayref_of_hashes($sql, $pauseid, $limit);
}


sub search_latest_threads {
    my ($self, $limit) = @_;

    $limit ||= 10;
    my $sql = "SELECT A.id, A.thread, A.subject subject, A.date,
            $MORE_SQL
            FROM posts A, groups, users
            WHERE 
            thread IN (
                SELECT DISTINCT X.thread FROM posts X WHERE X.thread IN (
                    SELECT B.thread FROM posts B ORDER BY B.date DESC LIMIT ?)) 
            AND 
            A.id IN (SELECT max(id) FROM posts C WHERE C.thread=A.thread)
            AND A.gid=groups.id AND A.uid=users.id
            ORDER BY A.date DESC";

    return $self->_fetch_arrayref_of_hashes($sql, $limit);
}
sub mysearch {
    my ($self, $params) = @_;

    my %where  = %{$params->{where}};
    #%where = (1 => 1) if not %where;
    $CPAN::Forum::logger->debug(Data::Dumper->Dump([\%where], ['where']));

    my $pager = __PACKAGE__->mypager(
        where         => \%where,
        per_page      => $params->{per_page} || 10,
        page          => $params->{page}     || 1,
        order_by      => $params->{order_by} || "id DESC",
    );
}

sub list_counted_posts {
    my ($self) = @_;
    my $sql = "SELECT groups.name gname, COUNT(*) cnt
               FROM posts, groups
               WHERE posts.gid=groups.id
               GROUP BY gname
               ORDER BY cnt DESC";
    return $self->_fetch_arrayref_of_hashes($sql);
}

# returns the number of entries in a single thread
sub count_thread {
    my ($self, $thread_id) = @_;
    my $sql = "SELECT count(*) FROM posts WHERE thread=?";
    return $self->_fetch_single_value($sql, $thread_id);
}

# returns a hashref where the keys are the given thread ids
# the values are the number of entries in the given thread
sub count_threads {
    my ($self, @thread_ids) = @_;
    return {} if not @thread_ids;
    # TODO check if they are all numbers?

    $CPAN::Forum::logger->debug(Data::Dumper->Dump([\@thread_ids], ['thread_ids']));
    my $ids = join ",", @thread_ids;
    my $sql = "SELECT thread, COUNT(*) cnt FROM posts WHERE thread in ($ids) GROUP BY thread";
    return $self->_selectall_hashref($sql, 'thread');
}

sub stat_posts_by_group {
    my ($self, $limit) = @_;
    my $sql = qq{
            SELECT COUNT(*) cnt, groups.name gname
            FROM posts,groups 
            WHERE posts.gid=groups.id
            GROUP BY gname
            ORDER BY cnt DESC
            LIMIT ?
            };
    return $self->_fetch_arrayref_of_hashes($sql, $limit);
}

sub stat_posts_by_user {
    my ($self, $limit) = @_;
    my $sql = qq{
            SELECT COUNT(*) cnt, users.username username 
            FROM posts,users
            WHERE posts.uid=users.id
            GROUP BY username
            ORDER BY cnt DESC
            LIMIT ?
            };
    return $self->_fetch_arrayref_of_hashes($sql, $limit);
}

sub list_posts_by {
    my ($self, $field, $value) = @_;
    Carp::croak("Invalid field '$field'") if $field ne 'parent';
    my $sql = "SELECT id FROM posts WHERE $field=?";
    return $self->_fetch_arrayref_of_hashes($sql, $value);
};

sub add_post {
    my ($self, $data, $parent_post, $parent) = @_;
    $self->add('posts', $data);
    my $dbh = CPAN::Forum::DBI::db_Main();
    my $post_id = $dbh->func('last_insert_rowid');

    my $sql = "UPDATE posts SET thread=?";
    my @values = (
            ($parent_post ? $parent_post->{thread} : $post_id),
    );
    if ($parent_post) {
        $sql .= ", parent=?";
        push @values, $parent;
    }
    $sql .= " WHERE id=?";
    push @values, $post_id;
    $dbh->do($sql, undef, @values);
    return $post_id;
}

sub list_uids_who_posted_in_thread {
    my ($self, $thread) = @_;
    my $sql = "SELECT DISTINCT uid FROM posts WHERE thread=?";
    return $self->_select_column($sql, $thread);
}


1;
 
