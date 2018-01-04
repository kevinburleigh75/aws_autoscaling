require 'rails_helper'

RSpec.describe 'Protocol#categorize_records' do
  let(:target_group_uuid)          { SecureRandom.uuid.to_s }
  let(:target_instance_uuid)       { SecureRandom.uuid.to_s }

  let(:dead_record_timeout)        { 10.seconds }
  let(:live_record_updated_at)     { Time.now - dead_record_timeout + 0.1.seconds }
  let(:dead_record_updated_at)     { Time.now - dead_record_timeout - 0.1.seconds }

  let(:action) {
    Protocol::categorize_records(
      instance_uuid:       target_instance_uuid,
      dead_record_timeout: dead_record_timeout,
      group_records:       group_records,
    )
  }

  context 'when no group records are given' do
    let!(:group_records) { [] }

    context 'instance_record is nil' do
      it 'should pass' do
        instance_record, live_records, dead_records = action
        expect(instance_record).to be_nil
      end
    end

    context 'live_records is empty' do
      it 'should pass' do
        instance_record, live_records, dead_records = action
        expect(live_records).to be_empty
      end
    end

    context 'dead_records is empty' do
      it 'should pass' do
        instance_record, dead_records, dead_records = action
        expect(dead_records).to be_empty
      end
    end

  end

  context 'when group records are given' do
    context 'example 1: all categories present, instance record is live' do
      let!(:group_records) {[
        create(:protocol_record,
          group_uuid: target_group_uuid, instance_modulo: 5, updated_at: dead_record_updated_at,
        ),
        create(:protocol_record,
          group_uuid: target_group_uuid, instance_modulo: 3, updated_at: live_record_updated_at,
        ),
        create(:protocol_record,
          group_uuid: target_group_uuid, instance_modulo: 4, updated_at: dead_record_updated_at,
        ),
        create(:protocol_record,
          group_uuid: target_group_uuid, instance_modulo: 1, updated_at: live_record_updated_at, instance_uuid: target_instance_uuid,
        ),
        create(:protocol_record,
          group_uuid: target_group_uuid, instance_modulo: 2, updated_at: dead_record_updated_at,
        ),
      ]}

      let(:target_instance_record) { group_records.at(3) }
      let(:target_live_records)    { group_records.values_at(1,3) }
      let(:target_dead_records)    { group_records.values_at(0,2,4) }

      context 'instance_record is set to the instance record' do
        it 'should pass' do
          instance_record, live_records, dead_records = action
          expect(instance_record).to equal(target_instance_record)
        end
      end

      context 'live_records contains only the live records (including instance_record)' do
        it 'should pass' do
          instance_record, live_records, dead_records = action
          expect(live_records).to match_array(target_live_records)
        end
      end

      context 'dead_records contains only the dead records' do
        it 'should pass' do
          instance_record, dead_records, dead_records = action
          expect(dead_records).to match_array(target_dead_records)
        end
      end
    end
  end

end
