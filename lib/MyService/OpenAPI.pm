package MyService::OpenAPI;

use v5.24;
use warnings;

use Encode qw[encode_utf8];
use JSON::MaybeXS;

our $VERSION = v0.1;

use Carp;
use YAML qw[Dump];

sub new {
    my ($self, %data) = @_;
    %data = (
        openapi => "3.0.0",
        %data,
    );
    bless(\%data => 'MyService::OpenAPI');
}

sub info {
    my ($self, %meta) = @_;
    my %defaults = (
        version => "0.0.1",
        title   => "$0 API",
        description => "Expanded description of $0 API",
        license => {
            name => 'Perl',
            url => 'https://dev.perl.org/licenses/'
        },
        contact => {
            name => "$0 contact",
            email => 'spam@spam.com',
        }
    );
    $self->{info} = {%defaults, %meta};
}

sub describe {
    my ($self, $api) = @_;

    foreach my $method (keys %$api) {
        foreach my $path (keys $api->{$method}->%*) {
            # Use either supplied path, or take it from regexp
            my $openapi_path = $api->{$method}->{$path}->{path}
                if (exists $api->{$method}->{$path}->{path});
            unless (defined $openapi_path) {
                ($openapi_path) = $path =~ /(?:[^:]+:)?([\w\/]{3,})/;
            }
            # Prefix with "/"
            $openapi_path = '/' . $openapi_path unless ($openapi_path =~ m:^/:);

            my $responses = $api->{$method}->{$path}->{responses};
            my $openapi_method = lc $method;
            foreach my $property (qw[description responses]) {
                $self->{paths}->{$openapi_path}->{$openapi_method}->{$property} = $api->{$method}->{$path}->{$property};
            }
        }
    }

    $self;
}

sub to_json {
    my ($self) = @_;
    return encode_utf8(encode_json({ %$self }));
}

sub to_yaml {
    my ($self) = @_;
    return encode_utf8(Dump({ %$self }));
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

MyService::OpenAPI - provide an OpenAPI description for REST service

=head1 VERSION

Version 0.1

=head1 SYNOPSIS

    my $api_desc = MyService::OpenAPI->new();
    $api_desc->info(...);
    $api_desc->describe($API);
    my $json = $api_desc->to_json();

=head1 DESCRIPTION

MyService::OpenAPI - provide an OpenAPI description for REST service

=head1 COPYRIGHT AND LICENSE

This module is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
