#!/usr/bin/perl

use v5.24; # Let it be fairly modern, with stable postderef
use warnings;

use Data::Dumper;

use Plack::App::URLMap;
use Plack::Request;

use Plack::Test;
use HTTP::Request::Common;
use Test::More;
use Encode qw(encode_utf8);
use JSON::MaybeXS qw(encode_json);

use FindBin qw[$RealBin];
my $root_dir;
BEGIN {
    $root_dir = ($RealBin =~ s:[^\w](bin|t|lib.+)\z::r);
}
use lib "$root_dir/lib";

use MyService::Context q[$context];
use MyService::Model;

my %dispatch = (
    GET => {
        qr/candidates.[0-9]+$/ => {
            comment => "Candidate info or 4xx",
            action  => sub {
                my ($code, $result) = MyService::Model->new($context)->getCandidate(@_);
                return($code, $result);
            },
        },
        qr/candidates$/ => {
            comment => "All the candidates info or 4xx",
            action  => sub {
                my ($code, $result) =  MyService::Model->new($context)->getAllCandidates();
                return($code, $result);
            },
        },
    },
    DELETE => {
        qr/candidates.[0-9]+$/ => {
            comment => "Delete candidate info or 4xx",
            action  => sub {
                my ($code, $result) = MyService::Model->new($context)->deleteCandidate(@_);
                return($code, $result);
            },
        },
    },
    POST => {
        qr/candidates$/ => {
            comment => "Create candidate info",
            checks  => {
                first_name        => qr/^[[:graph:]]+$/,
                last_name         => qr/^[[:graph:]]+$/,
                email             => qr/^[[:alnum:]._]+@[[:alnum:]._]+[[:alnum:]]$/,
                motivation_letter => sub { length($_[0]) > 200 },
            },
            action  => sub {
                my ($code, $result) = MyService::Model->new($context)->addCandidate(@_);
                return($code, $result);
            },
        },
    },
);

# API implementation
my $api = sub {
    my $env = shift;

    my ($code, $body);
    my $req = Plack::Request->new($env);

    if (defined $req->content_length and $req->content_length >  1024**2) {
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
            my $checks = undef;
            $checks = $dispatch{$method}->{$matcher}->{'checks'}
                 if (exists $dispatch{$method}->{$matcher}->{'checks'});

            ($code, $body) = $dispatch{$method}->{$matcher}->{'action'}->({
                env => $env,
                path => $path,
                checks => $checks,
                parameters => $parameters,
            });

            $matched++;
        }
    }
    unless ($matched) {
        return [404, [ "Content-Type" => "text/plain" ], [ 'Not Found' ]];
    }

    return [$code, [ "Content-Type" => "text/plain" ], [ $body ]];
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

    [
        200,
        [ "Content-Type" => "text/plain" ],
        [ Dumper($env) . Dumper(\%ENV) ]
    ]
};

my $openAPI = sub {
    my $env = shift;

    [
        200,
        [ "Content-Type" => "text/plain" ],
        [ 'API description (TBD)' ]
    ]
};

# Framework such as Raisin or Mojolicious or Dancer2 may be used to implement
# more sophisticated dispatch logic, but here is quite straightforward
# implementation: URLMap for top-level branching and then dispatch table
my $urlmap = Plack::App::URLMap->new;
$urlmap->map("/api" => $api);
$urlmap->map("/file" => $file);
$urlmap->map("/debug" => $debug);
$urlmap->map("/swagger.json" => $openAPI);
$urlmap->map("/" =>  sub { [404, [ "Content-Type" => "text/plain" ], [ '404 Not Found' ]] });
my $app = $urlmap->to_app;

# RUNNING SOME TESTS
my $test = Plack::Test->create($app);

# 1-2: not found
my $res = $test->request(GET "/BlaBlaBla");
is($res->code, 404);
like($res->content, qr/Not Found/);
# 2-4: wrong method
$res = $test->request(PUT "/api/candidates");
is($res->code, 405);
like($res->content, qr/Method Not Allowed/);
# Post candidate -> Wrong email field
{
    my $header = ['Content-Type' => 'application/json; charset=UTF-8'];
    my $data = {
        first_name        => 'Test',
        last_name         => 'mcTesty',
        emall             => 'mail@spam.com',
        motivation_letter => 'Roses are red, violets are blue' x (20 + rand 100),
    };

    my $body = encode_utf8(encode_json($data));
    $res = $test->request(POST '/api/candidates', Header => $header, Content => $body);
    is($res->code, 400);
    like($res->content, qr/Bad Request: field/);
}
# Post candidate -> Incorrect email field
{
    my $header = ['Content-Type' => 'application/json; charset=UTF-8'];
    my $data = {
        first_name        => 'Test',
        last_name         => 'mcTesty',
        email             => 'mailspam.com',
        motivation_letter => 'Roses are red, violets are blue' x (20 + rand 100),
    };

    my $body = encode_utf8(encode_json($data));
    $res = $test->request(POST '/api/candidates', Header => $header, Content => $body);
    is($res->code, 400);
    like($res->content, qr/Bad Request: incorrect/);
}
# Post candidate -> Everything ok
{
    my $header = ['Content-Type' => 'application/json; charset=UTF-8'];
    my $data = {
        first_name        => 'Test',
        last_name         => 'mcTesty',
        email             => 'mail@spam.com',
        motivation_letter => 'Roses are red, violets are blue' x (20 + rand 100),
    };

    my $body = encode_utf8(encode_json($data));
    $res = $test->request(POST '/api/candidates', Header => $header, Content => $body);
    is($res->code, 201);
    like($res->content, qr/\d+/);
}
# Same again -> error
{
    my $header = ['Content-Type' => 'application/json; charset=UTF-8'];
    my $data = {
        first_name        => 'Test',
        last_name         => 'mcTesty',
        email             => 'mail@spam.com',
        motivation_letter => 'Roses are red, violets are blue' x (20 + rand 100),
    };

    my $body = encode_utf8(encode_json($data));
    $res = $test->request(POST '/api/candidates', Header => $header, Content => $body);
    isnt($res->code, 201);
}
my $circumfix = 'A';
for (1..3) {
    my $header = ['Content-Type' => 'application/json; charset=UTF-8'];
    my $data = {
        first_name        => 'Test',
        last_name         => 'mcTesty',
        email             => ++$circumfix . 'mail@spam.com' . $circumfix++,
        motivation_letter => 'Roses are red, violets are blue' x (20 + rand 100),
    };

    my $body = encode_utf8(encode_json($data));
    $res = $test->request(POST '/api/candidates', Header => $header, Content => $body);
    is($res->code, 201);
    like($res->content, qr/\d+/);
}

# Delete candidate
$res = 'foo';
$res = $test->request(HTTP::Request::Common::DELETE '/api/candidates/1');
is($res->code, 204);
like($res->content, qr/No Content/);

done_testing();
