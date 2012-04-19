jQuery(document).ready(function() {
    $(document).endlessScroll({
      fireOnce: true,
      bottomPixels: 200,
      fireDelay: 300,
        ceaseFire: function(){
          return jQuery('#infinite-scroll').length ? false : true;
        },
        callback: function(){
          jQuery.ajax({
              url: '/priorities/show_feed/'+jQuery("#endless_scroll_ul_priority_show").attr('priority_id'),
              data: {
                  last: jQuery("#endless_scroll_ul_priority_show").attr('last')
              },
              dataType: 'script'
            });
        }
    });
});