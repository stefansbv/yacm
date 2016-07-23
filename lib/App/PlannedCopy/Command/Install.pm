package App::PlannedCopy::Command::Install;

# ABSTRACT: Install the project items (files)

use 5.010001;
use utf8;
use Path::Tiny;
use Try::Tiny;
use Archive::Any::Lite;
use MooseX::App::Command;
use namespace::autoclean;

extends qw(App::PlannedCopy);

with qw(App::PlannedCopy::Role::Printable
        App::PlannedCopy::Role::Utils
        App::PlannedCopy::Role::Validate::Install
       );

use App::PlannedCopy::Resource;

command_long_description q[Install the configuration files of the selected <project>.];

parameter 'project' => (
    is            => 'rw',
    isa           => 'Str',
    required      => 1,
    documentation => q[Project name.],
);

parameter 'dst_name' => (
    is            => 'rw',
    isa           => 'Str',
    required      => 0,
    cmd_flag      => 'file',
    documentation => q[Optional destination file name.],
);

sub run {
    my ( $self ) = @_;

    my $file = $self->config->resource_file( $self->project );
    my $res  = App::PlannedCopy::Resource->new( resource_file => $file );
    my $iter = $res->resource_iter;
    my $name = $self->dst_name;

    if (    $self->config->current_user ne 'root'
        and $res->resource_scope eq 'system' )
    {
        say "\n[EE] Root privileges are required to install resources with 'system' scope.\n";
        exit;
    }

    if ($name) {
        say 'Job: 1 file',
            ' to check and install', ( $self->verbose ? ' (verbose)' : '' ),
            ':',
            "\n";
    }
    else {
        say 'Job: ', $res->count, ' file', ( $res->count != 1 ? 's' : '' ),
            ' to check and install', ( $self->verbose ? ' (verbose)' : '' ),
            ':',
            "\n";
    }

    $self->no_resource_message($self->project) if $res->count == 0;

    while ( $iter->has_next ) {
        my $res = $iter->next;
        if ($name) {

            # Skip until found; not efficient but simple to implement ;)
            next unless $res->dst->_name eq $name;
        }

        $self->prevalidate_element($res);

        if ( $res->has_no_issues ) {
            $self->item_printer($res) if $self->verbose;
            $self->inc_count_skip;
        }
        else {
            if ( $res->has_action('skip') ) {
                $self->item_printer($res);
                $self->inc_count_skip;
            }
            else {

                # install
                if (   $res->has_action('install')
                    || $res->has_action('unpack') )
                {
                    try {
                        $self->install_file($res);
                        $self->inc_count_inst;
                    }
                    catch {
                        $self->exceptions( $_, $res );
                        $self->inc_count_skip;
                    };
                }

                # update
                if ( $res->has_action('update') ) {
                    try {
                        $self->install_file($res);
                        $self->inc_count_inst;
                    }
                    catch {
                        $self->exceptions( $_, $res );
                        $self->inc_count_skip;
                    };
                }

                # chmod
                if ( $res->has_action('chmod') ) {
                    try {
                        $self->change_perms($res);
                    }
                    catch { $self->exceptions( $_, $res ) };
                }

                # chown
                if ( $res->has_action('chown') ) {
                    try {
                        $self->change_owner($res);
                    }
                    catch { $self->exceptions( $_, $res ) };
                }

                # unpack
                if ( $res->has_action('unpack') ) {
                    try {
                        $self->extract_archive($res);
                        $self->remove_archive($res);
                    }
                    catch { $self->exceptions( $_, $res ) };
                }

                # print
                $self->item_printer($res);
            }
        }
        $self->inc_count_proc;
    }

    $self->print_summary;

    return;
}

