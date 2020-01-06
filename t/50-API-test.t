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
use HTTP::Request::Common qw[GET PUT POST DELETE];
use MIME::Base64 ();
use Plack::Test;
use Test::More;

use MyService::Context q[$context];

my $app = do "$root_dir/bin/candidates.psgi";

# RUNNING SOME TESTS
my $test = Plack::Test->create($app);

my @candidate_ids = ();
my %candidate_emails = ();

# headers
my $header = ['Content-Type' => 'application/json; charset=UTF-8'];
my $auth_header = [
    Authorization =>  'Basic ' . MIME::Base64::encode('Test:Foobar', ''),
    @$header,
];

# 1-2: not found
my $res = $test->request(GET "/BlaBlaBla");
is($res->code, 404, 'Returned 404 code');
like($res->content, qr/Not Found/);

# 2-4: wrong method
$res = $test->request(PUT "/api/candidates");
is($res->code, 405, 'Returned 405 code');
like($res->content, qr/Method Not Allowed/);

# Post candidate -> Wrong email field
{
    my $data = {
        first_name        => 'Test',
        last_name         => 'mcTesty',
        emall             => 'mail@spam.com',
        motivation_letter => 'Roses are red, violets are blue' x (20 + rand 100),
    };

    my $body = encode_utf8(encode_json($data));
    $res = $test->request(POST '/api/candidates', Header => $auth_header, Content => $body);
    is($res->code, 400, 'Returned 400');
    like($res->content, qr/Bad Request: field/, 'Bad request');
}

# Post candidate -> Incorrect email field
{
    my $data = {
        first_name        => 'Test',
        last_name         => 'mcTesty',
        email             => 'mailspam.com',
        motivation_letter => 'Roses are red, violets are blue' x (20 + rand 100),
    };

    my $body = encode_utf8(encode_json($data));
    $res = $test->request(POST '/api/candidates', Header => $auth_header, Content => $body);
    is($res->code, 400, 'Returned 400');
    like($res->content, qr/Bad Request: incorrect/, 'Bad request');
}

# Post candidate -> Everything ok
{
    my $data = {
        first_name        => 'Test',
        last_name         => 'mcTesty',
        email             => 'mail@spam.com',
        motivation_letter => 'Roses are red, violets are blue' x (20 + rand 100),
    };

    $candidate_emails{ $data->{email} }++;

    my $body = encode_utf8(encode_json($data));
    $res = $test->request(POST '/api/candidates', Header => $auth_header, Content => $body);
    is($res->code, 201, 'Returned 201 code');
    like($res->content, qr/[0-9]+/);
    push(@candidate_ids, int $res->content);
}

# Same again -> error
{
    my $data = {
        first_name        => 'Test',
        last_name         => 'mcTesty',
        email             => 'mail@spam.com',
        motivation_letter => 'Roses are red, violets are blue' x (20 + rand 100),
    };

    my $body = encode_utf8(encode_json($data));
    $res = $test->request(POST '/api/candidates', Header => $auth_header, Content => $body);
    isnt($res->code, 201, 'Returned not a 201 code');
}

# Constraint: letter is too small
{
    my $data = {
        first_name        => 'Test',
        last_name         => 'mcTesty',
        email             => 'another@spam.com',
        motivation_letter => 'Roses are red, violets are blue',
    };

    my $body = encode_utf8(encode_json($data));
    $res = $test->request(POST '/api/candidates', Header => $auth_header, Content => $body);
    isnt($res->code, 201, 'Returned not a 201 code');
}

my $circumfix = 'A';
for (1..3) {
    my $data = {
        first_name        => 'Test',
        last_name         => 'mcTesty',
        email             => ++$circumfix . 'mail@spam.com' . $circumfix++,
        motivation_letter => 'Roses are red, violets are blue' x (20 + rand 100),
    };

    $candidate_emails{ $data->{email} }++;

    my $body = encode_utf8(encode_json($data));
    $res = $test->request(POST '/api/candidates', Header => $auth_header, Content => $body);
    is($res->code, 201, 'Returned 201 code');
    like($res->content, qr/[0-9]+/, 'Returned an id');
    push(@candidate_ids, int $res->content);
}

# Get a list of candidates
@candidate_ids = sort {$a <=> $b} @candidate_ids;
sub candidateIDsMatch {
    use experimental 'smartmatch';
    $res = $test->request(GET '/api/candidates');
    is($res->code, 200, 'Returned 200 code');

    my $candidates = decode_json($res->content);

    my @returned_ids = ();
    foreach (@$candidates) {
        push(@returned_ids, $_->{candidate_id});
    }
    @returned_ids = sort {$a <=> $b} @returned_ids;

    ok(@candidate_ids ~~ @returned_ids, 'Candidate ids match');

    return $candidates if defined wantarray;
}
candidateIDsMatch();

# Delete a second candidate
{
    my $cid = splice(@candidate_ids, 1, 1);
    $res = $test->request(DELETE "/api/candidates/$cid", Header => $auth_header, Content => '');
    is($res->code, 204, 'Returned 204 code');
    like($res->content, qr/No Content/, 'Response ok');
}

# Unauthorized request
{
    my $cid = $candidate_ids[0];
    $res = $test->request(DELETE "/api/candidates/$cid", Header => $header);
    is($res->code, 401, 'Returned 401 code');
    like($res->content, qr/Authorization required/i, 'Response ok - authorization reqired');
}

# Candidate ID indeed is deleted; all mails are ok
{
    my $candidates = candidateIDsMatch();
    foreach (@$candidates) {
        $res = $test->request(GET "/api/candidates/" . $_->{candidate_id});
        is($res->code, 200, 'Returned 200 for candidate');
        $res = decode_json($res->content);
        ok(exists $candidate_emails{ $res->{email} }, 'Email as expected');
    }
}

done_testing();
