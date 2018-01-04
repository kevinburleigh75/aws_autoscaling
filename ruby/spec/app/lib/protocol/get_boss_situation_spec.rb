require 'rails_helper'

RSpec.describe 'Protocol#get_boss_situation' do
  let(:target_group_uuid)          { SecureRandom.uuid.to_s }
  let(:target_instance_uuid)       { SecureRandom.uuid.to_s }

  let(:action) {
    Protocol.get_boss_situation(
      instance_uuid: target_instance_uuid,
      live_records:  live_records
    )
  }
  context 'when no live records are given' do
    let!(:live_records) { [] }

    context 'am_boss is falsy' do
      it 'should pass' do
        am_boss, boss_record = action
        expect(am_boss).to be_falsy
      end
    end
    context 'boss_record is nil' do
      it 'should pass' do
        am_boss, boss_record = action
        expect(boss_record).to be_nil
      end
    end
  end

  context 'when live records are given' do
      let(:non_boss_uuid_1) { SecureRandom.uuid.to_s }
      let(:non_boss_uuid_2) { SecureRandom.uuid.to_s }
      let(:non_boss_uuid_3) { SecureRandom.uuid.to_s }

    context 'and there is no boss' do
      let!(:live_records) {[
        create(:protocol_record,
          group_uuid: target_group_uuid, instance_modulo: 5, boss_uuid: non_boss_uuid_1,
        ),
        create(:protocol_record,
          group_uuid: target_group_uuid, instance_modulo: 3, boss_uuid: non_boss_uuid_2,
        ),
        create(:protocol_record,
          group_uuid: target_group_uuid, instance_modulo: 1, boss_uuid: non_boss_uuid_2, instance_uuid: target_instance_uuid,
        ),
        create(:protocol_record,
          group_uuid: target_group_uuid, instance_modulo: 4, boss_uuid: non_boss_uuid_3,
        ),
      ]}

      context 'am_boss is falsy' do
        it 'should pass' do
          am_boss, boss_record = action
          expect(am_boss).to be_falsy
        end
      end
      context 'boss_record is nil' do
        it 'should pass' do
          am_boss, boss_record = action
          expect(boss_record).to be_nil
        end
      end
    end

    context 'and there is a live boss' do
      context 'and the target instance is the boss' do
        let(:boss_uuid) { target_instance_uuid }

        let!(:live_records) {[
          create(:protocol_record,
            group_uuid: target_group_uuid, instance_modulo: 5, boss_uuid: non_boss_uuid_1,
          ),
          create(:protocol_record,
            group_uuid: target_group_uuid, instance_modulo: 7, boss_uuid: non_boss_uuid_2,
          ),
          create(:protocol_record,
            group_uuid: target_group_uuid, instance_modulo: 3, boss_uuid: boss_uuid,
          ),
          create(:protocol_record,
            group_uuid: target_group_uuid, instance_modulo: 1, boss_uuid: boss_uuid, instance_uuid: target_instance_uuid,
          ),
          create(:protocol_record,
            group_uuid: target_group_uuid, instance_modulo: 4, boss_uuid: non_boss_uuid_2,
          ),
          create(:protocol_record,
            group_uuid: target_group_uuid, instance_modulo: 0, boss_uuid: boss_uuid,
          ),
          create(:protocol_record,
            group_uuid: target_group_uuid, instance_modulo: 6, boss_uuid: boss_uuid,
          ),
        ]}

        let(:target_instance_record) { live_records.at(3) }

        context 'am_boss is truthy' do
          it 'should pass' do
            am_boss, boss_record = action
            expect(am_boss).to be_truthy
          end
        end
        context 'boss_record is the target instance record' do
          it 'should pass' do
            am_boss, boss_record = action
            expect(boss_record).to equal(target_instance_record)
          end
        end

      end

      context 'and the target instance is not the boss' do
        let(:boss_uuid) { SecureRandom.uuid.to_s }

        let!(:live_records) {[
          create(:protocol_record,
            group_uuid: target_group_uuid, instance_modulo: 5, boss_uuid: non_boss_uuid_1,
          ),
          create(:protocol_record,
            group_uuid: target_group_uuid, instance_modulo: 7, boss_uuid: non_boss_uuid_2,
          ),
          create(:protocol_record,
            group_uuid: target_group_uuid, instance_modulo: 3, boss_uuid: boss_uuid, instance_uuid: boss_uuid,
          ),
          create(:protocol_record,
            group_uuid: target_group_uuid, instance_modulo: 1, boss_uuid: boss_uuid, instance_uuid: target_instance_uuid,
          ),
          create(:protocol_record,
            group_uuid: target_group_uuid, instance_modulo: 4, boss_uuid: non_boss_uuid_2,
          ),
          create(:protocol_record,
            group_uuid: target_group_uuid, instance_modulo: 0, boss_uuid: boss_uuid,
          ),
          create(:protocol_record,
            group_uuid: target_group_uuid, instance_modulo: 6, boss_uuid: boss_uuid,
          ),
        ]}

        let(:target_boss_record) { live_records.at(2) }

        context 'am_boss is falsy' do
          it 'should pass' do
            am_boss, boss_record = action
            expect(am_boss).to be_falsy
          end
        end
        context 'boss_record is the boss instance record' do
          it 'should pass' do
            am_boss, boss_record = action
            expect(boss_record).to equal(target_boss_record)
          end
        end
      end
    end

    context 'and there is a dead boss' do
      let(:boss_uuid) { SecureRandom.uuid.to_s }

      let!(:live_records) {[
        create(:protocol_record,
          group_uuid: target_group_uuid, instance_modulo: 5, boss_uuid: non_boss_uuid_1,
        ),
        create(:protocol_record,
          group_uuid: target_group_uuid, instance_modulo: 7, boss_uuid: non_boss_uuid_2,
        ),
        create(:protocol_record,
          group_uuid: target_group_uuid, instance_modulo: 3, boss_uuid: boss_uuid,
        ),
        create(:protocol_record,
          group_uuid: target_group_uuid, instance_modulo: 1, boss_uuid: boss_uuid, instance_uuid: target_instance_uuid,
        ),
        create(:protocol_record,
          group_uuid: target_group_uuid, instance_modulo: 4, boss_uuid: non_boss_uuid_2,
        ),
        create(:protocol_record,
          group_uuid: target_group_uuid, instance_modulo: 0, boss_uuid: boss_uuid,
        ),
        create(:protocol_record,
          group_uuid: target_group_uuid, instance_modulo: 6, boss_uuid: boss_uuid,
        ),
      ]}

      context 'am_boss is falsy' do
        it 'should pass' do
          am_boss, boss_record = action
          expect(am_boss).to be_falsy
        end
      end
      context 'boss_record is nil' do
        it 'should pass' do
          am_boss, boss_record = action
          expect(boss_record).to be_nil
        end
      end
    end

  end
end
