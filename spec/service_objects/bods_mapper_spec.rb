require 'rails_helper'

RSpec.describe BodsMapper do
  describe "#statement_id" do
    context "for Entities" do
      let(:entity) { create(:legal_entity) }

      it "returns a stable id" do
        id = BodsMapper.new.statement_id(entity)
        second_id = BodsMapper.new.statement_id(entity)
        expect(id).to eq second_id
      end

      it "returns different ids for different entities" do
        other_entity = create(:entity)
        id = BodsMapper.new.statement_id(entity)
        other_id = BodsMapper.new.statement_id(other_entity)
        expect(id).not_to eq other_id
      end

      it 'changes when the entity itself changes' do
        entity.set(self_updated_at: 1.second.ago)
        id = BodsMapper.new.statement_id(entity)
        entity.touch(:self_updated_at)
        new_id = BodsMapper.new.statement_id(entity)
        expect(id).not_to eq new_id
      end

      it "doesn't change when just a relationship to the entity changes" do
        entity.set(updated_at: 1.second.ago)
        id = BodsMapper.new.statement_id(entity)
        entity.touch # This is what changing a relationship will do
        new_id = BodsMapper.new.statement_id(entity)
        expect(id).to eq new_id
      end

      context 'for UnknownPersonsEntities' do
        let(:statement) { create(:statement, type: 'psc-exists-but-not-identified') }
        let(:unknown_entity) do
          UnknownPersonsEntity.new_for_statement(statement)
        end

        it "returns a stable id" do
          id = BodsMapper.new.statement_id(unknown_entity)
          second_id = BodsMapper.new.statement_id(unknown_entity)
          expect(id).to eq second_id
        end

        it "returns different ids for different statements" do
          other_statement = create(:statement, type: 'psc-exists-but-not-identified')
          other_unknown_entity = UnknownPersonsEntity.new_for_statement(other_statement)
          id = BodsMapper.new.statement_id(unknown_entity)
          other_id = BodsMapper.new.statement_id(other_unknown_entity)
          expect(id).not_to eq other_id
        end

        it "changes when the underlying statement changes" do
          statement.set(updated_at: 1.second.ago) # Otherwise it can end up identical
          id = BodsMapper.new.statement_id(unknown_entity)
          statement.touch
          new_unknown_entity = UnknownPersonsEntity.new_for_statement(statement)
          new_id = BodsMapper.new.statement_id(new_unknown_entity)
          expect(id).not_to eq new_id
        end

        it "returns nil for entities which don't generate statements" do
          unknown_entity = UnknownPersonsEntity.new_for_entity(create(:legal_entity))
          id = BodsMapper.new.statement_id(unknown_entity)
          expect(id).to be_nil
        end
      end
    end

    context "for Relationships" do
      let(:relationship) { create(:relationship) }

      it "returns a stable id" do
        id = BodsMapper.new.statement_id(relationship)
        second_id = BodsMapper.new.statement_id(relationship)
        expect(id).to eq second_id
      end

      it "returns different ids for different entities" do
        other_relationship = create(:relationship)
        id = BodsMapper.new.statement_id(relationship)
        other_id = BodsMapper.new.statement_id(other_relationship)
        expect(id).not_to eq other_id
      end

      it 'changes when the relationship changes' do
        relationship.set(updated_at: 1.second.ago) # Otherwise it can end up idential
        id = BodsMapper.new.statement_id(relationship)
        relationship.touch
        new_id = BodsMapper.new.statement_id(relationship)
        expect(id).not_to eq new_id
      end

      it 'changes when the source entity changes' do
        relationship.source.set(updated_at: 1.second.ago) # Otherwise it can end up idential
        id = BodsMapper.new.statement_id(relationship)
        relationship.source.touch(:self_updated_at)
        new_id = BodsMapper.new.statement_id(relationship)
        expect(id).not_to eq new_id
      end

      it 'changes when the relationship entity changes' do
        relationship.target.set(updated_at: 1.second.ago) # Otherwise it can end up idential
        id = BodsMapper.new.statement_id(relationship)
        relationship.target.touch(:self_updated_at)
        new_id = BodsMapper.new.statement_id(relationship)
        expect(id).not_to eq new_id
      end
    end

    context "for Statements" do
      let(:statement) { create(:statement) }

      it "returns a stable id" do
        id = BodsMapper.new.statement_id(statement)
        second_id = BodsMapper.new.statement_id(statement)
        expect(id).to eq second_id
      end

      it "returns different ids for different statements" do
        other_statement = create(:statement)
        id = BodsMapper.new.statement_id(statement)
        other_id = BodsMapper.new.statement_id(other_statement)
        expect(id).not_to eq other_id
      end

      it 'changes when the statement changes' do
        statement.set(updated_at: 1.second.ago) # Otherwise it can end up idential
        id = BodsMapper.new.statement_id(statement)
        statement.touch
        new_id = BodsMapper.new.statement_id(statement)
        expect(id).not_to eq new_id
      end

      it 'changes when the statement entity changes' do
        statement.entity.set(updated_at: 1.second.ago) # Otherwise it can end up idential
        id = BodsMapper.new.statement_id(statement)
        statement.entity.touch(:self_updated_at)
        new_id = BodsMapper.new.statement_id(statement)
        expect(id).not_to eq new_id
      end
    end

    it "raises an error for other classes" do
      obj = Object.new
      expected = "Unexpected object for statement_id - class: #{obj.class.name}, obj: #{obj.inspect}"
      expect { BodsMapper.new.statement_id(obj) }.to raise_error(expected)
    end
  end

  describe "#generates_statement?" do
    it 'returns true for a company' do
      company = create(:legal_entity)
      expect(BodsMapper.new.generates_statement?(company)).to eq(true)
    end

    it 'returns true for a person' do
      person = create(:natural_person)
      expect(BodsMapper.new.generates_statement?(person)).to eq(true)
    end

    it 'returns false for an totally unknown person' do
      company = create(:legal_entity)
      unknown_person = UnknownPersonsEntity.new_for_entity(company)
      expect(BodsMapper.new.generates_statement?(unknown_person)).to eq(false)
    end

    it 'returns true for unknown people from the right set of PSC statement types' do
      %w[
        psc-contacted-but-no-response
        psc-contacted-but-no-response-partnership
        restrictions-notice-issued-to-psc
        restrictions-notice-issued-to-psc-partnership
        psc-exists-but-not-identified
        psc-exists-but-not-identified-partnership
        psc-details-not-confirmed
        psc-has-failed-to-confirm-changed-details
        psc-details-not-confirmed-partnership
        psc-has-failed-to-confirm-changed-details-partnership
        super-secure-person-with-significant-control
      ].each do |statement_type|
        statement = create(:statement, type: statement_type)
        unknown_person = UnknownPersonsEntity.new_for_statement(statement)
        expect(BodsMapper.new.generates_statement?(unknown_person)).to eq(true)
      end
    end

    it 'returns false for unknown people from the other PSC statement types' do
      %w[
        no-individual-or-entity-with-signficant-control
        no-individual-or-entity-with-signficant-control-partnership
        disclosure-transparency-rules-chapter-five-applies
        psc-exempt-as-trading-on-regulated-market
        psc-exempt-as-shares-admitted-on-market
        steps-to-find-psc-not-yet-completed
        steps-to-find-psc-not-yet-completed-partnership
      ].each do |statement_type|
        statement = create(:statement, type: statement_type)
        unknown_person = UnknownPersonsEntity.new_for_statement(statement)
        expect(BodsMapper.new.generates_statement?(unknown_person)).to eq(false)
      end
    end
  end

  describe "#entity_statement" do
    let(:entity) { create(:legal_entity) }

    subject { BodsMapper.new.entity_statement(entity) }

    it "gives the statement an id"
    it 'sets statementType to entityStatement'
    it 'maps entityType to registeredEntity'
    it 'sets statementDate to nil'
    it 'sets the entity name'

    describe 'mapping identifiers' do
      context 'GB PSC' do
        context 'companies' do
          it 'sets the scheme to GB-COH and uses the company number for id'
        end
        context 'people' do
          it 'returns nil'
        end
      end

      context 'Denmark CVR' do
        context 'companies' do
          it 'sets the scheme to DK-CVR and uses the company number for id'
        end
        context 'people' do
          it 'sets the scheme to MISC-Denmark CVR and uses the beneficial owner id'
        end
      end

      context 'Slovakia PSP' do
        context 'companies' do
          it 'sets the scheme to SK-ORSR and uses the company number for id'
        end
        context 'people' do
          it 'sets the scheme to MISC-Slovakia PSP Register and uses the beneficial owner id'
        end
      end

      context 'Ukraine EDR' do
        context 'companies' do
          it 'sets the scheme to UA-EDR and uses the company number for id'
        end
        context 'people' do
          it 'returns nil'
        end
      end

      context 'EITI' do
        it 'returns nil for both companies and people'
      end

      context 'other sources' do
        it 'returns nil for both companies and people'
      end
    end

    describe 'mapping addresses' do
      it "maps to nil if there's no address"
      it 'maps to a registered address'

      describe 'setting country' do
        it "maps to nil if the entity has no country_code"
        it "maps to the entity's country_code if it exists"
      end
    end

    it 'maps foundingDate to ISO8601 formatted incorporation_date if it exists'
    it 'maps dissolutionDate to ISO8601 formatted dissolution_date if it exists'

    describe 'mapping incorporatedInJurisdiction' do
      let(:entity) { create(:legal_entity, jurisdiction_code: 'gb') }

      it 'maps the jurisdiction_code to a Jurisdiction' do
        expected = {
          name: 'United Kingdom of Great Britain and Northern Ireland',
          code: 'GB',
        }
        expect(subject[:incorporatedInJurisdiction]).to eq(expected)
      end

      context "when there's no jurisdiction_code" do
        let(:entity) { create(:legal_entity, jurisdiction_code: nil) }

        it 'maps to nil' do
          expect(subject[:incorporatedInJurisdiction]).to be_nil
        end
      end
    end
  end

  describe "#person_statement" do
    context 'when the person is a known person' do
      it "gives the statement an id"
      it 'sets statementDate to nil'
      it 'sets statementType to personStatement'
      it 'sets personType to knownPerson'

      describe 'mapping nationalities' do
        it "maps to nil if there's no nationality"
        it "maps to nil if there's a nationality but it's not a known country"
        it "maps to a country name and two-digit code if there's a nationality"
      end

      describe 'mapping addresses' do
        it "maps to nil if there's no address"

        describe "setting country" do
          context "when the country_of_residence looks like a country code" do
            it 'maps to nil if its not a known country code'
            it 'maps to the country code if its a known country code'
          end
          it 'maps to the ISO3166 code if the country_of_residence can be found as a name'
          it 'maps to the ISO3166 code if the country_of_residence can be found as a 3 digit code'
        end
      end
    end

    context 'when the person is an unknown person who generates a statement' do
      let(:psc_statement) { create(:statement, type: 'psc-exists-but-not-identified') }
      let(:relationship) { CreateRelationshipsForStatements.call(psc_statement.entity).first }
      let(:unknown_person) { relationship.source }
      subject { BodsMapper.new.person_statement(unknown_person) }

      it 'gives the statement an id' do
        expect(subject[:statementID]).to eq BodsMapper.new.statement_id(unknown_person)
      end

      describe 'setting the personType' do
        it 'sets it to anonymousPerson for PSC super-secure people' do
          psc_statement = create(:statement, type: 'super-secure-person-with-significant-control')
          relationship = CreateRelationshipsForStatements.call(psc_statement.entity).first
          statement = BodsMapper.new.person_statement(relationship.source)
          expect(statement[:personType]).to eq 'anonymousPerson'
        end

        it 'sets it to unknownPerson for all other unknown people' do
          %w[
            psc-contacted-but-no-response
            psc-contacted-but-no-response-partnership
            restrictions-notice-issued-to-psc
            restrictions-notice-issued-to-psc-partnership
            psc-exists-but-not-identified
            psc-exists-but-not-identified-partnership
            psc-details-not-confirmed
            psc-details-not-confirmed-partnership
            psc-has-failed-to-confirm-changed-details
            psc-has-failed-to-confirm-changed-details-partnership
          ].each do |psc_type|
            psc_statement = create(:statement, type: psc_type)
            relationship = CreateRelationshipsForStatements.call(psc_statement.entity).first
            statement = BodsMapper.new.person_statement(relationship.source)
            expect(statement[:personType]).to eq 'unknownPerson'
          end
        end
      end

      it "maps the missingInfoReason to the unknown person's unknown_reason" do
        expect(subject[:missingInfoReason]).to eq unknown_person.unknown_reason
      end

      it 'maps other fields to nil or empty lists as appropriate' do
        expect(subject[:statementDate]).to eq(nil)
        expect(subject[:names]).to eq([])
        expect(subject[:identifiers]).to eq([])
        expect(subject[:nationalities]).to eq([])
        expect(subject[:placeOfBirth]).to eq(nil)
        expect(subject[:birthDate]).to eq(nil)
        expect(subject[:deathDate]).to eq(nil)
        expect(subject[:placeOfResidence]).to eq(nil)
        expect(subject[:addresses]).to eq([])
        expect(subject[:pepStatus]).to eq(nil)
        expect(subject[:source]).to eq(nil)
        expect(subject[:annotations]).to eq(nil)
        expect(subject[:replacesStatements]).to eq(nil)
      end
    end
  end

  describe "#ownership_or_control_statement" do
    let(:relationship) { create(:relationship) }

    subject do
      BodsMapper.new.ownership_or_control_statement(relationship)
    end

    describe 'setting statementDate' do
      it "maps to the sample_date if it's set"
      it 'maps to nil if the sample_date is not set'
    end

    it "maps the subject to the relationship's target's id" do
      expected = {
        describedByEntityStatement: BodsMapper.new.statement_id(relationship.target),
      }
      expect(subject[:subject]).to eq expected
    end

    describe 'mapping interestedParty' do
      context 'when the relationship source is a person' do
        it "maps the interestedParty to the persons's id" do
          expected = {
            describedByPersonStatement: BodsMapper.new.statement_id(relationship.source),
          }
          expect(subject[:interestedParty]).to eq expected
        end
      end

      context 'when the relationship source is a company' do
        let(:company) { create(:legal_entity) }

        before do
          relationship.source = company
        end

        it "maps the interestedParty to the company's id" do
          expected = {
            describedByEntityStatement: BodsMapper.new.statement_id(relationship.source),
          }
          expect(subject[:interestedParty]).to eq expected
        end
      end

      context 'when the relationship source is an unknown person from a PSC Statement' do
        def maps_to_an_unspecified_ocs(statement_type, expected_reason)
          psc_statement = create(:statement, type: statement_type)
          relationship = CreateRelationshipsForStatements.call(psc_statement.entity).first
          unknown_person = relationship.source
          expected = {
            unspecified: {
              reason: expected_reason,
              description: unknown_person.name,
            },
          }
          statement = BodsMapper.new.ownership_or_control_statement(relationship)
          expect(statement[:interestedParty]).to eq expected
        end

        def maps_to_an_unknown_person(statement_type)
          psc_statement = create(:statement, type: statement_type)
          relationship = CreateRelationshipsForStatements.call(psc_statement.entity).first
          unknown_person = relationship.source
          expected = {
            describedByPersonStatement: BodsMapper.new.statement_id(unknown_person),
          }
          statement = BodsMapper.new.ownership_or_control_statement(relationship)
          expect(statement[:interestedParty]).to eq expected
        end

        it { maps_to_an_unknown_person('psc-contacted-but-no-response') }
        it { maps_to_an_unknown_person('psc-contacted-but-no-response-partnership') }
        it { maps_to_an_unknown_person('restrictions-notice-issued-to-psc') }
        it { maps_to_an_unknown_person('restrictions-notice-issued-to-psc-partnership') }
        it { maps_to_an_unknown_person('psc-exists-but-not-identified') }
        it { maps_to_an_unknown_person('psc-exists-but-not-identified-partnership') }
        it { maps_to_an_unknown_person('psc-details-not-confirmed') }
        it { maps_to_an_unknown_person('psc-details-not-confirmed-partnership') }
        it { maps_to_an_unknown_person('psc-has-failed-to-confirm-changed-details') }
        it { maps_to_an_unknown_person('psc-has-failed-to-confirm-changed-details-partnership') }
        it { maps_to_an_unknown_person('super-secure-person-with-significant-control') }

        it { maps_to_an_unspecified_ocs('no-individual-or-entity-with-signficant-control', 'no-beneficial-owners') }
        it { maps_to_an_unspecified_ocs('no-individual-or-entity-with-signficant-control-partnership', 'no-beneficial-owners') }
        it { maps_to_an_unspecified_ocs('disclosure-transparency-rules-chapter-five-applies', 'subject-exempt-from-disclosure') }
        it { maps_to_an_unspecified_ocs('psc-exempt-as-trading-on-regulated-market', 'subject-exempt-from-disclosure') }
        it { maps_to_an_unspecified_ocs('psc-exempt-as-shares-admitted-on-market', 'subject-exempt-from-disclosure') }
        it { maps_to_an_unspecified_ocs('steps-to-find-psc-not-yet-completed', 'unknown') }
        it { maps_to_an_unspecified_ocs('steps-to-find-psc-not-yet-completed-partnership', 'unknown') }
      end

      context 'when the relationship source is totally unknown' do
        let(:entity) { create(:legal_entity) }
        let(:relationship) do
          CreateRelationshipsForStatements.call(entity).first
        end

        it "maps the interestedParty to an unspecified relationship" do
          expected = {
            unspecified: {
              description: 'Unknown person(s)',
              reason: 'unknown',
            },
          }
          expect(subject[:interestedParty]).to eq expected
        end
      end
    end

    describe 'setting the source' do
      context 'when the relationship has no RawDataProvenances' do
        context 'and it has no Provenance' do
          before do
            relationship.provenance = nil
          end

          it 'maps to nil' do
            expect(subject[:source]).to be_nil
          end
        end

        context 'but it has a Provenance' do
          before do
            relationship.provenance.source_name = 'UK PSC Register'
            relationship.provenance.retrieved_at = Time.find_zone('UTC').local(2019, 1, 1, 0, 0, 0)
          end

          it "maps type via the source_name in the provenance to one of our hardcoded types" do
            expect(subject[:source][:type]).to match_array(['officialRegister'])
          end

          it "maps description to the source_name" do
            expect(subject[:source][:description]).to eq('UK PSC Register')
          end

          it "maps url to the url" do
            expect(subject[:source][:url]).to eq('http://www.example.com')
          end

          it "maps retrieved_at to the url in ISO8601 format" do
            expect(subject[:source][:retrievedAt]).to eq('2019-01-01T00:00:00Z')
          end
        end
      end

      context 'when the relationship has RawDataProvenances' do
        let(:data_source) do
          create(:data_source, name: 'Example', document_id: 'Example')
        end

        let(:import) do
          create(
            :import,
            data_source: data_source,
            created_at: Time.find_zone('UTC').local(2019, 1, 1, 0, 0, 0),
          )
        end

        before do
          create(
            :raw_data_provenance,
            entity_or_relationship: relationship,
            import: import,
          )
        end

        it "maps type to the data source's types array" do
          expect(subject[:source][:type]).to match_array(['officialRegister'])
        end

        it "maps description to the data source's name" do
          expect(subject[:source][:description]).to eq 'Example'
        end

        it "maps url to the data source's url" do
          expect(subject[:source][:url]).to eq 'http://www.example.com'
        end

        it "maps retrieved_at to the most recent import's created_at (in ISO8601)" do
          expect(subject[:source][:retrievedAt]).to eq '2019-01-01T00:00:00Z'
        end

        context 'when the relationship is from multiple DataSources' do
          before do
            data_source2 = create(:data_source)
            import2 = create(:import, data_source: data_source2)
            create(:raw_data_provenance, entity_or_relationship: relationship, import: import2)
          end

          it 'raises an error' do
            expected_error = "[BodsMapper] Relationship: #{relationship.id} comes from multiple data sources, can't produce a single Source for it"
            expect { subject }.to raise_error expected_error
          end
        end
      end
    end

    describe 'mapping interests' do
      context 'when the interests are empty' do
        before do
          relationship.interests = []
        end

        it 'maps to an empty array' do
          expect(subject[:interests]).to eq []
        end
      end

      context 'when the interests are a Hash' do
        before do
          relationship.interests = [{
            'type' => 'shareholding',
            'share_min' => 10,
            'share_max' => 20,
          }]
        end

        it 'maps the type from the interest' do
          expect(subject[:interests].first[:type]).to eq('shareholding')
        end

        it "maps values to 'exact' if min == max" do
          relationship.interests.first['share_min'] = 20
          expect(subject[:interests].first[:share][:exact]).to eq(20)
          expect(subject[:interests].first[:share][:minimum]).to eq(20)
          expect(subject[:interests].first[:share][:maximum]).to eq(20)
        end

        it "maps values to min/max separately and sets exclusivity if min != max" do
          expect(subject[:interests].first[:share][:exact]).to be_nil
          expect(subject[:interests].first[:share][:minimum]).to eq(10)
          expect(subject[:interests].first[:share][:maximum]).to eq(20)
          expect(subject[:interests].first[:share][:exclusiveMinimum]).to eq(false)
          expect(subject[:interests].first[:share][:exclusiveMaximum]).to eq(false)
        end
      end

      context 'when the interests are a PSC share percentage string' do
        before do
          relationship.interests = ['ownership-of-shares-75-to-100-percent']
        end

        it 'sets the type' do
          expect(subject[:interests].first[:type]).to eq('shareholding')
        end

        it 'copies the source string into details' do
          expect(subject[:interests].first[:details]).to eq('ownership-of-shares-75-to-100-percent')
        end

        it 'sets the min/max' do
          expect(subject[:interests].first[:share][:minimum]).to eq(75)
          expect(subject[:interests].first[:share][:maximum]).to eq(100)
        end

        it 'sets exclusiveMin/Max' do
          expect(subject[:interests].first[:share][:exclusiveMinimum]).to eq(false)
          expect(subject[:interests].first[:share][:exclusiveMaximum]).to eq(false)
        end
      end

      context 'when the interests are a PSC voting rights string' do
        before do
          relationship.interests = ['voting-rights-50-to-75-percent-as-trust-limited-liability-partnership']
        end

        it 'sets the type' do
          expect(subject[:interests].first[:type]).to eq('voting-rights')
        end

        it 'copies the source string into details' do
          expect(subject[:interests].first[:details]).to eq('voting-rights-50-to-75-percent-as-trust-limited-liability-partnership')
        end

        it 'sets the min/max' do
          expect(subject[:interests].first[:share][:minimum]).to eq(50)
          expect(subject[:interests].first[:share][:maximum]).to eq(75)
        end

        it 'sets exclusiveMin/Max' do
          expect(subject[:interests].first[:share][:exclusiveMinimum]).to eq(true)
          expect(subject[:interests].first[:share][:exclusiveMaximum]).to eq(true)
        end
      end

      context 'when the interests are another kind of control string' do
        before do
          relationship.interests = ['right-to-share-surplus-assets-50-to-75-percent-as-firm-limited-liability-partnership']
        end

        it 'sets the type' do
          expect(subject[:interests].first[:type]).to eq('rights-to-surplus-assets')
        end

        it 'copies the source string into details' do
          expect(subject[:interests].first[:details]).to eq('right-to-share-surplus-assets-50-to-75-percent-as-firm-limited-liability-partnership')
        end
      end
    end

    it 'maps annotations to nil' do
      expect(subject[:annotations]).to be_nil
    end

    it 'maps replacesStatements to nil' do
      expect(subject[:replacesStatements]).to be_nil
    end
  end
end
