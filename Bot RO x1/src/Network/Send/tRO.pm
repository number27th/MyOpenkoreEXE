#################################################################################################
#  OpenKore - Network subsystem									#
#  This module contains functions for sending messages to the server.				#
#												#
#  This software is open source, licensed under the GNU General Public				#
#  License, version 2.										#
#  Basically, this means that you're allowed to modify and distribute				#
#  this software. However, if you distribute modified versions, you MUST			#
#  also distribute the source code.								#
#  See http://www.gnu.org/licenses/gpl.html for the full license.				#
#################################################################################################
# tRO (Thai)
package Network::Send::tRO;
use strict;
use Globals;
use Network::Send::ServerType0;
use base qw(Network::Send::ServerType0);
use Log qw(error debug);
use I18N qw(stringToBytes);
use Utils qw(getTickCount getHex getCoordString);
use Math::BigInt;

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	$self->{char_create_version} = 1;
	$self->{flag} = 1;
	$self->{seq} = 0;
	
	my %packets = (
		'0A76' => ['master_login', 'V Z40 a32 C', [qw(version username password_rijndael master_version)]],
		'0275' => ['game_login', 'a4 a4 a4 v C x16 v', [qw(accountID sessionID sessionID2 userLevel accountSex iAccountSID)]]
		);
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	
	my %handlers = qw(
		map_login 0436
		item_use 0439
		master_login 0A76
		game_login 0275
		character_move 035F
		sync 0360
		actor_look_at 0361
		item_take 0362
		item_drop 0363
		storage_item_add 0364
		storage_item_remove 0365
		skill_use_location 0366
		actor_info_request 0368
		actor_name_request 0369
		party_setting 07D7
		buy_bulk_vender 0801
		char_create 0970
		storage_password 023B
		send_equip 0998
	);
	
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
	#$self->cryptKeys(0x0, 0x0, 0x0);
	return $self;
}
1;