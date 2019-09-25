require 'rails_helper'

RSpec.describe BodsCompanyNumberExtractor do
  let(:schemes) { %w[test1 test2] }

  subject { BodsCompanyNumberExtractor.new(schemes) }

  it "extracts identifiers with any of the given schemes" do
    identifiers = [{ 'scheme' => 'test1', 'id' => '1234567' }]
    expect(subject.extract(identifiers)).to eq '1234567'

    identifiers = [{ 'scheme' => 'test2', 'id' => '5678910' }]
    expect(subject.extract(identifiers)).to eq '5678910'
  end

  it "prefers identifiers in the order they're given" do
    identifiers = [
      { 'scheme' => 'test1', 'id' => '1234567' },
      { 'scheme' => 'test2', 'id' => '5678910' },
    ]
    expect(subject.extract(identifiers)).to eq '1234567'
  end

  it "returns nil if there's no identifier with any of the given schemes" do
    identifiers = [{ 'scheme' => 'GB-COH', 'id' => '1234567' }]
    expect(subject.extract(identifiers)).to be_nil
  end

  it "skips identifiers that don't have an id" do
    identifiers = [
      { 'scheme' => 'test1' },
      { 'scheme' => 'test2', 'id' => '5678910' },
    ]
    expect(subject.extract(identifiers)).to eq('5678910')
  end

  it 'returns nil if no matching identifiers have an id' do
    identifiers = [
      { 'scheme' => 'test1' },
      { 'scheme' => 'test2' },
    ]
    expect(subject.extract(identifiers)).to be_nil
  end

  it "returns the first identifier if there are several with the same scheme" do
    identifiers = [
      { 'scheme' => 'test1', 'id' => '1234567' },
      { 'scheme' => 'test1', 'id' => '89101112' },
    ]
    expect(subject.extract(identifiers)).to eq '1234567'
  end
end
