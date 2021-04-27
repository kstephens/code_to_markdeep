console.log(" // ctmd/js/core.js {");

///////////////////////////////////////////////////////////////
// Markdeep onLoad hooks:

var ctmd = {
};
ctmd.onLoad_funs = [ ];
ctmd.onLoad = function(f) {
    return ctmd.onLoad_funs.push(f);
};
ctmd.onLoad_run = function() {
  ctmd.onLoad_funs.forEach(function(f) {
    return f();
  });
};
ctmd.markdeepOptions = {
  onLoad: ctmd.onLoad_run,
  tocStyle: 'long',
};
window.markdeepOptions = ctmd.markdeepOptions;

///////////////////////////////////////////////////////////////
// Style/content improvements:

ctmd.onLoad(function(){
  // Fix text-align of ASCII-art diagrams.
  $("svg.diagram").wrap('<div class="ctmd-diagram"></div>');

  // Translate all Li_123nE to line number spans.
  var code_lineno_rx = /%Li_(_*)(?:<span[^>]*>)?(\d*)(?:<\/span[^>]*>)?_nE%/g;
  var code_lineno_rp = function(match, p1, p2, offset, string) {
    p1 = p1 + p2
    // console.log("lineno <== " + p1);
    var replaced = '<span class="ctmd-code-lineno">' + p1.replace(/_/g, '&nbsp;') + '</span>';
    // console.log("lineno ==> " + replaced);
    return replaced;
  };
  $("code").html(function(index, text){
    // console.log("<== " + text);
    var replaced = text.replace(code_lineno_rx, code_lineno_rp);
    // console.log("==> " + replaced);
    return replaced;
  });
});

console.log(" // ctmd/js/core.js }");
