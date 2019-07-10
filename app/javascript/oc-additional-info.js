class OCAdditionalInfo {
  constructor($) {
    $(function () {
      var $additionalInfo = $('.js-opencorporates-additional-info');
      if($additionalInfo.length > 0) {
        var noDataMsg = $additionalInfo.data('no-data-msg');
        var additionalInfoUrl = $additionalInfo.data('additional-info-url');
        $.get(additionalInfoUrl)
          .done(function(data) {
            $additionalInfo.html(data);
          })
          .fail(function(){
            $additionalInfo.html('<div class="frame-light meta"><div class="frame-wrap"><p class="unknown">' + noDataMsg + '</p></div></div>');
          });
      }
    });
  }
}

export default OCAdditionalInfo;
