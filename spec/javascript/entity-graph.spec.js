import EntityGraph from 'entity-graph';

function escapeHtml(unsafe) {
  return unsafe
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

describe('EntityGraph', () => {
  const elements = {
    nodes: [
      {
        data: {
          label: 'Test Person',
          id: 'abc123',
          tooltip: '<div class="tooltip">Test Person Tooltip</div>',
          classes: [],
        },
      },
      {
        data: {
          label: 'Test Company',
          id: 'def456',
          tooltip: '<div class="tooltip">Test Company Tooltip</div>',
          classes: [],
        },
      },
    ],
    edges: [
      {
        data: {
          id: 'hij789',
          source: 'abc123',
          target: 'def456',
          tooltip: '<div class="tooltip">Test Relationship Tooltip</div>',
          classes: [],
        },
      },
    ],
  };

  const body = `
    <div class="graph-controls">
      <div class="graph-zoom-control">
        <span class="fa fa-search-minus"></span>
        <input type="range" class="graph-zoom">
        <span class="fa fa-search-plus"></span>
      </div>
    </div>
    <div class="cytoscape-container"
         data-elements="${escapeHtml(JSON.stringify(elements))}"
         data-selected="abc123">
    </div>`;

  let graph = null;

  beforeEach(() => {
    document.body.innerHTML = body;
    graph = new EntityGraph(document);
  });

  describe('init', () => {
    beforeEach(() => {
      graph.init();
    });

    it('initialises a Cytoscape object with the nodes and edges', () => {
      expect(graph.cy).not.toBeNull();
      const nodes = graph.cy.nodes();
      const edges = graph.cy.edges();

      expect(nodes.length).toBe(2);

      expect(nodes[0].id()).toBe('abc123');
      expect(nodes[0].data('label')).toBe('Test Person');
      expect(nodes[0].data('tooltip')).toBe('<div class="tooltip">Test Person Tooltip</div>');
      expect(nodes[0].data('classes')).toEqual([]);

      expect(nodes[1].id()).toBe('def456');
      expect(nodes[1].data('label')).toBe('Test Company');
      expect(nodes[1].data('tooltip')).toBe('<div class="tooltip">Test Company Tooltip</div>');
      expect(nodes[1].data('classes')).toEqual([]);

      expect(edges.length).toBe(1);

      expect(edges[0].id()).toBe('hij789');
      expect(edges[0].data('source')).toBe('abc123');
      expect(edges[0].data('target')).toBe('def456');
      expect(edges[0].data('classes')).toEqual([]);
      expect(edges[0].data('tooltip')).toBe('<div class="tooltip">Test Relationship Tooltip</div>');
    });

    it('initialises the zoom controls min/max and step', () => {
      const zoomControl = document.querySelector('.graph-zoom');
      expect(zoomControl.getAttribute('min')).toEqual(graph.cy.minZoom().toString());
      expect(zoomControl.getAttribute('max')).toEqual(graph.cy.maxZoom().toString());
      expect(zoomControl.getAttribute('step')).toEqual('0.1');
    });
  });

  describe('zooming the graph', () => {
    let zoomIn = null;
    let zoomOut = null;
    let zoomInput = null;

    beforeEach(() => {
      graph.init();
      zoomIn = document.querySelector('.fa-search-plus');
      zoomOut = document.querySelector('.fa-search-minus');
      zoomInput = document.querySelector('.graph-zoom');
    });

    it('zooms when the plus/minus icons are clicked', () => {
      graph.cy.zoom(graph.cy.maxZoom());

      zoomOut.click();
      expect(graph.cy.zoom()).toBeLessThan(graph.cy.maxZoom());

      zoomIn.click();
      expect(graph.cy.zoom()).toBeCloseTo(graph.cy.maxZoom(), 5);
    });

    it('keeps the zoom level within min/max limits', () => {
      graph.cy.zoom(graph.cy.maxZoom());

      zoomIn.click();
      expect(graph.cy.zoom()).toBeCloseTo(graph.cy.maxZoom(), 5);

      graph.cy.zoom(graph.cy.minZoom());

      zoomOut.click();
      expect(graph.cy.zoom()).toBeCloseTo(graph.cy.minZoom(), 5);
    });

    it('keeps the zoom input in sync with the buttons', () => {
      graph.cy.zoom(graph.cy.maxZoom());

      zoomOut.click();
      expect(parseFloat(zoomInput.value)).toBeCloseTo(graph.cy.zoom(), 5);
    });

    it('zooms when the input changes', () => {
      const currentZoom = graph.cy.zoom();

      const zoomControl = document.querySelector('.graph-zoom');
      zoomControl.value = currentZoom - 0.1;
      const event = new Event('change');
      zoomControl.dispatchEvent(event);

      expect(graph.cy.zoom()).toEqual(parseFloat(zoomControl.value));
    });
  });

  describe('showing tooltips', () => {
    beforeEach(() => {
      graph.init();
    });

    it('shows a tooltip when you click on a node', () => {
      graph.cy.getElementById('abc123').emit('vclick');
      const tooltip = document.querySelector('.tooltip');
      expect(tooltip.innerHTML).toEqual('Test Person Tooltip');
    });

    it('shows a tooltip when you click on an edge', () => {
      graph.cy.getElementById('hij789').emit('vclick');
      const tooltip = document.querySelector('.tooltip');
      expect(tooltip.innerHTML).toEqual('Test Relationship Tooltip');
    });

    it('hides other tooltips when you click on something else', () => {
      graph.cy.getElementById('hij789').emit('click');
      graph.cy.getElementById('def456').emit('vclick');
      const tooltip = document.querySelector('.tooltip');
      expect(tooltip.innerHTML).toEqual('Test Company Tooltip');
    });
  });

  describe('hovering nodes', () => {
    beforeEach(() => {
      graph.init();
    });

    it('adds a hover class during mouseover', () => {
      const node = graph.cy.getElementById('abc123');
      node.emit('mouseover');
      expect(node.classes()).toContain('hover');
      node.emit('mouseout');
      expect(node.classes()).not.toContain('hover');
    });

    it('adds a cursor pointer to the container during mouseover', () => {
      const container = document.querySelector('.cytoscape-container');
      graph.cy.getElementById('abc123').emit('mouseover');
      expect(container.style.cursor).toBe('pointer');
      graph.cy.getElementById('abc123').emit('mouseout');
      expect(container.style.cursor).toBe('default');
    });
  });
});
