#
# Test the projects list builder
#
use Test::More;
use Test::Exception;

use Path::Tiny;
use App::PlannedCopy;

subtest 'Test with no config files' => sub {

    local $ENV{PLCP_SYS_CONFIG} = path(qw(t nonexistent.conf));
    local $ENV{PLCP_USR_CONFIG} = path(qw(t nonexistent.conf));

    throws_ok { $app = App::PlannedCopy->new }
        qr/No local.path is set/,
        'no local.path set in config caught okay';
};

subtest 'Test with the test config files' => sub {

    local $ENV{PLCP_SYS_CONFIG} = path(qw(t system.conf));
    local $ENV{PLCP_USR_CONFIG} = path(qw(t user.conf));

    ok $app = App::PlannedCopy->new, 'constructor';

    ok my @dirs = $app->projects, 'get project dirs';
    is scalar @dirs, 8, 'we have 8 dirs';
    is $app->count_projects, 8, 'we have 8 dirs, indeed';
    ok my $p = $app->find_project( sub { $_->{path} eq 'sync' } ), 'we have a sync dir';
    is $p->{path}, 'sync', 'it has a name';
    is $p->{resource}, 1, 'it has a resource file';
};

done_testing;
