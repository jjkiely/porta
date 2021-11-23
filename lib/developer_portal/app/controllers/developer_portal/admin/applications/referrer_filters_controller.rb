class DeveloperPortal::Admin::Applications::ReferrerFiltersController < ::DeveloperPortal::BaseController
  before_action :find_cinstance

  # TODO: this controller responds only with js, so redirect part doesn't make much sense.

  def create
    @referrer_filter = @cinstance.referrer_filters.add(params[:referrer_filter])

    if @referrer_filter.persisted?
      if request.xhr?
        render
      else
        redirect_to return_url, notice: 'Referrer filter has been created.'
      end
    else
      @error = @referrer_filter.errors.full_messages.to_sentence

      if request.xhr?
        render :action => 'error'
      else
        flash[:error] = @error
        redirect_to(return_url)
      end
    end
  end

  def destroy
    @referrer_filter = @cinstance.referrer_filters.find(params[:id])
    @referrer_filter.destroy

    if request.xhr?
      render
    else
      redirect_to return_url, notice: 'Referrer filter has been deleted.'
    end
  end

  private

    def find_cinstance
      @cinstance = current_account.bought_cinstances.by_service(@service).find(params.require(:application_id))
    end

    def return_url
      if site_account.multiple_applications_allowed?
        admin_application_path(@cinstance)
      else
        admin_applications_access_details_path
      end
    end
end
