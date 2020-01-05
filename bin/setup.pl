#!/usr/bin/perl

# Script that helps with configuration of MyService

use v5.24; # Let it be fairly modern, with stable postderef
use warnings;

use FindBin qw[$RealBin];
my $root_dir;
BEGIN {
    $root_dir = ($RealBin =~ s:[^\w](bin|lib|t)\z::r);
}
use lib "$root_dir/lib";

my $conf_dir = "$root_dir/conf";

use Carp;
use Data::Dumper;
use Digest::SHA qw[sha512_base64];
use Pod::Usage;
use YAML;

pod2usage(0) unless (@ARGV);

# Process argument(s)
for (@ARGV) {
    if(/perm(issions)?/i) { fix_permissions(); next }
    if(/pass(word)?/i)    { hash_passwords(); next }
    if(/[\w]=[\w]?/)      { set_value($_); next }
    if(/[\w]\?$/)         { get_value($_); next }
    say "Unknown command: " . $_;
    pod2usage(0);
}

sub fix_permissions {
    my $conf = [ $conf_dir        => qr/ya?ml$/ ];
    my $cert = [ "$root_dir/crt"  => qr/(pem|cert|key)$/ ];

    foreach my $place ($conf, $cert) {
        opendir(my $DH, $place->[0]) or croak("Failed to open $place->[0]: [$!]!");
        while (readdir $DH) {
            my $file = "$place->[0]/$_";
            next if ($file !~ $place->[1] or ! -f $file);
            my $perm = (stat($file))[2] & 07777;
            if ($perm & 077) {
                say "Setting permissions on [$file]";
                chmod($perm | 0600, $file);
            }
        }
        closedir $DH;
    }
}

sub hash_passwords {
    my $file = "$conf_dir/config.yaml";
    my $conf = _get_config($file);
    my $modified = 0;

    foreach my $login (keys $conf->{auth}->{users}->%*) {
        next unless exists($conf->{auth}->{users}->{$login}->{pass});
        my $pass = delete($conf->{auth}->{users}->{$login}->{pass});
        $pass = sha512_base64($pass);
        $conf->{auth}->{users}->{$login}->{digest} = $pass;
        say "Hashed password for [$login]";
        $modified++;
    }

    if ($modified) {
        $conf->{info}->{modified} = 'Last time modified on ' . scalar localtime . ' (automatically)';
        _save_config($conf, $file);
    }
}

# Set value in config file
sub set_value {
    my ($entry) = @_;
    my $file = "$conf_dir/config.yaml";
    my $conf = _get_config($file);

    my ($path, $value) = split('=', $entry);
    my (@elements) = split('/', $path);

    my $hr = $conf;
    my $key = pop @elements;
    foreach (@elements) {
        $hr = (exists($hr->{$_}))
            ? ($hr->{$_})
            : ($hr->{$_} = {});
    }
    $hr->{$key} = $value;

    say "Writing $path -> $value into $file";
    $conf->{info}->{modified} = 'Last time modified on ' . scalar localtime . " (changed $path)";
    _save_config($conf, $file);
}

# Get value in config file
sub get_value {
    my ($entry) = @_;
    $entry =~ s/\?$//;
    my $file = "$conf_dir/config.yaml";
    my $conf = _get_config($file);
    my (@elements) = split('/', $entry);

    my $hr = $conf;
    my $key = pop @elements;
    foreach (@elements) {
        $hr = (exists($hr->{$_}))
            ? ($hr->{$_})
            : (croak("No key $_ found!"));
    }
    say(exists($hr->{$key})
        ? $hr->{$key}
        : croak("No key $key found!"));
}

# Read YAML
sub _get_config {
    my ($file) = @_;
    my $conf;
    open(my $FH, '<', $file) or croak("Failed to open $file: [$!]!");
    sysread($FH, $conf, -s $file) or croak("Failed to read $file: [$!]!");
    close $FH;
    return Load($conf);
}

# Save as YAML
sub _save_config {
    my ($conf, $file) = @_;
    $YAML::Indent = 4;
    my $save = Dump($conf);

    open(my $FH, '+>', $file) or croak("Failed to open $file for writing: [$!]!");
    print $FH $save;
    close $FH;
}

exit 0;

__END__

=pod

=encoding UTF-8

=head1 SYNOPSIS

Script that helps with configuration of MyService. It does the next things:

    setup.pl permissions            Set up proper permissions for conf files
    setup.pl passwords              Securely hash passwords
    setup.pl path/to/key=value      Set values in config files
    setup.pl path/to/key?           Get values from config file

=head1 AUTHORS

Vasyl Kupchenko

=head1 COPYRIGHT AND LICENSE

This module is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
