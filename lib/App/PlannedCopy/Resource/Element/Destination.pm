package App::PlannedCopy::Resource::Element::Destination;

# ABSTRACT: The destination resource element object

use Moose;
use App::PlannedCopy::Types;
use namespace::autoclean;

with qw{App::PlannedCopy::Role::Resource::Element};

has '_perm' => (
    is       => 'ro',
    isa      => 'Octal',
    required => 1,
    default  => sub {'0644'},
    init_arg => 'perm',
);

has '_verb' => (
    is       => 'ro',
    isa      => 'Str',
    required => 0,
    init_arg => 'verb',
);

has '_abs_path' => (
    is       => 'ro',
    isa      => 'Path::Tiny',
    lazy     => 1,
    default  => sub {
        my $self = shift;
        return $self->_full_path->absolute;
    },
);

has '_parent_dir' => (
    is       => 'ro',
    isa      => 'Path::Tiny',
    lazy     => 1,
    default  => sub {
        my $self = shift;
        return $self->_abs_path->parent;
    },
);

has '_user_is_default' => (
    is       => 'rw',
    isa      => 'Str',
    required => 0,
    init_arg => undef,
    default => sub {
        return 1;
    },
);

has '_user' => (
    is       => 'ro',
    isa      => 'Str',
    required => 0,
    init_arg => 'user',
    default  => sub {
        return getpwuid($<);
    },
    trigger => sub {
        my ( $self, $new, $old ) = @_;
        $self->_user_is_default(0);          # reset attribute
    },
);

sub verb_is {
    my ($self, $verb_action) = @_;
    return 1 if $self->_verb eq $verb_action;
    return;
}

__PACKAGE__->meta->make_immutable;

1;
