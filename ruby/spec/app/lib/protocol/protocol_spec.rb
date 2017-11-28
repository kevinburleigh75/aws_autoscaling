require 'rails_helper'
require 'timeout'

RSpec.describe 'protocol' do
  context 'basic construction' do
    it 'should work' do
      Protocol.new(
        group_uuid: SecureRandom.uuid.to_s,
        work_modulo:         1.0.seconds,
        work_offset:         0.0.seconds,
        min_work_interval:   0.1.seconds,
        min_boss_interval:   0.3.seconds,
        min_end_interval:    0.1.seconds,
        min_update_interval: 0.05.seconds,
        work_block: lambda{|instance_count, instance_modulo, am_boss| },
        boss_block: lambda{|instance_count, instance_modulo, am_boss| },
        end_block:  lambda{ },
      )
    end
  end

  context '.run' do
    let(:group_uuid)  { SecureRandom.uuid.to_s }

    let(:work_modulo) { 1.0.seconds }
    let(:work_offset) { 0.0.seconds }

    let(:min_work_interval)   { 0.1.seconds }
    let(:min_boss_interval)   { 0.1.seconds }
    let(:min_end_interval)    { 0.1.seconds }
    let(:min_update_interval) { 0.05.seconds }

    let(:work_block) { lambda{|instance_count:, instance_modulo:, am_boss:| } }
    let(:boss_block) { lambda{|instance_count:, instance_modulo:, protocol:| } }
    let(:end_block)  { lambda{ } }

    let(:protocol) {
      Protocol.new(
        group_uuid:          group_uuid,
        work_modulo:         work_modulo,
        work_offset:         work_offset,
        min_work_interval:   min_work_interval,
        min_boss_interval:   min_boss_interval,
        min_end_interval:    min_end_interval,
        min_update_interval: min_update_interval,
        work_block:          work_block,
        boss_block:          boss_block,
        end_block:           end_block,
      )
    }

    context 'calling of end_block' do
      class EndBlock
        attr_accessor :call_count
        attr_accessor :target_num_calls
        attr_accessor :call_times

        def initialize
          @call_count       = 0
          @target_num_calls = 0
          @call_times       = []
        end

        def call
          self.call_times << Time.now()
          self.call_count += 1

          self.call_count == self.target_num_calls
        end
      end

      let(:end_block) {
        dbl = EndBlock.new
        allow(dbl).to receive(:call).and_call_original
        dbl
      }

      let(:min_work_interval)   { 1.seconds }
      let(:min_boss_interval)   { 1.seconds }
      let(:min_end_interval)    { 0.1.seconds }
      let(:min_update_interval) { 1.seconds }

      it 'should run until end_block returns true' do
        end_block.target_num_calls = 3
        Timeout.timeout(1.seconds) {
          protocol.run
        }
        expect(end_block).to have_received(:call).exactly(3).times
      end

      it 'should call end_block about once per min_end_interval' do
        end_block.target_num_calls = 10
        Timeout.timeout(2.seconds) {
          protocol.run
        }
        deltas = end_block.call_times.each_cons(2).map{ |t1, t2| t2 - t1 }
        delta_mean = deltas.sum/deltas.size
        delta_std  = Math.sqrt(deltas.inject(0){ |result, val|
          result += (val - delta_mean)**2
          result
        }/(deltas.size-1))

        expect(end_block.call_count).to equal(10)
        expect(delta_mean).to be_within(0.01).of(0.1)
        expect(delta_std).to be <= 0.01
      end
    end
  end
end