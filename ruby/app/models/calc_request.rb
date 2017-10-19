class CalcRequest < ActiveRecord::Base
  after_initialize :init

  def init
    self.partition_value ||= Kernel.rand(1*2*3*4*5*6*7*8*9*10)
  end
end
