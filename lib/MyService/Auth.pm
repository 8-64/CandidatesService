package MyService::Auth;

use v5.24;
use warnings;

our $VERSION = v0.1;

use Exporter qw[import];
our @ISA = ('Exporter');
our @EXPORT = qw[_authenticate];

use Carp;
use Digest::SHA qw[sha512_base64];
use MIME::Base64;

use FindBin qw[$RealBin];
my $root_dir;
BEGIN {
    $root_dir = ($RealBin =~ s:[^\w](bin|t|lib.+)\z::r);
}
use lib "$root_dir/lib";
use MyService::Context qw[$context];

sub unauthorized {
    my $body = 'Authorization required';
     return [
         401,
         [ 'Content-Type' => 'text/plain',
           'Content-Length' => length $body,
           'WWW-Authenticate' => 'Basic realm="Candidates Service API"' ],
         [ $body ],
     ]
}

sub _authenticate {
    my($env) = @_;

    my $auth = $env->{HTTP_AUTHORIZATION}
        # For testing
        // (exists $env->{HTTP_HEADER} ? ($env->{HTTP_HEADER} =~ /(Basic\s[a-z0-9+\/=]+)/i)[0] : undef)
        // return unauthorized();

    # Next logic literally taken from Plack::Middleware::Auth::Basic,
    # but here we are getting more granularity
    # note the 'i' on the regex, as, according to RFC2617 this is a
    # "case-insensitive token to identify the authentication scheme"
    if ($auth =~ /^Basic (.*)$/i) {
        my($user, $pass) = split /:/, (MIME::Base64::decode($1) || ":"), 2;
        $pass = '' unless defined $pass;

        return [200] if $context->{auth}->{disabled};
        # User not found
        return unauthorized() unless exists $context->{auth}->{users}->{$user};
        # Password is wrong
        return unauthorized() if (sha512_base64($pass) ne $context->{auth}->{users}->{$user}->{digest});

        $env->{REMOTE_USER} = $user;
        return [200];
    }

    return unauthorized();
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

MyService::Auth - provides an authorization logic

=head1 VERSION

Version 0.1

=head1 SYNOPSIS

    use MyService::Auth;

=head1 DESCRIPTION

MyService::Auth - contains and provides authorization logic. By default supports
Basic authorization

=head1 COPYRIGHT AND LICENSE

This module is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
