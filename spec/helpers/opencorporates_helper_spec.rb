require 'rails_helper'

RSpec.describe OpencorporatesHelper do
  describe '#previous_names' do
    subject { helper.previous_names(company_hash) }

    context 'when the company has previous names' do
      let(:company_hash) do
        {
          previous_names: [
            {
              company_name: 'FOO LIMITED',
            },
            {
              company_name: 'BAR LIMITED',
            },
          ],
        }
      end

      it 'returns a string containing the previous names' do
        expect(subject).to eq('FOO LIMITED, BAR LIMITED')
      end
    end

    context 'when the company has no previous names' do
      let(:company_hash) do
        {
          previous_names: [],
        }
      end

      it 'returns an empty string' do
        expect(subject).to eq('')
      end
    end
  end

  describe '#industry_codes' do
    subject { helper.industry_codes(company_hash) }

    context 'when then company has industry codes' do
      let(:company_hash) do
        {
          industry_codes: [
            {
              industry_code: {
                code: '62012',
                description: 'Business and domestic software development',
              },
            },
          ],
        }
      end

      it 'returns a string containing the codes and their descriptions' do
        expect(subject).to eq('62012 Business and domestic software development')
      end
    end

    context 'when the company has no industry codes' do
      let(:company_hash) do
        {
          industry_codes: [],
        }
      end

      it 'returns an empty string' do
        expect(subject).to eq('')
      end
    end
  end

  describe '#officers' do
    subject { helper.officers(company_hash) }

    context 'when the company has officers' do
      let(:officer_hash) do
        {
          name: 'Joe Bloggs',
          inactive: false,
        }
      end

      let(:company_hash) do
        {
          officers: [
            {
              officer: officer_hash,
            },
          ],
        }
      end

      it 'returns an array of officer hashes' do
        expect(subject).to eq([officer_hash])
      end

      context 'when the company has inactive officers' do
        let(:company_hash) do
          {
            officers: [
              {
                officer: officer_hash,
              },
              {
                officer: {
                  name: 'A. N. Other',
                  inactive: true,
                },
              },
            ],
          }
        end

        it 'filters out the inactive officers' do
          expect(subject).to eq([officer_hash])
        end
      end
    end

    context 'when the company has no officers' do
      let(:company_hash) do
        {
          officers: [],
        }
      end

      it 'returns an empty array' do
        expect(subject).to eq([])
      end
    end
  end

  describe '#officer_attributes_snippet' do
    subject { helper.officer_attributes_snippet(officer_hash) }

    context 'when the officer has attributes' do
      let(:officer_hash) do
        {
          position: 'director',
          start_date: '2011-07-15',
        }
      end

      it 'returns a formatted string' do
        expect(subject).to eq('Director (2011-07-15 – )')
      end
    end

    context 'when the officer does not have attributes' do
      let(:officer_hash) do
        {}
      end

      it 'returns an empty string' do
        expect(subject).to eq('')
      end
    end
  end
end
