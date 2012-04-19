/*
//
// Differentiator - Jon Dal
//
*/

var diffelements = [];
var diff_changes_made = false;

function diff_get_element_id_from_object(element) {
  return jQuery(element).attr("id").replace("diff-content-change-", "");
}

function diff_add_element(element_id) {
  element_id = element_id + "";
  diffelements.push(element_id);
}

function diff_remove_element(element_id) {
  element_id = element_id + "";
  diffelements.splice(jQuery.inArray(element_id, diffelements),1);
}

function toggle_element_in_array(element_id) {
  element_id = element_id + "";
  (jQuery.inArray(element_id, diffelements) > -1) ? diff_remove_element(element_id) : diff_add_element(element_id);
}

function render_element_classes() {
  var users = [];

  // Remove class definition
  jQuery("#diff-content-container .changes ul li").each(function(index,element) {
    jQuery(element).removeClass("selected");
  });
  jQuery("ul#diff-changes-list li").each(function(index,element) {
    jQuery(element).removeClass("selected");
  });
  // Add selected class
  jQuery.each(diffelements, function(element_id) {
    var element = jQuery("#diff-content-change-" + element_id);
    var user_id = element.attr("rel");
    element.addClass("selected");
    jQuery("#diff-changes-document-user-" + user_id).addClass("selected");
  });
}

function toggle_change_element(element_id) {
  diff_changes_made = true;
  toggle_element_in_array(element_id);
  render_element_classes();
  return false;
}

function toggle_change_user(user_id) {
  diff_changes_made = true;
  var at_least_one_element_found = false;

  jQuery("#diff-content-container .changes ul li").each(function(index,element) {
    var element_user_id = jQuery(element).attr("rel");
    if (element_user_id == user_id) {
      var element_id = diff_get_element_id_from_object(element) + "";
      if (jQuery.inArray(element_id, diffelements) > -1) at_least_one_element_found = true;
    }
  });

  at_least_one_element_found ? toggle_change_user_remove_all(user_id) : toggle_change_user_add_all(user_id);
  render_element_classes();
  return false;
}

function toggle_change_user_add_all(user_id) {
  jQuery("#diff-content-container .changes ul li").each(function(index,element) { if (jQuery(element).attr("rel") == user_id) diff_add_element(diff_get_element_id_from_object(element)); });
}

function toggle_change_user_remove_all(user_id) {
  jQuery("#diff-content-container .changes ul li").each(function(index,element) { if (jQuery(element).attr("rel") == user_id) diff_remove_element(diff_get_element_id_from_object(element)); });
}

function diff_save() {
  var form = document.forms["diffform"];
  var current_id = jQuery("#diff-current-preview-id").html();

  // TODO: reevaluate this
  if (false && !diff_changes_made && current_id != "") {
    location.href = "/uidiff/preview/" + current_id;
  } else {
    form.elements["change_elements"].value = diffelements.join(",");
    form.submit();
  }

  return false;
}
