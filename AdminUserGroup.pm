# --
# Copyright (C) 2001-2020 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::Modules::AdminUserGroup;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $ParamObject  = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $GroupObject  = $Kernel::OM->Get('Kernel::System::Group');
    my $UserObject   = $Kernel::OM->Get('Kernel::System::User');

    my $Search = $ParamObject->GetParam( Param => 'Search' ) || '';
    my $Limit  = $ParamObject->GetParam( Param => 'Limit' )  || '';

    # ------------------------------------------------------------ #
    # user <-> group 1:n
    # ------------------------------------------------------------ #
    if ( $Self->{Subaction} eq 'User' ) {

        # get user id
        my $ID = $ParamObject->GetParam( Param => 'ID' );

        # get user data
        my %UserData = $UserObject->GetUserData(
            UserID        => $ID,
            NoOutOfOffice => 1,
        );

        my %Types;
        my %GroupData;

        # get permission list groups
        for my $Type ( @{ $ConfigObject->Get('System::Permission') } ) {
            my %Data = $GroupObject->PermissionUserGroupGet(
                UserID => $ID,
                Type   => $Type,
            );

            $Types{$Type} = \%Data;
            %GroupData = ( %GroupData, %Data );
        }

        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar();

        $Output .= $Self->_Change(
            %Types,
            Data => \%GroupData,
            ID   => $UserData{UserID},
            Name => "$UserData{UserFullname}",
            Type => 'User',
        );

        $Output .= $LayoutObject->Footer();
        return $Output;
    }

    # ------------------------------------------------------------ #
    # group <-> user n:1
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'Group' ) {

        # get group id
        my $ID = $ParamObject->GetParam( Param => 'ID' );

        # get group data
        my %GroupData = $GroupObject->GroupGet(
            ID => $ID,
        );

        my %Types;
        my %UserData;

        # get permission list users
        for my $Type ( @{ $ConfigObject->Get('System::Permission') } ) {
            my %Data = $GroupObject->PermissionGroupUserGet(
                GroupID => $ID,
                Type    => $Type,
            );

            $Types{$Type} = \%Data;
            %UserData     = ( %UserData, %Data );
        }

        # get user name
        USERID:
        for my $UserID ( sort keys %UserData ) {
            my $Name = $UserObject->UserName(
                UserID        => $UserID,
                NoOutOfOffice => 1,
            );
            next USERID if !$Name;

            $UserData{$UserID} .= " ($Name)";
        }

        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar();

        $Output .= $Self->_Change(
            %Types,
            Data => \%UserData,
            ID   => $GroupData{ID},
            Name => $GroupData{Name},
            Type => 'Group',
        );

        $Output .= $LayoutObject->Footer();
        return $Output;
    }

    # ------------------------------------------------------------ #
    # add user to groups
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'ChangeGroup' ) {

        # challenge token check for write action
        $LayoutObject->ChallengeTokenCheck();

        my $ID = $ParamObject->GetParam( Param => 'ID' ) || '';

        # get new groups
        my %Permissions;
        for my $Type ( @{ $ConfigObject->Get('System::Permission') } ) {
            my @IDs = $ParamObject->GetArray( Param => $Type );
            $Permissions{$Type} = \@IDs;
        }

        # get group data
        my %UserData = $UserObject->UserList(
            Valid         => 1,
            NoOutOfOffice => 1,
        );

        my %NewPermission;
        for my $UserID ( sort keys %UserData ) {
            for my $Permission ( sort keys %Permissions ) {
                $NewPermission{$Permission} = 0;
                my @Array = @{ $Permissions{$Permission} };

                ID:
                for my $ID (@Array) {
                    next ID if !$ID;
                    if ( $UserID == $ID ) {
                        $NewPermission{$Permission} = 1;
                    }
                }
            }

            $GroupObject->PermissionGroupUserAdd(
                UID        => $UserID,
                GID        => $ID,
                Permission => \%NewPermission,
                UserID     => $Self->{UserID},
            );
        }

        # if the user would like to continue editing the group-user relation just redirect to the edit screen
        # otherwise return to relations overview
        if (
            defined $ParamObject->GetParam( Param => 'ContinueAfterSave' )
            && ( $ParamObject->GetParam( Param => 'ContinueAfterSave' ) eq '1' )
            )
        {
            return $LayoutObject->Redirect( OP => "Action=$Self->{Action};Subaction=Group;ID=$ID" );
        }

        return $LayoutObject->Redirect( OP => "Action=$Self->{Action}" );
    }

    # ------------------------------------------------------------ #
    # groups to user
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'ChangeUser' ) {

        # challenge token check for write action
        $LayoutObject->ChallengeTokenCheck();

        my $ID = $ParamObject->GetParam( Param => 'ID' );

        # get new groups
        my %Permissions;
        for my $Type ( @{ $ConfigObject->Get('System::Permission') } ) {
            my @IDs = $ParamObject->GetArray( Param => $Type );
            $Permissions{$Type} = \@IDs;
        }

        # get group data
        my %GroupData = $GroupObject->GroupList(
            Valid => 1,
        );

        my %NewPermission;
        for my $GroupID ( sort keys %GroupData ) {
            for my $Permission ( sort keys %Permissions ) {
                $NewPermission{$Permission} = 0;
                my @Array = @{ $Permissions{$Permission} };

                ID:
                for my $ID (@Array) {
                    next ID if !$ID;
                    if ( $GroupID eq $ID ) {
                        $NewPermission{$Permission} = 1;
                    }
                }
            }

            $GroupObject->PermissionGroupUserAdd(
                UID        => $ID,
                GID        => $GroupID,
                Permission => \%NewPermission,
                UserID     => $Self->{UserID},
            );
        }

        # if the user would like to continue editing the group-user relation just redirect to the edit screen
        # otherwise return to relations overview
        if (
            defined $ParamObject->GetParam( Param => 'ContinueAfterSave' )
            && ( $ParamObject->GetParam( Param => 'ContinueAfterSave' ) eq '1' )
            )
        {
            return $LayoutObject->Redirect( OP => "Action=$Self->{Action};Subaction=User;ID=$ID" );
        }

        return $LayoutObject->Redirect( OP => "Action=$Self->{Action}" );
    }

    # ------------------------------------------------------------ #
    # overview
    # ------------------------------------------------------------ #
    my $Output = $LayoutObject->Header();
    $Output .= $LayoutObject->NavigationBar();

    $Output .= $Self->_Overview(
        Search => $Search,
        Limit  => $Limit,
    );

    $Output .= $LayoutObject->Footer();
    return $Output;
}

