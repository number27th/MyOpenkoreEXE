#########################################################################
#  OpenKore - WxWidgets Interface
#  Inventory list control
#
#  Copyright (c) 2007 OpenKore development team 
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#
#  $Revision: 0001 $
#  $Id: Inventory.pm 0001 2007-02-13 22:00:00Z neuronet $
#########################################################################
#  modified:
#  ICQ 266048166 Click Wx-Interface v20 for OpenKore 2.0.5 and hight
#  Thank's IBotMan
#########################################################################
#########################################################################

package Interface::Wx::List::ItemList::Inventory;

use strict;
use Wx ':everything';
use Wx qw(:listctrl);
use Wx::Event qw(EVT_BUTTON EVT_MOTION EVT_LIST_ITEM_RIGHT_CLICK EVT_MENU EVT_TIMER);
use Wx::Event qw(EVT_LIST_ITEM_ACTIVATED);
use base qw(Wx::Panel);
use encoding 'utf8';
#use LWP::UserAgent;


use Globals;
use Log qw(message debug error warning);
use Settings;
use Utils;
use Misc;
use AI;
use Match;
use Translation;
use Commands;

my %bmpindex;
my %bmpfilename;
my $imglistindex;

my @all;
my @useable;
my @equipment;
my @uequipment;
my @non_useable;

my $master;
my $mouse_x;
my $mouse_y;

my $actuallist;
my $info;


