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
use JSON::MaybeXS qw[decode_json from_json];
use JSON::Validator;
use YAML;
use HTTP::Request::Common;
use Plack::Test;
use Test::More;

use MyService::Context '$context';
use MyService::Util 'SysSlurp';

my $app = do "$root_dir/bin/candidates.psgi";
my $schema = "$root_dir/data/schema/OpenAPI_v3.0.json";

my $test = Plack::Test->create($app);

my $validator = JSON::Validator->new();
$validator->schema(SysSlurp($schema));

# 1) Request a JSON specification
{
    my $res = $test->request(GET '/openapi.json');
    is($res->code, 200, 'Returned 200 code');
    ok(length($res->content) >  100, 'Responded with a document');

    eval { decode_json($res->content) };
    ok(($@ ? 0 : 1), 'Document decoded as a JSON');

    my $for_check = from_json($res->content);
    my @validation_errors = $validator->validate($for_check);
    is(join('', @validation_errors), '', 'No validation errors found');
}

# 2) Request a YAML specification
{
    my $res = $test->request(GET '/openapi.yaml');
    is($res->code, 200, 'Returned 200 code');
    ok(length($res->content) >  100, 'Responded with a document');

    my $for_check;
    eval { $for_check = Load($res->content) };
    ok(($@ ? 0 : 1), 'Document decoded as a YAML');

    my @validation_errors = $validator->validate($for_check);
    is(join('', @validation_errors), '', 'No validation errors found');
}

done_testing();
