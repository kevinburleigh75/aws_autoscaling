class TasksController < ApplicationController
  def task1
    sleep(0.05)
    render plain: 'well that was fun (6)'

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