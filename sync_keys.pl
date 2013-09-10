#!/usr/bin/env perl

# TODO THIS SCRIPT DOES NOT PROTECT AGAIST SAGE



use strict;
use warnings;
use Switch;
use cat::db;

use Path::Class;
use Data::Dumper;

my $dbh = cat::db::connectToDb('gitolite');
my $sql = 'select * from keys';
my $sth = $dbh->prepare($sql);

$sth->execute or die "SQL Error: $DBI::errstr\n";

my $dir = dir( $ARGV[0] );

while ( my $row = $sth->fetchrow_hashref )
    {
        switch ($row->{'state'}) {
            case "pending"  {isPending($row);}
            case "deleting" {isDeleting($row);}
            case "present"  {isPresent($row);}
            else            {die "awe bones! there is no state for entry: $row->{'name'}";}
        }
    }

$dbh->disconnect;


# Verify that the key exists in the file folder
# if not, create it; else skip
sub isPresent {
    my ($row) = @_;
    print ($row->{'name'} . " is present\n");
    my $file = $dir->file( $row->{'name'} . '.pub' );
    if (-e $file){
        return 0;
    }
    else {
        isPending($row);
    }
}

# Remove the file from the folder and remove the instance of the key from the db
sub isDeleting {
    my ($row) = @_;
    print ($row->{'name'} . " is deleting\n");

    # delete the File

    # Delete the entry in db
    # "DELETE FROM keys WHERE name=$row->{'name'}"
}

# Add the key to the keyfolder
# Change entry state to present
sub isPending {
    my ($row) = @_;
    print ($row->{'name'} . " is pending\n");
    my $file        = $dir->file( $row->{'name'} . '.pub' );
    my $file_handle = $file->openw();
    $file_handle->print( $row->{'keydata'} . "\n" );

    # Alter DB to reflect presence
    # "UPDATE keys SET state='present' where name=$row->{'name'}"

}
