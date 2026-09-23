class Cards::ClosuresController < ApplicationController
  def create
    redirect_to card_path(params[:card_id])
  end

  def destroy
    redirect_to card_path(params[:card_id])
  end
end
