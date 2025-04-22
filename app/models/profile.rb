class Profile < ApplicationRecord
  belongs_to :user

  # Attachments
  has_one_attached :avatar
  has_one_attached :cover_photo
  has_many_attached :gallery_images
  
  # Associations
  has_many :followers, class_name: 'Follow', foreign_key: 'followed_id', dependent: :destroy
  has_many :following, class_name: 'Follow', foreign_key: 'follower_id', dependent: :destroy
  has_many :actual_followers, through: :followers, source: :follower
  has_many :actual_following, through: :following, source: :followed
  has_many :testimonials, dependent: :destroy
  has_many :profile_highlights, dependent: :destroy
  has_many :profile_views, dependent: :destroy

  # Validations
  validates :username, presence: true, uniqueness: { case_sensitive: false }
  validates :username, format: { with: /\A[a-zA-Z0-9_\.]+\z/, message: "only allows letters, numbers, dots and underscores" }
  validates :username, length: { in: 3..30 }
  validates :display_name, length: { maximum: 50 }
  validates :bio, length: { maximum: 1000 }
  validates :headline, length: { maximum: 100 }
  validates :website, format: { with: URI::regexp(%w(http https)), allow_blank: true }
  validates :contact_email, format: { with: URI::MailTo::EMAIL_REGEXP, allow_blank: true }
  validates :ambassador_level, inclusion: { in: %w(bronze silver gold platinum diamond) }, allow_nil: true
  validate :birth_date_cannot_be_in_the_future
  validate :validate_gallery_images_count

  # Constants
  AMBASSADOR_LEVELS = %w(bronze silver gold platinum diamond).freeze
  EXPERTISE_CATEGORIES = [
    "Fashion", "Beauty", "Home Decor", "Electronics", "Fitness", 
    "Cooking", "Arts & Crafts", "Gaming", "Parenting", "Travel",
    "Wellness", "Finance", "Education", "Photography", "Music"
  ].freeze

  # Scopes
  scope :featured, -> { where("featured_until > ?", Time.current) }
  scope :recommended, -> { where(is_recommended: true) }
  scope :by_ambassador_level, ->(level) { where(ambassador_level: level) }
  scope :by_expertise, ->(expertise) { where("expertise @> ARRAY[?]::varchar[]", expertise) }
  scope :open_for_collaboration, -> { where(open_for_collaboration: true) }
  scope :search_by_name, ->(query) { 
    where("username ILIKE :q OR display_name ILIKE :q", q: "%#{query}%") 
  }

  # Callbacks
  before_save :update_ambassador_level
  before_save :sanitize_content
  after_create :set_default_avatar

  # Methods
  def display_name_or_username
    display_name.presence || username
  end
  
  def featured?
    featured_until.present? && featured_until > Time.current
  end
  
  def profile_completion_percentage
    required_fields = [
      username.present?,
      display_name.present?,
      bio.present?,
      location.present?,
      headline.present?,
      expertise.any?,
      avatar.attached?,
      cover_photo.attached?,
      website.present? || social_links.any?
    ]
    
    (required_fields.count(true).to_f / required_fields.size * 100).round
  end

  def record_view(viewer_id)
    return if viewer_id == user_id # Don't count self-views
    
    view = profile_views.find_or_initialize_by(viewer_id: viewer_id)
    view.views_count += 1
    view.last_viewed_at = Time.current
    view.save
  end
  
  def add_expertise(expertise_name)
    return false unless EXPERTISE_CATEGORIES.include?(expertise_name)
    return true if expertise.include?(expertise_name)
    
    self.expertise = expertise + [expertise_name]
    save
  end
  
  def social_links_list
    links = social_links || {}
    links.map { |platform, url| { platform: platform, url: url } }
  end
  
  def formatted_social_links
    default_links = { 
      "instagram" => nil, 
      "tiktok" => nil, 
      "youtube" => nil,
      "twitter" => nil,
      "facebook" => nil,
      "linkedin" => nil
    }
    
    default_links.merge(social_links || {})
  end
  
  def performance_metrics(period = 30.days.ago)
    {
      sales_count: user.brand_ambassadors.joins(:attributed_order_items)
                       .where('order_items.created_at > ?', period).count,
      commission_earned: user.commission_records
                         .where('created_at > ?', period)
                         .sum(:amount),
      total_stream_minutes: user.hosted_streams
                            .where('created_at > ?', period)
                            .sum('EXTRACT(EPOCH FROM (end_time - actual_start_time)) / 60'),
      total_viewers: user.hosted_streams
                    .where('created_at > ?', period)
                    .sum(:live_viewer_count)
    }
  end
  
  def top_selling_products(limit = 5)
    user.brand_ambassadors.approved.joins(attributed_order_items: :product)
        .select('products.*, SUM(order_items.quantity) as total_sold')
        .group('products.id')
        .order('total_sold DESC')
        .limit(limit)
  end
  
  def is_available_at?(datetime)
    day = datetime.strftime('%A').downcase
    return false unless availability_hours&.dig(day).present?
    
    time_str = datetime.strftime('%H:%M')
    availability_hours[day].any? do |slot|
      time_str >= slot['start'] && time_str <= slot['end']
    end
  end
  
  def update_privacy_setting(setting, value)
    return false unless privacy_settings&.key?(setting.to_s)
    
    privacy = self.privacy_settings.dup
    privacy[setting.to_s] = value
    update(privacy_settings: privacy)
  end

  private
  
  def birth_date_cannot_be_in_the_future
    if birth_date.present? && birth_date > Date.today
      errors.add(:birth_date, "can't be in the future")
    end
  end
  
  def validate_gallery_images_count
    if gallery_images.attached? && gallery_images.count > 10
      errors.add(:gallery_images, "you can upload a maximum of 10 images")
    end
  end
  
  def update_ambassador_level
    return if ambassador_level_changed? # Skip if manually changed
    
    total_commission = total_commission_earned || 0
    streams = streams_count || 0
    
    self.ambassador_level = 
      if total_commission > 10000 && streams > 50
        "diamond"
      elsif total_commission > 5000 && streams > 30
        "platinum"
      elsif total_commission > 2500 && streams > 20
        "gold"
      elsif total_commission > 1000 && streams > 10
        "silver"
      else
        "bronze"
      end
  end
  
  def sanitize_content
    self.bio = ActionController::Base.helpers.sanitize(bio) if bio.present?
    self.headline = ActionController::Base.helpers.sanitize(headline) if headline.present?
  end
  
  def set_default_avatar
    return if avatar.attached?
    
    # If you have an avatar service, uncomment this
    # avatar_service = DefaultAvatarService.new(self)
    # avatar_blob = avatar_service.generate_avatar
    # avatar.attach(avatar_blob) if avatar_blob
  end
end