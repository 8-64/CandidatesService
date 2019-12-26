package MyService::Model;

use v5.24;
use warnings;

our $VERSION = v0.1;

use Carp;
use DBI;
use JSON::MaybeXS;

use FindBin qw[$RealBin];
my $root_dir;
BEGIN {
    $root_dir = ($RealBin =~ s:[^\w](bin|t|lib.+)\z::r);
}
use lib "$root_dir/lib";

sub new {
    my ($class, $params) = @_;
    my %data = (
    );

    my $options = {
        AutoCommit  => $params->{db}->{AutoCommit},
        PrintError  => $params->{db}->{PrintError},
        RaiseError  => $params->{db}->{RaiseError},
    };

    (%data) = (%data, %{ $params->{db} } ) if (exists $params->{db});
    if ($params->{db}->{driver} eq 'SQLite') {
        $data{connection} = "dbname=$root_dir/db/data.db";
    }

    my $connection_string = join(':', 'dbi', $data{driver}, $data{connection});
    my @db = ($connection_string, $data{login}, $data{pass}, $options);
    my $dbh = DBI->connect(@db) or croak("Cannot connect! ($DBI::err - ($DBI::errstr))");
    $data{dbh} = $dbh;

    bless(\%data => $class);
}

# Get database handle
sub getDBH {
    my ($self) = @_;
    $self->{dbh};
}

sub addCandidate {
    my ($self, $data) = @_;

    my ($input) = grep { length } $data->{parameters}->@*;
    $input = decode_json($input);

    # Do some validation
    if (exists $data->{checks}) {
        foreach my $field (keys $data->{checks}->%*) {
            unless (exists $input->{$field}) {
                return (400, "Bad Request: field [$field] not found");
            }
            if (ref($data->{checks}->{$field}) eq 'Regexp' and !($input->{$field} =~ $data->{checks}->{$field})) {
                return (400, "Bad Request: incorrect field [$field] supplied.");
            }
            if (ref($data->{checks}->{$field}) eq 'CODE' and !($data->{checks}->{$field}->( $input->{$field} ))) {
                return (400, "Bad Request: field [$field] validation failed.");
            }
        }
    }

    my $letter_id = _generateID(64);

    my $dbh = $self->getDBH;

    # Save the file
    my $sth = $dbh->prepare('
INSERT INTO FILES
        (LETTER_ID, LETTER_CONTENT)
VALUES (?, ?);
') or croak("Failed to prepare statement - $DBI::err ($DBI::errstr)");
    $sth->bind_param(1, $letter_id);
    $sth->bind_param(2, $input->{motivation_letter});
    $sth->execute or croak("Failed to add candidate - $DBI::err ($DBI::errstr)");

    $sth = $dbh->prepare('
INSERT INTO CANDIDATES
        (FIRST_NAME, LAST_NAME, EMAIL, LETTER_ID)
VALUES (?, ?, ?, ?);
') or croak("Failed to prepare statement - $DBI::err ($DBI::errstr)");
    $sth->bind_param(1, $input->{first_name});
    $sth->bind_param(2, $input->{last_name});
    $sth->bind_param(3, $input->{email});
    $sth->bind_param(4, $letter_id);
    $sth->execute or croak("Failed to add candidate - $DBI::err ($DBI::errstr)");

    $sth = $dbh->prepare("SELECT CANDIDATE_ID FROM CANDIDATES WHERE LETTER_ID = '$letter_id';")
        or croak("Failed to prepare select statement - $DBI::err ($DBI::errstr)");
    $sth->execute or croak("Failed to fetch candidate - $DBI::err ($DBI::errstr)");
    my ($id) = $sth->fetchrow_array();

    return(201, $id);
}

sub getCandidate {
    my ($self, $data) = @_;

    my $path = $data->{path};
    my ($id) = ($path =~ /([0-9]+)$/);
    $id = int $id;

    my $dbh = $self->getDBH;
    my $sth = $dbh->prepare("
SELECT
    FIRST_NAME, LAST_NAME, EMAIL, LETTER_ID
FROM CANDIDATES WHERE CANDIDATE_ID = $id;")
        or croak("Failed to prepare select statement - $DBI::err ($DBI::errstr)");
    $sth->execute or croak("Failed to fetch candidate - $DBI::err ($DBI::errstr)");
    my ($first_name, $last_name, $email, $letter_id) = $sth->fetchrow_array();
    unless (defined $email) {
        return(404, "Not Found: no candidate No $id");
    }

    my $letter = 'https://' . $data->{env}->{HTTP_HOST} . '/file/' . $letter_id;
    my $output = {
        candidate_id => $id,
        first_name => $first_name,
        last_name => $last_name,
        email => $email,
        motivation_letter => $letter,
    };

    $output = encode_json($output);

    return(200, $output);
}

sub deleteCandidate {
    my ($self, $data) = @_;

    my $path = $data->{path};
    my ($id) = ($path =~ /([0-9]+)$/);
    $id = int $id;

    my $dbh = $self->getDBH;
    my $sth = $dbh->prepare("
DELETE FROM FILES
WHERE LETTER_ID = (
    SELECT LETTER_ID FROM CANDIDATES WHERE CANDIDATE_ID = $id
);") or croak("Failed to prepare select statement - $DBI::err ($DBI::errstr)");
    $sth->execute or croak("Failed to fetch candidate - $DBI::err ($DBI::errstr)");

    $sth = $dbh->prepare("DELETE FROM CANDIDATES WHERE CANDIDATE_ID = $id;")
        or croak("Failed to prepare select statement - $DBI::err ($DBI::errstr)");
    $sth->execute or croak("Failed to fetch candidate - $DBI::err ($DBI::errstr)");

    return(204, 'No Content');
}

sub getAllCandidates {
    my ($self, $data) = @_;

    my $output = [];

    my $dbh = $self->getDBH;
    my $sth = $dbh->prepare('SELECT CANDIDATE_ID, FIRST_NAME, LAST_NAME FROM CANDIDATES;')
        or croak("Failed to prepare select - $DBI::err ($DBI::errstr)");
    $sth->execute or croak("Failed to fetch candidate - $DBI::err ($DBI::errstr)");

    my ($id, $first_name, $last_name);
    while (($id, $first_name, $last_name) = $sth->fetchrow_array) {
        push (@$output, {
            candidate_id => int $id,
            first_name => $first_name,
            last_name => $last_name,
        });
    }

    $output = encode_json($output);

    return(200, $output);
}

sub getMotivationLetterFile {
    my ($self, $data) = @_;

    my $path = $data->{env}->{PATH_INFO};
    my ($file_id) = ($path =~ m:([a-z0-9]{64})/?$:);

    unless (length $file_id) { return(404, 'File Not Found') }

    my $dbh = $self->getDBH;
    my $sth = $dbh->prepare("SELECT LETTER_CONTENT FROM FILES WHERE LETTER_ID  = ?;")
        or croak("Failed to prepare select - $DBI::err ($DBI::errstr)");
    $sth->bind_param(1, $file_id);
    $sth->execute or croak("Failed to fetch candidate - $DBI::err ($DBI::errstr)");
    my ($output) = $sth->fetchrow_array;

    return(200, $output);
}

sub _generateID {
    my ($length) = @_;
    my @charset = ('a'..'z', 0 .. 9);
    my $id;
    $id .= $charset[int rand @charset] while $length--;
    return $id;
}

1;