sub new {
	my $class = shift;
	my ($parent, $id) = @_;
	my $self;

        # Create folder for downloading Bitmaps it not exists
	if (! -d "Bitmaps") {
		if (!mkdir("Bitmaps")) {
			die "Unable to create folder Bitmaps...";
		}
	}
        
 	$self = $class->SUPER::new($parent, $id);

        $master = $self;
        
        # Load  bitmapindex from file
	$self->loadbitmapindex;
        
        # Create ListControl for Items
        $self->{ItemList} = Wx::ListCtrl->new( $self, 5500, wxDefaultPosition,
                                wxDefaultSize, wxLC_REPORT|
                                wxSUNKEN_BORDER|wxLC_SINGLE_SEL );
        
        # Create Buttons
	$self->{btn_all} = new Wx::Button($self, 46, '&All');
	$self->{btn_all}->SetToolTip('Shows all items in inventory');
	$self->{btn_useable} = new Wx::Button($self, 47, '&Useable');
	$self->{btn_useable}->SetToolTip('Shows useable items in inventory');
	$self->{btn_nonuseable} = new Wx::Button($self, 48, '&Non Useable');
	$self->{btn_nonuseable}->SetToolTip('Shows non useable items in inventory');
	$self->{btn_equiped} = new Wx::Button($self, 49, '&Equipped');
	$self->{btn_equiped}->SetToolTip('Shows equipped items');
	$self->{btn_unequiped} = new Wx::Button($self, 50, 'N&ot Equipped');
	$self->{btn_unequiped}->SetToolTip('Shows not equipped items in inventory');

        # Create Sizers for Elements
	my $vsizer = $self->{vsizer} = new Wx::BoxSizer(wxVERTICAL);
	my $btn_sizer_1 = new Wx::BoxSizer(wxHORIZONTAL);
	my $btn_sizer_2 = new Wx::BoxSizer(wxHORIZONTAL);
	my $btn_sizer_3 = new Wx::BoxSizer(wxHORIZONTAL);
	my $btn_sizer_4 = new Wx::BoxSizer(wxHORIZONTAL);

        # Arrange Sizers and Elements in Panel 
	$self->SetSizer($vsizer);
	$vsizer->Add($self->{ItemList}, 3, wxGROW);
	$vsizer->Add($btn_sizer_1, 0, wxBOTTOM | wxGROW);
        $btn_sizer_1->Add($btn_sizer_2, 0, wxBOTTOM);
        $btn_sizer_1->Add($btn_sizer_3, 0, wxBOTTOM);
        $btn_sizer_2->Add($btn_sizer_4, 0, wxBOTTOM);
	$btn_sizer_4->Add($self->{btn_all}, 80);
	$btn_sizer_4->Add($self->{btn_useable}, 80);
	$btn_sizer_2->Add($self->{btn_nonuseable}, 80);
	$btn_sizer_3->Add($self->{btn_equiped}, 80);
	$btn_sizer_3->Add($self->{btn_unequiped}, 80);
       
        # Insert Columns in ListControl and set Properties
        $self->{ItemList}->InsertColumn( 0, "Item" );
        $self->{ItemList}->InsertColumn( 1, "Slot" );
        $self->{ItemList}->InsertColumn( 2, "Type" );
        $self->{ItemList}->InsertColumn( 3, "Name" );
        $self->{ItemList}->InsertColumn( 4, "Amount" );
        $self->{ItemList}->SetTextColour( wxBLUE );
        $self->{ItemList}->SetBackgroundColour( wxLIGHT_GREY );
        $self->{ItemList}->SetColumnWidth( 0, 50 );
        $self->{ItemList}->SetColumnWidth( 1, 50 );
        $self->{ItemList}->SetColumnWidth( 2, 100 );
        $self->{ItemList}->SetColumnWidth( 3, 200 );
        $self->{ItemList}->SetColumnWidth( 4, 100 );

        # Create ImageList fr Item-Icons
        $self->{IMAGELISTSMALL} = Wx::ImageList->new( 24, 24, 1 );
        $self->{IMAGELISTSMALL}->Add( Wx::GetWxPerlIcon( 1 ) );		
        $self->{ItemList}->SetImageList( $self->{IMAGELISTSMALL}, wxIMAGE_LIST_SMALL );

        # Set Mouse-Events for Buttons
        EVT_BUTTON($self->{btn_all}, -1, sub{_ListItems(1)});
        EVT_BUTTON($self->{btn_useable}, -1, sub{_ListItems(2)});
        EVT_BUTTON($self->{btn_nonuseable}, -1, sub{_ListItems(3)});
        EVT_BUTTON($self->{btn_equiped}, -1, sub{_ListItems(4)});
        EVT_BUTTON($self->{btn_unequiped}, -1, sub{_ListItems(5)});
		EVT_LIST_ITEM_RIGHT_CLICK($self->{ItemList}, -1, \&_onRightClick);
	EVT_LIST_ITEM_ACTIVATED($self->{ItemList}, -1, \&_onDblClick);
	EVT_MOTION($self->{ItemList}, \&_onMotion);
        $imglistindex=0;
    
        # Display ALL Items in ListControl
if ($char) {
        _ListItems(1);

	my $timer = new Wx::Timer($self, 246);
	EVT_TIMER($self, 246, \&_updateListCtrl);
	$timer->Start(200, 0);
}
	return $self;
}

