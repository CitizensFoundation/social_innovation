function setup_portal_menu(container_id,crumDefaultTxt,topLinkText)
{
	if (container_id!=-1)
	{
	    id_url = "?container_id="+container_id;
	};

    jQuery('#portlets-menu').menu({
        content: jQuery('#portlets-menu').next().html(),
        showSpeed: 100,
        backLink: false,
        dispatchType: 1,
        flyOut: false,
		topLinkText: topLinkText,
		crumbDefaultText: crumDefaultTxt,
        chooseItem: function(item){
            // edit this for your own custom function/callback:
            jQuery.ajax({
                url: "/portal/add_portlet/"+id_url,
                cache: false,
                type: "POST",
                data: ({
                    data: jQuery(item).text()
                }),
                dataType: "script"
            });
        }
    });

}
			
function setup_portal_dialogues(delPortletLabel, cancelLabel){
	var name = jQuery("#name"), allFields = jQuery([]).add(name), tips = jQuery("#validateTips");
	
	function updateTips(t){
		tips.text(t).effect("highlight", {}, 1500);
	}
	
	function checkLength(o, n, min, max){
	
		if (o.val().length > max || o.val().length < min) {
			o.addClass('ui-state-error');
			updateTips("Length of " + n + " must be between " + min + " and " + max + ".");
			return false;
		}
		else {
			return true;
		}
		
	}
	
	function checkRegexp(o, regexp, n){
	
		if (!(regexp.test(o.val()))) {
			o.addClass('ui-state-error');
			updateTips(n);
			return false;
		}
		else {
			return true;
		}
		
	}
	
	var buttons = {};
	buttons[delPortletLabel] = function(){
		jQuery.ajax({
			url: "/portal/delete_portlet/" + id_url,
			cache: false,
			type: "POST",
			data: ({
				portlet_id: global_portlet_id_to_delete
			}),
			dataType: "script"
		});
		jQuery(this).dialog('close');
	};
	buttons[cancelLabel] = function(){
		jQuery(this).dialog('close');
	};
	
	jQuery("#delete-portlet-dialog").dialog({
		bgiframe: true,
		autoOpen: false,
		height: 100,
		modal: true,
		buttons: buttons,
		close: function(){
			allFields.val('').removeClass('ui-state-error');
		}
	});
}

jQuery.ajaxSetup({ 
  'beforeSend': function(xhr) {xhr.setRequestHeader("Accept", "text/javascript")}
})

function setup_columns(){
	global_portlet_id_to_delete = "0";
	//hover states on the static widgets
	jQuery('#dialog_link, ul#icons li').hover(function(){
		jQuery(this).addClass('ui-state-hover');
	}, function(){
		jQuery(this).removeClass('ui-state-hover');
	});
	
	jQuery(".column").sortable({
		connectWith: '.column',
		scroll: true,
		handle : ".portlet-header",
		update: savelayout
	});
	
	jQuery(".portlet-header .collapse-portlet-button").click(function(){
		jQuery(this).toggleClass("ui-icon-lusthick");
		jQuery(this).parents(".portlet:first").find(".portlet-content").toggle();
	});
	
	jQuery(".portlet-header .delete-portlet-button").click(function(){
		global_portlet_id_to_delete = this.id;
		af = jQuery(this).id;
		jQuery('#delete-portlet-dialog').dialog('open');
	});
	
	jQuery(".column").disableSelection();
}
    		
function savelayout()
{
	var positions = "";
	var yindex = 0;
    jQuery(".portlet").each(function(){yindex++;positions+=("portlet_id-" +this.id + "=" + this.parentNode.id + "|" + yindex + "&");});
    jQuery.ajax({
		type: "POST",
		url: "/portal/save_positions",
		data: positions
    });
}

function submitForm(form){
    jQuery(form).submit();
    return false;
};
