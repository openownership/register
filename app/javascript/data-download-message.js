class DataDownloadMessage {
  constructor(document) {
    this.document = document;
    this.alert = null;
    this.setCookie = this.setCookie.bind(this);
  }

  setCookie() {
    this.document.cookie = 'seenDataDownloadAvailableMessage=1; max-age=31536000';
  }

  init() {
    this.alert = this.document.querySelector('.data-download-alert');
    if (this.alert !== null) {
      this.alert.addEventListener('close.bs.alert', this.setCookie);
    }
  }
}

export default DataDownloadMessage;
