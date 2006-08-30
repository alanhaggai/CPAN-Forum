package CPAN::Forum::RM::Search;
use strict;
use warnings;

# currently returning the number of results but this might change
sub _search_results {
    my ($self, $t, $params) = @_;
    
    $params->{per_page} = $self->config("per_page");

    my $pager   = CPAN::Forum::DB::Posts->mysearch($params);
    my @results = $pager->search_where();
    my $total   = $pager->total_entries;
    $self->log->debug("number of entries: total=$total");
    my $data = $self->build_listing(\@results);

    $t->param(messages       => $data);
    $t->param(total          => $total);
    $t->param(previous_page  => $pager->previous_page);
    $t->param(next_page      => $pager->next_page);
    $t->param(first_entry    => $pager->first);
    $t->param(last_entry     => $pager->last);
    $t->param(first_page     => 1)                      if $pager->current_page != 1;
    $t->param(last_page      => $pager->last_page)      if $pager->current_page != $pager->last_page;
    return $pager->total_entries;
}

sub module_search_form {
    my ($self, $errors) = @_;
    my $t = $self->load_tmpl("module_search_form.tmpl");
    $t->param($_=>1) foreach @$errors;
    $t->output;
}

sub module_search {
    my ($self) = @_;

    my $q = $self->query;
    my $txt = $q->param("q");
    $txt =~ s/^\s+|\s+$//g;

    # remove taint if there is
    if ($txt =~ /^([\w:.%-]+)$/) {
        $txt = $1;
    } else {
        $self->log->debug("Tained search: $txt");
    }

    if (not $txt) {
        return $self->module_search_form(['invalid_search_term']);
    }
    $self->log->debug("group name search term: $txt");
    $txt =~ s/::/-/g;
    $txt = '%' . $txt . '%';
    
    my $it =  CPAN::Forum::DB::Groups->search_like(name => $txt);
    my $cnt = CPAN::Forum::DB::Groups->sql_count_like("name", $txt)->select_val;
    my @group_names;
    my @group_ids;
    while (my $group  = $it->next) {
        push @group_names, $group->name;
        push @group_ids, $group->id;
    }
    if (not @group_names) {
        return $self->module_search_form(['no_module_found']);
    }
    
    #$self->log->debug("GROUP NAMES: @group_names");

    my $t = $self->load_tmpl("module_select_form.tmpl",
    );
    $t->param("group_selector" => $self->_group_selector(\@group_names, \@group_ids));
    $t->output;
}

sub search {
    my ($self) = @_;
    my $q      = $self->query;
    my $name   = $q->param("name")    || '';
    my $what   = $q->param("what")    || '';
    $name      =~ s/^\s+|\s+$//g;
    my $any_result = 0;

    # kill the taint checking (why do I use taint checking if I kill it then ?)
    if ($name =~ /(.*)/) { $name    = $1; }
    $name =~ s/::/-/g if $what eq "module";
    
    my $t = $self->load_tmpl("search.tmpl",
        associate => $q,
        loop_context_vars => 1,
    );
    my $it;

    if (not $what and not $name) {
        $what = $self->session->param('search_what');
        $name = $self->session->param('search_name');
    }

    $self->session->param(search_what => $what);
    $self->session->param(search_name => $name);

    if ($what and $name) {
        if ($what eq "module" or $what eq "pauseid") {
            my $it;
            if ($what eq "module") {
               $it =  CPAN::Forum::DB::Groups->search_like(name => '%' . $name . '%');
            } else {
                my ($author) = CPAN::Forum::DB::Authors->search(pauseid => uc $name);
                if ($author) {
                    $it =  CPAN::Forum::DB::Groups->search(pauseid => $author->id);
                } 
            }
            my @things;
            if ($it) {
                while (my $group  = $it->next) {
                    push @things, {name => $group->name};
                }
            }
            $any_result = 1 if @things;
            $t->param(groups => \@things);
            $t->param($what => 1);
        } elsif ($what eq "user") {
            my @things;
            my $it =  CPAN::Forum::DB::Users->search_like(username => '%' . lc($name) . '%');
            while (my $user  = $it->next) {
                push @things, {username => $user->username};
            }
            $any_result = 1 if @things;
            $t->param(users => \@things);
            $t->param($what => 1);
        } else {
            my %where;
            if ($what eq "subject") { %where = (subject => {'LIKE', '%' . $name . '%'}); }
            if ($what eq "text")    { %where = (text    => {'LIKE', '%' . $name . '%'}); }
            $self->log->debug("Search 1: " . join "|", %where);
            if (%where) {

                $self->log->debug("Search 2: " . join "|", %where);

                my $page = $q->param('page') || 1;
                $any_result = $self->_search_results($t, {where => \%where, page => $page});
                $t->param($what => 1);
            }
        }
        $t->param(no_results => not $any_result);
    }
    $t->output;
}

1;

