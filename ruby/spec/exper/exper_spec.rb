require 'awesome_print'
require 'securerandom'

class CohortAllocator
  def initialize(cohorts:, students:)
    @cohorts  = cohorts
    @students = students

  end

  def allocate
    accepting_cohorts = @cohorts.select{|cohort| cohort[:is_accepting] == true}

    total_weight       = accepting_cohorts.map{|cohort| cohort[:weight]}.inject(:+)
    total_num_students = accepting_cohorts.map{|cohort| cohort[:students].count}.inject(:+) + @students.count

    # ap total_weight
    # ap total_num_students

    working_cohorts = accepting_cohorts.map{ |cohort|
      target_num_students = Rational(cohort[:weight], total_weight)*total_num_students
      actual_num_students = cohort[:students].count

      {
        uuid:                cohort[:uuid],
        target_num_students: target_num_students,
        actual_num_students: actual_num_students,
        new_students:        [],
        error:               actual_num_students - target_num_students,
      }
    }

    @students.each do |student|
      errors = working_cohorts.map{|cohort| cohort[:error]}
      # ap errors.map{|error| error.to_f}
      target_cohort_idx = errors.each_with_index.min.last

      target_cohort = working_cohorts[target_cohort_idx]
      target_cohort[:actual_num_students] += 1
      target_cohort[:error]               += 1
      target_cohort[:new_students] << student
    end

    return working_cohorts
  end
end

RSpec.describe 'something' do
  context 'some context' do
    let(:cohorts) {
      [
        {
          uuid:          SecureRandom.uuid.to_s,
          is_accepting:  true,
          weight:        1,
          students:      3.times.map{ SecureRandom.uuid.to_s },
        },
        {
          uuid:          SecureRandom.uuid.to_s,
          is_accepting:  true,
          weight:        2,
          students:      0.times.map{ SecureRandom.uuid.to_s },
        },
        {
          uuid:          SecureRandom.uuid.to_s,
          is_accepting:  false,
          weight:        100,
          students:      1.times.map{ SecureRandom.uuid.to_s },
        },
        {
          uuid:          SecureRandom.uuid.to_s,
          is_accepting:  true,
          weight:        3,
          students:      200.times.map{ SecureRandom.uuid.to_s },
        },
      ]
    }

    let(:students) { 100.times.map{ SecureRandom.uuid.to_s } }

    it 'works' do
      result = CohortAllocator.new(cohorts: cohorts, students: students).allocate
      ap result.map{|hh| [ hh[:new_students].count, hh[:actual_num_students], hh[:error]] }
    end
  end
end
