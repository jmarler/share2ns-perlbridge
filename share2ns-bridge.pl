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
$ENV{'PERL_LWP_SSL_VERIFY_HOSTNAME'} = 0;
my $minutes  = 1440;
my $maxcount = 10;
my $help     = '';
my $quiet    = '';

# Process command-line arguments
GetOptions ("minutes=i" => \$minutes, "maxcount=i" => \$maxcount, "h" => \$help, "q" => \$quiet ) or usage();
usage() if $help;

# Display usage text
sub usage {
    die ("\nUsage: share2ns-bridge.pl {options}\n\n Options:\n\n   --minutes xx  - Number of minutes to query is xx (optional - default 1440)\n   --maxcount yy - Maximum number of records to query is yy (optional - default 10)\n   -q            - Quiet mode. Supress all output. (useful for cron)\n\n");
}

# Set configuration values
my %config = ( 
dexcom_login_host => 'https://share1.dexcom.com',
dexcom_data_host  => 'https://share1.dexcom.com',
application_id    => 'd89443d2-327c-4a6f-89e5-496bbb0317db',
agent_tag         => 'Dexcom Share/3.0.2.11 CFNetwork/711.2.23 Darwin/14.0.0',
dexcom_login_uri  => '/ShareWebServices/Services/General/LoginPublisherAccountByName',
dexcom_data_uri   => '/ShareWebServices/Services/Publisher/ReadPublisherLatestGlucoseValues',
dexcom_username   => '',
dexcom_password   => '',
ns_uri            => '/api/v1/entries.json',
ns_host           => 'http://',
ns_api_secret     => '');

# Display command line parameters
$oldesttime = time - ($minutes*60);
$oldest     = strftime("%a %b %e %H:%M:%S %Z %Y", localtime($oldesttime));
if (!$quiet) { print "Loading a maximum of " . $maxcount . " records searching back to " . $oldest . "\n"; }

# Create login request
my %loginhash = ('password' => $config{dexcom_password}, 'accountName' => $config{dexcom_username}, 'applicationId' => $config{application_id} );
my $loginbody = encode_json \%loginhash;
my $headers   = {'Accept' => 'application/json', 'User-Agent' => $config{agent_tag}, 'Content-Type' => 'application/json'};

# Create new REST Client
my $client = REST::Client->new();

# Set client parameters
$client->setHost($config{dexcom_login_host});

# Send login request to receive session token
if (!$quiet) { print "Logging in to Dexcom host " . $config{dexcom_login_host} . " . . . "; }
$client->POST($config{dexcom_login_uri},$loginbody,$headers);
if (!$quiet) { print "done.\n"; }

# Check to see if login was successful
if ($client->responseCode() != '200') { die ("Dexcom login failed with HTTP error " . $client->responseCode() . ". Check config.pl values, and connectivity to " . $config{dexcom_login_host} . "\n" . $client ->responseContent()); }
# Collect session token from response and clean up
my $session_id = $client->responseContent();
$session_id =~ s/"//g;

# Create URL for data request
my $data_uri_full = $config{dexcom_data_uri} . "?sessionID=" . $session_id . "&minutes=" . $minutes . "&maxCount=" . $maxcount;

# Set client parameters
$client->setHost($config{dexcom_data_host});

# Send login request to receive latest data set
if (!$quiet) { print "Requesting data from " . $config{dexcom_data_host} . " . . . "; }
$client->POST($data_uri_full,'',$headers);
if (!$quiet) { print "done.\n"; }

# Parse response from Dexcom server
my $records       = 0;
my $response_json = $client->responseContent();
my @all_data      = @{decode_json($response_json)};

# Iterate through all of the returned records
foreach my $latest_data ( @all_data ) {
   $records++;
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

   # Display record
   if (!$quiet) { print "Record:" . $records . "\n sgv: ".$bgvalue."\n date: ".strftime("%a %b %e %H:%M:%S %Z %Y", localtime($wt/1000)) . "\n trend: " . $trend . " - " . $trends[$trend] . "\n device: share2\n type: sgv\n"; }
   
   # Create JSON for entry to upload
   my $entry_json = new JSON;
   my $ns_entry   = $entry_json->encode($to_ns);
   
   # Create new REST Client
   my $client = REST::Client->new();
   
   # Set client parameters
   $client->setHost($config{ns_host});
   
   # Setup headers for Nightscout upload
   my $headers   = {'Accept' => 'application/json', 'User-Agent' => $config{agent_tag}, 'Content-Type' => 'application/json', 'api-secret' => sha1_hex($config{ns_api_secret}) };
   
   # Send login request to receive latest data set
   if (!$quiet) { print "Sending data to nightscout URL: " . $config{ns_host} . " . . ."; }
   $client->POST($config{ns_uri},$ns_entry,$headers);
   if (!$quiet) { print "done.\n"; }
}

if (!$quiet) { print "Processed " . $records . " entries.\n"; }

