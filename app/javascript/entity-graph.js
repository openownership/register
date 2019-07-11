import cytoscape from 'cytoscape';
import dagre from 'cytoscape-dagre';
import popper from 'cytoscape-popper';
import tippy from 'tippy.js';

cytoscape.use(dagre);
cytoscape.use(popper);

class EntityGraph {
  document = null;
  elements = null;
  selected = null;
  cy = null;
  zoom = null;
  zoomPlus = null;
  zoomMinus = null;
  nodeTextMaxWidth = 300;
  nodeStyles = [
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
        'text-max-width': this.nodeTextMaxWidth + 'px'
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
  edgeStyles = [
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
        'control-point-step-size': (this.nodeTextMaxWidth / 2) + 'px'
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
  styles = this.nodeStyles.concat(this.edgeStyles);
  layout = { name: 'dagre' };

  constructor(document) {
    this.document = document;
    this.centerOnSelected = this.centerOnSelected.bind(this);
    this.elementMouseOver = this.elementMouseOver.bind(this);
    this.elementMouseOut = this.elementMouseOut.bind(this);
    this.tooltip = this.tooltip.bind(this);
    this.initZoomControls = this.initZoomControls.bind(this);
    this.zoomIn = this.zoomIn.bind(this);
    this.zoomOut = this.zoomOut.bind(this);
  }

  centerOnSelected() {
    var selectedNode = this.cy.getElementById(this.selected);
    selectedNode.addClass('current').select();
    this.cy.fit(selectedNode);
  }

  toggleTooltip(event) {
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

  elementMouseOver(e) {
    var element = e.target;
    if(element.data('tooltip')) {
      element.addClass('hover');
      this.container.style.cursor = 'pointer';
    }
  }

  elementMouseOut(e) {
    var element = e.target;
    if(element.data('tooltip')) {
      element.removeClass('hover');
      this.container.style.cursor = 'default';
    }
  }

  tooltip(element) {
    return tippy(element.popperRef(), {
      content: () => element.data('tooltip'),
      hideOnClick: false,
      trigger: 'manual',
      arrow: true,
      distance: 20,
      theme: 'light',
      interactive: true,
      onShow: (instance) => {
        tippy.hideAll({ exclude: instance })
        this.cy.on('vclick', instance.hide);
      },
      onHide: (instance) => {
        this.cy.off('vclick', instance.hide);
      }
    });
  }

  initZoomControls() {
    this.zoom.setAttribute('min', this.cy.minZoom());
    this.zoom.setAttribute('max', this.cy.maxZoom());
    this.zoom.setAttribute('step', 0.1);
    this.zoom.value = this.roundZoom(this.cy.zoom());
    this.zoom.addEventListener('change', () => {
      this.cy.zoom(parseFloat(this.zoom.value));
    });
  }

  roundZoom(zoom) {
    return Math.round(zoom * 10) / 10;
  }

  zoomIn() {
    var step = parseFloat(this.zoom.getAttribute('step'));
    var zoom = Math.max(this.cy.minZoom(), this.cy.zoom() + step);
    zoom = this.roundZoom(zoom);
    this.cy.zoom(zoom);
    this.zoom.value = zoom;
  }

  zoomOut(){
    var step = parseFloat(this.zoom.getAttribute('step'));
    var zoom = Math.max(this.cy.minZoom(), this.cy.zoom() - step);
    zoom = this.roundZoom(zoom);
    this.cy.zoom(zoom);
    this.zoom.value = zoom;
  }

  init() {
    this.container = document.querySelector('.cytoscape-container');
    if(this.container === null) {
      return;
    }
    this.zoom = document.querySelector('.graph-zoom');
    this.zoomPlus = document.querySelector('.graph-controls .fa-search-plus');
    this.zoomMinus = document.querySelector('.graph-controls .fa-search-minus')
    this.elements = JSON.parse(this.container.dataset.elements);
    this.selected = this.container.dataset.selected;

    this.cy = cytoscape({
      container: this.container,
      elements: this.elements,
      style: this.styles,
      layout: this.layout,
      maxZoom: 1,
      minZoom: 0.5,
      boxSelectionEnabled: false,
      userZoomingEnabled: false
    });

    this.cy.elements().forEach((element) => {
      if(element.data('tooltip')) {
        element.tooltip = this.tooltip(element);
      }
    });

    this.cy.ready(this.centerOnSelected);
    this.cy.ready(this.initZoomControls);
    this.cy.on('vclick', '*', this.toggleTooltip);
    this.cy.on('mouseover', '*', this.elementMouseOver);
    this.cy.on('mouseout', '*', this.elementMouseOut);
    this.cy.on('zoom', () => {
      var zoom = this.roundZoom(this.cy.zoom());
      this.zoom.value = zoom;
    });

    tippy('.graph-zoom', {arrow: true, placement: 'bottom'});

    this.zoomMinus.addEventListener('click', this.zoomOut);
    this.zoomPlus.addEventListener('click', this.zoomIn);
  }
}

export default EntityGraph;
