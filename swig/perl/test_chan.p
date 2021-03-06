#!/usr/bin/perl

# test_chan
#
# Test of the MC channel and user code.
#
# Author: MontaVista Software, Inc.
#         Corey Minyard <minyard@mvista.com>
#         source@mvista.com
#
# Copyright 2004 MontaVista Software Inc.
#
#  This program is free software; you can redistribute it and/or
#  modify it under the terms of the GNU Lesser General Public License
#  as published by the Free Software Foundation; either version 2 of
#  the License, or (at your option) any later version.
#
#
#  THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED
#  WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
#  MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
#  IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
#  INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
#  BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS
#  OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
#  ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR
#  TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
#  USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
#  You should have received a copy of the GNU Lesser General Public
#  License along with this program; if not, write to the Free
#  Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#

use Lanserv;
use OpenIPMI;

my $errcountholder : shared = 0;
$errcount = \$errcountholder;

my $fru_field_table = {};

sub reg_err {
    my $str = shift;

    $$errcount++;
    print STDERR "***", $str, "\n";
}

sub get_errcount {
    return $$errcount;
}

{
    package CloseDomain;
    sub new {
	my $a = shift;
	my $b = \$a;
	$b = bless $b;
	return $b;
    }

    sub domain_cb {
	my $self = shift;
	my $domain = shift;

	$domain->close($$self);
    }

    package aaa;

    sub new {
	my $self = shift;
	my $a = {};
	$a->{handler} = shift;
	return bless \$a;
    }

    package Handlers;

    sub new {
	my $a = {};
	$a->{keepon} = 1;
	$a->{accmode} = 0;
	return bless \$a;
    }

    sub log {
	my $self = shift;
	my $level = shift;
	my $log = shift;

	print $level, ": ", $log, "\n";
    }

    sub mc_channel_set_user_cb {
	my $self = shift;
	my $mc = shift;
	my $err = shift;

	if ($err) {
	    main::reg_err("Error setting user: $err");
	    $self->close();
	    return;
	}

	print "Set user\n";

	$rv = $mc->get_users(7, 3, $self);
	if ($rv) {
	    main::reg_err("Unable to get users(1): $rv\n");
	    $self->close();
	    return;
	}
    }

    sub mc_channel_got_users_cb {
	my $self = shift;
	my $mc = shift;
	my $err = shift;
	my $max_user = shift;
	my $enabled_users = shift;
	my $fixed_users = shift;
	my $user = shift;
	my $val;
	my $rv;

	if ($err) {
	    main::reg_err("Error getting user: $err");
	    $self->close();
	    return;
	}

	print "Got user: $$self->{accmode}\n";

	$rv = $user->get_channel(\$val);
	if ($rv) {
	    main::reg_err("Error getting channel");
	} elsif ($val != 7) {
	    main::reg_err("Channel not 7: $val");
	}

	$rv = $user->get_num(\$val);
	if ($rv) {
	    main::reg_err("Error getting num");
	} elsif ($val != 3) {
	    main::reg_err("num not 3");
	}

	if ($$self->{accmode} == 2) {
	    $val = $user->get_name();
	    if ($val ne "") {
		main::reg_err("user name not empty: $val");
	    }

	    $rv = $user->get_link_auth_enabled(\$val);
	    if ($rv) {
		main::reg_err("Error getting link_auth_enabled");
	    } elsif ($val != 0) {
		main::reg_err("link_auth_enabled not 0: $val");
	    }

	    $rv = $user->get_msg_auth_enabled(\$val);
	    if ($rv) {
		main::reg_err("Error getting msg_auth_enabled");
	    } elsif ($val != 0) {
		main::reg_err("msg_auth_enabled not 0: $val");
	    }

	    $rv = $user->get_access_cb_only(\$val);
	    if ($rv) {
		main::reg_err("Error getting access_cb_only");
	    } elsif ($val != 0) {
		main::reg_err("access_cb_only not 0: $val");
	    }

	    $rv = $user->get_privilege_limit(\$val);
	    if ($rv) {
		main::reg_err("Error getting privilege_limit");
	    } elsif ($val != 0) {
		main::reg_err("privilege_limit not 0: $val");
	    }

	    $rv = $user->set_name("asdfasdf");
	    if ($rv) {
		main::reg_err("Error setting name");
	    }

	    $rv = $user->set_password("asdfasdf");
	    if ($rv) {
		main::reg_err("Error setting password");
	    }

	    $rv = $user->set_enable(1);
	    if ($rv) {
		main::reg_err("Error setting enable");
	    }

	    $rv = $user->set_link_auth_enabled(1);
	    if ($rv) {
		main::reg_err("Error setting link_auth_enabled");
	    }

	    $rv = $user->set_msg_auth_enabled(1);
	    if ($rv) {
		main::reg_err("Error setting msg_auth_enabled");
	    }

	    $rv = $user->set_access_cb_only(1);
	    if ($rv) {
		main::reg_err("Error setting access_cb_only");
	    }

	    $rv = $user->set_privilege_limit($OpenIPMI::PRIVILEGE_ADMIN);
	    if ($rv) {
		main::reg_err("Error setting privilege_limit");
	    }

	    $rv = $user->set_session_limit(0);
	    if ($rv) {
		main::reg_err("Error setting session_limit");
	    }

	    $rv = $mc->set_user($user, 7, 3, $self);
	    if ($rv) {
		main::reg_err("Unable to set user: $rv\n");
		$self->close();
		return;
	    }

	    $$self->{accmode} = 3;

	} elsif ($$self->{accmode} == 3) {
	    $val = $user->get_name();
	    if ($val ne "asdfasdf") {
		main::reg_err("user name not asdfasdf");
	    }

	    $rv = $user->get_link_auth_enabled(\$val);
	    if ($rv) {
		main::reg_err("Error getting link_auth_enabled");
	    } elsif ($val != 1) {
		main::reg_err("link_auth_enabled not 1");
	    }

	    $rv = $user->get_msg_auth_enabled(\$val);
	    if ($rv) {
		main::reg_err("Error getting msg_auth_enabled");
	    } elsif ($val != 1) {
		main::reg_err("msg_auth_enabled not 1");
	    }

	    $rv = $user->get_access_cb_only(\$val);
	    if ($rv) {
		main::reg_err("Error getting access_cb_only");
	    } elsif ($val != 1) {
		main::reg_err("access_cb_only not 1");
	    }

	    $rv = $user->get_privilege_limit(\$val);
	    if ($rv) {
		main::reg_err("Error getting privilege_limit");
	    } elsif ($val != $OpenIPMI::PRIVILEGE_ADMIN) {
		main::reg_err("privilege_limit not admin: $val");
	    }

	    $self->close();
	}
    }

    sub mc_channel_set_access_cb {
	my $self = shift;
	my $mc = shift;
	my $err = shift;

	if ($err) {
	    main::reg_err("Error setting channel access: $err");
	    $self->close();
	    return;
	}

	print "Set channel access\n";

	$rv = $mc->channel_get_access(7, "nonvolatile", $self);
	if ($rv) {
	    main::reg_err("Unable to get channel access(1): $rv\n");
	    $self->close();
	    return;
	}
    }

    sub mc_channel_got_access_cb {
	my $self = shift;
	my $mc = shift;
	my $err = shift;
	my $acc = shift;
	my $rv;
	my $val;

	if ($err) {
	    main::reg_err("Error getting channel access");
	    $self->close();
	    return;
	}

	print "Got channel access: $$self->{accmode}\n";

	$rv = $acc->get_channel(\$val);
	if ($rv) {
	    main::reg_err("Error getting channel");
	} elsif ($val != 7) {
	    main::reg_err("Channel not 7");
	}

	if ($$self->{accmode} == 0) {
	    $rv = $acc->get_alerting_enabled(\$val);
	    if ($rv) {
		main::reg_err("Error getting alerting_enabled");
	    } elsif ($val != 1) {
		main::reg_err("alerting_enabled not 1");
	    }

	    $rv = $acc->get_per_msg_auth(\$val);
	    if ($rv) {
		main::reg_err("Error getting per_msg_auth");
	    } elsif ($val != 1) {
		main::reg_err("per_msg_auth not 1");
	    }

	    $rv = $acc->get_user_auth(\$val);
	    if ($rv) {
		main::reg_err("Error getting user_auth");
	    } elsif ($val != 1) {
		main::reg_err("user_auth not 1");
	    }

	    $rv = $acc->get_access_mode(\$val);
	    if ($rv) {
		main::reg_err("Error getting access_mode");
	    } elsif ($val != $OpenIPMI::CHANNEL_ACCESS_MODE_ALWAYS) {
		main::reg_err("access_mode not always");
	    }

	    $rv = $acc->get_privilege_limit(\$val);
	    if ($rv) {
		main::reg_err("Error getting privilege_limit");
	    } elsif ($val != 4) {
		main::reg_err("privilege_limit(2) not 4: $val");
	    }

	    # Sort of test these, but the simulator doesn't support
	    # turning these off.
	    $rv = $acc->set_alerting_enabled(1);
	    if ($rv) {
		main::reg_err("Error setting alerting_enabled");
	    }

	    $rv = $acc->set_per_msg_auth(1);
	    if ($rv) {
		main::reg_err("Error setting per_msg_auth");
	    }

	    $rv = $acc->set_user_auth(1);
	    if ($rv) {
		main::reg_err("Error setting user_auth");
	    }

	    $rv = $acc->set_privilege_limit($OpenIPMI::PRIVILEGE_ADMIN);
	    if ($rv) {
		main::reg_err("Error setting privilege_limit");
	    }

	    $rv = $mc->channel_set_access($acc, 7, "nonvolatile", $self);
	    if ($rv) {
		main::reg_err("Unable to set channel access(1): $rv\n");
		$self->close();
		return;
	    }

	    $$self->{accmode} = 1;

	} elsif ($$self->{accmode} == 1) {
	    $rv = $acc->get_alerting_enabled(\$val);
	    if ($rv) {
		main::reg_err("Error getting alerting_enabled");
	    } elsif ($val != 1) {
		main::reg_err("alerting_enabled not 1");
	    }

	    $rv = $acc->get_per_msg_auth(\$val);
	    if ($rv) {
		main::reg_err("Error getting per_msg_auth");
	    } elsif ($val != 1) {
		main::reg_err("per_msg_auth not 1");
	    }

	    $rv = $acc->get_user_auth(\$val);
	    if ($rv) {
		main::reg_err("Error getting user_auth");
	    } elsif ($val != 1) {
		main::reg_err("user_auth not 1");
	    }

	    $rv = $acc->get_access_mode(\$val);
	    if ($rv) {
		main::reg_err("Error getting access_mode");
	    } elsif ($val != $OpenIPMI::CHANNEL_ACCESS_MODE_ALWAYS) {
		main::reg_err("access_mode not always");
	    }

	    $rv = $acc->get_privilege_limit(\$val);
	    if ($rv) {
		main::reg_err("Error getting privilege_limit");
	    } elsif ($val != $OpenIPMI::PRIVILEGE_ADMIN) {
		main::reg_err("privilege_limit not admin: $val");
	    }

	    $$self->{accmode} = 2;
	    $rv = $mc->get_users(7, 3, $self);
	    if ($rv) {
		main::reg_err("Unable to get users(1): $rv\n");
		$self->close();
		return;
	    }
	}
    }

    sub mc_channel_got_info_cb {
	my $self = shift;
	my $mc = shift;
	my $err = shift;
	my $info = shift;
	my $rv;
	my $channel;
	my $medium;
	my $protocol;
	my $session_sup;
	my $vendor_id;
	my $aux_info;

	if ($err) {
	    main::reg_err("Error getting channel info: $err");
	    $self->close();
	    return;
	}

	print "Got channel info\n";

	$rv = $info->get_channel(\$channel);
	if ($rv) {
	    main::reg_err("Error getting channel");
	} elsif ($channel != 7) {
	    main::reg_err("Channel not 7");
	}

	$rv = $info->get_medium(\$medium);
	if ($rv) {
	    main::reg_err("Error getting medium");
	} elsif ($medium != $OpenIPMI::CHANNEL_MEDIUM_8023_LAN) {
	    main::reg_err("medium not LAN");
	}

	$rv = $info->get_protocol_type(\$protocol);
	if ($rv) {
	    main::reg_err("Error getting protocol");
	} elsif ($protocol != $OpenIPMI::CHANNEL_PROTOCOL_IPMB) {
	    main::reg_err("Protocol not IPMB: was $protocol");
	}

	$rv = $info->get_session_support(\$session_sup);
	if ($rv) {
	    main::reg_err("Error getting session support");
	} elsif ($session_sup != $OpenIPMI::CHANNEL_MULTI_SESSION) {
	    main::reg_err("Session support not multi-session");
	}

	$vendor_id = $info->get_vendor_id();
	if ($vendor_id ne "0xf2 0x1b 0x00") {
	    main::reg_err("Vendor id incorrect");
	}

	$aux_info = $info->get_aux_info();
	if ($aux_info ne "0x00 0x00") {
	    main::reg_err("aux info incorrect");
	}

	$rv = $mc->channel_get_access(7, "nonvolatile", $self);
	if ($rv) {
	    main::reg_err("Unable to get channel access(1): $rv\n");
	    $self->close();
	    return;
	}
    }

    sub mc_update_cb {
	my $self = shift;
	my $op = shift;
	my $domain = shift;
	my $mc = shift;
	my $rv;

	if ($op eq "added") {
	    print $op, " MC ", $mc->get_name(), "\n";
	    $rv = $mc->channel_get_info(7, $self);
	    if ($rv) {
		main::reg_err("Unable to get channel info: $rv\n");
		$self->close();
		return;
	    }
	}
    }

    sub conn_change_cb {
	my $self = shift;
	my $domain = shift;
	my $err = shift;
	my $conn_num = shift;
	my $port_num = shift;
	my $still_connected = shift;
	my $rv;

	if ($err) {
	    main::reg_err("Error starting up IPMI connection: $err");
	    $self->close();
	    return;
	}

	print "Connection up!\n";
	$rv = $domain->add_mc_update_handler($self);
	if ($rv) {
	    main::reg_err("Unable to add mc updated handler: $rv\n");
	    $self->close();
	    return;
	}
    }

    sub domain_close_done_cb {
	my $self = shift;

	$$self->{keepon} = 0;
    }

    sub close {
	my $self = shift;
	my $domain = shift;

	if (defined $$self->{domain_id}) {
	    my $v = CloseDomain::new($self);
	    $$self->{domain_id}->to_domain($v);
	} else {
	    $$self->{keepon} = 0;
	}
    }

}

package main;

$lanserv = Lanserv->new();
if (! $lanserv) {
    main::reg_err("Unable to start lanserv");
    exit(1);
}

# Add a BMC
$lanserv->cmd("mc_add 0x20 0 has-device-sdrs 0x23 9 8 0x1f 0x1291 0xf02");
$lanserv->cmd("mc_enable 0x20");

sleep 1;

#OpenIPMI::enable_debug_msg();
OpenIPMI::enable_debug_malloc();

# Now start OpenIPMI
$rv = OpenIPMI::init();
if ($rv != 0) {
    print "init failed";
    exit 1;
}

$h = Handlers::new();

OpenIPMI::set_log_handler($h);

@args = ( "-noseteventrcvr",
	  "lan", "-p", "9000", "-U", "minyard", "-P", "test", "localhost");
$$h->{domain_id} = OpenIPMI::open_domain2("test", \@args, $h, \undef);
if (! $$h->{domain_id}) {
    $lanserv->close();
    print "IPMI open failed\n";
    exit 1;
}

while ($$h->{keepon}) {
    OpenIPMI::wait_io(1000);
}

$lanserv->close();
OpenIPMI::shutdown_everything();
exit main::get_errcount();
