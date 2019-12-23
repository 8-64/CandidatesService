package MyService::Context;

use v5.24;
use warnings;

our $VERSION = v0.1;

use FindBin qw[$RealBin];
my $root_dir;
BEGIN {
    $root_dir = ($RealBin =~ s:[^\w](bin|t|lib.+)\z::r);
}
use Carp;
use Config qw[];
use YAML   qw[Load];

use Exporter qw[import];
our @ISA = qw[Exporter];
our @EXPORT_OK = qw[$context];
our %EXPORT_TAGS = (ALL => [qw[$context]]);

our $context;

sub read {
    my ($class, %data) = @_;
    $class or $class = __PACKAGE__;

    %data = (
        file => '',
        %data
    );

    length($data{'file'}) or $data{'file'} = get_config_file();
    $data{'raw'} = do {
        open(my $fh, '<', $data{'file'}) or croak('Cannot open configuration file!');
        local $/ = undef;
        <$fh>
    };

    %data = (%data, %{ Load($data{'raw'}) });
    delete($data{'raw'}); # No point to keep it
    $data{'perl'} = { %Config::Config };

    $data{'root_dir'} = $root_dir; # And store projects root dir

    $context = bless(\%data => $class);
    return $context;
}

sub get {
    return $context;
}

# Find config file
sub get_config_file {
    my @config_names = ('config.yaml', 'config.yml');
    my $path = "$root_dir/conf/";
    foreach my $name (@config_names) {
        if (-r "$path$name") {
            croak('Found empty configuration file!') unless (-s "$path$name");
            return "$path$name";
        }
    }
    croak('No configuration file found!');
}

# Initialise at use to export early
BEGIN {
    MyService::Context::read();
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

MyService::Context - provide configuration, passwords and context

=head1 VERSION

Version 0.1

=head1 SYNOPSIS

    my $conf = MyService::Context->get;
    # Re-read configuration
    my $conf = MyService::Context->read;

=head1 DESCRIPTION

MyService::Context - provide configuration, passwords and context

=head1 COPYRIGHT AND LICENSE

This module is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
