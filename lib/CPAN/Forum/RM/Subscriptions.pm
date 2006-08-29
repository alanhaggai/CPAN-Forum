package CPAN::Forum::RM::Subscriptions;
use strict;
use warnings;

=head2 mypan

Manage the notify subscription.

Creates checkboxes, the names of the checkboxes start with
the subscription mode:

  allposts_   - every post
  starters_   - every time a new thread is started
  followups_  - every time there is a post where the user has already posted

The names are the followed wit one of the following:

  _all      - all the modules
  _NNN      - Where NNN is the id number of an author
  NNN       - where NNN is the id number of a group (distribution) 

The gids field contains the comma separated list of all the postfixes.

(Yes the difference between the two types of id is the extra _ only.)

C<update_subscription> will process the submitted form.

=cut

sub mypan {
    my $self = shift;

    my $t = $self->load_tmpl("mypan.tmpl",
        loop_context_vars => 1,
    );
    my $username = $self->session->param("username");
    my ($user) = CPAN::Forum::Users->search(username => $username);

    if (not $user) {
        return $self->internal_error(
            "Trouble accessing personal information of: '$username' $ENV{PATH_INFO}",
            );
    }
    my $fullname = "";
    $fullname .= $user->fname if $user->fname;
    $fullname .= " " if $fullname;
    $fullname .= $user->lname if $user->lname;

    $t->param(fullname => $fullname);
    $t->param(title    => "Information about $username");

    my @params = @{$self->param("path_parameters")};
    my @subscriptions;
    my $gids;


    if (@params == 2 and $params[0] eq "dist") { # specific distribution
        my $group = $params[1];
        my ($grp) = CPAN::Forum::Groups->search(name => $group);
        if (not $grp) {
            return $self->internal_error(
                "Accessing $ENV{PATH_INFO}\n",
            );
        }
        $gids = $grp->id;
        my ($s) = CPAN::Forum::Subscriptions->search(uid => $user->id, gid => $grp->id);
        if ($s) {
            push @subscriptions, {
                gid       => $grp->id,
                group     => $group,
                allposts  => $s->allposts,
                starters  => $s->starters,
                followups => $s->followups,
            };
                
        } else {
            push @subscriptions, {
                gid       => $grp->id,
                group     => $group,
                allposts  => 0,
                starters  => 0,
                followups => 0,
            };
        }
    } else { # show all subscriptions
        my ($s) = CPAN::Forum::Subscriptions_all->search(uid => $user->id);
        $self->log->debug("all subscriptions " . ($s ? "found" : "not found"));
        push @subscriptions, {
            gid       => "_all",
            group     => "All",
            allposts  => $s ? $s->allposts  : '',
            starters  => $s ? $s->starters  : '',
            followups => $s ? $s->followups : '',
        };
        $gids = "_all";

        my $it = CPAN::Forum::Subscriptions_pauseid->search(uid => $user->id);
        while (my $s = $it->next) {
            $gids .= ($gids ? ",_" : "_") . $s->pauseid->id; 
            push @subscriptions, {
                gid       => "_" . $s->pauseid->id,
                group     => $s->pauseid->pauseid,
                allposts  => $s->allposts,
                starters  => $s->starters,
                followups => $s->followups,
            };
        }

        $it = CPAN::Forum::Subscriptions->search(uid => $user->id);
        while (my $s = $it->next) {
            $gids .= ($gids ? "," : "") . $s->gid->id; 
            push @subscriptions, {
                gid       => $s->gid,
                group     => $s->gid->name,
                allposts  => $s->allposts,
                starters  => $s->starters,
                followups => $s->followups,
            };
        }
    }

    $t->param(subscriptions => \@subscriptions);
    $t->param(gids => $gids);

    $t->output;
}

=head2 update_subscription

Process the submitted form created by C<mypan()>

=cut
sub update_subscription {
    my $self = shift;
    my $q = $self->query;
    
    my @gids = split /,/, $q->param("gids");
    if (not @gids) {
        return $self->internal_error();
    }

    my $username = $self->session->param("username");
    my ($user) = CPAN::Forum::Users->search(username => $username);

    foreach my $gid (@gids) {
        if ($gid eq "_all") {
            my ($s) = CPAN::Forum::Subscriptions_all->search(uid => $user->id);
            if (not $s) {
                $s = CPAN::Forum::Subscriptions_all->create({
                    uid       => $user->id,
                });
            }
            $self->_update_subs($s, $gid);
        } elsif ($gid =~ /^_(\d+)$/) {
            my $pauseid = $1;
            my ($s) = CPAN::Forum::Subscriptions_pauseid->search(pauseid => $pauseid, uid => $user->id);
            if (not $s) {
                $s = CPAN::Forum::Subscriptions->create({
                    uid       => $user->id,
                    pauseid   => $pauseid,
                });
            }
            $self->_update_subs($s, $gid);
        } elsif ($gid =~ /^(\d+)$/) {
            my ($s) = CPAN::Forum::Subscriptions->search(gid => $gid, uid => $user->id);
            if (not $s) {
                $s = CPAN::Forum::Subscriptions->create({
                    uid       => $user->id,
                    gid       => $gid,
                });
            }
            $self->_update_subs($s, $gid);
        } else {
            $self->log->error("Invalid gid: '$gid' provided in the gids entry of mypan");
            # shall we show an error page here?
        }
    }
    
    # if there is not name, no need for further processing
    if (not $q->param("name")) {
        return $self->notes("mypanok");
    }

    # TODO: error messages in case not all the values were filled in correctly
    # process new entry
    if (not $q->param("type")) {
        return $self->note("no_subs_type");
    }

    # TODO: if there is a subscription to the given distro or PAUSEID
    # we should not let the user overwrite it using the new entry box
    if ($q->param("type") eq "pauseid") {
        my $pauseid = uc $q->param("name");
        my ($author) = CPAN::Forum::Authors->search(pauseid => $pauseid);
        if ($author) {
            my $s = CPAN::Forum::Subscriptions_pauseid->find_or_create({
                uid       => $user->id,
                pauseid   => $author->id,
            });
            $self->_update_subs($s, "_new");
        } else {
            return $self->notes("no_such_pauseid");
        }
    }
    elsif ($q->param("type") eq "distro") {
        my $name = $q->param("name");
        $name =~ s/::/-/g;  
        my ($grp) = CPAN::Forum::Groups->search(name => $name);
        if ($grp) {
            my $s = CPAN::Forum::Subscriptions->find_or_create({
                uid       => $user->id,
                gid       => $grp->id,
            });
            $self->_update_subs($s, "_new");
        } else {
            return $self->notes("no_such_group");
        }
    }
    else {
        return $self->internal_error("", "invalid_subs_type");
    }

    return $self->notes("mypanok");
}

=head2 _update_subs

Given a subscription obkect (1 out of 3 possible classes)
and a gid (_all, _NNN or NNN) fetches the relevan checkboxes 
(See C<mypan()> for details) and update the subscription object.

=cut
sub _update_subs {
    my ($self, $s, $gid) = @_;
    my $q = $self->query;

    my $on = 0;
    foreach my $type (qw(allposts starters followups)) {
        if (defined $q->param($type ."_$gid") and $q->param($type . "_$gid") eq "on") {
            $s->set($type, 1);
            $on++;
        } else {
            $s->set($type, 0);
        }
    }
    if ($on) {
        return $s->update;
    }
    else {
        return $s->delete;   # remove the whole line if there are no subscriptions at all.
    }
}

1;

