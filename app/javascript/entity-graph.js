import cytoscape from 'cytoscape';
import dagre from 'cytoscape-dagre';
import popper from 'cytoscape-popper';
import tippy from 'tippy.js';

cytoscape.use(dagre);
cytoscape.use(popper);

class EntityGraph {
  constructor(document) {
    this.document = document;
    this.elements = null;
    this.selected = null;
    this.cy = null;
    this.zoom = null;
    this.zoomPlus = null;
    this.zoomMinus = null;
    this.nodeTextMaxWidth = 300;
    this.nodeStyles = [
      {
        selector: 'node',
        style: {
          // Node properties
          'shape': 'rectangle',
          'padding': '0px',
          'background-opacity': 0,
          'width': '24px',
          'height': '16px',
          // Label properties
          'label': 'data(label)',
          'text-halign': 'center',
          'text-valign': 'top',
          'font-size': '16px',
          'text-wrap': 'wrap',
          'text-max-width': `${this.nodeTextMaxWidth}px`,
          'text-margin-y': '-4px',
          'text-background-color': '#F4F6F8',
          'text-background-opacity': 1,
          'text-events': 'yes',
          // Flag image properties
          'background-image': 'data(flag)',
          'background-height': '100%',
          'background-width': '100%',
          'background-repeat': 'no-repeat',
          'background-fit': 'cover',
          'background-clip': 'none',
        },
      },
      {
        selector: 'node.current',
        style: {
          'font-weight': 'bold',
        },
      },
      {
        selector: 'node.hover',
        style: {
          color: '#3C31D4',
        },
      },
      {
        selector: 'node.dissolved',
        style: {
          color: '#DDD',
        },
      },
    ];
    this.edgeStyles = [
      {
        selector: 'edge',
        style: {
          'curve-style': 'bezier',
          'width': 2,
          'line-color': '#3C31D4',
          'target-arrow-shape': 'triangle',
          'target-arrow-color': '#3C31D4',
          'target-endpoint': 'outside-to-line-or-label',
          'source-endpoint': 'outside-to-line-or-label',
          'target-distance-from-node': '16px',
          'source-distance-from-node': '8px',
        },
      },
      {
        selector: 'edge.label',
        style: {
          'line-color': '#CCC',
          'target-arrow-color': '#CCC',
          'width': 1,
          'line-style': 'dashed',
        },
      },
      {
        selector: 'edge.circular',
        style: {
          'control-point-step-size': `${this.nodeTextMaxWidth / 2}px`,
        },
      },
      {
        selector: 'edge.ended',
        style: {
          'line-color': '#CCC',
          'target-arrow-color': '#CCC',
        },
      },
    ];
    this.styles = this.nodeStyles.concat(this.edgeStyles);
    this.layout = {
      name: 'dagre',
      nodeDimensionsIncludeLabels: true,
    };

    this.centerOnSelected = this.centerOnSelected.bind(this);
    this.elementMouseOver = this.elementMouseOver.bind(this);
    this.elementMouseOut = this.elementMouseOut.bind(this);
    this.tooltip = this.tooltip.bind(this);
    this.initZoomControls = this.initZoomControls.bind(this);
    this.zoomIn = this.zoomIn.bind(this);
    this.zoomOut = this.zoomOut.bind(this);
  }

  centerOnSelected() {
    const selectedNode = this.cy.getElementById(this.selected);
    selectedNode.addClass('current').select();
    this.cy.fit(selectedNode);
  }

  static toggleTooltip(event) {
    const { tooltip } = event.target;
    if (typeof tooltip !== 'undefined') {
      if (tooltip.state.isVisible) {
        tooltip.hide();
      } else {
        tooltip.show();
      }
    }
    return false;
  }

  elementMouseOver(e) {
    const element = e.target;
    if (element.data('tooltip')) {
      element.addClass('hover');
      this.container.style.cursor = 'pointer';
    }
  }

  elementMouseOut(e) {
    const element = e.target;
    if (element.data('tooltip')) {
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
        tippy.hideAll({ exclude: instance });
        this.cy.on('vclick', instance.hide);
      },
      onHide: (instance) => {
        this.cy.off('vclick', instance.hide);
      },
    });
  }

  initZoomControls() {
    this.zoom.setAttribute('min', this.cy.minZoom());
    this.zoom.setAttribute('max', this.cy.maxZoom());
    this.zoom.setAttribute('step', 0.1);
    this.zoom.value = this.constructor.roundZoom(this.cy.zoom());
    this.zoom.addEventListener('change', () => {
      this.cy.zoom(parseFloat(this.zoom.value));
    });
  }

  static roundZoom(zoom) {
    return Math.round(zoom * 10) / 10;
  }

  zoomIn() {
    const step = parseFloat(this.zoom.getAttribute('step'));
    let zoom = Math.min(this.cy.maxZoom(), this.cy.zoom() + step);
    zoom = this.constructor.roundZoom(zoom);
    this.cy.zoom(zoom);
    this.zoom.value = zoom;
  }

  zoomOut() {
    const step = parseFloat(this.zoom.getAttribute('step'));
    let zoom = Math.max(this.cy.minZoom(), this.cy.zoom() - step);
    zoom = this.constructor.roundZoom(zoom);
    this.cy.zoom(zoom);
    this.zoom.value = zoom;
  }

  init() {
    this.container = document.querySelector('.cytoscape-container');
    if (this.container === null) {
      return;
    }
    this.zoom = document.querySelector('.graph-zoom');
    this.zoomPlus = document.querySelector('.graph-controls .fa-search-plus');
    this.zoomMinus = document.querySelector('.graph-controls .fa-search-minus');
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
      userZoomingEnabled: false,
    });

    this.cy.elements().forEach((element) => {
      if (element.data('tooltip')) {
        element.tooltip = this.tooltip(element);
      }
    });

    this.cy.ready(this.centerOnSelected);
    this.cy.ready(this.initZoomControls);
    this.cy.on('vclick', '*', this.constructor.toggleTooltip);
    this.cy.on('mouseover', '*', this.elementMouseOver);
    this.cy.on('mouseout', '*', this.elementMouseOut);
    this.cy.on('zoom', () => {
      const zoom = this.constructor.roundZoom(this.cy.zoom());
      this.zoom.value = zoom;
    });

    tippy('.graph-zoom', { arrow: true, placement: 'bottom' });

    this.zoomMinus.addEventListener('click', this.zoomOut);
    this.zoomPlus.addEventListener('click', this.zoomIn);
  }
}

export default EntityGraph;
