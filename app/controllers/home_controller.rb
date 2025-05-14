class HomeController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index], if: :devise_controller?
  
  def index
  end
end
