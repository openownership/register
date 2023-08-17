import Rails from 'rails-ujs';
import 'bootstrap.native.custom';
import tippy from 'tippy.js';
import EntityGraph from 'entity-graph';
import OCAdditionalInfo from 'oc-additional-info';

(() => {
  Rails.start();

  const ready = (callback) => {
    if (document.readyState !== 'loading') {
      // in case the document is already rendered
      callback();
    } else if (document.addEventListener) {
      // modern browsers
      document.addEventListener('DOMContentLoaded', callback);
    } else {
      // IE <= 8
      document.attachEvent('onreadystatechange', () => {
        if (document.readyState === 'complete') {
          callback();
        }
      });
    }
  };

  const entityGraph = new EntityGraph(document);
  const ocAdditionalInfo = new OCAdditionalInfo(window.document);

  ready(() => {
    entityGraph.init();
    ocAdditionalInfo.init();
    tippy('[data-tippy-content]');
  });
})();
