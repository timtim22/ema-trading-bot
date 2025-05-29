class TrackedSymbolsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_tracked_symbol, only: [:destroy, :toggle]
  
  # POST /tracked_symbols
  def create
    @tracked_symbol = current_user.tracked_symbols.build(tracked_symbol_params)
    
    respond_to do |format|
      if @tracked_symbol.save
        format.json { 
          render json: { 
            success: true, 
            message: "#{@tracked_symbol.symbol} added to tracking list",
            tracked_symbol: {
              id: @tracked_symbol.id,
              symbol: @tracked_symbol.symbol,
              active: @tracked_symbol.active
            }
          }
        }
        format.html { 
          redirect_to bot_settings_path, 
          notice: "#{@tracked_symbol.symbol} added to tracking list" 
        }
      else
        format.json { 
          render json: { 
            success: false, 
            message: @tracked_symbol.errors.full_messages.join(', '),
            errors: @tracked_symbol.errors
          }, status: :unprocessable_entity
        }
        format.html { 
          redirect_to bot_settings_path, 
          alert: @tracked_symbol.errors.full_messages.join(', ') 
        }
      end
    end
  end

  # DELETE /tracked_symbols/:id
  def destroy
    symbol = @tracked_symbol.symbol
    
    respond_to do |format|
      if @tracked_symbol.destroy
        format.json { 
          render json: { 
            success: true, 
            message: "#{symbol} removed from tracking list",
            symbol: symbol
          }
        }
        format.html { 
          redirect_to bot_settings_path, 
          notice: "#{symbol} removed from tracking list" 
        }
      else
        format.json { 
          render json: { 
            success: false, 
            message: "Failed to remove #{symbol}"
          }, status: :unprocessable_entity
        }
        format.html { 
          redirect_to bot_settings_path, 
          alert: "Failed to remove #{symbol}" 
        }
      end
    end
  end
  
  # PATCH /tracked_symbols/:id/toggle
  def toggle
    respond_to do |format|
      if @tracked_symbol.toggle_active!
        status_text = @tracked_symbol.active? ? 'activated' : 'deactivated'
        format.json { 
          render json: { 
            success: true, 
            message: "#{@tracked_symbol.symbol} #{status_text}",
            tracked_symbol: {
              id: @tracked_symbol.id,
              symbol: @tracked_symbol.symbol,
              active: @tracked_symbol.active
            }
          }
        }
        format.html { 
          redirect_to bot_settings_path, 
          notice: "#{@tracked_symbol.symbol} #{status_text}" 
        }
      else
        format.json { 
          render json: { 
            success: false, 
            message: "Failed to toggle #{@tracked_symbol.symbol}"
          }, status: :unprocessable_entity
        }
        format.html { 
          redirect_to bot_settings_path, 
          alert: "Failed to toggle #{@tracked_symbol.symbol}" 
        }
      end
    end
  end

  private

  def set_tracked_symbol
    @tracked_symbol = current_user.tracked_symbols.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.json { 
        render json: { 
          success: false, 
          message: "Symbol not found" 
        }, status: :not_found
      }
      format.html { 
        redirect_to bot_settings_path, 
        alert: "Symbol not found" 
      }
    end
  end

  def tracked_symbol_params
    params.require(:tracked_symbol).permit(:symbol, :active)
  end
end
