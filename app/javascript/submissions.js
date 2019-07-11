import tippy from 'tippy.js';

class Submissions {
  document = null;
  searchInput = null;
  searchForm = null;

  constructor(document) {
    this.document = document;
    this.showEmptySearchTooltip = this.showEmptySearchTooltip.bind(this);
    this.showSpinner = this.showSpinner.bind(this);
  }

  showEmptySearchTooltip() {
    tippy(this.searchInput, {
      content: this.searchInput.dataset.tooltip,
      placement: 'top',
      trigger: 'manual',
      offset: '5, 0'
    }).show();
  }

  showSpinner() {
    var overlay = this.document.createElement('div')
    overlay.classList.add('submission-overlay');
    var spinner = this.document.createElement('div');
    spinner.classList.add('submission-overlay__spinner');
    overlay.appendChild(spinner);
    this.document.querySelector('body').appendChild(overlay);
  }

  init() {
    this.searchInput = this.document.querySelector('.submission-search-field .form-control');
    if(this.searchInput === null) {
      return;
    }
    this.searchForm = this.document.querySelector('.submission-search-form');

    if(this.searchInput.value === '') {
      this.showEmptySearchTooltip();
    }

    this.searchForm.addEventListener('submit', this.showSpinner);
  }
}

export default Submissions;
