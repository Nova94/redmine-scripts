#!/usr/bin/env perl

# TODO THIS SCRIPT DOES NOT PROTECT AGAIST SAGE



use strict;
use warnings;
use Switch;
use cat::db;

use Path::Class;
use Data::Dumper;


my $dbh = cat::db::connectToDb('gitolite');
my $sql       = 'SELECT * FROM keys WHERE state=?';
my $delSql    = 'DELETE FROM keys WHERE name=?';
my $statePen  = 'UPDATE keys SET state=\'present\' WHERE name=?';

my $sth = $dbh->prepare($sql);
my $dir = dir($ARGV[0]);


$sth->execute('deleting') or die "SQL Error: $DBI::errstr\n";
while ( my $row = $sth->fetchrow_hashref ) {
    isDeleting($row);
}

$sth->execute('pending') or die "SQL Error: $DBI::errstr\n";
while ( my $row = $sth->fetchrow_hashref ) {
    isPending($row);
}

$dbh->disconnect;


# Verify that the key exists in the file folder
# if not, create it; else skip
sub isPresent {
    my $time = `date +%D-%T`;
    chomp($time);
    my ($row) = @_;
    my $file = $dir->file( $row->{'name'} . '.pub' );
    if (-e $file){
        return 0;
    }
    else {
        print "[ $time ] ERROR: $row->{'name'} wasn't actually present\n";
        isPending($row);
    }
}

# Remove the file from the folder and remove the instance of the key from the db
sub isDeleting {
    my $time = `date +%D-%T`;
    chomp($time);
    my ($row) = @_;
    my $file        = $dir->file( $row->{'name'} . '.pub' );
    print "[ $time ] DELETING: $file\n";
    $file =~ s/ /\\ /;
    `rm $file`;
    $dbh->prepare($delSql)->execute($row->{'name'}) or die "SQL Error: $DBI::errstr\n";
}

# Add the key to the keyfolder
# Change entry state to present
sub isPending {
    my $time = `date +%D-%T`;
    chomp($time);
    my ($row) = @_;
    my $file        = $dir->file( $row->{'name'} . '.pub' );
    my $file_handle = $file->openw();
    print "[ $time ] CREATING: $file\n";
    $file_handle->print( $row->{'keydata'} . "\n" );
    $dbh->prepare($statePen)->execute($row->{'name'}) or die "SQL Error: $DBI::errstr\n";
}
