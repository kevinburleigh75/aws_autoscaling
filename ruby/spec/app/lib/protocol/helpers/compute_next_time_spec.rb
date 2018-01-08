require 'rails_helper'

RSpec.describe 'Protocol::Helpers.compute_next_time' do
  let(:action) {
    Protocol::Helpers.compute_next_time(
      current_time:    given_current_time,
      reference_time:  given_reference_time,
      timing_modulo:   given_timing_modulo,
      timing_offset:   given_timing_offset,
      instance_count:  given_instance_count,
      instance_modulo: given_instance_modulo,
      interval:        given_interval,
    )
  }

  context 'example group 1' do
    let(:given_reference_time)  { Chronic.parse('14:02:19.1234') }
    let(:given_timing_modulo)   { 5.0.seconds }
    let(:given_timing_offset)   { 0.3 }
    let(:given_instance_count)  { 4 }
    let(:given_interval)        { 8.seconds }

    context 'instance modulo 0' do
      let(:given_instance_modulo) { 0 }

      context 'current time is before nearest interval boundary' do
        let(:given_current_time) { Chronic.parse('14:02:07.299') }
        let(:target_next_time)   { Chronic.parse('14:02:07.300') }

        it 'passes' do
          expect(action).to be_within(1e-6.seconds).of(target_next_time)
        end
      end

      context 'current time is after nearest interval boundary' do
        let(:given_current_time) { Chronic.parse('14:02:07.301') }
        let(:target_next_time)   { Chronic.parse('14:02:15.300') }

        it 'passes' do
          expect(action).to be_within(1e-6.seconds).of(target_next_time)
        end
      end
    end

    context 'instance modulo 1' do
      let(:given_instance_modulo) { 1 }

      context 'current time is before nearest interval boundary' do
        let(:given_current_time) { Chronic.parse('14:02:09.299') }
        let(:target_next_time)   { Chronic.parse('14:02:09.300') }

        it 'passes' do
          expect(action).to be_within(1e-6.seconds).of(target_next_time)
        end
      end

      context 'current time is after nearest interval boundary' do
        let(:given_current_time) { Chronic.parse('14:02:09.301') }
        let(:target_next_time)   { Chronic.parse('14:02:17.300') }

        it 'passes' do
          expect(action).to be_within(1e-6.seconds).of(target_next_time)
        end
      end
    end

    context 'instance modulo 2' do
      let(:given_instance_modulo) { 2 }

      context 'current time is before nearest interval boundary' do
        let(:given_current_time) { Chronic.parse('14:02:11.299') }
        let(:target_next_time)   { Chronic.parse('14:02:11.300') }

        it 'passes' do
          expect(action).to be_within(1e-6.seconds).of(target_next_time)
        end
      end

      context 'current time is after nearest interval boundary' do
        let(:given_current_time) { Chronic.parse('14:02:11.301') }
        let(:target_next_time)   { Chronic.parse('14:02:19.300') }

        it 'passes' do
          expect(action).to be_within(1e-6.seconds).of(target_next_time)
        end
      end
    end

    context 'instance modulo 3' do
      let(:given_instance_modulo) { 3 }

      context 'current time is before nearest interval boundary' do
        let(:given_current_time) { Chronic.parse('14:02:13.299') }
        let(:target_next_time)   { Chronic.parse('14:02:13.300') }

        it 'passes' do
          expect(action).to be_within(1e-6.seconds).of(target_next_time)
        end
      end

      context 'current time is after nearest interval boundary' do
        let(:given_current_time) { Chronic.parse('14:02:13.301') }
        let(:target_next_time)   { Chronic.parse('14:02:21.300') }

        it 'passes' do
          expect(action).to be_within(1e-6.seconds).of(target_next_time)
        end
      end
    end
  end
end
