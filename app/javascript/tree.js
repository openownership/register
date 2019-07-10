import {default as stringToColor} from 'string-to-color';

class Tree {
  constructor($) {
    $(function() {
      var $treeWindow = $('.tree-window');
      var id = $treeWindow.data('tree');
      var key = "tree-" + id + "-";
      var x = parseInt(sessionStorage.getItem(key + "x")) || 0;
      var y = parseInt(sessionStorage.getItem(key + "y")) || 0;
      var z = parseInt(sessionStorage.getItem(key + "z")) || 50;
      var groupedTooltip = $treeWindow.data('grouped_tooltip');

      update();

      $('.tree-window').on('mousedown touchstart', function(event) {
        event.preventDefault();

        var dx = (event.pageX || event.originalEvent.touches[0].clientX) - x;
        var dy = (event.pageY || event.originalEvent.touches[0].clientY) - y;

        $(document).on('mousemove.test touchmove.test', function(event) {
          event.preventDefault();

          var mx = event.pageX || event.originalEvent.touches[0].clientX;
          var my = event.pageY || event.originalEvent.touches[0].clientY;

          x = mx - dx;
          y = my - dy;

          sessionStorage.setItem(key + "x", x);
          sessionStorage.setItem(key + "y", y);

          update();
        });

        $(document).one('mouseup.test touchend', function(event) {
          event.preventDefault();
          $(document).off('mousemove.test touchmove.test');
        });
      });

      $('.tree-zoom').on('input change', function() {
        z = $(this).val();
        sessionStorage.setItem(key + "z", z);
        update();
      });

      $('.tree-controls .fa-search-minus').click(function() {
        z = Math.max(0, z - 10);
        sessionStorage.setItem(key + "z", z);
        update();
      });

      $('.tree-controls .fa-search-plus').click(function() {
        z = Math.min(100, z + 10);
        sessionStorage.setItem(key + "z", z);
        update();
      });

      function update() {
        $('.tree-zoom').val(z);
        $('.tree-canvas').css({
          transform: "translate(" + x + "px, " + y + "px)"
        });
        $('.tree-group').first().css({
          transform: "scale(" + scale(z) + ")"
        });
      }

      function scale(n) {
        return 0.5 + (n / 100);
      }

      $('.tree-node--natural-person').each(function() {
        var id = $(this).data('node');
        var similar = $('[data-node="' + id + '"]');
        var entity = $(this).find('.tree-node__entity');

        if (similar.size() > 1) {
          entity.css('outline', '2px solid ' + stringToColor(id));
          entity.tooltip({ title: groupedTooltip, offset: "5 0" })
        }
      });

      $('.tree-node--natural-person .tree-node__entity').hover(function() {
        var id = $(this).closest('[data-node]').data('node');
        var similar = $('[data-node="' + id + '"]');

        if (similar.size() > 1) {
          $('[data-node]').not(similar).css('opacity', 0.5);
        }
      }, function() {
          $('[data-node]').css('opacity', 1);
      });

      $('.tree-canvas').fadeTo('fast', 1);
    });
  }
}

export default Tree;
