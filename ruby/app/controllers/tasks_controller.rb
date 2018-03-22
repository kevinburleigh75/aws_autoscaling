class TasksController < ApplicationController
  def task1
    sleep(0.05)
    render plain: "InstanceId: #{ENV['AWS_INSTANCE_ID']} LcName: #{ENV['AWS_ASG_LC_NAME']} LcImageId: #{ENV['AWS_ASG_LC_IMAGE_ID']}"

    filename = Rails.root.join('tmp','status.txt').to_s
    FileUtils.touch(filename)
  end

  def task2
    sleep(30)
    render plain: 'well that was long'

    filename = Rails.root.join('tmp','status.txt').to_s
    FileUtils.touch(filename)
  end
end