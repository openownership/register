require 'rails_helper'

RSpec.describe BodsCompanyNumberExtractor do
  let(:scheme) { 'test' }

  subject { BodsCompanyNumberExtractor.new(scheme) }

  it "extracts identifiers with the given scheme" do
    identifiers = [{ 'scheme' => scheme, 'id' => '1234567' }]
    expect(subject.extract(identifiers)).to eq '1234567'
  end

  it "returns nil if there's no identifier with the given scheme" do
    identifiers = [{ 'scheme' => 'GB-COH', 'id' => '1234567' }]
    expect(subject.extract(identifiers)).to be_nil
  end

  it "returns nil if there's an identifier but it doesn't have an id" do
    identifiers = [{ 'scheme' => scheme }]
    expect(subject.extract(identifiers)).to be_nil
  end

  it "returns the first identifier if there are several with the same scheme" do
    identifiers = [
      { 'scheme' => scheme, 'id' => '1234567' },
      { 'scheme' => scheme, 'id' => '89101112' },
    ]
    expect(subject.extract(identifiers)).to eq '1234567'
  end
end
