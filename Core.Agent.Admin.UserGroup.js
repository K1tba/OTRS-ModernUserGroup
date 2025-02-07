// --
// Copyright (C) 2001-2020 OTRS AG, https://otrs.com/
// --
// This software comes with ABSOLUTELY NO WARRANTY. For details, see
// the enclosed file COPYING for license information (GPL). If you
// did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
// --

"use strict";

var Core = Core || {};
Core.Agent = Core.Agent || {};
Core.Agent.Admin = Core.Agent.Admin || {};

/**
 * @namespace Core.Agent.Admin.UserGroup
 * @memberof Core.Agent.Admin
 * @author OTRS AG
 * @description
 *      This namespace contains the special module function for UserGroup selection.
 */
 Core.Agent.Admin.UserGroup = (function (TargetNS) {

    /*
    * @name Init
    * @memberof Core.Agent.Admin.UserGroup
    * @function
    * @description
    *      This function initializes filter and "SelectAll" actions.
    */
    TargetNS.Init = function () {
        var RelationItems = Core.Config.Get('RelationItems');

        // initialize "SelectAll" checkbox and bind click event on "SelectAll" for each relation item
        if (RelationItems) {
            $.each(RelationItems, function (index) {
                Core.Form.InitSelectAllCheckboxes($('table td input[type="checkbox"][name=' + RelationItems[index] + ']'), $('#SelectAll' + RelationItems[index]));

                $('input[type="checkbox"][name=' + RelationItems[index] + ']').click(function () {
                    Core.Form.SelectAllCheckboxes($(this), $('#SelectAll' + RelationItems[index]));
                });
            });
        }

        // initialize table filters
        Core.UI.Table.InitTableFilter($("#Filter"), $("#UserGroups"));

        //bind click function to add button
        $('#AddValue').on('click', function () {
            TargetNS.AddValue(
                $("#DefaultList"),
                $(this).closest('table').find('tbody')
            );
            return false;
        });

        //bind click function to remove button
        $('.ValueRemove').on('click', function () {
            TargetNS.RemoveRow($(this).attr('id'));
            return false;
        });

    };

    /**
     * @name AddValue
     * @memberof Core.Agent.Preferences
     * @function
     * @returns {Boolean} Returns false
     * @param {Object} ValueInsert - HTML container of the value mapping row.
     * @description
     *      This function add a new value to the possible values list
     */
    TargetNS.AddValue = function (Select, ValueInsert) {

        var $Key   = Select.val(),
            $Value = Select.find('option:selected').text();

        if ( $Key === '0' ) {
            return false;
        }

        // clone key dialog
        var $Clone = $('.TemplateRow').clone();

        // remove unnecessary classes
        $Clone.removeClass('TemplateRow Hidden');

        // add needed id
        $Clone.attr('id', 'Row_' + $Key);

        // copy values and change ids and names
        $Clone.find('td:first-child a').each(function(){
            var Href = $(this).attr('href');
            $(this).attr('href', Href + $Key);
            $(this).text($Value);
        });

        // copy values and change ids and names
        $Clone.find(':input').each(function(){
            $(this).val($Key);
        });

        // copy values and change ids and names
        $Clone.find('a.RemoveButton').each(function(){
            var ID = $(this).attr('id');
            $(this).attr('id', ID + $Key);

            // add event handler to remove button
            if($(this).hasClass('RemoveButton')) {

                // bind click function to remove button
                $(this).on('click', function () {
                    TargetNS.RemoveRow($(this).attr('id'));
                    return false;
                });
            }
        });

        // remove the value from default list
        if ($Key !== ''){
            $('#DefaultList').find("option[value='" + $Key + "']").remove();
            $('#DefaultList').trigger('redraw.InputField');
        }

        // append to container
        ValueInsert.prepend($Clone);

        return false;
    };

    /**
     * @name RemoveRow
     * @memberof Core.Agent.Admin.UserGroup
     * @function
     * @returns {Boolean} Returns false
     * @param {String} IDSelector - ID of the pressed remove value button.
     * @description
     *      This function removes a value from possible values list and creates a stub input so
     *      the server can identify if a value is empty or deleted (useful for server validation)
     *      It also deletes the Value from the DefaultValues list
     */
    TargetNS.RemoveRow = function ( IDSelector ){

        // copy HTML code for an input replacement for the deleted value
        //var $Clone = $('.DeletedValue').clone(),

        // get the index of the value to delete (its always the second element (1) in this RegEx
        var $Key = IDSelector.match(/.+_(\d+)/)[1],

        // get the key name to add in the defaults select
        $Value = $('#Row_' + $Key).find('td:first a').text();

        // remove the value from default list
        if ( $Value !== '' ){
            //$('#TemplateList').find("option[value='" + $Key + "']").remove();
            $('#DefaultList').append('<option value="' + $Key + '">' + $Value + '</option>');
            $('#DefaultList').trigger('redraw.InputField');
        }

        // remove possible value
        $('#Row_' + $Key).remove();

        return false;
    };

    Core.Init.RegisterNamespace(TargetNS, 'APP_MODULE');

    return TargetNS;
}(Core.Agent.Admin.UserGroup || {}));
