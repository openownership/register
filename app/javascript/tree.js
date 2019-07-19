import stringToColor from 'string-to-color';
import tippy from 'tippy.js';

class Tree {
  constructor(document) {
    this.document = document;
    this.treeWindow = null;
    this.treeZoom = null;
    this.treeCanvas = null;
    this.treeGroup = null;
    this.id = null;
    this.key = null;
    this.x = null;
    this.y = null;
    this.z = null;
    this.groupedTooltip = null;
    this.peopleNodes = [];
    this.peopleEntities = [];

    this.mouseDown = this.mouseDown.bind(this);
    this.inputChange = this.inputChange.bind(this);
    this.update = this.update.bind(this);
    this.zoomIn = this.zoomIn.bind(this);
    this.zoomOut = this.zoomOut.bind(this);
    this.highlightSimilarPeople = this.highlightSimilarPeople.bind(this);
    this.similarMouseOver = this.similarMouseOver.bind(this);
    this.similarMouseOut = this.similarMouseOut.bind(this);
    this.bindSimilarHover = this.bindSimilarHover.bind(this);
  }

  mouseDown(event) {
    event.preventDefault();

    const dx = (event.pageX || event.originalEvent.touches[0].clientX) - this.x;
    const dy = (event.pageY || event.originalEvent.touches[0].clientY) - this.y;

    const mouseMove = (moveEvent) => {
      moveEvent.preventDefault();

      const mx = moveEvent.pageX || moveEvent.originalEvent.touches[0].clientX;
      const my = moveEvent.pageY || moveEvent.originalEvent.touches[0].clientY;

      this.x = mx - dx;
      this.y = my - dy;

      sessionStorage.setItem(`${this.key}x`, this.x);
      sessionStorage.setItem(`${this.key}y`, this.y);

      this.update();
    };

    const mouseUp = (upEvent) => {
      upEvent.preventDefault();
      this.document.removeEventListener('mousemove', mouseMove);
      this.document.removeEventListener('touchmove', mouseMove);
      // Instead of using the once option (so that it works in IE)
      this.document.removeEventListener('mouseup', mouseUp);
      this.document.removeEventListener('touchend', mouseUp);
    };

    this.document.addEventListener('mousemove', mouseMove);
    this.document.addEventListener('touchmove', mouseMove);

    this.document.addEventListener('mouseup', mouseUp);
    this.document.addEventListener('touchend', mouseUp);
  }

  inputChange() {
    this.z = this.treeZoom.value;
    sessionStorage.setItem(`${this.key}z`, this.z);
    this.update();
  }

  update() {
    this.treeZoom.value = this.z;
    this.treeCanvas.style.transform = `translate(${this.x}px, ${this.y}px)`;
    this.treeGroup.style.transform = `scale(${0.5 + (this.z / 100)})`;
  }

  zoomIn() {
    this.z = Math.min(100, this.z + 10);
    sessionStorage.setItem(`${this.key}z`, this.z);
    this.update();
  }

  zoomOut() {
    this.z = Math.max(0, this.z - 10);
    sessionStorage.setItem(`${this.key}z`, this.z);
    this.update();
  }

  highlightSimilarPeople(node) {
    const id = node.dataset.node;
    const similar = this.document.querySelectorAll(`[data-node="${id}"]`);
    const entity = node.querySelector('.tree-node__entity');

    if (similar.length > 1) {
      entity.style.outline = `2px solid ${stringToColor(id)}`;
      tippy(entity, { content: this.groupedTooltip, offset: '5, 0' });
    }
  }

  similarMouseOver(entity) {
    const id = entity.closest('[data-node]').dataset.node;
    const similar = this.document.querySelectorAll(`[data-node="${id}"]`);

    if (similar.length > 1) {
      const similarArray = Array.from(similar);
      this.document.querySelectorAll('[data-node]').forEach((node) => {
        if (!similarArray.includes(node)) {
          node.style.opacity = 0.5;
        }
      });
    }
  }

  similarMouseOut() {
    this.document.querySelectorAll('[data-node]').forEach((node) => {
      node.style.opacity = 1;
    });
  }

  bindSimilarHover(entity) {
    entity.addEventListener('mouseover', () => this.similarMouseOver(entity));
    entity.addEventListener('mouseout', this.similarMouseOut);
  }

  init() {
    this.treeWindow = this.document.querySelector('.tree-window');
    if (this.treeWindow === null) {
      return;
    }
    this.id = this.treeWindow.dataset.tree;
    this.key = `tree-${this.id}-`;
    this.x = parseInt(sessionStorage.getItem(`${this.key}x`), 10) || 0;
    this.y = parseInt(sessionStorage.getItem(`${this.key}y`), 10) || 0;
    this.z = parseInt(sessionStorage.getItem(`${this.key}z`), 10) || 50;
    this.groupedTooltip = this.treeWindow.dataset.groupedTooltip;
    this.treeZoom = this.document.querySelector('.tree-zoom');
    this.treeCanvas = this.document.querySelector('.tree-canvas');
    this.treeGroup = this.document.querySelector('.tree-group');
    this.zoomMinus = this.document.querySelector('.tree-controls .fa-search-minus');
    this.zoomPlus = this.document.querySelector('.tree-controls .fa-search-plus');
    this.peopleNodes = this.document.querySelectorAll('.tree-node--natural-person');
    this.peopleEntities = this.document.querySelectorAll('.tree-node--natural-person .tree-node__entity');

    this.update();

    this.treeWindow.addEventListener('mousedown', this.mouseDown);
    this.treeWindow.addEventListener('touchstart', this.mouseDown);

    this.treeZoom.addEventListener('input', this.inputChange);
    this.treeZoom.addEventListener('change', this.inputChange);

    this.zoomMinus.addEventListener('click', this.zoomOut);
    this.zoomPlus.addEventListener('click', this.zoomIn);

    this.peopleNodes.forEach(this.highlightSimilarPeople);
    this.peopleEntities.forEach(this.bindSimilarHover);

    this.treeCanvas.style.opacity = 1;
  }
}

export default Tree;
