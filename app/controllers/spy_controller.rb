class SpyController < ApplicationController
  def index
    @finnish, @bullshits = Spy::Agent.instance.run
  end
end
