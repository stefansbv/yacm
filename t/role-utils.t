#
# Test the Utils role
#
use Test::Most;
use Test::Moose;
use Path::Tiny;
use lib 't/lib';
use TestCmd;

my @attributes = ( qw() );
my @methods    = (
    qw(
        is_selfsame
        copy_file
        set_perm
        set_owner
        handle_exception
        exception_to_issue
        no_resource_message
        quote_string
        compare
        get_project_files
        check_res_user
        check_user
        exceptions
        prevalidate_element
        get_perms
        get_owner
        check_project_name
        is_project_path
        is_project
      )
);

my $cmd = TestCmd->new;
map has_attribute_ok( $cmd, $_ ), @attributes;
map can_ok( $cmd, $_ ), @methods;

my $repo_path = path( qw(t test-repo) );
my $dest_path = path( qw(t test-dst) );

# Copy
ok my $src1 = path($repo_path, qw(check nonexistent.file) ),
    'source file path';
ok my $dst1 = path($dest_path, qw(check nonexistent.file)), 'destination dir';
throws_ok { $cmd->copy_file( $src1, $dst1 ) }
    qr/No such file or directory/, 'no such file or directory caught okay';

ok my $src2 = path($repo_path, qw(check filename1) ), 'source file path';
ok my $dst2 = path($dest_path, qw(check filename1) ), 'destination file path';
is $src2->is_file, 1, 'src is a file';
lives_ok { $cmd->copy_file($src2, $dst2) } 'file copy';
is $dst2->is_file, 1, 'dst is a file';

# Selfsame
lives_ok { $cmd->is_selfsame( $src1, $dst1 ) } 'is selfsame 1';
is $cmd->is_selfsame( $src1, $dst1 ), 0, 'not the same';
lives_ok { $cmd->is_selfsame($src2, $dst2  ) } 'is selfsame 2';

# Perms
throws_ok { $cmd->get_perms($dst1) }
    qr/No such file or directory/, 'no such file or directory caught okay';
is $cmd->get_perms($dst2), '0644', 'the perms of the file';
throws_ok { $cmd->set_perm( $dst1, oct(644) ) }
    qr/works only with files/, 'works only with files caught';
lives_ok { $cmd->set_perm( $dst2, oct(644) ) } 'file set perm';

# Owner
throws_ok { $cmd->get_owner($dst1) }
    qr/No such file or directory/, 'no such file or directory caught okay';
ok $cmd->get_owner($dst2), 'the owner of the file';
# TODO: test set_owner (how?)

done_testing();
