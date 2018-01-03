require 'rails_helper'
require 'timeout'

class TestBlock
  attr_accessor :call_count
  attr_accessor :target_num_calls
  attr_accessor :call_times

  def initialize(call_block: lambda{|block| block.call_count == block.target_num_calls})
    @target_num_calls = -1
    @call_count       =  0
    @call_times       = []
    @call_block       = call_block
  end

  def call
    self.call_times << Time.now()
    self.call_count += 1

    @call_block.call(self)
  end
end

RSpec.describe 'protocol' do

  context '.run' do
    context 'termination' do
      context 'no end_block is given' do
        let(:protocol) {
          Protocol.new
        }

        context '.run loops forever' do
          it 'should pass' do
            expect {
              Timeout.timeout(2.seconds) {
                protocol.run
              }
            }.to raise_error(Timeout::Error);
          end
        end
      end

      context 'end_block is given' do
        let(:min_end_interval) { 0.05.seconds }

        let(:end_block) {
          dbl = TestBlock.new
          allow(dbl).to receive(:call).and_call_original
          dbl
        }

        let(:protocol) {
          Protocol.new(
            min_end_interval: min_end_interval,
            end_block:        end_block,
          )
        }

        context '.run continues until end_block returns truthy' do
          it 'should pass' do
            end_block.target_num_calls = 3
            Timeout.timeout(1.seconds) {
              protocol.run
            }
            expect(end_block).to have_received(:call).exactly(3).times
          end
        end
      end
    end

    context 'block timing' do
      context 'when end, boss, and work blocks are given' do
        let(:min_boss_interval) { 0.07654.seconds }

        let(:boss_block) {
          dbl = TestBlock.new
          allow(dbl).to receive(:call).and_call_original
          dbl
        }

        let(:min_work_interval) { 0.04321.seconds }

        let(:work_block) {
          dbl = TestBlock.new
          allow(dbl).to receive(:call).and_call_original
          dbl
        }

        let(:min_end_interval) { 0.02345.seconds }

        let(:end_block) {
          dbl = TestBlock.new(call_block: lambda{ |block|
            (block.call_count >= 10) && (boss_block.call_count >= 10) && (work_block.call_count >= 10)
          })
          allow(dbl).to receive(:call).and_call_original
          dbl
        }

        let(:protocol) {
          Protocol.new(
            min_end_interval:  min_end_interval,
            end_block:         end_block,
            min_boss_interval: min_boss_interval,
            boss_block:        boss_block,
            min_work_interval: min_work_interval,
            work_block:        work_block,
          )
        }

        context '.run calls end_block about once per min_end_interval' do
          it 'should pass' do
            Timeout.timeout(2.seconds) {
              protocol.run
            }

            deltas = end_block.call_times.each_cons(2).map{|t1, t2| t2 - t1}
            delta_mean = deltas.sum/[deltas.size,1].max
            delta_std  = Math.sqrt(deltas.inject(0){ |result, val|
              result += (val - delta_mean)**2
              result
            })/[deltas.size-1,1].max

            expect(end_block.call_count).to  be >= 10
            expect(delta_mean).to be_within(0.01).of(min_end_interval)
            expect(delta_std).to be <= 0.01
          end
        end

        context '.run calls boss_block about once per min_boss_interval' do
          it 'should pass' do
            Timeout.timeout(2.seconds) {
              protocol.run
            }

            deltas = boss_block.call_times.each_cons(2).map{|t1, t2| t2 - t1}
            delta_mean = deltas.sum/[deltas.size,1].max
            delta_std  = Math.sqrt(deltas.inject(0){ |result, val|
              result += (val - delta_mean)**2
              result
            })/[deltas.size-1,1].max

            expect(boss_block.call_count).to  be >= 10
            expect(delta_mean).to be_within(0.01).of(min_boss_interval)
            expect(delta_std).to be <= 0.01
          end
        end

        context '.run calls work_block about once per min_work_interval' do
          it 'should pass' do
            Timeout.timeout(2.seconds) {
              protocol.run
            }

            deltas = work_block.call_times.each_cons(2).map{|t1, t2| t2 - t1}
            delta_mean = deltas.sum/[deltas.size,1].max
            delta_std  = Math.sqrt(deltas.inject(0){ |result, val|
              result += (val - delta_mean)**2
              result
            })/[deltas.size-1,1].max

            expect(work_block.call_count).to  be >= 10
            expect(delta_mean).to be_within(0.01).of(min_work_interval)
            expect(delta_std).to be <= 0.01
          end
        end

      end
    end
  end
end
