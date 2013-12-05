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
    
    email($row);

    $dbh->prepare($delSql)->execute($row->{'name'}) or die "SQL Error: $DBI::errstr\n";
}

sub email {
    my ($row) = @_;

    my $uid = $row->{'uid'};
    my $name = $row->{'name'};

    open(FILE, 'email_forms/key_deletion_email') or die "Cannot read key deletion email file\n";
    local $/;
    my $message = <FILE>;
    $message =~ s/(\$\w+)/$1/eeg;

    my $sendmail = '/usr/sbin/sendmail -t';
    my $from = "From: redmine\@cecs.pdx.edu\n";
    my $subject = "Subject: Your ssh key $name has been removed from your redmine account\n";
    my $send_to = "To: $uid\@cecs.pdx.edu\n";

    open(SENDMAIL, "|$sendmail") or die "Cannot open $sendmail";
    print SENDMAIL $from;
    print SENDMAIL $subject;
    print SENDMAIL $send_to;
    print SENDMAIL "Content-type: text/plain\n\n";
    print SENDMAIL $message;
    close(SENDMAIL);
}
