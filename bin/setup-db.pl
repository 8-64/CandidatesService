#!/usr/bin/perl

use v5.24; # Let it be fairly modern, with stable postderef
use warnings;

use FindBin qw[$RealBin];
my $root_dir;
BEGIN {
    $root_dir = ($RealBin =~ s:[^\w](bin|lib|t)\z::r);
}
use lib "$root_dir/lib";
my $sql_dir = "$root_dir/sql";

use Carp;
use DBI;
use SQL::SplitStatement;

use MyService::Context qw[$context];
use MyService::Model;

$| = 1;

my $dbh = MyService::Model->new($context)->getDBH();

unless (@ARGV) {
    print <<"HEREDOC";
Script that runs SQL files, statement after statement
Usage: $0 some task
If you made so far, then connection with the database is likely working.
HEREDOC
    exit 0;
}

my $task = join('_', @ARGV);
say "Running task [$task]";
my $sql_script = "$sql_dir/$task.sql";

(-r $sql_script) or do {
    croak "Cant'f find anything for task [$task]!";
};

my $sql;
$sql = do {
    open (my $SQL_FILE, '<', $sql_script) or croak("Can't open [$sql_script] - ($!)");
    local $/ = undef;
    <$SQL_FILE>;
};

say "Running [$sql_script]";
my $sql_splitter = SQL::SplitStatement->new;
my @statements = $sql_splitter->split($sql);

foreach my $statement (@statements) {
    my $info = $statement;
    if (length($info) > 65) {
        $info = substr($info, 0, 62) . '...';
    }
    print "Executing [$info] ";

    # Fix Oracle quirks
    $statement =~ s/(?<=\s)END\z/END;/i;

    my $sth = $dbh->prepare($statement) or croak "Failure - error $DBI::err ($DBI::errstr)";

    $sth->execute or croak "Failure - error $DBI::err ($DBI::errstr)";

    say 'OK';
}

exit 0;

__END__

=pod

=encoding UTF-8

=head1 DESCRIPTION

Script that helps to run PL/SQL files, statement after statement

=head1 AUTHORS

Vasyl Kupchenko

=head1 COPYRIGHT AND LICENSE

This module is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
