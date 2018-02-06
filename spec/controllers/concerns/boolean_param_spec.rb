require 'rails_helper'

RSpec.describe 'BooleanParam concern' do
  let(:klass) do
    Class.new(ApplicationController) do
      include BooleanParam

      def params
        {}
      end
    end
  end

  subject { klass.new }

  let(:name) { :foo }

  def build_params(params)
    ActionController::Parameters.new(params)
  end

  before do
    allow(subject).to receive(:params).and_return(params)
  end

  context 'when the param is not provided' do
    let :params do
      build_params('another_param' => 'true')
    end

    it 'should return the default (false)' do
      expect(subject.boolean_param(name)).to be false
    end
  end

  context 'when the param is provided' do
    context 'with nil value' do
      let :params do
        build_params(name => nil)
      end

      it 'should return true' do
        expect(subject.boolean_param(name)).to be true
      end
    end

    context 'with empty string' do
      let :params do
        build_params(name => '')
      end

      it 'should return true' do
        expect(subject.boolean_param(name)).to be true
      end
    end

    context 'with "true" value' do
      let :params do
        build_params(name => "true")
      end

      it 'should return true' do
        expect(subject.boolean_param(name)).to be true
      end
    end

    context 'with "1" value' do
      let :params do
        build_params(name => "1")
      end

      it 'should return true' do
        expect(subject.boolean_param(name)).to be true
      end
    end

    context 'with "false" value' do
      let :params do
        build_params(name => "false")
      end

      it 'should return false' do
        expect(subject.boolean_param(name)).to be false
      end
    end

    context 'with "0" value' do
      let :params do
        build_params(name => "0")
      end

      it 'should return false' do
        expect(subject.boolean_param(name)).to be false
      end
    end
  end
end
