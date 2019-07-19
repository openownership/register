import tippy from 'tippy.js';

class Submissions {
  constructor(document) {
    this.document = document;
    this.searchInput = null;
    this.searchForm = null;

    this.showEmptySearchTooltip = this.showEmptySearchTooltip.bind(this);
    this.showSpinner = this.showSpinner.bind(this);
  }

  showEmptySearchTooltip() {
    tippy(this.searchInput, {
      content: this.searchInput.dataset.tooltip,
      placement: 'top',
      trigger: 'manual',
      offset: '5, 0',
    }).show();
  }

  showSpinner() {
    const overlay = this.document.createElement('div');
    overlay.classList.add('submission-overlay');
    const spinner = this.document.createElement('div');
    spinner.classList.add('submission-overlay__spinner');
    overlay.appendChild(spinner);
    this.document.querySelector('body').appendChild(overlay);
  }

  init() {
    this.searchInput = this.document.querySelector('.submission-search-field .form-control');
    if (this.searchInput === null) {
      return;
    }
    this.searchForm = this.document.querySelector('.submission-search-form');

    if (this.searchInput.value === '') {
      this.showEmptySearchTooltip();
    }

    this.searchForm.addEventListener('submit', this.showSpinner);
  }
}

export default Submissions;
