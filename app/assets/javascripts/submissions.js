var SIGNPOST_TEMPLATE = '<div class="tooltip tooltip--signpost" role="tooltip"><div class="tooltip-arrow"></div><div class="tooltip-inner"></div></div>';

$(document).on('submit', '.submission-search-form', function() {
  var overlay = $('<div class="submission-overlay" />');
  var spinner = $('<div class="submission-overlay__spinner" />');

  overlay
    .append(spinner)
    .hide()
    .appendTo('body')
    .fadeIn('fast');
});
