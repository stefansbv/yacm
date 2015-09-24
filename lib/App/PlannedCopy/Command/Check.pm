package App::PlannedCopy::Command::Check;

# ABSTRACT: Compare the repository files with the installed versions

use 5.010001;
use utf8;
use Try::Tiny;
use MooseX::App::Command;
use namespace::autoclean;

extends qw(App::PlannedCopy);

with qw(App::PlannedCopy::Role::Printable
        App::PlannedCopy::Role::Utils);

use App::PlannedCopy::Resource;

command_long_description q[Compare the repository files with the installed versions for the selected <project>.];

parameter 'project' => (
    is            => 'rw',
    isa           => 'Str',
    required      => 1,
    documentation => q[Project name.],
);

sub execute {
    my ( $self ) = @_;

    my $file = $self->config->resource_file( $self->project );
    my $res  = App::PlannedCopy::Resource->new( resource_file => $file);
    my $iter = $res->resource_iter;

    say 'Job: ', $res->count, ' file', ( $res->count != 1 ? 's' : '' ),
        ' to check', ( $self->verbose ? ' (verbose)' : '' ), ':', "\n";

    $self->no_resource_message($self->project) if $res->count == 0;

    while ( $iter->has_next ) {
        $self->set_error_level('info');
        my $rec  = $iter->next;
        my $cont = try { $self->validate_element($rec) }
        catch {
            my $e = $self->handle_exception($_);
            $self->item_printer($rec);
            $self->exception_printer($e) if $e;
            $self->inc_count_skip;
            return undef;       # required
        };
        if ($cont) {
            try {
                $self->check($rec);
                $self->item_printer($rec);
            }
            catch {
                my $e = $self->handle_exception($_);
                $self->exception_printer($e) if $e;
                $self->inc_count_skip;
            };
        }
        $self->inc_count_proc;
    }

    $self->print_summary;

    return;
}

sub check {
    my ($self, $rec) = @_;
    my $src_path = $rec->src->_abs_path;
    my $dst_path = $rec->dst->_abs_path;
    if ( $self->is_selfsame( $src_path, $dst_path ) ) {
        $self->set_error_level('info');
    }
    else {
        $self->inc_count_resu;
        $self->set_error_level('warn');
    }
    $self->inc_count_inst;
    return;
}

sub print_summary {
    my $self = shift;
    my $cnt_proc = $self->count_proc // 0;
    say '';
    say 'Summary:';
    say ' - processed: ', $cnt_proc, ' records';
    say ' - checked  : ', $self->count_inst;
    say ' - skipped  : ', $self->count_skip;
    say ' - different: ', $self->count_resu;
    say '';
    return;
}

__PACKAGE__->meta->make_immutable;

1;
