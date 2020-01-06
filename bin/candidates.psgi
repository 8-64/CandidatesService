#!/usr/bin/perl

use v5.24; # Let it be fairly modern, with stable postderef
use warnings;

use Plack::App::URLMap;
use Plack::Builder;
use Plack::Request;

use FindBin qw[$RealBin];
my $root_dir;
BEGIN {
    $root_dir = ($RealBin =~ s:[^\w](bin|t|lib.+)\z::r);
}
use lib "$root_dir/lib";

use MyService::Auth;
use MyService::Context qw[$context];
use MyService::Model;
use MyService::OpenAPI;
use MyService::Util qw[ModuleInstalled];

use Log::Log4perl;
use Log::Log4perl::Level;
use Log::Dispatch::FileRotate;

my %dispatch = (
    GET => {
        qr/candidates.[0-9]+$/ => {
            description => "Candidate info or 4xx",
            action      => sub {
                my ($code, $result) = MyService::Model->new($context)->getCandidate(@_);
                return($code, $result);
            },
            path        => '/candidates/{id}',
            responses   => {
                200 => {
                    description => 'OK, retrieved'
                },
            },
        },
        qr/candidates$/ => {
            description => "All the candidates info or 4xx",
            action      => sub {
                my ($code, $result) =  MyService::Model->new($context)->getAllCandidates();
                return($code, $result);
            },
            responses   => {
                200 => {
                    description => 'OK, retrieved'
                },
            },
        },
    },
    DELETE => {
        qr/candidates.[0-9]+$/ => {
            description => "Delete candidate info or 4xx",
            action      => sub {
                my ($code, $result) = MyService::Model->new($context)->deleteCandidate(@_);
                return($code, $result);
            },
            auth        => '_authenticate',
            path        => '/candidates/{id}',
            responses   => {
                204 => {
                    description => 'OK, deleted'
                },
            },
        },
    },
    POST => {
        qr/candidates$/ => {
            description => "Create candidate info",
            checks      => {
                first_name        => qr/^[[:graph:]]+$/,
                last_name         => qr/^[[:graph:]]+$/,
                email             => qr/^[[:alnum:]._]+@[[:alnum:]._]+[[:alnum:]]$/,
                motivation_letter => sub { length($_[0]) > 200 },
            },
            action      => sub {
                my ($code, $result) = MyService::Model->new($context)->addCandidate(@_);
                return($code, $result);
            },
            auth       => '_authenticate',
            responses => {
                201 => {
                    description => 'OK, created'
                },
            }
        },
    },
);

# API implementation
my $api = sub {
    my $env = shift;

    my ($code, $body);
    my $req = Plack::Request->new($env);

    if (defined $req->content_length and $req->content_length > $context->{service}->{max_request}) {
        return [413, [ "Content-Type" => "text/plain" ], [ 'Payload Too Large' ]];
    }

    my $method = $req->method;
    unless (exists $dispatch{$method}) {
        return [405, [ "Content-Type" => "text/plain" ], [ 'Method Not Allowed' ]];
    }

    my $path   = $req->script_name . $req->path;
    $path =~ s:/$::;

    my $parameters = [ $req->body_parameters->%* ];

    # Match and dispatch
    my $matched = 0;
    foreach my $matcher (keys $dispatch{$method}->%*) {
        if ($path =~ /$matcher/) {
            my $entry = $dispatch{$method}->{$matcher};

            # Is this part restricted? If so, authenticate
            if (exists $entry->{'auth'}) {
                my $authenticator = \&{ $entry->{'auth'} };
                my $auth_outcome = &{$authenticator}($env);
                return $auth_outcome if ($auth_outcome->[0] != 200);
            }

            my $checks = undef;
            $checks = $entry->{'checks'}
                 if (exists $entry->{'checks'});

            ($code, $body) = $entry->{'action'}->({
                env => $env,
                path => $path,
                checks => $checks,
                parameters => $parameters,
            });

            $matched++;
            last;
        }
    }
    unless ($matched) {
        return [404, [ "Content-Type" => "text/plain" ], [ 'Not Found' ]];
    }

    my $c_type = ($code > 199 and $code < 300) ? 'application/json' : 'text/plain';
    return [$code, [ "Content-Type" => $c_type ], [ $body ]];
};

