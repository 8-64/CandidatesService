#!/usr/bin/perl

use v5.24; # Let it be fairly modern, with stable postderef
use warnings;

use FindBin qw[$RealBin];
my $root_dir;
BEGIN {
    $root_dir = ($RealBin =~ s:[^\w](bin|t|lib.+)\z::r);
}
use lib "$root_dir/lib";

use Test::More;

BEGIN {
    my @modules = qw[
        MyService::Context
        MyService::Model
    ];

    foreach my $module (@modules) {
        use_ok($module);
    }
}

done_testing();
