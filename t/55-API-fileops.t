#!/usr/bin/perl

use v5.24; # Let it be fairly modern, with stable postderef
use warnings;

use Data::Dumper;

use FindBin qw[$RealBin];
my $root_dir;
BEGIN {
    $root_dir = ($RealBin =~ s:[^\w](bin|t|lib.+)\z::r);
}
use lib "$root_dir/lib";

use Encode qw[encode_utf8];
use JSON::MaybeXS;
use HTTP::Request::Common;
use Plack::Test;
use Test::More;

use MyService::Context q[$context];

my $app = do "$root_dir/bin/candidates.psgi";

my $test = Plack::Test->create($app);

my $header = ['Content-Type' => 'application/json; charset=UTF-8'];
my $candidate_id;
my $file_link;
my $motivation_letter = 'Ipsum lorem something ' x 100;

my $data = {
    first_name        => 'FileTest',
    last_name         => 'mcTesty',
    email             => $^T . $$ . '_file@test.com',
    motivation_letter => $motivation_letter,
};

# 1) Create an entry and a file
{
    my $body = encode_utf8(encode_json($data));
    my $res = $test->request(POST '/api/candidates', Header => $header, Content => $body);
    is($res->code, 201, 'Returned 201 code');
    like($res->content, qr/[0-9]+/);
    $candidate_id = int $res->content;
}

# 2) Entry was created, get a file link
{
    my $res = $test->request(GET "/api/candidates/$candidate_id");
    is($res->code, 200, 'Returned 200 for candidate');
    $res = decode_json($res->content);
    is($res->{email}, $data->{email}, 'Email is the same');
    $file_link = $res->{motivation_letter};
    like($file_link, qr{^https?://[^\.\s/]+[\./][^\.\s/]+}, 'File link looks like URI');
}

# 3) Get and compare the file
{
    my $res = $test->request(GET $file_link);
    is($res->code, 200, 'Returned 200 for file');
    $res = $res->content;
    is($motivation_letter, $res, 'File is identical');
}

# 4) Remove the entry
{
    my $res = $test->request(HTTP::Request::Common::DELETE "/api/candidates/$candidate_id");
    is($res->code, 204, 'Returned 204 code');
    like($res->content, qr/No Content/, 'Deleted ok');
}

# 5) File does not exists afterwards
{
    my $res = $test->request(GET $file_link);
    is($res->code, 404, 'Returned 404 for file');
    like($res->content, qr/Not Found/, 'File not found.');
}

done_testing();