sub loadbitmapindex {
        my $this = shift;
        
        undef %bmpfilename;
	undef %bmpindex;
#        _downloadFile("num2itemresnametable.txt"); 
	open FILE, "<", "Bitmaps/items/num2itemresnametable.txt";
	foreach (<FILE>) {
		s/[\r\n\x{FEFF}]//g;
		next if (length($_) == 0 || /^\/\//);
		my ($id, $filename) = split /#/, $_, 3;
		if ($id ne "" && $filename ne "") {
                        $bmpfilename{$id}=$filename;
                        $bmpindex{$id}="NA";
		}
	}
	close FILE;
}

# Load Items into Categories
sub getItems {
        my @empty;
        @all = @empty;
        @useable = @empty;
        @equipment = @empty;
        @uequipment = @empty;
        @non_useable = @empty;
        undef @empty;
		foreach my $item (@{$char->inventory->getItems()}) {
			if (($item->{type} == 3 ||
			     $item->{type} == 6 ||
			     $item->{type} == 10 ||
			     $item->{type} == 16 ||
			     $item->{type} == 17) && !$item->{equipped}) {
				push @non_useable, $item->{invIndex};
                        push @all, $item->{invIndex};
                } elsif ($item->{type} <= 2) {
                        push @useable, $item->{invIndex};
                        push @all, $item->{invIndex};
                } else {
                        if ($item->{equipped}) {
                                push @equipment, $item->{invIndex};
                                push @all, $item->{invIndex};
                        } else {
                                push @uequipment, $item->{invIndex};
                                push @all, $item->{invIndex};
                        }
                }
        }
}

sub _addItem {
        my ($item_id, $i, $index, $item_type_name, $item_name, $item_amount) = @_;

        my $bmpid = $bmpindex{$item_id};

        if ($bmpid eq "NA") {
                my $filename = "Bitmaps/items/".$item_id.".bmp";
                my $bitmap = Wx::Bitmap->new( "$filename", wxBITMAP_TYPE_BMP );
                if ($bitmap->Ok) {
                        $master->{IMAGELISTSMALL}->Add($bitmap, Wx::Colour->new(0,0,0));
                        $imglistindex++;
                        $bmpindex{$item_id} = $imglistindex;
                }
                else {
#                        _downloadFile("$item_id.bmp"); 
                        my $filename = "Bitmaps/items/".$item_id.".bmp";
                        my $bitmap = Wx::Bitmap->new( "$filename", wxBITMAP_TYPE_BMP );
                        if ($bitmap->Ok) {
                                $master->{IMAGELISTSMALL}->Add($bitmap, Wx::Colour->new(0,0,0));
                                $imglistindex++;
                                $bmpindex{$item_id} = $imglistindex;
                        }
                        else {
                                $bmpindex{$item_id} = 0;
                        }
                }
                $bmpid = $bmpindex{$item_id};
        }
        
        my $id = $master->{ItemList}->InsertImageItem( $i, $bmpid);
        $master->{ItemList}->SetItem( $id, 1, $index );
        $master->{ItemList}->SetItem( $id, 2, $item_type_name);
        $master->{ItemList}->SetItem( $id, 3, $item_name);
        $master->{ItemList}->SetItem( $id, 4, $item_amount);			
}

sub _ListItems {
        my ($button) = @_;

        getItems;
        
        my @itemarray;

        $master->{btn_all}->Enable(1);        
        $master->{btn_useable}->Enable(1);        
        $master->{btn_nonuseable}->Enable(1);        
        $master->{btn_equiped}->Enable(1);        
        $master->{btn_unequiped}->Enable(1);
        if ($button eq 1) {
                @itemarray=@all;
        } elsif ($button eq 2) {
                @itemarray=@useable;
        } elsif ($button eq 3) {
                @itemarray=@non_useable;
        } elsif ($button eq 4) {
                @itemarray=@equipment;
        } elsif ($button eq 5) {
                @itemarray=@uequipment;
        }
        
        $actuallist = $button;
        
        $master->{ItemList}->DeleteAllItems;
        
        if (@itemarray ne 0) {
                for (my $i = 0; $i < @itemarray; $i++) {
                        my $index = $itemarray[$i];
 
		my $item = $char->inventory->get($index);

                       my $item_id = $item->{nameID};
                        my $item_type = $item->{type};
                        my $item_type_name = $itemTypes_lut{$item_type};
                        my $item_name = $item->{name};
                        my $ident = ("Not Identified") if !$item->{identified};
                        my $item_amount = "$item->{amount} $ident";
                                 
                        _addItem($item_id, $i, $index, $item_type_name, $item_name, $item_amount);        
                }
        }
        
        
}

sub _updateListCtrl {

	# Get actual Inventory Array
        getItems;
        
        # Which list is actually displayer?
	# Copy viewed list to @itemarray
        my @itemarray;

        if ($actuallist eq 1) {
                @itemarray=@all;
        } elsif ($actuallist eq 2) {
                @itemarray=@useable;
        } elsif ($actuallist eq 3) {
                @itemarray=@non_useable;
        } elsif ($actuallist eq 4) {
                @itemarray=@equipment;
        } elsif ($actuallist eq 5) {
                @itemarray=@uequipment;
        }
        
	# Update Inventory-View
        if (@itemarray ne 0) {
		my $listctrl_count = 0;
		for (my $l=0; $l < @itemarray; $l++) {
			# Get actual Item from Inventory-Array
			my $index = $itemarray[$l];

			my $item = $char->inventory->get($index);

			my $item_id = $item->{nameID};
			my $item_type = $item->{type};
			my $item_type_name = $itemTypes_lut{$item_type};
			my $item_name = $item->{name};
			my $item_amount = $item->{amount};
	
			my $listcount = $master->{ItemList}->GetItemCount;
                        
                        my $list_index;
                        my $list_type_name;
                        my $list_name;
                        my $list_amount;
                        
                        my $list_end;
                        
                        if ($listctrl_count < $listcount) {
                                $list_index = ( $master->{ItemList}->GetItem( $listctrl_count, 1 ) );
                                $list_index = $list_index->GetText;
                                $list_type_name = ( $master->{ItemList}->GetItem( $listctrl_count, 2 ) );
                                $list_type_name = $list_type_name->GetText;
                                $list_name = ( $master->{ItemList}->GetItem( $listctrl_count, 3 ) );
                                $list_name = $list_name->GetText;
                                $list_amount = ( $master->{ItemList}->GetItem( $listctrl_count, 4 ) );
                                $list_amount = $list_amount->GetText;
        
                                if ($index eq $list_index) {
                                        if ($item_amount != $list_amount) {
                                                $master->{ItemList}->SetItem( $listctrl_count, 4, $item_amount);
                                        }
                                        $listctrl_count++;
                                }
                                elsif ($index < $list_index) {
                                        _addItem($item_id, $l, $index, $item_type_name, $item_name, $item_amount);
                                        $listctrl_count++;
                                }
                                else {
                                        $master->{ItemList}->DeleteItem($listctrl_count);
                                        $l--;
                                }
                        }
                        elsif ($listctrl_count == $listcount) {
                                _addItem($item_id, $l, $index, $item_type_name, $item_name, $item_amount);
                                $listctrl_count++;
                        }
		}
                my $item_count = @itemarray;
                my $list_count = $master->{ItemList}->GetItemCount;
                while ($item_count < $list_count) {
                        $master->{ItemList}->DeleteItem($item_count);
                        $list_count = $master->{ItemList}->GetItemCount;                                
                }
                
	}
	else {
	        $master->{ItemList}->DeleteAllItems;
	}
}

sub _onMotion {
	my $self = shift;
	my $event = shift;
	$mouse_x = $event->GetX;
	$mouse_y = $event->GetY;
}

sub _onRightClick {
	my ($this, $event) = @_;
	my $item = $char->inventory->get($info);
	my $type = $itemTypes_lut{$item->{type}};

        $info = ( $this->GetItem( $event->GetIndex, 1 ) );
        $info = $info->GetText;
        my $item_id = $item->{nameID};
        my $item_name= $item->{name};
        my $item_amount = $item->{amount};

	my $menuPopUp = Wx::Menu->new($item_name . " Options:");
	
	if ($type eq "Usable") {	
		$menuPopUp->Append(1, "Self Use Item (is)");
		EVT_MENU($menuPopUp, 1, \&_on_self_use);
	}

	if ($type eq "Usable Heal") {	
		$menuPopUp->Append(1, "Self Use Item (is)");
		EVT_MENU($menuPopUp, 1, \&_on_self_use);
	}

	if ($type eq "Usable Special") {	
		$menuPopUp->Append(1, "Self Use Item (is)");
		EVT_MENU($menuPopUp, 1, \&_on_self_use);
	}

	if ($type eq "Armour") {
		if ($item->{equipped}) {
			$menuPopUp->Append(2, "Unequip");
			EVT_MENU($menuPopUp, 2, \&_on_unequip);
		}

		else {
			$menuPopUp->Append(2, "Equip");
			EVT_MENU($menuPopUp, 2, \&_on_equip);
		}
	}

	if ($type eq "Weapon") {
		if ($item->{equipped}) {
			$menuPopUp->Append(2, "Unequip");
			EVT_MENU($menuPopUp, 2, \&_on_unequip);
		}

		else {
			$menuPopUp->Append(2, "Equip");
			EVT_MENU($menuPopUp, 2, \&_on_equip);
		}
	}

	if ($type eq "Arrows") {
		if ($item->{equipped}) {
			$menuPopUp->Append(2, "Unequip");
			EVT_MENU($menuPopUp, 2, \&_on_unequip);
		}

		else {
			$menuPopUp->Append(2, "Equip");
			EVT_MENU($menuPopUp, 2, \&_on_equip);
		}
	}
	$menuPopUp->Append(3, "Drop 1");
        EVT_MENU($menuPopUp, 3, \&_on_drop_one);
        
	if ($item_amount > 1) {
                $menuPopUp->Append(4, "Drop all (".$item_amount.")");
                EVT_MENU($menuPopUp, 4, \&_on_drop_all);
        }

	if ($item_amount > 1) {
                $menuPopUp->Append(4, "sell (".$item_amount.")");
                EVT_MENU($menuPopUp, 4, \&_on_sell_all);
        }

	if ($item_amount > 1) {
                $menuPopUp->Append(4, "Deal (".$item_amount.")");
                EVT_MENU($menuPopUp, 4, \&_on_deal_all);
        }
        
	$master->PopupMenu($menuPopUp, $mouse_x+20, $mouse_y);
}

sub _onDblClick {
	my ($this, $event) = @_;
        $info = ( $this->GetItem( $event->GetIndex, 1 ) );
        $info = $info->GetText;
	my $i_type = ( $this->GetItem( $event->GetIndex, 2 ) );
	my $i_type = $i_type->GetText;
	if ($i_type eq "Usable") {
		my $command = "is " . $info;
		Commands::run($command);
	}
	if ($i_type eq "Usable Heal") {
		my $command = "is " . $info;
		Commands::run($command);
	}
	if ($i_type eq "Usable Special") {
		my $command = "is " . $info;
		Commands::run($command);
	}
	if ($i_type eq "Armour") {
		my $command = "eq " . $info;
		Commands::run($command);
	}
	if ($i_type eq "Weapon") {
		my $command = "eq " . $info;
		Commands::run($command);
	}
	if ($i_type eq "Arrows") {
		my $command = "eq " . $info;
		Commands::run($command);
	}
}

sub _on_self_use {
        my $command = "is " . $info;
	my $item = $char->inventory->get($info);
	if ($item->{nameID}) {
		Commands::run($command);
	}
}

sub _on_unequip {
        my $command = "uneq " . $info;
	my $item = $char->inventory->get($info);
	if ($item->{nameID}) {
        Commands::run($command) if $item->{nameID};
	}
}
sub _on_equip {
        my $command = "eq " . $info;
	my $item = $char->inventory->get($info);
	if ($item->{nameID}) {
        Commands::run($command) if $item->{nameID};
	}
}

sub _on_drop_one {
        my $command = "drop " . $info . " 1";
	my $item = $char->inventory->get($info);
	if ($item->{nameID}) {
        Commands::run($command) if $item->{nameID};
	}
}

sub _on_drop_all {
        my $command = "drop " . $info;
	my $item = $char->inventory->get($info);
	if ($item->{nameID}) {
        Commands::run($command) if $item->{nameID};
	}
}

sub _on_sell_all {
        my $command = "sell " . $info;
	my $item = $char->inventory->get($info);
	if ($item->{nameID}) {
        Commands::run($command) if $item->{nameID};
		Commands::run("sell done")
	}
}

sub _on_deal_all {
        my $command = "deal add " . $info;
	my $item = $char->inventory->get($info);
	if ($item->{nameID}) {
        Commands::run($command) if $item->{nameID};
	}
}

1;