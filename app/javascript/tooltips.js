class Tooltips {
  $ = null;

  constructor($) {
    this.$ = $;
  }

  init() {
    $('[data-toggle="tooltip"]').tooltip();
  }
}

export default Tooltips
