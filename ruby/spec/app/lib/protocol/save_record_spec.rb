require 'rails_helper'

RSpec.describe 'Protocol#save_record' do
  let!(:target_record) { create(:protocol_record, instance_modulo: 1) }
  let!(:updated_after_time) { sleep 0.1; Time.now.utc }

  context 'when the record has been updated' do
    let!(:action) {
      target_record.instance_modulo = 4
      Protocol.save_record(record: target_record)
    }

    context 'the record is saved and updated_at is changed' do
      let!(:new_records) { ProtocolRecord.where('updated_at > ?', updated_after_time) }

      it 'should pass' do
        expect(new_records.size).to eq(1)
        expect(new_records.first.id).to eq(target_record.id)
        expect(new_records.first.instance_modulo).to eq(4)
      end
    end
  end

  context 'when the record has not been updated' do
    let!(:action) {
      Protocol.save_record(record: target_record)
    }

    context 'updated_at is updated anyways' do
      let!(:new_records) { ProtocolRecord.where('updated_at > ?', updated_after_time) }

      it 'should pass' do
        expect(new_records.size).to eq(1)
        expect(new_records.first.id).to eq(target_record.id)
      end
    end
  end
end
