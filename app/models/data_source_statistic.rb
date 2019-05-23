class DataSourceStatistic
  include Mongoid::Document
  include Mongoid::Timestamps

  field :type, type: String
  field :value, type: Integer

  embedded_in :data_source

  module Types
    TOTAL = 'total'.freeze
    REGISTER_TOTAL = 'register_total'.freeze
    DISSOLVED = 'dissolved'.freeze
    PSC_UNKNOWN_OWNER = 'psc_unknown_owner'.freeze
    PSC_NO_OWNER = 'psc_no_owner'.freeze
    PSC_OFFSHORE_RLE = 'psc_offshore_rle'.freeze
    PSC_NON_LEGIT_RLE = 'psc_non_legit_rle'.freeze
    PSC_SECRECY_RLE = 'psc_secrecy_rle'.freeze
  end

  def total?
    type == Types::TOTAL
  end

  def show_as_percentage?
    type != Types::DISSOLVED
  end
end
