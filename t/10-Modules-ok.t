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
use Test::Pod;

BEGIN {
    my @modules = qw[
        MyService::Auth
        MyService::Context
        MyService::Model
        MyService::OpenAPI
        MyService::Util
    ];

    plan tests => scalar(@modules) * 3;

    foreach my $module (@modules) {
        use_ok($module);

        my $file = "$module.pm";
        $file =~ s[::][/]g;
        Test::Pod::pod_file_ok($INC{$file});

        is(ref(\eval $module->VERSION()), 'VSTRING', "[$module] has a version set");
    }
}

done_testing();
