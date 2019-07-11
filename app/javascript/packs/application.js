/* eslint no-console:0 */
// This file is automatically compiled by Webpack, along with any other files
// present in this directory. You're encouraged to place your actual application logic in
// a relevant structure within app/javascript and only use these pack files to reference
// that code so it'll be compiled.
//
// To reference this file, add <%= javascript_pack_tag 'application' %> to the appropriate
// layout file, like app/views/layouts/application.html.erb


// Uncomment to copy all static images under ../images to the output folder and reference
// them with the image_pack_tag helper in views (e.g <%= image_pack_tag 'rails.png' %>)
// or the `imagePath` JavaScript helper below.
//
// const images = require.context('../images', true)
// const imagePath = (name) => images(name, true)

import Rails from 'rails-ujs';
Rails.start();
import 'bootstrap.native';

import EntityGraph from 'entity-graph';
import OCAdditionalInfo from 'oc-additional-info';
import Submissions from 'submissions';
import Tree from 'tree';
import Tooltips from 'tooltips';

(() => {
  function ready(callback){
    // in case the document is already rendered
    if (document.readyState!='loading') callback();
    // modern browsers
    else if (document.addEventListener) document.addEventListener('DOMContentLoaded', callback);
    // IE <= 8
    else document.attachEvent('onreadystatechange', function(){
        if (document.readyState=='complete') callback();
    });
  }

  const entityGraph = new EntityGraph(document);
  const ocAdditionalInfo = new OCAdditionalInfo(window.document);
  const submissions = new Submissions(window.document);
  const tree = new Tree(window.document);
  const tooltips = new Tooltips();

  ready(() => {
    entityGraph.init();
    ocAdditionalInfo.init();
    submissions.init();
    tree.init();
    tooltips.init();
  });
})();