# File retrieval
my $file = sub {
    my $env = shift;

    my ($code, $result) = MyService::Model->new($context)->getMotivationLetterFile({env => $env});
    return [$code, [ "Content-Type" => "text/plain" ], [ $result ]];
};

# Information for debugging
my $debug = sub {
    my $env = shift;
    require Data::Dumper;
    "Data::Dumper"->import();
    $Data::Dumper::Sortkeys = 1;

    [
        200,
        [ "Content-Type" => "text/html" ],
        [ '<html><body><pre>' . Dumper($env) . Dumper(\%ENV) . '</pre></body></html>' ]
    ]
};

my $openAPI = sub {
    my $env = shift;

    my $api_desc = MyService::OpenAPI->new();
    $api_desc->info(
        version => "0.1",
        title   => "MyService API",
        description => "Expanded description of MyService API",
        license => {
            name => 'Perl',
            url => 'https://dev.perl.org/licenses/'
        },
        contact => {
            name => 'MyService contact',
            email => 'spam@spam.com',
        }
    );
    $api_desc->describe(\%dispatch);

    my $req = Plack::Request->new($env);

    say $req->script_name . $req->path;

    my ($body, $c_type) = (($req->script_name . $req->path) =~ m/\.json/)
        ? ($api_desc->to_json, "application/json")
        : ($api_desc->to_yaml, "application/x-yaml");

    [
        200,
        [ "Content-Type" => $c_type ],
        [ $body ]
    ]
};

# Middleware installation
# More debugging!
if (ModuleInstalled('Plack::Middleware::Debug')) {
    $debug = builder {
        enable 'Debug';
        $debug;
    };
}

# Framework such as Raisin or Mojolicious or Dancer2 may be used to implement
# more sophisticated dispatch logic, but here is quite straightforward
# implementation: URLMap for top-level branching and then dispatch table
my $urlmap = Plack::App::URLMap->new;
$urlmap->map("/api" => $api);
$urlmap->map("/file" => $file);
$urlmap->map("/debug" => $debug);
$urlmap->map("/openapi.json" => $openAPI);
$urlmap->map("/openapi.yaml" => $openAPI);
$urlmap->map("/" =>  sub { [404, [ "Content-Type" => "text/plain" ], [ '404 Not Found' ]] });
my $app = $urlmap->to_app;

# Store access log, if enabled
if ($context->{service}->{logging}) {
    Log::Log4perl->init($context->{service}->{log_config});
    my $log = Log::Log4perl->get_logger();

    $app = builder {
        enable "Plack::Middleware::AccessLog",
        format => '%t "%r" %h %u %>s %b "%{Referer}i" "%{User-agent}i"',
        logger => sub { $log->debug(@_) };
        $app;
    };
}

# Standalone implementation. May be run without "plackup" script
unless (caller) {
    @ARGV = (
        '--server'  => $context->{plack}->{server},
        '--port'    => $context->{plack}->{port},
        '--host'    => $context->{plack}->{host},
        '--workers' => $context->{plack}->{workers},
        '--ssl'     => $context->{plack}->{ssl},
        # Conditionally include SSL parameters if it is enabled
        # Different servers use different names for them
        (
            '--ssl-key-file'  => $root_dir . $context->{plack}->{'ssl-key-file'},
            '--ssl-cert-file' => $root_dir . $context->{plack}->{'ssl-cert-file'},
            '--ssl-key'       => $root_dir . $context->{plack}->{'ssl-key-file'},
            '--ssl-cert'      => $root_dir . $context->{plack}->{'ssl-cert-file'},
        ) x ($context->{plack}->{ssl}),
        @ARGV
    );

    require Plack::Runner;
    my $runner = Plack::Runner->new;
    $runner->parse_options(@ARGV);
    $runner->run($app);
    exit 0;
}

return $app;
