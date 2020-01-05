#!/usr/bin/perl

use v5.24; # Let it be fairly modern, with stable postderef
use warnings;

use FindBin qw[$RealBin];
my $root_dir;
BEGIN {
    $root_dir = ($RealBin =~ s:[^\w](bin|t|lib.+)\z::r);
}
use lib "$root_dir/lib";

use Encode qw[encode_utf8];
use JSON::MaybeXS;
use YAML;
use HTTP::Request::Common;
use Plack::Test;
use Test::More;

use MyService::Context q[$context];

my $app = do "$root_dir/bin/candidates.psgi";

my $test = Plack::Test->create($app);

# 1) Request a JSON specification
{
    my $res = $test->request(GET '/openapi.json');
    is($res->code, 200, 'Returned 200 code');
    ok(length($res->content) >  100, 'Responded with a document');
    eval { decode_json($res->content) };
    ok(($@ ? 0 : 1), 'Document decoded as a JSON');
}

# 2) Request a YAML specification
{
    my $res = $test->request(GET '/openapi.yaml');
    is($res->code, 200, 'Returned 200 code');
    ok(length($res->content) >  100, 'Responded with a document');
    eval { my $e = Load($res->content) };
    ok(($@ ? 0 : 1), 'Document decoded as a YAML');
}

done_testing();