sub _Change {
    my ( $Self, %Param ) = @_;

    my %Data   = %{ $Param{Data} };
    my $Type   = $Param{Type} || 'User';
    my $NeType = $Type eq 'Group' ? 'User' : 'Group';

    my %VisibleType = (
        Group => 'Group',
        User  => 'Agent',
    );

    # get layout object
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    if ( $VisibleType{$Type} eq 'Group' ) {
        $Param{BreadcrumbTitle} = $LayoutObject->{LanguageObject}->Translate("Change Agent Relations for Group");
    }
    else {
        $Param{BreadcrumbTitle} = $LayoutObject->{LanguageObject}->Translate("Change Group Relations for Agent");
    }

    $LayoutObject->Block(
        Name => 'ActionList',
    );

    $LayoutObject->Block(
        Name => 'ActionOverview',
    );

    $LayoutObject->Block(
        Name => 'ChangeReference',
    );

    $LayoutObject->Block(
        Name => 'Change',
        Data => {
            %Param,
            ActionHome    => 'Admin' . $Type,
            NeType        => $NeType,
            VisibleType   => $VisibleType{$Type},
            VisibleNeType => $VisibleType{$NeType},
        },
    );

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    my @Permissions;

    TYPE:
    for my $Type ( @{ $ConfigObject->Get('System::Permission') } ) {
        next TYPE if !$Type;

        my $Mark = $Type eq 'rw' ? "Highlight" : '';

        $LayoutObject->Block(
            Name => 'ChangeHeader',
            Data => {
                %Param,
                Mark => $Mark,
                Type => $Type,
            },
        );
        push @Permissions, $Type;
    }

    # set permissions
    $LayoutObject->AddJSData(
        Key   => 'RelationItems',
        Value => \@Permissions,
    );

    my %DataList;
    if ( $NeType eq 'Group' ) {
        %DataList = $Kernel::OM->Get('Kernel::System::Group')->GroupList(
            Valid => 1,
        );
    }
    else {
        my $UserObject = $Kernel::OM->Get('Kernel::System::User');
        %DataList      = $UserObject->UserList(
            Valid         => 1,
            NoOutOfOffice => 1,
        );

        # get user name
        USERID:
        for my $UserID ( sort keys %DataList ) {
            my $Name = $UserObject->UserName(
                UserID        => $UserID,
                NoOutOfOffice => 1,
            );
            next USERID if !$Name;

            $DataList{$UserID} .= " ($Name)";
        }
    }

    for my $ID ( sort { uc( $Data{$a} ) cmp uc( $Data{$b} ) } keys %Data ) {

        # set output class
        $LayoutObject->Block(
            Name => 'ChangeRow',
            Data => {
                %Param,
                Name   => $Param{Data}->{$ID},
                ID     => $ID,
                NeType => $NeType,
            },
        );

        TYPE:
        for my $Type ( @{ $ConfigObject->Get('System::Permission') } ) {
            next TYPE if !$Type;

            my $Mark     = $Type eq 'rw'        ? "Highlight"          : '';
            my $Selected = $Param{$Type}->{$ID} ? ' checked="checked"' : '';

            $LayoutObject->Block(
                Name => 'ChangeRowItem',
                Data => {
                    %Param,
                    Mark     => $Mark,
                    Type     => $Type,
                    ID       => $ID,
                    Selected => $Selected,
                    Name     => $Param{Data}->{$ID},
                },
            );
        }

        delete $DataList{$ID};
    }

    $DataList{'0'} = '-';
    my $DefaultListStrg = $LayoutObject->BuildSelection(
        Data         => \%DataList,
        Name         => 'DefaultList',
        ID           => 'DefaultList',
        Class        => 'Modernize',
        SelectedID   => 0,
        Translation  => 0,
    );

    # set output class
    $LayoutObject->Block(
        Name => 'TemplateRow',
        Data => {
            %Param,
            NeType => $NeType,
        },
    );

    # set output class
    $LayoutObject->Block(
        Name => 'NewRow',
        Data => {
            %Param,
            DefaultListStrg => $DefaultListStrg,
            NeType          => $NeType,
        },
    );

    TYPE:
    for my $Type ( @{ $ConfigObject->Get('System::Permission') } ) {
        next TYPE if !$Type;

        my $Mark = $Type eq 'rw' ? "Highlight" : '';

        $LayoutObject->Block(
            Name => 'TemplateRowItem',
            Data => {
                %Param,
                Mark     => $Mark,
                Type     => $Type,
            },
        );

        $LayoutObject->Block(
            Name => 'NewRowItem',
            Data => {
                %Param,
                Mark     => $Mark,
                Type     => $Type,
            },
        );
    }

    return $LayoutObject->Output(
        TemplateFile => 'AdminUserGroup',
        Data         => \%Param,
    );
}

