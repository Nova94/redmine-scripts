#!/usr/bin/env perl

use cat::db;

use strict;
use warnings;

#Load the database and yaml file
my $dbh = cat::db::connectToDb('gitolite');
use YAML qw(LoadFile);
my $config = LoadFile('config.yaml');


#Update the projects db if there are any pending projects
my $sql_count = "select count(*) from projects where status='pending';";
my $sth_count = $dbh->prepare($sql_count);
$sth_count->execute or die "SQL Error: $DBI::errstr\n";
my $count_hash = $sth_count->fetchrow_hashref;

if ( $count_hash->{'count'} > 0 ) {
    system ("./gitolite-redmine.pl > " . $config->{'basedir'} . "/conf/projects.conf");
}

$sth_count->fetchrow_hashref;


#Update the keys database if there are pending keys
$sql_count = "select count(*) from keys where state='pending';";
$sth_count = $dbh->prepare($sql_count);
$sth_count->execute or die "SQL Error: $DBI::errstr\n";
$count_hash = $sth_count->fetchrow_hashref;

if ( $count_hash->{'count'} > 0 ) {
    system("./aliases.pl > " . $config->{'basedir'} . "/conf/aliases.pl");
}

$sth_count->fetchrow_hashref;


#Do some other stuff
system("./makesvn.pl");
system("./sync_keys.pl " . $config->{'basedir'} . "/keydir");
system("./sync_redmine.pl");


#Set any pending projects to present
my $sql_update = "update projects set status = 'present' where status = 'pending';";
my $sth_update = $dbh->prepare($sql_update);
$sth_update->execute or die "SQL Error: $DBI::errstr\n";
$dbh->disconnect;


#Commit and push changes
chdir $config->{'basedir'};
if ( `git status` !~ /nothing to commit/ ) {
    system("git add -A");
    system("git commit -m \"Commit through update-gitolite.pl\"");
    system("git push");
}
