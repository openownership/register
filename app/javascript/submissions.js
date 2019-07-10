class Submissions {
  signpostTemplate = '<div class="tooltip tooltip--signpost" role="tooltip"><div class="tooltip-arrow"></div><div class="tooltip-inner"></div></div>';

  constructor($) {
    $(function() {
      var $search = $('.submission-search-field .form-control');
      if($search.val() === '') {
        $search
          .tooltip({
            title: $search.data('tooltip'),
            placement: 'top',
            trigger: 'manual',
            offset: '5 0',
            template: this.signpostTemplate
          })
          .tooltip('show');
      }

      $(document).on('submit', '.submission-search-form', function() {
        var overlay = $('<div class="submission-overlay" />');
        var spinner = $('<div class="submission-overlay__spinner" />');

        overlay
          .append(spinner)
          .hide()
          .appendTo('body')
          .fadeIn('fast');
      });
    });
  }
}

export default Submissions;
