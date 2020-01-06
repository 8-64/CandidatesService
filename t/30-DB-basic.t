#!/usr/bin/perl

use v5.24; # Let it be fairly modern, with stable postderef
use warnings;

use FindBin qw[$RealBin];
my $root_dir;
BEGIN {
    $root_dir = ($RealBin =~ s:[^\w](bin|t|lib.+)\z::r);
}
use lib "$root_dir/lib";
use MyService::Context q[$context];

use Test::More tests => 2;

my $db_type = lc $context->{db}->{driver};
$db_type =~ s/:.*$//;

ok(system("$root_dir/bin/setup-db.pl") == 0, 'Launched DB helper script');

my @args = ('create', $db_type, 'db');
ok(system($^X, "$root_dir/bin/setup-db.pl", @args) == 0, 'Purged and re-created a database');
