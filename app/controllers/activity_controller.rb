class ActivityController < ApplicationController
  before_action :authenticate_user!
  
  def index
    @activities = filter_activities
    @event_types = ActivityLog::TYPES
    @levels = ActivityLog::LEVELS
    
    # Get filter parameters
    @selected_type = params[:type]
    @selected_level = params[:level]
    @selected_timeframe = params[:timeframe] || 'today'
    
    # Statistics for the dashboard
    @stats = calculate_stats
    
    respond_to do |format|
      format.html
      format.json { render json: activities_json }
    end
  end
  
  # Stream new activities via AJAX
  def stream
    last_id = params[:last_id].to_i
    new_activities = ActivityLog.where('id > ?', last_id)
                                .recent
                                .limit(50)
    
    render json: {
      activities: new_activities.map { |activity| activity_json(activity) },
      last_id: new_activities.maximum(:id) || last_id
    }
  end
  
  # Clear old logs (admin functionality)
  def clear
    if current_user.admin?
      days_to_keep = params[:days]&.to_i || 30
      deleted_count = ActivityLog.where('occurred_at < ?', days_to_keep.days.ago).delete_all
      
      ActivityLog.log_info(
        "Activity logs cleared: #{deleted_count} entries older than #{days_to_keep} days",
        event_type: 'system',
        user: current_user
      )
      
      flash[:notice] = "Cleared #{deleted_count} old activity logs"
    else
      flash[:alert] = "Access denied"
    end
    
    redirect_to activity_path
  end
  
  private
  
  def filter_activities
    activities = ActivityLog.includes(:user).recent
    
    # Filter by user (only show current user's activities unless admin)
    unless current_user.admin?
      activities = activities.where(user: [current_user, nil])
    end
    
    # Apply filters
    activities = activities.by_type(params[:type])
    activities = activities.by_level(params[:level])
    
    # Apply timeframe filter
    case params[:timeframe]
    when 'today'
      activities = activities.today
    when 'week'
      activities = activities.this_week
    when 'hour'
      activities = activities.where(occurred_at: 1.hour.ago..Time.current)
    when 'all'
      # No time filter
    else
      activities = activities.today
    end
    
    # Add pagination with Kaminari
    activities.page(params[:page]).per(25)
  end
  
  def calculate_stats
    base_scope = current_user.admin? ? ActivityLog.all : ActivityLog.where(user: [current_user, nil])
    
    {
      total_today: base_scope.today.count,
      errors_today: base_scope.today.where(level: 'error').count,
      signals_today: base_scope.today.where(event_type: 'signal').count,
      orders_today: base_scope.today.where(event_type: 'order').count,
      last_activity: base_scope.recent.first&.occurred_at
    }
  end
  
  def activities_json
    pagination_info = if @activities.respond_to?(:current_page)
      {
        current_page: @activities.current_page,
        total_pages: @activities.total_pages,
        total_count: @activities.total_count,
        limit_value: @activities.limit_value,
        offset_value: @activities.offset_value
      }
    else
      nil
    end
    
    {
      activities: @activities.map { |activity| activity_json(activity) },
      stats: @stats,
      pagination: pagination_info,
      filters: {
        type: @selected_type,
        level: @selected_level,
        timeframe: @selected_timeframe
      }
    }
  end
  
  def activity_json(activity)
    {
      id: activity.id,
      event_type: activity.event_type,
      level: activity.level,
      message: activity.message,
      symbol: activity.symbol,
      user: activity.user&.email,
      details: activity.details,
      occurred_at: activity.occurred_at.iso8601,
      formatted_time: activity.formatted_occurred_at,
      time_ago: activity.time_ago,
      level_badge_class: activity.level_badge_class,
      type_badge_class: activity.type_badge_class
    }
  end
end 