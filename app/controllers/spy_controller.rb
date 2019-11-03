class SpyController < ApplicationController
  def index
    Spy::Agent.instance.loadall
    @finnish, @bullshits = Spy::Agent.instance.run
  end
end
