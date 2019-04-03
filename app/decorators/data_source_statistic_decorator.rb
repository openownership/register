class DataSourceStatisticDecorator < ApplicationDecorator
  delegate_all

  def title(footnote_index)
    title = I18n.t("data_source_statistics.#{type}.title")
    return title if footnote(footnote_index).blank?
    "#{title} [<a href='##{footnote_anchor(footnote_index)}'>#{footnote_index}</a>]"
  end

  def footnote?
    I18n.exists?(footnote_key)
  end

  def footnote(index)
    return unless footnote?
    "<span id='#{footnote_anchor(index)}'>[#{index}] #{I18n.t(footnote_key)}</span>"
  end

  def percentage(total)
    value.to_f / total.value.to_f * 100.0
  end

  private

  def footnote_key
    "data_source_statistics.#{type}.footnote_html"
  end

  def footnote_anchor(index)
    "statistic-footnote-#{index}"
  end
end
