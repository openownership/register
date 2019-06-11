//= require cytoscape.js
//= require dagre.js
//= require popper.js
//= require tippy.js
//= require cytoscape-dagre.js
//= require cytoscape-popper.js
$(function() {
  var elements, selected, cy;
  var $container = $('.cytoscape-container');
  var $zoom = $('.graph-zoom');
  var $zoomPlus = $('.graph-controls .fa-search-plus');
  var $zoomMinus = $('.graph-controls .fa-search-minus')
  var nodeTextMaxWidth = 300;
  var nodeStyles = [
    {
      selector: 'node',
      style: {
        // Node properties
        'shape': 'rectangle',
        'background-color': 'white',
        'width': 'label',
        'height': 'label',
        'padding': '8px 12px 8px 12px',
        'border-width': '1px',
        'border-color': 'black',
        'border-opacity': '0.05',
        // Label properties
        'label': 'data(label)',
        'text-valign': 'center',
        'text-halign': 'center',
        'font-size': '16px',
        'text-wrap': 'wrap',
        'text-max-width': nodeTextMaxWidth + 'px'
      }
    },
    {
      selector: 'node:selected',
      style: {
        'border-color': '#3C31D4',
        'border-opacity': '1'
      }
    },
    {
      selector: 'node.current',
      style: {
        'background-color': '#3C31D4',
        'color': 'white'
      }
    },
    {
      selector: 'node.label',
      style: {
        'background-color': '#EEE',
        'shape': 'round-rectangle',
        'border-style': 'dashed'
      }
    },
    {
      selector: 'node.hover',
      style: {
        'color': '#3C31D4'
      }
    },
    {
      selector: 'node.current.hover',
      style: {
        'color': 'white'
      }
    },
    {
      selector: 'node.dissolved',
      style: {
        'background-color': '#CCC'
      }
    }
  ];
  var edgeStyles = [
    {
      selector: 'edge',
      style: {
        'curve-style': 'bezier',
        'width': 2,
        'line-color': '#3C31D4',
        'target-arrow-shape': 'triangle',
        'target-arrow-color': '#3C31D4',
        'target-endpoint': 'outside-to-line-or-label'
      }
    },
    {
      selector: 'edge.label',
      style: {
        'line-color': '#CCC',
        'target-arrow-color': '#CCC',
        'width': 1,
        'line-style': 'dashed'
      }
    },
    {
      selector: 'edge.circular',
      style: {
        'control-point-step-size': (nodeTextMaxWidth / 2) + 'px'
      }
    },
    {
      selector: 'edge.ended',
      style: {
        'line-color': '#CCC',
        'target-arrow-color': '#CCC'
      }
    }
  ];
  var styles = nodeStyles.concat(edgeStyles);
  var layout = { name: 'dagre' };

  function centerOnSelected() {
    selectedNode = cy.getElementById(selected);
    selectedNode.addClass('current').select();
    cy.fit(selectedNode.neighbourhood());
  }

  function toggleTooltip(event) {
    var tooltip = event.target.tooltip;
    if(typeof tooltip != 'undefined') {
      if(tooltip.state.isVisible) {
        tooltip.hide();
      } else {
        tooltip.show();
      }
    }
    return false
  }

  function elementMouseOver(e) {
    var element = e.target;
    if(element.data('tooltip')) {
      element.addClass('hover');
      $container.css('cursor', 'pointer');
    }
  }

  function elementMouseOut(e) {
    var element = e.target;
    if(element.data('tooltip')) {
      element.removeClass('hover');
      $container.css('cursor', 'default');
    }
  }

  function tooltip(element) {
    return tippy(element.popperRef(), {
      content: function() { return element.data('tooltip') },
      hideOnClick: false,
      trigger: 'manual',
      arrow: true,
      distance: 20,
      theme: 'light',
      interactive: true,
      onShow: function(instance) {
        tippy.hideAll({ exclude: instance })
        cy.on('vclick', instance.hide);
      },
      onHide: function(instance) {
        cy.off('vclick', instance.hide);
      }
    });
  }

  function initZoomControls() {
    $zoom
      .attr('min', cy.minZoom())
      .attr('max', cy.maxZoom())
      .attr('step', 0.1)
      .val(roundZoom(cy.zoom()))
      .on('change', function() {
        console.log($zoom.val());
        cy.zoom(parseFloat($zoom.val()));
      });
  }

  function roundZoom(zoom) {
    return Math.round(zoom * 10) / 10;
  }

  if($container.length > 0) {
    elements = $container.data('elements');
    selected = $container.data('selected');
    cy = cytoscape({
      container: $container,
      elements: elements,
      style: styles,
      layout: layout,
      maxZoom: 1,
      minZoom: 0.5,
      boxSelectionEnabled: false
    });
    cy.elements().forEach(function (element) {
      if(element.data('tooltip')) {
        element.tooltip = tooltip(element);
      }
    });
    cy.ready(centerOnSelected);
    cy.ready(initZoomControls);
    cy.on('vclick', '*', toggleTooltip);
    cy.on('mouseover', '*', elementMouseOver);
    cy.on('mouseout', '*', elementMouseOut);
    cy.on('zoom', function() {
      var zoom = roundZoom(cy.zoom());
      $zoom.val(zoom);
    });

    tippy('.graph-zoom', {arrow: true, placement: 'bottom'});

    $zoomMinus.click(function() {
      var step = parseFloat($zoom.attr('step'));
      var zoom = Math.max(cy.minZoom(), cy.zoom() - step);
      zoom = roundZoom(zoom);
      cy.zoom(zoom);
      $zoom.val(zoom);
    });

    $zoomPlus.click(function() {
      var step = parseFloat($zoom.attr('step'));
      var zoom = Math.min(cy.maxZoom(), cy.zoom() + step);
      zoom = roundZoom(zoom);
      cy.zoom(zoom);
      $zoom.val(zoom);
    });
  }
});
