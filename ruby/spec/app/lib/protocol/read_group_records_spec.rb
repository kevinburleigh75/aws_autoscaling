require 'rails_helper'

RSpec.describe 'Protocol::Helpers.read_group_records' do
  let(:target_group_uuid) { SecureRandom.uuid.to_s }

  let(:action) {
    Protocol::Helpers.read_group_records(group_uuid: target_group_uuid)
  }

  context 'when no ProtocolRecords are present' do
    context 'an empty collection is returned' do
      it 'should pass' do
        expect(action).to be_empty
      end
    end
  end

  context 'when ProtocolRecords are present' do

    context 'when no target group records are present' do
      let!(:records) {
        [
          create(:protocol_record),
          create(:protocol_record),
          create(:protocol_record),
        ]
      }

      context 'an empty collection is returned' do
        it 'should pass' do
          expect(action).to be_empty
        end
      end
    end

    context 'when target group records are present' do
      let!(:records) {
        [
          create(:protocol_record, instance_modulo: 0),
          create(:protocol_record, instance_modulo: 1, group_uuid: target_group_uuid),
          create(:protocol_record, instance_modulo: 1),
          create(:protocol_record, instance_modulo: 0, group_uuid: target_group_uuid),
          create(:protocol_record, instance_modulo: 3),
          create(:protocol_record, instance_modulo: 2),
        ]
      }

      let(:target_group_records) { records.values_at(1, 3) }

      context 'only the target group records are returned' do
        it 'should pass' do
          expect(action.map(&:id)).to match_array(target_group_records.map(&:id))
        end
      end
    end

  end
end

#   let!(:non_target_records) {
#     [
#       create(:protocol_record),
#       create(:protocol_record, updated_at: dead_records_updated_at),
#       create(:protocol_record),
#       create(:protocol_record, updated_at: dead_records_updated_at),
#       create(:protocol_record),
#     ]
#   }

#   context 'when target group ProtocolRecords are not present' do
#     context 'instance_record is nil' do
#       it 'should pass' do
#         instance_record, group_records, dead_records = action
#         expect(instance_record).to be_nil
#       end
#     end

#     context 'group_records is empty' do
#       it 'should pass' do
#         instance_record, group_records, dead_records = action
#         expect(group_records).to be_empty
#       end
#     end

#     context 'dead_records is empty' do
#       it 'should pass' do
#         instance_record, group_records, dead_records = action
#         expect(dead_records).to be_empty
#       end
#     end
#   end

#   context 'when target group ProtocolRecords are present' do
#     context 'dead_records' do
#       context 'when dead records are present' do
#         let!(:group_records) {
#           [
#             create(:protocol_record, group_uuid: target_group_uuid, instance_modulo: 0),
#             create(:protocol_record, group_uuid: target_group_uuid, instance_modulo: 1, updated_at: dead_records_updated_at),
#             create(:protocol_record, group_uuid: target_group_uuid, instance_modulo: 2),
#             create(:protocol_record, group_uuid: target_group_uuid, instance_modulo: 3, updated_at: dead_records_updated_at, instance_uuid: target_instance_uuid),
#             create(:protocol_record, group_uuid: target_group_uuid, instance_modulo: 4, updated_at: dead_records_updated_at),
#             create(:protocol_record, group_uuid: target_group_uuid, instance_modulo: 5),
#           ]
#         }

#         let(:target_dead_record_ids) { group_records.map(&:id).values_at(1,3,4) }

#         context 'dead_records contains the dead records for the target group' do
#           it 'should pass' do
#             instance_record, group_records, dead_records = action
#             expect(dead_records.map(&:id)).to match_array(target_dead_record_ids)
#           end
#         end
#       end

#       context 'when dead records are not present' do
#         let!(:group_records) {
#           [
#             create(:protocol_record, group_uuid: target_group_uuid, instance_modulo: 0),
#             create(:protocol_record, group_uuid: target_group_uuid, instance_modulo: 1),
#             create(:protocol_record, group_uuid: target_group_uuid, instance_modulo: 2),
#             create(:protocol_record, group_uuid: target_group_uuid, instance_modulo: 3, instance_uuid: target_instance_uuid),
#             create(:protocol_record, group_uuid: target_group_uuid, instance_modulo: 4),
#             create(:protocol_record, group_uuid: target_group_uuid, instance_modulo: 5),
#           ]
#         }

