class ProfilesController < ApplicationController
  before_action :authenticate_user!, except: [:show, :index]
  before_action :set_profile, only: [:show, :edit, :update, :follow, :unfollow, :gallery, :highlights]
  before_action :ensure_own_profile, only: [:edit, :update]
  
  def index
    @profiles = Profile.includes(:user)
                      .with_attached_avatar
                      .where(users: { status: 'active' })
                      .order(created_at: :desc)
                      .page(params[:page]).per(24)
    
    # Apply filters if provided
    @profiles = @profiles.by_expertise(params[:expertise]) if params[:expertise].present?
    @profiles = @profiles.by_ambassador_level(params[:level]) if params[:level].present?
    @profiles = @profiles.search_by_name(params[:search]) if params[:search].present?
    
    # Filter by open for collaboration
    @profiles = @profiles.open_for_collaboration if params[:open_for_collaboration] == 'true'
    
    respond_to do |format|
      format.html
      format.json { render json: @profiles.as_json(only: [:id, :username, :display_name, :headline, :ambassador_level, :expertise]) }
      format.turbo_stream
    end
  end
  
  def show
    # Record the profile view if the viewer is logged in and not the profile owner
    if user_signed_in? && current_user.id != @profile.user_id
      @profile.record_view(current_user.id)
    end
    
    @streams = @profile.user.hosted_streams
                        .includes(:brand_ambassador, :products)
                        .order(created_at: :desc)
                        .limit(5)
    
    @testimonials = @profile.testimonials.verified.recent.limit(3)
    @highlights = @profile.profile_highlights.active.ordered
    
    # Get ambassador performance metrics if profile belongs to an ambassador
    if @profile.user.ambassador?
      @performance_metrics = @profile.performance_metrics
      @top_products = @profile.top_selling_products
    end
    
    respond_to do |format|
      format.html
      format.json { render json: @profile.as_json(include: [:testimonials, :highlights]) }
    end
  end
  
  def new
    # This should never be reached since profiles are created with users
    redirect_to edit_profile_path(current_user.profile)
  end
  
  def edit
    @social_platforms = %w(instagram tiktok youtube twitter facebook linkedin)
    @available_expertise = Profile::EXPERTISE_CATEGORIES
  end
  
  def update
    respond_to do |format|
      if @profile.update(profile_params)
        format.html { redirect_to profile_path(@profile), notice: "Profile was successfully updated." }
        format.json { render json: @profile, status: :ok }
        format.turbo_stream { flash.now[:notice] = "Profile was successfully updated." }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @profile.errors, status: :unprocessable_entity }
        format.turbo_stream { render :edit, status: :unprocessable_entity }
      end
    end
  end
  
  def follow
    current_profile = current_user.profile
    
    # Prevent following yourself
    if current_profile.id == @profile.id
      respond_to do |format|
        format.html { redirect_to @profile, alert: "You cannot follow yourself." }
        format.json { render json: { error: "You cannot follow yourself" }, status: :unprocessable_entity }
        format.turbo_stream { flash.now[:alert] = "You cannot follow yourself." }
      end
      return
    end
    
    # Create the follow relationship
    follow = Follow.new(follower: current_profile, followed: @profile)
    
    respond_to do |format|
      if follow.save
        format.html { redirect_to @profile, notice: "You are now following #{@profile.display_name_or_username}." }
        format.json { render json: { status: "following", followers_count: @profile.followers_count }, status: :ok }
        format.turbo_stream
      else
        format.html { redirect_to @profile, alert: "Could not follow this profile." }
        format.json { render json: follow.errors, status: :unprocessable_entity }
        format.turbo_stream { flash.now[:alert] = "Could not follow this profile." }
      end
    end
  end
  
  def unfollow
    current_profile = current_user.profile
    follow = Follow.find_by(follower: current_profile, followed: @profile)
    
    if follow.nil?
      respond_to do |format|
        format.html { redirect_to @profile, alert: "You are not following this profile." }
        format.json { render json: { error: "Not following" }, status: :not_found }
        format.turbo_stream { flash.now[:alert] = "You are not following this profile." }
      end
      return
    end
    
    respond_to do |format|
      if follow.destroy
        format.html { redirect_to @profile, notice: "You have unfollowed #{@profile.display_name_or_username}." }
        format.json { render json: { status: "not_following", followers_count: @profile.followers_count }, status: :ok }
        format.turbo_stream
      else
        format.html { redirect_to @profile, alert: "Could not unfollow this profile." }
        format.json { render json: { error: "Could not unfollow" }, status: :unprocessable_entity }
        format.turbo_stream { flash.now[:alert] = "Could not unfollow this profile." }
      end
    end
  end
  
  def gallery
    @gallery_images = @profile.gallery_images.order(created_at: :desc)
    
    respond_to do |format|
      format.html
      format.json { render json: @gallery_images.map { |img| { id: img.id, url: url_for(img) } } }
      format.turbo_stream
    end
  end
  
  def highlights
    @highlights = @profile.profile_highlights.active.ordered
    
    respond_to do |format|
      format.html
      format.json { render json: @highlights }
      format.turbo_stream
    end
  end
  
  def upload_gallery_image
    @profile = current_user.profile
    
    if params[:image].present?
      @profile.gallery_images.attach(params[:image])
      respond_to do |format|
        format.html { redirect_to gallery_profile_path(@profile), notice: "Image uploaded successfully." }
        format.json { render json: { success: true, image_url: url_for(@profile.gallery_images.last) }, status: :ok }
        format.turbo_stream
      end
    else
      respond_to do |format|
        format.html { redirect_to gallery_profile_path(@profile), alert: "No image selected." }
        format.json { render json: { error: "No image selected" }, status: :unprocessable_entity }
        format.turbo_stream { flash.now[:alert] = "No image selected." }
      end
    end
  end
  
  def remove_gallery_image
    @profile = current_user.profile
    image = @profile.gallery_images.find(params[:image_id])
    
    if image
      image.purge
      respond_to do |format|
        format.html { redirect_to gallery_profile_path(@profile), notice: "Image removed." }
        format.json { render json: { success: true }, status: :ok }
        format.turbo_stream
      end
    else
      respond_to do |format|
        format.html { redirect_to gallery_profile_path(@profile), alert: "Image not found." }
        format.json { render json: { error: "Image not found" }, status: :not_found }
        format.turbo_stream { flash.now[:alert] = "Image not found." }
      end
    end
  end
  
  def update_avatar
    @profile = current_user.profile
    
    if params[:avatar].present?
      @profile.avatar.attach(params[:avatar])
      respond_to do |format|
        format.html { redirect_to edit_profile_path(@profile), notice: "Profile picture updated." }
        format.json { render json: { success: true, avatar_url: url_for(@profile.avatar) }, status: :ok }
        format.turbo_stream
      end
    else
      respond_to do |format|
        format.html { redirect_to edit_profile_path(@profile), alert: "No image selected." }
        format.json { render json: { error: "No image selected" }, status: :unprocessable_entity }
        format.turbo_stream { flash.now[:alert] = "No image selected." }
      end
    end
  end
  
  def update_cover
    @profile = current_user.profile
    
    if params[:cover_photo].present?
      @profile.cover_photo.attach(params[:cover_photo])
      respond_to do |format|
        format.html { redirect_to edit_profile_path(@profile), notice: "Cover photo updated." }
        format.json { render json: { success: true, cover_url: url_for(@profile.cover_photo) }, status: :ok }
        format.turbo_stream
      end
    else
      respond_to do |format|
        format.html { redirect_to edit_profile_path(@profile), alert: "No image selected." }
        format.json { render json: { error: "No image selected" }, status: :unprocessable_entity }
        format.turbo_stream { flash.now[:alert] = "No image selected." }
      end
    end
  end
  
  def followers
    @profile = Profile.find_by!(username: params[:profile_username])
    @followers = @profile.actual_followers.includes(:user).page(params[:page]).per(20)
    
    respond_to do |format|
      format.html
      format.json { render json: @followers }
      format.turbo_stream
    end
  end
  
  def following
    @profile = Profile.find_by!(username: params[:profile_username])
    @following = @profile.actual_following.includes(:user).page(params[:page]).per(20)
    
    respond_to do |format|
      format.html
      format.json { render json: @following }
      format.turbo_stream
    end
  end
  
  def update_privacy
    @profile = current_user.profile
    
    if @profile.update(privacy_params)
      respond_to do |format|
        format.html { redirect_to edit_profile_path(@profile), notice: "Privacy settings updated." }
        format.json { render json: { success: true }, status: :ok }
        format.turbo_stream { flash.now[:notice] = "Privacy settings updated." }
      end
    else
      respond_to do |format|
        format.html { redirect_to edit_profile_path(@profile), alert: "Could not update privacy settings." }
        format.json { render json: @profile.errors, status: :unprocessable_entity }
        format.turbo_stream { flash.now[:alert] = "Could not update privacy settings." }
      end
    end
  end
  
  def update_notifications
    @profile = current_user.profile
    
    if @profile.update(notification_params)
      respond_to do |format|
        format.html { redirect_to edit_profile_path(@profile), notice: "Notification preferences updated." }
        format.json { render json: { success: true }, status: :ok }
        format.turbo_stream { flash.now[:notice] = "Notification preferences updated." }
      end
    else
      respond_to do |format|
        format.html { redirect_to edit_profile_path(@profile), alert: "Could not update notification preferences." }
        format.json { render json: @profile.errors, status: :unprocessable_entity }
        format.turbo_stream { flash.now[:alert] = "Could not update notification preferences." }
      end
    end
  end
  
  def set_availability
    @profile = current_user.profile
    
    if @profile.update(availability_params)
      respond_to do |format|
        format.html { redirect_to edit_profile_path(@profile), notice: "Availability settings updated." }
        format.json { render json: { success: true }, status: :ok }
        format.turbo_stream { flash.now[:notice] = "Availability settings updated." }
      end
    else
      respond_to do |format|
        format.html { redirect_to edit_profile_path(@profile), alert: "Could not update availability settings." }
        format.json { render json: @profile.errors, status: :unprocessable_entity }
        format.turbo_stream { flash.now[:alert] = "Could not update availability settings." }
      end
    end
  end
  
  def search
    @query = params[:q]
    @profiles = []
    
    if @query.present? && @query.length >= 2
      @profiles = Profile.includes(:user)
                         .with_attached_avatar
                         .search_by_name(@query)
                         .where(users: { status: 'active' })
                         .limit(10)
    end
    
    respond_to do |format|
      format.html
      format.json { render json: @profiles.as_json(only: [:id, :username, :display_name, :headline]) }
      format.turbo_stream
    end
  end
  
  private
  
  def set_profile
    @profile = Profile.find_by!(username: params[:username])
  end
  
  def ensure_own_profile
    unless @profile.user_id == current_user.id
      respond_to do |format|
        format.html { redirect_to @profile, alert: "You don't have permission to edit this profile." }
        format.json { render json: { error: "Unauthorized" }, status: :unauthorized }
        format.turbo_stream { flash.now[:alert] = "You don't have permission to edit this profile." }
      end
    end
  end
  
  def profile_params
    params.require(:profile).permit(
      :display_name, :bio, :location, :headline, :website, :birth_date, :gender, 
      :preferred_language, :contact_email, :public_phone, :open_for_collaboration,
      :min_collaboration_budget, :theme_preference, :accent_color,
      expertise: [], 
      social_links: {},
      education: [:institution, :degree, :field_of_study, :start_year, :end_year, :description],
      work_experience: [:company, :position, :start_date, :end_date, :description],
      certifications: [:title, :issuing_organization, :date_obtained, :expiration_date]
    )
  end
  
  def privacy_params
    params.require(:privacy_settings).permit(
      :show_email, :show_phone, :show_location, :show_birth_date, :show_sales_metrics
    )
  end
  
  def notification_params
    params.require(:notification_preferences).permit(
      :email_marketing, :email_stream_notifications, :email_order_updates,
      :push_messages, :push_stream_start
    )
  end
  
  def availability_params
    params.require(:profile).permit(
      availability_hours: {}
    )
  end
end