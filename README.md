# share2ns-perlbridge
Perl script that downloads data from Dexcom and submits it to a nightscout installation

# About this script
This script is intended for users who already have a working nightscout installation, have a Dexcom Share CGM, and want to use the Dexcom Share application to collect data from the CGM, submit the data to Dexcom, and then use this script to copy that data from Dexcom's servers to the user's NightScout installation.

# Requirements
* Working NightScout installation
* URL to working NightScout installation
* API secret configured in NightScout (uploader device does not have to use API secret but it's a good way to test it)
* API secret value from NightScout
* Dexcom Share CGM
* Dexcom Share account
* Dexcom Share account credentials (username and password)
* Dexcom Share application working on iPhone and connected to Dexcom CGM
* Computer/server that can run perl with these modules:
```
REST::Client
JSON
POSIX
Digest::SHA1
Getopt::Long
Data::Dumper
```
* A working text editor to edit script and add credentials

# Before you start
* Confirm that you have a working NightScout installation, with the API secret enabled
* Confirm that you have a working Dexcom Share setup working on your iPhone
* Collect the NightScout URL and API secret
* Collect your Dexcom Share credentials (username and password)

# Configuration
After cloning this repo, or downloading share-ns-perlbridge.pl, edit the file in your favorite text editor. I recommend TextWrangler on OS X, Notepad++ on Windows OS, and vim on Linux/*nix.

The configuration variables start at line 38. The only variables you should have to edit are:
```
dexcom_username   => '',
dexcom_password   => '',
...
ns_host           => 'http://',
ns_api_secret     => '');
```

For dexcom_username and dexcom_password, enter in the credentials you use in the Dexcom share application on your iPhone. For ns_host, enter in the URL you use to view NightScout in your web browser. For ns_api_secret, enter in the API secret from your NightScout. An example of a properly configured script is:
```
dexcom_username   => 'jsmith',
dexcom_password   => 'secretpassword',
...
ns_host           => 'http://user414.azure.com',
ns_api_secret     => 'secretapicodeword');
```

The rest of the configuration variables you should never have to change. If Dexcom changes the parameters used by the Share application at a later date, these variables make it easy to change them.

# Command-line parameters
```
Usage: share2ns-bridge.pl {options}

 Options:

   --minutes xx  - Number of minutes to query is xx (optional - default 1440)
   --maxcount yy - Maximum number of records to query is yy (optional - default 10)
   -q            - Quiet mode. Supress all output. (useful for cron)
```

Running without any command-line parameters is the same as requesting 1440 minutes of data to query, with a maximum of 10 records. This should allow the script to automatically catch-up if the Share app becomes disconnected from the CGM for a short period of time. If there is a large gap in NightScout, you can safely expand either value to synchronize any gaps. Pushing the data into NightScout multiple times will not cause any data duplication to occur. All data uploaded by this script is tagged as coming from the "share2" device in NightScout.

# Calling script from cron
Included below is an example crontab entry that can be used to call the script every four minutes to download 300 minutes of data with a maximum record count of 30 records.
```
0,4,8,12,16,20,24,28,32,36,40,44,48,52,56 * * * * /usr/local/bin/share2ns-bridge.pl -q --minutes 300 --maxcount 30
```

# About [NightScout](http://www.nightscout.info)
Nightscout (CGM in the Cloud) is an open source, DIY project that allows real time access to a Dexcom G4 CGM from web browsers via smartphones, computers, tablets, and the Pebble smartwatch. The goal of the project is to allow remote monitoring of the T1D’s glucose level using existing monitoring devices.

This script is not a part of the official NightScout project, but borrows from [Scott Hanselman's reverse engineering work](http://www.hanselman.com/blog/BridgingDexcomShareCGMReceiversAndNightscout.aspx) on the Dexcom Share application. 

Copyright 2015 Jon Marler

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0
