class OCAdditionalInfo {
  constructor(document) {
    this.document = document;
    this.additionalInfo = null;
    this.noDataMessage = null;
    this.additionalInfoUrl = null;
    this.showNoDataMsg = this.showNoDataMsg.bind(this);
    this.getAdditionalInfo = this.getAdditionalInfo.bind(this);
  }

  showNoDataMsg() {
    this.additionalInfo.innerHTML = `
      <div class="frame-light meta">
        <div class="frame-wrap">
          <p class="unknown">${this.noDataMsg}</p>
        </div>
      </div>`;
  }

  getAdditionalInfo() {
    const request = new XMLHttpRequest();
    request.open('GET', this.additionalInfoUrl, true);
    request.onload = () => {
      if (request.status >= 200 && request.status < 400) {
        this.additionalInfo.innerHTML = request.responseText;
      } else {
        this.showNoDataMsg();
      }
    };
    request.onerror = this.showNoDataMsg;
    request.send();
  }

  init() {
    this.additionalInfo = this.document.querySelector('.js-opencorporates-additional-info');
    if (this.additionalInfo === null) {
      return;
    }
    this.noDataMsg = this.additionalInfo.dataset.noDataMsg;
    this.additionalInfoUrl = this.additionalInfo.dataset.additionalInfoUrl;
    this.getAdditionalInfo();
  }
}

export default OCAdditionalInfo;
