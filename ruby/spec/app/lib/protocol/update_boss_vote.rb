require 'rails_helper'

RSpec.describe 'Protocol#update_boss_vote' do
  let(:target_group_uuid)    { SecureRandom.uuid.to_s }
  let(:target_instance_uuid) { '33521a44-c825-4e9f-bf55-a1bcde2db82c'}

  let(:non_boss_uuid_1) { SecureRandom.uuid.to_s }
  let(:non_boss_uuid_2) { SecureRandom.uuid.to_s }
  let(:non_boss_uuid_3) { SecureRandom.uuid.to_s }

  let!(:live_records) {[
    create(:protocol_record,
      group_uuid: target_group_uuid, instance_modulo: 5, boss_uuid: non_boss_uuid_1, instance_uuid: '55521a44-c825-4e9f-bf55-a1bcde2db82c',
    ),
    create(:protocol_record,
      group_uuid: target_group_uuid, instance_modulo: 3, boss_uuid: non_boss_uuid_2, instance_uuid: '11521a44-c825-4e9f-bf55-a1bcde2db82c',
    ),
    create(:protocol_record,
      group_uuid: target_group_uuid, instance_modulo: 1, boss_uuid: non_boss_uuid_2, instance_uuid: target_instance_uuid, instance_count: 3,
    ),
    create(:protocol_record,
      group_uuid: target_group_uuid, instance_modulo: 4, boss_uuid: non_boss_uuid_3, instance_uuid: '44521a44-c825-4e9f-bf55-a1bcde2db82c',
    ),
  ]}

  let(:target_instance_record) { live_records.at(2) }

  let!(:updated_after_time) { sleep 0.01; Time.now.utc }

  let!(:action) {
    Protocol.update_boss_vote(
      instance_record: target_instance_record,
      live_records: live_records
    )
  }

  let!(:updated_records) { ProtocolRecord.where('updated_at > ?', updated_after_time) }

  it 'updates the instance record boss_uuid to the lowest instance_uuid' do
    expect(updated_records.count).to eq(1)
    expect(updated_records.first.id).to eq(target_instance_record.id)
    expect(updated_records.first.boss_uuid).to eq('11521a44-c825-4e9f-bf55-a1bcde2db82c')
  end

  it 'updates the instance record instance_count to the number of live records' do
    expect(updated_records.count).to eq(1)
    expect(updated_records.first.id).to eq(target_instance_record.id)
    expect(updated_records.first.instance_count).to eq(4)
  end
end
