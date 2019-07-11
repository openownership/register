import {default as stringToColor} from 'string-to-color';
import tippy from 'tippy.js';

class Tree {
  document = null;
  treeWindow = null;
  treeZoom = null;
  treeCanvas = null;
  treeGroup = null;
  id = null;
  key = null;
  x = null;
  y = null;
  z = null;
  groupedTooltip = null;
  peopleNodes = [];
  peopleEntities = [];

  constructor(document) {
    this.document = document;
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

    var dx = (event.pageX || event.originalEvent.touches[0].clientX) - this.x;
    var dy = (event.pageY || event.originalEvent.touches[0].clientY) - this.y;

    var mouseMove = function(event) {
      event.preventDefault();

      var mx = event.pageX || event.originalEvent.touches[0].clientX;
      var my = event.pageY || event.originalEvent.touches[0].clientY;

      this.x = mx - dx;
      this.y = my - dy;

      sessionStorage.setItem(this.key + "x", this.x);
      sessionStorage.setItem(this.key + "y", this.y);

      this.update();
    };
    mouseMove = mouseMove.bind(this);

    var mouseUp = function(event) {
      event.preventDefault();
      this.document.removeEventListener('mousemove', mouseMove);
      this.document.removeEventListener('touchmove', mouseMove);
      // Instead of using the once option (so that it works in IE)
      this.document.removeEventListener('mouseup', mouseUp);
      this.document.removeEventListener('touchend', mouseUp);
    };
    mouseUp = mouseUp.bind(this);

    this.document.addEventListener('mousemove', mouseMove);
    this.document.addEventListener('touchmove', mouseMove);

    this.document.addEventListener('mouseup', mouseUp);
    this.document.addEventListener('touchend', mouseUp);
  }

  inputChange() {
    this.z = this.treeZoom.value;
    sessionStorage.setItem(this.key + "z", this.z);
    this.update();
  }

  update() {
    this.treeZoom.value = this.z;
    this.treeCanvas.style.transform = "translate(" + this.x + "px, " + this.y + "px)";
    this.treeGroup.style.transform ="scale(" + this.scale(this.z) + ")";
  }

  scale(n) {
    return 0.5 + (n / 100);
  }

  zoomIn() {
    this.z = Math.min(100, this.z + 10);
    sessionStorage.setItem(this.key + "z", this.z);
    this.update();
  }

  zoomOut() {
    this.z = Math.max(0, this.z - 10);
    sessionStorage.setItem(this.key + "z", this.z);
    this.update();
  }

  highlightSimilarPeople(node) {
    var id = node.dataset.node;
    var similar = this.document.querySelectorAll('[data-node="' + id + '"]');
    var entity = node.querySelector('.tree-node__entity');

    if (similar.length > 1) {
      entity.style.outline = '2px solid ' + stringToColor(id);
      tippy(entity, { content: this.groupedTooltip, offset: "5, 0" });
    }
  }

  similarMouseOver(entity) {
    var id = entity.closest('[data-node]').dataset.node;
    var similar = this.document.querySelectorAll('[data-node="' + id + '"]');

    if (similar.length > 1) {
      var similarArray = Array.from(similar);
      this.document.querySelectorAll('[data-node]').forEach(function(node) {
        if(!similarArray.includes(node)) {
          node.style.opacity = 0.5;
        }
      });
    }
  }

  similarMouseOut() {
    this.document.querySelectorAll('[data-node]').forEach(function(node) {
      node.style.opacity = 1;
    });
  }

  bindSimilarHover(entity) {
    entity.addEventListener('mouseover', () => { this.similarMouseOver(entity) });
    entity.addEventListener('mouseout', this.similarMouseOut);
  }

  init() {
    this.treeWindow = this.document.querySelector('.tree-window');
    if(this.treeWindow === null) {
      return;
    }
    this.id = this.treeWindow.dataset.tree;
    this.key = "tree-" + this.id + "-";
    this.x = parseInt(sessionStorage.getItem(this.key + "x")) || 0;
    this.y = parseInt(sessionStorage.getItem(this.key + "y")) || 0;
    this.z = parseInt(sessionStorage.getItem(this.key + "z")) || 50;
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
