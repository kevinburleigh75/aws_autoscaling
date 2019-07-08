require 'rails_helper'

RSpec.describe 'Protocol::Core#process' do
  def self.check_method_calls
    called_methods.each do |thing|
      if thing.is_a?(Array)
        method_name = thing[0]
        call_count  = thing[1]

        it "calls #{method_name} #{call_count} times" do
          action
          expect(given_world).to have_received(method_name).exactly(call_count).times
        end
      else
        method_name = thing
        it "calls #{method_name}" do
          action
          expect(given_world).to have_received(method_name).once
        end
      end
    end

    uncalled_methods.each do |method_name|
      it "does not call #{method_name}" do
        action
        expect(given_world).to_not have_received(method_name)
      end
    end
  end

  let(:given_process_time) { Chronic.parse('Oct 6, 2014 14:56:31.5256') }

  let(:core) {
    Protocol::Core.new(
      world: given_world
    )
  }

  let(:nil_value) { nil }

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

  def self.method_infos
    [
      [:read_group_records             , :nil_value                                ],
      [:categorize_records             , :nil_value                                ],
      [:has_instance_record?           , :has_instance_record_return_value         ],
      [:create_instance_record         , :nil_value                                ],
      [:has_boss_record?               , :has_boss_record_return_value             ],
      [:update_boss_vote               , :nil_value                                ],
      [:align_with_boss                , :nil_value                                ],
      [:am_boss?                       , :am_boss_return_value                     ],
      [:has_next_boss_time?            , :has_next_boss_time_return_value          ],
      [:compute_and_set_next_boss_time , :nil_value                                ],
      [:clear_next_boss_time           , :nil_value                                ],
      [:destroy_dead_records           , :nil_value                                ],
      [:allocate_modulo                , :allocate_modulo_return_value             ],
      [:end_block_should_be_called?    , :end_block_should_be_called_return_value  ],
      [:call_end_block                 , :end_block_return_value                   ],
      [:compute_and_set_next_end_time  , :nil_value                                ],
      [:boss_block_should_be_called?   , :boss_block_should_be_called_return_value ],
      [:call_boss_block                , :nil_value                                ],
      [:compute_and_set_next_boss_time , :nil_value                                ],
      [:work_block_should_be_called?   , :work_block_should_be_called_return_value ],
      [:call_work_block                , :nil_value                                ],
      [:compute_and_set_next_work_time , :nil_value                                ],
      [:compute_next_wake_time         , :nil_value                                ],
      [:sleep_until_next_event         , :nil_value                                ],
      [:save_record                    , :nil_value                                ],
    ]
  end

  def self.all_methods
    method_infos.map{|method_name,value| method_name}
  end

  def self.called_methods
    []
  end

  def self.uncalled_methods
    []
  end

  let(:given_world) {
    dbl = double.tap{ |dbl|
      self.class.method_infos.each do |method_name, value_sym|
        value = send(value_sym)
        allow(dbl).to receive(method_name).and_return(value)
      end
    }
  }

  let(:action) { core.process(process_time: given_process_time) }

  context 'unconditionally' do
    def self.called_methods
      [ :read_group_records,
        :categorize_records,
        :has_instance_record?,
      ]
    end

    def self.uncalled_methods
      []
    end

    check_method_calls
  end

  context 'when the target instance record does not exist' do
    let(:has_instance_record_return_value) { false }

    def self.called_methods
      [ :create_instance_record ]
    end

    def self.unchecked_methods
        [ :read_group_records,
          :categorize_records,
          :has_instance_record?, ]
    end

    def self.uncalled_methods
      all_methods - called_methods - unchecked_methods
    end

    check_method_calls
  end

  context 'when the target instance record does exist' do
    let(:has_instance_record_return_value) { true }

    def self.called_methods
      [ :has_boss_record? ]
    end

    def self.uncalled_methods
      [ ]
    end

    check_method_calls

    context 'when there is no boss record' do
      let(:has_boss_record_return_value) { false }

      def self.called_methods
        [ :update_boss_vote ]
      end

      def self.unchecked_methods
        [ :read_group_records,
          :categorize_records,
          :has_instance_record?,
          :has_boss_record?,
          :save_record, ]
      end

      def self.uncalled_methods
        all_methods - called_methods - unchecked_methods
      end

      check_method_calls
    end

    context 'when there is a boss record' do
      let(:has_boss_record_return_value) { true }

      def self.called_methods
        [ :allocate_modulo,
          :align_with_boss,
          [:am_boss?,2], ]
      end

      def self.uncalled_methods
        [ ]
      end

      check_method_calls

      context 'when this instance the the boss' do
        let(:am_boss_return_value) { true }

        def self.called_methods
          [ :destroy_dead_records ]
        end

        def self.uncalled_methods
          [ ]
        end

        check_method_calls
      end

      context 'when the instance modulo needs to be allocated' do
        let(:allocate_modulo_return_value) { true }

        def self.called_methods
          [ ]
        end

        def self.unchecked_methods
          [
            :read_group_records,
            :categorize_records,
            :has_instance_record?,
            :has_boss_record?,
            :align_with_boss,
            :am_boss?,
            :destroy_dead_records,
            :allocate_modulo,
          ]
        end

        def self.uncalled_methods
          all_methods - called_methods - unchecked_methods
        end

        check_method_calls
      end

      context 'when the instance modulo does not need to be allocated' do
        let(:allocate_modulo_return_value) { false }

        def self.called_methods
          [ [:am_boss?,2] ]
        end

        def self.uncalled_methods
          [ ]
        end

        check_method_calls

        context 'when this instance is the boss' do
          let(:am_boss_return_value) { true }

          def self.called_methods
            [
              :has_next_boss_time?,
              :boss_block_should_be_called?,
            ]
          end

          def self.uncalled_methods
            [ :clear_next_boss_time ]
          end

          check_method_calls

          context 'when this instance has no next_boss_time' do
            let(:has_next_boss_time_return_value) { false }

            def self.called_methods
              [ :compute_and_set_next_boss_time ]
            end

            def self.uncalled_methods
              [ ]
            end

            check_method_calls
          end

          context 'when this instance has a next_boss_time' do
            let(:has_next_boss_time_return_value) { true }

            def self.called_methods
              [ ]
            end

            def self.uncalled_methods
              [ :compute_and_set_next_boss_time ]
            end

            check_method_calls
          end

          context 'when the boss block should be called' do
            let(:has_next_boss_time_return_value)          { true }
            let(:boss_block_should_be_called_return_value) { true }

            def self.called_methods
              [
                :call_boss_block,
                :compute_and_set_next_boss_time,
              ]
            end

            def self.uncalled_methods
              [ ]
            end

            check_method_calls
          end

          context 'when the boss block should not be called' do
            let(:has_next_boss_time_return_value)          { true }
            let(:boss_block_should_be_called_return_value) { false }

            def self.called_methods
              [ ]
            end

            def self.uncalled_methods
              [ :call_boss_block,
                :compute_and_set_next_boss_time,
              ]
            end

            check_method_calls
          end
        end

        context 'when this instance is not the boss' do
          let(:am_boss_return_value) { false }

          def self.called_methods
            [ :clear_next_boss_time ]
          end

          def self.uncalled_methods
            [
              :destroy_dead_records,
              :compute_and_set_next_boss_time,
              :boss_block_should_be_called?,
            ]
          end

          check_method_calls
        end

        context 'when the end block should be called' do
          let(:end_block_should_be_called_return_value) { true }

          def self.called_methods
            [ :call_end_block ]
          end

          def self.uncalled_methods
            [ ]
          end

          check_method_calls

          context 'when the end block returns truthy' do
            let(:end_block_return_value) { true }

            def self.called_methods
              [ ]
            end

            def self.uncalled_methods
              [
                :compute_and_set_next_end_time,
                :compute_next_wake_time,
                :sleep_until_next_event,
                :save_record,
              ]
            end

            check_method_calls
          end

          context 'when the end block returns falsy' do
            let(:end_block_return_value) { false }

            def self.called_methods
              [
                :compute_and_set_next_end_time,
                :compute_next_wake_time,
                :sleep_until_next_event,
                :save_record,
              ]
            end

            def self.uncalled_methods
              [ ]
            end

            check_method_calls
          end
        end

        context 'when the end block should not be called' do
          let(:end_block_should_be_called_return_value) { false }

          def self.called_methods
            [ ]
          end

          def self.uncalled_methods
            [
              :call_end_block,
              :compute_and_set_next_end_time,
            ]
          end

          check_method_calls
        end

        context 'when the work block should be called' do
          let(:work_block_should_be_called_return_value) { true }

          def self.called_methods
            [
              :call_work_block,
              :compute_and_set_next_work_time,
            ]
          end

          def self.uncalled_methods
            [ ]
          end

          check_method_calls
        end

        context 'when the work block should not be called' do
          let(:work_block_should_be_called_return_value) { false }

          def self.called_methods
            [ ]
          end

          def self.uncalled_methods
            [
              :call_work_block,
              :compute_and_set_next_work_time,
            ]
          end

          check_method_calls
        end

      end
    end
  end
end
