class Spree::SofortController < ApplicationController

  skip_before_filter :verify_authenticity_token, :only => :status

  def success
    # changed by Manuel Thurner - if there are multiple with the same sofort hash, take the last one.
    # this can happen if a previous attempt to checkout with sofort was unsuccessful
    sofort_payment = Spree::Payment.unscoped.where(sofort_hash: params[:sofort_hash]).order('created_at DESC').first
    if params.blank? or params[:sofort_hash].blank? or sofort_payment.blank?
       flash[:error] = I18n.t("sofort.payment_not_found")
       redirect_to '/checkout/payment', :status => 302
       return
    end

    order = sofort_payment.order
    if order.blank?
     	flash[:error] = I18n.t("sofort.order_not_found")
     	redirect_to '/checkout/payment', :status => 302
     	return
    end

    if order.state.eql? "complete"  # complete again via browser back or recalling sofort "go" url
      success_redirect order
    else
      order.finalize!
      order.state = "complete"
      order.save!
      # Added by Manuel Thurner <manuel@volo.de> to reflect our custom data model
      sofort_payment.type_label = 'sofort'
      sofort_payment.complete!
      session[:order_id] = nil
      flash[:success] = I18n.t("sofort.completed_successfully")
      success_redirect order
    end

  end

  def cancel
    flash[:error] = I18n.t("sofort.canceled")
    redirect_to '/checkout/payment', :status => 302
  end

  def status
    Spree::SofortService.instance.eval_transaction_status_change(params)

    render :nothing => true
  end

  private

  def success_redirect order
    redirect_to "/orders/#{order.number}", :status => 302
  end

end
