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
my $statePen  = 'UPDATE keys SET state=\'present\' WHERE name=?';

my $sth = $dbh->prepare($sql);
my $dir = dir($ARGV[0]);


$sth->execute('pending') or die "SQL Error: $DBI::errstr\n";
while ( my $row = $sth->fetchrow_hashref ) {
    isPending($row);
}

$dbh->disconnect;


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

    email($row);

    $dbh->prepare($statePen)->execute($row->{'name'}) or die "SQL Error: $DBI::errstr\n";
}

sub email {
    my ($row) = @_;

    my $uid = $row->{'uid'};
    my $name = $row->{'name'};

    open(FILE, 'email_forms/key_creation_email') or die "Cannot read key deletion email file\n";
    local $/;
    my $message = <FILE>;
    $message =~ s/(\$\w+)/$1/eeg;

    my $sendmail = '/usr/sbin/sendmail -t';
    my $from = "From: redmine\@cecs.pdx.edu\n";
    my $subject = "Subject: Your ssh key $name has been added to your redmine account\n";
    my $send_to = "To: $uid\@cecs.pdx.edu\n";

    open(SENDMAIL, "|$sendmail") or die "Cannot open $sendmail";
    print SENDMAIL $from;
    print SENDMAIL $subject;
    print SENDMAIL $send_to;
    print SENDMAIL "Content-type: text/plain\n\n";
    print SENDMAIL $message;
    close(SENDMAIL);
}
