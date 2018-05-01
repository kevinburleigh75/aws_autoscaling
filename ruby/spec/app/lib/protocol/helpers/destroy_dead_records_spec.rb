require 'rails_helper'

class TestBlock
  attr_accessor :call_count

  def initialize
    @call_count       = 0
    @call_times       = []
  end

  def call(record)
    @call_times << Time.now()
    @call_count += 1
  end
end

RSpec.describe 'Protocol::Helpers.destroy_dead_records' do
  let(:action) {
    Protocol::Helpers.destroy_dead_records(
      dead_records:        dead_records,
      dead_record_block:   dead_record_block,
    )
  }

  let(:dead_record_block) { TestBlock.new }

  let(:target_group_uuid) { SecureRandom.uuid.to_s }

  let(:records) {[
    create(:protocol_record,
      group_uuid: target_group_uuid, instance_modulo: 2,
    ),
    create(:protocol_record,
      group_uuid: target_group_uuid, instance_modulo: 0,
    ),
    create(:protocol_record,
      group_uuid: target_group_uuid, instance_modulo: 1,
    ),
    create(:protocol_record,
      group_uuid: target_group_uuid, instance_modulo: 3,
    ),
  ]}

  context 'when there are no dead records' do
    let(:dead_records) { [] }
    let(:live_records) { records }

    it 'no records should be destroyed' do
      expect{action}.to_not change{ProtocolRecord.count}
    end

    it 'the dead_record_block should not be called' do
      action
      expect(dead_record_block.call_count).to eq(0)
    end
  end

  context 'when there are dead records' do
    let(:dead_records) { records.values_at(1,3) }
    let(:live_records) { records.values_at(0,2) }

    it 'the dead records should be destroyed' do
      action
      undead_records = ProtocolRecord.where(group_uuid: target_group_uuid)
                                     .where(instance_modulo: dead_records.map(&:instance_modulo))
      expect(undead_records).to be_empty
    end

    it 'the dead_record_block should be called for each destroyed record' do
      action
      expect(dead_record_block.call_count).to eq(dead_records.count)
    end

    it 'the other records should remain untouched' do
      action
      untouched_records = ProtocolRecord.where(group_uuid: target_group_uuid)
                                        .where(instance_modulo: live_records.map(&:instance_modulo))
      expect(untouched_records.size).to be(live_records.size)
    end
  end
end
