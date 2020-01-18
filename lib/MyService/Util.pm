package MyService::Util;

use v5.24;
use warnings;

our $VERSION = v0.1;

use Carp;
use Exporter qw[import];
our @ISA = ('Exporter');
our @EXPORT_OK = qw[
    ModuleInstalled
    SysSlurp
];

# Is this module available?
sub ModuleInstalled {
    my ($module) = @_;
    qx[perldoc -lm $module];
    return($? == 0 ? 1 : 0);
}

# sysread()-based file slurp
sub SysSlurp {
    my ($file, $var) = @_;
    open(my $FH, '<', $file) or croak("Failed to open $file: [$!]!");
    sysread($FH, $var, -s $file) or croak("Failed to read $file: [$!]!");
    close $FH;
    return $var if (defined wantarray);
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

MyService::Util - provides utility functions for REST service

=head1 VERSION

Version 0.1

=head1 SYNOPSIS

    use MyService::Util ('ModuleInstalled');

=head1 DESCRIPTION

MyService::Util - utility functions for REST service

=head1 COPYRIGHT AND LICENSE

This module is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
