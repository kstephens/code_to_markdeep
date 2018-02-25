$(document).ready(function(){
  // console.log(" ;; nav.js");

  // Fix text-align of ASCII-art diagrams.
  $("svg.diagram").wrap('<div class="ctmd-diagram"></div>');

  // Translate all Li_123nE to line number spans.
  var code_lineno_rx = /Li(_*[_\d]+)nE/g;
  var code_lineno_rp = function(match, p1, offset, string) {
    return '<span class="ctmd-code-lineno">' + p1.replace(/_/g, ' ') + '</span>';
  };
  $("code").html(function(index, text){
     return text.replace(code_lineno_rx, code_lineno_rp);
  });

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

  var show_all_state = true;
  var show_all_nav = function() {
    $('.ctmd-nav-tree').removeClass('ctmd-nav-hide');
  };
  var last_nav_id;
  var show_nav_id = function(nav_id) {
    var id = '#ctmd-nav-tree-' + nav_id;
    var last_id;
    console.log("show_nav_id " + nav_id + ' => ' + id + ' ' + show_all_state);

    if ( show_all_state ) {
      $('.ctmd-nav-tree').removeClass('ctmd-nav-hide');
    } else {
      $('.ctmd-nav-tree').addClass('ctmd-nav-hide');
    }
    if ( last_nav_id && last_nav_id != nav_id ) {
      last_id = '#ctmd-nav-tree-' + last_nav_id;
      $(last_id).removeClass('ctmd-nav-hide');
    }
    $(id).removeClass('ctmd-nav-hide');
    last_nav_id = nav_id;
    window.innerHeight;
    
    $('html, body').animate({
      scrollTop: $(id).offset().top,
    }, {
      duration: 250,
      complete: function () {
        if ( show_all_state ) {
          $('.ctmd-nav-tree').removeClass('ctmd-nav-hide');
        } else {
          if ( last_id && last_nav_id != nav_id ) {
            $(last_id).addClass('ctmd-nav-hide');
          }
        }
        window.innerHeight;
      }
    });
  };
  var toggle_show_all = function(nav_id) {
    show_all_state = ! show_all_state;
    if ( show_all_state ) {
      show_all_nav();
    }
    show_nav_id(nav_id);
  };
  var nav_dir = function (dir) {
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
      nav_dir(-1);
      e.preventDefault();
    } else if ( e.which == 93 ) { // ]
      nav_dir(1);
      e.preventDefault();
    } else if ( e.which == 92 ) { // \ OR |
      nav_dir(0);
      e.preventDefault();
    }
  });

});