sub _Overview {
    my ( $Self, %Param ) = @_;

    # get layout object
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    $LayoutObject->Block(
        Name => 'Overview',
    );

    $LayoutObject->Block(
        Name => 'ActionList',
    );

    $LayoutObject->Block(
        Name => 'NewActions',
    );

    $LayoutObject->Block(
        Name => 'SearchUserGroups',
        Data => \%Param,
    );

    $LayoutObject->Block(
        Name => 'OverviewResult',
    );

    # Shown users and groups limitation in AdminUserGroup
    my $Limit = $Param{Limit} ? $Param{Limit} : 50;

    if ( $Param{Search} && $Param{Search} !~ /\*$/i ) {
       $Param{Search} .= '*';
    }

    # get use object
    my $UserObject = $Kernel::OM->Get('Kernel::System::User');

    # users search 
    my %UserData;
    if ( $Param{Search} ) {
        %UserData = $UserObject->UserSearch(
            Search => $Param{Search},
            Limit  => $Limit,
        );

        # get user name
        USERID:
        for my $UserID ( sort keys %UserData ) {
            my $Name = $UserObject->UserName(
                UserID        => $UserID,
                NoOutOfOffice => 1,
            );
            next USERID if !$Name;

            $UserData{$UserID} .= " ($Name)";
        }
    }

    if ( %UserData ) {
        for my $UserID ( sort { uc( $UserData{$a} ) cmp uc( $UserData{$b} ) } keys %UserData ) {

            # set output class
            $LayoutObject->Block(
                Name => 'List1n',
                Data => {
                    Name      => $UserData{$UserID},
                    Subaction => 'User',
                    ID        => $UserID,
                },
            );
        }
    }
    else {
        $LayoutObject->Block(
            Name => 'UsersNoDataFound',
            Data => {},
        );
    }

    # groups search
    my %GroupData;
    if ( $Param{Search} ) {
        %GroupData = $Kernel::OM->Get('Kernel::System::Group')->GroupSearch(
            Search => $Param{Search},
            Limit  => $Limit,
        );
    }

    if ( %GroupData ) {
        for my $GroupID ( sort { uc( $GroupData{$a} ) cmp uc( $GroupData{$b} ) } keys %GroupData ) {

            # set output class
            $LayoutObject->Block(
                Name => 'Listn1',
                Data => {
                    Name      => $GroupData{$GroupID},
                    Subaction => 'Group',
                    ID        => $GroupID,
                },
            );
        }
    }
    else {
        $LayoutObject->Block(
            Name => 'GroupsNoDataFound',
            Data => {},
        );
    }

    # return output
    return $LayoutObject->Output(
        TemplateFile => 'AdminUserGroup',
        Data         => \%Param,
    );
}

1;
