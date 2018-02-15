class TasksController < ApplicationController
  def task1
    sleep(0.05)
    render plain: 'well that was fun (2)'
  end

  def task2
    sleep(30)
    render plain: 'well that was long'
  end
end