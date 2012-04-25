//= require jquery
//= require jquery_ujs
//= require jquery.ui.all
//= require facebox
//= require jquery.NobleCount.min
//= require jquery.timeago
//= require jquery.truncator
//= require autoresize.jquery.min
//= require jquery.defaultvalue
//= require jquery.hoverIntent.minified
//= require jquery.bgiframe.min
//= require jquery.corner
//= require jquery.delayedObserver
//= require jquery.endless-scroll
//= require jquery.sticky
//= require jquery.pop
//= require_self

jQuery(function ($) {
  $.fn.extend({
    turnRemoteToToggle: function(target,altText){
        var $el = $(this),
            altText = altText || "Hide";

        $el.text(altText);
        $el.toggle(
          function(){
            $el.text(el.data('origText'));
            $el.data('expanded', false);
            target.slideUp(); // or target.hide() or other effect
          }, 
          function(){
            $el.text(altText);
            $el.data('expanded', true);
            target.slideDown(); // or target.show() or whatever
          }
        );
      }
  });
});


jQuery(document).ready(function() {
  jQuery('form[data-remote]').bind("ajax:before", function(){
    for (instance in CKEDITOR.instances){
      CKEDITOR.instances[instance].updateElement();
    }
  });

  jQuery('a[data-remote]').live("ajax:beforeSend", function(){
      var $clicked = $(this);
      $disable_with = $clicked.attr("data-disable-with");
      if ($clicked.attr("data-loader-name")!="no_loader") {
        $loader_name = $clicked.attr("data-loader-name");
        $clicked.replaceWith($disable_with+' <img src=\"/assets/ajax/'+$loader_name+'.gif\">');
      } else {
        $clicked.replaceWith($disable_with);
      }

    // $clicked.href("#");
    });

	var isChrome = /Chrome/.test(navigator.userAgent);
	if(!isChrome & jQuery.support.opacity) {
		//jQuery(".tab_header a, div.tab_body").corners(); 
	}
	//jQuery("#idea_column, #intro, #buzz_box, #content_text, #notification_show, .bulletin_form").corners();
	//jQuery("#top_right_column, #toolbar").corners("bottom");
	
	jQuery("abbr[class*=timeago]").timeago();	
	jQuery("#pointContent").NobleCount('#pointContentDown',{ on_negative: 'go_red', on_positive: 'go_green', max_chars: 500 });
    jQuery("#ideaContent").NobleCount('#ideaContentDown',{ on_negative: 'go_red', on_positive: 'go_green', max_chars: 300 });
	jQuery("input#user_login_search").autocomplete({ source: "/users.js" });
	jQuery('#bulletin_content, #blurb_content, #message_content, #document_content, #email_template_content, #page_content').autoResize({extraSpace : 20})

	function addMega(){
	  jQuery(this).addClass("hovering"); 
	} 
                                          77
	function removeMega(){ 
	  jQuery(this).removeClass("hovering"); 
	}
	var megaConfig = {
	     interval: 20,
	     sensitivity: 1,
	     over: addMega,
	     timeout: 20,
	     out: removeMega
	};
	jQuery(".mega").hoverIntent(megaConfig);


});

function toggleAll(name)
{
  boxes = document.getElementsByClassName(name);
  for (i = 0; i < boxes.length; i++)
    if (!boxes[i].disabled)
   		{	boxes[i].checked = !boxes[i].checked ; }
}

function setAll(name,state)
{
  boxes = document.getElementsByClassName(name);
  for (i = 0; i < boxes.length; i++)
    if (!boxes[i].disabled)
   		{	boxes[i].checked = state ; }
}

function showSubNavLayer(layer) {
    var myLayer = document.getElementById(layer);
    if(myLayer.style.display=="none" || myLayer.style.display==""){
      myLayer.style.display="block";
    } else {
      myLayer.style.display="none";
    }
}