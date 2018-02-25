$(document).ready(function(){
  // console.log(" ;; nav2.js");
  var nav_id = 0;
    $(".longTOC").each(function(){
    $(this).prepend('<a class="ctmd-nav-anchor" name="ctmd-nav-anchor-' + (nav_id + 0) + '"/>');
  });
  $("h1,h2,h3,h4,h5,h6").each(function(){
    var hx = $(this);
    var hx_tag = this.nodeName;
    var id = nav_id += 1;
    var a_class_target = hx.prev();
    var toc_name = a_class_target.attr('name');
    var toc_num = toc_name.replace(/^toc/, '');
    $(hx).attr('data-toc-num', toc_num);
    $(hx).before('<span ' +
                 'id="ctmd-nav-tree-' + id + '" ' +
                 'data-nav-id="' + id + '" ' +
                 'data-nav-tag="' + hx_tag + '" ' +
                 'data-nav-toc-name="' + toc_name + '" ' +
                 'data-nav-toc-num="'  + toc_num + '" ' +
                 'class="ctmd-nav-anchor-tree ctmd-nav-anchor-tree-' + hx_tag + '">' +
                 '</span>'
    );
  });
  var wrap_tree_div = function() {
    // var until = '.ctmd-nav-anchor-tree';
    var until = 'a.target';
    return function() {
      var id = this.id;
      var sp = $(this);
      var nav_id = $(sp).data('nav-id');
      var hx_tag = $(sp).data('nav-tag');
      var toc_name = $(sp).data('nav-toc-name');
      $(sp)
        .nextUntil(until)
        .wrapAll('<div id="' + id + '" ' +
                 'data-nav-id="' + nav_id + '" ' +
                 'data-nav-toc-name="' + toc_name + '" ' +
                 'class="ctmd-nav-tree ctmd-nav-tree-' + hx_tag + '" ' +
                 '/>');
    };
  };
  $(".ctmd-nav-anchor-tree").each(wrap_tree_div());
  $('.ctmd-nav-anchor-tree').remove();
  $('head').append('<style>' +
                   '.md h1:before, .md h2:before, .md h3:before, .md h4:before { ' +
                   'content: attr(data-toc-num); ' +
                   'margin-right: 10px; ' +
                   '}' +
                   '</style>');
 });