#         context 'dead_records is empty' do
#           it 'should pass' do
#             instance_record, group_records, dead_records = action
#             expect(dead_records).to be_empty
#           end
#         end
#       end
#     end

#     context 'live_records' do
#       context 'when live records are present' do
#         let!(:group_records) {
#           [
#             create(:protocol_record, group_uuid: target_group_uuid, instance_modulo: 0),
#             create(:protocol_record, group_uuid: target_group_uuid, instance_modulo: 1, updated_at: dead_records_updated_at),
#             create(:protocol_record, group_uuid: target_group_uuid, instance_modulo: 2),
#             create(:protocol_record, group_uuid: target_group_uuid, instance_modulo: 3, instance_uuid: target_instance_uuid),
#             create(:protocol_record, group_uuid: target_group_uuid, instance_modulo: 4, updated_at: dead_records_updated_at),
#             create(:protocol_record, group_uuid: target_group_uuid, instance_modulo: 5),
#           ]
#         }

#         let(:target_live_record_ids) { group_records.map(&:id).values_at(0,2,3,5) }

#         context 'live_records contains the live records for the target group' do
#           it 'should pass' do
#             instance_record, live_records, dead_records = action
#             expect(live_records.map(&:id)).to match_array(target_live_record_ids)
#           end
#         end
#       end

#       context 'when live records are not present' do
#         let!(:group_records) {
#           [
#             create(:protocol_record, group_uuid: target_group_uuid, instance_modulo: 0, updated_at: dead_records_updated_at),
#             create(:protocol_record, group_uuid: target_group_uuid, instance_modulo: 1, updated_at: dead_records_updated_at),
#             create(:protocol_record, group_uuid: target_group_uuid, instance_modulo: 2, updated_at: dead_records_updated_at),
#             create(:protocol_record, group_uuid: target_group_uuid, instance_modulo: 3, updated_at: dead_records_updated_at, instance_uuid: target_instance_uuid),
#             create(:protocol_record, group_uuid: target_group_uuid, instance_modulo: 4, updated_at: dead_records_updated_at),
#             create(:protocol_record, group_uuid: target_group_uuid, instance_modulo: 5, updated_at: dead_records_updated_at),
#           ]
#         }

#         context 'live_records is empty' do
#           it 'should pass' do
#             instance_record, live_records, dead_records = action
#             expect(live_records).to be_empty
#           end
#         end
#       end
#     end

#     context 'instance_record' do
#       context 'when target instance record is present' do
#         let!(:group_records) {
#           [
#             create(:protocol_record, group_uuid: target_group_uuid, instance_modulo: 0),
#             create(:protocol_record, group_uuid: target_group_uuid, instance_modulo: 1, updated_at: dead_records_updated_at),
#             create(:protocol_record, group_uuid: target_group_uuid, instance_modulo: 2),
#             create(:protocol_record, group_uuid: target_group_uuid, instance_modulo: 3, instance_uuid: target_instance_uuid),
#             create(:protocol_record, group_uuid: target_group_uuid, instance_modulo: 4, updated_at: dead_records_updated_at),
#             create(:protocol_record, group_uuid: target_group_uuid, instance_modulo: 5),
#           ]
#         }

#         let(:target_instance_record_id) { group_records.map(&:id)[3] }

#         context 'instance_record is the target instance record' do
#           it 'should pass' do
#             instance_record, live_records, dead_records = action
#             expect(instance_record.id).to equal(target_instance_record_id)
#           end
#         end
#       end

#       context 'when target intance record is not present' do
#         let!(:group_records) {
#           [
#             create(:protocol_record, group_uuid: target_group_uuid, instance_modulo: 0),
#             create(:protocol_record, group_uuid: target_group_uuid, instance_modulo: 1, updated_at: dead_records_updated_at),
#             create(:protocol_record, group_uuid: target_group_uuid, instance_modulo: 2),
#             create(:protocol_record, group_uuid: target_group_uuid, instance_modulo: 3),
#             create(:protocol_record, group_uuid: target_group_uuid, instance_modulo: 4, updated_at: dead_records_updated_at),
#             create(:protocol_record, group_uuid: target_group_uuid, instance_modulo: 5),
#           ]
#         }

#         context 'instance_record is nil' do
#           it 'should pass' do
#             instance_record, live_records, dead_records = action
#             expect(instance_record).to be_nil
#           end
#         end
#       end
#     end

#   end
