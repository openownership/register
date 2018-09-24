require 'rails_helper'

RSpec.describe ChunkHelper do
  let :strings do
    %w[foo bar baz]
  end

  let :chunk do
    "eJxLy8/nSkosAuIqABayA8s=\n"
  end

  describe '.to_chunk' do
    it 'should transform the list of strings into a compressed and base64 encoded string' do
      expect(subject.to_chunk(strings)).to eq chunk
    end
  end

  describe '.from_chunk' do
    it 'should transform back the compressed and base64 encoded strings into a list of strings' do
      expect(subject.from_chunk(chunk)).to eq strings
    end
  end

  describe 'both .to_chunk and .from_chunk working in tandem' do
    it 'should convert then transform back the list of strings' do
      expect(
        subject.from_chunk(
          subject.to_chunk(strings),
        ),
      ).to eq strings
    end
  end
end
