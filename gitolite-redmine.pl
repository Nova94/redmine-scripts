#!/usr/bin/env perl

#TODO
# do the curlopt_capath bit from this instead of just turrning off ssl_verify
# $curl->setopt(CURLOPT_SSL_VERIFYPEER, 0);
# http://www.tek-tips.com/viewthread.cfm?qid=1460875

use strict;
use warnings;

use Data::Dumper;    # Perl core module
use WWW::Curl::Easy;
use YAML qw(LoadFile);
use JSON;
use feature 'switch';
my $config;

main();

sub main
    {

    $config = LoadFile('config.yaml');

    # Offset from the beginning
    my $projoffset = 0;

    # how many results we will get each time through the loop
    my $limit = 100;

    my $projects_list_url = $config->{'redmine_url'} . 'projects.json';

    my $projtotal;
    my $membertotal;


    do
  {
  my $projects_list = returnjson($projects_list_url
    . "?offset=$projoffset&limit=$limit");

        $projtotal = $projects_list->{'total_count'};

  foreach my $project ( @{ $projects_list->{'projects'} } )
      {
      print 'repo ' . $project->{'identifier'} . "\n    RW+     =   id_rsa\n";

      my $prefix = 'projects/' . $project->{'id'};

      my $members_list_url =
    $config->{'redmine_url'} . "$prefix/memberships.json";

            my $memberoffset = 0;

      do
    {
    my $members_list = returnjson($members_list_url
        . "?offset=$memberoffset&limit=$limit" );

    $membertotal = $members_list->{'total_count'};

    each_member( $members_list->{'memberships'} );

    $memberoffset = $memberoffset + $limit;
    }
      while ($memberoffset <= $membertotal);

      print "\n";



      }

  $projoffset = $projoffset + $limit;


  }
    while ($projoffset <= $projtotal);

    return(1);
    }

sub returnjson
    {
    my ($request_url) = @_;
    my $curl = WWW::Curl::Easy->new;


    $curl->setopt( CURLOPT_HEADER,         0 );
    $curl->setopt( CURLOPT_SSL_VERIFYPEER, 0 );
    $curl->setopt( CURLOPT_URL,            $request_url . "\n");

    my @myheaders = ();
    $myheaders[0] = 'X-Redmine-API-Key: ' . $config->{'api_key'};
    $myheaders[1] = 'User-Agent: Perl interface for libcURL';

    $curl->setopt( CURLOPT_HTTPHEADER, \@myheaders );

    # A filehandle, reference to a scalar or reference to a typeglob
    # can be used here.

    my $response_body;
    $curl->setopt( CURLOPT_WRITEDATA, \$response_body );

    # Starts the actual request
    my $retcode = $curl->perform;

    my $curl_response;

    # Looking at the results...
    if ( $retcode == 0 )
        {

        #print("Transfer went ok\n");
        my $response_code = $curl->getinfo(CURLINFO_HTTP_CODE);

        # judge result and next action based on $response_code
        #print("Received response: $response_body\n");
        $curl_response = $response_body;
        }
    else
        {

        # Error code, type of error, error message
        print(    "An error happened: $retcode "
                . $curl->strerror($retcode) . ' '
                . $curl->errbuf
                . "\n" );
        }
    my $perl_scalar = decode_json $curl_response;
    return $perl_scalar;
    }

sub each_member
    {
    my ($memberships) = @_;
    foreach my $member (@$memberships)
        {
        if ( exists $member->{'user'} )
            {
            print '    ';
            given ( $member->{'roles'}[0]->{'name'} )
            {
                when ('Manager')
                {
                    print 'RW+     =   ';
                }
                when ('Developer')
                {
                    print 'RW+     =   ';
                }
                when ('Reporter')
                {
                    print 'R       =   ';
                }
                when ('Watcher')
                {
                    print 'R       =   ';
                }
                when ('Editor')
                {
                    print 'RW+     =   ';
                }
                when ('Viewer')
                {
                    print 'R       =   ';
                }
                default
                {
                }
            }

            print $member->{'user'}->{'name'} . "\n";
            }
        }

    return(1);
    }
