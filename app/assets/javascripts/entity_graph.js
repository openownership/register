//= require cytoscape.js
//= require dagre.js
//= require cytoscape-dagre.js
$(function() {
  var elements, selected, cy;
  var $container = $('.cytoscape-container');
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
    }
    ,
    {
      selector: 'node.hover',
      style: {
        'color': '#3C31D4'
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
    }
  ];
  var styles = nodeStyles.concat(edgeStyles);
  var layout = { name: 'dagre' };

  function centerOnSelected() {
    selectedNode = cy.getElementById(selected);
    selectedNode
      .addClass('current')
      .removeData('path')
      .select();
    cy.fit(selectedNode.neighbourhood());
  }

  function nodeClick(evt) {
    var node = evt.target;
    if(node.data('path')) {
      window.location = node.data('path');
    }
  }

  function nodeMouseOver(e) {
    var node = e.target;
    if(node.data('path')) {
      node.addClass('hover');
      $container.css('cursor', 'pointer');
    }
  }

  function nodeMouseOut(e) {
    var node = e.target;
    if(node.data('path')) {
      node.removeClass('hover');
      $container.css('cursor', 'default');
    }
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
    cy.ready(centerOnSelected);
    cy.on('vclick', 'node', nodeClick);
    cy.on('mouseover', 'node', nodeMouseOver);
    cy.on('mouseout', 'node', nodeMouseOut);
  }
});