sub install_file {
    my ( $self, $res ) = @_;
    return if $self->dryrun;
    my $parent_dir = $res->dst->_parent_dir;
    if ( !$parent_dir->is_dir ) {
        unless ( $parent_dir->mkpath ) {
            Exception::IO::PathNotFound->throw(
                message  => 'Failed to create the destination path.',
                pathname => $parent_dir,
            );
        }
    }
    $self->copy_file( $res->src->_abs_path, $res->dst->_abs_path );
    $res->remove_issue_by_action($res, 'install');
    $res->remove_issue_by_action($res, 'update');
    $res->issues_category('done');
    return;
}

sub change_perms {
    my ($self, $res) = @_;
    return if $self->dryrun;
    $self->set_perm( $res->dst->_abs_path, $res->dst->_perm );
    $res->remove_issue_by_action($res, 'chmod');
    $res->add_issue(
        App::PlannedCopy::Issue->new(
            message  => 'Perms changed to',
            details  => $res->dst->_perm,
            category => 'info',
        ),
    );
    $res->issues_category('done');
    return;
}

sub change_owner {
    my ( $self, $res ) = @_;
    return if $self->dryrun;
    $self->set_owner( $res->dst->_abs_path, $res->dst->_user );
    $res->remove_issue_by_action( $res, 'chown' );
    $res->add_issue(
        App::PlannedCopy::Issue->new(
            message  => 'Owner changed',
            category => 'info',
        ),
    );
    $res->issues_category('done');
    return;
}

sub extract_archive {
    my ( $self, $res ) = @_;
    return if $self->dryrun;
    my $archive_path = $res->dst->_abs_path;
    my $archive      = Archive::Any::Lite->new($archive_path);
    my $into_dir     = $archive_path->parent->stringify;
    my $archive_file = $archive_path->basename;
    my $extracted = try { $archive->extract($into_dir); }
        catch {
            Exception::IO::SystemCmd->throw(
            message => "Unpacking '$archive_file' failed",
            logmsg  => $_,
        );
        return undef;       # required
    };
    if ($extracted) {
        $res->remove_issue_by_action( $res, 'unpack' );
        $res->add_issue(
            App::PlannedCopy::Issue->new(
                message  => 'Unpacked',
                details  => $archive_file,
                category => 'info',
            ),
        );
        $res->issues_category('done');
    }
    return;
}

sub remove_archive {
    my ( $self, $res ) = @_;
    return if $self->dryrun;
    my $archive_path = $res->dst->_abs_path;
    my $archive_file = $archive_path->basename;
    unlink $archive_path
        || $res->add_issue(
        App::PlannedCopy::Issue->new(
            message  => 'Could not unlink',
            details  => $archive_file,
            category => 'warn',
        ),
        );
    return;
}

sub print_summary {
    my $self = shift;
    my $cnt_proc = $self->count_proc // 0;
    say '';
    say 'Summary:';
    say ' - processed: ', $cnt_proc, ' records';
    say ' - skipped  : ', $self->dryrun ? "$cnt_proc (dry-run)" : $self->count_skip;
    say ' - installed: ', $self->dryrun ? '0 (dry-run)' : $self->count_inst;
    say '';
    return;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=encoding utf8

=head1 Description

The implementation of the C<install> command.

=head1 Interface

=head2 Attributes

=head3 project

Required parameter attribute for the install command.  The name of the
project - a directory name under C<repo_path>.

=head3 dst_name

Optional parameter attribute for the install command.  If provided
only this file is installed.

=head2 Instance Methods

=head3 run

The method to be called when the C<install> command is run.

Builds an iterator for the resource items and iterates over them.  If
the C<validate_element> method throws an exception, it is cached and
the item is skipped.  If there is no fatal exception thrown, then the
C<install_file> method is called on the item.

=head3 install_file

Copies an item (file), changes the owner and the perms.  Unpacks
archive files.

=head3 extract_archive

Unpacks an archive file in the destination dir.  Can handle any type
of archive that the C<Archive::Any::Lite> module recognizes.

=head3 print_summary

Prints the summary of the command execution.

=cut
