# frozen_string_literal: true

module Jobs
  class AssignNotification < ::Jobs::Base
    def execute(args)
      raise Discourse::InvalidParameters.new(:topic_id) if args[:topic_id].nil?
      raise Discourse::InvalidParameters.new(:post_id) if args[:post_id].nil?
      raise Discourse::InvalidParameters.new(:assigned_to_id) if args[:assigned_to_id].nil?
      raise Discourse::InvalidParameters.new(:assigned_to_type) if args[:assigned_to_type].nil?
      raise Discourse::InvalidParameters.new(:assigned_by_id) if args[:assigned_by_id].nil?
      raise Discourse::InvalidParameters.new(:silent) if args[:silent].nil?

      topic = Topic.find(args[:topic_id])
      post = Post.find(args[:post_id])
      assigned_by = User.find(args[:assigned_by_id])
      assigned_to = args[:assigned_to_type] == "User" ? User.find(args[:assigned_to_id]) : Group.find(args[:assigned_to_id])
      assigned_to_users = args[:assigned_to_type] == "User" ? [assigned_to] : assigned_to.users

      assigned_to_users.each do |user|
        Assigner.publish_topic_tracking_state(topic, user.id)

        next if assigned_by == user

        PostAlerter.new(post).create_notification_alert(
          user: user,
          post: post,
          username: assigned_by.username,
          notification_type: Notification.types[:custom],
          excerpt: I18n.t(
            "discourse_assign.topic_assigned_excerpt",
            title: topic.title,
            locale: user.effective_locale
          )
        )

        next if args[:silent]
        Notification.create!(
          notification_type: Notification.types[:custom],
          user_id: user.id,
          topic_id: topic.id,
          post_number: post.post_number,
          high_priority: true,
          data: {
            message: args[:assigned_to_type] == "User" ? 'discourse_assign.assign_notification' : 'discourse_assign.assign_group_notification',
            display_username: args[:assigned_to_type] == "User" ? assigned_by.username : assigned_to.name,
            topic_title: topic.title
          }.to_json
        )
      end
    end
  end
end
