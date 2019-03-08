console.log(" ;; nav.js");
$(document).ready(function(){
  console.log(" ;; nav.js document ready");

  ///////////////////////////////////////////////////////////////
  // Style/content improvements:
  
  // Fix text-align of ASCII-art diagrams.
  $("svg.diagram").wrap('<div class="ctmd-diagram"></div>');

  // Translate all Li_123nE to line number spans.
  var code_lineno_rx = /Li(_*[_\d]+)nE/g;
  var code_lineno_rp = function(match, p1, offset, string) {
    // console.log("lineno " + p1);
    return '<span class="ctmd-code-lineno">' + p1.replace(/_/g, ' ') + '</span>';
  };
  $("code").html(function(index, text){
     // console.log("code " + text);
     return text.replace(code_lineno_rx, code_lineno_rp);
  });


  ///////////////////////////////////////////////////////////////
  // Annotate section headers with navigation attributes:

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

  // Style overrides
  $('head').append('<style>' +
                   '.md h1:before, .md h2:before, .md h3:before, .md h4:before { ' +
                   'content: attr(data-toc-num); ' +
                   'margin-right: 10px; ' +
                   '}' +
                   '</style>');

  ///////////////////////////////////////////////////////////////
  // Annotate section headers with nav buttons:
  
  $("h1,h2,h3,h4,h5,h6").each(function(){
    var hx = $(this);
    var id = $(hx).parent('.ctmd-nav-tree').data('nav-id');
    $(hx).addClass('ctmd-nav-header');
    $(hx).before('<span id="ctmd-nav-group-' + (id + 0) + '" ' +
                 'class="ctmd-nav-anchor-group">' +
                 '<a class="ctmd-nav-anchor" name="ctmd-nav-anchor-' + (id + 0) + '"/>' +
                 '</span>'
                  );
    $(hx).append('<span class="ctmd-nav-button-group">' +
                 '<span class="ctmd-nav-buttons">' +
                 '<a class="ctmd-nav-show" data-nav-id="' + (id + 0) + '" >'  + '##' + '</a>' +
                 '&nbsp;' +
                 '<a class="ctmd-nav-this" data-nav-id="' + (id + 0) + '" >'  + '==' + '</a>' +
                 '&nbsp;' +
                 '<a class="ctmd-nav-prev" data-nav-id="' + (id - 1) + '" >'  + '&lt;&lt;' + '</a>' +
                 '&nbsp;' +
                 '<a class="ctmd-nav-next" data-nav-id="' + (id + 1) + '" >'  + '&gt;&gt;' + '</a>' +
                 '</span>' +
                 '</span>');
  });

  ///////////////////////////////////////////////////////////////
  // Keyboard "slideshow" navigiation:
  
  var nav_id_to_dom_id = function(nav_id) {
    return '#ctmd-nav-tree-' + nav_id;
  };
  var nav_id_to_dom = function(nav_id) {
    return nav_id ? $(nav_id_to_dom_id(nav_id)) : null;
  }
  var nav_all_dom = function() {
    return $('.ctmd-nav-tree');
  }

  var nav_speed = 250;
  var nav_set_opacity = function(dom, opacity) {
    dom.animate({
      opacity: opacity
    }, {
      duration: nav_speed * 1.5
    });
  }
  var nav_scroll_to = function(dom) {
    $('html, body').animate({
      scrollTop: dom.offset().top
    }, {
      duration: nav_speed
    });
  }

  var nav_showing_all = true;
  var nav_show = function(dom) {
    nav_set_opacity(dom, 1.0);
    // dom.removeClass('ctmd-nav-hide');
  };
  var nav_hide = function(dom) {
    nav_set_opacity(dom, 0.0);
    nav_showing_all = false;
    // dom.addClass('ctmd-nav-hide');
  };
  var nav_show_all = function() {
    if ( ! nav_showing_all )
      nav_show(nav_all_dom());
    nav_showing_all = true;
  }
  
  var nav_show_all_state = true;
  var last_nav_id;
  var show_nav_id = function(nav_id) {
    var nav_dom       = nav_id_to_dom(nav_id);
    var last_nav_dom  = nav_id_to_dom(last_nav_id);
    console.log("nav_show_id " + nav_id + ' ' + nav_show_all_state);
    if ( nav_show_all_state ) {
      nav_show_all();
    } else {
      nav_hide(nav_all_dom().not(nav_dom));
      nav_show(nav_dom);
    }
    nav_scroll_to(nav_dom);
    last_nav_id = nav_id;
    // window.innerHeight; // force re-layout
  };

  var toggle_show_all = function(nav_id) {
    nav_show_all_state = ! nav_show_all_state;
    show_nav_id(nav_id);
  };
  var nav_direction = function (dir) {
    if ( last_nav_id )
      show_nav_id(last_nav_id + dir);
  };
  
  $('.ctmd-nav-show').each(function() {
    $(this).click(function() {
      var nav_id = $(this).data('nav-id');
      toggle_show_all(nav_id);
    });
  });
  $('.ctmd-nav-this, .ctmd-nav-next, .ctmd-nav-prev').each(function () {
    $(this).click(function() {
      var nav_id = $(this).data('nav-id');
      show_nav_id(nav_id);
    });
  });

  $(window).keypress(function (e) {
    console.log("e.which=" + e.which);
    if ( e.which == 91 ) { // [
      nav_direction(-1);
      e.preventDefault();
    } else if ( e.which == 93 ) { // ]
      nav_direction(1);
      e.preventDefault();
    } else if ( e.which == 92 ) { // \ OR |
      nav_direction(0);
      e.preventDefault();
    } else if ( e.which == 47 ) { // /
      nav_show_all_state = true;
      nav_show_all();
      e.preventDefault();
    }
  });

});

