package App::PlannedCopy::Command::List;

# ABSTRACT: Print a list of the projects in the repository

use 5.010001;
use utf8;
use MooseX::App::Command;
use App::PlannedCopy::Ls;
use Try::Tiny;
use namespace::autoclean;

extends qw(App::PlannedCopy);

with qw(App::PlannedCopy::Role::Utils
        App::PlannedCopy::Role::Printable);

parameter 'project' => (
    is            => 'rw',
    isa           => 'Str',
    required      => 0,
    documentation => q[Project name.],
);

sub execute {
    my ( $self ) = @_;

    if ( my $project = $self->project ) {
        say "Job: list files in '$project':\n";
        my @items;
        try {
            @items = map { $_->{path} } @{ $self->get_files($project) };
        }
        catch {
            if ( my $e = Exception::Base->catch($_) ) {
                if ( $e->isa('Exception::IO') ) {
                    say "[EE] ", $e->message, ' : ', $e->pathname;
                }
                else {
                    say "[EE] Unknown exception: $_";
                }
            }
        };
        return unless scalar @items;
        my $list  = App::PlannedCopy::Ls->new( items => \@items );
        $list->column_printer;
        return;
    }
    else {
        say "Job: list projects:\n";
        $self->project_list_printer( @{ $self->get_projects } );
    }

    $self->print_summary;

    return;
}

sub print_summary {
    my $self = shift;
    say '';
    say 'Summary:';
    say ' - directories: ', $self->count_proc;
    say ' - projects   : ', $self->count_inst;
    say '';
    return;
}

__PACKAGE__->meta->make_immutable;

1;

=head2 get_projects

Returns an array reference of the names of the subdirectories of
L<repo_path> that contains a resource file (L<resource.yml>).

=cut
