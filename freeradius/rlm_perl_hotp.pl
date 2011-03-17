# Code behaviour
use strict;
use warnings;

# External modules
use Authen::HOTP qw(hotp);
use Data::Dumper;
use Redis;

# Globals
use vars qw( %RAD_CONFIG %RAD_REQUEST %RAD_REPLY %RAD_CHECK %KEYS $redis $new_offset );

# Some utility constants
use constant false => 0;
use constant true  => 1;

# Some debugging control
use constant DEBUG_SUB => false;
use constant DEBUG_REQ => false;

# Radlog's constants
use constant L_DBG => 1;
use constant L_AUTH => 2;
use constant L_INFO => 3;
use constant L_ERR => 4;
use constant L_PROXY => 5;
use constant L_ACCT => 6;
use constant L_CONS => 128;

# Return code constants
use constant RLM_MODULE_REJECT => 0; # immediately reject the request 
use constant RLM_MODULE_FAIL => 1; # module failed, don't reply 
use constant RLM_MODULE_OK  => 2; # the module is OK, continue 
use constant RLM_MODULE_HANDLED  => 3; # the module handled the request, so stop. 
use constant RLM_MODULE_INVALID  => 4; # the module considers the request invalid. 
use constant RLM_MODULE_USERLOCK => 5; # reject the request (user is locked out) 
use constant RLM_MODULE_NOTFOUND => 6; # user not found 
use constant RLM_MODULE_NOOP  => 7; # module succeeded without doing anything 
use constant RLM_MODULE_UPDATED  => 8; # OK (pairs modified) 
use constant RLM_MODULE_NUMCODES => 9; # How many return codes there are

#############################################################################
# Internal subs
#############################################################################

# Connect on Redis
sub setup_redis {
	&log_sub if DEBUG_SUB;
	eval {
		$redis = Redis->new;
	};
	if ($@) {
		&radiusd::radlog(L_ERR, 'Cannot connect to Redis');
		return false;
	}
	return true;
}

# Setup key names that this script is going to use in Redis, acording to User-Name
sub setup_keys {
	&log_sub if DEBUG_SUB;
	my $username = $RAD_REQUEST{'User-Name'};
	$KEYS{'offset'} = "$username:offset";
	$KEYS{'secret'} = "$username:secret";
	$KEYS{'serial'} = "$username:serial";
}

# Check if all keys are in Redis
sub check_user_in_redis {
	&log_sub if DEBUG_SUB;
	for (keys %KEYS) {
		if (!$redis->exists($KEYS{$_})) {
			&radiusd::radlog(L_ERR, "Could not find key {$KEYS{$_}} in Redis");
			return false;
		}
	}
	return true;
}

# Check OTP if it's valid
sub check_otp {
	&log_sub if DEBUG_SUB;
	my ($otp, $offset, $secret, $window) = @_;
	my $counter = int(time / 60) + $offset;
	my $digits = length($otp);

	for (my($i) = -$window; $i <= $window; $i++) {
		my $pass = hotp($secret, $counter + $i, $digits);
		if ($pass == $otp) {
			$new_offset = $offset + $i;
			return true;
		}
	}

	&radiusd::radlog(L_DBG, "Invalid OTP. Check server's clock, offset sync, and OTP!");
	return false;
}

# Log calling sub name
sub log_sub {
	my $subname = (caller(1))[3];
	&radiusd::radlog(L_DBG, "$subname");
} 

# Logs things
sub log_request {
	for (keys %RAD_CHECK) {
		&radiusd::radlog(L_DBG, "RAD_CHECK: $_ = $RAD_CHECK{$_}");
	}
	for (keys %RAD_REPLY) {
		&radiusd::radlog(L_DBG, "RAD_REPLY: $_ = $RAD_REPLY{$_}");
	}
	for (keys %RAD_CONFIG) {
		&radiusd::radlog(L_DBG, "RAD_CONFIG: $_ = $RAD_CONFIG{$_}");
	}
	for (keys %RAD_REQUEST) {
		&radiusd::radlog(L_DBG, "RAD_REQUEST: $_ = $RAD_REQUEST{$_}");
	}
}

#############################################################################
# Subroutines called by FreeRadius
#############################################################################

# Check if user exists into Redis
sub authorize {
	&log_sub if DEBUG_SUB;
	&log_request if DEBUG_REQ;
	&setup_keys;
	return RLM_MODULE_FAIL unless &setup_redis;
	return RLM_MODULE_NOTFOUND unless &check_user_in_redis;
	return RLM_MODULE_OK;
}

# Authenticate User-Name's One-Time-Password
sub authenticate {
	&log_sub if DEBUG_SUB;
	&log_request if DEBUG_REQ;
	&setup_keys;
	return RLM_MODULE_FAIL unless &setup_redis;
	return RLM_MODULE_NOTFOUND unless &check_user_in_redis;

	return RLM_MODULE_INVALID unless exists $RAD_REQUEST{'One-Time-Password'};
	my $otp = $RAD_REQUEST{'One-Time-Password'};
	return RLM_MODULE_INVALID unless exists $RAD_CONFIG{'OTP-Window'};
	my $window = int($RAD_CONFIG{'OTP-Window'});
	my $offset = int($redis->get($KEYS{'offset'}));
	my $secret = $redis->get($KEYS{'secret'});
	my $serial = $redis->get($KEYS{'serial'});
	&radiusd::radlog(L_DBG, "Using offset $offset for token with serial $serial");

	return RLM_MODULE_REJECT unless &check_otp($otp, $offset, $secret, $window);
	#$redis->set($KEYS{'offset'}, $new_offset);
	return RLM_MODULE_OK;
}

# Function to handle detach
sub detach {
	&log_sub if DEBUG_SUB;
	&log_request if DEBUG_REQ;
	$redis->quit;
	return RLM_MODULE_NOOP
}

#############################################################################
# Unused subroutines called by FreeRadius. Must leave them here.
#############################################################################

# Function to handle preacct
sub preacct { return RLM_MODULE_NOOP; }
# Function to handle accounting
sub accounting { return RLM_MODULE_NOOP; }
# Function to handle checksimul
sub checksimul { return RLM_MODULE_NOOP; }
# Function to handle pre_proxy
sub pre_proxy { return RLM_MODULE_NOOP; }
# Function to handle post_proxy
sub post_proxy { return RLM_MODULE_NOOP; }
# Function to handle post_auth
sub post_auth { return RLM_MODULE_NOOP; }
# Function to handle xlat
sub xlat { return RLM_MODULE_NOOP }

