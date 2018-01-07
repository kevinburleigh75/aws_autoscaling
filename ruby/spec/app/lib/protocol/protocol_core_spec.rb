require 'rails_helper'

def check_method_calls(called:, uncalled:)
  called.each do |method_name|
    it "calls #{method_name}" do
      action
      expect(given_world).to have_received(method_name).once
    end
  end

  uncalled.each do |method_name|
    it "does not call #{method_name}" do
      action
      expect(given_world).to_not have_received(method_name)
    end
  end
end

RSpec.describe 'Protocol::Core#process' do
  let(:given_process_time) { Chronic.parse('Oct 6, 2014 14:56:31.5256') }

  let(:core) {
    Protocol::Core.new(
      world: given_world
    )
  }

  let(:given_world) {
    dbl = double
    allow(dbl).to receive(:read_group_records)
    allow(dbl).to receive(:categorize_records)
    allow(dbl).to receive(:create_instance_record)
    allow(dbl).to receive(:has_instance_record?)
              .and_return(has_instance_record_return_value)
    allow(dbl).to receive(:has_boss_record?)
              .and_return(has_boss_record_return_value)
    allow(dbl).to receive(:update_boss_vote)
    allow(dbl).to receive(:am_boss?)
              .and_return(am_boss_return_value)
    allow(dbl).to receive(:has_next_boss_time?)
              .and_return(has_next_boss_time_return_value)
    allow(dbl).to receive(:clear_next_boss_time)
    allow(dbl).to receive(:destroy_dead_records)
    allow(dbl).to receive(:allocate_modulo)
              .and_return(allocate_modulo_return_value)
    allow(dbl).to receive(:end_block_should_be_called?)
              .and_return(end_block_should_be_called_return_value)
    allow(dbl).to receive(:call_end_block).and_return(end_block_return_value)
    allow(dbl).to receive(:compute_and_set_next_end_time)
    allow(dbl).to receive(:boss_block_should_be_called?)
              .and_return(boss_block_should_be_called_return_value)
    allow(dbl).to receive(:call_boss_block)
    allow(dbl).to receive(:compute_and_set_next_boss_time)
    allow(dbl).to receive(:work_block_should_be_called?)
              .and_return(work_block_should_be_called_return_value)
    allow(dbl).to receive(:call_work_block)
    allow(dbl).to receive(:compute_and_set_next_work_time)
    allow(dbl).to receive(:sleep_until_next_time)
    allow(dbl).to receive(:save_record)
    dbl
  }

  let(:has_instance_record_return_value)         { false }
  let(:has_boss_record_return_value)             { false }
  let(:has_next_boss_time_return_value)          { false }
  let(:am_boss_return_value)                     { false }
  let(:has_next_boss_time_return_value)          { false }
  let(:allocate_modulo_return_value)             { false }
  let(:end_block_should_be_called_return_value)  { false }
  let(:end_block_return_value)                   { false }
  let(:boss_block_should_be_called_return_value) { false }
  let(:work_block_should_be_called_return_value) { false }

  all_methods = [
    :read_group_records,
    :categorize_records,
    :has_instance_record?,
    :create_instance_record,
    :has_boss_record?,
    :update_boss_vote,
    :am_boss?,
    :has_next_boss_time?,
    :compute_and_set_next_boss_time,
    :clear_next_boss_time,
    :destroy_dead_records,
    :allocate_modulo,
    :end_block_should_be_called?,
    :call_end_block,
    :compute_and_set_next_end_time,
    :boss_block_should_be_called?,
    :call_boss_block,
    :compute_and_set_next_boss_time,
    :work_block_should_be_called?,
    :call_work_block,
    :compute_and_set_next_work_time,
    :sleep_until_next_time,
    :save_record,
  ]

  let(:action) { core.process(process_time: given_process_time) }

  called_methods = [
    :read_group_records,
    :categorize_records,
    :has_instance_record?,
  ]
  uncalled_methods = []

  check_method_calls(called: called_methods, uncalled: uncalled_methods)

  context 'when the target instance record does not exist' do
    let(:has_instance_record_return_value) { false }

    called_methods    = [:create_instance_record]
    unchecked_methods = [
      :read_group_records,
      :categorize_records,
      :has_instance_record?,
    ]
    uncalled_methods  = all_methods - called_methods - unchecked_methods

    check_method_calls(called: called_methods, uncalled: uncalled_methods)
  end

  context 'when the target instance record does exist' do
    let(:has_instance_record_return_value) { true }

    called_methods   = [:has_boss_record?]
    uncalled_methods = []

    check_method_calls(called: called_methods, uncalled: uncalled_methods)

    context 'when there is no boss record' do
      let(:has_boss_record_return_value) { false }

      called_methods = [
        :update_boss_vote,
      ]
      unchecked_methods = [
        :read_group_records,
        :categorize_records,
        :has_instance_record?,
        :has_boss_record?,
        :save_record,
      ]
      uncalled_methods  = all_methods - called_methods - unchecked_methods

      check_method_calls(called: called_methods, uncalled: uncalled_methods)
    end

    context 'when there is a boss record' do
      let(:has_boss_record_return_value) { true }

      called_methods    = [:allocate_modulo]
      uncalled_methods  = []

      check_method_calls(called: called_methods, uncalled: uncalled_methods)

      context 'when the instance modulo needs to be allocated' do
        let(:allocate_modulo_return_value) { true }

        called_methods = []
        unchecked_methods = [
          :read_group_records,
          :categorize_records,
          :has_instance_record?,
          :has_boss_record?,
          :allocate_modulo,
        ]
        uncalled_methods  = all_methods - called_methods - unchecked_methods

        check_method_calls(called: called_methods, uncalled: uncalled_methods)
      end

      context 'when the instance modulo does not need to be allocated' do
        let(:allocate_modulo_return_value) { false }

        called_methods    = [:am_boss?]
        uncalled_methods  = []

        check_method_calls(called: called_methods, uncalled: uncalled_methods)

        context 'when this instance is the boss' do
          let(:am_boss_return_value) { true }

          called_methods    = [
            :has_next_boss_time?,
            :destroy_dead_records,
            :boss_block_should_be_called?,
          ]
          uncalled_methods  = [:clear_next_boss_time]

          check_method_calls(called: called_methods, uncalled: uncalled_methods)

          context 'when this instance has no next_boss_time' do
            let(:has_next_boss_time_return_value) { false }

            called_methods    = [:compute_and_set_next_boss_time]
            uncalled_methods  = []

            check_method_calls(called: called_methods, uncalled: uncalled_methods)
          end

          context 'when this instance has a next_boss_time' do
            let(:has_next_boss_time_return_value) { true }

            called_methods   = []
            uncalled_methods = [:compute_and_set_next_boss_time]

            check_method_calls(called: called_methods, uncalled: uncalled_methods)
          end

          context 'when the boss block should be called' do
            let(:has_next_boss_time_return_value)          { true }
            let(:boss_block_should_be_called_return_value) { true }

            called_methods   = [:call_boss_block, :compute_and_set_next_boss_time]
            uncalled_methods = []

            check_method_calls(called: called_methods, uncalled: uncalled_methods)
          end

          context 'when the boss block should not be called' do
            let(:has_next_boss_time_return_value)          { true }
            let(:boss_block_should_be_called_return_value) { false }

            called_methods   = []
            uncalled_methods = [:call_boss_block, :compute_and_set_next_boss_time]

            check_method_calls(called: called_methods, uncalled: uncalled_methods)
          end
        end

        context 'when this instance is not the boss' do
          let(:am_boss_return_value) { false }

          called_methods    = [:clear_next_boss_time]
          uncalled_methods  = [
            :destroy_dead_records,
            :compute_and_set_next_boss_time,
            :boss_block_should_be_called?,
          ]

          check_method_calls(called: called_methods, uncalled: uncalled_methods)
        end

        context 'when the end block should be called' do
          let(:end_block_should_be_called_return_value) { true }

          called_methods    = [:call_end_block]
          uncalled_methods  = []

          check_method_calls(called: called_methods, uncalled: uncalled_methods)

          context 'when the end block returns truthy' do
            let(:end_block_return_value) { true }

            called_methods   = []
            uncalled_methods = [
              :compute_and_set_next_end_time,
              :sleep_until_next_time,
              :save_record,
            ]

            check_method_calls(called: called_methods, uncalled: uncalled_methods)
          end

          context 'when the end block returns falsy' do
            let(:end_block_return_value) { false }

            called_methods = [
              :compute_and_set_next_end_time,
              :sleep_until_next_time,
              :save_record,
            ]
            uncalled_methods = []

            check_method_calls(called: called_methods, uncalled: uncalled_methods)
          end

        end

        context 'when the end block should not be called' do
          let(:end_block_should_be_called_return_value) { false }

          called_methods   = []
          uncalled_methods = [:call_end_block, :compute_and_set_next_end_time]

          check_method_calls(called: called_methods, uncalled: uncalled_methods)
        end

        context 'when the work block should be called' do
          let(:work_block_should_be_called_return_value) { true }

          called_methods    = [:call_work_block, :compute_and_set_next_work_time]
          uncalled_methods  = []

          check_method_calls(called: called_methods, uncalled: uncalled_methods)
        end

        context 'when the work block should not be called' do
          let(:work_block_should_be_called_return_value) { false }

          called_methods   = []
          uncalled_methods = [:call_work_block, :compute_and_set_next_work_time]

          check_method_calls(called: called_methods, uncalled: uncalled_methods)
        end
      end
    end
  end
