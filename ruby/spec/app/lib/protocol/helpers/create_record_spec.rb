require 'rails_helper'

RSpec.describe 'Protocol::Helpers.create_record' do
  let(:target_group_uuid)          { SecureRandom.uuid.to_s }
  let(:target_instance_uuid)       { SecureRandom.uuid.to_s }
  let(:target_instance_desc)       { 'the target instance description' }

  let(:action) {
    Protocol::Helpers.create_record(
      group_uuid:    target_group_uuid,
      instance_uuid: target_instance_uuid,
      instance_desc: target_instance_desc,
    )
  }

  context 'creates a new ProtocolRecord record' do
    it 'should pass' do
      expect{action}.to change{ProtocolRecord.count}.by 1
    end

    context 'with an instance_count of 1' do
      it 'should pass' do
        expect(action.instance_count).to eq(1)
      end
    end

    context 'with a negative instance_modulo' do
      it 'should pass' do
        expect(action.instance_modulo).to be < 0
      end
    end

    context 'with the given group_uuid' do
      it 'should pass' do
        expect(action.group_uuid).to eq(target_group_uuid)
      end
    end

    context 'with the given instance_uuid' do
      it 'should pass' do
        expect(action.instance_uuid).to eq(target_instance_uuid)
      end
    end

    context 'with the given instance_desc' do
      it 'should pass' do
        expect(action.instance_desc).to eq(target_instance_desc)
      end
    end

    context 'whose boss_uuid is the given instance_uuid' do
      it 'should pass' do
        expect(action.boss_uuid).to eq(target_instance_uuid)
      end
    end
  end
end
