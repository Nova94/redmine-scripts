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
    system ("./gitolite-redmine.pl > " . $config->{'gitolite_admin_path'} . "/conf/projects.conf");
}

$sth_count->fetchrow_hashref;


#Update the keys database if there are pending keys
$sql_count = "select count(*) from keys where state='pending';";
$sth_count = $dbh->prepare($sql_count);
$sth_count->execute or die "SQL Error: $DBI::errstr\n";
$count_hash = $sth_count->fetchrow_hashref;

if ( $count_hash->{'count'} > 0 ) {
    system("./aliases.pl > " . $config->{'gitolite_admin_path'} . "/conf/aliases.pl");
}

$sth_count->fetchrow_hashref;

#update the gitolite keydir
system("./sync_keys.pl " . $config->{'gitolite_admin_path'} . "/keydir");

#Create git repos
chdir $config->{'gitolite_admin_path'};
if ( `git status` !~ /nothing to commit/ ) {
    system("git add -A");
    system("git commit -m \"Commit through update-gitolite.pl\"");
    system("git push");
}

#Create svn repos
system("./makesvn.pl");

#update redmine
system("./sync_redmine.pl");


#Set any pending projects to present
my $sql_update = "update projects set status = 'present' where status = 'pending';";
my $sth_update = $dbh->prepare($sql_update);
$sth_update->execute or die "SQL Error: $DBI::errstr\n";
$dbh->disconnect;
