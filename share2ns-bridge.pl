#!/usr/bin/perl

use REST::Client;
use JSON;
use POSIX qw(strftime);
use Digest::SHA1 qw(sha1_hex);
use Getopt::Long;
use Data::Dumper;

# Create array of trend directions
$trends[0] = 'NONE';
$trends[1] = 'DoubleUp';
$trends[2] = 'SingleUp';
$trends[3] = 'FortyFiveUp';
$trends[4] = 'Flat';
$trends[5] = 'FortyFiveDown';
$trends[6] = 'SingleDown';
$trends[7] = 'DoubleDown';
$trends[8] = 'NOT COMPUTABLE';
$trends[9] = 'RATE OUT OF RANGE';

# Setup default command-line parameters
my $minutes  = 1440;
my $maxcount = 1;
my $help     = '';

# Process command-line arguments
GetOptions ("minutes=i" => \$minutes, "maxcount=i" => \$maxcounti, "h" => \$help ) or usage();
usage() if $help;

# Display usage text
sub usage {
    die ("\nUsage: share2ns-bridge.pl {options}\n\n Options:\n\n   --minutes xx  - Number of minutes to query is xx (optional - default 1440)\n   --maxcount yy - Maximum number of records to query is yy (optional - default 1)\n\n");
}



# Load and set configuration variables
if (-e 'config.pl') {
    my %config   = do 'config.pl';
} else { 
    die ("\n You must first create config.pl. Use the included config.pl.orig as a template, or see https://github.com/jmarler/share2ns-bridge\n\n");
}

# Create login request
my %loginhash = ('password' => $config{dexcom_password}, 'accountName' => $config{dexcom_username}, 'applicationId' => $config{application_id} );
my $loginbody = encode_json \%loginhash;
my $headers   = {'Accept' => 'application/json', 'User-Agent' => $config{agent_tag}, 'Content-Type' => 'application/json'};

# Create new REST Client
my $client = REST::Client->new();

# Set client parameters
$client->setHost($config{dexcom_login_host});

# Send login request to receive session token
$client->POST($config{dexcom_login_uri},$loginbody,$headers);

# Collect session token from response and clean up
my $session_id = $client->responseContent();
$session_id =~ s/"//g;

# Create URL for data request
my $data_uri_full = $config{dexcom_data_uri} . "?sessionID=" . $session_id . "&minutes=1440&maxCount=1";

# Set client parameters
$client->setHost($config{dexcom_data_host});

# Send login request to receive latest data set
$client->POST($data_uri_full,'',$headers);

# Parse response from Dexcom server
my $data_json     = new JSON;
my $response_json = $client->responseContent();
$response_json    =~ s/[\[\]]//g;
my $latest_data     = $data_json->decode($response_json);

# Convert Dexcom values to NightScout values
my $dt      = $latest_data->{'DT'};
my $st      = $latest_data->{'ST'};
my $wt      = $latest_data->{'WT'};
my $bgvalue = $latest_data->{'Value'};
my $trend   = $latest_data->{'Trend'};
$wt  =~ s/[\/Date()]//g;
$st  =~ s/[\/Date()]//g;

# Build array of data to send to Nightscout
my $to_ns   = {
				'sgv'        => $bgvalue*1,
				'date'       => $wt*1,
				'dateString' => strftime("%a %b %e %H:%M:%S %Z %Y", localtime($wt/1000)), 
				'trend'      => $trend*1,
				'direction'  => $trends[$trend],
				'device'     => 'share2',
				'type'       => 'sgv'
};

# Create JSON for entry to upload
my $entry_json = new JSON;
my $ns_entry   = $data_json->encode($to_ns);

# Create new REST Client
my $client = REST::Client->new();

# Set client parameters
$client->setHost($config{ns_host});

# Setup headers for Nightscout upload
my $headers   = {'Accept' => 'application/json', 'User-Agent' => $config{agent_tag}, 'Content-Type' => 'application/json', 'api-secret' => sha1_hex($config{ns_api_secret}) };

# Send login request to receive latest data set
$client->POST($config{ns_uri},$ns_entry,$headers);