end

  # context 'when there is no elected boss' do
  #   let(:given_world) {
  #     dbl = double
  #     allow(dbl).to receive(:read_group_records)
  #     allow(dbl).to receive(:categorize_records)
  #     allow(dbl).to receive(:has_instance_record?).and_return(true)
  #     allow(dbl).to receive(:has_boss_record?).and_return(false)
  #     allow(dbl).to receive(:update_boss_vote)
  #     allow(dbl).to receive(:save_record)
  #     dbl
  #   }

  #   it 'calls .read_group_records' do
  #     action
  #     expect(given_world).to have_received(:read_group_records).once
  #   end

  #   it 'calls .categorize_records' do
  #     action
  #     expect(given_world).to have_received(:categorize_records).once
  #   end

  #   it 'calls .has_instance_record?' do
  #     action
  #     expect(given_world).to have_received(:has_instance_record?).once
  #   end

  #   it 'does not call .create_instance_record' do
  #     action
  #     ## This is handled by the use of a strict double
  #     # expect(given_world).to_not have_received(:create_instance_record)
  #   end

  #   it 'calls .has_boss_record?' do
  #     action
  #     expect(given_world).to have_received(:has_boss_record?).once
  #   end

  #   it 'calls .update_boss_vote' do
  #     action
  #     expect(given_world).to have_received(:update_boss_vote).once
  #   end

  #   it 'calls .save_record' do
  #     action
  #     expect(given_world).to have_received(:save_record).once
  #   end

  #   it 'does not call the end block' do
  #     action
  #     ## This is handled by the use of a strict double
  #     # expect(given_world).to_not have_received(:end_block_should_be_called?)
  #     # expect(given_world).to_not have_received(:call_end_block)
  #   end

  #   it 'does not call the boss block' do
  #     action
  #     ## This is handled by the use of a strict double
  #     # expect(given_world).to_not have_received(:boss_block_should_be_called?)
  #     # expect(given_world).to_not have_received(:call_boss_block)
  #   end

  #   it 'does not call the work block' do
  #     action
  #     ## This is handled by the use of a strict double
  #     # expect(given_world).to_not have_received(:work_block_should_be_called?)
  #     # expect(given_world).to_not have_received(:call_work_block)
  #   end

  #   it 'does not sleep' do
  #     action
  #     ## This is handled by the use of a strict double
  #     # expect(given_world).to_not have_received(:sleep_until_next_time)
  #   end
  # end

  # context 'when this instance is the elected boss' do
  #   context 'and its modulo does not need to be allocated' do
  #     let(:given_world) {
  #       dbl = double
  #       allow(dbl).to receive(:read_group_records)
  #       allow(dbl).to receive(:categorize_records)
  #       allow(dbl).to receive(:has_instance_record?).and_return(true)
  #       allow(dbl).to receive(:has_boss_record?).and_return(true)
  #       allow(dbl).to receive(:am_boss?).and_return(true)
  #       allow(dbl).to receive(:has_next_boss_time?).and_return(false)
  #       allow(dbl).to receive(:compute_and_set_next_boss_time)
  #       allow(dbl).to receive(:destroy_dead_records)
  #       allow(dbl).to receive(:allocate_modulo).and_return(false)
  #       allow(dbl).to receive(:end_block_should_be_called?).and_return(false)
  #       allow(dbl).to receive(:boss_block_should_be_called?).and_return(false)
  #       allow(dbl).to receive(:work_block_should_be_called?).and_return(false)
  #       allow(dbl).to receive(:sleep_until_next_time)
  #       allow(dbl).to receive(:save_record)
  #       dbl
  #     }

  #     it 'calls .read_group_records' do
  #       action
  #       expect(given_world).to have_received(:read_group_records).once
  #     end

  #     it 'calls .categorize_records' do
  #       action
  #       expect(given_world).to have_received(:categorize_records).once
  #     end

  #     it 'calls .has_instance_record?' do
  #       action
  #       expect(given_world).to have_received(:has_instance_record?).once
  #     end

  #     it 'does not call .create_instance_record' do
  #       action
  #       ## This is handled by the use of a strict double
  #       # expect(given_world).to_not have_received(:create_instance_record)
  #     end

  #     it 'calls .has_boss_record?' do
  #       action
  #       expect(given_world).to have_received(:has_boss_record?).once
  #     end

  #     it 'calls .am_boss?' do
  #       action
  #       expect(given_world).to have_received(:am_boss?).once
  #     end

  #     it 'does not call .update_boss_vote' do
  #       action
  #       ## This is handled by the use of a strict double
  #       # expect(given_world).to_not have_received(:update_boss_vote)
  #     end

  #     it 'calls .has_next_boss_time?' do
  #       action
  #       expect(given_world).to have_received(:has_next_boss_time?).once
  #     end

  #     it 'calls .compute_and_set_next_boss_time' do
  #       action
  #       expect(given_world).to have_received(:compute_and_set_next_boss_time).once
  #     end

  #     it 'calls .destroy_dead_records' do
  #       action
  #       expect(given_world).to have_received(:destroy_dead_records).once
  #     end

  #     it 'calls .save_record' do
  #       action
  #       expect(given_world).to have_received(:save_record).once
  #     end

  #     it 'does not call the end block' do
  #       action
  #       expect(given_world).to have_received(:end_block_should_be_called?)
  #       ## This is handled by the use of a strict double
  #       # expect(given_world).to_not have_received(:call_end_block)
  #     end

  #     it 'does not call the boss block' do
  #       action
  #       expect(given_world).to have_received(:boss_block_should_be_called?)
  #       ## This is handled by the use of a strict double
  #       # expect(given_world).to_not have_received(:call_boss_block)
  #     end

  #     it 'does not call the work block' do
  #       action
  #       expect(given_world).to have_received(:work_block_should_be_called?)
  #       ## This is handled by the use of a strict double
  #       # expect(given_world).to_not have_received(:call_work_block)
  #     end

  #     it 'sleeps' do
  #       action
  #       expect(given_world).to have_received(:sleep_until_next_time).once
  #     end
  #   end

  #   context 'and its modulo needs to be allocated' do
  #     let(:given_world) {
  #       dbl = double
  #       allow(dbl).to receive(:read_group_records)
  #       allow(dbl).to receive(:categorize_records)
  #       allow(dbl).to receive(:has_instance_record?).and_return(true)
  #       allow(dbl).to receive(:has_boss_record?).and_return(true)
  #       allow(dbl).to receive(:am_boss?).and_return(false)
  #       allow(dbl).to receive(:clear_next_boss_time)
  #       allow(dbl).to receive(:allocate_modulo).and_return(true)
  #       allow(dbl).to receive(:save_record)
  #       dbl
  #     }

  #     it 'calls .read_group_records' do
  #       action
  #       expect(given_world).to have_received(:read_group_records).once
  #     end

  #     it 'calls .categorize_records' do
  #       action
  #       expect(given_world).to have_received(:categorize_records).once
  #     end

  #     it 'calls .has_instance_record?' do
  #       action
  #       expect(given_world).to have_received(:has_instance_record?).once
  #     end

  #     it 'does not call .create_instance_record' do
  #       action
  #       ## This is handled by the use of a strict double
  #       # expect(given_world).to_not have_received(:create_instance_record)
  #     end

  #     it 'calls .has_boss_record?' do
  #       action
  #       expect(given_world).to have_received(:has_boss_record?).once
  #     end

  #     it 'calls .am_boss?' do
  #       action
  #       expect(given_world).to have_received(:am_boss?).once
  #     end

  #     it 'calls .clear_next_boss_time' do
  #       action
  #       expect(given_world).to have_received(:clear_next_boss_time).once
  #     end

  #     it 'does not call .update_boss_vote' do
  #       action
  #       ## This is handled by the use of a strict double
  #       # expect(given_world).to_not have_received(:update_boss_vote)
  #     end

  #     it 'does not call .has_next_boss_time?' do
  #       action
  #       ## This is handled by the use of a strict double
  #       # expect(given_world).to have_received(:has_next_boss_time?).once
  #     end

  #     it 'does not call .compute_and_set_next_boss_time' do
  #       action
  #       ## This is handled by the use of a strict double
  #       # expect(given_world).to have_received(:compute_and_set_next_boss_time).once
  #     end

  #     it 'does not call .destroy_dead_records' do
  #       action
  #       ## This is handled by the use of a strict double
  #       # expect(given_world).to have_received(:destroy_dead_records).once
  #     end

  #     it 'calls .save_record' do
  #       action
  #       expect(given_world).to have_received(:save_record).once
  #     end

  #     it 'does not call the end block' do
  #       action
  #       # expect(given_world).to_not have_received(:end_block_should_be_called?)
  #       # expect(given_world).to_not have_received(:call_end_block)
  #     end

  #     it 'does not call the boss block' do
  #       action
  #       # expect(given_world).to_not have_received(:boss_block_should_be_called?)
  #       # expect(given_world).to_not have_received(:call_boss_block)
  #     end

  #     it 'does not call the work block' do
  #       action
  #       # expect(given_world).to_not have_received(:work_block_should_be_called?)
  #       # expect(given_world).to_not have_received(:call_work_block)
  #     end

  #     it 'does not sleep' do
  #       action
  #       # expect(given_world).to_not have_received(:sleep_until_next_time)
  #     end
  #   end

#   end
# end
