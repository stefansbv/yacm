package App::PlannedCopy::Command::Resu;

# ABSTRACT: Create/update a resource file

use 5.010001;
use utf8;
use Try::Tiny;
use Path::Tiny;
use Path::Iterator::Rule;
use List::Compare;
use MooseX::App::Command;
use Moose::Util::TypeConstraints;
use namespace::autoclean;

extends qw(App::PlannedCopy);

with qw(App::PlannedCopy::Role::Utils
        App::PlannedCopy::Role::Printable);

use App::PlannedCopy::Resource::Read;
use App::PlannedCopy::Resource::Write;

command_long_description q[Create/update a resource file for the <project>.];

parameter 'project' => (
    is            => 'rw',
    isa           => 'Str',
    required      => 1,
    documentation => q[Project name.],
);

has 'resource_file' => (
    is      => 'ro',
    isa     => 'Str',
    lazy    => 1,
    default => sub {
        my $self = shift;
        return $self->config->resource_file( $self->project );
    },
);

has 'resource_old' => (
    is      => 'rw',
    isa     => 'HashRef',
    traits  => ['Hash'],
    lazy    => 1,
    builder => '_build_old_resource',
    handles => {
        get_old_res    => 'get',
        has_no_old_res => 'is_empty',
        num_old_res    => 'count',
        old_res_keys   => 'keys',
        old_res_pairs  => 'kv',
    },
);

has 'resource_fs' => (
    is      => 'rw',
    isa     => 'HashRef',
    traits  => ['Hash'],
    lazy    => 1,
    builder => '_build_fs_resource',
    handles => {
        get_fs_res    => 'get',
        has_no_fs_res => 'is_empty',
        num_fs_res    => 'count',
        fs_res_keys   => 'keys',
        fs_res_pairs  => 'kv',
    },
);

has '_compare' => (
    is      => 'rw',
    isa     => 'HashRef',
    traits  => ['Hash'],
    lazy    => 1,
    builder => '_build_compare',
    handles => {
        get_compare => 'get',
    },
);

has '_kept' => (
    is      => 'rw',
    isa     => 'ArrayRef',
    traits  => ['Array'],
    lazy    => 1,
    default => sub {
        my $self = shift;
        return $self->get_compare('upd');
    },
    handles => {
        get_kept   => 'elements',
        count_kept => 'count',
    },
);

has '_removed' => (
    is      => 'rw',
    isa     => 'ArrayRef',
    traits  => ['Array'],
    lazy    => 1,
    default => sub {
        my $self = shift;
        return $self->get_compare('del');
    },
    handles => {
        get_removed   => 'elements',
        count_removed => 'count',
    },
);

has '_added' => (
    is      => 'rw',
    isa     => 'ArrayRef',
    traits  => ['Array'],
    lazy    => 1,
    default => sub {
        my $self = shift;
        return $self->get_compare('add');
    },
    handles => {
        get_added   => 'elements',
        count_added => 'count',
    },
);

sub _build_old_resource {
    my $self = shift;
    my $reader = App::PlannedCopy::Resource::Read->new(
        resource_file => $self->resource_file );
    my %items;
    foreach my $res ( @{ $reader->contents } ) {
        my $name
            = path( $res->{source}{path}, $res->{source}{name} )->stringify;
        $items{$name} = $res;
    }
    return \%items;
}

sub _build_fs_resource {
    my $self = shift;
    my $proj = $self->project;
    my %items;
    foreach my $rec ( @{ $self->get_files( $self->project ) } ) {
        my $file = $rec->{name};
        my $path = $rec->{path};
        my $name = path($path, $file)->stringify;
        $items{$name} = {
            source => {
                name => $file,
                path => $path,
            },
            destination => {
                name => $file,
                path => undef,
                perm => '0644',
            }
        };
    }
    return \%items;
}

sub _build_compare {
    my $self = shift;
    my @old = $self->old_res_keys;
    my @fs  = $self->fs_res_keys;
    my $dc  = List::Compare->new( \@old, \@fs );
    my @upd = $dc->get_intersection;
    my @del = $dc->get_unique;
    my @add = $dc->get_complement;
    my %comp;
    $comp{upd} = \@upd;
    $comp{del} = \@del;
    $comp{add} = \@add;
    return \%comp;
}

sub execute {
    my ( $self ) = @_;

    my $proj = $self->project;
    say "Job: add/update the resource file for '$proj':\n";

    my @del = $self->get_removed;
    my @upd = $self->get_kept;
    my @add = $self->get_added;

    unless ( $self->dryrun ) {
        my @res_data;
        foreach my $name (@upd) {
            my $data = $self->get_old_res($name);
            push @res_data, $data;
        }
        foreach my $name (@add) {
            my $data = $self->get_fs_res($name);
            push @res_data, $data;
        }
        $self->write_resource( \@res_data );
    }

    $self->list_printer( 'removed', @del );
    $self->list_printer( 'kept',    @upd );
    $self->list_printer( 'added',   @add );

    $self->print_summary;
    $self->note
        if $self->count_added > 0
        and not $self->is_error_level('error');

    return;
}

sub print_summary {
    my $self = shift;
    say '';
    say 'Summary:';
    say ' - removed: ', $self->dryrun ? '0 (dry-run)' : $self->count_removed;
    say ' - kept   : ', $self->count_kept;
    say ' - added  : ', $self->dryrun ? '0 (dry-run)' : $self->count_added;
    say '';
    return;
}

sub note {
    my $self = shift;
    my $resource = $self->resource_file;
    say "---";
    say " Remember to EDIT the destination paths\n  in '$resource'.";
    say "---";
}

sub write_resource {
    my ($self, $data) = @_;
    my $rw = App::PlannedCopy::Resource::Write->new(
        resource_file => $self->resource_file );
    try   { $rw->create_yaml( { resources => $data } ) }
    catch {
        if ( my $e = Exception::Base->catch($_) ) {
            $self->set_error_level('error');
            if ( $e->isa('Exception::IO') ) {
                say "[EE] ", $e->message, ' (', $e->pathname, ').';
            }
            elsif ( $e->isa('Exception::Config::YAML') ) {
                say "[EE] ", $e->usermsg, ' ', $e->logmsg;
            }
            else {
                say "[EE] Unknown exception: $_";
            }
        }
    };
    return;
}

sub get_files {
    my ($self, $dir) = @_;
    die "The 'dir' parameter is required for 'get_files'\n" unless $dir;
    my $abs_dir = path( $self->config->repo_path, $dir );
    my $rule    = Path::Iterator::Rule->new;
    $rule->skip(
        $rule->new->file->empty,
        $rule->new->file->name('resource.yml'),
    );
    my $next = $rule->iter( $abs_dir,
        { relative => 0, sorted => 1, follow_symlinks => 0 } );
    my @files;
    while ( defined( my $item = $next->() ) ) {
        my $item = path $item;
        next if $item->is_dir;
        my $name = $item->basename;
        my $path = $item->parent->relative( $abs_dir->parent )->stringify;
        push @files, { name => $name, path => $path };
    }
    return \@files;
}

__PACKAGE__->meta->make_immutable;

1;
