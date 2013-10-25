#!/usr/bin/env perl




use strict;
use warnings;
use Switch;
use cat::db;

use Path::Class;
use Data::Dumper;


my $dbh = cat::db::connectToDb('gitolite');
my $sql       = 'SELECT * FROM keys WHERE state=?';
my $delSql    = 'DELETE FROM keys WHERE name=?';

my $sth = $dbh->prepare($sql);
my $dir = dir($ARGV[0]);


$sth->execute('deleting') or die "SQL Error: $DBI::errstr\n";
while ( my $row = $sth->fetchrow_hashref ) {
    isDeleting($row);
}


$dbh->disconnect;


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
