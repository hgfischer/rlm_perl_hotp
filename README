rlm_perl_hotp
=============

This is a HOTP/RFC-4226 authentication script that uses 
Redis as a backend for storing user/tokens information. 

I choose Redis because it's blazing fast and persists 
information in disk, but the script can be adapted to 
use another type of backend. I do not suggest using files 
as a backend since I planned to implement some kind of 
automatic offset adjustment during authentication.

FreeRadius configuration
------------------------

I've included some sample configuration files:

* modules-perl: configuration for the FreeRadius perl module;
* dictionary: I've added 2 attributes for the script, so they 
              must be configured in the FreeRadius dictionary;
* site-hotp: A virtual server configuration that works with 
             OTP+LDAP. It splits the password in two and 
             authenticate the first 6 digits as OTP and the 
             rest as password in LDAP;

Populating Redis
----------------

Redis must be populated with user and token information. It reads
a CSV-like file and load it's information into Redis. The file format
is username, token's serial number, initial offset, base64 encoded 
and cryptographed token's secret.

The column separator is "~" without the quotes.
